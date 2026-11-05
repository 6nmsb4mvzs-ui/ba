import SwiftUI
import AppKit

enum WallpaperType: String, Codable {
    case video = "Video"
    case image = "Image"
    case gradient = "Gradient"
}

struct WallpaperItem: Identifiable, Codable {
    let id: String
    let name: String
    let type: WallpaperType
    let path: String?
    let gradientColors: [String]?

    var previewColors: [Color] {
        if let colors = gradientColors {
            return colors.map { Color(hex: $0) }
        }
        switch name.lowercased() {
        case let n where n.contains("night") || n.contains("city"):
            return [Color(hex: "#0a1628"), Color(hex: "#1a3a5c")]
        case let n where n.contains("mountain") || n.contains("snow"):
            return [Color(hex: "#2c3e50"), Color(hex: "#4ca1af")]
        case let n where n.contains("rain"):
            return [Color(hex: "#141e30"), Color(hex: "#243b55")]
        case let n where n.contains("forest") || n.contains("nature"):
            return [Color(hex: "#0f2027"), Color(hex: "#2c5364")]
        case let n where n.contains("sunset"):
            return [Color(hex: "#ee9ca7"), Color(hex: "#ffdde1")]
        case let n where n.contains("ocean") || n.contains("sea"):
            return [Color(hex: "#2193b0"), Color(hex: "#6dd5ed")]
        case let n where n.contains("neon") || n.contains("cyber"):
            return [Color(hex: "#0f0c29"), Color(hex: "#302b63"), Color(hex: "#24243e")]
        default:
            let hash = name.hashValue
            let hue = Double(abs(hash) % 360) / 360.0
            return [
                Color(hue: hue, saturation: 0.6, brightness: 0.3),
                Color(hue: (hue + 0.15).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 0.5)
            ]
        }
    }
}

class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()

    @Published var wallpapers: [WallpaperItem] = []
    @Published var currentWallpaper: WallpaperItem?
    @Published var wallpaperDirectory: URL

    private let engine = WallpaperEngine()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        wallpaperDirectory = appSupport.appendingPathComponent("GlassOS/Wallpapers")
        try? FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
        loadWallpapers()
    }

    func loadWallpapers() {
        var items: [WallpaperItem] = []

        // Built-in gradient wallpapers
        items.append(contentsOf: [
            WallpaperItem(id: "gradient-night-city", name: "Night City", type: .gradient, path: nil,
                         gradientColors: ["#0a0a2e", "#1a1a4e", "#0f3460"]),
            WallpaperItem(id: "gradient-cyber-rain", name: "Cyber Rain", type: .gradient, path: nil,
                         gradientColors: ["#141e30", "#243b55", "#1a3a5c"]),
            WallpaperItem(id: "gradient-snow-mountain", name: "Snow Mountain", type: .gradient, path: nil,
                         gradientColors: ["#2c3e50", "#4ca1af", "#bdc3c7"]),
            WallpaperItem(id: "gradient-deep-ocean", name: "Deep Ocean", type: .gradient, path: nil,
                         gradientColors: ["#000428", "#004e92"]),
            WallpaperItem(id: "gradient-forest-mist", name: "Forest Mist", type: .gradient, path: nil,
                         gradientColors: ["#0f2027", "#203a43", "#2c5364"]),
            WallpaperItem(id: "gradient-aurora", name: "Aurora", type: .gradient, path: nil,
                         gradientColors: ["#0f0c29", "#302b63", "#24243e"]),
            WallpaperItem(id: "gradient-twilight", name: "Twilight", type: .gradient, path: nil,
                         gradientColors: ["#1a0533", "#2d1b69", "#11998e"]),
            WallpaperItem(id: "gradient-midnight", name: "Midnight", type: .gradient, path: nil,
                         gradientColors: ["#000000", "#0a0a2e"]),
            WallpaperItem(id: "gradient-neon-pulse", name: "Neon Pulse", type: .gradient, path: nil,
                         gradientColors: ["#12c2e9", "#c471ed", "#f64f59"]),
            WallpaperItem(id: "gradient-dark-matter", name: "Dark Matter", type: .gradient, path: nil,
                         gradientColors: ["#0d0d0d", "#1a1a2e", "#16213e"]),
            WallpaperItem(id: "gradient-steel", name: "Steel", type: .gradient, path: nil,
                         gradientColors: ["#2c3e50", "#3498db"]),
            WallpaperItem(id: "gradient-ember", name: "Ember", type: .gradient, path: nil,
                         gradientColors: ["#1a0000", "#4a0000", "#8b0000"]),
        ])

        // Scan directory for user wallpapers
        if let enumerator = FileManager.default.enumerator(at: wallpaperDirectory, includingPropertiesForKeys: nil) {
            while let url = enumerator.nextObject() as? URL {
                let ext = url.pathExtension.lowercased()
                if ["mp4", "mov", "m4v", "webm"].contains(ext) {
                    items.append(WallpaperItem(
                        id: url.lastPathComponent,
                        name: url.deletingPathExtension().lastPathComponent,
                        type: .video,
                        path: url.path,
                        gradientColors: nil
                    ))
                } else if ["jpg", "jpeg", "png", "heic", "webp", "tiff"].contains(ext) {
                    items.append(WallpaperItem(
                        id: url.lastPathComponent,
                        name: url.deletingPathExtension().lastPathComponent,
                        type: .image,
                        path: url.path,
                        gradientColors: nil
                    ))
                }
            }
        }

        wallpapers = items
    }

    func applyWallpaper(_ wallpaper: WallpaperItem) {
        currentWallpaper = wallpaper

        switch wallpaper.type {
        case .video:
            guard let path = wallpaper.path else { return }
            engine.applyVideoWallpaper(url: URL(fileURLWithPath: path))
        case .image:
            guard let path = wallpaper.path else { return }
            engine.applyStaticWallpaper(url: URL(fileURLWithPath: path))
        case .gradient:
            guard let colorStrings = wallpaper.gradientColors else { return }
            let colors = colorStrings.map { NSColor(hex: $0) }
            engine.applyColorWallpaper(colors: colors)
        }

        UserDefaults.standard.set(wallpaper.id, forKey: "currentWallpaperID")
    }

    func addWallpaper(from url: URL) {
        let destination = wallpaperDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: destination)
        loadWallpapers()
    }

    func removeWallpaper() {
        engine.removeAllWallpapers()
        currentWallpaper = nil
        UserDefaults.standard.removeObject(forKey: "currentWallpaperID")
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: CGFloat
        switch hex.count {
        case 6:
            r = CGFloat((int >> 16) & 0xFF) / 255.0
            g = CGFloat((int >> 8) & 0xFF) / 255.0
            b = CGFloat(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
