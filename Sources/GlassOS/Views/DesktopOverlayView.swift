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
    @ObservedObject var fontManager = FontManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassWidgetCard {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        if let art = nowPlaying.artwork {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 64)
                                .cornerRadius(8)
                                .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [.cyan.opacity(0.15), .blue.opacity(0.15)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white.opacity(0.25))
                                )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            if !nowPlaying.title.isEmpty {
                                Text(nowPlaying.title)
                                    .font(fontManager.widgetFont(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(nowPlaying.artist)
                                    .font(fontManager.widgetFont(size: 12))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)
                                if !nowPlaying.album.isEmpty {
                                    Text(nowPlaying.album)
                                        .font(fontManager.widgetFont(size: 11))
                                        .foregroundColor(.white.opacity(0.35))
                                        .lineLimit(1)
                                }
                            } else {
                                Text("Not Playing")
                                    .font(fontManager.widgetFont(size: 13))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            let progress = nowPlaying.duration > 0
                                ? min(nowPlaying.elapsedTime / nowPlaying.duration, 1.0)
                                : 0.0
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(progress), height: 3)
                            }
                        }
                        .frame(height: 3)

                        HStack {
                            Text(formatDuration(nowPlaying.elapsedTime))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                            Spacer()
                            Text(formatDuration(nowPlaying.duration))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                    .padding(.horizontal, 12)

                    HStack(spacing: 18) {
                        Button(action: { nowPlaying.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(nowPlaying.shuffleOn ? .cyan : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: { nowPlaying.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)

                        Button(action: { nowPlaying.togglePlayPause() }) {
                            Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)

                        Button(action: { nowPlaying.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)

                        Button(action: { nowPlaying.toggleRepeat() }) {
                            Image(systemName: nowPlaying.repeatMode == 2 ? "repeat.1" : "repeat")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(nowPlaying.repeatMode > 0 ? .cyan : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                    .padding(.bottom, 4)
                }
            }

            if !nowPlaying.timedLyrics.isEmpty {
                TimedLyricsView(
                    lyrics: nowPlaying.timedLyrics,
                    elapsedTime: nowPlaying.elapsedTime
                )
            } else if !nowPlaying.lyrics.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(nowPlaying.lyrics)
                        .font(fontManager.widgetFont(size: 12, weight: .light))
                        .foregroundColor(.white.opacity(0.65))
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 120)
            }

            if !nowPlaying.nextUp.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT UP")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(1)
                        .padding(.horizontal, 4)

                    ForEach(nowPlaying.nextUp) { track in
                        HStack(spacing: 6) {
                            Image(systemName: "music.note")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.25))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(track.title)
                                    .font(fontManager.widgetFont(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(fontManager.widgetFont(size: 9))
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
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
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(.system(size: index == activeIndex ? 14 : 12,
                                          weight: index == activeIndex ? .semibold : .light))
                            .foregroundColor(index == activeIndex ? .white : .white.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 160)
            .onChange(of: elapsedTime) { _ in
                guard !lyrics.isEmpty else { return }
                let newIndex = currentIndex()
                guard newIndex != activeIndex, newIndex < lyrics.count else { return }
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

// MARK: - App Launcher Widget (compact horizontal strip)

struct AppLauncherOverlayView: View {
    @ObservedObject var dockApps = DockAppsManager.shared
    @ObservedObject var wallpaperManager = WallpaperManager.shared

    var body: some View {
        let iconColor = DockAppsManager.adaptiveColor(for: wallpaperManager.currentWallpaper)

        GlassWidgetCard {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: min(dockApps.apps.count, 8))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(dockApps.apps) { app in
                    Button(action: { dockApps.launch(app) }) {
                        VStack(spacing: 3) {
                            Image(systemName: app.symbolName)
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(iconColor)
                                .frame(width: 34, height: 34)

                            Text(app.name)
                                .font(.system(size: 8))
                                .foregroundColor(iconColor.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(AppButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Wallpaper Carousel Widget

struct WallpaperCarouselOverlayView: View {
    @ObservedObject var wallpaperManager = WallpaperManager.shared
    @ObservedObject var imageCache = ImageCache.shared
    @ObservedObject var fontManager = FontManager.shared
    @State private var carouselIndex: Int = 0
    @State private var carouselDragOffset: CGFloat = 0
    @State private var scrollAccumulator: CGFloat = 0

    var body: some View {
        GlassWidgetCard {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let cardHeight: CGFloat = 80
                    let cardWidth: CGFloat = geo.size.width - 16
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
                        .allowsHitTesting(false)
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
                .frame(height: 30)
                .frame(maxHeight: .infinity, alignment: .bottom)

            Text(wp.name)
                .font(fontManager.widgetFont(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.bottom, 5)
        }
        .frame(width: width, height: height)
        .cornerRadius(6)
        .shadow(color: wallpaperManager.currentWallpaper?.id == wp.id ? .cyan.opacity(0.4) : .black.opacity(0.15), radius: wallpaperManager.currentWallpaper?.id == wp.id ? 10 : 4)
    }
}

// MARK: - Font Chooser Widget

struct FontChooserOverlayView: View {
    @ObservedObject var fontManager = FontManager.shared
    @State private var scrollAccumulator: CGFloat = 0

    private var fonts: [String] {
        FontManager.recommendedFonts
    }

    var body: some View {
        GlassWidgetCard {
            VStack(spacing: 0) {
                Text("FONT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(fonts, id: \.self) { family in
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    fontManager.clockFontFamily = family
                                }
                            }) {
                                Text(fontManager.displayName(for: family))
                                    .font(family.isEmpty
                                        ? .system(size: 10, weight: .medium)
                                        : .custom(family, size: 10))
                                    .foregroundColor(fontManager.clockFontFamily == family ? .cyan : .white.opacity(0.6))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(fontManager.clockFontFamily == family
                                                ? Color.white.opacity(0.08)
                                                : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self = self, let window = self.window,
                      event.window === window else { return event }
                let loc = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(loc) {
                    let delta = event.hasPreciseScrollingDeltas
                        ? event.scrollingDeltaY
                        : event.scrollingDeltaY * 10
                    self.onScroll?(delta)
                }
                return event
            }
        }
    }

    override func removeFromSuperview() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        super.removeFromSuperview()
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}

// MARK: - Accepting-First-Mouse Hosting View

class WidgetHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
