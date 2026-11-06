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
        let visualEffect = NSVisualEffectView(frame: contentRect(forFrameRect: frame))
        visualEffect.blendingMode = NSVisualEffectView.BlendingMode.behindWindow
        visualEffect.state = NSVisualEffectView.State.active
        visualEffect.material = NSVisualEffectView.Material.fullScreenUI
        visualEffect.alphaValue = 0.82
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        visualEffect.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]

        view.frame = visualEffect.bounds
        view.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        visualEffect.addSubview(view)

        contentView = visualEffect
    }
}
