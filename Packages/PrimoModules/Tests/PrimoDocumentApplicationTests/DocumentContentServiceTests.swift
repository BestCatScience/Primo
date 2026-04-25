import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import Testing

struct DocumentContentServiceTests {
    @Test
    func applyPixelsRollsBackCreatedLayerAfterFailure() {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 7),
            documentMutationGateway: DocumentMutationGateway(
                resizeCanvas: { _, _ in .success(()) },
                resizeCanvasExtent: { _, _ in .success(()) },
                addLayer: { name in
                    recorder.record("addLayer:\(name)")
                    return .success(3)
                },
                deleteLayer: { index in
                    recorder.record("deleteLayer:\(index)")
                    return .success(())
                },
                setActiveLayer: { index in
                    recorder.record("setActiveLayer:\(index)")
                    return .success(())
                },
                setLayerName: { _, _ in .success(()) },
                setLayerVisibility: { _, _ in .success(()) },
                revealLayerForEditing: { _ in .success(()) },
                replaceLayerPixels: { index, _ in
                    recorder.record("replaceLayerPixels:\(index)")
                    return .failure(.emptyInput)
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
            ),
            textLayerGateway: textLayerGateway()
        )

        let result = service.applyPixels(
            Data(),
            to: .newLayer(name: "Generated")
        )

        #expect(result == .failure(.emptyInput))
        #expect(
            recorder.values == [
                "addLayer:Generated",
                "replaceLayerPixels:3",
                "deleteLayer:3",
                "setActiveLayer:7",
            ]
        )
    }

    @Test
    func applyTextLayerActivatesTargetLayerAfterSuccess() throws {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 1),
            documentMutationGateway: DocumentMutationGateway(
                resizeCanvas: { _, _ in .success(()) },
                resizeCanvasExtent: { _, _ in .success(()) },
                addLayer: { _ in .success(5) },
                deleteLayer: { _ in .success(()) },
                setActiveLayer: { index in
                    recorder.record("setActiveLayer:\(index)")
                    return .success(())
                },
                setLayerName: { _, _ in .success(()) },
                setLayerVisibility: { _, _ in .success(()) },
                revealLayerForEditing: { _ in .success(()) },
                replaceLayerPixels: { _, _ in .success(()) },
                replaceLayerPixelsInRect: { _, _, _ in .success(()) },
                applyLayerSurfaceMutation: { _, _ in .success(()) },
                applyLayerMutation: { _, _ in .success(()) },
                applyTextLayerMutation: { _, _, _ in .success(()) },
                replaceLayerMask: { _, _ in .success(()) },
                clearLayerMask: { _ in .success(()) },
                applyLayerMask: { _ in .success(()) },
                clearLayer: { _ in .success(()) },
                applyLayerProcessing: { _, _ in .success(()) }
            ),
            textLayerGateway: TextLayerGateway(
                textLayerData: { _ in nil },
                setTextLayer: { index, textLayer in
                    recorder.record("setTextLayer:\(index):\(textLayer.text)")
                    return .success(())
                },
                clearTextLayerData: { _ in }
            )
        )

        let result = service.applyTextLayer(
            TextLayerData(
                text: "Hello",
                positionX: 10,
                positionY: 20,
                fontPostScriptName: "Helvetica",
                fontDisplayName: "Helvetica",
                fontSize: 24,
                red: 1,
                green: 1,
                blue: 1,
                alpha: 1
            ),
            to: .newLayer(name: "Caption")
        )

        let mutation = try result.get()
        #expect(mutation == AppliedLayerContentMutation(targetLayerIndex: 5))
        #expect(
            recorder.values == [
                "setTextLayer:5:Hello",
                "setActiveLayer:5",
            ]
        )
    }
}

private final class CallRecorder: @unchecked Sendable {
    private(set) var values: [String] = []

    func record(_ value: String) {
        values.append(value)
    }
}

private func queryGateway(activeLayerIndex: Int) -> DocumentQueryGateway {
    let presentation = PaintDocumentPresentation(
        canvasSize: CGSize(width: 64, height: 64),
        activeLayerIndex: activeLayerIndex,
        layerRows: [],
        layerSidebarRows: [],
        renderSnapshot: nil
    )
    return DocumentQueryGateway(
        lightweightPresentation: { presentation },
        presentation: { presentation },
        compositePixelData: { Data() },
        compositeSurface: { DocumentCompositeSurface(width: 0, height: 0, pixelData: Data()) },
        pixelDataForLayer: { _ in Data() },
        consumeDirtyUpdate: { nil }
    )
}

private func textLayerGateway() -> TextLayerGateway {
    TextLayerGateway(
        textLayerData: { _ in nil },
        setTextLayer: { _, _ in .success(()) },
        clearTextLayerData: { _ in }
    )
}
