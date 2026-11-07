import SwiftUI

struct SketchyBarView: View {
    @ObservedObject var manager = SketchyBarManager.shared
    @State private var expandedWidget: String?
    @State private var showAddWidget = false
    @State private var showExport = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                statusCard
                    .padding(.horizontal, 24)

                if manager.isInstalled {
                    barSettingsCard
                        .padding(.horizontal, 24)

                    widgetsSection
                        .padding(.horizontal, 24)

                    actionsCard
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 20)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SketchyBar")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            Text("Custom menu bar with widgets and effects")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "menubar.rectangle")
                        .font(.title3)
                        .foregroundColor(.cyan)
                    Text("Status")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()

                    if !manager.isInstalled {
                        statusBadge("Not Installed", color: .orange)
                    } else if manager.isRunning {
                        statusBadge("Running", color: .green)
                    } else {
                        statusBadge("Stopped", color: .red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if let progress = manager.installProgress {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.cyan)
                        Text(progress)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }

                Divider().opacity(0.2).padding(.horizontal, 16)

                HStack(spacing: 12) {
                    if !manager.isInstalled {
                        actionButton("Install SketchyBar", icon: "arrow.down.circle", color: .cyan) {
                            manager.installSketchyBar()
                        }
                    } else {
                        if manager.isRunning {
                            actionButton("Stop", icon: "stop.fill", color: .red) {
                                manager.stopSketchyBar()
                            }
                            actionButton("Restart", icon: "arrow.clockwise", color: .orange) {
                                manager.restartSketchyBar()
                            }
                        } else {
                            actionButton("Start", icon: "play.fill", color: .green) {
                                manager.startSketchyBar()
                            }
                        }
                        actionButton("Apply", icon: "checkmark.circle", color: .cyan) {
                            manager.applyLive()
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Bar Settings

    private var barSettingsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Bar Settings", icon: "slider.horizontal.3")

                settingsRow("Position") {
                    Picker("", selection: $manager.config.position) {
                        Text("Top").tag("top")
                        Text("Bottom").tag("bottom")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                settingsDivider()

                settingsRow("Height") {
                    HStack(spacing: 8) {
                        Slider(value: intBinding($manager.config.height, range: 20...60),
                               in: 20...60, step: 1)
                            .tint(.cyan)
                            .frame(width: 120)
                        Text("\(manager.config.height)px")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.cyan)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                settingsDivider()

                settingsRow("Blur Radius") {
                    HStack(spacing: 8) {
                        Slider(value: intBinding($manager.config.blurRadius, range: 0...50),
                               in: 0...50, step: 1)
                            .tint(.cyan)
                            .frame(width: 120)
                        Text("\(manager.config.blurRadius)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.cyan)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                settingsDivider()

                settingsRow("Bar Color") {
                    ColorPicker("", selection: hexColorBinding($manager.config.barColor))
                        .labelsHidden()
                }

                settingsDivider()

                settingsRow("Bar Opacity") {
                    HStack(spacing: 8) {
                        Slider(value: $manager.config.barOpacity, in: 0...1, step: 0.05)
                            .tint(.cyan)
                            .frame(width: 120)
                        Text("\(Int(manager.config.barOpacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.cyan)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                settingsDivider()

                settingsRow("Corner Radius") {
                    HStack(spacing: 8) {
                        Slider(value: intBinding($manager.config.cornerRadius, range: 0...20),
                               in: 0...20, step: 1)
                            .tint(.cyan)
                            .frame(width: 120)
                        Text("\(manager.config.cornerRadius)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.cyan)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                settingsDivider()

                settingsRow("Border Width") {
                    HStack(spacing: 8) {
                        Slider(value: intBinding($manager.config.borderWidth, range: 0...5),
                               in: 0...5, step: 1)
                            .tint(.cyan)
                            .frame(width: 120)
                        Text("\(manager.config.borderWidth)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.cyan)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                settingsDivider()

                settingsRow("Border Color") {
                    ColorPicker("", selection: hexColorBinding($manager.config.borderColor))
                        .labelsHidden()
                }

                settingsDivider()

                settingsRow("Margin") {
                    HStack(spacing: 8) {
                        Slider(value: intBinding($manager.config.margin, range: 0...20),
                               in: 0...20, step: 1)
                            .tint(.cyan)
                            .frame(width: 120)
                        Text("\(manager.config.margin)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.cyan)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                settingsDivider()

                settingsRow("Y Offset") {
                    HStack(spacing: 8) {
                        Slider(value: intBinding($manager.config.yOffset, range: -10...10),
                               in: -10...10, step: 1)
                            .tint(.cyan)
                            .frame(width: 120)
                        Text("\(manager.config.yOffset)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.cyan)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                settingsDivider()

                GlassToggle(title: "Shadow", isOn: $manager.config.shadow)
                Divider().opacity(0.2).padding(.horizontal, 16)
                GlassToggle(title: "Sticky", isOn: $manager.config.sticky)
                Divider().opacity(0.2).padding(.horizontal, 16)
                GlassToggle(title: "Font Smoothing", isOn: $manager.config.fontSmoothing)
            }
        }
    }

    // MARK: - Widgets Section

    private var widgetsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Widgets")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showAddWidget.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Widget")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }

            if showAddWidget {
                addWidgetPicker
            }

            ForEach(manager.widgets) { widget in
                widgetCard(widget)
            }
        }
    }

    private var addWidgetPicker: some View {
        GlassCard {
            VStack(spacing: 8) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 8) {
                    ForEach(SketchyBarWidget.WidgetKind.allCases, id: \.self) { kind in
                        Button(action: {
                            manager.addWidget(kind: kind)
                            showAddWidget = false
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: kind.sfSymbol)
                                    .font(.title3)
                                    .foregroundColor(.cyan)
                                Text(kind.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
        }
    }

    private func widgetCard(_ widget: SketchyBarWidget) -> some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: widget.kind.sfSymbol)
                        .foregroundColor(.cyan)
                        .frame(width: 20)

                    Text(widget.name)
                        .font(.body.bold())
                        .foregroundColor(.white)

                    Spacer()

                    Text(widget.position.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.06)))

                    Toggle("", isOn: widgetEnabledBinding(widget))
                        .toggleStyle(.switch)
                        .scaleEffect(0.7)
                        .tint(.cyan)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedWidget = expandedWidget == widget.id ? nil : widget.id
                        }
                    }) {
                        Image(systemName: expandedWidget == widget.id ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)

                    Button(action: { manager.removeWidget(id: widget.id) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.7))
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if expandedWidget == widget.id {
                    widgetEditor(widget)
                }
            }
        }
    }

    private func widgetEditor(_ widget: SketchyBarWidget) -> some View {
        VStack(spacing: 0) {
            Divider().opacity(0.2).padding(.horizontal, 16)

            settingsRow("Position") {
                Picker("", selection: widgetPositionBinding(widget)) {
                    ForEach(SketchyBarWidget.WidgetPosition.allCases, id: \.self) { pos in
                        Text(pos.rawValue.capitalized).tag(pos)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            settingsDivider()

            settingsRow("Icon Color") {
                ColorPicker("", selection: widgetColorBinding(widget, \.iconColor))
                    .labelsHidden()
            }

            settingsDivider()

            settingsRow("Label Color") {
                ColorPicker("", selection: widgetColorBinding(widget, \.labelColor))
                    .labelsHidden()
            }

            settingsDivider()

            settingsRow("Background") {
                ColorPicker("", selection: widgetColorBinding(widget, \.backgroundColor))
                    .labelsHidden()
            }

            settingsDivider()

            settingsRow("BG Opacity") {
                HStack(spacing: 8) {
                    Slider(value: widgetDoubleBinding(widget, \.backgroundOpacity),
                           in: 0...1, step: 0.05)
                        .tint(.cyan)
                        .frame(width: 120)
                    Text("\(Int(widget.backgroundOpacity * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.cyan)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            settingsDivider()

            settingsRow("BG Corner Radius") {
                HStack(spacing: 8) {
                    Slider(value: widgetIntBinding(widget, \.backgroundCornerRadius, range: 0...20),
                           in: 0...20, step: 1)
                        .tint(.cyan)
                        .frame(width: 120)
                    Text("\(widget.backgroundCornerRadius)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.cyan)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            settingsDivider()

            settingsRow("Font") {
                Picker("", selection: widgetStringBinding(widget, \.fontFamily)) {
                    Text("SF Pro").tag("SF Pro")
                    Text("SF Mono").tag("SF Mono")
                    Text("Menlo").tag("Menlo")
                    Text("Helvetica").tag("Helvetica Neue")
                    Text("Monaco").tag("Monaco")
                    Text("Fira Code").tag("Fira Code")
                    Text("JetBrains Mono").tag("JetBrains Mono")
                }
                .frame(width: 150)
            }

            settingsDivider()

            settingsRow("Font Size") {
                HStack(spacing: 8) {
                    Slider(value: widgetDoubleBinding(widget, \.fontSize),
                           in: 8...24, step: 0.5)
                        .tint(.cyan)
                        .frame(width: 120)
                    Text(String(format: "%.1f", widget.fontSize))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.cyan)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            settingsDivider()

            settingsRow("Font Style") {
                Picker("", selection: widgetStringBinding(widget, \.fontStyle)) {
                    Text("Regular").tag("Regular")
                    Text("Bold").tag("Bold")
                    Text("Heavy").tag("Heavy")
                    Text("Light").tag("Light")
                    Text("Semibold").tag("Semibold")
                    Text("Medium").tag("Medium")
                    Text("Italic").tag("Italic")
                }
                .frame(width: 150)
            }

            settingsDivider()

            settingsRow("Padding L / R") {
                HStack(spacing: 8) {
                    Stepper("", value: widgetIntStepperBinding(widget, \.paddingLeft), in: 0...30)
                        .labelsHidden()
                    Text("\(widget.paddingLeft)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.cyan)
                        .frame(width: 20)
                    Text("/")
                        .foregroundColor(.white.opacity(0.3))
                    Stepper("", value: widgetIntStepperBinding(widget, \.paddingRight), in: 0...30)
                        .labelsHidden()
                    Text("\(widget.paddingRight)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.cyan)
                        .frame(width: 20)
                }
            }

            settingsDivider()

            settingsRow("Update (sec)") {
                HStack(spacing: 8) {
                    Slider(value: widgetIntBinding(widget, \.updateFrequency, range: 0...120),
                           in: 0...120, step: 1)
                        .tint(.cyan)
                        .frame(width: 120)
                    Text("\(widget.updateFrequency)s")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.cyan)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            if widget.kind != .separator && widget.kind != .spaces {
                settingsDivider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Script")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    TextEditor(text: widgetStringBinding(widget, \.customScript))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(height: 60)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.04))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Actions", icon: "wrench.and.screwdriver")

                HStack(spacing: 12) {
                    actionButton("Write Config", icon: "doc.text", color: .cyan) {
                        manager.writeConfig()
                    }

                    actionButton("Export", icon: "square.and.arrow.up", color: .purple) {
                        showExport = true
                    }

                    actionButton("Reset Defaults", icon: "arrow.counterclockwise", color: .orange) {
                        manager.addDefaultWidgets()
                        manager.config = SketchyBarConfig()
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showExport) {
            exportSheet
        }
    }

    private var exportSheet: some View {
        VStack(spacing: 16) {
            Text("SketchyBar Configuration")
                .font(.headline)
                .foregroundColor(.white)

            ScrollView {
                Text(manager.exportConfig())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 400)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)

            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(manager.exportConfig(), forType: .string)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)

                Button("Close") {
                    showExport = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 600, height: 500)
        .background(.ultraThinMaterial)
    }

    // MARK: - Reusable Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func settingsDivider() -> some View {
        Divider().opacity(0.2).padding(.horizontal, 16)
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bindings

    private func intBinding(_ binding: Binding<Int>, range: ClosedRange<Double>) -> Binding<Double> {
        Binding<Double>(
            get: { Double(binding.wrappedValue) },
            set: { binding.wrappedValue = Int($0) }
        )
    }

    private func hexColorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding<Color>(
            get: { hexToColor(hex.wrappedValue) },
            set: { hex.wrappedValue = colorToHex($0) }
        )
    }

    private func widgetEnabledBinding(_ widget: SketchyBarWidget) -> Binding<Bool> {
        Binding<Bool>(
            get: { widget.enabled },
            set: { newVal in
                var w = widget
                w.enabled = newVal
                manager.updateWidget(w)
            }
        )
    }

    private func widgetPositionBinding(_ widget: SketchyBarWidget) -> Binding<SketchyBarWidget.WidgetPosition> {
        Binding(
            get: { widget.position },
            set: { newVal in
                var w = widget
                w.position = newVal
                manager.updateWidget(w)
            }
        )
    }

    private func widgetColorBinding(_ widget: SketchyBarWidget, _ keyPath: WritableKeyPath<SketchyBarWidget, String>) -> Binding<Color> {
        Binding<Color>(
            get: { hexToColor(widget[keyPath: keyPath]) },
            set: { newColor in
                var w = widget
                w[keyPath: keyPath] = colorToHex(newColor)
                manager.updateWidget(w)
            }
        )
    }

    private func widgetDoubleBinding(_ widget: SketchyBarWidget, _ keyPath: WritableKeyPath<SketchyBarWidget, Double>) -> Binding<Double> {
        Binding<Double>(
            get: { widget[keyPath: keyPath] },
            set: { newVal in
                var w = widget
                w[keyPath: keyPath] = newVal
                manager.updateWidget(w)
            }
        )
    }

    private func widgetIntBinding(_ widget: SketchyBarWidget, _ keyPath: WritableKeyPath<SketchyBarWidget, Int>, range: ClosedRange<Double>) -> Binding<Double> {
        Binding<Double>(
            get: { Double(widget[keyPath: keyPath]) },
            set: { newVal in
                var w = widget
                w[keyPath: keyPath] = Int(newVal)
                manager.updateWidget(w)
            }
        )
    }

    private func widgetIntStepperBinding(_ widget: SketchyBarWidget, _ keyPath: WritableKeyPath<SketchyBarWidget, Int>) -> Binding<Int> {
        Binding<Int>(
            get: { widget[keyPath: keyPath] },
            set: { newVal in
                var w = widget
                w[keyPath: keyPath] = newVal
                manager.updateWidget(w)
            }
        )
    }

    private func widgetStringBinding(_ widget: SketchyBarWidget, _ keyPath: WritableKeyPath<SketchyBarWidget, String>) -> Binding<String> {
        Binding<String>(
            get: { widget[keyPath: keyPath] },
            set: { newVal in
                var w = widget
                w[keyPath: keyPath] = newVal
                manager.updateWidget(w)
            }
        )
    }

    // MARK: - Color Conversion

    private func hexToColor(_ hex: String) -> Color {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    private func colorToHex(_ color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
