import SwiftUI
import AVFoundation

struct WallpaperBrowserView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @State private var selectedWallpaper: WallpaperItem?
    @State private var showCarousel = true
    @State private var importerPresented = false
    @State private var dragOffset: CGFloat = 0
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                if showCarousel {
                    carouselView
                        .frame(maxHeight: .infinity)
                } else {
                    gridView
                        .frame(maxHeight: .infinity)
                }

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Wallpapers")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { withAnimation { showCarousel = true } }) {
                    Image(systemName: "rectangle.3.group")
                        .font(.title3)
                        .foregroundColor(showCarousel ? .cyan : .white.opacity(0.5))
                }
                .buttonStyle(.plain)

                Button(action: { withAnimation { showCarousel = false } }) {
                    Image(systemName: "square.grid.3x3")
                        .font(.title3)
                        .foregroundColor(!showCarousel ? .cyan : .white.opacity(0.5))
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 20)
                    .opacity(0.3)

                Button(action: { importerPresented = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.body)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cyan.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var carouselView: some View {
        GeometryReader { geometry in
            let cardWidth: CGFloat = min(280, geometry.size.width * 0.25)
            let cardHeight: CGFloat = cardWidth * 1.6
            let spacing: CGFloat = 20
            let centerX = geometry.size.width / 2

            ZStack {
                ForEach(Array(wallpaperManager.wallpapers.enumerated()), id: \.element.id) { index, wallpaper in
                    let offset = CGFloat(index - currentIndex)
                    let xPos = centerX + (offset * (cardWidth * 0.6 + spacing)) + dragOffset * 0.6
                    let distFromCenter = abs(xPos - centerX)
                    let maxDist = geometry.size.width / 2
                    let normalizedDist = min(distFromCenter / maxDist, 1.0)
                    let scale = 1.0 - (normalizedDist * 0.35)
                    let zIndex = 100.0 - Double(abs(index - currentIndex))
                    let rotation = -normalizedDist * 25 * (xPos < centerX ? -1 : 1)
                    let opacity = max(0.3, 1.0 - normalizedDist * 0.7)

                    WallpaperCarouselCard(
                        wallpaper: wallpaper,
                        isSelected: selectedWallpaper?.id == wallpaper.id,
                        width: cardWidth,
                        height: cardHeight
                    )
                    .scaleEffect(scale)
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .opacity(opacity)
                    .position(x: xPos, y: geometry.size.height / 2)
                    .zIndex(zIndex)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if selectedWallpaper?.id == wallpaper.id {
                                wallpaperManager.applyWallpaper(wallpaper)
                            } else {
                                selectedWallpaper = wallpaper
                                currentIndex = index
                            }
                        }
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if value.translation.width < -threshold {
                                currentIndex = min(currentIndex + 1, wallpaperManager.wallpapers.count - 1)
                            } else if value.translation.width > threshold {
                                currentIndex = max(currentIndex - 1, 0)
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)
            ], spacing: 16) {
                ForEach(wallpaperManager.wallpapers) { wallpaper in
                    WallpaperGridCard(
                        wallpaper: wallpaper,
                        isSelected: selectedWallpaper?.id == wallpaper.id
                    )
                    .onTapGesture {
                        withAnimation {
                            selectedWallpaper = wallpaper
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var bottomBar: some View {
        HStack {
            if let selected = selectedWallpaper {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text(selected.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(selected.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Button(action: {
                        wallpaperManager.applyWallpaper(selected)
                    }) {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                            Text("Apply")
                        }
                        .font(.body.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    GlassBackground(cornerRadius: 12)
                )
            } else {
                Text("Select a wallpaper to preview")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(16)
            }
        }
    }
}

struct WallpaperCarouselCard: View {
    let wallpaper: WallpaperItem
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: wallpaper.previewColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width, height: height)
                .overlay(
                    ZStack {
                        if wallpaper.type == .video {
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ?
                                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [.white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(wallpaper.name)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack {
                    Image(systemName: wallpaper.type == .video ? "film" : "photo")
                        .font(.caption2)
                    Text(wallpaper.type.rawValue)
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(
                    RoundedCorner(radius: 16, corners: [.bottomLeft, .bottomRight])
                )
            )
        }
        .frame(width: width, height: height)
        .shadow(color: isSelected ? .cyan.opacity(0.3) : .black.opacity(0.3), radius: isSelected ? 20 : 10)
    }
}

struct WallpaperGridCard: View {
    let wallpaper: WallpaperItem
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: wallpaper.previewColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(16/10, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.cyan : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )

            HStack {
                Text(wallpaper.name)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
                if wallpaper.type == .video {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(10)
            .background(.ultraThinMaterial.opacity(0.8))
            .clipShape(RoundedCorner(radius: 12, corners: [.bottomLeft, .bottomRight]))
        }
        .shadow(color: isSelected ? .cyan.opacity(0.3) : .clear, radius: 10)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: NSRectCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                       radius: topRight, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                       radius: bottomRight, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                       radius: bottomLeft, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                       radius: topLeft, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        path.closeSubpath()
        return path
    }
}

struct NSRectCorner: OptionSet {
    let rawValue: Int
    static let topLeft = NSRectCorner(rawValue: 1 << 0)
    static let topRight = NSRectCorner(rawValue: 1 << 1)
    static let bottomLeft = NSRectCorner(rawValue: 1 << 2)
    static let bottomRight = NSRectCorner(rawValue: 1 << 3)
    static let allCorners: NSRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}
