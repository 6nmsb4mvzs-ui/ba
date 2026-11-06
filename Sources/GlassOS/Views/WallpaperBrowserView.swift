import SwiftUI
import AVFoundation

struct WallpaperBrowserView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @ObservedObject var imageCache = ImageCache.shared
    @State private var selectedWallpaper: WallpaperItem?
    @State private var showCarousel = true
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var keyMonitor: Any?

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
                        .clipped()
                } else {
                    gridView
                        .frame(maxHeight: .infinity)
                }

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .zIndex(10)
            }
        }
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if showCarousel {
                    let wallpapers = wallpaperManager.wallpapers
                    switch event.keyCode {
                    case 123: // left arrow
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentIndex = max(0, currentIndex - 1)
                            selectedWallpaper = wallpapers[currentIndex]
                        }
                        return nil
                    case 124: // right arrow
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentIndex = min(wallpapers.count - 1, currentIndex + 1)
                            selectedWallpaper = wallpapers[currentIndex]
                        }
                        return nil
                    case 36: // return — apply selected
                        if let sel = selectedWallpaper {
                            wallpaperManager.applyWallpaper(sel)
                        }
                        return nil
                    default:
                        break
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let m = keyMonitor {
                NSEvent.removeMonitor(m)
                keyMonitor = nil
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
            }
        }
    }

    private var carouselView: some View {
        GeometryReader { geometry in
            let cardWidth: CGFloat = min(280, geometry.size.width * 0.25)
            let cardHeight: CGFloat = cardWidth * 1.6
            let centerX = geometry.size.width / 2
            let wallpapers = wallpaperManager.wallpapers
            let spacing: CGFloat = cardWidth * 0.65
            let dragIndexOffset = dragOffset / spacing

            ZStack {
                ForEach(Array(wallpapers.enumerated()), id: \.element.id) { index, wallpaper in
                    let floatIndex = CGFloat(index) - CGFloat(currentIndex) + dragIndexOffset
                    let xPos = centerX + (floatIndex * spacing)
                    let distFromCenter = abs(floatIndex)
                    let normalizedDist = min(distFromCenter / (geometry.size.width / (2 * spacing)), 1.0)
                    let scale = 1.0 - (normalizedDist * 0.35)
                    let zIndex = 100.0 - Double(distFromCenter)
                    let rotation = -min(normalizedDist, 1.0) * 25 * (floatIndex < 0 ? -1 : 1)
                    let cardOpacity = max(0.3, 1.0 - normalizedDist * 0.7)

                    WallpaperCarouselCard(
                        wallpaper: wallpaper,
                        isSelected: selectedWallpaper?.id == wallpaper.id,
                        width: cardWidth,
                        height: cardHeight,
                        cachedImage: imageCache.image(for: wallpaper)
                    )
                    .scaleEffect(scale)
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .opacity(cardOpacity)
                    .position(x: xPos, y: geometry.size.height / 2)
                    .zIndex(zIndex)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedWallpaper = wallpaper
                            currentIndex = index
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .background(WindowDragBlocker())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let cardsMoved = Int(round(-value.translation.width / spacing))
                        let predicted = Int(round(-value.predictedEndTranslation.width / spacing))
                        let move = abs(predicted) > abs(cardsMoved) ? predicted : cardsMoved
                        let newIndex = max(0, min(wallpapers.count - 1, currentIndex + move))
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentIndex = newIndex
                            selectedWallpaper = wallpapers[newIndex]
                            dragOffset = 0
                        }
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    break
                case .ended:
                    break
                @unknown default:
                    break
                }
            }
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
                        isSelected: selectedWallpaper?.id == wallpaper.id,
                        cachedImage: imageCache.image(for: wallpaper)
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
                        Text(selected.category?.capitalized ?? selected.type.rawValue)
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
                .background(GlassBackground(cornerRadius: 12))
            } else {
                HStack(spacing: 24) {
                    KeyHintSmall(key: "←→", label: "Navigate")
                    KeyHintSmall(key: "Drag", label: "Scroll")
                    KeyHintSmall(key: "Click", label: "Select")
                    KeyHintSmall(key: "↵", label: "Apply")
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            }
        }
    }
}

struct KeyHintSmall: View {
    let key: String
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption2.monospaced().bold())
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.1)))
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

struct WallpaperCarouselCard: View {
    let wallpaper: WallpaperItem
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat
    let cachedImage: NSImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let nsImage = cachedImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
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
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white.opacity(0.5))
                    )
            }

            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected ?
                        LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isSelected ? 2 : 1
                )
                .frame(width: width, height: height)

            VStack(alignment: .leading, spacing: 4) {
                Text(wallpaper.name)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack {
                    Image(systemName: iconForType)
                        .font(.caption2)
                    Text(wallpaper.category?.capitalized ?? wallpaper.type.rawValue)
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

    private var iconForType: String {
        switch wallpaper.type {
        case .video: return "film"
        case .remote: return "arrow.down.circle"
        case .image: return "photo"
        case .gradient: return "paintpalette"
        }
    }
}

struct WallpaperGridCard: View {
    let wallpaper: WallpaperItem
    let isSelected: Bool
    let cachedImage: NSImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let nsImage = cachedImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minHeight: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
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
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white.opacity(0.4))
                    )
            }

            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.cyan : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)

            HStack {
                Text(wallpaper.name)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(10)
            .background(.ultraThinMaterial.opacity(0.4))
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
        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                       radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                       radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                       radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                       radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
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

class NoDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NoDragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
