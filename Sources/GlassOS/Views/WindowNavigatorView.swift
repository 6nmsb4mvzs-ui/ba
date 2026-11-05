import SwiftUI
import AppKit

struct WindowNavigatorView: View {
    let onDismiss: () -> Void
    @State private var windows: [WindowInfo] = []
    @State private var selectedIndex: Int = 0
    @State private var searchText = ""
    @State private var isVisible = false

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
                .onTapGesture { dismiss() }

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
                            ForEach(Array(filteredWindows.enumerated()), id: \.element.id) { index, window in
                                WindowCard(
                                    window: window,
                                    isSelected: index == selectedIndex
                                )
                                .onTapGesture {
                                    focusWindow(window)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: 320)
                }

                HStack(spacing: 24) {
                    KeyHint(key: "←→", description: "Navigate")
                    KeyHint(key: "↵", description: "Switch")
                    KeyHint(key: "ESC", description: "Close")
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
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyEvent(event)
                return nil
            }
        }
    }

    private func loadWindows() {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        windows = windowList.compactMap { info -> WindowInfo? in
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { return nil }

            let name = info[kCGWindowName as String] as? String ?? ownerName
            if name.isEmpty || ownerName == "Window Server" || ownerName == "GlassOS" { return nil }

            return WindowInfo(
                id: Int(windowID),
                name: name,
                ownerName: ownerName,
                bounds: CGRect(
                    x: bounds["X"] ?? 0,
                    y: bounds["Y"] ?? 0,
                    width: bounds["Width"] ?? 0,
                    height: bounds["Height"] ?? 0
                )
            )
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        switch event.keyCode {
        case 123: // Left arrow
            withAnimation { selectedIndex = max(0, selectedIndex - 1) }
        case 124: // Right arrow
            withAnimation { selectedIndex = min(filteredWindows.count - 1, selectedIndex + 1) }
        case 36: // Return
            if selectedIndex < filteredWindows.count {
                focusWindow(filteredWindows[selectedIndex])
                dismiss()
            }
        case 53: // Escape
            dismiss()
        default:
            break
        }
    }

    private func focusWindow(_ window: WindowInfo) {
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.localizedName == window.ownerName }) {
            app.activate()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

struct WindowCard: View {
    let window: WindowInfo
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
                    Text(window.ownerName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Text(window.name)
                .font(.caption.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 180)

            Text(window.ownerName)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(12)
        .background(
            GlassBackground(cornerRadius: 14)
        )
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
    let description: String

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
            Text(description)
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
