import SwiftUI

struct DesktopOverlayView: View {
    @ObservedObject var nowPlaying = NowPlayingManager.shared
    @ObservedObject var dockApps = DockAppsManager.shared
    @ObservedObject var wallpaperManager = WallpaperManager.shared
    @ObservedObject var imageCache = ImageCache.shared
    @ObservedObject var fontManager = FontManager.shared
    @State private var currentTime = Date()
    @State private var wallpaperScrollOffset: CGFloat = 0

    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)

                // Clock + Date — top center
                clockSection
                    .padding(.top, 36)
                    .frame(maxWidth: .infinity)

                // Left column: Now Playing + Lyrics
                VStack(alignment: .leading, spacing: 14) {
                    nowPlayingSection
                    if !nowPlaying.lyrics.isEmpty {
                        lyricsSection
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 280, alignment: .leading)
                .position(x: 172, y: geo.size.height * 0.45)

                // Center: App launcher
                appLauncherSection
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)

                // Right: Vertical wallpaper strip
                wallpaperStrip(height: geo.size.height)
                    .position(x: geo.size.width - 130, y: geo.size.height * 0.5)
            }
        }
        .onReceive(clockTimer) { currentTime = $0 }
    }

    // MARK: - Clock

    private var clockSection: some View {
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

    // MARK: - Now Playing

    private var nowPlayingSection: some View {
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
    }

    // MARK: - Lyrics

    private var lyricsSection: some View {
        GlassWidgetCard {
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
    }

    // MARK: - App Launcher

    private var appLauncherSection: some View {
        GlassWidgetCard {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(.cyan.opacity(0.7))
                    Text("Apps")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }

                let columns = Array(repeating: GridItem(.fixed(76), spacing: 14), count: min(dockApps.apps.count, 5))

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
        .frame(maxWidth: 500)
    }

    // MARK: - Wallpaper Vertical Strip

    private func wallpaperStrip(height: CGFloat) -> some View {
        GlassWidgetCard {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(.cyan.opacity(0.7))
                    Text("Wallpapers")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(wallpaperManager.wallpapers) { wp in
                            wallpaperCard(wp)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(10)
        }
        .frame(width: 200, height: min(height - 120, 600))
    }

    private func wallpaperCard(_ wp: WallpaperItem) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                wallpaperManager.applyWallpaper(wp)
            }
        }) {
            ZStack(alignment: .bottomLeading) {
                if let img = imageCache.image(for: wp) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 178, height: 100)
                        .clipped()
                } else {
                    LinearGradient(colors: wp.previewColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 178, height: 100)
                }

                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 40)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Text(wp.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)

                if wallpaperManager.currentWallpaper?.id == wp.id {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan, lineWidth: 2)
                }
            }
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial.opacity(0.35))
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Click-Through Hosting View

class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        if result === self { return nil }
        return result
    }
}
