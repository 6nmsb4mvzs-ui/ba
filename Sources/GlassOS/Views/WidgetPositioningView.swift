import SwiftUI
import AppKit

struct PositioningLaunchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(.cyan)

            Text("Widget Positioning")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("Open the positioning overlay to drag widgets\nto your preferred positions on the desktop.")
                .font(.body)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button(action: {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.openPositioning()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3.topleft.filled")
                    Text("Open Positioning Overlay")
                }
                .font(.body.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cyan.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Text("Return saves positions  ·  Esc cancels")
                .font(.caption)
                .foregroundColor(.white.opacity(0.35))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WidgetPositioningView: View {
    var closePanel: () -> Void

    @State private var tempPositions: [String: CGPoint] = [:]
    @State private var selectedWidget: String?
    @State private var saved = false
    @State private var keyMonitor: Any?
    @State private var screenSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.45)

                GridOverlay(size: geo.size)

                ForEach(WidgetLayoutManager.widgetDefinitions, id: \.key) { def in
                    widgetDraggable(def: def, geo: geo)
                }

                instructionBar
            }
            .onAppear {
                screenSize = geo.size
                loadCurrentPositions(screenSize: geo.size)
                installKeyMonitor(screenSize: geo.size)
            }
            .onDisappear {
                removeKeyMonitor()
            }
            .onChange(of: geo.size) { newSize in
                screenSize = newSize
            }
        }
    }

    private func widgetDraggable(def: WidgetLayout, geo: GeometryProxy) -> some View {
        let pos = tempPositions[def.key] ?? CGPoint(
            x: geo.size.width * def.defaultNormX,
            y: geo.size.height * (1 - def.defaultNormY)
        )

        return WidgetPreview(
            label: def.label,
            size: CGSize(width: def.width, height: def.height),
            isSelected: selectedWidget == def.key
        )
        .position(pos)
        .gesture(
            DragGesture()
                .onChanged { value in
                    selectedWidget = def.key
                    let halfW = def.width / 2
                    let halfH = def.height / 2
                    let newX = min(max(value.location.x, halfW), geo.size.width - halfW)
                    let newY = min(max(value.location.y, halfH), geo.size.height - halfH)
                    tempPositions[def.key] = CGPoint(x: newX, y: newY)
                }
                .onEnded { _ in }
        )
    }

    private var instructionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                if saved {
                    Text("Positions saved! Press Esc to close.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    Text("Drag widgets to reposition")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    keyHint("Return", "Save", .cyan)
                    keyHint("Esc", "Cancel", .orange)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.6))
            )
            .padding(.bottom, 40)
        }
    }

    private func keyHint(_ key: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.15)))
            Text("= \(label)")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(color)
    }

    private func installKeyMonitor(screenSize: CGSize) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 53: // Esc
                closePanel()
                return nil
            case 36: // Return
                if !saved {
                    savePositions(screenSize: screenSize)
                } else {
                    closePanel()
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func loadCurrentPositions(screenSize: CGSize) {
        let layout = WidgetLayoutManager.shared
        for def in WidgetLayoutManager.widgetDefinitions {
            let norm = layout.normalizedPosition(for: def.key) ?? layout.defaultNormalizedPosition(for: def.key)
            tempPositions[def.key] = CGPoint(
                x: screenSize.width * norm.x,
                y: screenSize.height * (1 - norm.y)
            )
        }
    }

    private func savePositions(screenSize: CGSize) {
        let layout = WidgetLayoutManager.shared
        for def in WidgetLayoutManager.widgetDefinitions {
            guard let pos = tempPositions[def.key] else { continue }
            let normX = pos.x / screenSize.width
            let normY = 1 - (pos.y / screenSize.height)
            layout.savePosition(CGPoint(x: normX, y: normY), for: def.key)
        }
        NotificationCenter.default.post(name: .init("WidgetLayoutDidChange"), object: nil)
        saved = true
    }
}

struct WidgetPreview: View {
    let label: String
    let size: CGSize
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.cyan : Color.white.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )

            VStack(spacing: 4) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: isSelected ? .cyan.opacity(0.3) : .clear, radius: 10)
    }
}

struct GridOverlay: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let spacing: CGFloat = 60
            let color = Color.white.opacity(0.04)

            var col: CGFloat = spacing
            while col < canvasSize.width {
                context.stroke(
                    Path { p in p.move(to: CGPoint(x: col, y: 0)); p.addLine(to: CGPoint(x: col, y: canvasSize.height)) },
                    with: .color(color), lineWidth: 0.5
                )
                col += spacing
            }
            var row: CGFloat = spacing
            while row < canvasSize.height {
                context.stroke(
                    Path { p in p.move(to: CGPoint(x: 0, y: row)); p.addLine(to: CGPoint(x: canvasSize.width, y: row)) },
                    with: .color(color), lineWidth: 0.5
                )
                row += spacing
            }

            let centerColor = Color.white.opacity(0.08)
            let cx = canvasSize.width / 2, cy = canvasSize.height / 2
            context.stroke(
                Path { p in p.move(to: CGPoint(x: cx, y: 0)); p.addLine(to: CGPoint(x: cx, y: canvasSize.height)) },
                with: .color(centerColor), lineWidth: 1
            )
            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: cy)); p.addLine(to: CGPoint(x: canvasSize.width, y: cy)) },
                with: .color(centerColor), lineWidth: 1
            )
        }
    }
}
