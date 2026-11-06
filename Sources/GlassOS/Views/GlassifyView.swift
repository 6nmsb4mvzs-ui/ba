import SwiftUI

struct GlassifyView: View {
    @ObservedObject var manager = GlassifyManager.shared
    @State private var searchText = ""

    var filteredApps: [RunningAppInfo] {
        if searchText.isEmpty { return manager.runningApps }
        return manager.runningApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 16)
                .padding(.horizontal, 24)

            globalControls
                .padding(.horizontal, 24)
                .padding(.top, 12)

            if !manager.glassifiedApps.isEmpty {
                activeAppsSection
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }

            appList
                .padding(.top, 16)

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Glassify")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            Text("Make any app transparent with a glass effect")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var globalControls: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "eye")
                        .foregroundColor(.cyan)
                    Text("Global Transparency")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int((1.0 - manager.globalAlpha) * 100))%")
                        .font(.body.monospacedDigit())
                        .foregroundColor(.cyan)
                }

                Slider(value: Binding(
                    get: { 1.0 - manager.globalAlpha },
                    set: { manager.updateAlpha(1.0 - $0) }
                ), in: 0...0.9, step: 0.05)
                .tint(.cyan)

                if !manager.glassifiedApps.isEmpty {
                    HStack {
                        Spacer()
                        Button(action: { manager.restoreAll() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Restore All")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.red.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
    }

    private var activeAppsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Active")
                    .font(.headline)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ForEach(manager.glassifiedApps) { app in
                    HStack(spacing: 10) {
                        if let running = manager.runningApps.first(where: { $0.bundleID == app.bundleID }) {
                            Image(nsImage: running.icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "app")
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Text(app.name)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer()

                        Text("\(Int((1.0 - app.alpha) * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white.opacity(0.5))

                        Slider(value: Binding(
                            get: { 1.0 - app.alpha },
                            set: { manager.updateAppAlpha(app.bundleID, alpha: 1.0 - $0) }
                        ), in: 0...0.9, step: 0.05)
                        .tint(.cyan)
                        .frame(width: 100)

                        Button(action: { manager.toggleApp(app.bundleID, name: app.name) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.4))
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
            )
            .padding(.horizontal, 24)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        AppRow(app: app) {
                            manager.toggleApp(app.bundleID, name: app.name)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}

struct AppRow: View {
    let app: RunningAppInfo
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onToggle) {
                HStack(spacing: 4) {
                    Image(systemName: app.isGlassified ? "sparkles" : "wand.and.stars")
                    Text(app.isGlassified ? "Active" : "Glassify")
                }
                .font(.caption.bold())
                .foregroundColor(app.isGlassified ? .black : .cyan)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(app.isGlassified ?
                            AnyShapeStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)) :
                            AnyShapeStyle(Color.white.opacity(0.08))
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(app.isGlassified ? Color.cyan.opacity(0.05) : Color.clear)
        )
    }
}
