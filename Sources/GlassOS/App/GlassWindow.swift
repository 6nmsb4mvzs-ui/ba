import AppKit

class GlassWindow: NSWindow {
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
        container.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]

        let glass = NSVisualEffectView(frame: container.bounds)
        glass.blendingMode = NSVisualEffectView.BlendingMode.behindWindow
        glass.state = NSVisualEffectView.State.active
        glass.material = NSVisualEffectView.Material.fullScreenUI
        glass.alphaValue = 0.55
        glass.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        container.addSubview(glass)

        view.frame = container.bounds
        view.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        container.addSubview(view)

        contentView = container
    }
}
