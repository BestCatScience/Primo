import CoreGraphics
import Foundation
import PrimoBrushDomain
import PrimoDocumentApplication
import PrimoDocumentContracts
import Testing

struct DocumentCommandServiceTests {
    @Test
    func compositeSurfaceReturnsQueryGatewayPayload() {
        let expected = Data([0x10, 0x20, 0x30])
        let expectedSurface = DocumentCompositeSurface(unsafeUncheckedWidth: 1, height: 3, pixelData: expected)
        let service = DocumentCanvasCommandService(
            queryGateway: DocumentQueryGateway(
                lightweightPresentation: { queryGateway().lightweightPresentation() },
                presentation: { queryGateway().presentation() }
            ),
            renderGateway: DocumentRenderGateway(
                compositePixelData: { expected },
                compositeSurface: { expectedSurface },
                pixelDataForLayer: { _ in Data() }
            ),
            mutationGateway: mutationGateway(recorder: CallRecorder()),
            persistenceGateway: persistenceGateway(recorder: CallRecorder())
        )

        #expect(service.compositeSurface() == expectedSurface)
    }

    @Test
    func compositeSurfaceReplacesLegacyPixelDataReadback() {
        let expected = Data([0x10, 0x20, 0x30])
        let expectedSurface = DocumentCompositeSurface(unsafeUncheckedWidth: 1, height: 3, pixelData: expected)
        let service = DocumentCanvasCommandService(
            queryGateway: DocumentQueryGateway(
                lightweightPresentation: { queryGateway().lightweightPresentation() },
                presentation: { queryGateway().presentation() }
            ),
            renderGateway: DocumentRenderGateway(
                compositePixelData: { Data() },
                compositeSurface: { expectedSurface },
                pixelDataForLayer: { _ in Data() }
            ),
            mutationGateway: mutationGateway(recorder: CallRecorder()),
            persistenceGateway: persistenceGateway(recorder: CallRecorder())
        )

        #expect(service.compositeSurface().pixelData == expected)
    }

    @Test
    func initializeImportedCanvasCreatesCanvasAndActivatesImportedLayer() {
        let recorder = CallRecorder()
        let service = DocumentCanvasCommandService(
            queryGateway: queryGateway(),
            renderGateway: renderGateway(),
            mutationGateway: mutationGateway(recorder: recorder),
            persistenceGateway: persistenceGateway(recorder: recorder)
        )

        let result = service.initializeImportedCanvas(
            ImportedCanvasRequest(
                width: 48,
                height: 32,
                pixelData: Data([0xAA, 0xBB])
            ),
            "Imported"
        )

        if case .failure = result {
            Issue.record("Expected imported canvas initialization to succeed")
        }
        #expect(
            recorder.values == [
                "newCanvas:48x32",
                "prewarmDrawingResources",
                "replaceLayerPixels:0:2",
                "setLayerName:0:Imported",
                "setActiveLayer:0",
            ]
        )
    }

    @Test
    func undoAndRedoRouteThroughHistoryGateway() {
        let recorder = CallRecorder()
        let service = DocumentHistoryCommandService(historyGateway: historyGateway(recorder: recorder))

        if case .failure = service.undo() {
            Issue.record("Expected undo to succeed")
        }
        if case .failure = service.redo() {
            Issue.record("Expected redo to succeed")
        }
        #expect(recorder.values == ["undo", "redo"])
    }

    @Test
    func endBlurStrokePropagatesGatewayFailure() {
        let service = DocumentStrokeCommandService(
            strokeGateway: strokeGateway(endBlurStroke: { .failure(.bridgeMutationFailed("endBlurStroke")) })
        )

        if case let .failure(failure) = service.endBlurStroke() {
            #expect(failure == .bridgeMutationFailed("endBlurStroke"))
        } else {
            Issue.record("Expected endBlurStroke failure to propagate")
        }
    }
}

private final class CallRecorder: @unchecked Sendable {
    private(set) var values: [String] = []

    func record(_ value: String) {
        values.append(value)
    }
}

private func queryGateway() -> DocumentQueryGateway {
    let presentation = PaintDocumentPresentation(
        canvasSize: CGSize(width: 64, height: 64),
        activeLayerIndex: 0,
        layerRows: [],
        layerSidebarRows: [],
        renderSnapshot: nil
    )
    return DocumentQueryGateway(
        lightweightPresentation: { presentation },
        presentation: { presentation }
    )
}

private func renderGateway() -> DocumentRenderGateway {
    DocumentRenderGateway(
        compositePixelData: { Data() },
        compositeSurface: { DocumentCompositeSurface(unsafeUncheckedWidth: 0, height: 0, pixelData: Data()) },
        pixelDataForLayer: { _ in Data() }
    )
}

private func mutationGateway(recorder: CallRecorder) -> DocumentMutationGateway {
    DocumentMutationGateway(
        resizeCanvas: { _, _ in .success(()) },
        resizeCanvasExtent: { _, _ in .success(()) },
        addLayer: { _ in .success(0) },
        deleteLayer: { _ in .success(()) },
        setActiveLayer: { index in
            recorder.record("setActiveLayer:\(index)")
            return .success(())
        },
        setLayerName: { index, name in
            recorder.record("setLayerName:\(index):\(name)")
            return .success(())
        },
        setLayerVisibility: { _, _ in .success(()) },
        revealLayerForEditing: { _ in .success(()) },
        replaceLayerPixels: { index, pixelData in
            recorder.record("replaceLayerPixels:\(index):\(pixelData.count)")
            return .success(())
        },
        replaceLayerPixelsInRect: { _, _, _ in .success(()) },
                applyLayerSurfaceMutation: { _, _ in .success(()) },
        applyLayerMutation: { _, _ in .success(()) },
        applyTextLayerMutation: { _, _, _ in .success(()) },
        replaceLayerMask: { _, _ in .success(()) },
        clearLayerMask: { _ in .success(()) },
        applyLayerMask: { _ in .success(()) },
        clearLayer: { _ in .success(()) },
        applyLayerProcessing: { _, _ in .success(()) }
    )
}

private func strokeGateway(
    endBlurStroke: @escaping @Sendable () -> DocumentMutationResult = { .success(()) },
    cancelBlurStroke: @escaping @Sendable () -> Void = {}
) -> StrokeInputGateway {
    StrokeInputGateway(
        beginStroke: { _, _ in },
        appendStroke: { _ in },
        endStroke: { .success(()) },
        cancelStroke: {},
        blurStroke: { _, _, _, _ in .success(()) },
        endBlurStroke: endBlurStroke,
        cancelBlurStroke: cancelBlurStroke,
        fill: { _, _ in .success(()) },
        applyGpuStrokeSurface: { _, _, _ in .success(()) }
    )
}

private func historyGateway(recorder: CallRecorder) -> DocumentHistoryGateway {
    DocumentHistoryGateway(
        canUndo: { true },
        canRedo: { true },
        undo: {
            recorder.record("undo")
            return .success(())
        },
        redo: {
            recorder.record("redo")
            return .success(())
        }
    )
}

private func persistenceGateway(recorder: CallRecorder) -> DocumentPersistenceGateway {
    DocumentPersistenceGateway(
        saveProject: { _, _ in },
        loadProject: { _ in
            LoadedPaintProject(
                presentation: queryGateway().presentation(),
                paperStyle: .default
            )
        },
        setPaperStyle: { _ in },
        newCanvas: { width, height in
            recorder.record("newCanvas:\(width)x\(height)")
        },
        prewarmDrawingResources: {
            recorder.record("prewarmDrawingResources")
        }
    )
}
