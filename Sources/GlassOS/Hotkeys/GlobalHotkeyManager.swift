import AppKit
import Carbon

class GlobalHotkeyManager {
    private var eventHandler: (() -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?

    init(handler: @escaping () -> Void) {
        self.eventHandler = handler
        registerHotkey()
    }

    deinit {
        unregisterHotkey()
    }

    private func registerHotkey() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 99 {
                self?.eventHandler?()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 99 {
                self?.eventHandler?()
                return nil
            }
            return event
        }
    }

    private func unregisterHotkey() {
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
        }
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
        }
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
    }
}
