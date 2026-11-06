import AppKit

class GlassWindow: NSWindow {
    private var glassContainer: NSView?

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        isOpaque = false
        backgroundColor = .clear
    }

    func setGlassContent(_ view: NSView) {
        let container = NSView(frame: contentRect(forFrameRect: frame))
        container.wantsLayer = true
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true
        container.autoresizingMask = [.width, .height]
        glassContainer = container

        let darkBg = NSView(frame: container.bounds)
        darkBg.wantsLayer = true
        darkBg.layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.35).cgColor
        darkBg.autoresizingMask = [.width, .height]
        container.addSubview(darkBg)

        let glass = NSVisualEffectView(frame: container.bounds)
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.material = .fullScreenUI
        glass.alphaValue = 0.10
        glass.autoresizingMask = [.width, .height]
        container.addSubview(glass)

        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)

        contentView = container
    }

    override func toggleFullScreen(_ sender: Any?) {
        super.toggleFullScreen(sender)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func updateCornerRadius(fullscreen: Bool) {
        glassContainer?.layer?.cornerRadius = fullscreen ? 0 : 16
    }
}
