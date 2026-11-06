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

    private var _getNowPlayingInfo: MRInfoCallback?
    private var _getIsPlaying: MRStateCallback?

    private init() {
        loadMediaRemote()
        startPolling()
    }

    private func loadMediaRemote() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework" as CFString
        guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path, .cfurlposixPathStyle, true),
              let bundle = CFBundleCreate(kCFAllocatorDefault, url) else { return }
        mrBundle = bundle

        if CFBundleLoadExecutable(bundle) {
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
                _getNowPlayingInfo = unsafeBitCast(ptr, to: MRInfoCallback.self)
            }
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString) {
                _getIsPlaying = unsafeBitCast(ptr, to: MRStateCallback.self)
            }
        }

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(mediaChanged),
            name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(mediaChanged),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil
        )
    }

    private func startPolling() {
        fetchNowPlaying()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchNowPlaying()
        }
    }

    @objc private func mediaChanged(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    func fetchNowPlaying() {
        if let getNowPlayingInfo = _getNowPlayingInfo {
            getNowPlayingInfo(DispatchQueue.main) { [weak self] info in
                guard let self = self else { return }
                let newTitle = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""

                if newTitle.isEmpty {
                    self.fetchNowPlayingViaAppleScript()
                    return
                }

                let titleChanged = newTitle != self.title
                self.title = newTitle
                self.artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                self.album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""

                if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data,
                   let img = NSImage(data: data) {
                    self.artwork = img
                }

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

    private func fetchNowPlayingViaAppleScript() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Try Music.app
            let musicScript = NSAppleScript(source: """
            tell application "System Events"
                if not (exists (processes where name is "Music")) then return ""
            end tell
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

            // Only try Spotify if it is actually running (avoids "find application" dialog)
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
            let script = NSAppleScript(source: """
            tell application "System Events"
                set musicRunning to (exists (processes where name is "Music"))
            end tell
            if musicRunning then
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
            end if
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
