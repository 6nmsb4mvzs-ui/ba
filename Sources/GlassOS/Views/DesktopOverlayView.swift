import SwiftUI

struct DesktopOverlayView: View {
    @ObservedObject var nowPlaying = NowPlayingManager.shared
    @ObservedObject var dockApps = DockAppsManager.shared
    @ObservedObject var wallpaperManager = WallpaperManager.shared
    @ObservedObject var imageCache = ImageCache.shared
    @State private var currentTime = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear

                VStack(spacing: 0) {
                    clockWidget
                        .padding(.top, geo.size.height * 0.03)

                    Spacer(minLength: 0)
                }

                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        nowPlayingWidget
                        if !nowPlaying.lyrics.isEmpty {
                            lyricsWidget
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: 280)
                    .padding(.top, geo.size.height * 0.1)
                    .padding(.leading, 32)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 0) {
                        wallpaperWidget
                        Spacer(minLength: 0)
                    }
                    .frame(width: 220)
                    .padding(.top, geo.size.height * 0.06)
                    .padding(.trailing, 32)
                }

                appLauncherWidget
                    .padding(.top, geo.size.height * 0.15)
            }
        }
        .onReceive(timer) { currentTime = $0 }
    }

    // MARK: - Clock

    private var clockWidget: some View {
        VStack(spacing: 2) {
            Text(timeFormatter.string(from: currentTime))
                .font(.system(size: 64, weight: .ultraLight, design: .default))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)

            Text(dateFormatter.string(from: currentTime))
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Now Playing

    private var nowPlayingWidget: some View {
        GlassWidgetCard {
            VStack(alignment: .leading, spacing: 10) {
                if let art = nowPlaying.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 248, height: 248)
                        .cornerRadius(12)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.cyan.opacity(0.2), .blue.opacity(0.2)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 248, height: 140)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }

                if !nowPlaying.title.isEmpty {
                    Text(nowPlaying.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(nowPlaying.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                } else {
                    Text("Nothing Playing")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(16)
        }
    }

    // MARK: - Lyrics

    private var lyricsWidget: some View {
        GlassWidgetCard {
            ScrollView(showsIndicators: false) {
                Text(nowPlaying.lyrics)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(16)
        }
    }

    // MARK: - App Launcher

    private var appLauncherWidget: some View {
        GlassWidgetCard {
            VStack(spacing: 12) {
                Text("Apps")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(80), spacing: 12), count: 5), spacing: 16) {
                    ForEach(dockApps.apps.prefix(10)) { app in
                        Button(action: { dockApps.launch(app) }) {
                            VStack(spacing: 6) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 48, height: 48)
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                                Text(app.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: 480)
    }

    // MARK: - Wallpaper Chooser

    private var wallpaperWidget: some View {
        GlassWidgetCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Wallpapers")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(wallpaperManager.wallpapers.prefix(20)) { wp in
                            wallpaperThumbnail(wp)
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 500)
    }

    private func wallpaperThumbnail(_ wp: WallpaperItem) -> some View {
        Button(action: { wallpaperManager.applyWallpaper(wp) }) {
            ZStack {
                if let img = imageCache.image(for: wp) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 88, height: 56)
                        .clipped()
                } else {
                    LinearGradient(colors: wp.previewColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 88, height: 56)
                }

                if wallpaperManager.currentWallpaper?.id == wp.id {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.cyan, lineWidth: 2)
                }
            }
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
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
                        .fill(.ultraThinMaterial.opacity(0.4))
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.25))
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            )
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
