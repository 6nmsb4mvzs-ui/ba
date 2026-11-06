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
        case "car", "supercar":
            return [Color(hex: "#1a0000"), Color(hex: "#8b0000")]
        case "superhero":
            return [Color(hex: "#1a1a2e"), Color(hex: "#c0392b")]
        case "bike", "motorcycle":
            return [Color(hex: "#1a1a1a"), Color(hex: "#e67e22")]
        case "actor":
            return [Color(hex: "#2c1810"), Color(hex: "#d4a574")]
        case "landscape":
            return [Color(hex: "#3a2e0a"), Color(hex: "#c8a951")]
        case "nature":
            return [Color(hex: "#1a2e0a"), Color(hex: "#6b8e23")]
        case "forest":
            return [Color(hex: "#0f2027"), Color(hex: "#2c5364")]
        case "mountain":
            return [Color(hex: "#1a3040"), Color(hex: "#4ca1af")]
        case "ocean", "beach":
            return [Color(hex: "#003545"), Color(hex: "#6dd5ed")]
        case "city":
            return [Color(hex: "#0a1628"), Color(hex: "#1a5276")]
        case "space":
            return [Color(hex: "#0f0c29"), Color(hex: "#302b63")]
        case "musician":
            return [Color(hex: "#1a0a33"), Color(hex: "#7b2d8e")]
        case "anime":
            return [Color(hex: "#2d1b69"), Color(hex: "#e91e8c")]
        case "cyberpunk":
            return [Color(hex: "#0d0221"), Color(hex: "#0abdc6")]
        case "alternative", "dark":
            return [Color(hex: "#0a0a0a"), Color(hex: "#333333")]
        case "abstract":
            return [Color(hex: "#2b1055"), Color(hex: "#d53f8c")]
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
        switch (category ?? "").lowercased() {
        case "car", "supercar": return 0
        case "superhero": return 10
        case "bike", "motorcycle": return 25
        case "actor": return 40
        case "landscape": return 55
        case "nature": return 80
        case "forest": return 120
        case "mountain": return 155
        case "ocean", "beach": return 185
        case "city": return 215
        case "space": return 245
        case "musician": return 270
        case "anime": return 295
        case "cyberpunk": return 310
        case "alternative", "dark": return 330
        case "abstract": return 345
        default: return 180
        }
    }

    var thumbnailURL: URL? {
        guard let urlStr = remoteURL else { return nil }
        return URL(string: urlStr + "&w=800&q=80")
    }

    var fullResURL: URL? {
        guard let urlStr = remoteURL else { return nil }
        return URL(string: urlStr + "&w=3456&h=2234&fit=crop&q=90")
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

        // --- Cars (hue ~0, reds) ---
        items.append(wp("red-porsche", "Red Porsche", "photo-1552519507-da3b142c6e3d", "car"))
        items.append(wp("red-ferrari", "Red Ferrari", "photo-1580273916550-e323be2ae537", "car"))
        items.append(wp("red-lambo", "Red Lamborghini", "photo-1617814076668-8dfc6cafee80", "car"))
        items.append(wp("yellow-lambo", "Yellow Lamborghini", "photo-1553440569-bcc63803a83d", "car"))
        items.append(wp("blue-mclaren", "Blue McLaren", "photo-1583121274602-3e2820c69888", "car"))
        items.append(wp("green-aventador", "Green Aventador", "photo-1590362891991-f776e747a588", "car"))
        items.append(wp("dark-ferrari", "Dark Ferrari", "photo-1592186304929-ed06c878449a", "car"))
        items.append(wp("orange-mclaren", "Orange McLaren", "photo-1618843479313-40f8afb4b4d8", "car"))
        items.append(wp("gold-coupe", "Gold Coupe", "photo-1614026480418-bd11404532a6", "car"))
        items.append(wp("white-porsche", "White Porsche", "photo-1511919884226-fd3cad34687c", "car"))
        items.append(wp("night-drive", "Night Drive", "photo-1560958089-b8a1929cea89", "car"))
        items.append(wp("classic-muscle", "Classic Muscle", "photo-1561066365-42867a47f0d8", "car"))

        // --- Superheroes (hue ~10) ---
        items.append(wp("hero-silhouette", "Hero Silhouette", "photo-1612036782180-6f0b6cd846fe", "superhero"))
        items.append(wp("hero-action", "Hero Action", "photo-1636247639271-5f9001230a95", "superhero"))
        items.append(wp("hero-dark", "Hero Dark", "photo-1768697581060-52e2edbee7fa", "superhero"))

        // --- Bikes & Motorcycles (hue ~25) ---
        items.append(wp("sport-bike", "Sport Bike", "photo-1544552866-d3ed42536cfd", "bike"))
        items.append(wp("cafe-racer", "Cafe Racer", "photo-1558618047-3c8c76ca7d2b", "bike"))
        items.append(wp("dark-motorcycle", "Dark Motorcycle", "photo-1558980664-2cd663cf8dde", "bike"))
        items.append(wp("chopper-road", "Chopper Road", "photo-1568605117036-5fe5e7bab0b7", "bike"))
        items.append(wp("vintage-harley", "Vintage Harley", "photo-1591231720264-80b4c3b9bc76", "bike"))
        items.append(wp("custom-scrambler", "Custom Scrambler", "photo-1614152412583-bae4138b3f50", "bike"))
        items.append(wp("neon-rider", "Neon Rider", "photo-1691838870244-d56470357328", "bike"))
        items.append(wp("moto-sunset", "Moto Sunset", "photo-1707561525582-2ddcf937a6dd", "bike"))

        // --- Actors & Portraits (hue ~40) ---
        items.append(wp("dramatic-portrait", "Dramatic Portrait", "photo-1414235077428-338989a2e8c0", "actor"))
        items.append(wp("studio-portrait", "Studio Portrait", "photo-1438761681033-6461ffad8d80", "actor"))
        items.append(wp("cinematic-look", "Cinematic Look", "photo-1472099645785-5658abf4ff4e", "actor"))
        items.append(wp("moody-portrait", "Moody Portrait", "photo-1467003909585-2f8a72700288", "actor"))
        items.append(wp("artistic-portrait", "Artistic Portrait", "photo-1486325212027-8081e485255e", "actor"))
        items.append(wp("golden-hour-portrait", "Golden Hour Portrait", "photo-1452587925148-ce544e77e70d", "actor"))
        items.append(wp("fashion-portrait", "Fashion Portrait", "photo-1469334031218-e382a71b716b", "actor"))
        items.append(wp("silhouette-portrait", "Silhouette Portrait", "photo-1476480862126-209bfaa8edc8", "actor"))

        // --- Landscapes (hue ~55) ---
        items.append(wp("golden-desert", "Golden Desert", "photo-1509316785289-025f5b846b35", "landscape"))
        items.append(wp("sunset-beach", "Sunset Beach", "photo-1507525428034-b723cf961d3e", "landscape"))
        items.append(wp("sunset-field", "Sunset Field", "photo-1499346030926-9a72daac6c63", "landscape"))
        items.append(wp("cherry-blossom", "Cherry Blossom", "photo-1522383225653-ed111181a951", "landscape"))
        items.append(wp("autumn-path", "Autumn Path", "photo-1507003211169-0a1dd7228f2d", "landscape"))
        items.append(wp("lavender-sunset", "Lavender Sunset", "photo-1468581264429-2548ef9eb732", "landscape"))

        // --- Nature & Forest (hue ~80) ---
        items.append(wp("misty-forest", "Misty Forest", "photo-1448375240586-882707db888b", "nature"))
        items.append(wp("waterfall", "Majestic Waterfall", "photo-1432405972618-c60b0225b8f9", "nature"))
        items.append(wp("green-canopy", "Green Forest Canopy", "photo-1441974231531-c6227db76b6e", "nature"))
        items.append(wp("northern-lights", "Northern Lights", "photo-1531366936337-7c912a4589a7", "nature"))
        items.append(wp("bamboo-grove", "Bamboo Grove", "photo-1518173946687-a4c8892bbd9f", "nature"))
        items.append(wp("flower-meadow", "Flower Meadow", "photo-1465146344425-f00d5f5c8f07", "nature"))
        items.append(wp("tropical-palms", "Tropical Palms", "photo-1511497584788-876760111969", "nature"))
        items.append(wp("redwood-trail", "Redwood Trail", "photo-1473116763249-2faaef81ccda", "nature"))

        // --- Mountains (hue ~155) ---
        items.append(wp("mountain-lake", "Alpine Lake", "photo-1506905925346-21bda4d32df4", "mountain"))
        items.append(wp("dark-mountain", "Dark Mountain", "photo-1519681393784-d120267933ba", "mountain"))
        items.append(wp("dramatic-peak", "Dramatic Peak", "photo-1464822759023-fed622ff2c3b", "mountain"))
        items.append(wp("mountain-sunrise", "Mountain Sunrise", "photo-1454496522488-7a8e488e8606", "mountain"))
        items.append(wp("misty-peaks", "Misty Peaks", "photo-1447752875215-b2761acb3c5d", "mountain"))
        items.append(wp("snowy-ridge", "Snowy Ridge", "photo-1529429617124-95b109e86bb8", "mountain"))

        // --- Ocean & Beach (hue ~185) ---
        items.append(wp("ocean-wave", "Ocean Wave", "photo-1505118380757-91f5f5632de0", "ocean"))
        items.append(wp("deep-blue", "Deep Blue Ocean", "photo-1518022525094-218670c9b745", "ocean"))
        items.append(wp("crystal-water", "Crystal Water", "photo-1473773508845-188df298d2d1", "ocean"))
        items.append(wp("aerial-reef", "Aerial Reef", "photo-1484318571209-661cf29a69c3", "ocean"))

        // --- Cities (hue ~215) ---
        items.append(wp("city-skyline", "City Skyline", "photo-1477959858617-67f85cf4f1df", "city"))
        items.append(wp("tokyo-night", "Tokyo Night", "photo-1540959733332-eab4deabeeaf", "city"))
        items.append(wp("modern-arch", "Modern Architecture", "photo-1470723710355-95304d8aece4", "city"))
        items.append(wp("neon-city", "Neon City", "photo-1545486332-9e0999c535b2", "city"))
        items.append(wp("minimal-building", "Minimal Building", "photo-1487958449943-2429e8be8625", "city"))
        items.append(wp("night-skyline", "Night Skyline", "photo-1517430816045-df4b7de11d1d", "city"))
        items.append(wp("japan-temple", "Japan Temple", "photo-1480796927426-f609979314bd", "city"))
        items.append(wp("tokyo-tower", "Tokyo Tower", "photo-1490806843957-31f4c9a91c65", "city"))
        items.append(wp("kyoto-shrine", "Kyoto Shrine", "photo-1493976040374-85c8e12f0c0e", "city"))
        items.append(wp("shibuya-crossing", "Shibuya Crossing", "photo-1542051841857-5f90071e7989", "city"))

        // --- Space (hue ~245) ---
        items.append(wp("cosmic-galaxy", "Cosmic Galaxy", "photo-1462331940025-496dfbfc7564", "space"))
        items.append(wp("milky-way", "Milky Way", "photo-1419242902214-272b3f66ee7a", "space"))
        items.append(wp("nebula-dream", "Nebula Dream", "photo-1465101162946-4377e57745c3", "space"))
        items.append(wp("deep-nebula", "Deep Nebula", "photo-1465101046530-73398c7f28ca", "space"))
        items.append(wp("starfield", "Starfield", "photo-1454789548928-9efd52dc4031", "space"))
        items.append(wp("space-dust", "Space Dust", "photo-1464802686167-b939a6910659", "space"))

        // --- Musicians & Concerts (hue ~270) ---
        items.append(wp("concert-crowd", "Concert Crowd", "photo-1470229722913-7c0e2dbbafd3", "musician"))
        items.append(wp("stage-lights", "Stage Lights", "photo-1493225457124-a3eb161ffa5f", "musician"))
        items.append(wp("festival-night", "Festival Night", "photo-1501281668745-f7f57925c3b4", "musician"))
        items.append(wp("live-performance", "Live Performance", "photo-1511671782779-c97d3d27a1d4", "musician"))
        items.append(wp("dj-booth", "DJ Booth", "photo-1514525253161-7a46d19cd819", "musician"))
        items.append(wp("concert-energy", "Concert Energy", "photo-1516450360452-9312f5e86fc7", "musician"))
        items.append(wp("music-festival", "Music Festival", "photo-1506157786151-b8491531f063", "musician"))
        items.append(wp("neon-performer", "Neon Performer", "photo-1571019613454-1cb2f99b2d8b", "musician"))
        items.append(wp("guitar-solo", "Guitar Solo", "photo-1415201364774-f6f0bb35f28f", "musician"))
        items.append(wp("crowd-energy", "Crowd Energy", "photo-1470225620780-dba8ba36b745", "musician"))

        // --- Anime & Manga (hue ~295) ---
        items.append(wp("anime-sunset", "Anime Sunset", "photo-1578632767115-351597cf2477", "anime"))
        items.append(wp("anime-street", "Anime Street", "photo-1580477667995-2b94f01c9516", "anime"))
        items.append(wp("anime-cityscape", "Anime Cityscape", "photo-1607604276583-eef5d076aa5f", "anime"))
        items.append(wp("anime-night", "Anime Night", "photo-1608889825103-eb5ed706fc64", "anime"))
        items.append(wp("manga-world", "Manga World", "photo-1613376023733-0a73315d9b06", "anime"))
        items.append(wp("anime-sakura", "Anime Sakura", "photo-1614583225154-5fcdda07019e", "anime"))
        items.append(wp("anime-landscape", "Anime Landscape", "photo-1633356122102-3fe601e05bd2", "anime"))
        items.append(wp("anime-sky", "Anime Sky", "photo-1634986666676-ec8fd927c23d", "anime"))

        // --- Cyberpunk & Neon (hue ~310) ---
        items.append(wp("neon-alley", "Neon Alley", "photo-1519608487953-e999c86e7455", "cyberpunk"))
        items.append(wp("neon-rain", "Neon Rain", "photo-1557682250-33bd709cbe85", "cyberpunk"))
        items.append(wp("cyber-streets", "Cyber Streets", "photo-1557682224-5b8590cd9ec5", "cyberpunk"))
        items.append(wp("glitch-art", "Glitch Art", "photo-1550859492-d5da9d8e45f3", "cyberpunk"))

        // --- Alternative & Dark (hue ~330) ---
        items.append(wp("dark-smoke", "Dark Smoke", "photo-1553356084-58ef4a67b2a7", "alternative"))
        items.append(wp("dark-texture", "Dark Texture", "photo-1553949345-eb786d5ddac5", "alternative"))
        items.append(wp("moody-dark", "Moody Dark", "photo-1554034483-04fda0d3507b", "alternative"))
        items.append(wp("dark-waves", "Dark Waves", "photo-1558591710-4b4a1ae0f04d", "alternative"))
        items.append(wp("dark-gradient", "Dark Gradient", "photo-1614851099511-773084f6911d", "alternative"))
        items.append(wp("noir-abstract", "Noir Abstract", "photo-1617957718597-97e8f652643f", "alternative"))

        // --- Abstract (hue ~345) ---
        items.append(wp("color-splash", "Color Splash", "photo-1541701494587-cb58502866ab", "abstract"))
        items.append(wp("fluid-gradient", "Fluid Gradient", "photo-1579546929518-9e396f3cc809", "abstract"))
        items.append(wp("abstract-wave", "Abstract Wave", "photo-1604076913837-52ab5629fba9", "abstract"))
        items.append(wp("cosmic-art", "Cosmic Art", "photo-1618005182384-a83a8bd57fbe", "abstract"))
        items.append(wp("liquid-metal", "Liquid Metal", "photo-1578662996442-48f60103fc96", "abstract"))
        items.append(wp("color-burst", "Color Burst", "photo-1605721911519-3dfeb3be25e7", "abstract"))

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
