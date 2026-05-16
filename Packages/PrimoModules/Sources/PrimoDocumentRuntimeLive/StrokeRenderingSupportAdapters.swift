import CoreGraphics
import PrimoBrushRuntimeContracts
import PrimoDocumentMetalStrokeInfrastructure
import PrimoDocumentPresentationContracts
import PrimoDocumentStrokeInfrastructure

package enum BrushStrokeKernel {
    package static func taperScale(progress: CGFloat, taperIn: CGFloat, taperOut: CGFloat) -> CGFloat {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.taperScale(
            progress: progress,
            taperIn: taperIn,
            taperOut: taperOut
        )
    }

    package static func taperScale(progress: Double, taperIn: Double, taperOut: Double) -> Double {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.taperScale(
            progress: progress,
            taperIn: taperIn,
            taperOut: taperOut
        )
    }

    package static func resolvedRadius(
        for sample: StylusSample,
        progress: CGFloat,
        brush: BrushRuntimeSettings
    ) -> CGFloat {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.resolvedRadius(
            for: sample,
            progress: progress,
            brush: brush
        )
    }

    package static func previewStampAlpha(
        pressure: Double,
        opacityJitter: Double,
        opacity: Double,
        flow: Double,
        hardness: Double,
        opacityPressureSensitivity: Double,
        flowPressureSensitivity: Double,
        hasCustomTip: Bool
    ) -> Double {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.previewStampAlpha(
            pressure: pressure,
            opacityJitter: opacityJitter,
            opacity: opacity,
            flow: flow,
            hardness: hardness,
            opacityPressureSensitivity: opacityPressureSensitivity,
            flowPressureSensitivity: flowPressureSensitivity,
            hasCustomTip: hasCustomTip
        )
    }

    package static func noise(x: CGFloat, y: CGFloat) -> CGFloat {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.noise(x: x, y: y)
    }
}

package enum GpuRenderingSupport {
    package static func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
        PrimoDocumentMetalStrokeInfrastructure.GpuRenderingSupport.shouldUseIncrementalPreviewUpdate(for: brush)
    }

    package static func shouldUseGpuOnlyResponsivePreview(for brush: BrushRuntimeSettings) -> Bool {
        PrimoDocumentMetalStrokeInfrastructure.GpuRenderingSupport.shouldUseGpuOnlyResponsivePreview(for: brush)
    }

    package static func responsivePreviewBrush(from brush: BrushRuntimeSettings) -> BrushRuntimeSettings {
        PrimoDocumentMetalStrokeInfrastructure.GpuRenderingSupport.responsivePreviewBrush(from: brush)
    }
}
