import AppKit

struct DockApp: Identifiable {
    let id: String
    let name: String
    let icon: NSImage
    let path: String
}

class DockAppsManager: ObservableObject {
    static let shared = DockAppsManager()

    @Published var apps: [DockApp] = []

    private init() {
        loadDockApps()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appsChanged),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appsChanged),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil
        )
    }

    @objc private func appsChanged(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.loadDockApps()
        }
    }

    func loadDockApps() {
        var result: [DockApp] = []

        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        if let persistentApps = dockDefaults?.array(forKey: "persistent-apps") as? [[String: Any]] {
            for app in persistentApps {
                guard let tileData = app["tile-data"] as? [String: Any],
                      let fileData = tileData["file-data"] as? [String: Any],
                      let urlString = fileData["_CFURLString"] as? String else { continue }

                var path = urlString.removingPercentEncoding ?? urlString
                if path.hasPrefix("file://") { path = String(path.dropFirst(7)) }
                if path.hasSuffix("/") { path = String(path.dropLast()) }

                guard FileManager.default.fileExists(atPath: path) else { continue }

                let name = tileData["file-label"] as? String ??
                    (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 64, height: 64)
                result.append(DockApp(id: path, name: name, icon: icon, path: path))
            }
        }

        if result.isEmpty {
            result = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
                .compactMap { app -> DockApp? in
                    guard let name = app.localizedName, let url = app.bundleURL else { return nil }
                    let icon = app.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
                    icon.size = NSSize(width: 64, height: 64)
                    return DockApp(id: url.path, name: name, icon: icon, path: url.path)
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        apps = result
    }

    func launch(_ app: DockApp) {
        let url = URL(fileURLWithPath: app.path)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }
}
