import SwiftUI
import UIKit

extension ContentView {
    var canvasSizePresets: [(label: String, width: Int, height: Int)] {
        [
            (
                "現在のサイズ (\(max(Int(store.canvas.canvasSize.width.rounded()), 1)) × \(max(Int(store.canvas.canvasSize.height.rounded()), 1)))",
                max(Int(store.canvas.canvasSize.width.rounded()), 1),
                max(Int(store.canvas.canvasSize.height.rounded()), 1)
            ),
            ("768 × 1024", 768, 1024),
            ("1024 × 1024", 1024, 1024),
            ("1152 × 1536", 1152, 1536),
            ("1536 × 2048", 1536, 2048),
            ("2048 × 2048", 2048, 2048)
        ]
    }

    var newCanvasSheet: some View {
        NavigationStack {
            Form {
                Section("サイズ") {
                    TextField(StudioStrings.width(language), text: $newCanvasWidthText)
                        .keyboardType(.numberPad)

                    TextField(StudioStrings.height(language), text: $newCanvasHeightText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(StudioStrings.newCanvas(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        showsNewCanvasSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.create(language)) {
                        guard
                            let width = parsedCanvasDimension(from: newCanvasWidthText),
                            let height = parsedCanvasDimension(from: newCanvasHeightText)
                        else { return }
                        store.send(.newCanvasRequested(width: width, height: height))
                        showsNewCanvasSheet = false
                    }
                    .disabled(
                        parsedCanvasDimension(from: newCanvasWidthText) == nil ||
                        parsedCanvasDimension(from: newCanvasHeightText) == nil
                    )
                }
            }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    var hueSaturationBrightnessSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.hueSaturationBrightness(language)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.hue(language))
                            Spacer()
                            Text("\(Int(hsbAdjustmentSettings.hueDegrees.rounded()))°")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $hsbAdjustmentSettings.hueDegrees, in: -180...180, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.saturation(language))
                            Spacer()
                            Text(String(format: "%.2f", hsbAdjustmentSettings.saturation))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $hsbAdjustmentSettings.saturation, in: 0...2, step: 0.01)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.brightness(language))
                            Spacer()
                            Text(String(format: "%.2f", hsbAdjustmentSettings.brightness))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $hsbAdjustmentSettings.brightness, in: -1...1, step: 0.01)
                    }
                }
            }
            .navigationTitle(StudioStrings.hueSaturationBrightness(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.hueSaturationBrightnessPreviewChanged(nil))
                        showsHSBSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.hueSaturationBrightnessApplied(hsbAdjustmentSettings))
                        showsHSBSheet = false
                    }
                }
            }
        }
        .onChange(of: hsbAdjustmentSettings) { _, newValue in
            store.send(.hueSaturationBrightnessPreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.hueSaturationBrightnessPreviewChanged(nil))
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    var brightnessContrastSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.brightnessContrast(language)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.brightness(language))
                            Spacer()
                            Text(String(format: "%.2f", brightnessContrastSettings.brightness))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $brightnessContrastSettings.brightness, in: -1...1, step: 0.01)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.contrast(language))
                            Spacer()
                            Text(String(format: "%.2f", brightnessContrastSettings.contrast))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $brightnessContrastSettings.contrast, in: 0...2, step: 0.01)
                    }
                }
            }
            .navigationTitle(StudioStrings.brightnessContrast(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.brightnessContrastPreviewChanged(nil))
                        showsBrightnessContrastSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.brightnessContrastApplied(brightnessContrastSettings))
                        showsBrightnessContrastSheet = false
                    }
                }
            }
        }
        .onChange(of: brightnessContrastSettings) { _, newValue in
            store.send(.brightnessContrastPreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.brightnessContrastPreviewChanged(nil))
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    var levelsSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.levels(language)) {
                    adjustmentSlider(
                        title: StudioStrings.inputBlack(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.inputBlack),
                        value: $levelsAdjustmentSettings.inputBlack,
                        range: 0...0.95
                    )
                    adjustmentSlider(
                        title: StudioStrings.inputWhite(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.inputWhite),
                        value: $levelsAdjustmentSettings.inputWhite,
                        range: 0.05...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.gamma(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.gamma),
                        value: $levelsAdjustmentSettings.gamma,
                        range: 0.2...3
                    )
                    adjustmentSlider(
                        title: StudioStrings.outputBlack(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.outputBlack),
                        value: $levelsAdjustmentSettings.outputBlack,
                        range: 0...0.95
                    )
                    adjustmentSlider(
                        title: StudioStrings.outputWhite(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.outputWhite),
                        value: $levelsAdjustmentSettings.outputWhite,
                        range: 0.05...1
                    )
                }
            }
            .navigationTitle(StudioStrings.levels(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.levelsPreviewChanged(nil))
                        showsLevelsSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.levelsApplied(normalizedLevelsSettings))
                        showsLevelsSheet = false
                    }
                }
            }
        }
        .onChange(of: levelsAdjustmentSettings) { _, _ in
            store.send(.levelsPreviewChanged(normalizedLevelsSettings))
        }
        .onDisappear {
            store.send(.levelsPreviewChanged(nil))
        }
        .presentationDetents([.height(480)])
        .presentationDragIndicator(.visible)
    }

    var toneCurveSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.toneCurve(language)) {
                    adjustmentSlider(
                        title: StudioStrings.shadows(language),
                        valueText: String(format: "%.2f", toneCurveSettings.shadows),
                        value: $toneCurveSettings.shadows,
                        range: -1...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.midtones(language),
                        valueText: String(format: "%.2f", toneCurveSettings.midtones),
                        value: $toneCurveSettings.midtones,
                        range: -1...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.highlights(language),
                        valueText: String(format: "%.2f", toneCurveSettings.highlights),
                        value: $toneCurveSettings.highlights,
                        range: -1...1
                    )
                }
            }
            .navigationTitle(StudioStrings.toneCurve(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.toneCurvePreviewChanged(nil))
                        showsToneCurveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.toneCurveApplied(toneCurveSettings))
                        showsToneCurveSheet = false
                    }
                }
            }
        }
        .onChange(of: toneCurveSettings) { _, newValue in
            store.send(.toneCurvePreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.toneCurvePreviewChanged(nil))
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    var colorBalanceSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.colorBalance(language)) {
                    adjustmentSlider(
                        title: StudioStrings.redCyan(language),
                        valueText: String(format: "%.2f", colorBalanceSettings.redCyan),
                        value: $colorBalanceSettings.redCyan,
                        range: -1...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.greenMagenta(language),
                        valueText: String(format: "%.2f", colorBalanceSettings.greenMagenta),
                        value: $colorBalanceSettings.greenMagenta,
                        range: -1...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.blueYellow(language),
                        valueText: String(format: "%.2f", colorBalanceSettings.blueYellow),
                        value: $colorBalanceSettings.blueYellow,
                        range: -1...1
                    )
                }
            }
            .navigationTitle(StudioStrings.colorBalance(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.colorBalancePreviewChanged(nil))
                        showsColorBalanceSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.colorBalanceApplied(colorBalanceSettings))
                        showsColorBalanceSheet = false
                    }
                }
            }
        }
        .onChange(of: colorBalanceSettings) { _, newValue in
            store.send(.colorBalancePreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.colorBalancePreviewChanged(nil))
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    var thresholdSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.thresholdAdjustment(language)) {
                    adjustmentSlider(
                        title: StudioStrings.threshold(language),
                        valueText: String(format: "%.2f", thresholdSettings.threshold),
                        value: $thresholdSettings.threshold,
                        range: 0...1
                    )
                }
            }
            .navigationTitle(StudioStrings.thresholdAdjustment(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.thresholdPreviewChanged(nil))
                        showsThresholdSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.thresholdApplied(thresholdSettings))
                        showsThresholdSheet = false
                    }
                }
            }
        }
        .onChange(of: thresholdSettings) { _, newValue in
            store.send(.thresholdPreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.thresholdPreviewChanged(nil))
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }

    var posterizeSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.posterize(language)) {
                    adjustmentSlider(
                        title: StudioStrings.levelCount(language),
                        valueText: "\(Int(posterizeSettings.levels.rounded()))",
                        value: $posterizeSettings.levels,
                        range: 2...32,
                        step: 1
                    )
                }
            }
            .navigationTitle(StudioStrings.posterize(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.posterizePreviewChanged(nil))
                        showsPosterizeSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.posterizeApplied(posterizeSettings))
                        showsPosterizeSheet = false
                    }
                }
            }
        }
        .onChange(of: posterizeSettings) { _, newValue in
            store.send(.posterizePreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.posterizePreviewChanged(nil))
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }

    var gradientMapSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.gradientMap(language)) {
                    gradientPreviewBar

                    Text(language.localized("プレビューをタップすると点を追加、点をドラッグすると移動できます。"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(language.localized("プリセット読込"))
                            .font(.headline)

                        ForEach(GradientMapPreset.allCases) { preset in
                            Button(preset.localizedTitle(language)) {
                                gradientMapSettings = AppFeature.gradientMapSettings(for: preset)
                                selectedGradientStopID = gradientMapSettings.stops.dropFirst().first?.id
                            }
                        }
                    }

                    ForEach($gradientMapSettings.stops) { $stop in
                        gradientStopEditor(stop: $stop)
                    }

                    Button(language.localized("ポイントを追加")) {
                        addGradientStop()
                    }
                    .disabled(gradientMapSettings.stops.count >= 8)
                }
            }
            .navigationTitle(StudioStrings.gradientMap(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.gradientMapPreviewChanged(nil))
                        showsGradientMapSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.gradientMapApplied(normalizedGradientMapSettings))
                        showsGradientMapSheet = false
                    }
                }
            }
        }
        .onAppear {
            if selectedGradientStopID == nil {
                selectedGradientStopID = normalizedGradientMapSettings.stops.dropFirst().first?.id
            }
            store.send(.gradientMapPreviewChanged(normalizedGradientMapSettings))
        }
        .onChange(of: gradientMapSettings) { _, _ in
            store.send(.gradientMapPreviewChanged(normalizedGradientMapSettings))
        }
        .onDisappear {
            store.send(.gradientMapPreviewChanged(nil))
        }
        .presentationDetents([.height(620)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    func adjustmentSlider(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.01
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    @ViewBuilder
    func gradientStopEditor(stop: Binding<GradientMapStopSettings>) -> some View {
        let isEndpoint = isEndpointStop(id: stop.wrappedValue.id)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(gradientStopTitle(for: stop.wrappedValue.id))
                    .font(.headline)
                    .foregroundStyle(selectedGradientStopID == stop.wrappedValue.id ? StudioTheme.Palette.accentBright : .primary)

                Spacer()

                if !isEndpoint {
                    Button(role: .destructive) {
                        removeGradientStop(id: stop.wrappedValue.id)
                    } label: {
                        Text(language.localized("削除"))
                    }
                }
            }

            ColorPicker(
                language.localized("色"),
                selection: Binding(
                    get: { color(from: stop.wrappedValue) },
                    set: { newColor in
                        apply(color: newColor, to: stop)
                    }
                ),
                supportsOpacity: false
            )

            if !isEndpoint {
                adjustmentSlider(
                    title: language.localized("位置"),
                    valueText: String(format: "%.2f", stop.wrappedValue.position),
                    value: stop.position,
                    range: 0.05...0.95
                )
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedGradientStopID = stop.wrappedValue.id
        }
    }

    var gradientPreviewBar: some View {
        let normalizedSettings = normalizedGradientMapSettings
        let stops = normalizedSettings.stops
        return VStack(alignment: .leading, spacing: 10) {
            Text(language.localized("プレビュー"))
                .font(.headline)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        stops: stops.map {
                            .init(color: color(from: $0), location: $0.position)
                        },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                addGradientStop(at: value.location.x, width: proxy.size.width)
                            }
                    )

                    ForEach(stops) { stop in
                        Circle()
                            .fill(color(from: stop))
                            .frame(
                                width: selectedGradientStopID == stop.id ? 18 : 14,
                                height: selectedGradientStopID == stop.id ? 18 : 14
                            )
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                            .position(
                                x: proxy.size.width * stop.position,
                                y: proxy.size.height / 2
                            )
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        selectedGradientStopID = stop.id
                                        updateGradientStopPosition(
                                            id: stop.id,
                                            x: value.location.x,
                                            width: proxy.size.width
                                        )
                                    }
                            )
                    }
                }
            }
            .frame(height: 44)
        }
    }

    var normalizedGradientMapSettings: GradientMapSettings {
        AppFeature.normalizeGradientMapSettings(gradientMapSettings)
    }

    func gradientStopTitle(for id: GradientMapStopSettings.ID) -> String {
        let normalizedStops = normalizedGradientMapSettings.stops
        guard let index = normalizedStops.firstIndex(where: { $0.id == id }) else {
            return language.localized("ポイント")
        }
        if index == 0 {
            return StudioStrings.shadows(language)
        }
        if index == normalizedStops.count - 1 {
            return StudioStrings.highlights(language)
        }
        return "\(language.localized("ポイント")) \(index)"
    }

    func isEndpointStop(id: GradientMapStopSettings.ID) -> Bool {
        let normalizedStops = normalizedGradientMapSettings.stops
        guard let index = normalizedStops.firstIndex(where: { $0.id == id }) else { return false }
        return index == 0 || index == normalizedStops.count - 1
    }

    func addGradientStop() {
        let normalized = normalizedGradientMapSettings.stops
        guard let previous = normalized.dropLast().last,
              let next = normalized.last else { return }
        let midpoint = (previous.position + next.position) / 2
        insertGradientStop(at: midpoint)
    }

    func addGradientStop(at x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let position = min(max(Double(x / width), 0.0), 1.0)
        insertGradientStop(at: position)
    }

    func removeGradientStop(id: GradientMapStopSettings.ID) {
        guard gradientMapSettings.stops.count > 2 else { return }
        gradientMapSettings.stops.removeAll { $0.id == id }
        if selectedGradientStopID == id {
            selectedGradientStopID = normalizedGradientMapSettings.stops.dropFirst().first?.id
        }
    }

    func insertGradientStop(at position: Double) {
        guard gradientMapSettings.stops.count < 8 else { return }
        let clampedPosition = min(max(position, 0.0), 1.0)
        let mixed = AppFeature.mappedGradientColor(
            for: clampedPosition,
            stops: AppFeature.gradientMapStops(for: normalizedGradientMapSettings)
        )
        let newStop = GradientMapStopSettings(
            position: clampedPosition,
            red: mixed.red,
            green: mixed.green,
            blue: mixed.blue
        )
        gradientMapSettings.stops.append(newStop)
        gradientMapSettings = normalizedGradientMapSettings
        selectedGradientStopID = newStop.id
    }

    func updateGradientStopPosition(id: GradientMapStopSettings.ID, x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        guard let index = gradientMapSettings.stops.firstIndex(where: { $0.id == id }) else { return }
        guard !isEndpointStop(id: id) else { return }
        gradientMapSettings.stops[index].position = min(max(Double(x / width), 0.0), 1.0)
        gradientMapSettings = normalizedGradientMapSettings
    }

    func color(from stop: GradientMapStopSettings) -> Color {
        Color(
            red: Double(stop.red) / 255.0,
            green: Double(stop.green) / 255.0,
            blue: Double(stop.blue) / 255.0
        )
    }

    func color(from stop: AppFeature.GradientMapStop) -> Color {
        Color(
            red: Double(stop.red) / 255.0,
            green: Double(stop.green) / 255.0,
            blue: Double(stop.blue) / 255.0
        )
    }

    func apply(color: Color, to stop: Binding<GradientMapStopSettings>) {
        let resolved = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: nil)
        stop.wrappedValue.red = UInt8(min(max((red * 255.0).rounded(), 0), 255))
        stop.wrappedValue.green = UInt8(min(max((green * 255.0).rounded(), 0), 255))
        stop.wrappedValue.blue = UInt8(min(max((blue * 255.0).rounded(), 0), 255))
    }

    func parsedCanvasDimension(from text: String) -> Int? {
        let digits = text.filter(\.isNumber)
        guard let value = Int(digits), (64...8192).contains(value) else { return nil }
        return value
    }

    var menuBar: some View {
        HStack(spacing: 8) {
            Button {
                store.send(.homeReturnRequested)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(language.localized("ホーム"))
                        .font(StudioTheme.Typography.label(9))
                }
                .foregroundStyle(StudioTheme.Palette.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(StudioTheme.Palette.accent.opacity(0.18))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(StudioTheme.Palette.accentSoft.opacity(0.4), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Circle()
                    .fill(StudioTheme.Palette.accent)
                    .frame(width: 6, height: 6)

                Text(StudioStrings.appName(language))
                    .font(StudioTheme.Typography.label(9))
                    .foregroundStyle(StudioTheme.Palette.textPrimary)
            }

            menuBarMenu(StudioStrings.settingsMenu(language)) {
                Menu(StudioStrings.languageMenu(language)) {
                    ForEach(AppLanguage.allCases) { option in
                        Button {
                            store.send(.languageChanged(option))
                        } label: {
                            if option == language {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                }

                Divider()

                Button(store.brushPanel.isCollapsed ? StudioStrings.showBrushPanel(language) : StudioStrings.hideBrushPanel(language)) {
                    store.send(.panelCollapseToggled(.brush))
                }

                Button(store.layerPanel.isCollapsed ? StudioStrings.showLayerPanel(language) : StudioStrings.hideLayerPanel(language)) {
                    store.send(.panelCollapseToggled(.layers))
                }
            }

            menuBarMenu(StudioStrings.fileMenu(language)) {
                Menu(StudioStrings.newCanvas(language)) {
                    ForEach(canvasSizePresets, id: \.label) { preset in
                        Button(preset.label) {
                            store.send(.newCanvasRequested(width: preset.width, height: preset.height))
                        }
                    }

                    Divider()

                    Button(StudioStrings.customSize(language)) {
                        newCanvasWidthText = "\(max(Int(store.canvas.canvasSize.width.rounded()), 1))"
                        newCanvasHeightText = "\(max(Int(store.canvas.canvasSize.height.rounded()), 1))"
                        showsNewCanvasSheet = true
                    }
                }
                Button(StudioStrings.open(language)) {
                    showsOpenDocumentImporter = true
                }
                Button(StudioStrings.save(language)) {
                    store.send(.saveDocumentRequested)
                }
                Button(StudioStrings.export(language)) {
                    store.send(.exportDocumentRequested)
                }
                Button(StudioStrings.exportTimelapse(language)) {
                    store.send(.exportTimelapseRequested)
                }
            }

            menuBarMenu(StudioStrings.editMenu(language)) {
                Menu(StudioStrings.colorCorrection(language)) {
                    Button(StudioStrings.hueSaturationBrightness(language)) {
                        store.send(.brightnessContrastPreviewChanged(nil))
                        hsbAdjustmentSettings = HueSaturationBrightnessSettings()
                        showsHSBSheet = true
                    }

                    Button(StudioStrings.brightnessContrast(language)) {
                        store.send(.hueSaturationBrightnessPreviewChanged(nil))
                        brightnessContrastSettings = BrightnessContrastSettings()
                        showsBrightnessContrastSheet = true
                    }

                    Button(StudioStrings.levels(language)) {
                        levelsAdjustmentSettings = LevelsAdjustmentSettings()
                        store.send(.levelsPreviewChanged(normalizedLevelsSettings))
                        showsLevelsSheet = true
                    }

                    Button(StudioStrings.toneCurve(language)) {
                        toneCurveSettings = ToneCurveSettings()
                        showsToneCurveSheet = true
                    }

                    Button(StudioStrings.colorBalance(language)) {
                        colorBalanceSettings = ColorBalanceSettings()
                        showsColorBalanceSheet = true
                    }

                    Button(StudioStrings.thresholdAdjustment(language)) {
                        thresholdSettings = ThresholdSettings()
                        showsThresholdSheet = true
                    }

                    Button(StudioStrings.posterize(language)) {
                        posterizeSettings = PosterizeSettings()
                        showsPosterizeSheet = true
                    }

                    Menu(StudioStrings.gradientMap(language)) {
                        Button(language.localized("カスタム…")) {
                            gradientMapSettings = AppFeature.gradientMapSettings(for: .graphite)
                            showsGradientMapSheet = true
                        }

                        Divider()

                        ForEach(GradientMapPreset.allCases) { preset in
                            Button(preset.localizedTitle(language)) {
                                store.send(.gradientMapSelected(preset))
                            }
                        }
                    }
                }
                .disabled(activeLayer == nil || store.canvas.renderSnapshot == nil)

                Divider()

                Button(StudioStrings.clearActiveLayer(language)) {
                    store.send(.clearActiveLayerButtonTapped)
                }

                Button(StudioStrings.refreshView(language)) {
                    store.send(.refreshPresentationRequested)
                }
            }

            menuBarMenu(StudioStrings.pageMenu(language)) {
                Button(StudioStrings.pagesAdd(language)) {}
                    .disabled(true)
                Button(StudioStrings.pagesDuplicate(language)) {}
                    .disabled(true)
                Button(StudioStrings.pagesDelete(language)) {}
                    .disabled(true)
            }

            menuBarMenu(StudioStrings.layerMenu(language)) {
                Button(StudioStrings.addLayer(language)) {
                    store.send(.layerSidebar(.addLayerButtonTapped))
                }

                Button(StudioStrings.addFolder(language)) {
                    store.send(.layerSidebar(.addFolderButtonTapped))
                }

                Button(activeLayerIsVisible ? StudioStrings.hideActiveLayer(language) : StudioStrings.showActiveLayer(language)) {
                    store.send(.activeLayerVisibilityToggled)
                }
                .disabled(activeLayer == nil)

                Divider()

                Button(StudioStrings.selectUpperLayer(language)) {
                    store.send(.selectPreviousLayer)
                }
                .disabled(!canSelectPreviousLayer)

                Button(StudioStrings.selectLowerLayer(language)) {
                    store.send(.selectNextLayer)
                }
                .disabled(!canSelectNextLayer)

                Divider()

                Button(StudioStrings.clearActiveLayer(language)) {
                    store.send(.clearActiveLayerButtonTapped)
                }
                .disabled(activeLayer == nil)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            ZStack {
                StudioTheme.Gradients.surface

                LinearGradient(
                    colors: [
                        StudioTheme.Palette.accentBright.opacity(0.18),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        StudioTheme.Palette.toolbarHighlight
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioTheme.Palette.accentSoft.opacity(0.28))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .compositingGroup()
        .shadow(color: StudioTheme.Palette.accentGlow.opacity(0.14), radius: 18, y: 8)
    }

    var undoRedoBar: some View {
        HStack(spacing: 4) {
            Button {
                store.send(.undoRequested)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.accent.opacity(0.18))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.42), lineWidth: 1)
            }

            Button {
                store.send(.redoRequested)
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.accent.opacity(0.18))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.42), lineWidth: 1)
            }

            Button {
                store.send(.clearActiveLayerButtonTapped)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.accent.opacity(0.14))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.34), lineWidth: 1)
            }
            .disabled(activeLayer == nil)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            ZStack {
                StudioTheme.Gradients.surface

                StudioTheme.Gradients.accentBar
                    .opacity(0.12)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        StudioTheme.Palette.toolbarHighlight
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioTheme.Palette.accentSoft.opacity(0.24))
                .frame(height: 1)
        }
    }

    func menuBarMenu<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            Text(title)
                .font(StudioTheme.Typography.label(9))
                .foregroundStyle(StudioTheme.Palette.textPrimary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .minimumHitTarget(28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(StudioTheme.Palette.toolbarFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(StudioTheme.Palette.accentSoft.opacity(0.22), lineWidth: 1)
                }
        }
    }

    var activeLayer: LayerRowModel? {
        store.layerSidebar.layers.first { $0.index == store.layerSidebar.activeLayerIndex }
    }

    var activeLayerIsVisible: Bool {
        activeLayer?.visible ?? false
    }

    var activeLayerPosition: Int? {
        store.layerSidebar.layers.firstIndex { $0.index == store.layerSidebar.activeLayerIndex }
    }

    var normalizedLevelsSettings: LevelsAdjustmentSettings {
        var settings = levelsAdjustmentSettings
        settings.inputBlack = min(settings.inputBlack, settings.inputWhite - 0.001)
        settings.inputWhite = max(settings.inputWhite, settings.inputBlack + 0.001)
        settings.outputBlack = min(settings.outputBlack, settings.outputWhite)
        settings.outputWhite = max(settings.outputWhite, settings.outputBlack)
        settings.gamma = max(settings.gamma, 0.01)
        return settings
    }

    var canSelectPreviousLayer: Bool {
        guard let activeLayerPosition else { return false }
        return activeLayerPosition > 0
    }

    var canSelectNextLayer: Bool {
        guard let activeLayerPosition else { return false }
        return activeLayerPosition < store.layerSidebar.layers.count - 1
    }
}
