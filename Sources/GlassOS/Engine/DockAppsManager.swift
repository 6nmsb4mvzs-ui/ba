import AppKit
import SwiftUI

struct DockApp: Identifiable {
    let id: String
    let name: String
    let symbolName: String
    let bundleID: String
}

class DockAppsManager: ObservableObject {
    static let shared = DockAppsManager()

    @Published var apps: [DockApp] = []

    private static let pinnedApps: [(String, String, String)] = [
        ("Music",     "music.note",                   "com.apple.Music"),
        ("Chrome",    "globe",                        "com.google.Chrome"),
        ("Settings",  "gearshape",                    "com.apple.systempreferences"),
        ("Discord",   "bubble.left.and.bubble.right", "com.hnc.Discord"),
        ("Soundgrab", "waveform",                     "com.soundgrab.Soundgrab"),
        ("PG3D",      "gamecontroller",               "com.pixel.gun3d"),
        ("Modrinth App", "shippingbox",               "ModrinthApp"),
        ("GlassOS",   "sparkles.rectangle.stack",     Bundle.main.bundleIdentifier ?? "com.glassos.app"),
    ]

    private init() {
        apps = Self.pinnedApps.map {
            DockApp(id: $0.2, name: $0.0, symbolName: $0.1, bundleID: $0.2)
        }
    }

    func launch(_ app: DockApp) {
        if app.bundleID == (Bundle.main.bundleIdentifier ?? "com.glassos.app") {
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showMainWindow()
            }
            return
        }

        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleID }) {
            running.activate(options: .activateIgnoringOtherApps)
            return
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) {
            openApp(at: url)
            return
        }

        for dir in ["/Applications", NSHomeDirectory() + "/Applications"] {
            let exactPath = "\(dir)/\(app.name).app"
            if FileManager.default.fileExists(atPath: exactPath) {
                openApp(at: URL(fileURLWithPath: exactPath))
                return
            }

            if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                let lowerName = app.name.lowercased().replacingOccurrences(of: " ", with: "")
                for item in contents where item.hasSuffix(".app") {
                    let itemLower = item.replacingOccurrences(of: ".app", with: "").lowercased().replacingOccurrences(of: " ", with: "")
                    if itemLower.contains(lowerName) || lowerName.contains(itemLower) {
                        openApp(at: URL(fileURLWithPath: "\(dir)/\(item)"))
                        return
                    }
                }
            }
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", app.name]
        try? proc.run()
    }

    private func openApp(at url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
    }

    static func adaptiveColor(for wallpaper: WallpaperItem?) -> Color {
        guard let colors = wallpaper?.gradientColors, let first = colors.first else {
            return .white.opacity(0.7)
        }
        let (r, g, b) = hexToRGB(first)
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b

        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        var hue: Double = 0
        if delta > 0.001 {
            if maxC == r { hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == g { hue = (b - r) / delta + 2 }
            else { hue = (r - g) / delta + 4 }
            hue /= 6; if hue < 0 { hue += 1 }
        }
        let sat = maxC > 0 ? delta / maxC : 0

        if brightness < 0.3 {
            return Color(hue: hue, saturation: min(sat * 0.6, 0.35), brightness: 0.85)
        } else {
            return Color(hue: hue, saturation: min(sat * 0.8, 0.5), brightness: 0.2)
        }
    }

    private static func hexToRGB(_ hex: String) -> (Double, Double, Double) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        return (Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0)
    }
}
