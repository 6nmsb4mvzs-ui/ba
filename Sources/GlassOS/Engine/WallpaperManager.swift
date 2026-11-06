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
        case "abstract":
            return [Color(hex: "#ee9ca7"), Color(hex: "#ffdde1")]
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

private func wp(_ id: String, _ name: String, _ photoID: String, _ cat: String) -> WallpaperItem {
    WallpaperItem(
        id: id, name: name, type: .remote, path: nil,
        remoteURL: "https://images.unsplash.com/\(photoID)?auto=format&fit=crop",
        gradientColors: nil, category: cat
    )
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

        // --- Mountains & Landscapes ---
        items.append(wp("mountain-lake", "Mountain Lake", "photo-1506905925346-21bda4d32df4", "mountain"))
        items.append(wp("snowy-peaks", "Snowy Peaks", "photo-1519681393784-d120267933ba", "mountain"))
        items.append(wp("green-valley", "Green Valley", "photo-1470071459604-3b5ec3a7fe05", "landscape"))
        items.append(wp("purple-sunset", "Purple Sunset", "photo-1536431311719-398b6704d4cc", "landscape"))
        items.append(wp("desert-dunes", "Desert Dunes", "photo-1509316975850-ff9c5deb0cd9", "landscape"))
        items.append(wp("autumn-road", "Autumn Road", "photo-1508193638397-1c4234db14d8", "nature"))
        items.append(wp("dramatic-peak", "Dramatic Peak", "photo-1464822759023-fed622ff2c3b", "mountain"))
        items.append(wp("lake-reflection", "Lake Reflection", "photo-1501785888041-af3ef285b470", "landscape"))
        items.append(wp("waterfall", "Waterfall", "photo-1433086966358-54859d0ed716", "nature"))
        items.append(wp("sunset-field", "Sunset Field", "photo-1500534314263-a834e5fe8f3c", "landscape"))
        items.append(wp("aerial-trees", "Aerial Forest", "photo-1497436072909-60f360e1d4b1", "nature"))
        items.append(wp("flower-field", "Flower Field", "photo-1465146344425-f00d5f5c8f07", "nature"))
        items.append(wp("sunset-silhouette", "Sunset Silhouette", "photo-1490730141103-6cac27aaab94", "landscape"))
        items.append(wp("dramatic-clouds", "Dramatic Clouds", "photo-1504608524841-42fe6f032b4b", "landscape"))
        items.append(wp("golden-hour", "Golden Hour", "photo-1472214103451-9374bd1c798e", "landscape"))

        // --- Ocean & Beach ---
        items.append(wp("ocean-waves", "Ocean Waves", "photo-1505118380757-91f5f5632de0", "ocean"))
        items.append(wp("tropical-beach", "Tropical Beach", "photo-1507525428034-b723cf961d3e", "beach"))
        items.append(wp("calm-ocean", "Calm Ocean", "photo-1439405326854-014607f694d7", "ocean"))
        items.append(wp("aerial-reef", "Aerial Reef", "photo-1518837695005-2083093ee35b", "ocean"))
        items.append(wp("coastal-cliff", "Coastal Cliff", "photo-1494783367193-149034c05e8f", "ocean"))

        // --- Space & Night Sky ---
        items.append(wp("galaxy", "Galaxy", "photo-1462331940025-496dfbfc7564", "space"))
        items.append(wp("earth-space", "Earth from Space", "photo-1451187580459-43490279c0fa", "space"))
        items.append(wp("starry-sky", "Starry Sky", "photo-1444703686981-a3abbc4d4fe3", "space"))
        items.append(wp("milky-way", "Milky Way", "photo-1419242902214-272b3f66ee7a", "space"))
        items.append(wp("nebula-colors", "Nebula", "photo-1543722530-d2c3201371e7", "space"))

        // --- Cities ---
        items.append(wp("nyc-skyline", "NYC Skyline", "photo-1514565131-fce0801e5785", "city"))
        items.append(wp("tokyo-nights", "Tokyo Nights", "photo-1540959733332-eab4deabeeaf", "city"))
        items.append(wp("city-lights", "City Lights", "photo-1477959858617-67f85cf4f1df", "city"))
        items.append(wp("city-aerial", "City Aerial", "photo-1480714378408-67cf0d13bc1b", "city"))
        items.append(wp("night-highway", "Night Highway", "photo-1519501025264-65ba15a82390", "city"))

        // --- Nature & Forest ---
        items.append(wp("aurora-borealis", "Northern Lights", "photo-1531366936337-7c912a4589a7", "nature"))
        items.append(wp("misty-forest", "Misty Forest", "photo-1448375240586-882707db888b", "forest"))
        items.append(wp("cherry-blossoms", "Cherry Blossoms", "photo-1493976040374-85c8e12f0c0e", "nature"))
        items.append(wp("lightning-storm", "Lightning Storm", "photo-1461511669078-d46bf351cd6e", "nature"))
        items.append(wp("volcano", "Volcano", "photo-1462275646964-a0e3c11f18a6", "nature"))
        items.append(wp("green-canopy", "Green Canopy", "photo-1441974231531-c6227db76b6e", "forest"))
        items.append(wp("fog-forest", "Fog Forest", "photo-1418065460487-3e41a6c84dc5", "forest"))
        items.append(wp("autumn-lake", "Autumn Lake", "photo-1476231682828-37e571bc172f", "nature"))
        items.append(wp("bamboo-grove", "Bamboo Grove", "photo-1467269204594-9661b134dd2b", "nature"))
        items.append(wp("lavender-field", "Lavender Field", "photo-1499002238440-d264edd596ec", "nature"))

        // --- Abstract & Artistic ---
        items.append(wp("neon-glow", "Neon Glow", "photo-1550684376-efcbd6e3f031", "abstract"))
        items.append(wp("color-gradient", "Color Gradient", "photo-1579546929518-9e396f3cc809", "abstract"))
        items.append(wp("fluid-art", "Fluid Art", "photo-1558591710-4b4a1ae0f04d", "abstract"))
        items.append(wp("smoke-colors", "Smoke Colors", "photo-1541701494587-cb58502866ab", "abstract"))
        items.append(wp("crystal-cave", "Crystal Cave", "photo-1519681393784-d120267933ba", "abstract"))

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
