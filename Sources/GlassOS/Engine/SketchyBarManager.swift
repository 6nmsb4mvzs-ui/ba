import AppKit
import Combine

struct SketchyBarConfig: Codable, Equatable {
    var position: String = "top"
    var height: Int = 40
    var blurRadius: Int = 30
    var barColor: String = "#000000"
    var barOpacity: Double = 0.25
    var cornerRadius: Int = 0
    var borderColor: String = "#FFFFFF"
    var borderWidth: Int = 0
    var margin: Int = 0
    var yOffset: Int = 0
    var shadow: Bool = false
    var sticky: Bool = true
    var topmost: String = "window"
    var fontSmoothing: Bool = true
    var padding_left: Int = 10
    var padding_right: Int = 10
}

struct SketchyBarWidget: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var kind: WidgetKind
    var name: String
    var enabled: Bool = true
    var position: WidgetPosition = .right

    var iconName: String = ""
    var iconColor: String = "#FFFFFF"
    var labelColor: String = "#FFFFFF"
    var backgroundColor: String = "#000000"
    var backgroundOpacity: Double = 0.0
    var backgroundCornerRadius: Int = 5
    var backgroundHeight: Int = 26
    var fontFamily: String = "SF Pro"
    var fontSize: Double = 13.0
    var fontStyle: String = "Regular"
    var paddingLeft: Int = 4
    var paddingRight: Int = 4
    var updateFrequency: Int = 10
    var customScript: String = ""

    enum WidgetKind: String, Codable, CaseIterable {
        case clock = "Clock"
        case battery = "Battery"
        case volume = "Volume"
        case cpu = "CPU"
        case weather = "Weather"
        case frontApp = "Front App"
        case spaces = "Spaces"
        case media = "Media"
        case wifi = "WiFi"
        case separator = "Separator"

        var defaultIcon: String {
            switch self {
            case .clock:    return "\u{e381}"
            case .battery:  return "\u{e315}"
            case .volume:   return "\u{e050}"
            case .cpu:      return "\u{e1a0}"
            case .weather:  return "\u{e2bd}"
            case .frontApp: return "\u{e8d4}"
            case .spaces:   return "\u{e8f8}"
            case .media:    return "\u{e405}"
            case .wifi:     return "\u{e63e}"
            case .separator: return "|"
            }
        }

        var sfSymbol: String {
            switch self {
            case .clock:     return "clock"
            case .battery:   return "battery.75percent"
            case .volume:    return "speaker.wave.2"
            case .cpu:       return "cpu"
            case .weather:   return "cloud.sun"
            case .frontApp:  return "macwindow"
            case .spaces:    return "square.grid.2x2"
            case .media:     return "music.note"
            case .wifi:      return "wifi"
            case .separator: return "minus"
            }
        }
    }

    enum WidgetPosition: String, Codable, CaseIterable {
        case left, center, right
    }
}

class SketchyBarManager: ObservableObject {
    static let shared = SketchyBarManager()

    @Published var isInstalled = false
    @Published var isRunning = false
    @Published var installProgress: String?
    @Published var config = SketchyBarConfig()
    @Published var widgets: [SketchyBarWidget] = []

    private let defaults = UserDefaults.standard
    private let configKey = "sketchybar_config"
    private let widgetsKey = "sketchybar_widgets"
    private var statusTimer: Timer?

    private init() {
        loadSaved()
        checkInstallation()
        checkRunning()
        startStatusMonitoring()
    }

    func checkInstallation() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let installed = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/sketchybar")
                || FileManager.default.fileExists(atPath: "/usr/local/bin/sketchybar")
            DispatchQueue.main.async {
                self?.isInstalled = installed
            }
        }
    }

    func checkRunning() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            proc.arguments = ["-x", "sketchybar"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            let running = proc.terminationStatus == 0
            DispatchQueue.main.async {
                self?.isRunning = running
            }
        }
    }

    private func startStatusMonitoring() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkRunning()
        }
    }

    private func brewPath() -> String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            return "/opt/homebrew/bin/brew"
        }
        return "/usr/local/bin/brew"
    }

    private func sketchyBarPath() -> String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/sketchybar") {
            return "/opt/homebrew/bin/sketchybar"
        }
        return "/usr/local/bin/sketchybar"
    }

    func installSketchyBar() {
        guard !isInstalled else { return }
        installProgress = "Installing via Homebrew..."
        let brew = brewPath()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: brew)
            proc.arguments = ["install", "FelixKratz/formulae/sketchybar"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            try? proc.run()
            proc.waitUntilExit()

            DispatchQueue.main.async {
                if proc.terminationStatus == 0 {
                    self?.isInstalled = true
                    self?.installProgress = "Installed successfully!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.installProgress = nil
                    }
                } else {
                    self?.installProgress = "Installation failed. Is Homebrew installed?"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.installProgress = nil
                    }
                }
            }
        }
    }

    func startSketchyBar() {
        writeConfig()
        let brew = brewPath()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: brew)
            proc.arguments = ["services", "start", "sketchybar"]
            try? proc.run()
            proc.waitUntilExit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.checkRunning()
            }
        }
    }

    func stopSketchyBar() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            proc.arguments = ["sketchybar"]
            try? proc.run()
            proc.waitUntilExit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.checkRunning()
            }
        }
    }

    func restartSketchyBar() {
        writeConfig()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let kill = Process()
            kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            kill.arguments = ["sketchybar"]
            try? kill.run()
            kill.waitUntilExit()

            Thread.sleep(forTimeInterval: 0.5)

            let sketchybar = self?.sketchyBarPath() ?? "/opt/homebrew/bin/sketchybar"
            let start = Process()
            start.executableURL = URL(fileURLWithPath: sketchybar)
            try? start.run()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.checkRunning()
            }
        }
    }

    func applyLive() {
        guard isRunning else { return }
        let barCmd = buildBarCommand()
        let sketchybar = sketchyBarPath()
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-c", "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH; " + barCmd]
            try? proc.run()
            proc.waitUntilExit()
        }

        for widget in widgets where widget.enabled {
            let widgetCmd = buildWidgetCommand(widget)
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                proc.arguments = ["-c", "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH; " + widgetCmd]
                try? proc.run()
                proc.waitUntilExit()
            }
        }
    }

    func addWidget(kind: SketchyBarWidget.WidgetKind) {
        let widget = SketchyBarWidget(
            kind: kind,
            name: "\(kind.rawValue) \(widgets.filter { $0.kind == kind }.count + 1)",
            iconName: kind.defaultIcon
        )
        widgets.append(widget)
        save()
    }

    func removeWidget(id: String) {
        widgets.removeAll { $0.id == id }
        save()
    }

    func updateWidget(_ widget: SketchyBarWidget) {
        if let idx = widgets.firstIndex(where: { $0.id == widget.id }) {
            widgets[idx] = widget
            save()
        }
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func addDefaultWidgets() {
        widgets = [
            SketchyBarWidget(kind: .spaces, name: "Spaces", position: .left, iconName: " "),
            SketchyBarWidget(kind: .frontApp, name: "Front App", position: .left, iconName: " "),
            SketchyBarWidget(kind: .clock, name: "Clock", position: .right, iconName: "\u{e381}", updateFrequency: 10),
            SketchyBarWidget(kind: .battery, name: "Battery", position: .right, iconName: "\u{e315}", updateFrequency: 120),
            SketchyBarWidget(kind: .volume, name: "Volume", position: .right, iconName: "\u{e050}"),
            SketchyBarWidget(kind: .wifi, name: "WiFi", position: .right, iconName: "\u{e63e}", updateFrequency: 5),
            SketchyBarWidget(kind: .cpu, name: "CPU", position: .right, iconName: "\u{e1a0}", updateFrequency: 2),
        ]
        save()
    }

    private func save() {
        if let configData = try? JSONEncoder().encode(config) {
            defaults.set(configData, forKey: configKey)
        }
        if let widgetsData = try? JSONEncoder().encode(widgets) {
            defaults.set(widgetsData, forKey: widgetsKey)
        }
    }

    private func loadSaved() {
        if let data = defaults.data(forKey: configKey),
           let saved = try? JSONDecoder().decode(SketchyBarConfig.self, from: data) {
            config = saved
        }
        if let data = defaults.data(forKey: widgetsKey),
           let saved = try? JSONDecoder().decode([SketchyBarWidget].self, from: data) {
            widgets = saved
        }
        if widgets.isEmpty {
            addDefaultWidgets()
        }
    }

    func writeConfig() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sketchybar")
        let pluginsDir = configDir.appendingPathComponent("plugins")

        try? FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)

        var script = "#!/bin/bash\n\n"
        script += "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH\n"
        script += "PLUGIN_DIR=\"$HOME/.config/sketchybar/plugins\"\n\n"
        script += buildBarCommand() + "\n\n"

        for widget in widgets where widget.enabled {
            let scriptFile = pluginScript(for: widget)
            let pluginPath = pluginsDir.appendingPathComponent("\(sanitizeName(widget.name)).sh")
            try? scriptFile.write(to: pluginPath, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: pluginPath.path)

            script += buildWidgetAddCommand(widget) + "\n"
            script += buildWidgetCommand(widget) + "\n\n"
        }

        script += "\nsketchybar --update\n"

        let rcPath = configDir.appendingPathComponent("sketchybarrc")
        try? script.write(to: rcPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: rcPath.path)
    }

    func exportConfig() -> String {
        var script = "#!/bin/bash\n# GlassOS SketchyBar Configuration\n\n"
        script += "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH\n\n"
        script += buildBarCommand() + "\n\n"
        for widget in widgets where widget.enabled {
            script += buildWidgetAddCommand(widget) + "\n"
            script += buildWidgetCommand(widget) + "\n\n"
        }
        script += "sketchybar --update\n"
        return script
    }

    private func buildBarCommand() -> String {
        let c = config
        let hexColor = colorToSketchyHex(c.barColor, opacity: c.barOpacity)
        let borderHex = colorToSketchyHex(c.borderColor, opacity: 1.0)

        var parts = ["sketchybar --bar"]
        parts.append("position=\(c.position)")
        parts.append("height=\(c.height)")
        parts.append("blur_radius=\(c.blurRadius)")
        parts.append("color=\(hexColor)")
        parts.append("corner_radius=\(c.cornerRadius)")
        parts.append("border_color=\(borderHex)")
        parts.append("border_width=\(c.borderWidth)")
        parts.append("margin=\(c.margin)")
        parts.append("y_offset=\(c.yOffset)")
        parts.append("shadow=\(c.shadow ? "on" : "off")")
        parts.append("sticky=\(c.sticky ? "on" : "off")")
        parts.append("topmost=\(c.topmost)")
        parts.append("font_smoothing=\(c.fontSmoothing ? "on" : "off")")
        parts.append("padding_left=\(c.padding_left)")
        parts.append("padding_right=\(c.padding_right)")
        return parts.joined(separator: " ")
    }

    private func buildWidgetAddCommand(_ w: SketchyBarWidget) -> String {
        let name = sanitizeName(w.name)
        return "sketchybar --add item \(name) \(w.position.rawValue)"
    }

    private func buildWidgetCommand(_ w: SketchyBarWidget) -> String {
        let name = sanitizeName(w.name)
        let bgHex = colorToSketchyHex(w.backgroundColor, opacity: w.backgroundOpacity)
        let iconHex = colorToSketchyHex(w.iconColor, opacity: 1.0)
        let labelHex = colorToSketchyHex(w.labelColor, opacity: 1.0)

        var parts = ["sketchybar --set \(name)"]
        if !w.iconName.isEmpty {
            parts.append("icon=\"\(w.iconName)\"")
        }
        parts.append("icon.color=\(iconHex)")
        parts.append("icon.font=\"\(w.fontFamily):Bold:\(w.fontSize)\"")
        parts.append("label.color=\(labelHex)")
        parts.append("label.font=\"\(w.fontFamily):\(w.fontStyle):\(w.fontSize)\"")
        parts.append("background.color=\(bgHex)")
        parts.append("background.corner_radius=\(w.backgroundCornerRadius)")
        parts.append("background.height=\(w.backgroundHeight)")
        parts.append("padding_left=\(w.paddingLeft)")
        parts.append("padding_right=\(w.paddingRight)")

        if w.updateFrequency > 0 {
            parts.append("update_freq=\(w.updateFrequency)")
        }

        let pluginsDir = "~/.config/sketchybar/plugins"
        parts.append("script=\"\(pluginsDir)/\(name).sh\"")

        return parts.joined(separator: " ")
    }

    private func pluginScript(for widget: SketchyBarWidget) -> String {
        if !widget.customScript.isEmpty {
            return "#!/bin/bash\n\(widget.customScript)\n"
        }

        switch widget.kind {
        case .clock:
            return "#!/bin/bash\nsketchybar --set $NAME label=\"$(date '+%H:%M')\"\n"
        case .battery:
            return """
            #!/bin/bash
            PERCENTAGE=$(pmset -g batt | grep -Eo "\\d+%" | cut -d% -f1)
            CHARGING=$(pmset -g batt | grep 'AC Power')
            if [ -n "$CHARGING" ]; then
              ICON="⚡"
            else
              ICON="🔋"
            fi
            sketchybar --set $NAME icon="$ICON" label="${PERCENTAGE}%"
            """
        case .volume:
            return """
            #!/bin/bash
            VOLUME=$(osascript -e 'output volume of (get volume settings)')
            sketchybar --set $NAME label="${VOLUME}%"
            """
        case .cpu:
            return """
            #!/bin/bash
            CPU=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
            sketchybar --set $NAME label="${CPU}%"
            """
        case .weather:
            return "#!/bin/bash\nsketchybar --set $NAME label=\"--\"\n"
        case .frontApp:
            return """
            #!/bin/bash
            if [ "$SENDER" = "front_app_switched" ]; then
              sketchybar --set $NAME label="$INFO"
            fi
            """
        case .spaces:
            return "#!/bin/bash\n"
        case .media:
            return """
            #!/bin/bash
            TRACK=$(osascript -e 'tell application "Music" to name of current track' 2>/dev/null)
            ARTIST=$(osascript -e 'tell application "Music" to artist of current track' 2>/dev/null)
            if [ -n "$TRACK" ]; then
              sketchybar --set $NAME label="$ARTIST - $TRACK"
            else
              sketchybar --set $NAME label="No Media"
            fi
            """
        case .wifi:
            return """
            #!/bin/bash
            SSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ SSID/ {print substr($0, index($0, $2))}')
            sketchybar --set $NAME label="$SSID"
            """
        case .separator:
            return "#!/bin/bash\n"
        }
    }

    private func sanitizeName(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private func colorToSketchyHex(_ hex: String, opacity: Double) -> String {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let alpha = String(format: "%02x", Int(opacity * 255))
        return "0x\(alpha)\(h)"
    }
}
