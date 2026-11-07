import AppKit
import Combine

struct TimedLyricLine: Identifiable {
    let id = UUID()
    let timestamp: Double
    let text: String
}

struct NextUpTrack: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
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
    @Published var shuffleOn: Bool = false
    @Published var repeatMode: Int = 0
    @Published var nextUp: [NextUpTrack] = []

    private var pollTimer: Timer?
    private var artworkCache: [String: NSImage] = [:]
    private var lastArtworkKey: String = ""
    private var fetchingArtwork = false

    private typealias MRSendCommand = @convention(c) (UInt32, UnsafeRawPointer?) -> Bool
    private var _sendCommand: MRSendCommand?
    private var mrHandle: UnsafeMutableRawPointer?

    private init() {
        loadMediaRemoteCommands()
        startPolling()
    }

    // MARK: - MediaRemote (only for sending playback commands)

    private func loadMediaRemoteCommands() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else { return }
        mrHandle = handle
        if let ptr = dlsym(handle, "MRMediaRemoteSendCommand") {
            _sendCommand = unsafeBitCast(ptr, to: MRSendCommand.self)
        }
    }

    // MARK: - Single polling loop (the only source of truth)

    private func startPolling() {
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let musicRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.apple.Music"
            }
            let spotifyRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.spotify.client"
            }

            if musicRunning {
                self.pollMusic()
            } else if spotifyRunning {
                self.pollSpotify()
            } else {
                DispatchQueue.main.async {
                    self.title = ""
                    self.artist = ""
                    self.album = ""
                    self.isPlaying = false
                    self.elapsedTime = 0
                    self.duration = 0
                    self.artwork = nil
                }
            }
        }
    }

    private func pollMusic() {
        let src = """
        tell application "Music"
            try
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set playState to "playing"
                if player state is paused then set playState to "paused"
                if player state is stopped then set playState to "stopped"
                set pos to player position
                set dur to duration of current track
                set sep to "<<SEP>>"
                return trackName & sep & trackArtist & sep & trackAlbum & sep & playState & sep & (pos as text) & sep & (dur as text)
            end try
        end tell
        return ""
        """
        let script = NSAppleScript(source: src)
        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error),
              let text = result.stringValue, !text.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.isPlaying = false
            }
            return
        }

        let parts = text.components(separatedBy: "<<SEP>>")
        guard parts.count >= 6 else { return }

        let newTitle = parts[0]
        let newArtist = parts[1]
        let newAlbum = parts[2]
        let state = parts[3]
        let pos = Double(parts[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let dur = Double(parts[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let trackKey = "\(newTitle)|\(newArtist)|\(newAlbum)"
        let titleChanged = newTitle != self.title || newArtist != self.artist

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.title = newTitle
            self.artist = newArtist
            self.album = newAlbum
            self.isPlaying = (state == "playing")
            self.elapsedTime = pos
            self.duration = dur
        }

        if titleChanged && !newTitle.isEmpty {
            fetchArtworkForTrack(title: newTitle, artist: newArtist, album: newAlbum, trackKey: trackKey, provider: "music")
            fetchLyrics()
            fetchNextUp()
        } else if self.artwork == nil && !newTitle.isEmpty && trackKey != lastArtworkKey {
            fetchArtworkForTrack(title: newTitle, artist: newArtist, album: newAlbum, trackKey: trackKey, provider: "music")
        }
    }

    private func pollSpotify() {
        let src = """
        tell application "Spotify"
            try
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set playState to "playing"
                if player state is paused then set playState to "paused"
                set pos to player position
                set dur to (duration of current track) / 1000
                set artURL to artwork url of current track
                set sep to "<<SEP>>"
                return trackName & sep & trackArtist & sep & trackAlbum & sep & playState & sep & (pos as text) & sep & (dur as text) & sep & artURL
            end try
        end tell
        return ""
        """
        let script = NSAppleScript(source: src)
        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error),
              let text = result.stringValue, !text.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.isPlaying = false
            }
            return
        }

        let parts = text.components(separatedBy: "<<SEP>>")
        guard parts.count >= 6 else { return }

        let newTitle = parts[0]
        let newArtist = parts[1]
        let newAlbum = parts[2]
        let state = parts[3]
        let pos = Double(parts[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let dur = Double(parts[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let artURL = parts.count >= 7 ? parts[6] : ""

        let trackKey = "\(newTitle)|\(newArtist)|\(newAlbum)"
        let titleChanged = newTitle != self.title || newArtist != self.artist

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.title = newTitle
            self.artist = newArtist
            self.album = newAlbum
            self.isPlaying = (state == "playing")
            self.elapsedTime = pos
            self.duration = dur
            self.lyrics = ""
            self.timedLyrics = []
        }

        if titleChanged && !newTitle.isEmpty {
            fetchArtworkForTrack(title: newTitle, artist: newArtist, album: newAlbum, trackKey: trackKey, provider: "spotify", spotifyURL: artURL)
        } else if self.artwork == nil && !newTitle.isEmpty && trackKey != lastArtworkKey {
            fetchArtworkForTrack(title: newTitle, artist: newArtist, album: newAlbum, trackKey: trackKey, provider: "spotify", spotifyURL: artURL)
        }
    }

    // MARK: - Artwork (iTunes Search API for Apple Music, direct URL for Spotify)

    private func fetchArtworkForTrack(title: String, artist: String, album: String, trackKey: String, provider: String, spotifyURL: String = "") {
        if let cached = artworkCache[trackKey] {
            lastArtworkKey = trackKey
            DispatchQueue.main.async { [weak self] in self?.artwork = cached }
            return
        }

        guard !fetchingArtwork else { return }
        fetchingArtwork = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            defer { self?.fetchingArtwork = false }

            var image: NSImage?

            if provider == "spotify", !spotifyURL.isEmpty,
               let url = URL(string: spotifyURL),
               let data = try? Data(contentsOf: url),
               let img = NSImage(data: data) {
                image = img
            }

            if image == nil {
                image = self?.fetchArtworkFromiTunesAPI(title: title, artist: artist)
            }

            guard let finalImage = image else { return }

            self?.artworkCache[trackKey] = finalImage
            if self?.artworkCache.count ?? 0 > 50 {
                self?.artworkCache.removeAll()
                self?.artworkCache[trackKey] = finalImage
            }

            self?.lastArtworkKey = trackKey
            DispatchQueue.main.async { [weak self] in
                self?.artwork = finalImage
            }
        }
    }

    private func fetchArtworkFromiTunesAPI(title: String, artist: String) -> NSImage? {
        let query = "\(artist) \(title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(query)&entity=song&limit=5"
        guard let url = URL(string: urlString) else { return nil }

        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let artURLString = first["artworkUrl100"] as? String else { return nil }

        let hiRes = artURLString.replacingOccurrences(of: "100x100bb", with: "512x512bb")
        guard let artURL = URL(string: hiRes),
              let artData = try? Data(contentsOf: artURL),
              let img = NSImage(data: artData) else { return nil }

        return img
    }

    // MARK: - Lyrics

    private func fetchLyrics() {
        let currentTitle = self.title
        let currentArtist = self.artist

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
                    set theLyrics to lyrics of current track
                    if theLyrics is not missing value and theLyrics is not "" then
                        return theLyrics
                    end if
                end try
            end tell
            return ""
            """)
            var error: NSDictionary?
            let result = script?.executeAndReturnError(&error)
            let text = result?.stringValue ?? ""

            if text.isEmpty {
                self?.fetchLyricsFromLRCLIB(title: currentTitle, artist: currentArtist)
            } else {
                self?.parseLyrics(text)
            }
        }
    }

    private func fetchLyricsFromLRCLIB(title: String, artist: String) {
        let t = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let a = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://lrclib.net/api/get?track_name=\(t)&artist_name=\(a)"
        guard let url = URL(string: urlString),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            DispatchQueue.main.async { [weak self] in
                self?.lyrics = ""
                self?.timedLyrics = []
            }
            return
        }

        if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
            parseLyrics(synced)
        } else if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.lyrics = plain
                self?.timedLyrics = []
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.lyrics = ""
                self?.timedLyrics = []
            }
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

            let tagParts = tag.components(separatedBy: ":")
            guard tagParts.count == 2, let minutes = Double(tagParts[0]) else { continue }

            let secParts = tagParts[1].components(separatedBy: ".")
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

    // MARK: - Playback Controls

    func togglePlayPause() {
        if let send = _sendCommand {
            _ = send(UInt32(2), nil)
        } else {
            sendAppleScriptCommand("playpause")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.poll()
        }
    }

    func nextTrack() {
        if let send = _sendCommand {
            _ = send(UInt32(4), nil)
        } else {
            sendAppleScriptCommand("next track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.poll()
        }
    }

    func previousTrack() {
        if let send = _sendCommand {
            _ = send(UInt32(5), nil)
        } else {
            sendAppleScriptCommand("previous track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.poll()
        }
    }

    func toggleShuffle() {
        if let send = _sendCommand { _ = send(UInt32(6), nil) }
        shuffleOn.toggle()
    }

    func toggleRepeat() {
        if let send = _sendCommand { _ = send(UInt32(7), nil) }
        repeatMode = (repeatMode + 1) % 3
    }

    private func sendAppleScriptCommand(_ command: String) {
        let musicRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Music"
        }
        let app = musicRunning ? "Music" : "Spotify"
        let script = NSAppleScript(source: "tell application \"\(app)\" to \(command)")
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
    }

    // MARK: - Next Up Queue

    func fetchNextUp() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let musicRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.apple.Music"
            }
            guard musicRunning else {
                DispatchQueue.main.async { self?.nextUp = [] }
                return
            }

            let script = NSAppleScript(source: """
            tell application "Music"
                try
                    set output to ""
                    set idx to index of current track
                    set pl to current playlist
                    set totalTracks to count of tracks of pl
                    set maxNext to idx + 5
                    if maxNext > totalTracks then set maxNext to totalTracks
                    repeat with i from (idx + 1) to maxNext
                        set t to track i of pl
                        set output to output & name of t & "||" & artist of t & return
                    end repeat
                    return output
                end try
            end tell
            return ""
            """)
            var error: NSDictionary?
            let result = script?.executeAndReturnError(&error)
            let text = result?.stringValue ?? ""

            var tracks: [NextUpTrack] = []
            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                let parts = line.components(separatedBy: "||")
                if parts.count >= 2 {
                    tracks.append(NextUpTrack(title: parts[0], artist: parts[1]))
                }
            }
            DispatchQueue.main.async { self?.nextUp = tracks }
        }
    }
}
