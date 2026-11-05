import AppKit
import AVFoundation
import AVKit

class WallpaperEngine {
    private var wallpaperWindows: [NSScreen: NSWindow] = [:]
    private var players: [NSScreen: AVPlayer] = [:]
    private var currentWallpaper: WallpaperItem?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applyVideoWallpaper(url: URL, to screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first!
        removeWallpaper(from: targetScreen)

        let window = NSWindow(
            contentRect: targetScreen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none

        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.videoGravity = .resizeAspectFill
        playerView.frame = window.contentView!.bounds
        playerView.autoresizingMask = [.width, .height]

        window.contentView?.addSubview(playerView)
        window.setFrame(targetScreen.frame, display: true)
        window.orderFront(nil)

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()

        wallpaperWindows[targetScreen] = window
        players[targetScreen] = player
    }

    func applyStaticWallpaper(url: URL, to screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first!
        removeWallpaper(from: targetScreen)

        do {
            try NSWorkspace.shared.setDesktopImageURL(url, for: targetScreen)
        } catch {
            print("Failed to set wallpaper: \(error)")
        }
    }

    func applyColorWallpaper(colors: [NSColor], to screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first!
        removeWallpaper(from: targetScreen)

        let window = NSWindow(
            contentRect: targetScreen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.isOpaque = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = targetScreen.frame

        let view = NSView(frame: targetScreen.frame)
        view.wantsLayer = true
        view.layer = gradientLayer

        window.contentView = view
        window.setFrame(targetScreen.frame, display: true)
        window.orderFront(nil)

        wallpaperWindows[targetScreen] = window
    }

    func removeWallpaper(from screen: NSScreen) {
        players[screen]?.pause()
        players[screen] = nil
        wallpaperWindows[screen]?.orderOut(nil)
        wallpaperWindows[screen] = nil
    }

    func removeAllWallpapers() {
        for screen in NSScreen.screens {
            removeWallpaper(from: screen)
        }
    }

    @objc private func screensChanged() {
        if let wallpaper = currentWallpaper {
            WallpaperManager.shared.applyWallpaper(wallpaper)
        }
    }
}
