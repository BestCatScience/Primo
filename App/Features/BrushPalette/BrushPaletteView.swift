import ComposableArchitecture
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum PhotoshopDynamicControl: String, CaseIterable, Identifiable {
    case off
    case pressure
    case tilt
    case speed
    case random

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .off:
            return language == .japanese ? "なし" : "Off"
        case .pressure:
            return language == .japanese ? "筆圧" : "Pressure"
        case .tilt:
            return language == .japanese ? "傾き" : "Tilt"
        case .speed:
            return language == .japanese ? "速度" : "Speed"
        case .random:
            return language == .japanese ? "ランダム" : "Random"
        }
    }
}

private enum BrushSettingsCategory: String, CaseIterable, Identifiable {
    case tip
    case scatter
    case stroke
    case texture

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .tip:
            return language == .japanese ? "先端" : "Tip"
        case .scatter:
            return language == .japanese ? "散布" : "Scatter"
        case .stroke:
            return language == .japanese ? "描画" : "Stroke"
        case .texture:
            return language == .japanese ? "質感" : "Texture"
        }
    }
}

private struct BrushPreviewStyle {
    let color: Color
    let radius: Double
    let opacity: Double
    let roundness: Double
    let angle: Double
    let spacing: Double
    let scatterEnabled: Bool
    let scatterMode: BrushScatterMode
    let scatterLateral: Double
    let scatterLinear: Double
    let count: Int
    let countSizeJitter: Double
    let countOpacityJitter: Double
    let textureStrength: Double
    let flow: Double

    init(
        color: Color,
        radius: Double,
        opacity: Double,
        roundness: Double,
        angle: Double,
        spacing: Double,
        scatterEnabled: Bool,
        scatterMode: BrushScatterMode,
        scatterLateral: Double,
        scatterLinear: Double,
        count: Int,
        countSizeJitter: Double,
        countOpacityJitter: Double,
        textureStrength: Double,
        flow: Double
    ) {
        self.color = color
        self.radius = radius
        self.opacity = opacity
        self.roundness = roundness
        self.angle = angle
        self.spacing = spacing
        self.scatterEnabled = scatterEnabled
        self.scatterMode = scatterMode
        self.scatterLateral = scatterLateral
        self.scatterLinear = scatterLinear
        self.count = count
        self.countSizeJitter = countSizeJitter
        self.countOpacityJitter = countOpacityJitter
        self.textureStrength = textureStrength
        self.flow = flow
    }

    init(preset: BrushPreset) {
        color = .white
        radius = preset.radius
        opacity = preset.opacity
        roundness = preset.roundness
        angle = preset.angle
        spacing = preset.spacing
        scatterEnabled = preset.scatterEnabled
        scatterMode = preset.scatterMode
        scatterLateral = preset.scatterLateral
        scatterLinear = preset.scatterLinear
        count = preset.count
        countSizeJitter = preset.countSizeJitter
        countOpacityJitter = preset.countOpacityJitter
        textureStrength = preset.textureStrength
        flow = preset.flow
    }
}

private struct BrushStrokePreview: View {
    let style: BrushPreviewStyle
    var compact = false

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let points = previewPoints(in: size)
                let baseWidth = max(compact ? 2.2 : 3.8, min(size.width, size.height) * (compact ? 0.072 : 0.094) * style.radius / 6.0)
                let baseAlpha = max(0.18, min(0.96, style.opacity * (0.7 + style.flow * 0.3)))

                for index in 0..<points.count {
                    let point = points[index]
                    let pressure = previewPressure(at: index, total: points.count)
                    let clusterCount = max(1, style.scatterEnabled ? style.count : 1)
                    for clusterIndex in 0..<clusterCount {
                        let jitterSeed = Double(index * 13 + clusterIndex * 31 + 7)
                        let sizeJitter = 1.0 + signedNoise(jitterSeed * 0.17) * style.countSizeJitter * 0.55
                        let opacityJitter = 1.0 + signedNoise(jitterSeed * 0.11 + 0.3) * style.countOpacityJitter * 0.65
                        let scatter = scatterOffset(seed: jitterSeed, baseWidth: baseWidth)
                        let pressureWidth = lerp(0.52, 1.0, pressure)
                        let pressureOpacity = lerp(0.38, 1.0, pressure)
                        let rect = CGRect(
                            x: point.x + scatter.width - (baseWidth * sizeJitter * pressureWidth),
                            y: point.y + scatter.height - (baseWidth * sizeJitter * pressureWidth * max(0.28, style.roundness)),
                            width: baseWidth * 2.0 * sizeJitter * pressureWidth,
                            height: baseWidth * 2.0 * sizeJitter * pressureWidth * max(0.28, style.roundness)
                        )
                        let rotation = Angle(radians: style.angle + signedNoise(jitterSeed * 0.07) * 0.18)
                        let path = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.55)
                        let transformed = path.applying(CGAffineTransform(translationX: -rect.midX, y: -rect.midY))
                            .applying(CGAffineTransform(rotationAngle: rotation.radians))
                            .applying(CGAffineTransform(translationX: rect.midX, y: rect.midY))
                        context.fill(
                            transformed,
                            with: .color(style.color.opacity(max(0.08, min(1.0, baseAlpha * pressureOpacity * opacityJitter))))
                        )
                    }
                }
            }
        }
    }

    private func previewPoints(in size: CGSize) -> [CGPoint] {
        let start = CGPoint(x: size.width * 0.08, y: size.height * 0.68)
        let c1 = CGPoint(x: size.width * 0.28, y: size.height * 0.12)
        let c2 = CGPoint(x: size.width * 0.62, y: size.height * 0.92)
        let end = CGPoint(x: size.width * 0.92, y: size.height * 0.34)
        let steps = compact ? 28 : 54
        return (0...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            let spacingWarp = 1.0 + CGFloat(style.spacing * 0.45)
            let warped = min(1.0, pow(t, 1.0 / spacingWarp))
            return cubicPoint(start: start, c1: c1, c2: c2, end: end, t: warped)
        }
    }

    private func cubicPoint(start: CGPoint, c1: CGPoint, c2: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let x =
            mt * mt * mt * start.x +
            3 * mt * mt * t * c1.x +
            3 * mt * t * t * c2.x +
            t * t * t * end.x
        let y =
            mt * mt * mt * start.y +
            3 * mt * mt * t * c1.y +
            3 * mt * t * t * c2.y +
            t * t * t * end.y
        return CGPoint(x: x, y: y)
    }

    private func scatterOffset(seed: Double, baseWidth: Double) -> CGSize {
        guard style.scatterEnabled else { return .zero }
        let lateral = signedNoise(seed * 0.23 + 0.2) * style.scatterLateral * baseWidth * 1.8
        let linear = signedNoise(seed * 0.19 + 1.1) * style.scatterLinear * baseWidth * (style.scatterMode == .spray ? 1.8 : 1.0)
        if style.scatterMode == .spray {
            return CGSize(width: lateral, height: linear)
        }
        return CGSize(width: linear, height: lateral)
    }

    private func previewPressure(at index: Int, total: Int) -> Double {
        guard total > 1 else { return 0.85 }
        let t = Double(index) / Double(total - 1)
        let envelope = sin(t * .pi)
        let pulse = 0.72 + (0.28 * sin((t * .pi * 2.4) - 0.6))
        return max(0.18, min(1.0, envelope * pulse + 0.18))
    }

    private func signedNoise(_ seed: Double) -> Double {
        let value = sin(seed * 91.37 + 17.0) * 43758.5453
        return (value - floor(value)) * 2.0 - 1.0
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + ((b - a) * t)
    }
}

struct BrushPaletteView: View {
    @Bindable var store: StoreOf<BrushPaletteFeature>
    let currentTool: StudioToolKind
    let hasSelection: Bool
    let transformPreviewOffset: CGSize
    var transformPreviewScale: CGFloat = 1.0
    let language: AppLanguage
    var showsTitle = true
    @State private var isImportingBrush = false
    @State private var showsBrushSettingsPopover = false
    @State private var showsSavedBrushDeleteMode = false
    @State private var selectedBrushSettingsCategory: BrushSettingsCategory = .tip
    @State private var importErrorMessage: String?
    private let paletteColumns = Array(repeating: GridItem(.fixed(22), spacing: 8), count: 5)

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .top, spacing: 14) {
                if showsBrushLibrarySidebar {
                    brushLibrarySidebar
                        .frame(width: 196, alignment: .topLeading)
                        .overlay(alignment: .topLeading) {
                            if showsBrushSettingsPopover {
                                floatingBrushSettingsPanel
                                    .frame(width: min(proxy.size.width * 0.48, 420))
                                    .offset(x: 210, y: 0)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                                    .zIndex(10)
                            }
                        }
                        .zIndex(1)
                } else {
                    settingsPanelContent(showHeaderTitle: showsTitle)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showsBrushSettingsPopover)
        .fileImporter(
            isPresented: $isImportingBrush,
            allowedContentTypes: [.png, .atelierBrushTip, UTType(filenameExtension: "abr") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result else { return }
            var imported: [BrushPreset] = []
            var failures: [String] = []
            for url in urls {
                withSecurityScopedAccess(to: url) {
                    if url.pathExtension.lowercased() == "abr" {
                        do {
                            let brushes = try BrushTipLibrary.importPhotoshopBrushes(from: url).map(\.preset)
                            if brushes.isEmpty {
                                failures.append("\(url.lastPathComponent): \(language == .japanese ? "対応している先端が見つかりませんでした。" : "No supported sampled brushes were found.")")
                            } else {
                                imported.append(contentsOf: brushes)
                            }
                        } catch {
                            failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        }
                        return
                    }
                    let brushName = url.deletingPathExtension().lastPathComponent
                    do {
                        let tip = try BrushTipLibrary.loadRaster(from: url)
                        imported.append(BrushPreset.photoshopImported(name: brushName, tip: tip))
                    } catch {
                        failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
            if !imported.isEmpty {
                store.send(.importedPresets(imported))
            }
            if !failures.isEmpty {
                importErrorMessage = failures.joined(separator: "\n")
            }
        }
        .alert(
            language == .japanese ? "ブラシを読み込めませんでした" : "Could Not Import Brush",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { newValue in
                    if !newValue {
                        importErrorMessage = nil
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            },
            message: {
                Text(importErrorMessage ?? "")
            }
        )
    }

    private var showsBrushLibrarySidebar: Bool {
        currentTool == .brush || currentTool == .erase
    }

    private func settingsPanelContent(showHeaderTitle: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if showHeaderTitle {
                    Text(panelTitle)
                        .font(StudioTheme.Typography.title(26))
                        .foregroundStyle(.white.opacity(0.94))
                }

                headerCard(showsChrome: true)
                controlsCard(showsChrome: true)
                detailCard(showsChrome: true)
            }
            .padding(.bottom, 10)
        }
    }

    private func headerCard(showsChrome: Bool) -> some View {
        cardContainer(showsChrome: showsChrome) {
            VStack(alignment: .leading, spacing: 12) {
            sectionLabel(sectionTitle)

            if currentTool == .fill {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    store.brushColor.opacity(0.95),
                                    store.brushColor.opacity(0.32)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "paintbrush.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(StudioTheme.Palette.textPrimary)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        metricRow(language == .japanese ? "しきい値" : "Threshold", value: store.fillThresholdMode.localizedTitle(language))
                        metricRow(
                            store.fillThresholdMode == .opacity ? (language == .japanese ? "不透明度一致" : "Opacity Match") : (language == .japanese ? "色一致" : "Color Match"),
                            value: "\(Int((store.fillThresholdMode == .opacity ? store.fillOpacityTolerance : store.fillColorTolerance) * 100))%"
                        )
                        metricRow(language == .japanese ? "拡張" : "Expansion", value: "\(Int(store.fillExpansion)) px")
                        metricRow(language == .japanese ? "色" : "Color", value: store.selectedBrush?.name ?? (language == .japanese ? "カスタム" : "Custom Mix"))
                    }
                }
            } else if currentTool == .eyedropper {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    store.brushColor.opacity(0.96),
                                    StudioTheme.Palette.coolGlow.opacity(0.34)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "eyedropper")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(StudioTheme.Palette.textPrimary)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        metricRow(language == .japanese ? "取得元" : "Source", value: store.eyedropperSamplingSource.localizedTitle(language))
                        metricRow(language == .japanese ? "現在色" : "Current Color", value: colorHexLabel)
                        metricRow(language == .japanese ? "入力" : "Input", value: language == .japanese ? "Apple Pencil" : "Apple Pencil")
                        metricRow(language == .japanese ? "動作" : "Behavior", value: language == .japanese ? "ドラッグで連続取得" : "Drag to sample continuously")
                    }
                }
            } else if currentTool == .select {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    StudioTheme.Palette.accent.opacity(0.95),
                                    StudioTheme.Palette.coolGlow.opacity(0.42)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: store.selectionToolMode == .lasso ? "lasso" : "wand.and.stars")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(StudioTheme.Palette.textPrimary)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        metricRow(language == .japanese ? "モード" : "Mode", value: store.selectionToolMode.localizedTitle(language))
                        metricRow(language == .japanese ? "合成" : "Combine", value: store.selectionCombineMode.localizedTitle(language))
                        if store.selectionToolMode == .auto {
                            metricRow(language == .japanese ? "しきい値" : "Threshold", value: store.selectionThresholdMode.localizedTitle(language))
                            metricRow(
                                language == .japanese ? "一致" : "Match",
                                value: "\(Int((store.selectionThresholdMode == .opacity ? store.selectionOpacityTolerance : store.selectionColorTolerance) * 100))%"
                            )
                            metricRow(language == .japanese ? "拡張" : "Expansion", value: "\(Int(store.selectionExpansion)) px")
                        } else {
                            metricRow(language == .japanese ? "入力" : "Gesture", value: language == .japanese ? "フリーハンド" : "Freehand")
                            metricRow(language == .japanese ? "動作" : "Behavior", value: language == .japanese ? "パスを閉じる" : "Close Path")
                            metricRow(language == .japanese ? "対象" : "Scope", value: language == .japanese ? "アクティブレイヤー" : "Active Layer")
                        }
                    }
                }
            } else if currentTool == .move {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    StudioTheme.Palette.coolGlow.opacity(0.9),
                                    StudioTheme.Palette.accent.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: hasSelection ? "selection.pin.in.out" : "square.stack.3d.up")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(StudioTheme.Palette.textPrimary)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        metricRow(language == .japanese ? "対象" : "Target", value: hasSelection ? (language == .japanese ? "選択範囲" : "Selection") : (language == .japanese ? "レイヤー" : "Layer"))
                        metricRow("Offset X", value: "\(Int(transformPreviewOffset.width.rounded())) px")
                        metricRow("Offset Y", value: "\(Int(transformPreviewOffset.height.rounded())) px")
                        metricRow(language == .japanese ? "拡大率" : "Scale", value: "\(Int((transformPreviewScale * 100).rounded()))%")
                        metricRow(language == .japanese ? "状態" : "State", value: transformPreviewOffset == .zero ? (language == .japanese ? "待機" : "Idle") : (language == .japanese ? "未確定" : "Pending"))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    store.brushColor.opacity(0.92),
                                    store.brushColor.opacity(0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 122)
                        .overlay(
                            BrushStrokePreview(style: currentBrushPreviewStyle)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        )

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 90), spacing: 10),
                            GridItem(.flexible(minimum: 90), spacing: 10)
                        ],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        metricRow(language == .japanese ? "先端" : "Tip", value: store.brushTipKind.localizedTitle(language))
                        metricRow(language == .japanese ? "半径" : "Radius", value: "\(Int(store.brushRadius)) px")
                        metricRow(language == .japanese ? "形状" : "Shape", value: "\(Int(store.brushRoundness * 100))%")
                        metricRow(language == .japanese ? "角度" : "Angle", value: "\(Int((store.brushAngle * 180 / .pi).rounded()))°")
                        metricRow(language == .japanese ? "不透明度" : "Opacity", value: "\(Int(store.brushOpacity * 100))%")
                        metricRow(language == .japanese ? "間隔" : "Spacing", value: "\(Int(store.brushSpacing * 100))%")
                        metricRow(language == .japanese ? "散布" : "Scatter", value: store.brushScatterEnabled ? (language == .japanese ? "オン" : "On") : (language == .japanese ? "オフ" : "Off"))
                        metricRow(language == .japanese ? "テクスチャ" : "Texture", value: store.brushTextureMode.localizedTitle(language))
                        metricRow(language == .japanese ? "フロー" : "Flow", value: "\(Int(store.brushFlow * 100))%")
                        metricRow(language == .japanese ? "紙質" : "Paper", value: "\(Int(store.brushPaperStrength * 100))%")
                    }
                }
            }
            }
        }
    }

    private func controlsCard(showsChrome: Bool) -> some View {
        cardContainer(showsChrome: showsChrome) {
            VStack(alignment: .leading, spacing: 10) {
            if currentTool == .fill {
                segmentedModeRow(
                    title: language == .japanese ? "しきい値モード" : "Threshold Mode",
                    selectedTitle: store.fillThresholdMode.localizedTitle(language)
                ) {
                    Picker(language == .japanese ? "しきい値モード" : "Threshold Mode", selection: $store.fillThresholdMode) {
                        ForEach(FillThresholdMode.allCases) { mode in
                            Text(mode.localizedTitle(language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                sliderRow(
                    title: store.fillThresholdMode == .opacity ? (language == .japanese ? "不透明度しきい値" : "Opacity Threshold") : (language == .japanese ? "色しきい値" : "Color Threshold"),
                    value: "\(Int((store.fillThresholdMode == .opacity ? store.fillOpacityTolerance : store.fillColorTolerance) * 100))%",
                    slider: Group {
                        if store.fillThresholdMode == .opacity {
                            Slider(value: $store.fillOpacityTolerance, in: 0.0...1.0)
                        } else {
                            Slider(value: $store.fillColorTolerance, in: 0.0...1.0)
                        }
                    }
                )
                sliderRow(
                    title: language == .japanese ? "拡張" : "Expansion",
                    value: "\(Int(store.fillExpansion)) px",
                    slider: Slider(value: $store.fillExpansion, in: 0...24, step: 1)
                )
            } else if currentTool == .eyedropper {
                segmentedModeRow(
                    title: language == .japanese ? "取得元" : "Sampling Source",
                    selectedTitle: store.eyedropperSamplingSource.localizedTitle(language)
                ) {
                    Picker(language == .japanese ? "取得元" : "Sampling Source", selection: $store.eyedropperSamplingSource) {
                        ForEach(EyedropperSamplingSource.allCases) { source in
                            Text(source.localizedTitle(language)).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(language == .japanese ? "Apple Pencil でタップまたはドラッグすると色を取得して現在色に反映します。" : "Tap or drag with Apple Pencil to sample a color into the current paint color.")
                    .font(StudioTheme.Typography.body(11))
                    .foregroundStyle(.white.opacity(0.62))
            } else if currentTool == .select {
                segmentedModeRow(
                    title: language == .japanese ? "選択アクション" : "Selection Action",
                    selectedTitle: store.selectionCombineMode.localizedTitle(language)
                ) {
                    Picker(language == .japanese ? "選択アクション" : "Selection Action", selection: $store.selectionCombineMode) {
                        ForEach(SelectionCombineMode.allCases) { mode in
                            Text(mode.localizedTitle(language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                segmentedModeRow(
                    title: language == .japanese ? "選択モード" : "Selection Mode",
                    selectedTitle: store.selectionToolMode.localizedTitle(language)
                ) {
                    Picker(language == .japanese ? "選択モード" : "Selection Mode", selection: $store.selectionToolMode) {
                        ForEach(SelectionToolMode.allCases) { mode in
                            Text(mode.localizedTitle(language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if store.selectionToolMode == .auto {
                    segmentedModeRow(
                        title: language == .japanese ? "しきい値モード" : "Threshold Mode",
                        selectedTitle: store.selectionThresholdMode.localizedTitle(language)
                    ) {
                        Picker(language == .japanese ? "選択しきい値モード" : "Selection Threshold Mode", selection: $store.selectionThresholdMode) {
                            ForEach(FillThresholdMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    sliderRow(
                        title: store.selectionThresholdMode == .opacity ? (language == .japanese ? "不透明度しきい値" : "Opacity Threshold") : (language == .japanese ? "色しきい値" : "Color Threshold"),
                        value: "\(Int((store.selectionThresholdMode == .opacity ? store.selectionOpacityTolerance : store.selectionColorTolerance) * 100))%",
                        slider: Group {
                            if store.selectionThresholdMode == .opacity {
                                Slider(value: $store.selectionOpacityTolerance, in: 0.0...1.0)
                            } else {
                                Slider(value: $store.selectionColorTolerance, in: 0.0...1.0)
                            }
                        }
                    )
                    sliderRow(
                        title: language == .japanese ? "拡張" : "Expansion",
                        value: "\(Int(store.selectionExpansion)) px",
                        slider: Slider(value: $store.selectionExpansion, in: 0...24, step: 1)
                    )
                }
                Button {
                    store.send(.clearSelectionButtonTapped)
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text(language == .japanese ? "選択を解除" : "Clear Selection")
                            .font(StudioTheme.Typography.label(12))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(StudioTheme.Palette.cardFillStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else if currentTool == .move {
                VStack(alignment: .leading, spacing: 10) {
                    Text(hasSelection ? (language == .japanese ? "Apple Pencil で選択範囲を移動します。適用するまで確定されません。" : "Move the selected area with Pencil. Nothing is committed until you apply.") : (language == .japanese ? "Apple Pencil でアクティブレイヤーを移動します。適用するまで確定されません。" : "Move the active layer with Pencil. Nothing is committed until you apply."))
                        .font(StudioTheme.Typography.body(11))
                        .foregroundStyle(.white.opacity(0.62))

                    HStack(spacing: 8) {
                        Button {
                            store.send(.applyTransformButtonTapped)
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(language == .japanese ? "適用" : "Apply")
                                    .font(StudioTheme.Typography.label(12))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.white.opacity(0.92))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(StudioTheme.Palette.accent)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.send(.cancelTransformButtonTapped)
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(language == .japanese ? "キャンセル" : "Cancel")
                                    .font(StudioTheme.Typography.label(12))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(StudioTheme.Palette.cardFillStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Picker("", selection: $selectedBrushSettingsCategory) {
                    ForEach(BrushSettingsCategory.allCases) { category in
                        Text(category.localizedTitle(language)).tag(category)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedBrushSettingsCategory {
                case .tip:
                    sectionLabel(language == .japanese ? "先端形状" : "Brush Tip Shape")
                    segmentedModeRow(
                        title: language == .japanese ? "ブラシ先端" : "Brush Tip",
                        selectedTitle: store.brushTipKind.localizedTitle(language)
                    ) {
                        VStack(spacing: 8) {
                            ForEach(BrushTipKind.allCases) { tipKind in
                                brushTipButton(tipKind: tipKind, isSelected: store.brushTipKind == tipKind) {
                                    store.brushTipKind = tipKind
                                }
                            }
                        }
                    }
                    sliderRow(title: language == .japanese ? "サイズ" : "Size", value: "\(Int(store.brushRadius)) px", slider: Slider(value: $store.brushRadius, in: 1...100))
                    dynamicControlMenuRow(
                        title: language == .japanese ? "サイズコントロール" : "Size Control",
                        selection: sizeControlBinding,
                        allowed: [.off, .pressure, .speed]
                    )
                    sliderRow(title: language == .japanese ? "サイズ量" : "Size Amount", value: "\(Int(sizeAmountBinding.wrappedValue * 100))%", slider: Slider(value: sizeAmountBinding, in: 0.0...1.0))
                    sliderRow(title: language == .japanese ? "形状の細さ" : "Roundness", value: "\(Int(store.brushRoundness * 100))%", slider: Slider(value: $store.brushRoundness, in: 0.2...1.0))
                    dynamicControlMenuRow(
                        title: language == .japanese ? "形状コントロール" : "Roundness Control",
                        selection: roundnessControlBinding,
                        allowed: [.off, .pressure, .tilt, .random]
                    )
                    sliderRow(title: language == .japanese ? "形状量" : "Roundness Amount", value: "\(Int(roundnessAmountBinding.wrappedValue * 100))%", slider: Slider(value: roundnessAmountBinding, in: 0.0...1.0))
                    segmentedModeRow(
                        title: language == .japanese ? "回転モード" : "Rotation Mode",
                        selectedTitle: store.brushAngleMode.localizedTitle(language)
                    ) {
                        Picker(language == .japanese ? "回転モード" : "Rotation Mode", selection: $store.brushAngleMode) {
                            ForEach(BrushAngleMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    sliderRow(title: language == .japanese ? "角度" : "Angle", value: "\(Int((store.brushAngle * 180 / .pi).rounded()))°", slider: Slider(value: $store.brushAngle, in: -.pi / 2 ... .pi / 2))
                    dynamicControlMenuRow(
                        title: language == .japanese ? "角度コントロール" : "Angle Control",
                        selection: angleControlBinding,
                        allowed: [.off, .pressure, .tilt, .random]
                    )
                    sliderRow(title: language == .japanese ? "角度量" : "Angle Amount", value: "\(Int(angleAmountBinding.wrappedValue * 100))%", slider: Slider(value: angleAmountBinding, in: 0.0...1.0))
                    sliderRow(title: language == .japanese ? "硬さ" : "Hardness", value: "\(Int(store.brushHardness * 100))%", slider: Slider(value: $store.brushHardness, in: 0.2...0.98))

                case .scatter:
                    sectionLabel("Scattering")
                    Toggle(isOn: $store.brushScatterEnabled) {
                        Text(language == .japanese ? "散布を有効にする" : "Enable Scatter")
                            .font(StudioTheme.Typography.title(12))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .tint(StudioTheme.Palette.accentBright)
                    sliderRow(title: language == .japanese ? "スタンプ間隔" : "Spacing", value: "\(Int(store.brushSpacing * 100))%", slider: Slider(value: $store.brushSpacing, in: 0.08...0.8))
                    if store.brushScatterEnabled {
                        sliderRow(title: language == .japanese ? "間隔ジッター" : "Spacing Jitter", value: "\(Int(store.brushSpacingJitter * 100))%", slider: Slider(value: $store.brushSpacingJitter, in: 0.0...0.5))
                        segmentedModeRow(
                            title: language == .japanese ? "散布方式" : "Scatter Mode",
                            selectedTitle: store.brushScatterMode.localizedTitle(language)
                        ) {
                            Picker(language == .japanese ? "散布方式" : "Scatter Mode", selection: $store.brushScatterMode) {
                                ForEach(BrushScatterMode.allCases) { mode in
                                    Text(mode.localizedTitle(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        sliderRow(title: language == .japanese ? "横散布" : "Scatter X", value: "\(Int(store.brushScatterLateral * 100))%", slider: Slider(value: $store.brushScatterLateral, in: 0.0...0.6))
                        sliderRow(title: language == .japanese ? "前後散布" : "Scatter Y", value: "\(Int(store.brushScatterLinear * 100))%", slider: Slider(value: $store.brushScatterLinear, in: 0.0...0.4))
                        sliderRow(title: language == .japanese ? "散布数" : "Count", value: "\(Int(store.brushCount.rounded()))", slider: Slider(value: $store.brushCount, in: 1...4, step: 1))
                        sliderRow(title: language == .japanese ? "数ジッター" : "Count Jitter", value: "\(Int(store.brushCountJitter * 100))%", slider: Slider(value: $store.brushCountJitter, in: 0.0...1.0))
                        sliderRow(title: language == .japanese ? "粒サイズばらつき" : "Particle Size", value: "\(Int(store.brushCountSizeJitter * 100))%", slider: Slider(value: $store.brushCountSizeJitter, in: 0.0...1.0))
                        sliderRow(title: language == .japanese ? "粒濃度ばらつき" : "Particle Opacity", value: "\(Int(store.brushCountOpacityJitter * 100))%", slider: Slider(value: $store.brushCountOpacityJitter, in: 0.0...1.0))
                    }

                case .stroke:
                    sectionLabel("Transfer")
                    sliderRow(title: language == .japanese ? "不透明度" : "Opacity", value: "\(Int(store.brushOpacity * 100))%", slider: Slider(value: $store.brushOpacity, in: 0.1...1.0))
                    dynamicControlMenuRow(
                        title: language == .japanese ? "不透明度コントロール" : "Opacity Control",
                        selection: opacityControlBinding,
                        allowed: [.off, .pressure]
                    )
                    sliderRow(title: language == .japanese ? "不透明度量" : "Opacity Amount", value: "\(Int(opacityAmountBinding.wrappedValue * 100))%", slider: Slider(value: opacityAmountBinding, in: 0.0...1.0))
                    sliderRow(title: language == .japanese ? "フロー" : "Flow", value: "\(Int(store.brushFlow * 100))%", slider: Slider(value: $store.brushFlow, in: 0.05...1.0))
                    dynamicControlMenuRow(
                        title: language == .japanese ? "フローコントロール" : "Flow Control",
                        selection: flowControlBinding,
                        allowed: [.off, .pressure, .random]
                    )
                    sliderRow(title: language == .japanese ? "フロー量" : "Flow Amount", value: "\(Int(flowAmountBinding.wrappedValue * 100))%", slider: Slider(value: flowAmountBinding, in: 0.0...1.0))
                    segmentedModeRow(
                        title: language == .japanese ? "速度で濃さを変える" : "Speed Density",
                        selectedTitle: store.brushVelocityInfluence > 0.001 ? (language == .japanese ? "オン" : "On") : (language == .japanese ? "オフ" : "Off")
                    ) {
                        Picker(language == .japanese ? "速度で濃さを変える" : "Speed Density", selection: velocityDensityControlBinding) {
                            Text(language == .japanese ? "オフ" : "Off").tag(false)
                            Text(language == .japanese ? "オン" : "On").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    sliderRow(title: language == .japanese ? "手ぶれ補正" : "Stabilization", value: "\(Int(store.brushStabilization * 100))%", slider: Slider(value: $store.brushStabilization, in: 0.0...1.0))

                case .texture:
                    sectionLabel("Texture")
                    segmentedModeRow(
                        title: language == .japanese ? "テクスチャ適用" : "Texture Apply",
                        selectedTitle: store.brushTextureMode.localizedTitle(language)
                    ) {
                        Picker(language == .japanese ? "テクスチャ適用" : "Texture Apply", selection: $store.brushTextureMode) {
                            ForEach(BrushTextureMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    sliderRow(title: language == .japanese ? "先端テクスチャ" : "Tip Texture", value: "\(Int(store.brushTextureStrength * 100))%", slider: Slider(value: $store.brushTextureStrength, in: 0.0...1.0))
                    segmentedModeRow(
                        title: language == .japanese ? "ミキサーブラシ" : "Mixer Brush",
                        selectedTitle: "Wet / Load / Mix / Flow"
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            sliderRow(title: language == .japanese ? "ウェット" : "Wet", value: "\(Int(store.brushWetness * 100))%", slider: Slider(value: $store.brushWetness, in: 0.0...1.0))
                            dynamicControlMenuRow(
                                title: language == .japanese ? "ウェットコントロール" : "Wet Control",
                                selection: wetnessControlBinding,
                                allowed: [.off, .pressure]
                            )
                            sliderRow(title: language == .japanese ? "ウェット量" : "Wet Amount", value: "\(Int(wetnessAmountBinding.wrappedValue * 100))%", slider: Slider(value: wetnessAmountBinding, in: 0.0...1.0))
                            sliderRow(title: language == .japanese ? "混色量" : "Mix Strength", value: "\(Int(store.brushColorMixStrength * 100))%", slider: Slider(value: $store.brushColorMixStrength, in: 0.0...1.0))
                            sliderRow(title: language == .japanese ? "色の含み" : "Paint Load", value: "\(Int(store.brushPaintLoad * 100))%", slider: Slider(value: $store.brushPaintLoad, in: 0.0...1.0))
                            dynamicControlMenuRow(
                                title: language == .japanese ? "含みコントロール" : "Load Control",
                                selection: loadControlBinding,
                                allowed: [.off, .pressure]
                            )
                            sliderRow(title: language == .japanese ? "含み量" : "Load Amount", value: "\(Int(loadAmountBinding.wrappedValue * 100))%", slider: Slider(value: loadAmountBinding, in: 0.0...1.0))
                        }
                    }
                    segmentedModeRow(
                        title: language == .japanese ? "デュアルブラシ" : "Dual Brush",
                        selectedTitle: store.brushDualEnabled ? store.brushDualBlendMode.localizedTitle(language) : (language == .japanese ? "オフ" : "Off")
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $store.brushDualEnabled) {
                                Text(language == .japanese ? "デュアルブラシを使う" : "Enable dual brush")
                                    .font(StudioTheme.Typography.label(11))
                                    .foregroundStyle(.white.opacity(0.86))
                            }
                            .toggleStyle(.switch)

                            if store.brushDualEnabled {
                                Picker(language == .japanese ? "デュアル先端" : "Dual Tip", selection: $store.brushDualTipKind) {
                                    ForEach(BrushTipKind.allCases) { tipKind in
                                        Text(tipKind.localizedTitle(language)).tag(tipKind)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Picker(language == .japanese ? "合成" : "Blend", selection: $store.brushDualBlendMode) {
                                    ForEach(BrushDualBlendMode.allCases) { mode in
                                        Text(mode.localizedTitle(language)).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                sliderRow(title: language == .japanese ? "デュアルサイズ" : "Dual Scale", value: "\(Int(store.brushDualScale * 100))%", slider: Slider(value: $store.brushDualScale, in: 0.25...1.5))
                                sliderRow(title: language == .japanese ? "デュアル間隔" : "Dual Spacing", value: "\(Int(store.brushDualSpacing * 100))%", slider: Slider(value: $store.brushDualSpacing, in: 0.0...0.8))
                                sliderRow(title: language == .japanese ? "デュアル散布" : "Dual Scatter", value: "\(Int(store.brushDualScatter * 100))%", slider: Slider(value: $store.brushDualScatter, in: 0.0...0.8))
                                sliderRow(title: language == .japanese ? "デュアル角度" : "Dual Angle", value: "\(Int((store.brushDualAngle * 180 / .pi).rounded()))°", slider: Slider(value: $store.brushDualAngle, in: -.pi / 2 ... .pi / 2))
                            }
                        }
                    }
                    segmentedModeRow(
                        title: language == .japanese ? "紙質テクスチャ" : "Paper Texture",
                        selectedTitle: "\(Int(store.brushPaperStrength * 100))%"
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            sliderRow(title: language == .japanese ? "紙質の強さ" : "Paper Strength", value: "\(Int(store.brushPaperStrength * 100))%", slider: Slider(value: $store.brushPaperStrength, in: 0.0...1.0))
                            sliderRow(title: language == .japanese ? "紙目スケール" : "Paper Scale", value: String(format: "%.2f", store.brushPaperScale), slider: Slider(value: $store.brushPaperScale, in: 0.04...0.30))
                            sliderRow(title: language == .japanese ? "紙目しきい値" : "Paper Threshold", value: "\(Int(store.brushPaperThreshold * 100))%", slider: Slider(value: $store.brushPaperThreshold, in: 0.15...0.75))
                            sliderRow(title: language == .japanese ? "粒状感" : "Grain Scale", value: String(format: "%.2f", store.brushGrainScale), slider: Slider(value: $store.brushGrainScale, in: 0.6...2.8))
                            sliderRow(title: language == .japanese ? "粒コントラスト" : "Grain Contrast", value: String(format: "%.2f", store.brushGrainContrast), slider: Slider(value: $store.brushGrainContrast, in: 0.8...2.8))
                        }
                    }
                }
            }
            }
        }
    }

    @ViewBuilder
    private func detailCard(showsChrome: Bool) -> some View {
        if currentTool != .select && currentTool != .move {
            cardContainer(showsChrome: showsChrome) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            StudioTheme.Palette.textPrimary,
                                            Color.white.opacity(0.55)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(store.brushColor)
                                .padding(4)
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(currentTool == .fill ? (language == .japanese ? "塗り色" : "Fill Color") : (currentTool == .eyedropper ? (language == .japanese ? "取得色" : "Sampled Color") : (language == .japanese ? "色" : "Color")))
                                .font(StudioTheme.Typography.title(14))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(
                                currentTool == .fill
                                    ? (store.selectedBrush?.name ?? (language == .japanese ? "カスタム" : "Custom Mix"))
                                    : (currentTool == .eyedropper
                                        ? colorHexLabel
                                        : (store.selectedBrush?.name ?? "\(store.brushTipKind.localizedTitle(language)) \(language == .japanese ? "カスタム" : "Custom")"))
                            )
                                .font(StudioTheme.Typography.body(11))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }

                    SpectrumColorControl(color: $store.brushColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(StudioTheme.Palette.hairline)
                        )

                    LazyVGrid(columns: paletteColumns, alignment: .leading, spacing: 8) {
                        ForEach(PaletteSwatch.defaults) { swatch in
                            colorSwatch(color: swatch.color, isSelected: false) {
                                store.send(.binding(.set(\.brushColor, swatch.color)))
                            }
                        }
                    }
                }
            }

        } else {
            cardContainer(showsChrome: showsChrome) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            StudioTheme.Palette.accent,
                                            StudioTheme.Palette.coolGlow
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Image(systemName: "selection.pin.in.out")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(language == .japanese ? "選択" : "Selection")
                                .font(StudioTheme.Typography.title(14))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(store.selectionToolMode == .lasso ? (language == .japanese ? "Apple Pencil で囲んだあと、移動ツールで変形します" : "Trace with Pencil, then use Move to transform") : (language == .japanese ? "タップで選択したあと、移動ツールで変形します" : "Tap to sample, then use Move to transform"))
                                .font(StudioTheme.Typography.body(11))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var panelTitle: String {
        switch currentTool {
        case .fill:
            return currentTool.localizedTitle(language)
        case .eyedropper:
            return currentTool.localizedTitle(language)
        case .select:
            return currentTool.localizedTitle(language)
        case .move:
            return currentTool.localizedTitle(language)
        default:
            return StudioToolKind.brush.localizedTitle(language)
        }
    }

    private var currentBrushPreviewStyle: BrushPreviewStyle {
        BrushPreviewStyle(
            color: .white,
            radius: store.brushRadius,
            opacity: store.brushOpacity,
            roundness: store.brushRoundness,
            angle: store.brushAngle,
            spacing: store.brushSpacing,
            scatterEnabled: store.brushScatterEnabled,
            scatterMode: store.brushScatterMode,
            scatterLateral: store.brushScatterLateral,
            scatterLinear: store.brushScatterLinear,
            count: Int(store.brushCount.rounded()),
            countSizeJitter: store.brushCountSizeJitter,
            countOpacityJitter: store.brushCountOpacityJitter,
            textureStrength: store.brushTextureStrength,
            flow: store.brushFlow
        )
    }

    private var sectionTitle: String {
        switch currentTool {
        case .fill:
            return language == .japanese ? "塗りつぶし設定" : "Fill Engine"
        case .eyedropper:
            return language == .japanese ? "スポイト設定" : "Eyedropper"
        case .select:
            return language == .japanese ? "選択設定" : "Selection"
        case .move:
            return language == .japanese ? "変形" : "Transform"
        default:
            return language == .japanese ? "ブラシ設定" : "Brush Engine"
        }
    }

    private var sizeControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brushSizeSpeedSensitivity > 0.001 { return .speed }
                if store.brushPressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                switch newValue {
                case .off:
                    store.brushPressureSensitivity = 0.0
                    store.brushSizeSpeedSensitivity = 0.0
                case .pressure:
                    if store.brushPressureSensitivity <= 0.001 { store.brushPressureSensitivity = 0.6 }
                    store.brushSizeSpeedSensitivity = 0.0
                case .speed:
                    store.brushPressureSensitivity = 0.0
                    if store.brushSizeSpeedSensitivity <= 0.001 { store.brushSizeSpeedSensitivity = 0.25 }
                case .tilt, .random:
                    break
                }
            }
        )
    }

    private var colorHexLabel: String {
        let resolved = UIColor(store.brushColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int((red * 255.0).rounded()),
            Int((green * 255.0).rounded()),
            Int((blue * 255.0).rounded())
        )
    }

    private var sizeAmountBinding: Binding<Double> {
        Binding(
            get: {
                switch sizeControlBinding.wrappedValue {
                case .pressure: return store.brushPressureSensitivity
                case .speed: return store.brushSizeSpeedSensitivity
                default: return 0.0
                }
            },
            set: { newValue in
                switch sizeControlBinding.wrappedValue {
                case .pressure: store.brushPressureSensitivity = newValue
                case .speed: store.brushSizeSpeedSensitivity = newValue
                default: break
                }
            }
        )
    }

    private var roundnessControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brushRoundnessJitter > 0.001 { return .random }
                if store.brushRoundnessTiltSensitivity > 0.001 { return .tilt }
                if store.brushRoundnessPressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                store.brushRoundnessPressureSensitivity = 0.0
                store.brushRoundnessTiltSensitivity = 0.0
                store.brushRoundnessJitter = 0.0
                switch newValue {
                case .pressure:
                    store.brushRoundnessPressureSensitivity = 0.24
                case .tilt:
                    store.brushRoundnessTiltSensitivity = 0.24
                case .random:
                    store.brushRoundnessJitter = 0.12
                case .off, .speed:
                    break
                }
            }
        )
    }

    private var roundnessAmountBinding: Binding<Double> {
        Binding(
            get: {
                switch roundnessControlBinding.wrappedValue {
                case .pressure: return store.brushRoundnessPressureSensitivity
                case .tilt: return store.brushRoundnessTiltSensitivity
                case .random: return store.brushRoundnessJitter
                default: return 0.0
                }
            },
            set: { newValue in
                switch roundnessControlBinding.wrappedValue {
                case .pressure: store.brushRoundnessPressureSensitivity = newValue
                case .tilt: store.brushRoundnessTiltSensitivity = newValue
                case .random: store.brushRoundnessJitter = newValue
                default: break
                }
            }
        )
    }

    private var angleControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brushAngleJitter > 0.001 { return .random }
                if store.brushAngleTiltSensitivity > 0.001 { return .tilt }
                if store.brushAnglePressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                store.brushAnglePressureSensitivity = 0.0
                store.brushAngleTiltSensitivity = 0.0
                store.brushAngleJitter = 0.0
                switch newValue {
                case .pressure:
                    store.brushAnglePressureSensitivity = 0.16
                case .tilt:
                    store.brushAngleTiltSensitivity = 0.24
                case .random:
                    store.brushAngleJitter = 0.14
                case .off, .speed:
                    break
                }
            }
        )
    }

    private var angleAmountBinding: Binding<Double> {
        Binding(
            get: {
                switch angleControlBinding.wrappedValue {
                case .pressure: return store.brushAnglePressureSensitivity
                case .tilt: return store.brushAngleTiltSensitivity
                case .random: return min(1.0, store.brushAngleJitter)
                default: return 0.0
                }
            },
            set: { newValue in
                switch angleControlBinding.wrappedValue {
                case .pressure: store.brushAnglePressureSensitivity = newValue
                case .tilt: store.brushAngleTiltSensitivity = newValue
                case .random: store.brushAngleJitter = newValue
                default: break
                }
            }
        )
    }

    private var opacityControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: { store.brushOpacityPressureSensitivity > 0.001 ? .pressure : .off },
            set: { newValue in
                store.brushOpacityPressureSensitivity = newValue == .pressure ? max(store.brushOpacityPressureSensitivity, 0.4) : 0.0
            }
        )
    }

    private var opacityAmountBinding: Binding<Double> {
        Binding(
            get: { 1.0 - store.brushOpacityPressureSensitivity },
            set: { store.brushOpacityPressureSensitivity = 1.0 - $0 }
        )
    }

    private var flowControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brushFlowJitter > 0.001 { return .random }
                if store.brushFlowPressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                store.brushFlowPressureSensitivity = 0.0
                store.brushFlowJitter = 0.0
                switch newValue {
                case .pressure:
                    store.brushFlowPressureSensitivity = 0.24
                case .random:
                    store.brushFlowJitter = 0.18
                case .off, .tilt, .speed:
                    break
                }
            }
        )
    }

    private var flowAmountBinding: Binding<Double> {
        Binding(
            get: {
                switch flowControlBinding.wrappedValue {
                case .pressure: return 1.0 - store.brushFlowPressureSensitivity
                case .random: return 1.0 - store.brushFlowJitter
                default: return 0.0
                }
            },
            set: { newValue in
                switch flowControlBinding.wrappedValue {
                case .pressure: store.brushFlowPressureSensitivity = 1.0 - newValue
                case .random: store.brushFlowJitter = 1.0 - newValue
                default: break
                }
            }
        )
    }

    private var velocityDensityControlBinding: Binding<Bool> {
        Binding(
            get: { store.brushVelocityInfluence > 0.001 },
            set: { enabled in
                store.brushVelocityInfluence = enabled ? 0.012 : 0.0
            }
        )
    }

    private var wetnessControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: { store.brushWetnessPressureSensitivity > 0.001 ? .pressure : .off },
            set: { newValue in
                store.brushWetnessPressureSensitivity = newValue == .pressure ? max(store.brushWetnessPressureSensitivity, 0.3) : 0.0
            }
        )
    }

    private var wetnessAmountBinding: Binding<Double> {
        Binding(
            get: { 1.0 - store.brushWetnessPressureSensitivity },
            set: { store.brushWetnessPressureSensitivity = 1.0 - $0 }
        )
    }

    private var loadControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: { store.brushLoadPressureSensitivity > 0.001 ? .pressure : .off },
            set: { newValue in
                store.brushLoadPressureSensitivity = newValue == .pressure ? max(store.brushLoadPressureSensitivity, 0.24) : 0.0
            }
        )
    }

    private var loadAmountBinding: Binding<Double> {
        Binding(
            get: { 1.0 - store.brushLoadPressureSensitivity },
            set: { store.brushLoadPressureSensitivity = 1.0 - $0 }
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(StudioTheme.Typography.mono(10))
            .foregroundStyle(.white.opacity(0.48))
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.48))
            Spacer()
            Text(value)
                .font(StudioTheme.Typography.title(12))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private func sliderRow<SliderView: View>(title: String, value: String, slider: SliderView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(value)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            slider
                .tint(StudioTheme.Palette.accentBright)
                .frame(minHeight: 38)
                .contentShape(Rectangle())
        }
    }

    private func segmentedModeRow<Content: View>(
        title: String,
        selectedTitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(selectedTitle)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            content()
                .frame(minHeight: 32)
        }
    }

    private func dynamicControlMenuRow(
        title: String,
        selection: Binding<PhotoshopDynamicControl>,
        allowed: [PhotoshopDynamicControl]
    ) -> some View {
        segmentedModeRow(
            title: title,
            selectedTitle: selection.wrappedValue.localizedTitle(language)
        ) {
            Menu {
                ForEach(allowed) { control in
                    Button(control.localizedTitle(language)) {
                        selection.wrappedValue = control
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection.wrappedValue.localizedTitle(language))
                        .font(StudioTheme.Typography.label(11))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(StudioTheme.Palette.cardFillStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func colorSwatch(color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0.16), lineWidth: isSelected ? 2.5 : 1)
                        .padding(isSelected ? -4 : -2)
                )
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
    }

    private func presetChip(preset: BrushPreset, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                StudioTheme.Palette.overlayBlack.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                BrushStrokePreview(style: BrushPreviewStyle(preset: preset), compact: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(preset.name)
                        .font(StudioTheme.Typography.label(11))
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(1)
                    Text(preset.tipKind.localizedTitle(language))
                        .font(StudioTheme.Typography.mono(9))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(StudioTheme.Palette.overlayBlack.opacity(0.34))
                )
                .padding(8)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? StudioTheme.Palette.accent.opacity(0.28) : StudioTheme.Palette.hairline)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? StudioTheme.Palette.accent : StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var brushLibrarySidebar: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                if showsTitle {
                    Text(language == .japanese ? "ブラシライブラリ" : "Brush Library")
                        .font(StudioTheme.Typography.title(18))
                        .foregroundStyle(.white.opacity(0.94))
                }

                HStack(spacing: 8) {
                    sidebarIconButton(
                        title: language == .japanese ? "設定" : "Settings",
                        systemImage: "slider.horizontal.3",
                        isActive: showsBrushSettingsPopover
                    ) {
                        showsBrushSettingsPopover.toggle()
                    }

                    sidebarIconButton(
                        title: language == .japanese ? "保存" : "Save",
                        systemImage: "square.and.arrow.down.on.square"
                    ) {
                        store.send(.saveCurrentBrushButtonTapped)
                    }

                    sidebarIconButton(
                        title: language == .japanese ? "管理" : "Manage",
                        systemImage: "trash",
                        isActive: showsSavedBrushDeleteMode
                    ) {
                        showsSavedBrushDeleteMode.toggle()
                    }

                    sidebarIconButton(
                        title: language == .japanese ? "読込" : "Import",
                        systemImage: "square.and.arrow.down"
                    ) {
                        isImportingBrush = true
                    }
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        brushLibrarySection(
                            title: language == .japanese ? "保存済み" : "Saved",
                            presets: store.savedPresets,
                            emptyMessage: language == .japanese ? "保存したブラシがここに並びます。" : "Saved brushes appear here.",
                            allowsDeletion: true
                        )

                        brushLibrarySection(
                            title: language == .japanese ? "プリセット" : "Presets",
                            presets: store.presets,
                            emptyMessage: language == .japanese ? "まだプリセットがありません。" : "No presets yet.",
                            allowsDeletion: false
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                verticalBrushSlider(
                    title: language == .japanese ? "サイズ" : "Size",
                    valueText: "\(Int(store.brushRadius.rounded()))",
                    normalizedValue: Binding(
                        get: { min(max((store.brushRadius - 1.0) / 99.0, 0.0), 1.0) },
                        set: { store.brushRadius = 1.0 + ($0 * 99.0) }
                    )
                )

                verticalBrushSlider(
                    title: language == .japanese ? "不透明" : "Opacity",
                    valueText: "\(Int((store.brushOpacity * 100).rounded()))%",
                    normalizedValue: $store.brushOpacity
                )
            }
            .frame(width: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private func verticalBrushSlider(
        title: String,
        valueText: String,
        normalizedValue: Binding<Double>
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(StudioTheme.Typography.mono(8))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VerticalValueSlider(value: normalizedValue)
                .frame(width: 30, height: 132)

            Text(valueText)
                .font(StudioTheme.Typography.mono(8))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var floatingBrushSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(language == .japanese ? "ブラシ設定" : "Brush Settings")
                        .font(StudioTheme.Typography.title(15))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(store.selectedBrush?.name ?? (language == .japanese ? "カスタムブラシ" : "Custom Brush"))
                        .font(StudioTheme.Typography.body(11))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer(minLength: 0)

                Button {
                    showsBrushSettingsPopover = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(StudioTheme.Palette.hairline)
                        )
                }
                .buttonStyle(.plain)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard(showsChrome: false)
                    controlsCard(showsChrome: false)
                    detailCard(showsChrome: false)
                }
                .padding(.bottom, 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.26), radius: 18, x: 0, y: 16)
    }

    private func cardContainer<Content: View>(
        showsChrome: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(showsChrome ? 14 : 0)
            .background(
                Group {
                    if showsChrome {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(StudioTheme.Palette.cardFill)
                    }
                }
            )
            .overlay(
                Group {
                    if showsChrome {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                    }
                }
            )
    }

    private func brushLibrarySection(
        title: String,
        presets: [BrushPreset],
        emptyMessage: String,
        allowsDeletion: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.48))

            if presets.isEmpty {
                Text(emptyMessage)
                    .font(StudioTheme.Typography.body(11))
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(presets) { preset in
                        if allowsDeletion && showsSavedBrushDeleteMode {
                            deletableSavedPresetChip(preset: preset)
                        } else {
                            presetChip(
                                preset: preset,
                                isSelected: store.selectedBrush == preset
                            ) {
                                store.send(.selectPreset(preset))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deletableSavedPresetChip(preset: BrushPreset) -> some View {
        ZStack(alignment: .topTrailing) {
            presetChip(
                preset: preset,
                isSelected: store.selectedBrush == preset
            ) {
                store.send(.deleteSavedPresetButtonTapped(preset.name))
            }

            Circle()
                .fill(Color.red.opacity(0.92))
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                )
                .padding(.top, 6)
                .padding(.trailing, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sidebarIconButton(
        title: String,
        systemImage: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(StudioTheme.Typography.mono(9))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? StudioTheme.Palette.accent.opacity(0.28) : StudioTheme.Palette.cardFillStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? StudioTheme.Palette.accent : StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func withSecurityScopedAccess<T>(to url: URL, _ work: () -> T) -> T {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return work()
    }

}

private extension BrushPaletteView {
    func brushTipButton(tipKind: BrushTipKind, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tipKind.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)

                Text(tipKind.localizedTitle(language))
                    .font(StudioTheme.Typography.label(11))

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.82))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? StudioTheme.Palette.accent.opacity(0.28) : StudioTheme.Palette.hairline)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? StudioTheme.Palette.accent : StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SpectrumColorControl: View {
    @Binding var color: Color
    @State private var activeRegion: ActiveRegion?

    private let ringWidth: CGFloat = 18
    private let gap: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let outerRect = CGRect(
                x: (geometry.size.width - size) / 2,
                y: (geometry.size.height - size) / 2,
                width: size,
                height: size
            )
            let squareSide = max(size - ((ringWidth + gap) * 2), 24)
            let squareRect = CGRect(
                x: outerRect.midX - (squareSide / 2),
                y: outerRect.midY - (squareSide / 2),
                width: squareSide,
                height: squareSide
            )
            let hsb = ColorHSB(color: color)
            let ringIndicator = ringIndicatorPoint(in: outerRect, hue: hsb.hue)
            let squareIndicator = CGPoint(
                x: squareRect.minX + (hsb.saturation * squareRect.width),
                y: squareRect.minY + ((1 - hsb.brightness) * squareRect.height)
            )

            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .red, .yellow, .green, .cyan, .blue, .purple, .red
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .frame(width: outerRect.width, height: outerRect.height)
                    .position(x: outerRect.midX, y: outerRect.midY)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hue: hsb.hue, saturation: 1, brightness: 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .frame(width: squareRect.width, height: squareRect.height)
                    .position(x: squareRect.midX, y: squareRect.midY)

                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .position(x: ringIndicator.x, y: ringIndicator.y)

                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .position(x: squareIndicator.x, y: squareIndicator.y)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeRegion == nil {
                            activeRegion = hitRegion(at: value.location, outerRect: outerRect, squareRect: squareRect)
                        }

                        switch activeRegion {
                        case .square:
                            updateSquare(at: value.location, within: squareRect, hue: hsb.hue)
                        case .ring:
                            updateRing(at: value.location, within: outerRect, current: hsb)
                        case .none:
                            break
                        }
                    }
                    .onEnded { _ in
                        activeRegion = nil
                    }
            )
        }
        .frame(height: 176)
    }

    private func hitRegion(at point: CGPoint, outerRect: CGRect, squareRect: CGRect) -> ActiveRegion? {
        if squareRect.contains(point) {
            return .square
        }

        let dx = point.x - outerRect.midX
        let dy = point.y - outerRect.midY
        let distance = sqrt((dx * dx) + (dy * dy))
        let outerRadius = outerRect.width / 2
        let innerRadius = outerRadius - ringWidth
        if distance >= innerRadius && distance <= outerRadius {
            return .ring
        }

        return nil
    }

    private func updateRing(at point: CGPoint, within rect: CGRect, current: ColorHSB) {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        let angle = atan2(dy, dx) + (.pi / 2)
        let normalized = (angle < 0 ? angle + (.pi * 2) : angle) / (.pi * 2)
        color = Color(hue: normalized, saturation: current.saturation, brightness: current.brightness)
    }

    private func updateSquare(at point: CGPoint, within rect: CGRect, hue: Double) {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let saturation = (clampedX - rect.minX) / rect.width
        let brightness = 1 - ((clampedY - rect.minY) / rect.height)
        color = Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func ringIndicatorPoint(in rect: CGRect, hue: Double) -> CGPoint {
        let angle = (hue * .pi * 2) - (.pi / 2)
        let radius = (rect.width - ringWidth) / 2
        return CGPoint(
            x: rect.midX + (cos(angle) * radius),
            y: rect.midY + (sin(angle) * radius)
        )
    }

    private enum ActiveRegion {
        case ring
        case square
    }
}

private struct VerticalValueSlider: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geometry in
            let normalized = min(max(value, 0.0), 1.0)
            let knobSize: CGFloat = 18
            let trackWidth: CGFloat = 6
            let travel = max(0, geometry.size.height - knobSize)
            let knobY = travel * CGFloat(1.0 - normalized)

            ZStack(alignment: .top) {
                Capsule(style: .continuous)
                    .fill(StudioTheme.Palette.cardFillStrong)
                    .frame(width: trackWidth)

                Capsule(style: .continuous)
                    .fill(StudioTheme.Palette.accentBright.opacity(0.95))
                    .frame(width: trackWidth, height: max(trackWidth, geometry.size.height - knobY - (knobSize / 2)))
                    .offset(y: knobY + (knobSize / 2))

                Circle()
                    .fill(Color.white.opacity(0.96))
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
                    .offset(y: knobY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let clampedY = min(max(gesture.location.y - (knobSize / 2), 0), travel)
                        value = Double(1.0 - (clampedY / max(travel, 1)))
                    }
            )
        }
    }
}

private struct ColorHSB {
    let hue: Double
    let saturation: Double
    let brightness: Double

    init(color: Color) {
        let resolved = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        self.hue = Double(hue)
        self.saturation = Double(saturation)
        self.brightness = Double(brightness)
    }
}

private struct PaletteSwatch: Identifiable {
    let id: String
    let color: Color

    static let defaults: [PaletteSwatch] = [
        PaletteSwatch(id: "graphite", color: Color(red: 0.14, green: 0.15, blue: 0.18)),
        PaletteSwatch(id: "ruby", color: Color(red: 0.77, green: 0.23, blue: 0.26)),
        PaletteSwatch(id: "amber", color: Color(red: 0.89, green: 0.61, blue: 0.18)),
        PaletteSwatch(id: "moss", color: Color(red: 0.34, green: 0.55, blue: 0.29)),
        PaletteSwatch(id: "lagoon", color: Color(red: 0.19, green: 0.55, blue: 0.72)),
        PaletteSwatch(id: "violet", color: Color(red: 0.49, green: 0.37, blue: 0.76)),
        PaletteSwatch(id: "rose", color: Color(red: 0.86, green: 0.46, blue: 0.59))
    ]
}
