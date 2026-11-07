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
    private var interpTimer: Timer?
    private var lastPollPosition: Double = 0
    private var lastPollTime: Date = Date()
    private var artworkCache: [String: NSImage] = [:]
    private var lastArtworkKey: String = ""
    private var fetchingArtwork = false

    private typealias MRSendCommand = @convention(c) (UInt32, UnsafeRawPointer?) -> Bool
    private var _sendCommand: MRSendCommand?
    private var mrHandle: UnsafeMutableRawPointer?

    private init() {
        loadMediaRemoteCommands()
        startPolling()
        startInterpolation()
    }

    // MARK: - Run AppleScript via osascript subprocess (thread-safe)

    private func runOsascript(_ source: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", source]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runCurl(_ url: String) -> Data? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        proc.arguments = ["-s", "-L", "--max-time", "10", url]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        guard proc.terminationStatus == 0 else { return nil }
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }

    private func isAppRunning(_ bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    // MARK: - MediaRemote (only for sending playback commands)

    private func loadMediaRemoteCommands() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else { return }
        mrHandle = handle
        if let ptr = dlsym(handle, "MRMediaRemoteSendCommand") {
            _sendCommand = unsafeBitCast(ptr, to: MRSendCommand.self)
        }
    }

    // MARK: - Polling + smooth interpolation

    private func startPolling() {
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func startInterpolation() {
        interpTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            let elapsed = self.lastPollPosition + Date().timeIntervalSince(self.lastPollTime)
            if self.duration > 0 && elapsed <= self.duration {
                self.elapsedTime = elapsed
            }
        }
    }

    private func poll() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if self.isAppRunning("com.apple.Music") {
                self.pollMusic()
            } else if self.isAppRunning("com.spotify.client") {
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
        let script = """
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
                set d to ASCII character 31
                return trackName & d & trackArtist & d & trackAlbum & d & playState & d & (pos as text) & d & (dur as text)
            end try
        end tell
        return ""
        """
        guard let text = runOsascript(script), !text.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.isPlaying = false
            }
            return
        }

        let sep = String(Character(UnicodeScalar(31)))
        let parts = text.components(separatedBy: sep)
        guard parts.count >= 6 else { return }

        let newTitle = parts[0]
        let newArtist = parts[1]
        let newAlbum = parts[2]
        let state = parts[3]
        let pos = Double(parts[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let dur = Double(parts[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let trackKey = "\(newTitle)|\(newArtist)|\(newAlbum)"
        let oldTitle = self.title
        let oldArtist = self.artist
        let titleChanged = newTitle != oldTitle || newArtist != oldArtist

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.title = newTitle
            self.artist = newArtist
            self.album = newAlbum
            self.isPlaying = (state == "playing")
            self.elapsedTime = pos
            self.duration = dur
            self.lastPollPosition = pos
            self.lastPollTime = Date()
        }

        if titleChanged && !newTitle.isEmpty {
            fetchArtworkForTrack(title: newTitle, artist: newArtist, album: newAlbum, trackKey: trackKey, provider: "music")
            fetchLyrics(title: newTitle, artist: newArtist)
            fetchNextUp()
        } else if self.artwork == nil && !newTitle.isEmpty && trackKey != lastArtworkKey {
            fetchArtworkForTrack(title: newTitle, artist: newArtist, album: newAlbum, trackKey: trackKey, provider: "music")
        }
    }

    private func pollSpotify() {
        let script = """
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
                set d to ASCII character 31
                return trackName & d & trackArtist & d & trackAlbum & d & playState & d & (pos as text) & d & (dur as text) & d & artURL
            end try
        end tell
        return ""
        """
        guard let text = runOsascript(script), !text.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.isPlaying = false
            }
            return
        }

        let sep = String(Character(UnicodeScalar(31)))
        let parts = text.components(separatedBy: sep)
        guard parts.count >= 6 else { return }

        let newTitle = parts[0]
        let newArtist = parts[1]
        let newAlbum = parts[2]
        let state = parts[3]
        let pos = Double(parts[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let dur = Double(parts[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let artURL = parts.count >= 7 ? parts[6] : ""

        let trackKey = "\(newTitle)|\(newArtist)|\(newAlbum)"
        let oldTitle = self.title
        let oldArtist = self.artist
        let titleChanged = newTitle != oldTitle || newArtist != oldArtist

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.title = newTitle
            self.artist = newArtist
            self.album = newAlbum
            self.isPlaying = (state == "playing")
            self.elapsedTime = pos
            self.duration = dur
            self.lastPollPosition = pos
            self.lastPollTime = Date()
            self.lyrics = ""
            self.timedLyrics = []
        }

        if titleChanged && !newTitle.isEmpty {
            fetchArtworkForTrack(title: newTitle, artist: newArtist, album: newAlbum, trackKey: trackKey, provider: "spotify", spotifyURL: artURL)
        } else if self.artwork == nil && !newTitle.isEmpty && trackKey != lastArtworkKey {
            fetchArtworkForTrack(title: newTitle, artist: newArtist, album: newAlbum, trackKey: trackKey, provider: "spotify", spotifyURL: artURL)
        }
    }

    // MARK: - Artwork

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

            // Spotify: direct CDN URL via curl
            if provider == "spotify", !spotifyURL.isEmpty {
                if let data = self?.runCurl(spotifyURL), !data.isEmpty,
                   let img = NSImage(data: data) {
                    image = img
                }
            }

            // iTunes Search API via curl
            if image == nil {
                image = self?.fetchArtworkViaiTunes(title: title, artist: artist)
            }

            // Last resort for Apple Music: write artwork to temp file via osascript
            if image == nil && provider == "music" {
                image = self?.fetchArtworkViaOsascriptFile()
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

    private func fetchArtworkViaiTunes(title: String, artist: String) -> NSImage? {
        let raw = "\(artist) \(title)"
        let query = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        let urlString = "https://itunes.apple.com/search?term=\(query)&entity=song&limit=5"

        guard let jsonData = runCurl(urlString), !jsonData.isEmpty else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let artURLString = first["artworkUrl100"] as? String else { return nil }

        let hiRes = artURLString.replacingOccurrences(of: "100x100bb", with: "512x512bb")
        guard let artData = runCurl(hiRes), !artData.isEmpty,
              let img = NSImage(data: artData) else { return nil }
        return img
    }

    private func fetchArtworkViaOsascriptFile() -> NSImage? {
        let tmpPath = "/tmp/glassos_artwork_\(ProcessInfo.processInfo.processIdentifier).png"
        let script = """
        tell application "Music"
            try
                set theTrack to current track
                if (count of artworks of theTrack) > 0 then
                    set artData to raw data of artwork 1 of theTrack
                    set f to open for access (POSIX file "\(tmpPath)") with write permission
                    set eof of f to 0
                    write artData to f
                    close access f
                    return "\(tmpPath)"
                end if
            on error
                try
                    close access (POSIX file "\(tmpPath)")
                end try
            end try
        end tell
        return ""
        """
        guard let result = runOsascript(script), !result.isEmpty else { return nil }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: tmpPath)),
              !data.isEmpty else { return nil }

        try? FileManager.default.removeItem(atPath: tmpPath)

        if let img = NSImage(data: data) {
            return img
        }

        // Raw artwork data might have a PICT/JFIF header offset — try skipping first few bytes
        for offset in [0, 2, 4, 6] where offset < data.count {
            let slice = data.subdata(in: offset..<data.count)
            if let img = NSImage(data: slice) {
                return img
            }
        }
        return nil
    }

    // MARK: - Lyrics

    private func fetchLyrics(title: String, artist: String) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Try embedded lyrics from Music.app first
            if self.isAppRunning("com.apple.Music") {
                let script = """
                tell application "Music"
                    try
                        set theLyrics to lyrics of current track
                        if theLyrics is not missing value and theLyrics is not "" then
                            return theLyrics
                        end if
                    end try
                end tell
                return ""
                """
                let text = self.runOsascript(script) ?? ""
                if !text.isEmpty {
                    self.parseLyrics(text)
                    return
                }
            }

            // Fallback: LRCLIB for synced lyrics
            self.fetchLyricsFromLRCLIB(title: title, artist: artist)
        }
    }

    private func fetchLyricsFromLRCLIB(title: String, artist: String) {
        let t = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let a = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://lrclib.net/api/get?track_name=\(t)&artist_name=\(a)"

        guard let data = runCurl(urlString), !data.isEmpty,
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
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let app = self?.isAppRunning("com.apple.Music") == true ? "Music" : "Spotify"
                _ = self?.runOsascript("tell application \"\(app)\" to playpause")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.poll()
        }
    }

    func nextTrack() {
        if let send = _sendCommand {
            _ = send(UInt32(4), nil)
        } else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let app = self?.isAppRunning("com.apple.Music") == true ? "Music" : "Spotify"
                _ = self?.runOsascript("tell application \"\(app)\" to next track")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.poll()
        }
    }

    func previousTrack() {
        if let send = _sendCommand {
            _ = send(UInt32(5), nil)
        } else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let app = self?.isAppRunning("com.apple.Music") == true ? "Music" : "Spotify"
                _ = self?.runOsascript("tell application \"\(app)\" to previous track")
            }
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

    // MARK: - Next Up Queue

    func fetchNextUp() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self, self.isAppRunning("com.apple.Music") else {
                DispatchQueue.main.async { self?.nextUp = [] }
                return
            }

            let script = """
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
            """
            let text = self.runOsascript(script) ?? ""

            var tracks: [NextUpTrack] = []
            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                let parts = line.components(separatedBy: "||")
                if parts.count >= 2 {
                    tracks.append(NextUpTrack(title: parts[0], artist: parts[1]))
                }
            }
            DispatchQueue.main.async { self.nextUp = tracks }
        }
    }
}
