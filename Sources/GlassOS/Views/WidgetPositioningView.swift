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
    @State private var tempPositions: [String: CGPoint] = [:]
    @State private var selectedWidget: String?
    @State private var saved = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()

                GridOverlay(size: geo.size)

                ForEach(WidgetLayoutManager.widgetDefinitions, id: \.key) { def in
                    let pos = tempPositions[def.key] ?? CGPoint(
                        x: geo.size.width * def.defaultNormX,
                        y: geo.size.height * (1 - def.defaultNormY)
                    )

                    WidgetPreview(
                        label: def.label,
                        size: CGSize(width: def.width, height: def.height),
                        isSelected: selectedWidget == def.key
                    )
                    .position(pos)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                selectedWidget = def.key
                                let newX = min(max(value.location.x, def.width / 2), geo.size.width - def.width / 2)
                                let newY = min(max(value.location.y, def.height / 2), geo.size.height - def.height / 2)
                                tempPositions[def.key] = CGPoint(x: newX, y: newY)
                            }
                    )
                }

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
                            Text("Return = Save")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                            Text("Esc = Cancel")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .onAppear {
                loadCurrentPositions(screenSize: geo.size)
            }
            .background(
                KeyEventHandler(
                    onEscape: { dismiss() },
                    onReturn: { saveAndDismiss(screenSize: geo.size) }
                )
            )
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

    private func saveAndDismiss(screenSize: CGSize) {
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

    private func dismiss() {
        if let window = NSApp.keyWindow, window.level == .screenSaver {
            window.orderOut(nil)
        }
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

struct KeyEventHandler: NSViewRepresentable {
    var onEscape: () -> Void
    var onReturn: () -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onEscape = onEscape
        view.onReturn = onReturn
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onEscape = onEscape
        nsView.onReturn = onReturn
    }
}

class KeyCaptureView: NSView {
    var onEscape: (() -> Void)?
    var onReturn: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onEscape?()
        case 36: onReturn?()
        default: super.keyDown(with: event)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
