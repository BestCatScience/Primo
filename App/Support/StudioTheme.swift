import SwiftUI

enum StudioTheme {
    enum Palette {
        static let backgroundTop = Color(red: 0.18, green: 0.18, blue: 0.18)
        static let backgroundBottom = Color(red: 0.13, green: 0.13, blue: 0.13)
        static let stageTop = Color(red: 0.15, green: 0.15, blue: 0.15)
        static let stageBottom = Color(red: 0.13, green: 0.13, blue: 0.13)
        static let panelTop = Color(red: 0.20, green: 0.20, blue: 0.20)
        static let panelBottom = Color(red: 0.17, green: 0.17, blue: 0.17)
        static let surfaceTop = Color(red: 0.24, green: 0.24, blue: 0.24)
        static let surfaceBottom = Color(red: 0.20, green: 0.20, blue: 0.20)

        static let accent = Color(red: 0.16, green: 0.48, blue: 0.86)
        static let accentBright = Color(red: 0.30, green: 0.62, blue: 0.97)
        static let accentSoft = Color(red: 0.22, green: 0.55, blue: 0.90)
        static let accentGlow = Color(red: 0.12, green: 0.25, blue: 0.44)
        static let coolGlow = Color(red: 0.11, green: 0.16, blue: 0.22)

        static let textPrimary = Color.white.opacity(0.95)
        static let textSecondary = Color.white.opacity(0.72)
        static let textMuted = Color.white.opacity(0.42)
        static let hairline = Color.white.opacity(0.08)
        static let cardFill = Color.white.opacity(0.04)
        static let cardFillStrong = Color.white.opacity(0.07)
        static let cardBorder = Color.white.opacity(0.09)
        static let toolbarFill = Color.white.opacity(0.045)
        static let toolbarHighlight = Color.white.opacity(0.02)
        static let selectedFill = accent.opacity(0.18)
        static let selectedBorder = accentBright.opacity(0.72)
        static let overlayBlack = Color.black.opacity(0.62)
    }

    enum Typography {
        static func brand(_ size: CGFloat) -> Font {
            .custom("Didot-Bold", size: size)
        }

        static func display(_ size: CGFloat) -> Font {
            .custom("Didot", size: size)
        }

        static func title(_ size: CGFloat) -> Font {
            .custom("AvenirNextCondensed-DemiBold", size: size)
        }

        static func label(_ size: CGFloat) -> Font {
            .custom("AvenirNextCondensed-Bold", size: size)
        }

        static func body(_ size: CGFloat) -> Font {
            .custom("AvenirNext-Medium", size: size)
        }

        static func mono(_ size: CGFloat) -> Font {
            .custom("Menlo-Bold", size: size)
        }
    }

    enum Gradients {
        static let appBackground = LinearGradient(
            colors: [Palette.backgroundTop, Palette.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let topBar = LinearGradient(
            colors: [
                Color(red: 0.21, green: 0.21, blue: 0.21),
                Color(red: 0.18, green: 0.18, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let stage = LinearGradient(
            colors: [Palette.stageTop, Palette.stageBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let panel = LinearGradient(
            colors: [Palette.panelTop, Palette.panelBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let surface = LinearGradient(
            colors: [Palette.surfaceTop, Palette.surfaceBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accent = LinearGradient(
            colors: [Palette.accentBright, Palette.accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accentBar = LinearGradient(
            colors: [Palette.accentBright, Palette.accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
