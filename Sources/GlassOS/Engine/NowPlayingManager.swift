import AppKit
import Combine

class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()

    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var lyrics: String = ""

    private var timer: Timer?
    private var mrBundle: CFBundle?

    private typealias MRInfoCallback = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRStateCallback = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias MRRegisterNotifs = @convention(c) (DispatchQueue) -> Void

    private var _getNowPlayingInfo: MRInfoCallback?
    private var _getIsPlaying: MRStateCallback?

    private var titleKey = "kMRMediaRemoteNowPlayingInfoTitle"
    private var artistKey = "kMRMediaRemoteNowPlayingInfoArtist"
    private var albumKey = "kMRMediaRemoteNowPlayingInfoAlbum"
    private var artworkKey = "kMRMediaRemoteNowPlayingInfoArtworkData"

    private init() {
        loadMediaRemote()
        setupDistributedNotifications()
        startPolling()
    }

    // MARK: - Distributed Notifications (primary — no permissions needed)

    private func setupDistributedNotifications() {
        let dnc = DistributedNotificationCenter.default()

        dnc.addObserver(
            self, selector: #selector(musicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil
        )
        dnc.addObserver(
            self, selector: #selector(spotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil
        )
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

            if titleChanged {
                self.fetchArtwork()
            }
            self.lyrics = ""
        }
    }

    // MARK: - MediaRemote (fallback for initial state and artwork)

    private func loadMediaRemote() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework" as CFString
        guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path, .cfurlposixPathStyle, true),
              let bundle = CFBundleCreate(kCFAllocatorDefault, url) else { return }
        mrBundle = bundle

        guard CFBundleLoadExecutable(bundle) else { return }

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            _getNowPlayingInfo = unsafeBitCast(ptr, to: MRInfoCallback.self)
        }
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString) {
            _getIsPlaying = unsafeBitCast(ptr, to: MRStateCallback.self)
        }

        loadKeyString(bundle, symbol: "kMRMediaRemoteNowPlayingInfoTitle", into: &titleKey)
        loadKeyString(bundle, symbol: "kMRMediaRemoteNowPlayingInfoArtist", into: &artistKey)
        loadKeyString(bundle, symbol: "kMRMediaRemoteNowPlayingInfoAlbum", into: &albumKey)
        loadKeyString(bundle, symbol: "kMRMediaRemoteNowPlayingInfoArtworkData", into: &artworkKey)

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) {
            let register = unsafeBitCast(ptr, to: MRRegisterNotifs.self)
            register(DispatchQueue.main)
        }
    }

    private func loadKeyString(_ bundle: CFBundle, symbol: String, into target: inout String) {
        guard let ptr = CFBundleGetDataPointerForName(bundle, symbol as CFString) else { return }
        guard let rawValue = ptr.load(as: UnsafeRawPointer?.self) else { return }
        target = Unmanaged<NSString>.fromOpaque(rawValue).takeUnretainedValue() as String
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

                if let data = info[self.artworkKey] as? Data,
                   let img = NSImage(data: data) {
                    self.artwork = img
                }

                self.isPlaying = true

                if titleChanged {
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

    // MARK: - Artwork via MediaRemote

    private func fetchArtwork() {
        guard let getNowPlayingInfo = _getNowPlayingInfo else { return }
        getNowPlayingInfo(DispatchQueue.main) { [weak self] info in
            guard let self = self else { return }
            if let data = info[self.artworkKey] as? Data,
               let img = NSImage(data: data) {
                self.artwork = img
            }
        }
    }

    // MARK: - AppleScript fallback

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

    private func fetchLyrics() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let musicRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.apple.Music"
            }
            guard musicRunning else {
                DispatchQueue.main.async { self?.lyrics = "" }
                return
            }

            let script = NSAppleScript(source: """
            tell application "Music"
                try
                    if player state is playing or player state is paused then
                        set theLyrics to lyrics of current track
                        if theLyrics is not missing value then
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
            DispatchQueue.main.async {
                self?.lyrics = text
            }
        }
    }
}
