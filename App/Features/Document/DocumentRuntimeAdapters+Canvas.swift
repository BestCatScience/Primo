import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime

struct DocumentCanvasTransformAdapter: CanvasTransformPort {
    private let runtime: LayerEditingRuntime

    init(runtime: LayerEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentCanvasEditingPresentationAdapter: CanvasEditingPresentationPort {
    private let runtime: DocumentPresentationRuntime

    init(runtime: DocumentPresentationRuntime) {
        self.runtime = runtime
    }
}

extension DocumentCanvasMutationCapability {
    var canvasCommandService: CanvasMutationRuntime {
        canvasMutationRuntime
    }

    var historyCommandService: CanvasMutationRuntime {
        canvasMutationRuntime
    }

    var persistenceGateway: DocumentPersistenceGateway {
        persistenceRuntime.gateway
    }

    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: presentationRuntime.lightweightPresentation,
            presentation: presentationRuntime.presentation
        )
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }
}

extension DocumentCanvasEditingPresentationAdapter {
    var renderingWorkflow: DocumentRenderingWorkflow {
        runtime.renderingWorkflow
    }

    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: runtime.lightweightPresentation,
            presentation: runtime.presentation
        )
    }
}

extension DocumentCanvasTransformAdapter {
    func execute(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome {
        runtime.execute(command, state: context)
    }

    func transformedLayerPixels(
        source: RgbaSurface,
        selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets
    ) -> Data? {
        runtime.transformedLayerPixels(
            source: source,
            selection: selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets
        )
    }

    func transformedSelection(
        _ selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets,
        canvasSize: CGSize
    ) -> CanvasSelection? {
        runtime.transformedSelection(
            selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets,
            canvasSize: canvasSize
        )
    }

    func transformationBounds(
        selection: CanvasSelection?,
        surface: RgbaSurface
    ) -> CGRect? {
        runtime.transformationBounds(
            selection: selection,
            surface: surface
        )
    }
}
