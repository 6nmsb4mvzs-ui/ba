import AppKit

class GlassWindow: NSWindow {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true

        contentView = visualEffect
        isOpaque = false
        backgroundColor = .clear
    }

    override var contentView: NSView? {
        didSet {
            if let hosting = contentView, !(contentView is NSVisualEffectView) {
                let visualEffect = NSVisualEffectView(frame: bounds)
                visualEffect.blendingMode = .behindWindow
                visualEffect.state = .active
                visualEffect.material = .hudWindow
                visualEffect.wantsLayer = true
                visualEffect.layer?.cornerRadius = 16
                visualEffect.layer?.masksToBounds = true
                visualEffect.autoresizingMask = [.width, .height]

                hosting.frame = visualEffect.bounds
                hosting.autoresizingMask = [.width, .height]
                visualEffect.addSubview(hosting)

                super.contentView = visualEffect
            }
        }
    }
}
