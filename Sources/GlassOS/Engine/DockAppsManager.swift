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
    }

    func loadDockApps() {
        let dockPlistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist"
        guard let dict = NSDictionary(contentsOfFile: dockPlistPath),
              let persistentApps = dict["persistent-apps"] as? [[String: Any]] else {
            loadFromRunning()
            return
        }

        var result: [DockApp] = []
        for app in persistentApps {
            guard let tileData = app["tile-data"] as? [String: Any],
                  let fileData = tileData["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String else { continue }

            let cleaned = urlString.removingPercentEncoding ?? urlString
            let path: String
            if cleaned.hasPrefix("file://") {
                path = String(cleaned.dropFirst(7))
            } else {
                path = cleaned
            }

            guard FileManager.default.fileExists(atPath: path) else { continue }

            let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 64, height: 64)

            result.append(DockApp(id: path, name: name, icon: icon, path: path))
        }

        if result.isEmpty {
            loadFromRunning()
        } else {
            apps = result
        }
    }

    private func loadFromRunning() {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app -> DockApp? in
                guard let name = app.localizedName, let url = app.bundleURL else { return nil }
                let icon = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
                icon.size = NSSize(width: 64, height: 64)
                return DockApp(id: url.path, name: name, icon: icon, path: url.path)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        apps = running
    }

    func launch(_ app: DockApp) {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: app.path),
                                           configuration: NSWorkspace.OpenConfiguration())
    }
}
