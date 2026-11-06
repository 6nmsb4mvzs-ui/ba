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
        case "mountain", "landscape":
            return [Color(hex: "#2c3e50"), Color(hex: "#4ca1af")]
        case "night", "city":
            return [Color(hex: "#0a1628"), Color(hex: "#1a3a5c")]
        case "space":
            return [Color(hex: "#0f0c29"), Color(hex: "#302b63")]
        case "ocean", "beach":
            return [Color(hex: "#2193b0"), Color(hex: "#6dd5ed")]
        case "forest", "nature":
            return [Color(hex: "#0f2027"), Color(hex: "#2c5364")]
        default:
            let hash = abs(name.hashValue)
            let hue = Double(hash % 360) / 360.0
            return [
                Color(hue: hue, saturation: 0.6, brightness: 0.3),
                Color(hue: (hue + 0.15).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 0.5)
            ]
        }
    }

    var thumbnailURL: URL? {
        guard let urlStr = remoteURL else { return nil }
        return URL(string: urlStr + "&w=800&q=80")
    }

    var fullResURL: URL? {
        guard let urlStr = remoteURL else { return nil }
        return URL(string: urlStr + "&w=3840&q=90")
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

        let base = "https://images.unsplash.com/"

        items.append(contentsOf: [
            WallpaperItem(
                id: "unsplash-mountain-lake", name: "Mountain Lake", type: .remote,
                path: nil, remoteURL: base + "photo-1506905925346-21bda4d32df4?auto=format&fit=crop",
                gradientColors: nil, category: "landscape"
            ),
            WallpaperItem(
                id: "unsplash-snowy-peaks", name: "Snowy Peaks", type: .remote,
                path: nil, remoteURL: base + "photo-1519681393784-d120267933ba?auto=format&fit=crop",
                gradientColors: nil, category: "mountain"
            ),
            WallpaperItem(
                id: "unsplash-aurora", name: "Northern Lights", type: .remote,
                path: nil, remoteURL: base + "photo-1531366936337-7c912a4589a7?auto=format&fit=crop",
                gradientColors: nil, category: "nature"
            ),
            WallpaperItem(
                id: "unsplash-ocean", name: "Ocean Waves", type: .remote,
                path: nil, remoteURL: base + "photo-1505118380757-91f5f5632de0?auto=format&fit=crop",
                gradientColors: nil, category: "ocean"
            ),
            WallpaperItem(
                id: "unsplash-misty-forest", name: "Misty Forest", type: .remote,
                path: nil, remoteURL: base + "photo-1448375240586-882707db888b?auto=format&fit=crop",
                gradientColors: nil, category: "forest"
            ),
            WallpaperItem(
                id: "unsplash-galaxy", name: "Galaxy", type: .remote,
                path: nil, remoteURL: base + "photo-1462331940025-496dfbfc7564?auto=format&fit=crop",
                gradientColors: nil, category: "space"
            ),
            WallpaperItem(
                id: "unsplash-nyc-night", name: "NYC Skyline", type: .remote,
                path: nil, remoteURL: base + "photo-1514565131-fce0801e5785?auto=format&fit=crop",
                gradientColors: nil, category: "city"
            ),
            WallpaperItem(
                id: "unsplash-cherry-blossom", name: "Cherry Blossoms", type: .remote,
                path: nil, remoteURL: base + "photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop",
                gradientColors: nil, category: "nature"
            ),
            WallpaperItem(
                id: "unsplash-tropical-beach", name: "Tropical Beach", type: .remote,
                path: nil, remoteURL: base + "photo-1507525428034-b723cf961d3e?auto=format&fit=crop",
                gradientColors: nil, category: "beach"
            ),
            WallpaperItem(
                id: "unsplash-green-valley", name: "Green Valley", type: .remote,
                path: nil, remoteURL: base + "photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop",
                gradientColors: nil, category: "landscape"
            ),
            WallpaperItem(
                id: "unsplash-purple-sunset", name: "Purple Sunset", type: .remote,
                path: nil, remoteURL: base + "photo-1536431311719-398b6704d4cc?auto=format&fit=crop",
                gradientColors: nil, category: "landscape"
            ),
            WallpaperItem(
                id: "unsplash-desert-dunes", name: "Desert Dunes", type: .remote,
                path: nil, remoteURL: base + "photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop",
                gradientColors: nil, category: "landscape"
            ),
            WallpaperItem(
                id: "unsplash-autumn-road", name: "Autumn Road", type: .remote,
                path: nil, remoteURL: base + "photo-1508193638397-1c4234db14d8?auto=format&fit=crop",
                gradientColors: nil, category: "nature"
            ),
            WallpaperItem(
                id: "unsplash-volcano", name: "Volcano", type: .remote,
                path: nil, remoteURL: base + "photo-1462275646964-a0e3c11f18a6?auto=format&fit=crop",
                gradientColors: nil, category: "landscape"
            ),
            WallpaperItem(
                id: "unsplash-lightning", name: "Lightning Storm", type: .remote,
                path: nil, remoteURL: base + "photo-1461511669078-d46bf351cd6e?auto=format&fit=crop",
                gradientColors: nil, category: "nature"
            ),
            WallpaperItem(
                id: "unsplash-tokyo-night", name: "Tokyo Nights", type: .remote,
                path: nil, remoteURL: base + "photo-1540959733332-eab4deabeeaf?auto=format&fit=crop",
                gradientColors: nil, category: "city"
            ),
        ])

        if let enumerator = FileManager.default.enumerator(at: wallpaperDirectory, includingPropertiesForKeys: nil) {
            while let url = enumerator.nextObject() as? URL {
                let ext = url.pathExtension.lowercased()
                if ["mp4", "mov", "m4v", "webm"].contains(ext) {
                    items.append(WallpaperItem(
                        id: url.lastPathComponent,
                        name: url.deletingPathExtension().lastPathComponent,
                        type: .video, path: url.path, remoteURL: nil,
                        gradientColors: nil, category: "custom"
                    ))
                } else if ["jpg", "jpeg", "png", "heic", "webp", "tiff"].contains(ext) {
                    items.append(WallpaperItem(
                        id: url.lastPathComponent,
                        name: url.deletingPathExtension().lastPathComponent,
                        type: .image, path: url.path, remoteURL: nil,
                        gradientColors: nil, category: "custom"
                    ))
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
            let cachedPath = wallpaperDirectory.appendingPathComponent("\(wallpaper.id).jpg")

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
