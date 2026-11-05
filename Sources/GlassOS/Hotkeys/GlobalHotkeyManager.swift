import AppKit
import Carbon

class GlobalHotkeyManager {
    private var eventHandler: (() -> Void)?
    private var monitor: Any?
    private var hotKeyRef: EventHotKeyRef?

    init(handler: @escaping () -> Void) {
        self.eventHandler = handler
        registerHotkey()
    }

    deinit {
        unregisterHotkey()
    }

    private func registerHotkey() {
        // F3 key = keycode 99
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 99 { // F3
                self?.eventHandler?()
            }
        }

        // Also monitor local events
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 99 { // F3
                self?.eventHandler?()
                return nil
            }
            return event
        }
    }

    private func unregisterHotkey() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
}
