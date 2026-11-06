import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var updater: AutoUpdater
    @ObservedObject var fontManager = FontManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("hotkey_enabled") private var hotkeyEnabled = true
    @AppStorage("wallpaper_quality") private var wallpaperQuality = "High"
    @State private var showAllFonts = false

    let qualities = ["Low", "Medium", "High", "Ultra"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                GlassCard {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("General")
                        GlassToggle(title: "Launch at Login", isOn: $launchAtLogin)
                        Divider().opacity(0.2).padding(.horizontal, 16)
                        GlassToggle(title: "Show Menu Bar Icon", isOn: $showMenuBar)
                    }
                }
                .padding(.horizontal, 24)

                GlassCard {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Fonts")

                        VStack(spacing: 0) {
                            HStack {
                                Text("Clock Font")
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("", selection: $fontManager.clockFontFamily) {
                                    Text("System Default").tag("")
                                    Divider()
                                    if showAllFonts {
                                        ForEach(fontManager.allFontFamilies.dropFirst(), id: \.self) { family in
                                            Text(family).tag(family)
                                        }
                                    } else {
                                        ForEach(FontManager.recommendedFonts.dropFirst(), id: \.self) { family in
                                            Text(family).tag(family)
                                        }
                                    }
                                }
                                .frame(width: 200)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            Divider().opacity(0.2).padding(.horizontal, 16)

                            HStack {
                                Spacer()
                                Button(action: { showAllFonts.toggle() }) {
                                    Text(showAllFonts ? "Show Recommended" : "Show All Fonts")
                                        .font(.caption)
                                        .foregroundColor(.cyan)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)

                            Divider().opacity(0.2).padding(.horizontal, 16)

                            HStack {
                                Text("Weight")
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("", selection: $fontManager.clockFontWeight) {
                                    ForEach(FontManager.weightOptions, id: \.0) { name, _ in
                                        Text(name).tag(name.lowercased().replacingOccurrences(of: " ", with: ""))
                                    }
                                }
                                .frame(width: 200)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            Divider().opacity(0.2).padding(.horizontal, 16)

                            HStack {
                                Text("Size")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(fontManager.clockFontSize))pt")
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(.cyan)
                                    .frame(width: 50, alignment: .trailing)
                                Slider(value: $fontManager.clockFontSize, in: 32...120, step: 2)
                                    .frame(width: 150)
                                    .tint(.cyan)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            Divider().opacity(0.2).padding(.horizontal, 16)

                            VStack(spacing: 4) {
                                Text("12:34")
                                    .font(fontManager.clockFont(size: 42))
                                    .foregroundColor(.white)
                                Text("Monday, 1 January")
                                    .font(fontManager.dateFont(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    }
                }
                .padding(.horizontal, 24)

                GlassCard {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Hotkeys")
                        GlassToggle(title: "Enable F3 Window Navigator", isOn: $hotkeyEnabled)
                        HStack {
                            Text("Window Navigator")
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("F3")
                                .font(.body.monospaced())
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 24)

                GlassCard {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("Wallpaper Engine")

                        HStack {
                            Text("Quality")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $wallpaperQuality) {
                                ForEach(qualities, id: \.self) { quality in
                                    Text(quality).tag(quality)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 260)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().opacity(0.2).padding(.horizontal, 16)

                        HStack {
                            Text("Wallpaper Folder")
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                NSWorkspace.shared.open(wallpaperManager.wallpaperDirectory)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                    Text("Open")
                                }
                                .font(.caption)
                                .foregroundColor(.cyan)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().opacity(0.2).padding(.horizontal, 16)

                        HStack {
                            Text("Active Wallpaper")
                                .foregroundColor(.white)
                            Spacer()
                            Text(wallpaperManager.currentWallpaper?.name ?? "None")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if wallpaperManager.currentWallpaper != nil {
                            HStack {
                                Spacer()
                                GlassButton("Remove Wallpaper", icon: "xmark.circle", color: .red) {
                                    wallpaperManager.removeWallpaper()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.horizontal, 24)

                GlassCard {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("About")
                        infoRow("Version", value: "v\(AppVersion.current)")
                        Divider().opacity(0.2).padding(.horizontal, 16)
                        infoRow("Build", value: "Swift / SwiftUI")
                        Divider().opacity(0.2).padding(.horizontal, 16)
                        infoRow("Platform", value: "macOS 13+")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.cyan)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
