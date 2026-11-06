import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var mainWindow: NSWindow?
    var desktopWindow: NSWindow?
    var statusItem: NSStatusItem?
    var wallpaperEngine: WallpaperEngine?
    var hotkeyManager: GlobalHotkeyManager?
    var navigatorPanel: NSPanel?
    var desktopOverlayVisible = true

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

    private func setupDesktopOverlay() {
        guard let screen = NSScreen.main else { return }

        let panel = OverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true

        let overlayView = DesktopOverlayView()
        let hostingView = ClickThroughHostingView(rootView: overlayView)
        panel.contentView = hostingView

        panel.orderFront(nil)
        desktopWindow = panel

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            if let screen = NSScreen.main {
                self?.desktopWindow?.setFrame(screen.frame, display: true)
            }
        }
    }

    @objc func toggleDesktopOverlay() {
        if desktopOverlayVisible {
            desktopWindow?.orderOut(nil)
        } else {
            desktopWindow?.orderFront(nil)
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
