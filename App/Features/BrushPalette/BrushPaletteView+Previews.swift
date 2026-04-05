import ComposableArchitecture
import SwiftUI

#Preview("Brush") {
    BrushPaletteView(
        store: Store(initialState: BrushPaletteFeature.State()) {
            BrushPaletteFeature()
        },
        currentTool: .brush,
        hasSelection: false,
        transformPreviewOffset: .zero,
        language: .japanese
    )
    .padding()
    .background(StudioTheme.Gradients.appBackground)
}

#Preview("Eyedropper") {
    BrushPaletteView(
        store: Store(
            initialState: {
                var state = BrushPaletteFeature.State()
                state.eyedropperSamplingSource = .canvas
                return state
            }()
        ) {
            BrushPaletteFeature()
        },
        currentTool: .eyedropper,
        hasSelection: false,
        transformPreviewOffset: .zero,
        language: .english
    )
    .padding()
    .background(StudioTheme.Gradients.appBackground)
}
