import AppKit

struct WidgetLayout {
    let key: String
    let label: String
    let defaultNormX: CGFloat
    let defaultNormY: CGFloat
    let width: CGFloat
    let height: CGFloat
}

class WidgetLayoutManager: ObservableObject {
    static let shared = WidgetLayoutManager()

    static let widgetDefinitions: [WidgetLayout] = [
        WidgetLayout(key: "clock", label: "Clock", defaultNormX: 0.5, defaultNormY: 0.92, width: 440, height: 110),
        WidgetLayout(key: "nowPlaying", label: "Now Playing", defaultNormX: 0.85, defaultNormY: 0.7, width: 300, height: 360),
        WidgetLayout(key: "appLauncher", label: "App Launcher", defaultNormX: 0.85, defaultNormY: 0.42, width: 300, height: 140),
        WidgetLayout(key: "wallpaper", label: "Wallpapers", defaultNormX: 0.93, defaultNormY: 0.25, width: 170, height: 400),
        WidgetLayout(key: "fontChooser", label: "Fonts", defaultNormX: 0.82, defaultNormY: 0.25, width: 120, height: 400),
    ]

    func normalizedPosition(for key: String) -> CGPoint? {
        guard let d = UserDefaults.standard.dictionary(forKey: "widgetPos.\(key)"),
              let x = d["x"] as? CGFloat, let y = d["y"] as? CGFloat else { return nil }
        return CGPoint(x: x, y: y)
    }

    func defaultNormalizedPosition(for key: String) -> CGPoint {
        guard let def = Self.widgetDefinitions.first(where: { $0.key == key }) else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return CGPoint(x: def.defaultNormX, y: def.defaultNormY)
    }

    func widgetSize(for key: String) -> CGSize {
        if let d = UserDefaults.standard.dictionary(forKey: "widgetSize.\(key)"),
           let w = d["w"] as? CGFloat, let h = d["h"] as? CGFloat {
            return CGSize(width: w, height: h)
        }
        guard let def = Self.widgetDefinitions.first(where: { $0.key == key }) else {
            return CGSize(width: 200, height: 200)
        }
        return CGSize(width: def.width, height: def.height)
    }

    func saveSize(_ size: CGSize, for key: String) {
        UserDefaults.standard.set(["w": size.width, "h": size.height], forKey: "widgetSize.\(key)")
    }

    func savePosition(_ point: CGPoint, for key: String) {
        UserDefaults.standard.set(["x": point.x, "y": point.y], forKey: "widgetPos.\(key)")
    }

    func frame(for key: String, in screenFrame: NSRect) -> NSRect {
        let norm = normalizedPosition(for: key) ?? defaultNormalizedPosition(for: key)
        let size = widgetSize(for: key)
        let x = screenFrame.origin.x + norm.x * screenFrame.width - size.width / 2
        let y = screenFrame.origin.y + norm.y * screenFrame.height - size.height / 2
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    func resetAll() {
        for def in Self.widgetDefinitions {
            UserDefaults.standard.removeObject(forKey: "widgetPos.\(def.key)")
            UserDefaults.standard.removeObject(forKey: "widgetSize.\(def.key)")
        }
        NotificationCenter.default.post(name: .init("WidgetLayoutDidChange"), object: nil)
    }
}
