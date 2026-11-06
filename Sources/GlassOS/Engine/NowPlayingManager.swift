import AppKit

class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()

    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var lyrics: String = ""
    @Published var playerPosition: Double = 0
    @Published var duration: Double = 0

    private var timer: Timer?

    private typealias MRNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRNowPlayingStateFunction = @convention(c) (DispatchQueue, @escaping (Int) -> Void) -> Void
    private var getNowPlayingInfo: MRNowPlayingInfoFunction?
    private var getNowPlayingState: MRNowPlayingStateFunction?

    private init() {
        loadMediaRemote()
        startPolling()
    }

    private func loadMediaRemote() {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")) else { return }

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            getNowPlayingInfo = unsafeBitCast(ptr, to: MRNowPlayingInfoFunction.self)
        }

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString) {
            getNowPlayingState = unsafeBitCast(ptr, to: MRNowPlayingStateFunction.self)
        }

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(nowPlayingChanged),
            name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil
        )
    }

    private func startPolling() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    @objc private func nowPlayingChanged(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.update()
        }
    }

    func update() {
        getNowPlayingInfo?(DispatchQueue.main) { [weak self] info in
            let newTitle = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let newArtist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let titleChanged = newTitle != self?.title

            self?.title = newTitle
            self?.artist = newArtist
            self?.album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            self?.duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            self?.playerPosition = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0

            if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                self?.artwork = NSImage(data: artworkData)
            }

            if titleChanged && !newTitle.isEmpty {
                self?.fetchLyrics()
            }
        }

        getNowPlayingState?(DispatchQueue.main) { [weak self] state in
            self?.isPlaying = state == 1
        }
    }

    private func fetchLyrics() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let script = NSAppleScript(source: """
                tell application "System Events"
                    if exists (processes where name is "Music") then
                        tell application "Music"
                            if player state is playing then
                                try
                                    return lyrics of current track
                                end try
                            end if
                        end tell
                    end if
                end tell
                return ""
            """)
            var error: NSDictionary?
            let result = script?.executeAndReturnError(&error)
            let lyricsText = result?.stringValue ?? ""
            DispatchQueue.main.async {
                self?.lyrics = lyricsText
            }
        }
    }
}
