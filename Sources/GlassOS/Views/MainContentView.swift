import SwiftUI

struct MainContentView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var updater: AutoUpdater
    @State private var selectedTab: SidebarTab = .wallpapers
    @State private var searchText = ""

    enum SidebarTab: String, CaseIterable {
        case wallpapers = "Wallpapers"
        case monitor = "System Monitor"
        case settings = "Settings"
        case updates = "Updates"
    }

    var body: some View {
        ZStack {
            Color.clear

            HStack(spacing: 0) {
                sidebarView
                    .frame(width: 220)

                Divider()
                    .opacity(0.3)

                mainContentArea
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(.linearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Text("GlassOS")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    SidebarButton(
                        title: tab.rawValue,
                        icon: iconFor(tab),
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            if updater.updateAvailable {
                GlassCard {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Update Available")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Text("v\(updater.latestVersion)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal, 12)
                .onTapGesture {
                    selectedTab = .updates
                }
            }

            HStack {
                Text("v\(AppVersion.current)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial.opacity(0.12))
    }

    private var mainContentArea: some View {
        Group {
            switch selectedTab {
            case .wallpapers:
                WallpaperBrowserView()
                    .environmentObject(wallpaperManager)
            case .monitor:
                SystemMonitorView()
            case .settings:
                SettingsView()
                    .environmentObject(wallpaperManager)
                    .environmentObject(updater)
            case .updates:
                UpdateView()
                    .environmentObject(updater)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconFor(_ tab: SidebarTab) -> String {
        switch tab {
        case .wallpapers: return "photo.on.rectangle.angled"
        case .monitor: return "gauge.with.dots.needle.33percent"
        case .settings: return "gearshape"
        case .updates: return "arrow.triangle.2.circlepath"
        }
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.7))
                Text(title)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
