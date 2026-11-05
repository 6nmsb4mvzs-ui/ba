import SwiftUI

struct SystemMonitorView: View {
    @StateObject private var monitor = SystemMonitor()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("System Monitor")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    MonitorCard(
                        title: "CPU",
                        value: "\(monitor.cpuUsage)%",
                        icon: "cpu",
                        color: .cyan,
                        percentage: monitor.cpuUsage / 100.0
                    )

                    MonitorCard(
                        title: "Memory",
                        value: "\(monitor.memoryUsage)%",
                        icon: "memorychip",
                        color: .purple,
                        percentage: monitor.memoryUsage / 100.0
                    )

                    MonitorCard(
                        title: "GPU",
                        value: "\(monitor.gpuUsage)%",
                        icon: "gpu",
                        color: .green,
                        percentage: monitor.gpuUsage / 100.0
                    )

                    MonitorCard(
                        title: "Temperature",
                        value: "\(Int(monitor.temperature))°C",
                        icon: "thermometer.medium",
                        color: monitor.temperature > 80 ? .red : .orange,
                        percentage: min(monitor.temperature / 120.0, 1.0)
                    )
                }
                .padding(.horizontal, 24)

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.cyan)
                            Text("CPU History")
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        GeometryReader { geometry in
                            Path { path in
                                let data = monitor.cpuHistory
                                guard data.count > 1 else { return }
                                let step = geometry.size.width / CGFloat(data.count - 1)
                                path.move(to: CGPoint(x: 0, y: geometry.size.height * (1 - data[0] / 100)))
                                for i in 1..<data.count {
                                    path.addLine(to: CGPoint(
                                        x: CGFloat(i) * step,
                                        y: geometry.size.height * (1 - data[i] / 100)
                                    ))
                                }
                            }
                            .stroke(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                            )

                            Path { path in
                                let data = monitor.cpuHistory
                                guard data.count > 1 else { return }
                                let step = geometry.size.width / CGFloat(data.count - 1)
                                path.move(to: CGPoint(x: 0, y: geometry.size.height))
                                path.addLine(to: CGPoint(x: 0, y: geometry.size.height * (1 - data[0] / 100)))
                                for i in 1..<data.count {
                                    path.addLine(to: CGPoint(
                                        x: CGFloat(i) * step,
                                        y: geometry.size.height * (1 - data[i] / 100)
                                    ))
                                }
                                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.2), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        .frame(height: 120)
                    }
                    .padding(16)
                }
                .padding(.horizontal, 24)

                HStack(spacing: 16) {
                    InfoCard(title: "Uptime", value: monitor.uptime, icon: "clock")
                    InfoCard(title: "Processes", value: "\(monitor.processCount)", icon: "list.bullet")
                    InfoCard(title: "Disk", value: monitor.diskUsage, icon: "internaldrive")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

struct MonitorCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let percentage: Double

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Spacer()
                    Text(value)
                        .font(.title.bold().monospacedDigit())
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * max(0, min(percentage, 1.0)))
                    }
                }
                .frame(height: 6)
            }
            .padding(16)
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.cyan)
                Text(value)
                    .font(.body.bold().monospacedDigit())
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
    }
}
