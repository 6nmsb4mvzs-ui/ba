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

    private var overlapTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
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

    // MARK: - Desktop Overlay (separate floating panels per widget)

    private func setupDesktopOverlay() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.frame

        // Floating level so nonactivatingPanel receives mouse events
        let widgetLevel = NSWindow.Level.floating

        // Clock — top center, non-interactive
        clockPanel = makeOverlayPanel(
            frame: NSRect(x: sf.midX - 220, y: sf.maxY - 130, width: 440, height: 110),
            level: widgetLevel
        )
        clockPanel?.ignoresMouseEvents = true
        clockPanel?.contentView = NSHostingView(rootView: ClockOverlayView())
        clockPanel?.orderFront(nil)

        // Now Playing — top left, interactive
        nowPlayingPanel = makeOverlayPanel(
            frame: NSRect(x: sf.minX + 24, y: sf.maxY - 520, width: 310, height: 400),
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

        startOverlapDetection()
    }

    private func makeOverlayPanel(frame: NSRect, level: NSWindow.Level) -> NSPanel {
        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = level
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        return panel
    }

    // MARK: - Per-Widget Overlap Detection

    private func startOverlapDetection() {
        overlapTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateWidgetVisibility()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.updateWidgetVisibility()
            }
        }
    }

    private func updateWidgetVisibility() {
        guard desktopOverlayVisible else { return }
        guard let screen = NSScreen.main else { return }

        let myPID = ProcessInfo.processInfo.processIdentifier
        let screenHeight = screen.frame.height

        // Get all on-screen windows from other apps at normal level or above
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        let appWindowRects: [CGRect] = windowList.compactMap { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  pid != myPID,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer >= 0 && layer < 3, // normal windows only, not floating/menu
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let w = bounds["Width"], let h = bounds["Height"],
                  w > 50, h > 50 // ignore tiny windows (tooltips, etc.)
            else { return nil }
            // CG coords (top-left origin) — keep as-is for comparison
            return CGRect(x: x, y: y, width: w, height: h)
        }

        for panel in [clockPanel, nowPlayingPanel, appLauncherPanel, wallpaperPanel] {
            guard let panel = panel else { continue }
            let nsFrame = panel.frame
            // Convert NS coords (bottom-left) to CG coords (top-left)
            let cgFrame = CGRect(
                x: nsFrame.origin.x,
                y: screenHeight - nsFrame.origin.y - nsFrame.height,
                width: nsFrame.width,
                height: nsFrame.height
            )

            let isOverlapped = appWindowRects.contains { windowRect in
                let intersection = cgFrame.intersection(windowRect)
                guard !intersection.isNull else { return false }
                let overlapArea = intersection.width * intersection.height
                let panelArea = cgFrame.width * cgFrame.height
                return panelArea > 0 && (overlapArea / panelArea) > 0.25
            }

            let targetAlpha: CGFloat = isOverlapped ? 0.0 : 1.0
            if abs(panel.alphaValue - targetAlpha) > 0.01 {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    panel.animator().alphaValue = targetAlpha
                }
            }
        }
    }

    private func repositionOverlayPanels() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.frame
        clockPanel?.setFrame(NSRect(x: sf.midX - 220, y: sf.maxY - 130, width: 440, height: 110), display: true)
        nowPlayingPanel?.setFrame(NSRect(x: sf.minX + 24, y: sf.maxY - 520, width: 310, height: 400), display: true)
        appLauncherPanel?.setFrame(NSRect(x: sf.midX - 265, y: sf.midY - 200, width: 530, height: 400), display: true)
        let wpHeight = min(sf.height - 80, 620)
        wallpaperPanel?.setFrame(NSRect(x: sf.maxX - 260, y: sf.midY - wpHeight / 2, width: 240, height: wpHeight), display: true)
    }

    private var allOverlayPanels: [NSPanel?] {
        [clockPanel, nowPlayingPanel, appLauncherPanel, wallpaperPanel]
    }

    @objc func toggleDesktopOverlay() {
        if desktopOverlayVisible {
            overlapTimer?.invalidate()
            overlapTimer = nil
            allOverlayPanels.forEach { $0?.orderOut(nil) }
        } else {
            allOverlayPanels.forEach {
                $0?.alphaValue = 1.0
                $0?.orderFront(nil)
            }
            startOverlapDetection()
        }
        desktopOverlayVisible.toggle()
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
