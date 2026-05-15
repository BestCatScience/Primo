import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCoreTypes
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime
import PrimoDocumentRuntimeLive
import PrimoSystemClients

public enum DocumentAppRuntimeSupport {
    public static func liveWorkflows(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentApplicationWorkflowRuntime {
        DocumentApplicationRuntimeFactory.liveWorkflows(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
    }
}

public enum DocumentAppProjectPreviewSupport {
    public static func loadPreview(
        from url: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) throws -> DocumentProjectPreview {
        try DocumentProjectPreviewLoader.loadPreview(
            from: url,
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
    }
}

public enum DocumentAppTimelapseExportSupport {
    public static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        progress: (@Sendable (TimelapseExportProgress) -> Void)? = nil
    ) throws -> TimelapseExportResult {
        try TimelapseExportService.exportVideo(
            from: capture,
            to: directory,
            fileClient: fileClient,
            dateClient: dateClient,
            progress: progress
        )
    }
}

public enum DocumentAppStrokeMath {
    public static func taperScale(progress: CGFloat, taperIn: CGFloat, taperOut: CGFloat) -> CGFloat {
        BrushStrokeKernel.taperScale(
            progress: progress,
            taperIn: taperIn,
            taperOut: taperOut
        )
    }

    public static func taperScale(progress: Double, taperIn: Double, taperOut: Double) -> Double {
        BrushStrokeKernel.taperScale(
            progress: progress,
            taperIn: taperIn,
            taperOut: taperOut
        )
    }

    public static func resolvedRadius(
        for sample: StylusSample,
        progress: CGFloat,
        brush: BrushRuntimeSettings
    ) -> CGFloat {
        BrushStrokeKernel.resolvedRadius(
            for: sample,
            progress: progress,
            brush: brush
        )
    }

    public static func previewStampAlpha(
        pressure: Double,
        opacityJitter: Double,
        opacity: Double,
        flow: Double,
        hardness: Double,
        opacityPressureSensitivity: Double,
        flowPressureSensitivity: Double,
        hasCustomTip: Bool
    ) -> Double {
        BrushStrokeKernel.previewStampAlpha(
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

    public static func noise(x: CGFloat, y: CGFloat) -> CGFloat {
        BrushStrokeKernel.noise(x: x, y: y)
    }
}
