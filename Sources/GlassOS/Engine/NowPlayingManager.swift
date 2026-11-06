import AppKit
import Combine

struct TimedLyricLine: Identifiable {
    let id = UUID()
    let timestamp: Double
    let text: String
}

class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()

    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var lyrics: String = ""
    @Published var timedLyrics: [TimedLyricLine] = []
    @Published var elapsedTime: Double = 0
    @Published var duration: Double = 0

    private var timer: Timer?
    private var playbackTimer: Timer?
    private var elapsedTimeBase: Double = 0
    private var elapsedTimestamp: Date = Date()
    private var mrHandle: UnsafeMutableRawPointer?

    private typealias MRInfoCallback = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRStateCallback = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias MRRegisterNotifs = @convention(c) (DispatchQueue) -> Void

    private var _getNowPlayingInfo: MRInfoCallback?
    private var _getIsPlaying: MRStateCallback?

    private var titleKey = "kMRMediaRemoteNowPlayingInfoTitle"
    private var artistKey = "kMRMediaRemoteNowPlayingInfoArtist"
    private var albumKey = "kMRMediaRemoteNowPlayingInfoAlbum"
    private var artworkKey = "kMRMediaRemoteNowPlayingInfoArtworkData"
    private var elapsedTimeKey = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    private var durationKey = "kMRMediaRemoteNowPlayingInfoDuration"

    private init() {
        loadMediaRemote()
        setupNotifications()
        startPolling()
        startPlaybackTimer()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(
            self, selector: #selector(musicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil
        )
        dnc.addObserver(
            self, selector: #selector(spotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil
        )

        let nc = NotificationCenter.default
        for name in [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
        ] {
            nc.addObserver(self, selector: #selector(mediaRemoteChanged),
                           name: NSNotification.Name(name), object: nil)
        }
    }

    @objc private func mediaRemoteChanged() {
        fetchNowPlaying()
    }

    @objc private func musicNotification(_ notification: Notification) {
        guard let info = notification.userInfo else {
            fetchNowPlaying()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let newTitle = info["Name"] as? String ?? ""
            guard !newTitle.isEmpty else { return }

            let titleChanged = newTitle != self.title
            self.title = newTitle
            self.artist = info["Artist"] as? String ?? ""
            self.album = info["Album"] as? String ?? ""

            let state = info["Player State"] as? String ?? ""
            self.isPlaying = (state == "Playing")

            if let totalTime = info["Total Time"] as? Double {
                self.duration = totalTime / 1000.0
            }
            if let position = info["Player Position"] as? Double {
                self.elapsedTimeBase = position
                self.elapsedTimestamp = Date()
                self.elapsedTime = position
            }

            if titleChanged {
                self.fetchArtwork()
                self.fetchLyrics()
            }
        }
    }

    @objc private func spotifyNotification(_ notification: Notification) {
        guard let info = notification.userInfo else {
            fetchNowPlaying()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let newTitle = info["Name"] as? String ?? ""
            guard !newTitle.isEmpty else { return }

            let titleChanged = newTitle != self.title
            self.title = newTitle
            self.artist = info["Artist"] as? String ?? ""
            self.album = info["Album"] as? String ?? ""

            let state = info["Player State"] as? String ?? ""
            self.isPlaying = (state == "Playing")

            if let dur = info["Duration"] as? Double {
                self.duration = dur / 1000.0
            }
            if let position = info["Playback Position"] as? Double {
                self.elapsedTimeBase = position
                self.elapsedTimestamp = Date()
                self.elapsedTime = position
            }

            if titleChanged {
                self.fetchArtwork()
            }
            self.lyrics = ""
            self.timedLyrics = []
        }
    }

    // MARK: - MediaRemote (via dlopen for reliability)

    private func loadMediaRemote() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else { return }
        mrHandle = handle

        if let ptr = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            _getNowPlayingInfo = unsafeBitCast(ptr, to: MRInfoCallback.self)
        }
        if let ptr = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            _getIsPlaying = unsafeBitCast(ptr, to: MRStateCallback.self)
        }

        loadKeyViaDlsym(handle, symbol: "kMRMediaRemoteNowPlayingInfoTitle", into: &titleKey)
        loadKeyViaDlsym(handle, symbol: "kMRMediaRemoteNowPlayingInfoArtist", into: &artistKey)
        loadKeyViaDlsym(handle, symbol: "kMRMediaRemoteNowPlayingInfoAlbum", into: &albumKey)
        loadKeyViaDlsym(handle, symbol: "kMRMediaRemoteNowPlayingInfoArtworkData", into: &artworkKey)
        loadKeyViaDlsym(handle, symbol: "kMRMediaRemoteNowPlayingInfoElapsedTime", into: &elapsedTimeKey)
        loadKeyViaDlsym(handle, symbol: "kMRMediaRemoteNowPlayingInfoDuration", into: &durationKey)

        if let ptr = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let register = unsafeBitCast(ptr, to: MRRegisterNotifs.self)
            register(DispatchQueue.main)
        }
    }

    private func loadKeyViaDlsym(_ handle: UnsafeMutableRawPointer, symbol: String, into target: inout String) {
        guard let ptr = dlsym(handle, symbol) else { return }
        guard let strPtr = ptr.load(as: UnsafeRawPointer?.self) else { return }
        target = Unmanaged<NSString>.fromOpaque(strPtr).takeUnretainedValue() as String
    }

    private func startPolling() {
        fetchNowPlaying()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchNowPlaying()
        }
    }

    func fetchNowPlaying() {
        if let getNowPlayingInfo = _getNowPlayingInfo {
            getNowPlayingInfo(DispatchQueue.main) { [weak self] info in
                guard let self = self else { return }
                let newTitle = info[self.titleKey] as? String ?? ""

                if newTitle.isEmpty {
                    self.fetchNowPlayingViaAppleScript()
                    return
                }

                let titleChanged = newTitle != self.title
                self.title = newTitle
                self.artist = info[self.artistKey] as? String ?? ""
                self.album = info[self.albumKey] as? String ?? ""

                if let img = self.extractArtwork(from: info) {
                    self.artwork = img
                } else if titleChanged || self.artwork == nil {
                    self.fetchArtworkViaAppleScript()
                }

                if let elapsed = info[self.elapsedTimeKey] as? Double {
                    self.elapsedTimeBase = elapsed
                    self.elapsedTimestamp = Date()
                    self.elapsedTime = elapsed
                }
                if let dur = info[self.durationKey] as? Double {
                    self.duration = dur
                }

                self.isPlaying = true

                if titleChanged {
                    self.fetchLyrics()
                } else if self.lyrics.isEmpty && !self.title.isEmpty {
                    self.fetchLyrics()
                }
            }
        } else {
            fetchNowPlayingViaAppleScript()
        }

        _getIsPlaying?(DispatchQueue.main) { [weak self] playing in
            self?.isPlaying = playing
        }
    }

    // MARK: - Artwork

    private func extractArtwork(from info: [String: Any]) -> NSImage? {
        if let data = info[artworkKey] as? Data, !data.isEmpty,
           let img = NSImage(data: data) {
            return img
        }
        for (key, value) in info {
            let lk = key.lowercased()
            guard lk.contains("artwork") || lk.contains("image") else { continue }
            if let data = value as? Data, !data.isEmpty, let img = NSImage(data: data) {
                return img
            }
        }
        return nil
    }

    private func fetchArtwork() {
        if let getNowPlayingInfo = _getNowPlayingInfo {
            getNowPlayingInfo(DispatchQueue.main) { [weak self] info in
                guard let self = self else { return }
                if let img = self.extractArtwork(from: info) {
                    self.artwork = img
                } else {
                    self.fetchArtworkViaAppleScript()
                }
            }
        } else {
            fetchArtworkViaAppleScript()
        }
    }

    private func fetchArtworkViaAppleScript() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let musicRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.apple.Music"
            }
            if musicRunning {
                self?.fetchMusicArtwork()
                return
            }

            let spotifyRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.spotify.client"
            }
            if spotifyRunning {
                self?.fetchSpotifyArtwork()
            }
        }
    }

    private func fetchMusicArtwork() {
        let script = NSAppleScript(source: """
        tell application "Music"
            try
                if player state is playing or player state is paused then
                    set theTrack to current track
                    if (count of artworks of theTrack) > 0 then
                        return raw data of artwork 1 of theTrack
                    end if
                end if
            end try
        end tell
        """)
        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error) else { return }

        if let imgData = result.data, !imgData.isEmpty,
           let img = NSImage(data: imgData) {
            DispatchQueue.main.async { [weak self] in
                self?.artwork = img
            }
            return
        }

        let desc = result
        for i in 1...desc.numberOfItems {
            guard let sub = desc.atIndex(i), let d = sub.data, !d.isEmpty,
                  let img = NSImage(data: d) else { continue }
            DispatchQueue.main.async { [weak self] in
                self?.artwork = img
            }
            return
        }
    }

    private func fetchSpotifyArtwork() {
        let script = NSAppleScript(source: """
        tell application "Spotify"
            try
                if player state is playing or player state is paused then
                    return artwork url of current track
                end if
            end try
        end tell
        return ""
        """)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        let urlString = result?.stringValue ?? ""

        guard let url = URL(string: urlString) else { return }
        guard let data = try? Data(contentsOf: url),
              let img = NSImage(data: data) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.artwork = img
        }
    }

    // MARK: - AppleScript fallback for track info

    private func fetchNowPlayingViaAppleScript() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let musicRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.apple.Music"
            }

            if musicRunning {
                let musicScript = NSAppleScript(source: """
                tell application "Music"
                    try
                        if player state is playing or player state is paused then
                            set trackName to name of current track
                            set trackArtist to artist of current track
                            set trackAlbum to album of current track
                            set playState to "1"
                            if player state is paused then set playState to "0"
                            return trackName & "||" & trackArtist & "||" & trackAlbum & "||" & playState
                        end if
                    end try
                end tell
                return ""
                """)
                var error: NSDictionary?
                let result = musicScript?.executeAndReturnError(&error)
                let text = result?.stringValue ?? ""

                if !text.isEmpty {
                    self?.parseNowPlayingResult(text)
                    self?.fetchArtworkViaAppleScript()
                    return
                }
            }

            let spotifyRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.spotify.client"
            }
            guard spotifyRunning else { return }

            let spotifyScript = NSAppleScript(source: """
            tell application "Spotify"
                try
                    if player state is playing or player state is paused then
                        set trackName to name of current track
                        set trackArtist to artist of current track
                        set trackAlbum to album of current track
                        set playState to "1"
                        if player state is paused then set playState to "0"
                        return trackName & "||" & trackArtist & "||" & trackAlbum & "||" & playState
                    end if
                end try
            end tell
            return ""
            """)
            var error: NSDictionary?
            let spotResult = spotifyScript?.executeAndReturnError(&error)
            let spotText = spotResult?.stringValue ?? ""
            if !spotText.isEmpty {
                self?.parseNowPlayingResult(spotText)
                self?.fetchSpotifyArtwork()
            }
        }
    }

    private func parseNowPlayingResult(_ text: String) {
        let parts = text.components(separatedBy: "||")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let newTitle = parts.count > 0 ? parts[0] : ""
            let titleChanged = newTitle != self.title
            self.title = newTitle
            self.artist = parts.count > 1 ? parts[1] : ""
            self.album = parts.count > 2 ? parts[2] : ""
            self.isPlaying = parts.count > 3 ? parts[3] == "1" : false
            if titleChanged && !newTitle.isEmpty {
                self.fetchLyrics()
            }
        }
    }

    // MARK: - Lyrics

    private func fetchLyrics() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let musicRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.apple.Music"
            }
            guard musicRunning else {
                DispatchQueue.main.async {
                    self?.lyrics = ""
                    self?.timedLyrics = []
                }
                return
            }

            let script = NSAppleScript(source: """
            tell application "Music"
                try
                    if player state is playing or player state is paused then
                        set theLyrics to lyrics of current track
                        if theLyrics is not missing value and theLyrics is not "" then
                            return theLyrics
                        end if
                    end if
                end try
            end tell
            return ""
            """)
            var error: NSDictionary?
            let result = script?.executeAndReturnError(&error)
            let text = result?.stringValue ?? ""
            self?.parseLyrics(text)
        }
    }

    private func parseLyrics(_ text: String) {
        var timedLines: [TimedLyricLine] = []

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("["),
                  let closeBracket = trimmed.firstIndex(of: "]") else { continue }

            let tag = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
            let lyricText = String(trimmed[trimmed.index(after: closeBracket)...]).trimmingCharacters(in: .whitespaces)

            let parts = tag.components(separatedBy: ":")
            guard parts.count == 2, let minutes = Double(parts[0]) else { continue }

            let secParts = parts[1].components(separatedBy: ".")
            guard let seconds = Double(secParts[0]) else { continue }
            var frac = 0.0
            if secParts.count > 1, let fracVal = Double(secParts[1]) {
                frac = fracVal / pow(10.0, Double(secParts[1].count))
            }

            let timestamp = minutes * 60.0 + seconds + frac
            if !lyricText.isEmpty {
                timedLines.append(TimedLyricLine(timestamp: timestamp, text: lyricText))
            }
        }

        let sorted = timedLines.sorted { $0.timestamp < $1.timestamp }

        DispatchQueue.main.async { [weak self] in
            self?.lyrics = text
            self?.timedLyrics = sorted
        }
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            self.elapsedTime = self.elapsedTimeBase + Date().timeIntervalSince(self.elapsedTimestamp)
        }
    }
}
