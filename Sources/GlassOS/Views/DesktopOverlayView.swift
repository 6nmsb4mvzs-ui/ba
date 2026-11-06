import SwiftUI

// MARK: - Clock Widget (non-interactive, displayed in its own panel)

struct ClockOverlayView: View {
    @ObservedObject var fontManager = FontManager.shared
    @State private var currentTime = Date()
    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 4) {
            Text(formatTime())
                .font(fontManager.clockFont())
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 3)
            Text(formatDate())
                .font(fontManager.dateFont())
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(clockTimer) { currentTime = $0 }
    }

    private func formatTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: currentTime)
    }

    private func formatDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: currentTime)
    }
}

// MARK: - Now Playing Widget

struct NowPlayingOverlayView: View {
    @ObservedObject var nowPlaying = NowPlayingManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassWidgetCard {
                HStack(spacing: 12) {
                    if let art = nowPlaying.artwork {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .cornerRadius(10)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [.cyan.opacity(0.15), .blue.opacity(0.15)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.25))
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if !nowPlaying.title.isEmpty {
                            Text(nowPlaying.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            Text(nowPlaying.artist)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(1)
                            if !nowPlaying.album.isEmpty {
                                Text(nowPlaying.album)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.35))
                                    .lineLimit(1)
                            }
                        } else {
                            Text("Not Playing")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }

            if !nowPlaying.timedLyrics.isEmpty {
                TimedLyricsView(
                    lyrics: nowPlaying.timedLyrics,
                    elapsedTime: nowPlaying.elapsedTime
                )
            } else if !nowPlaying.lyrics.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(nowPlaying.lyrics)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(.white.opacity(0.65))
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .frame(maxHeight: 220)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Timed Lyrics View

struct TimedLyricsView: View {
    let lyrics: [TimedLyricLine]
    let elapsedTime: Double
    @State private var activeIndex: Int = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(.system(size: index == activeIndex ? 15 : 13,
                                          weight: index == activeIndex ? .semibold : .light))
                            .foregroundColor(index == activeIndex ? .white : .white.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 220)
            .onChange(of: elapsedTime) { _ in
                let newIndex = currentIndex()
                guard newIndex != activeIndex else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    activeIndex = newIndex
                    proxy.scrollTo(lyrics[newIndex].id, anchor: .center)
                }
            }
        }
    }

    private func currentIndex() -> Int {
        var idx = 0
        for (i, line) in lyrics.enumerated() {
            if elapsedTime >= line.timestamp { idx = i }
        }
        return idx
    }
}

// MARK: - App Launcher Widget

struct AppLauncherOverlayView: View {
    @ObservedObject var dockApps = DockAppsManager.shared

    var body: some View {
        GlassWidgetCard {
            VStack(spacing: 14) {
                let columns = Array(repeating: GridItem(.fixed(76), spacing: 14), count: min(max(dockApps.apps.count, 1), 5))

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(dockApps.apps.prefix(15)) { app in
                        Button(action: { dockApps.launch(app) }) {
                            VStack(spacing: 5) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 46, height: 46)
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

                                Text(app.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineLimit(1)
                                    .frame(width: 66)
                            }
                        }
                        .buttonStyle(AppButtonStyle())
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Wallpaper Carousel Widget

struct WallpaperCarouselOverlayView: View {
    @ObservedObject var wallpaperManager = WallpaperManager.shared
    @ObservedObject var imageCache = ImageCache.shared
    @State private var carouselIndex: Int = 0
    @State private var carouselDragOffset: CGFloat = 0
    @State private var scrollAccumulator: CGFloat = 0

    var body: some View {
        GlassWidgetCard {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let cardHeight: CGFloat = 100
                    let cardWidth: CGFloat = geo.size.width - 20
                    let spacing: CGFloat = cardHeight * 0.75
                    let centerY = geo.size.height / 2
                    let wallpapers = wallpaperManager.wallpapers
                    let dragIndexOffset = carouselDragOffset / spacing

                    ZStack {
                        ForEach(Array(wallpapers.enumerated()), id: \.element.id) { index, wp in
                            let floatIndex = CGFloat(index) - CGFloat(carouselIndex) + dragIndexOffset
                            let yPos = centerY + (floatIndex * spacing)
                            let distFromCenter = abs(floatIndex)
                            let normalizedDist = min(distFromCenter / 3.0, 1.0)
                            let scale = 1.0 - (normalizedDist * 0.25)
                            let zIdx = 100.0 - Double(distFromCenter)
                            let rotation = -min(normalizedDist, 1.0) * 35 * (floatIndex < 0 ? -1 : 1)
                            let cardOpacity = max(0.3, 1.0 - normalizedDist * 0.6)

                            wallpaperCarouselCard(wp, width: cardWidth, height: cardHeight)
                                .scaleEffect(scale)
                                .rotation3DEffect(
                                    .degrees(rotation),
                                    axis: (x: 1, y: 0, z: 0),
                                    perspective: 0.5
                                )
                                .opacity(cardOpacity)
                                .position(x: geo.size.width / 2, y: yPos)
                                .zIndex(zIdx)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        carouselIndex = index
                                        wallpaperManager.applyWallpaper(wp)
                                    }
                                }
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                carouselDragOffset = value.translation.height
                            }
                            .onEnded { value in
                                let cardsMoved = Int(round(-value.translation.height / spacing))
                                let predicted = Int(round(-value.predictedEndTranslation.height / spacing))
                                let move = abs(predicted) > abs(cardsMoved) ? predicted : cardsMoved
                                let newIndex = max(0, min(wallpapers.count - 1, carouselIndex + move))
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    carouselIndex = newIndex
                                    carouselDragOffset = 0
                                }
                            }
                    )
                    .overlay(
                        ScrollWheelView { delta in
                            scrollAccumulator += delta
                            let threshold: CGFloat = 30
                            if abs(scrollAccumulator) >= threshold {
                                let steps = Int(scrollAccumulator / threshold)
                                let newIndex = max(0, min(wallpapers.count - 1, carouselIndex - steps))
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    carouselIndex = newIndex
                                }
                                scrollAccumulator = 0
                            }
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func wallpaperCarouselCard(_ wp: WallpaperItem, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let img = imageCache.image(for: wp) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                LinearGradient(colors: wp.previewColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: width, height: height)
            }

            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(height: 36)
                .frame(maxHeight: .infinity, alignment: .bottom)

            Text(wp.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

        }
        .frame(width: width, height: height)
        .cornerRadius(8)
        .shadow(color: wallpaperManager.currentWallpaper?.id == wp.id ? .cyan.opacity(0.4) : .black.opacity(0.15), radius: wallpaperManager.currentWallpaper?.id == wp.id ? 12 : 6)
    }
}

// MARK: - App Button Style

struct AppButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Glass Widget Card

struct GlassWidgetCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }
}

// MARK: - Scroll Wheel Handler

struct ScrollWheelView: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

class ScrollWheelNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 10
        onScroll?(delta)
    }
}

// MARK: - Accepting-First-Mouse Hosting View

class WidgetHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
