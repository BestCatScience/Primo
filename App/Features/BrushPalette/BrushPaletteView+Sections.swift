import SwiftUI
import UIKit

extension BrushPaletteView {
    var showsBrushLibrarySidebar: Bool {
        currentTool == .brush || currentTool == .erase
    }

    func settingsPanelContent(showHeaderTitle: Bool) -> some View {
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

    func headerCard(showsChrome: Bool) -> some View {
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
                            metricRow(language.localized("Threshold"), value: store.fillThresholdMode.localizedTitle(language))
                            metricRow(
                                store.fillThresholdMode == .opacity ? (language.localized("Opacity Match")) : (language.localized("Color Match")),
                                value: "\(Int((store.fillThresholdMode == .opacity ? store.fillOpacityTolerance : store.fillColorTolerance) * 100))%"
                            )
                            metricRow(language.localized("Expansion"), value: "\(Int(store.fillExpansion)) px")
                            metricRow(language.localized("Color"), value: store.selectedBrush?.name ?? (language.localized("Custom Mix")))
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
                            metricRow(language.localized("Source"), value: store.eyedropperSamplingSource.localizedTitle(language))
                            metricRow(language.localized("Current Color"), value: colorHexLabel)
                            metricRow(language.localized("Input"), value: "Apple Pencil")
                            metricRow(language.localized("Behavior"), value: language.localized("Drag to sample continuously"))
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
                            metricRow(language.localized("Mode"), value: store.selectionToolMode.localizedTitle(language))
                            metricRow(language.localized("Combine"), value: store.selectionCombineMode.localizedTitle(language))
                            if store.selectionToolMode == .auto {
                                metricRow(language.localized("Threshold"), value: store.selectionThresholdMode.localizedTitle(language))
                                metricRow(
                                    language.localized("Match"),
                                    value: "\(Int((store.selectionThresholdMode == .opacity ? store.selectionOpacityTolerance : store.selectionColorTolerance) * 100))%"
                                )
                                metricRow(language.localized("Expansion"), value: "\(Int(store.selectionExpansion)) px")
                            } else {
                                metricRow(language.localized("Gesture"), value: language.localized("Freehand"))
                                metricRow(language.localized("Behavior"), value: language.localized("Close Path"))
                                metricRow(language.localized("Scope"), value: language.localized("Active Layer"))
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
                            metricRow(language.localized("Target"), value: hasSelection ? (language.localized("Selection")) : (language.localized("Layer")))
                            metricRow("Offset X", value: "\(Int(transformPreviewOffset.width.rounded())) px")
                            metricRow("Offset Y", value: "\(Int(transformPreviewOffset.height.rounded())) px")
                            metricRow(language.localized("Scale"), value: "\(Int((transformPreviewScale * 100).rounded()))%")
                            metricRow(language.localized("State"), value: transformPreviewOffset == .zero ? (language.localized("Idle")) : (language.localized("Pending")))
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
                            metricRow(language.localized("Tip"), value: store.brushTipKind.localizedTitle(language))
                            metricRow(language.localized("Radius"), value: "\(Int(store.brushRadius)) px")
                            metricRow(language.localized("Shape"), value: "\(Int(store.brushRoundness * 100))%")
                            metricRow(language.localized("Angle"), value: "\(Int((store.brushAngle * 180 / .pi).rounded()))°")
                            metricRow(language.localized("Opacity"), value: "\(Int(store.brushOpacity * 100))%")
                            metricRow(language.localized("Spacing"), value: "\(Int(store.brushSpacing * 100))%")
                            metricRow(language.localized("Scatter"), value: store.brushScatterEnabled ? (language.localized("On")) : (language.localized("Off")))
                            metricRow(language.localized("Texture"), value: store.brushTextureMode.localizedTitle(language))
                            metricRow(language.localized("Flow"), value: "\(Int(store.brushFlow * 100))%")
                            metricRow(language.localized("Paper"), value: "\(Int(store.brushPaperStrength * 100))%")
                        }
                    }
                }
            }
        }
    }

    func controlsCard(showsChrome: Bool) -> some View {
        cardContainer(showsChrome: showsChrome) {
            VStack(alignment: .leading, spacing: 10) {
                if currentTool == .fill {
                    segmentedModeRow(
                        title: language.localized("Threshold Mode"),
                        selectedTitle: store.fillThresholdMode.localizedTitle(language)
                    ) {
                        Picker(language.localized("Threshold Mode"), selection: $store.fillThresholdMode) {
                            ForEach(FillThresholdMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    sliderRow(
                        title: store.fillThresholdMode == .opacity ? (language.localized("Opacity Threshold")) : (language.localized("Color Threshold")),
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
                        title: language.localized("Expansion"),
                        value: "\(Int(store.fillExpansion)) px",
                        slider: Slider(value: $store.fillExpansion, in: 0...24, step: 1)
                    )
                } else if currentTool == .eyedropper {
                    segmentedModeRow(
                        title: language.localized("Sampling Source"),
                        selectedTitle: store.eyedropperSamplingSource.localizedTitle(language)
                    ) {
                        Picker(language.localized("Sampling Source"), selection: $store.eyedropperSamplingSource) {
                            ForEach(EyedropperSamplingSource.allCases) { source in
                                Text(source.localizedTitle(language)).tag(source)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text(language.localized("Tap or drag with Apple Pencil to sample a color into the current paint color."))
                        .font(StudioTheme.Typography.body(11))
                        .foregroundStyle(.white.opacity(0.62))
                } else if currentTool == .select {
                    segmentedModeRow(
                        title: language.localized("Selection Action"),
                        selectedTitle: store.selectionCombineMode.localizedTitle(language)
                    ) {
                        Picker(language.localized("Selection Action"), selection: $store.selectionCombineMode) {
                            ForEach(SelectionCombineMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    segmentedModeRow(
                        title: language.localized("Selection Mode"),
                        selectedTitle: store.selectionToolMode.localizedTitle(language)
                    ) {
                        Picker(language.localized("Selection Mode"), selection: $store.selectionToolMode) {
                            ForEach(SelectionToolMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if store.selectionToolMode == .auto {
                        segmentedModeRow(
                            title: language.localized("Threshold Mode"),
                            selectedTitle: store.selectionThresholdMode.localizedTitle(language)
                        ) {
                            Picker(language.localized("Selection Threshold Mode"), selection: $store.selectionThresholdMode) {
                                ForEach(FillThresholdMode.allCases) { mode in
                                    Text(mode.localizedTitle(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        sliderRow(
                            title: store.selectionThresholdMode == .opacity ? (language.localized("Opacity Threshold")) : (language.localized("Color Threshold")),
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
                            title: language.localized("Expansion"),
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
                            Text(language.localized("Clear Selection"))
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
                        Text(hasSelection ? (language.localized("Move the selected area with Pencil. Nothing is committed until you apply.")) : (language.localized("Move the active layer with Pencil. Nothing is committed until you apply.")))
                            .font(StudioTheme.Typography.body(11))
                            .foregroundStyle(.white.opacity(0.62))

                        HStack(spacing: 8) {
                            Button {
                                store.send(.applyTransformButtonTapped)
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(language.localized("Apply"))
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
                                    Text(language.localized("Cancel"))
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
                        sectionLabel(language.localized("Brush Tip Shape"))
                        segmentedModeRow(
                            title: language.localized("Brush Tip"),
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
                        sliderRow(title: language.localized("Size"), value: "\(Int(store.brushRadius)) px", slider: Slider(value: $store.brushRadius, in: 1...100))
                        dynamicControlMenuRow(
                            title: language.localized("Size Control"),
                            selection: sizeControlBinding,
                            allowed: [.off, .pressure, .speed]
                        )
                        sliderRow(title: language.localized("Size Amount"), value: "\(Int(sizeAmountBinding.wrappedValue * 100))%", slider: Slider(value: sizeAmountBinding, in: 0.0...1.0))
                        sliderRow(title: language.localized("Roundness"), value: "\(Int(store.brushRoundness * 100))%", slider: Slider(value: $store.brushRoundness, in: 0.2...1.0))
                        dynamicControlMenuRow(
                            title: language.localized("Roundness Control"),
                            selection: roundnessControlBinding,
                            allowed: [.off, .pressure, .tilt, .random]
                        )
                        sliderRow(title: language.localized("Roundness Amount"), value: "\(Int(roundnessAmountBinding.wrappedValue * 100))%", slider: Slider(value: roundnessAmountBinding, in: 0.0...1.0))
                        segmentedModeRow(
                            title: language.localized("Rotation Mode"),
                            selectedTitle: store.brushAngleMode.localizedTitle(language)
                        ) {
                            Picker(language.localized("Rotation Mode"), selection: $store.brushAngleMode) {
                                ForEach(BrushAngleMode.allCases) { mode in
                                    Text(mode.localizedTitle(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        sliderRow(title: language.localized("Angle"), value: "\(Int((store.brushAngle * 180 / .pi).rounded()))°", slider: Slider(value: $store.brushAngle, in: -.pi / 2 ... .pi / 2))
                        dynamicControlMenuRow(
                            title: language.localized("Angle Control"),
                            selection: angleControlBinding,
                            allowed: [.off, .pressure, .tilt, .random]
                        )
                        sliderRow(title: language.localized("Angle Amount"), value: "\(Int(angleAmountBinding.wrappedValue * 100))%", slider: Slider(value: angleAmountBinding, in: 0.0...1.0))
                        sliderRow(title: language.localized("Hardness"), value: "\(Int(store.brushHardness * 100))%", slider: Slider(value: $store.brushHardness, in: 0.2...0.98))

                    case .scatter:
                        sectionLabel("Scattering")
                        Toggle(isOn: $store.brushScatterEnabled) {
                            Text(language.localized("Enable Scatter"))
                                .font(StudioTheme.Typography.title(12))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        .tint(StudioTheme.Palette.accentBright)
                        sliderRow(title: language.localized("Spacing"), value: "\(Int(store.brushSpacing * 100))%", slider: Slider(value: $store.brushSpacing, in: 0.08...0.8))
                        if store.brushScatterEnabled {
                            sliderRow(title: language.localized("Spacing Jitter"), value: "\(Int(store.brushSpacingJitter * 100))%", slider: Slider(value: $store.brushSpacingJitter, in: 0.0...0.5))
                            segmentedModeRow(
                                title: language.localized("Scatter Mode"),
                                selectedTitle: store.brushScatterMode.localizedTitle(language)
                            ) {
                                Picker(language.localized("Scatter Mode"), selection: $store.brushScatterMode) {
                                    ForEach(BrushScatterMode.allCases) { mode in
                                        Text(mode.localizedTitle(language)).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            sliderRow(title: language.localized("Scatter X"), value: "\(Int(store.brushScatterLateral * 100))%", slider: Slider(value: $store.brushScatterLateral, in: 0.0...0.6))
                            sliderRow(title: language.localized("Scatter Y"), value: "\(Int(store.brushScatterLinear * 100))%", slider: Slider(value: $store.brushScatterLinear, in: 0.0...0.4))
                            sliderRow(title: language.localized("Count"), value: "\(Int(store.brushCount.rounded()))", slider: Slider(value: $store.brushCount, in: 1...4, step: 1))
                            sliderRow(title: language.localized("Count Jitter"), value: "\(Int(store.brushCountJitter * 100))%", slider: Slider(value: $store.brushCountJitter, in: 0.0...1.0))
                            sliderRow(title: language.localized("Particle Size"), value: "\(Int(store.brushCountSizeJitter * 100))%", slider: Slider(value: $store.brushCountSizeJitter, in: 0.0...1.0))
                            sliderRow(title: language.localized("Particle Opacity"), value: "\(Int(store.brushCountOpacityJitter * 100))%", slider: Slider(value: $store.brushCountOpacityJitter, in: 0.0...1.0))
                        }

                    case .stroke:
                        sectionLabel("Transfer")
                        sliderRow(title: language.localized("Opacity"), value: "\(Int(store.brushOpacity * 100))%", slider: Slider(value: $store.brushOpacity, in: 0.1...1.0))
                        dynamicControlMenuRow(
                            title: language.localized("Opacity Control"),
                            selection: opacityControlBinding,
                            allowed: [.off, .pressure]
                        )
                        sliderRow(title: language.localized("Opacity Amount"), value: "\(Int(opacityAmountBinding.wrappedValue * 100))%", slider: Slider(value: opacityAmountBinding, in: 0.0...1.0))
                        sliderRow(title: language.localized("Flow"), value: "\(Int(store.brushFlow * 100))%", slider: Slider(value: $store.brushFlow, in: 0.05...1.0))
                        dynamicControlMenuRow(
                            title: language.localized("Flow Control"),
                            selection: flowControlBinding,
                            allowed: [.off, .pressure, .random]
                        )
                        sliderRow(title: language.localized("Flow Amount"), value: "\(Int(flowAmountBinding.wrappedValue * 100))%", slider: Slider(value: flowAmountBinding, in: 0.0...1.0))
                        segmentedModeRow(
                            title: language.localized("Speed Density"),
                            selectedTitle: store.brushVelocityInfluence > 0.001 ? (language.localized("On")) : (language.localized("Off"))
                        ) {
                            Picker(language.localized("Speed Density"), selection: velocityDensityControlBinding) {
                                Text(language.localized("Off")).tag(false)
                                Text(language.localized("On")).tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        sliderRow(title: language.localized("Stabilization"), value: "\(Int(store.brushStabilization * 100))%", slider: Slider(value: $store.brushStabilization, in: 0.0...1.0))

                    case .texture:
                        sectionLabel("Texture")
                        segmentedModeRow(
                            title: language.localized("Texture Apply"),
                            selectedTitle: store.brushTextureMode.localizedTitle(language)
                        ) {
                            Picker(language.localized("Texture Apply"), selection: $store.brushTextureMode) {
                                ForEach(BrushTextureMode.allCases) { mode in
                                    Text(mode.localizedTitle(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        sliderRow(title: language.localized("Tip Texture"), value: "\(Int(store.brushTextureStrength * 100))%", slider: Slider(value: $store.brushTextureStrength, in: 0.0...1.0))
                        segmentedModeRow(
                            title: language.localized("Mixer Brush"),
                            selectedTitle: "Wet / Load / Mix / Flow"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                sliderRow(title: language.localized("Wet"), value: "\(Int(store.brushWetness * 100))%", slider: Slider(value: $store.brushWetness, in: 0.0...1.0))
                                dynamicControlMenuRow(
                                    title: language.localized("Wet Control"),
                                    selection: wetnessControlBinding,
                                    allowed: [.off, .pressure]
                                )
                                sliderRow(title: language.localized("Wet Amount"), value: "\(Int(wetnessAmountBinding.wrappedValue * 100))%", slider: Slider(value: wetnessAmountBinding, in: 0.0...1.0))
                                sliderRow(title: language.localized("Mix Strength"), value: "\(Int(store.brushColorMixStrength * 100))%", slider: Slider(value: $store.brushColorMixStrength, in: 0.0...1.0))
                                sliderRow(title: language.localized("Paint Load"), value: "\(Int(store.brushPaintLoad * 100))%", slider: Slider(value: $store.brushPaintLoad, in: 0.0...1.0))
                                dynamicControlMenuRow(
                                    title: language.localized("Load Control"),
                                    selection: loadControlBinding,
                                    allowed: [.off, .pressure]
                                )
                                sliderRow(title: language.localized("Load Amount"), value: "\(Int(loadAmountBinding.wrappedValue * 100))%", slider: Slider(value: loadAmountBinding, in: 0.0...1.0))
                            }
                        }
                        segmentedModeRow(
                            title: language.localized("Dual Brush"),
                            selectedTitle: store.brushDualEnabled ? store.brushDualBlendMode.localizedTitle(language) : (language.localized("Off"))
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(isOn: $store.brushDualEnabled) {
                                    Text(language.localized("Enable dual brush"))
                                        .font(StudioTheme.Typography.label(11))
                                        .foregroundStyle(.white.opacity(0.86))
                                }
                                .toggleStyle(.switch)

                                if store.brushDualEnabled {
                                    Picker(language.localized("Dual Tip"), selection: $store.brushDualTipKind) {
                                        ForEach(BrushTipKind.allCases) { tipKind in
                                            Text(tipKind.localizedTitle(language)).tag(tipKind)
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    Picker(language.localized("Blend"), selection: $store.brushDualBlendMode) {
                                        ForEach(BrushDualBlendMode.allCases) { mode in
                                            Text(mode.localizedTitle(language)).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    sliderRow(title: language.localized("Dual Scale"), value: "\(Int(store.brushDualScale * 100))%", slider: Slider(value: $store.brushDualScale, in: 0.25...1.5))
                                    sliderRow(title: language.localized("Dual Spacing"), value: "\(Int(store.brushDualSpacing * 100))%", slider: Slider(value: $store.brushDualSpacing, in: 0.0...0.8))
                                    sliderRow(title: language.localized("Dual Scatter"), value: "\(Int(store.brushDualScatter * 100))%", slider: Slider(value: $store.brushDualScatter, in: 0.0...0.8))
                                    sliderRow(title: language.localized("Dual Angle"), value: "\(Int((store.brushDualAngle * 180 / .pi).rounded()))°", slider: Slider(value: $store.brushDualAngle, in: -.pi / 2 ... .pi / 2))
                                }
                            }
                        }
                        segmentedModeRow(
                            title: language.localized("Paper Texture"),
                            selectedTitle: "\(Int(store.brushPaperStrength * 100))%"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                sliderRow(title: language.localized("Paper Strength"), value: "\(Int(store.brushPaperStrength * 100))%", slider: Slider(value: $store.brushPaperStrength, in: 0.0...1.0))
                                sliderRow(title: language.localized("Paper Scale"), value: String(format: "%.2f", store.brushPaperScale), slider: Slider(value: $store.brushPaperScale, in: 0.04...0.30))
                                sliderRow(title: language.localized("Paper Threshold"), value: "\(Int(store.brushPaperThreshold * 100))%", slider: Slider(value: $store.brushPaperThreshold, in: 0.15...0.75))
                                sliderRow(title: language.localized("Grain Scale"), value: String(format: "%.2f", store.brushGrainScale), slider: Slider(value: $store.brushGrainScale, in: 0.6...2.8))
                                sliderRow(title: language.localized("Grain Contrast"), value: String(format: "%.2f", store.brushGrainContrast), slider: Slider(value: $store.brushGrainContrast, in: 0.8...2.8))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func detailCard(showsChrome: Bool) -> some View {
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
                            Text(currentTool == .fill ? (language.localized("Fill Color")) : (currentTool == .eyedropper ? (language.localized("Sampled Color")) : (language.localized("Color"))))
                                .font(StudioTheme.Typography.title(14))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(
                                currentTool == .fill
                                    ? (store.selectedBrush?.name ?? (language.localized("Custom Mix")))
                                    : (currentTool == .eyedropper
                                        ? colorHexLabel
                                        : (store.selectedBrush?.name ?? "\(store.brushTipKind.localizedTitle(language)) \(language.localized("Custom"))"))
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
                            Text(language.localized("Selection"))
                                .font(StudioTheme.Typography.title(14))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(store.selectionToolMode == .lasso ? (language.localized("Trace with Pencil, then use Move to transform")) : (language.localized("Tap to sample, then use Move to transform")))
                                .font(StudioTheme.Typography.body(11))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    var panelTitle: String {
        switch currentTool {
        case .fill, .eyedropper, .select, .move:
            return currentTool.localizedTitle(language)
        default:
            return StudioToolKind.brush.localizedTitle(language)
        }
    }

    var currentBrushPreviewStyle: BrushPreviewStyle {
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

    var sectionTitle: String {
        switch currentTool {
        case .fill:
            return language.localized("Fill Engine")
        case .eyedropper:
            return language.localized("Eyedropper")
        case .select:
            return language.localized("Selection")
        case .move:
            return language.localized("Transform")
        default:
            return language.localized("Brush Engine")
        }
    }

    func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(StudioTheme.Typography.mono(10))
            .foregroundStyle(.white.opacity(0.48))
    }

    func metricRow(_ title: String, value: String) -> some View {
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

    func sliderRow<SliderView: View>(title: String, value: String, slider: SliderView) -> some View {
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

    func segmentedModeRow<Content: View>(
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

    func dynamicControlMenuRow(
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

    func colorSwatch(color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.5))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0.16), lineWidth: isSelected ? 2.5 : 1)
                        .padding(isSelected ? -4 : -2)
                )
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
    }

    func presetChip(preset: BrushPreset, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    func verticalBrushSlider(
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

    func cardContainer<Content: View>(
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

    var brushLibrarySidebar: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                if showsTitle {
                    Text(language.localized("Brush Library"))
                        .font(StudioTheme.Typography.title(18))
                        .foregroundStyle(.white.opacity(0.94))
                }

                HStack(spacing: 8) {
                    sidebarIconButton(
                        title: language.localized("Settings"),
                        systemImage: "slider.horizontal.3",
                        isActive: showsBrushSettingsPopover
                    ) {
                        showsBrushSettingsPopover.toggle()
                    }

                    sidebarIconButton(
                        title: language.localized("Save"),
                        systemImage: "square.and.arrow.down.on.square"
                    ) {
                        store.send(.saveCurrentBrushButtonTapped)
                    }

                    sidebarIconButton(
                        title: language.localized("Manage"),
                        systemImage: "trash",
                        isActive: showsSavedBrushDeleteMode
                    ) {
                        showsSavedBrushDeleteMode.toggle()
                    }

                    sidebarIconButton(
                        title: language.localized("Import"),
                        systemImage: "square.and.arrow.down"
                    ) {
                        isImportingBrush = true
                    }
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        brushLibrarySection(
                            title: language.localized("Saved"),
                            presets: store.savedPresets,
                            emptyMessage: language.localized("Saved brushes appear here."),
                            allowsDeletion: true
                        )

                        brushLibrarySection(
                            title: language.localized("Presets"),
                            presets: store.presets,
                            emptyMessage: language.localized("No presets yet."),
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
                    title: language.localized("Size"),
                    valueText: "\(Int(store.brushRadius.rounded()))",
                    normalizedValue: Binding(
                        get: { min(max((store.brushRadius - 1.0) / 99.0, 0.0), 1.0) },
                        set: { store.brushRadius = 1.0 + ($0 * 99.0) }
                    )
                )

                verticalBrushSlider(
                    title: language.localized("Opacity"),
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

    var floatingBrushSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.localized("Brush Settings"))
                        .font(StudioTheme.Typography.title(15))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(store.selectedBrush?.name ?? (language.localized("Custom Brush")))
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

    func brushLibrarySection(
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

    func deletableSavedPresetChip(preset: BrushPreset) -> some View {
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

    func sidebarIconButton(
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

    func withSecurityScopedAccess<T>(to url: URL, _ work: () -> T) -> T {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return work()
    }

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
