import SwiftUI

struct UpdateView: View {
    @EnvironmentObject var updater: AutoUpdater

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Updates")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                GlassCard {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: statusIcon)
                                .font(.system(size: 40))
                                .foregroundColor(statusColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(statusTitle)
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                Text(statusSubtitle)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()
                        }

                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 8, height: 8)
                                Text("Current: v\(AppVersion.current)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            if updater.updateAvailable {
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.3))
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Latest: v\(updater.latestVersion)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }

                            Spacer()
                        }

                        HStack(spacing: 12) {
                            GlassButton("Check for Updates", icon: "arrow.clockwise") {
                                updater.checkForUpdates()
                            }

                            if updater.updateAvailable {
                                GlassPrimaryButton("Update Now", icon: "arrow.down.circle") {
                                    updater.performUpdate()
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .padding(.horizontal, 24)

                if !updater.updateLog.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.cyan)
                                Text("Update Log")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { updater.updateLog.removeAll() }) {
                                    Text("Clear")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }

                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(updater.updateLog, id: \.self) { line in
                                        Text(line)
                                            .font(.caption.monospaced())
                                            .foregroundColor(.white.opacity(0.7))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 24)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.cyan)
                            Text("How Updates Work")
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            updateStep("1", text: "GlassOS checks GitHub for new versions")
                            updateStep("2", text: "When available, click 'Update Now'")
                            updateStep("3", text: "Source code is pulled and rebuilt automatically")
                            updateStep("4", text: "Restart the app to apply changes")
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func updateStep(_ number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.cyan)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.cyan.opacity(0.2)))
            Text(text)
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var statusIcon: String {
        switch updater.updateStatus {
        case .idle: return "checkmark.circle"
        case .checking: return "arrow.clockwise"
        case .available: return "arrow.down.circle"
        case .downloading: return "arrow.down"
        case .installing: return "gearshape.2"
        case .complete: return "checkmark.seal"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch updater.updateStatus {
        case .idle: return .green
        case .checking: return .cyan
        case .available: return .orange
        case .downloading, .installing: return .blue
        case .complete: return .green
        case .failed: return .red
        }
    }

    private var statusTitle: String {
        switch updater.updateStatus {
        case .idle: return "Up to Date"
        case .checking: return "Checking..."
        case .available(let v): return "Update Available (v\(v))"
        case .downloading: return "Downloading..."
        case .installing: return "Installing..."
        case .complete: return "Update Complete"
        case .failed(let e): return "Update Failed: \(e)"
        }
    }

    private var statusSubtitle: String {
        switch updater.updateStatus {
        case .idle: return "GlassOS is running the latest version"
        case .checking: return "Contacting GitHub..."
        case .available: return "A new version is ready to install"
        case .downloading: return "Pulling latest source from GitHub..."
        case .installing: return "Building and installing update..."
        case .complete: return "Restart the app to apply the update"
        case .failed: return "Check your internet connection and try again"
        }
    }
}
