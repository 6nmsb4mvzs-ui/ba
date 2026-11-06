import AppKit
import Combine

typealias CGSConnectionID = Int32
typealias CGSWindowID = Int32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSSetWindowAlpha")
func CGSSetWindowAlpha(_ cid: CGSConnectionID, _ wid: CGSWindowID, _ alpha: Float) -> Int32

@_silgen_name("CGSSetWindowOpacity")
func CGSSetWindowOpacity(_ cid: CGSConnectionID, _ wid: CGSWindowID, _ isOpaque: Int32) -> Int32

struct GlassifiedApp: Identifiable, Codable, Equatable {
    let bundleID: String
    let name: String
    var alpha: Double

    var id: String { bundleID }
}

struct RunningAppInfo: Identifiable {
    let bundleID: String
    let name: String
    let icon: NSImage
    var isGlassified: Bool

    var id: String { bundleID }
}

class GlassifyManager: ObservableObject {
    static let shared = GlassifyManager()

    @Published var glassifiedApps: [GlassifiedApp] = []
    @Published var runningApps: [RunningAppInfo] = []
    @Published var globalAlpha: Double = 0.7

    private var timer: Timer?
    private var cid: CGSConnectionID = 0
    private let defaults = UserDefaults.standard

    private init() {
        cid = CGSMainConnectionID()
        loadSaved()
        refreshRunningApps()
        startMonitoring()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appLaunched),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appTerminated),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil
        )
    }

    private func loadSaved() {
        if let data = defaults.data(forKey: "glassifiedApps"),
           let apps = try? JSONDecoder().decode([GlassifiedApp].self, from: data) {
            glassifiedApps = apps
        }
        globalAlpha = defaults.double(forKey: "glassifyAlpha")
        if globalAlpha == 0 { globalAlpha = 0.7 }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(glassifiedApps) {
            defaults.set(data, forKey: "glassifiedApps")
        }
        defaults.set(globalAlpha, forKey: "glassifyAlpha")
    }

    func refreshRunningApps() {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app -> RunningAppInfo? in
                guard let bid = app.bundleIdentifier, let name = app.localizedName else { return nil }
                return RunningAppInfo(
                    bundleID: bid,
                    name: name,
                    icon: app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage(),
                    isGlassified: glassifiedApps.contains { $0.bundleID == bid }
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        runningApps = apps
    }

    func toggleApp(_ bundleID: String, name: String) {
        if let idx = glassifiedApps.firstIndex(where: { $0.bundleID == bundleID }) {
            let app = glassifiedApps.remove(at: idx)
            restoreApp(bundleID: app.bundleID)
        } else {
            glassifiedApps.append(GlassifiedApp(bundleID: bundleID, name: name, alpha: globalAlpha))
            applyGlass(bundleID: bundleID, alpha: globalAlpha)
        }
        save()
        refreshRunningApps()
    }

    func updateAlpha(_ alpha: Double) {
        globalAlpha = alpha
        for i in glassifiedApps.indices {
            glassifiedApps[i].alpha = alpha
        }
        applyAll()
        save()
    }

    func updateAppAlpha(_ bundleID: String, alpha: Double) {
        guard let idx = glassifiedApps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        glassifiedApps[idx].alpha = alpha
        applyGlass(bundleID: bundleID, alpha: alpha)
        save()
    }

    private func applyAll() {
        for app in glassifiedApps {
            applyGlass(bundleID: app.bundleID, alpha: app.alpha)
        }
    }

    private func applyGlass(bundleID: String, alpha: Double) {
        let windowIDs = getWindowIDs(for: bundleID)
        for wid in windowIDs {
            let w = CGSWindowID(wid)
            _ = CGSSetWindowOpacity(cid, w, 0)
            _ = CGSSetWindowAlpha(cid, w, Float(alpha))
        }
    }

    private func restoreApp(bundleID: String) {
        let windowIDs = getWindowIDs(for: bundleID)
        for wid in windowIDs {
            let w = CGSWindowID(wid)
            _ = CGSSetWindowAlpha(cid, w, 1.0)
            _ = CGSSetWindowOpacity(cid, w, 1)
        }
    }

    private func getWindowIDs(for bundleID: String) -> [Int] {
        guard let pid = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID })?.processIdentifier else { return [] }

        guard let windowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }

        return windowList.compactMap { info -> Int? in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int,
                  ownerPID == pid,
                  let windowID = info[kCGWindowNumber as String] as? Int,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { return nil }
            return windowID
        }
    }

    func restoreAll() {
        for app in glassifiedApps {
            restoreApp(bundleID: app.bundleID)
        }
        glassifiedApps.removeAll()
        save()
        refreshRunningApps()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.applyAll()
        }
    }

    @objc private func appLaunched(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshRunningApps()
            self?.applyAll()
        }
    }

    @objc private func appTerminated(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshRunningApps()
        }
    }
}
