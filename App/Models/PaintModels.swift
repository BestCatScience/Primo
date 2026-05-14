import Foundation
import SwiftUI
import CoreGraphics
import PrimoBrushFileFormats
import PrimoBrushDomain
import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoLocalization
import UIKit
import simd

extension StudioToolKind {
    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .brush:
            return language.localized("ブラシ")
        case .erase:
            return language.localized("消しゴム")
        case .blur:
            return language.localized("ぼかし")
        case .fill:
            return language.localized("塗りつぶし")
        case .eyedropper:
            return language.localized("スポイト設定")
        case .move:
            return language.localized("移動")
        case .select:
            return language.localized("選択")
        case .shape:
            return language.localized("形状")
        case .text:
            return language.localized("テキスト")
        }
    }

    var systemImage: String {
        switch self {
        case .brush:
            return "paintbrush.pointed"
        case .erase:
            return "eraser"
        case .blur:
            return "drop"
        case .fill:
            return "paintbrush.fill"
        case .eyedropper:
            return "eyedropper"
        case .move:
            return "arrow.up.and.down.and.arrow.left.and.right"
        case .select:
            return "lasso"
        case .shape:
            return "square.on.circle"
        case .text:
            return "textformat"
        }
    }
}

extension TextLayerData {
    var displayColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum BrushColorSlot: String, CaseIterable, Equatable, Sendable, Identifiable {
    case primary
    case secondary
    case transparent

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .primary:
            return language.localized("主色")
        case .secondary:
            return language.localized("補助色")
        case .transparent:
            return language.localized("透明色")
        }
    }
}

extension EyedropperSamplingSource {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .activeLayer:
            return language.localized("アクティブレイヤー")
        case .canvas:
            return language.localized("キャンバス")
        }
    }
}

extension FillThresholdMode {
    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .opacity:
            return language.localized("不透明")
        case .color:
            return language.localized("色")
        }
    }
}

extension ShapeToolMode {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .line:
            return language.localized("直線")
        case .rectangle:
            return language.localized("四角")
        case .ellipse:
            return language.localized("丸")
        case .triangle:
            return language.localized("三角形")
        case .pentagon:
            return language.localized("五角形")
        case .hexagon:
            return language.localized("六角形")
        }
    }

    var systemImage: String {
        switch self {
        case .line:
            return "line.diagonal"
        case .rectangle:
            return "square"
        case .ellipse:
            return "circle"
        case .triangle:
            return "triangle"
        case .pentagon:
            return "pentagon"
        case .hexagon:
            return "hexagon"
        }
    }
}

extension LayerBlendMode {
    var title: String {
        localizedTitle(.japanese)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .normal:
            return language.localized("通常")
        case .darken:
            return language.localized("比較(暗)")
        case .multiply:
            return language.localized("乗算")
        case .colorBurn:
            return language.localized("焼き込みカラー")
        case .linearBurn:
            return language.localized("焼き込み(リニア)")
        case .subtract:
            return language.localized("削る")
        case .lighten:
            return language.localized("比較(明)")
        case .screen:
            return language.localized("スクリーン")
        case .colorDodge:
            return language.localized("覆い焼きカラー")
        case .glowDodge:
            return language.localized("覆い焼き(発光)")
        case .overlay:
            return language.localized("オーバーレイ")
        case .softLight:
            return language.localized("ソフトライト")
        case .hardLight:
            return language.localized("ハードライト")
        case .difference:
            return language.localized("差の絶対値")
        case .vividLight:
            return language.localized("ビビッドライト")
        case .linearLight:
            return language.localized("リニアライト")
        case .pinLight:
            return language.localized("ピンライト")
        case .hardMix:
            return language.localized("ハードミックス")
        case .exclusion:
            return language.localized("除外")
        case .darkerColor:
            return language.localized("カラー比較(暗)")
        case .lighterColor:
            return language.localized("カラー比較(明)")
        case .divide:
            return language.localized("除算")
        case .hue:
            return language.localized("色相")
        case .saturation:
            return language.localized("彩度")
        case .color:
            return language.localized("色")
        case .add:
            return language.localized("加算")
        case .addGlow:
            return language.localized("加算(発光)")
        case .luminosity:
            return language.localized("輝度")
        }
    }
}

extension GradientMapPreset {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .graphite:
            return language.localized("グラファイト")
        case .sepia:
            return language.localized("セピア")
        case .ocean:
            return language.localized("オーシャン")
        case .sunset:
            return language.localized("サンセット")
        case .toxic:
            return language.localized("トキシック")
        }
    }
}

extension BrushTipKind {
    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .pencil:
            return language.localized("鉛筆")
        case .ink:
            return language.localized("インク")
        case .oil:
            return language.localized("油彩")
        case .airbrush:
            return language.localized("エアブラシ")
        }
    }

    var systemImage: String {
        switch self {
        case .pencil:
            return "pencil.tip"
        case .ink:
            return "paintbrush.pointed"
        case .oil:
            return "paintbrush"
        case .airbrush:
            return "aqi.low"
        }
    }
}

extension BrushAngleMode {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .fixed:
            return language.localized("固定")
        case .strokeDirection:
            return language.localized("線方向")
        case .stylusTilt:
            return language.localized("傾き")
        }
    }
}

extension BrushTextureMode {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .off:
            return language.localized("オフ")
        case .strokeLocked:
            return language.localized("ストローク固定")
        case .eachTip:
            return language.localized("先端ごと")
        case .moving:
            return language.localized("移動")
        }
    }
}

extension BrushDualBlendMode {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .multiply:
            return language.localized("乗算")
        case .darker:
            return language.localized("暗い方")
        case .subtract:
            return language.localized("削る")
        }
    }
}

extension BrushScatterMode {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .directional:
            return language.localized("方向散布")
        case .spray:
            return language.localized("スプレー")
        }
    }
}

extension BrushColorMixingMode {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .off:
            return language.localized("オフ")
        case .blend:
            return language.localized("ブレンド")
        case .runningColor:
            return language.localized("ランニングカラー")
        case .smear:
            return language.localized("スメア")
        }
    }

}

extension BrushSmudgeMode {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .smearing:
            return language.localized("Smearing")
        case .dulling:
            return language.localized("Dulling")
        }
    }
}

extension BrushPreset {
    func localizedDisplayName(_ language: AppLanguage) -> String {
        language.localized(name)
    }

    var displayColor: Color {
        Color(
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0
        )
    }
}

enum BrushTipShapePreset: String, CaseIterable, Equatable, Sendable, Identifiable {
    case round
    case block
    case diamond
    case ribbon
    case petal
    case rake
    case star
    case custom

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .round:
            return language.localized("ラウンド")
        case .block:
            return language.localized("スクエア")
        case .diamond:
            return language.localized("ダイヤ")
        case .ribbon:
            return language.localized("リボン")
        case .petal:
            return language.localized("花びら")
        case .rake:
            return language.localized("レーキ")
        case .star:
            return language.localized("スター")
        case .custom:
            return language.localized("カスタム")
        }
    }

    func raster(currentCustomTip: BrushTipRaster?) -> BrushTipRaster? {
        switch self {
        case .round:
            return nil
        case .block:
            return BuiltInBrushTipFactory.block
        case .diamond:
            return BuiltInBrushTipFactory.diamond
        case .ribbon:
            return BuiltInBrushTipFactory.ribbon
        case .petal:
            return BuiltInBrushTipFactory.petal
        case .rake:
            return BuiltInBrushTipFactory.rake
        case .star:
            return BuiltInBrushTipFactory.star
        case .custom:
            return currentCustomTip
        }
    }

    static func matching(customTip: BrushTipRaster?) -> BrushTipShapePreset {
        guard let customTip else { return .round }
        for preset in BrushTipShapePreset.allCases where preset != .round && preset != .custom {
            if preset.raster(currentCustomTip: nil) == customTip {
                return preset
            }
        }
        return .custom
    }
}

private enum BuiltInBrushTipFactory {
    static let block = roundedSquare(size: 96, inset: 12, cornerRadius: 16)
    static let diamond = diamond(size: 96, inset: 12)
    static let ribbon = ribbon(size: 96, inset: 14, angle: .pi / 6)
    static let petal = petal(size: 96, inset: 8)
    static let rake = rake(size: 96, inset: 10, toothCount: 4)
    static let star = star(size: 96, points: 5, innerRadiusRatio: 0.44, outerInset: 10)

    private static func roundedSquare(size: Int, inset: CGFloat, cornerRadius: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let square = rect.insetBy(dx: inset, dy: inset)
            let path = CGPath(
                roundedRect: square,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
            context.addPath(path)
            context.fillPath()
        }
    }

    private static func diamond(size: Int, inset: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let box = rect.insetBy(dx: inset, dy: inset)
            let center = CGPoint(x: box.midX, y: box.midY)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: center.x, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: box.maxY))
            path.addLine(to: CGPoint(x: box.minX, y: center.y))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
    }

    private static func ribbon(size: Int, inset: CGFloat, angle: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let box = rect.insetBy(dx: inset, dy: inset * 1.6)
            context.saveGState()
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: angle)
            let ribbonRect = CGRect(
                x: -box.width * 0.5,
                y: -box.height * 0.22,
                width: box.width,
                height: box.height * 0.44
            )
            let path = CGPath(
                roundedRect: ribbonRect,
                cornerWidth: ribbonRect.height * 0.45,
                cornerHeight: ribbonRect.height * 0.45,
                transform: nil
            )
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
        }
    }

    private static func petal(size: Int, inset: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let petalWidth = rect.width * 0.24
            let petalHeight = rect.height * 0.50
            let distance = rect.width * 0.12

            for index in 0..<4 {
                context.saveGState()
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: CGFloat(index) * (.pi / 2))
                let petalRect = CGRect(
                    x: -petalWidth * 0.5,
                    y: -(petalHeight - distance),
                    width: petalWidth,
                    height: petalHeight
                ).insetBy(dx: inset * 0.05, dy: inset * 0.02)
                context.fillEllipse(in: petalRect)
                context.restoreGState()
            }

            context.fillEllipse(
                in: CGRect(
                    x: center.x - rect.width * 0.10,
                    y: center.y - rect.height * 0.10,
                    width: rect.width * 0.20,
                    height: rect.height * 0.20
                )
            )
        }
    }

    private static func rake(size: Int, inset: CGFloat, toothCount: Int) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let box = rect.insetBy(dx: inset, dy: inset)
            let gap = box.width * 0.06
            let toothWidth = (box.width - gap * CGFloat(toothCount - 1)) / CGFloat(toothCount)
            let topOffsets: [CGFloat] = [0.12, 0.0, 0.08, 0.18]

            for index in 0..<toothCount {
                let topOffset = box.height * topOffsets[min(index, topOffsets.count - 1)]
                let toothRect = CGRect(
                    x: box.minX + CGFloat(index) * (toothWidth + gap),
                    y: box.minY + topOffset,
                    width: toothWidth,
                    height: box.height - topOffset
                )
                let path = CGPath(
                    roundedRect: toothRect,
                    cornerWidth: toothWidth * 0.34,
                    cornerHeight: toothWidth * 0.34,
                    transform: nil
                )
                context.addPath(path)
                context.fillPath()
            }
        }
    }

    private static func star(size: Int, points: Int, innerRadiusRatio: CGFloat, outerInset: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = (min(rect.width, rect.height) * 0.5) - outerInset
            let innerRadius = outerRadius * innerRadiusRatio
            let path = CGMutablePath()

            for index in 0..<(points * 2) {
                let angle = (CGFloat(index) * .pi / CGFloat(points)) - (.pi / 2)
                let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
    }

    private static func raster(size: Int, draw: (CGContext, CGRect) -> Void) -> BrushTipRaster {
        var pixels = [UInt8](repeating: 0, count: size * size)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return
            }

            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.setFillColor(gray: 1.0, alpha: 1.0)
            draw(context, CGRect(x: 0, y: 0, width: size, height: size))
        }

        return BrushTipRaster(width: size, height: size, alphaData: Data(pixels))
    }
}

struct LayerCanvasBuffer: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    var name: String
    var visible: Bool
    var opacity: Double
    var blendMode: LayerBlendMode = .normal
    var strokes: [PreviewStrokeTrack] = []
}
