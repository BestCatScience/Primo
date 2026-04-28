import SwiftUI
import UIKit

struct SpectrumColorControl: View {
    @Binding var color: Color
    @State private var activeRegion: ActiveRegion?
    @State private var lastChromaticHue: Double?
    @State private var lastDisplaySaturation: Double?

    private let ringWidth: CGFloat = 24
    private let gap: CGFloat = 12
    private let chromaticThreshold = 0.001
    private let brightnessThreshold = 0.001

    var body: some View {
        GeometryReader { geometry in
            let size = max(min(geometry.size.width, geometry.size.height) - ringWidth - 4, 120)
            let outerRect = CGRect(
                x: (geometry.size.width - size) / 2,
                y: (geometry.size.height - size) / 2,
                width: size,
                height: size
            )
            let squareSide = max(size - ((ringWidth + gap) * 2), 64)
            let squareRect = CGRect(
                x: outerRect.midX - (squareSide / 2),
                y: outerRect.midY - (squareSide / 2),
                width: squareSide,
                height: squareSide
            )
            let hsb = ColorHSB(color: color)
            let displayHue = displayedHue(for: hsb)
            let displaySaturation = displayedSaturation(for: hsb)
            let ringIndicator = ringIndicatorPoint(in: outerRect, hue: displayHue)
            let squareIndicator = CGPoint(
                x: squareRect.minX + (displaySaturation * squareRect.width),
                y: squareRect.minY + ((1 - hsb.brightness) * squareRect.height)
            )

            ZStack {
                Circle()
                    .fill(Color(red: 0.22, green: 0.22, blue: 0.22))
                    .frame(width: outerRect.width - ringWidth - 2, height: outerRect.height - ringWidth - 2)
                    .position(x: outerRect.midX, y: outerRect.midY)

                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple, .pink, .red
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt)
                    )
                    .frame(width: outerRect.width, height: outerRect.height)
                    .position(x: outerRect.midX, y: outerRect.midY)

                Circle()
                    .stroke(Color.black.opacity(0.28), lineWidth: 1)
                    .frame(width: outerRect.width + ringWidth / 2, height: outerRect.height + ringWidth / 2)
                    .position(x: outerRect.midX, y: outerRect.midY)

                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    .frame(width: outerRect.width - ringWidth / 2, height: outerRect.height - ringWidth / 2)
                    .position(x: outerRect.midX, y: outerRect.midY)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hue: displayHue, saturation: 1, brightness: 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.black.opacity(0.58), lineWidth: 2)
                            .frame(width: squareRect.width, height: squareRect.height)
                            .position(x: squareRect.midX, y: squareRect.midY)
                    )

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.98))
                    .frame(width: 12, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(Color.black.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .rotationEffect(.radians(displayHue * .pi * 2))
                    .position(x: ringIndicator.x, y: ringIndicator.y)

                Circle()
                    .fill(Color.white.opacity(0.98))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.64), lineWidth: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 1)
                            .padding(3)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
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
                            updateSquare(at: value.location, within: squareRect, hue: displayHue)
                        case .ring:
                            updateRing(at: value.location, within: outerRect, current: hsb, saturation: displaySaturation)
                        case .none:
                            break
                        }
                    }
                    .onEnded { _ in
                        activeRegion = nil
                    }
            )
        }
        .frame(height: 220)
        .onAppear {
            rememberHueIfChromatic(ColorHSB(color: color))
        }
        .onChange(of: color) { _, newColor in
            rememberHueIfChromatic(ColorHSB(color: newColor))
        }
    }

    private func displayedHue(for hsb: ColorHSB) -> Double {
        hsb.saturation > chromaticThreshold ? hsb.hue : (lastChromaticHue ?? hsb.hue)
    }

    private func displayedSaturation(for hsb: ColorHSB) -> Double {
        hsb.brightness <= brightnessThreshold ? (lastDisplaySaturation ?? hsb.saturation) : hsb.saturation
    }

    private func rememberHueIfChromatic(_ hsb: ColorHSB) {
        if hsb.saturation > chromaticThreshold {
            lastChromaticHue = hsb.hue
        }
        if hsb.brightness > brightnessThreshold {
            lastDisplaySaturation = hsb.saturation
        }
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

    private func updateRing(at point: CGPoint, within rect: CGRect, current: ColorHSB, saturation: Double) {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        let angle = atan2(dy, dx) + (.pi / 2)
        let normalized = (angle < 0 ? angle + (.pi * 2) : angle) / (.pi * 2)
        lastChromaticHue = normalized
        lastDisplaySaturation = saturation
        color = Color(hue: normalized, saturation: saturation, brightness: current.brightness)
    }

    private func updateSquare(at point: CGPoint, within rect: CGRect, hue: Double) {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let saturation = (clampedX - rect.minX) / rect.width
        let brightness = 1 - ((clampedY - rect.minY) / rect.height)
        lastDisplaySaturation = saturation
        if saturation > chromaticThreshold {
            lastChromaticHue = hue
        }
        color = Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func ringIndicatorPoint(in rect: CGRect, hue: Double) -> CGPoint {
        let angle = (hue * .pi * 2) - (.pi / 2)
        let radius = (rect.width - ringWidth) / 2
        return CGPoint(
            x: rect.midX + (CGFloat(cos(angle)) * radius),
            y: rect.midY + (CGFloat(sin(angle)) * radius)
        )
    }

    private enum ActiveRegion {
        case ring
        case square
    }
}

struct BrushColorPalettePanel: View {
    @Binding var primaryColor: Color
    @Binding var secondaryColor: Color
    @Binding var selectedSlot: BrushColorSlot
    @Binding var paletteSwatches: [PaletteSwatch]
    @State private var lastChromaticHue: Double?
    @State private var selectedTab: ColorPalettePanelTab = .wheel
    @State private var selectedPaletteSwatchID: String?
    let paletteColumns: [GridItem]
    let panelHairlineFill: Color
    let isTransparentSelected: Bool
    let transparentTitle: String
    let swatchAction: (Color) -> Void
    private let chromaticThreshold = 0.001

    private var editableColor: Binding<Color> {
        Binding(
            get: {
                selectedSlot == .secondary ? secondaryColor : primaryColor
            },
            set: { newColor in
                switch selectedSlot {
                case .primary, .transparent:
                    primaryColor = newColor
                case .secondary:
                    secondaryColor = newColor
                }
            }
        )
    }

    private var activeHSB: ColorHSB {
        ColorHSB(color: editableColor.wrappedValue)
    }

    private var displayHue: Double {
        activeHSB.saturation > chromaticThreshold ? activeHSB.hue : (lastChromaticHue ?? activeHSB.hue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            paletteTabStrip

            Group {
                switch selectedTab {
                case .wheel:
                    SpectrumColorControl(color: editableColor)
                        .opacity(isTransparentSelected ? 0.42 : 1.0)
                        .allowsHitTesting(!isTransparentSelected)
                        .overlay {
                            if isTransparentSelected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.black.opacity(0.24))
                                    .overlay {
                                        VStack(spacing: 6) {
                                            Image(systemName: "eraser.fill")
                                                .font(.system(size: 16, weight: .bold))
                                            Text(transparentTitle)
                                                .font(StudioTheme.Typography.mono(10))
                                        }
                                        .foregroundStyle(.white.opacity(0.88))
                                    }
                            }
                        }

                case .palette:
                    VStack(alignment: .leading, spacing: 10) {
                        paletteEditToolbar
                        colorSetGrid
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            colorStatusRow
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(red: 0.28, green: 0.28, blue: 0.28).opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            rememberHueIfChromatic(activeHSB)
        }
        .onChange(of: editableColor.wrappedValue) { _, newColor in
            rememberHueIfChromatic(ColorHSB(color: newColor))
        }
    }

    private var paletteTabStrip: some View {
        HStack(spacing: 4) {
            ForEach(ColorPalettePanelTab.allCases) { tab in
                paletteTabButton(tab)
            }
        }
    }

    private func paletteTabButton(_ tab: ColorPalettePanelTab) -> some View {
        let isSelected = selectedTab == tab
        let foreground = isSelected ? Color.white.opacity(0.92) : Color.white.opacity(0.48)
        let background = isSelected ? Color.white.opacity(0.14) : Color.black.opacity(0.16)
        let border = isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.05)

        return Button {
            selectedTab = tab
        } label: {
            Text(tab.title)
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var colorStatusRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                selectedSlot = .transparent
            } label: {
                CheckerboardSwatch(cornerRadius: 8)
                    .frame(width: 74, height: 17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selectedSlot == .transparent ? Color.white.opacity(0.96) : Color.white.opacity(0.42), lineWidth: selectedSlot == .transparent ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(selectedSlot == .transparent ? 0.24 : 0.08), radius: selectedSlot == .transparent ? 5 : 2, y: 1)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                hsbMetric(label: "H", value: Int((displayHue * 360).rounded()))
                hsbMetric(label: "S", value: Int((activeHSB.saturation * 100).rounded()))
                hsbMetric(label: "V", value: Int((activeHSB.brightness * 100).rounded()))
            }
            .padding(.bottom, 4)
        }
    }

    private var colorSetGrid: some View {
        Group {
            if paletteSwatches.isEmpty {
                Text("色がありません")
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.black.opacity(0.16))
                    )
            } else {
                LazyVGrid(columns: paletteGridColumns, alignment: .leading, spacing: 8) {
                    ForEach(paletteSwatches) { swatch in
                        PalettePresetButton(
                            color: swatch.color,
                            isSelected: selectedPaletteSwatchID == swatch.id
                        ) {
                            selectedPaletteSwatchID = swatch.id
                            swatchAction(swatch.color)
                        }
                        .opacity(isTransparentSelected ? 0.38 : 1.0)
                        .allowsHitTesting(!isTransparentSelected)
                    }
                }
            }
        }
    }

    private var paletteGridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(26), spacing: 7), count: 5)
    }

    private var paletteEditToolbar: some View {
        HStack(spacing: 6) {
            paletteToolButton(systemImage: "plus", isEnabled: !isTransparentSelected) {
                let swatch = PaletteSwatch(color: editableColor.wrappedValue)
                paletteSwatches.append(swatch)
                selectedPaletteSwatchID = swatch.id
            }

            paletteToolButton(systemImage: "pencil", isEnabled: selectedPaletteSwatchID != nil && !isTransparentSelected) {
                guard let selectedPaletteSwatchID,
                      let index = paletteSwatches.firstIndex(where: { $0.id == selectedPaletteSwatchID }) else { return }
                paletteSwatches[index] = PaletteSwatch(id: selectedPaletteSwatchID, color: editableColor.wrappedValue)
            }

            paletteToolButton(systemImage: "trash", isEnabled: selectedPaletteSwatchID != nil) {
                guard let selectedPaletteSwatchID else { return }
                paletteSwatches.removeAll { $0.id == selectedPaletteSwatchID }
                self.selectedPaletteSwatchID = paletteSwatches.first?.id
            }

            Spacer(minLength: 0)
        }
    }

    private func paletteToolButton(
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isEnabled ? Color.white.opacity(0.86) : Color.white.opacity(0.26))
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.black.opacity(isEnabled ? 0.24 : 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(isEnabled ? 0.10 : 0.04), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func rememberHueIfChromatic(_ hsb: ColorHSB) {
        if hsb.saturation > chromaticThreshold {
            lastChromaticHue = hsb.hue
        }
    }

    private func hsbMetric(label: String, value: Int) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(StudioTheme.Typography.mono(9))
                .foregroundStyle(Color.white.opacity(0.72))
                .frame(width: 13, height: 13)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.black.opacity(0.34))
                )
            Text("\(value)")
                .font(StudioTheme.Typography.mono(13))
                .foregroundStyle(Color.white.opacity(0.82))
                .monospacedDigit()
                .frame(minWidth: 18, alignment: .leading)
        }
    }
}

private enum ColorPalettePanelTab: String, CaseIterable, Identifiable {
    case wheel
    case palette

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wheel:
            return "色環"
        case .palette:
            return "パレット"
        }
    }
}

private struct PalettePresetButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 26, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.96 : 0.0), lineWidth: 2)
                        .padding(-4)
                )
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
    }
}

private struct CheckerboardSwatch: View {
    let cornerRadius: CGFloat

    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 8
            let columns = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))

            for row in 0..<rows {
                for column in 0..<columns {
                    let isLight = (row + column).isMultiple(of: 2)
                    let rect = CGRect(
                        x: CGFloat(column) * tile,
                        y: CGFloat(row) * tile,
                        width: tile,
                        height: tile
                    )
                    context.fill(Path(rect), with: .color(isLight ? Color.white.opacity(0.88) : Color.black.opacity(0.26)))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct SquareSliderColorPalette: View {
    @Binding var color: Color
    @State private var activeRegion: ActiveRegion?

    var body: some View {
        GeometryReader { geometry in
            let hsb = ColorHSB(color: color)
            let sliderWidth: CGFloat = 18
            let spacing: CGFloat = 12
            let squareSide = min(geometry.size.height, max(96, geometry.size.width - sliderWidth - spacing))
            let squareRect = CGRect(x: 0, y: 0, width: squareSide, height: squareSide)
            let sliderRect = CGRect(x: squareSide + spacing, y: 0, width: sliderWidth, height: squareSide)
            let squareIndicator = CGPoint(
                x: squareRect.minX + (hsb.saturation * squareRect.width),
                y: squareRect.minY + ((1 - hsb.brightness) * squareRect.height)
            )
            let hueIndicatorY = sliderRect.minY + ((1 - hsb.hue) * sliderRect.height)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hue: hsb.hue, saturation: 1, brightness: 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                    }
                    .frame(width: squareRect.width, height: squareRect.height)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: sliderRect.width, height: sliderRect.height)
                    .offset(x: sliderRect.minX, y: sliderRect.minY)

                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 2))
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                    .position(x: squareIndicator.x, y: squareIndicator.y)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: sliderRect.width + 8, height: 10)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .offset(x: sliderRect.minX - 4, y: hueIndicatorY - 5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeRegion == nil {
                            activeRegion = hitRegion(at: value.location, squareRect: squareRect, sliderRect: sliderRect)
                        }
                        switch activeRegion {
                        case .square:
                            updateSquare(at: value.location, within: squareRect, hue: hsb.hue)
                        case .slider:
                            updateHue(at: value.location, within: sliderRect, current: hsb)
                        case .none:
                            break
                        }
                    }
                    .onEnded { _ in
                        activeRegion = nil
                    }
            )
        }
        .frame(height: 148)
    }

    private func hitRegion(at point: CGPoint, squareRect: CGRect, sliderRect: CGRect) -> ActiveRegion? {
        if squareRect.contains(point) { return .square }
        if sliderRect.insetBy(dx: -8, dy: -8).contains(point) { return .slider }
        return nil
    }

    private func updateSquare(at point: CGPoint, within rect: CGRect, hue: Double) {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let saturation = (clampedX - rect.minX) / rect.width
        let brightness = 1 - ((clampedY - rect.minY) / rect.height)
        color = Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func updateHue(at point: CGPoint, within rect: CGRect, current: ColorHSB) {
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let hue = 1 - ((clampedY - rect.minY) / rect.height)
        color = Color(hue: hue, saturation: current.saturation, brightness: current.brightness)
    }

    private enum ActiveRegion {
        case square
        case slider
    }
}

struct VerticalValueSlider: View {
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

struct ColorHSB {
    let hue: Double
    let saturation: Double
    let brightness: Double

    init(color: Color) {
        let resolved = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        resolved.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        self.hue = Double(hue)
        self.saturation = Double(saturation)
        self.brightness = Double(brightness)
    }
}

struct PaletteSwatch: Identifiable, Equatable {
    let id: String
    let color: Color

    init(id: String = UUID().uuidString, color: Color) {
        self.id = id
        self.color = color
    }

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
