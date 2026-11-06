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
            return URL(string: urlStr + "&w=800&q=80")
        }
        if urlStr.contains("w.wallhaven.cc/full") {
            let thumb = urlStr
                .replacingOccurrences(of: "https://w.wallhaven.cc/full", with: "https://th.wallhaven.cc/orig")
                .replacingOccurrences(of: "wallhaven-", with: "")
            if let dotRange = thumb.range(of: ".", options: .backwards) {
                return URL(string: String(thumb[thumb.startIndex..<dotRange.lowerBound]) + ".jpg")
            }
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

private func wh(_ whID: String, _ name: String, _ ext: String, _ cat: String) -> WallpaperItem {
    let prefix = String(whID.prefix(2))
    return WallpaperItem(
        id: "wh-\(whID)", name: name, type: .remote, path: nil,
        remoteURL: "https://w.wallhaven.cc/full/\(prefix)/wallhaven-\(whID).\(ext)",
        gradientColors: nil, category: cat
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
        loadWallpapers()
    }

    func loadWallpapers() {
        var items: [WallpaperItem] = []

        // ═══════════════════════════════════════════
        //  CITY — cyberpunk, neon, futuristic, Tokyo
        // ═══════════════════════════════════════════

        items.append(wh("5gpv25", "Rain City", "jpg", "city"))
        items.append(wh("pkr6mp", "Neon District", "png", "city"))
        items.append(wh("z8lgwg", "Cyber Tokyo", "jpg", "city"))
        items.append(wh("7jgyre", "Tokyo Nights", "jpg", "city"))
        items.append(wh("jxjm1m", "Synthwave", "png", "city"))
        items.append(wh("wy6vqx", "Akihabara", "jpg", "city"))
        items.append(wh("y8wm8g", "Shibuya Glow", "png", "city"))
        items.append(wh("vqv3p8", "Harajuku", "jpg", "city"))
        items.append(wh("5wezr9", "Metropolis", "png", "city"))
        items.append(wh("oxwj1l", "Neon Rain", "jpg", "city"))
        items.append(wh("exl88k", "Midnight Tokyo", "png", "city"))
        items.append(wh("w58q8x", "Ginza", "jpg", "city"))
        items.append(wh("6d1v5q", "Electric Avenue", "jpg", "city"))
        items.append(wh("pkrly9", "Blade Runner", "jpg", "city"))
        items.append(wh("d8w6gj", "Infinite Skyline", "jpg", "city"))
        items.append(wh("83rrm2", "Chrome City", "jpg", "city"))
        items.append(wh("725gj3", "Digital Downtown", "jpg", "city"))
        items.append(wh("ogj2v7", "Shinjuku", "jpg", "city"))
        items.append(wh("zm5pmj", "Midnight Circuit", "jpg", "city"))
        items.append(wh("lmdvlr", "Neon Haze", "jpg", "city"))
        items.append(wh("3llmey", "Phosphor", "jpg", "city"))
        items.append(wh("6l2rk7", "Monsoon Streets", "jpg", "city"))
        items.append(wh("vpeek5", "Crimson Gate", "png", "city"))
        items.append(wh("zykjko", "Ghost Protocol", "jpg", "city"))
        items.append(wh("83dpz2", "Voltage", "jpg", "city"))
        items.append(wh("gp3593", "Afterglow", "jpg", "city"))
        items.append(wh("96pzpw", "Downpour", "jpg", "city"))

        // ═══════════════════════════════════════════
        //  LANDSCAPE — dark forests, fantasy, stars,
        //  snow, aurora, cherry blossom
        // ═══════════════════════════════════════════

        items.append(wh("9mjoy1", "Sakura", "png", "landscape"))
        items.append(wh("m9md18", "Phantom Forest", "jpg", "landscape"))
        items.append(wh("72yzje", "Ethereal Realm", "jpg", "landscape"))
        items.append(wh("6k1dj7", "Shadow Valley", "jpg", "landscape"))
        items.append(wh("011zk3", "Emerald Mist", "jpg", "landscape"))
        items.append(wh("p8gp83", "Celestial Path", "jpg", "landscape"))
        items.append(wh("ey7prw", "Stargazer", "jpg", "landscape"))
        items.append(wh("eyw5qw", "Forgotten Lands", "jpg", "landscape"))
        items.append(wh("zm6qmw", "Cosmic Meadow", "jpg", "landscape"))
        items.append(wh("vqy2jp", "Ancient Kingdom", "jpg", "landscape"))
        items.append(wh("eolmrl", "Whispering Pines", "jpg", "landscape"))
        items.append(wh("yxdvjx", "Dark Horizon", "png", "landscape"))
        items.append(wh("kwd36d", "Twilight Expanse", "jpg", "landscape"))
        items.append(wh("zyvrxy", "Eternal Night", "png", "landscape"))
        items.append(wh("ox6zrl", "Misty Peaks", "jpg", "landscape"))
        items.append(wh("9mq26d", "Enchanted Grove", "jpg", "landscape"))
        items.append(wh("x8893d", "Silent Woods", "png", "landscape"))
        items.append(wh("vgexwm", "Aurora Dreams", "jpg", "landscape"))
        items.append(wh("47ol30", "Moss Cathedral", "jpg", "landscape"))
        items.append(wh("v9z1dl", "Crimson Dusk", "jpg", "landscape"))
        items.append(wh("96mlzd", "Frozen Kingdom", "jpg", "landscape"))
        items.append(wh("dgv8qo", "Verdant Shadows", "png", "landscape"))
        items.append(wh("mdrlj1", "Winter Silence", "jpg", "landscape"))
        items.append(wh("qzm89d", "Emerald Depths", "png", "landscape"))
        items.append(wh("2kp55x", "Northern Lights", "jpg", "landscape"))
        items.append(wh("exrvgk", "Frost Whisper", "jpg", "landscape"))
        items.append(wh("ne82mk", "Ronin's Path", "jpg", "landscape"))
        items.append(wh("6dz386", "Midnight Canvas", "jpg", "landscape"))
        items.append(wh("vp96kl", "Moonlit Sea", "jpg", "landscape"))
        items.append(wh("6qzl1l", "Ember Crown", "jpg", "landscape"))
        items.append(wh("d5gxgj", "Dark Citadel", "jpg", "landscape"))
        items.append(wh("gpgk57", "Wanderer", "jpg", "landscape"))

        // Scan for user-added local wallpapers
        if let enumerator = FileManager.default.enumerator(at: wallpaperDirectory, includingPropertiesForKeys: nil) {
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

        wallpapers = items.sorted { $0.sortHue < $1.sortHue }
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
