import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var mainWindow: NSWindow?
    var statusItem: NSStatusItem?
    var wallpaperEngine: WallpaperEngine?
    var hotkeyManager: GlobalHotkeyManager?
    var navigatorPanel: NSPanel?
    var desktopOverlayVisible = true

    var clockPanel: NSPanel?
    var nowPlayingPanel: NSPanel?
    var appLauncherPanel: NSPanel?
    var wallpaperPanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hideDock()
        setupMenuBar()
        setupDesktopOverlay()
        setupMainWindow()
        setupWallpaperEngine()
        setupGlobalHotkeys()

        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        restoreDock()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About GlassOS", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Check for Updates...", action: #selector(checkUpdates), keyEquivalent: "u")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit GlassOS", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Desktop Widgets", action: #selector(toggleDesktopOverlay), keyEquivalent: "d")
        viewMenu.addItem(withTitle: "Show Wallpaper Browser", action: #selector(showMainWindow), keyEquivalent: "b")
        viewMenu.addItem(withTitle: "Show Window Navigator", action: #selector(showNavigator), keyEquivalent: "")

        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: "GlassOS")
            button.action = #selector(statusBarClicked)
            button.target = self
        }

        let statusMenu = NSMenu()
        statusMenu.addItem(withTitle: "Toggle Desktop Widgets", action: #selector(toggleDesktopOverlay), keyEquivalent: "")
        statusMenu.addItem(withTitle: "Show Wallpaper Browser", action: #selector(showMainWindow), keyEquivalent: "")
        statusMenu.addItem(withTitle: "Window Navigator (F3)", action: #selector(showNavigator), keyEquivalent: "")
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(withTitle: "Check for Updates", action: #selector(checkUpdates), keyEquivalent: "")
        statusMenu.addItem(withTitle: "Settings", action: #selector(showSettings), keyEquivalent: "")
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem?.menu = statusMenu
    }

    private func setupMainWindow() {
        let contentView = MainContentView()
            .environmentObject(WallpaperManager.shared)
            .environmentObject(AutoUpdater.shared)

        mainWindow = GlassWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        mainWindow?.titlebarAppearsTransparent = true
        mainWindow?.titleVisibility = .hidden
        mainWindow?.isMovableByWindowBackground = true
        mainWindow?.backgroundColor = .clear
        mainWindow?.hasShadow = true
        mainWindow?.delegate = self
        mainWindow?.center()
        mainWindow?.setFrameAutosaveName("GlassOS.Main")
        let hostingView = NSHostingView(rootView: contentView)
        (mainWindow as? GlassWindow)?.setGlassContent(hostingView)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Desktop Overlay (separate panels per widget)

    private func setupDesktopOverlay() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.frame

        // One step below normal windows — macOS naturally layers app windows on top
        let widgetLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)

        // Clock — top center, non-interactive
        clockPanel = makeOverlayPanel(
            frame: NSRect(x: sf.midX - 220, y: sf.maxY - 130, width: 440, height: 110),
            level: widgetLevel
        )
        clockPanel?.ignoresMouseEvents = true
        clockPanel?.contentView = NSHostingView(rootView: ClockOverlayView())
        clockPanel?.orderFront(nil)

        // Now Playing — top left, interactive (wider for controls + next-up queue)
        nowPlayingPanel = makeOverlayPanel(
            frame: NSRect(x: sf.minX + 60, y: sf.maxY - 780, width: 340, height: 680),
            level: widgetLevel
        )
        nowPlayingPanel?.contentView = WidgetHostingView(rootView: NowPlayingOverlayView())
        nowPlayingPanel?.orderFront(nil)

        // App Launcher — center, interactive
        appLauncherPanel = makeOverlayPanel(
            frame: NSRect(x: sf.midX - 265, y: sf.midY - 200, width: 530, height: 400),
            level: widgetLevel
        )
        appLauncherPanel?.contentView = WidgetHostingView(rootView: AppLauncherOverlayView())
        appLauncherPanel?.orderFront(nil)

        // Wallpaper Carousel — right side, interactive
        let wpHeight = min(sf.height - 80, 620)
        wallpaperPanel = makeOverlayPanel(
            frame: NSRect(x: sf.maxX - 260, y: sf.midY - wpHeight / 2, width: 240, height: wpHeight),
            level: widgetLevel
        )
        wallpaperPanel?.contentView = WidgetHostingView(rootView: WallpaperCarouselOverlayView())
        wallpaperPanel?.orderFront(nil)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.repositionOverlayPanels()
        }

    }

    private func makeOverlayPanel(frame: NSRect, level: NSWindow.Level) -> NSPanel {
        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = level
        panel.collectionBehavior = [.stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // isFloatingPanel must be false so it doesn't override our level
        panel.isFloatingPanel = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        return panel
    }

    private func repositionOverlayPanels() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.frame
        clockPanel?.setFrame(NSRect(x: sf.midX - 220, y: sf.maxY - 130, width: 440, height: 110), display: true)
        nowPlayingPanel?.setFrame(NSRect(x: sf.minX + 60, y: sf.maxY - 780, width: 340, height: 680), display: true)
        appLauncherPanel?.setFrame(NSRect(x: sf.midX - 265, y: sf.midY - 200, width: 530, height: 400), display: true)
        let wpHeight = min(sf.height - 80, 620)
        wallpaperPanel?.setFrame(NSRect(x: sf.maxX - 260, y: sf.midY - wpHeight / 2, width: 240, height: wpHeight), display: true)
    }

    private var allOverlayPanels: [NSPanel?] {
        [clockPanel, nowPlayingPanel, appLauncherPanel, wallpaperPanel]
    }

    @objc func toggleDesktopOverlay() {
        if desktopOverlayVisible {
            allOverlayPanels.forEach { $0?.orderOut(nil) }
        } else {
            allOverlayPanels.forEach { $0?.orderFront(nil) }
        }
        desktopOverlayVisible.toggle()
    }

    // MARK: - Dock Hiding

    private func hideDock() {
        let cmds = [
            "defaults write com.apple.dock autohide -bool true",
            "defaults write com.apple.dock autohide-delay -float 1000",
            "defaults write com.apple.dock autohide-time-modifier -float 0",
            "killall Dock"
        ]
        for cmd in cmds {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", cmd]
            try? task.run()
            task.waitUntilExit()
        }
    }

    private func restoreDock() {
        let cmds = [
            "defaults delete com.apple.dock autohide-delay",
            "defaults delete com.apple.dock autohide-time-modifier",
            "defaults write com.apple.dock autohide -bool false",
            "killall Dock"
        ]
        for cmd in cmds {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", cmd]
            try? task.run()
            task.waitUntilExit()
        }
    }

    private func setupWallpaperEngine() {
        wallpaperEngine = WallpaperEngine()
    }

    private func setupGlobalHotkeys() {
        hotkeyManager = GlobalHotkeyManager { [weak self] in
            DispatchQueue.main.async {
                self?.toggleNavigator()
            }
        }
    }

    private func toggleNavigator() {
        if let panel = navigatorPanel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        showNavigatorPanel()
    }

    private func showNavigatorPanel() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        if navigatorPanel == nil {
            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            navigatorPanel = panel
        }

        let navigatorView = WindowNavigatorView {
            self.navigatorPanel?.orderOut(nil)
        }
        navigatorPanel?.contentView = NSHostingView(rootView: navigatorView)
        navigatorPanel?.setFrame(frame, display: true)
        navigatorPanel?.makeKeyAndOrderFront(nil)
    }

    @objc private func statusBarClicked() {
        showMainWindow()
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        (mainWindow as? GlassWindow)?.updateCornerRadius(fullscreen: true)
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        (mainWindow as? GlassWindow)?.updateCornerRadius(fullscreen: false)
    }

    @objc func showMainWindow() {
        if mainWindow == nil || !mainWindow!.isVisible {
            setupMainWindow()
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func showNavigator() {
        toggleNavigator()
    }

    @objc func showSettings() {
        let settingsView = SettingsView()
            .environmentObject(WallpaperManager.shared)
            .environmentObject(AutoUpdater.shared)

        let window = GlassWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.center()
        window.setGlassContent(NSHostingView(rootView: settingsView))
        window.makeKeyAndOrderFront(nil)
    }

    @objc func checkUpdates() {
        AutoUpdater.shared.checkForUpdates()
    }

    @objc func showAbout() {
        let aboutView = AboutView()
        let window = GlassWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.center()
        window.setGlassContent(NSHostingView(rootView: aboutView))
        window.makeKeyAndOrderFront(nil)
    }
}

class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
