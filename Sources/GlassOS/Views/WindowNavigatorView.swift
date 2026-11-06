import SwiftUI
import AppKit

struct WindowNavigatorView: View {
    let onDismiss: () -> Void
    @State private var windows: [WindowInfo] = []
    @State private var selectedIndex: Int = 0
    @State private var searchText = ""
    @State private var isVisible = false
    @State private var keyMonitor: Any?

    var filteredWindows: [WindowInfo] {
        if searchText.isEmpty { return windows }
        return windows.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.ownerName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(isVisible ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissView() }

            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Search windows...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .padding(16)
                .background(GlassBackground(cornerRadius: 14))
                .frame(maxWidth: 600)

                if filteredWindows.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No windows found")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(40)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(filteredWindows.enumerated()), id: \.element.id) { index, windowItem in
                                WindowCard(
                                    windowItem: windowItem,
                                    isSelected: index == selectedIndex
                                )
                                .onTapGesture {
                                    focusWindow(windowItem)
                                    dismissView()
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: 320)
                }

                HStack(spacing: 24) {
                    KeyHint(key: "←→", label: "Navigate")
                    KeyHint(key: "↵", label: "Switch")
                    KeyHint(key: "ESC", label: "Close")
                }
                .padding(.top, 8)
            }
            .scaleEffect(isVisible ? 1.0 : 0.9)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .onAppear {
            loadWindows()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isVisible = true
            }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                return self.handleKeyEvent(event)
            }
        }
        .onDisappear {
            if let m = keyMonitor {
                NSEvent.removeMonitor(m)
                keyMonitor = nil
            }
        }
    }

    private func loadWindows() {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return
        }

        windows = windowList.compactMap { info -> WindowInfo? in
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { return nil }

            let name = info[kCGWindowName as String] as? String ?? ownerName
            if name.isEmpty || ownerName == "Window Server" || ownerName == "GlassOS" {
                return nil
            }

            let x = (boundsDict["X"] as? NSNumber)?.doubleValue ?? 0
            let y = (boundsDict["Y"] as? NSNumber)?.doubleValue ?? 0
            let w = (boundsDict["Width"] as? NSNumber)?.doubleValue ?? 0
            let h = (boundsDict["Height"] as? NSNumber)?.doubleValue ?? 0

            return WindowInfo(
                id: Int(windowID),
                name: name,
                ownerName: ownerName,
                bounds: CGRect(x: x, y: y, width: w, height: h)
            )
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 123:
            withAnimation { selectedIndex = max(0, selectedIndex - 1) }
            return nil
        case 124:
            withAnimation { selectedIndex = min(filteredWindows.count - 1, selectedIndex + 1) }
            return nil
        case 36:
            if selectedIndex < filteredWindows.count {
                focusWindow(filteredWindows[selectedIndex])
                dismissView()
            }
            return nil
        case 53:
            dismissView()
            return nil
        default:
            return event
        }
    }

    private func focusWindow(_ windowItem: WindowInfo) {
        let apps = NSWorkspace.shared.runningApplications
        if let runningApp = apps.first(where: { $0.localizedName == windowItem.ownerName }) {
            if #available(macOS 14.0, *) {
                runningApp.activate()
            } else {
                runningApp.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }

    private func dismissView() {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

struct WindowCard: View {
    let windowItem: WindowInfo
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 140)

                VStack(spacing: 8) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.4))
                    Text(windowItem.ownerName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Text(windowItem.name)
                .font(.caption.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 180)

            Text(windowItem.ownerName)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(12)
        .background(GlassBackground(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(color: isSelected ? .cyan.opacity(0.3) : .clear, radius: 15)
    }
}

struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.caption.monospaced().bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

struct WindowInfo: Identifiable {
    let id: Int
    let name: String
    let ownerName: String
    let bounds: CGRect
}
