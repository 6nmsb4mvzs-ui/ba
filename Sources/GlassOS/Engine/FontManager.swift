import SwiftUI
import AppKit

class FontManager: ObservableObject {
    static let shared = FontManager()

    @AppStorage("clockFontFamily") var clockFontFamily: String = ""
    @AppStorage("clockFontWeight") var clockFontWeight: String = "ultraLight"
    @AppStorage("clockFontSize") var clockFontSize: Double = 64

    static let recommendedFonts = [
        "", "Helvetica Neue", "Avenir", "Avenir Next", "Futura",
        "SF Pro", "SF Mono", "Menlo", "Monaco", "Courier New",
        "Georgia", "Baskerville", "Didot", "Palatino",
        "Gill Sans", "Optima", "Verdana", "Trebuchet MS"
    ]

    static let weightOptions: [(String, Font.Weight)] = [
        ("Ultra Light", .ultraLight),
        ("Thin", .thin),
        ("Light", .light),
        ("Regular", .regular),
        ("Medium", .medium),
        ("Semibold", .semibold),
        ("Bold", .bold),
    ]

    var allFontFamilies: [String] {
        let families = NSFontManager.shared.availableFontFamilies.sorted()
        return [""] + families
    }

    var resolvedWeight: Font.Weight {
        switch clockFontWeight {
        case "ultraLight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return .ultraLight
        }
    }

    func clockFont(size: CGFloat? = nil) -> Font {
        let s = size ?? CGFloat(clockFontSize)
        if clockFontFamily.isEmpty {
            return .system(size: s, weight: resolvedWeight, design: .default)
        }
        return .custom(clockFontFamily, size: s).weight(resolvedWeight)
    }

    func dateFont(size: CGFloat = 18) -> Font {
        if clockFontFamily.isEmpty {
            return .system(size: size, weight: .light)
        }
        return .custom(clockFontFamily, size: size).weight(.light)
    }

    func displayName(for family: String) -> String {
        family.isEmpty ? "System Default" : family
    }
}
