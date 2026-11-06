import SwiftUI
import AppKit

enum WallpaperType: String, Codable {
    case video = "Video"
    case image = "Image"
    case gradient = "Gradient"
    case remote = "Remote"
}

struct WallpaperItem: Identifiable, Codable {
    let id: String
    let name: String
    let type: WallpaperType
    let path: String?
    let remoteURL: String?
    let gradientColors: [String]?
    let category: String?

    var previewColors: [Color] {
        if let colors = gradientColors {
            return colors.map { Color(hex: $0) }
        }
        switch (category ?? "").lowercased() {
        case "city":
            let hash = abs(name.hashValue)
            let variant = hash % 4
            switch variant {
            case 0: return [Color(hex: "#0a0a2e"), Color(hex: "#1a5276")]
            case 1: return [Color(hex: "#0d0221"), Color(hex: "#0abdc6")]
            case 2: return [Color(hex: "#1a0033"), Color(hex: "#e91e63")]
            default: return [Color(hex: "#0a1628"), Color(hex: "#6c3483")]
            }
        case "landscape":
            let hash = abs(name.hashValue)
            let variant = hash % 4
            switch variant {
            case 0: return [Color(hex: "#0f2027"), Color(hex: "#2c5364")]
            case 1: return [Color(hex: "#1a2a0a"), Color(hex: "#6b8e23")]
            case 2: return [Color(hex: "#1a1a2e"), Color(hex: "#4a2663")]
            default: return [Color(hex: "#0a0a0a"), Color(hex: "#3a3a5c")]
            }
        default:
            let hash = abs(name.hashValue)
            let hue = Double(hash % 360) / 360.0
            return [
                Color(hue: hue, saturation: 0.6, brightness: 0.3),
                Color(hue: (hue + 0.15).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 0.5)
            ]
        }
    }

    var sortHue: Double {
        let hash = abs(name.hashValue)
        let base: Double
        switch (category ?? "").lowercased() {
        case "city": base = 200
        case "landscape": base = 0
        default: base = 180
        }
        return base + Double(hash % 160)
    }

    var thumbnailURL: URL? {
        guard let urlStr = remoteURL else { return nil }
        if urlStr.contains("unsplash.com") {
            return URL(string: urlStr + "&w=1200&q=85")
        }
        return URL(string: urlStr)
    }

    var fullResURL: URL? {
        guard let urlStr = remoteURL else { return nil }
        if urlStr.contains("unsplash.com") {
            return URL(string: urlStr + "&w=3456&h=2234&fit=crop&q=90")
        }
        return URL(string: urlStr)
    }
}

private func wh(_ whID: String, _ name: String, _ ext: String, _ colors: [String]) -> WallpaperItem {
    let prefix = String(whID.prefix(2))
    return WallpaperItem(
        id: "wh-\(whID)", name: name, type: .remote, path: nil,
        remoteURL: "https://w.wallhaven.cc/full/\(prefix)/wallhaven-\(whID).\(ext)",
        gradientColors: colors, category: nil
    )
}

class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()

    @Published var wallpapers: [WallpaperItem] = []
    @Published var currentWallpaper: WallpaperItem?
    @Published var wallpaperDirectory: URL

    private let engine = WallpaperEngine()
    private let downloadCacheDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        wallpaperDirectory = appSupport.appendingPathComponent("GlassOS/Wallpapers")
        downloadCacheDir = appSupport.appendingPathComponent("GlassOS/DownloadCache")
        try? FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: downloadCacheDir, withIntermediateDirectories: true)
        cleanupOldCache()
        loadWallpapers()
    }

    private func cleanupOldCache() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: wallpaperDirectory, includingPropertiesForKeys: nil) else { return }
        for url in contents where url.lastPathComponent != "Custom" {
            try? fm.removeItem(at: url)
        }
    }

    func loadWallpapers() {
        var items: [WallpaperItem] = []

        // Sorted dark → green → blue → purple → red → warm → pastel

        items.append(wh("5yp939", "Kernel Panic",     "png", ["#000000", "#424153"]))
        items.append(wh("xekg7z", "Black Swordsman",  "png", ["#0a0a0a", "#3a0808"]))
        items.append(wh("og7vpm", "Digital Seraph",    "png", ["#050505", "#0a3a0a"]))
        items.append(wh("m9md18", "Phantom Forest",    "jpg", ["#0a1a0a", "#1a3a1a"]))
        items.append(wh("6k1dj7", "Shadow Valley",     "jpg", ["#0f1a17", "#1a3a2a"]))
        items.append(wh("011zk3", "Emerald Mist",      "jpg", ["#0a2a1a", "#1a5a2a"]))
        items.append(wh("47ol30", "Moss Cathedral",     "jpg", ["#1a3a0a", "#2a5a1a"]))
        items.append(wh("1qlpkv", "Hidden Falls",      "jpg", ["#1a2a2a", "#3a5a5a"]))
        items.append(wh("zp2y8j", "Frost City",        "jpg", ["#1a2a3a", "#3a6a7a"]))
        items.append(wh("6dz386", "Midnight Canvas",   "jpg", ["#08081a", "#1a1a3e"]))
        items.append(wh("vp96kl", "Moonlit Sea",       "jpg", ["#0a0a2a", "#1a3a5a"]))
        items.append(wh("yxdvjx", "Dark Horizon",      "png", ["#1a1a1a", "#3a3a5a"]))
        items.append(wh("k8jvm7", "Neural Grid",       "jpg", ["#1a1a2a", "#4a4a6a"]))
        items.append(wh("ey7prw", "Stargazer",         "jpg", ["#0a0a1e", "#1a2a5e"]))
        items.append(wh("p8gp83", "Celestial Path",    "jpg", ["#1a0a2e", "#3a2a6e"]))
        items.append(wh("yqwx17", "Vice City",         "jpg", ["#1a0a2a", "#5a1a6a"]))
        items.append(wh("jxjm1m", "Synthwave",         "png", ["#1a0033", "#e91e63"]))
        items.append(wh("yqkrv7", "Crimson Knight",    "png", ["#1a0505", "#5a1a1a"]))
        items.append(wh("7jmpz3", "Red Moon",          "jpg", ["#2a1a1a", "#5a3030"]))
        items.append(wh("jerxxw", "Cloud Atlas",       "jpg", ["#2a2a1a", "#5a4a3a"]))
        items.append(wh("gpgk57", "Wanderer",          "jpg", ["#1a1a10", "#3a3a2a"]))
        items.append(wh("eyw5qw", "Forgotten Lands",   "jpg", ["#1a1a10", "#4a3a2a"]))
        items.append(wh("po5o9m", "Dusk Garden",       "jpg", ["#2a1a1a", "#5a3a2a"]))
        items.append(wh("gp3593", "Afterglow",         "jpg", ["#2a1a0a", "#6a3a1a"]))
        items.append(wh("mloml9", "Sky Armada",        "jpg", ["#3a3a3a", "#6a5a4a"]))
        items.append(wh("yqw88g", "Pastel Peaks",      "jpg", ["#3a3a4a", "#8a6a7a"]))

        // Scan for user-added local wallpapers in Custom subfolder
        let customDir = wallpaperDirectory.appendingPathComponent("Custom")
        try? FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        if let enumerator = FileManager.default.enumerator(at: customDir, includingPropertiesForKeys: nil) {
            while let url = enumerator.nextObject() as? URL {
                let ext = url.pathExtension.lowercased()
                if ["mp4", "mov", "m4v", "webm"].contains(ext) {
                    items.append(WallpaperItem(
                        id: "local-\(url.lastPathComponent)", name: url.deletingPathExtension().lastPathComponent,
                        type: .video, path: url.path, remoteURL: nil, gradientColors: nil, category: "custom"
                    ))
                } else if ["jpg", "jpeg", "png", "heic", "webp", "tiff"].contains(ext) {
                    let name = url.deletingPathExtension().lastPathComponent
                    if !items.contains(where: { $0.id.hasSuffix(name + ".jpg") }) {
                        items.append(WallpaperItem(
                            id: "local-\(url.lastPathComponent)", name: name,
                            type: .image, path: url.path, remoteURL: nil, gradientColors: nil, category: "custom"
                        ))
                    }
                }
            }
        }

        wallpapers = items
    }

    func applyWallpaper(_ wallpaper: WallpaperItem) {
        currentWallpaper = wallpaper

        switch wallpaper.type {
        case .remote:
            guard let fullURL = wallpaper.fullResURL else { return }
            let cachedPath = downloadCacheDir.appendingPathComponent("\(wallpaper.id).jpg")

            if FileManager.default.fileExists(atPath: cachedPath.path) {
                engine.applyStaticWallpaper(url: cachedPath)
            } else {
                URLSession.shared.dataTask(with: fullURL) { [weak self] data, _, _ in
                    guard let data = data else { return }
                    try? data.write(to: cachedPath)
                    DispatchQueue.main.async {
                        self?.engine.applyStaticWallpaper(url: cachedPath)
                    }
                }.resume()
            }
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
        let customDir = wallpaperDirectory.appendingPathComponent("Custom")
        try? FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        let destination = customDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: destination)
        loadWallpapers()
    }

    func removeWallpaper() {
        engine.removeAllWallpapers()
        currentWallpaper = nil
        UserDefaults.standard.removeObject(forKey: "currentWallpaperID")
    }
}

class ImageCache: ObservableObject {
    static let shared = ImageCache()
    private var cache: [String: NSImage] = [:]
    private var loading: Set<String> = []
    private let cacheDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = appSupport.appendingPathComponent("GlassOS/ThumbnailCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func image(for wallpaper: WallpaperItem) -> NSImage? {
        if let cached = cache[wallpaper.id] { return cached }

        let diskPath = cacheDir.appendingPathComponent("\(wallpaper.id).jpg")
        if let img = NSImage(contentsOf: diskPath) {
            cache[wallpaper.id] = img
            return img
        }

        if let path = wallpaper.path, let img = NSImage(contentsOfFile: path) {
            cache[wallpaper.id] = img
            return img
        }

        if !loading.contains(wallpaper.id), let url = wallpaper.thumbnailURL {
            loading.insert(wallpaper.id)
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data, let img = NSImage(data: data) else {
                    DispatchQueue.main.async { self?.loading.remove(wallpaper.id) }
                    return
                }
                try? data.write(to: diskPath)
                DispatchQueue.main.async {
                    self?.cache[wallpaper.id] = img
                    self?.loading.remove(wallpaper.id)
                    self?.objectWillChange.send()
                }
            }.resume()
        }

        return nil
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
