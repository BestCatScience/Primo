import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import Testing

struct DocumentContentServiceTests {
    @Test
    func layerPixelAndMaskPayloadsValidateByteCounts() {
        #expect(LayerPixelData(width: 2, height: 2, rgba: Data(repeating: 0, count: 16)) != nil)
        #expect(LayerPixelData(width: 2, height: 2, rgba: Data(repeating: 0, count: 15)) == nil)
        #expect(LayerPixelData(width: 0, height: 2, rgba: Data()) == nil)

        #expect(LayerMaskData(width: 2, height: 2, bytes: Data(repeating: 0, count: 4)) != nil)
        #expect(LayerMaskData(width: 2, height: 2, bytes: Data(repeating: 0, count: 5)) == nil)
        #expect(LayerMaskData(width: 2, height: -1, bytes: Data()) == nil)
    }

    @Test
    func applyPixelsRejectsInvalidExistingLayerBeforeMutationGateway() {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 0, layerCount: 1),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )

        let result = service.applyPixels(
            Data(repeating: 0xff, count: 16),
            to: .existingLayer(index: 4)
        )

        #expect(result == .failure(.invalidLayerIndex(4)))
        #expect(recorder.values.isEmpty)
    }

    @Test
    func directPixelReplacementRejectsInvalidPayloadBeforeMutationGateway() {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 0, layerCount: 1),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )

        let result = service.replaceLayerPixels(0, Data(repeating: 0xff, count: 16))

        guard case let .failure(.gpu(.invalidPayloadSize(operation, expected, actual))) = result else {
            Issue.record("Expected invalid payload size failure")
            return
        }
        #expect(operation == "replaceLayerPixels")
        #expect(expected == 64 * 64 * 4)
        #expect(actual == 16)
        #expect(recorder.values.isEmpty)
    }

    @Test
    func directPixelReplacementRejectsInvalidLayerBeforeMutationGateway() {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 0, layerCount: 1),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )

        let result = service.replaceLayerPixels(2, Data(repeating: 0xff, count: 16))

        switch result {
        case let .failure(failure):
            #expect(failure == .invalidLayerIndex(2))
        case .success:
            Issue.record("Expected invalid layer index failure")
        }
        #expect(recorder.values.isEmpty)
    }

    @Test
    func directPixelReplacementRejectsLockedLayerBeforeMutationGateway() {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 0, layerCount: 1, lockedLayerIndexes: [0]),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )

        let result = service.replaceLayerPixels(0, Data(repeating: 0xff, count: 16))

        switch result {
        case let .failure(failure):
            #expect(failure == .layerLocked(0))
        case .success:
            Issue.record("Expected locked layer failure")
        }
        #expect(recorder.values.isEmpty)
    }

    @Test
    func applyPixelsRollsBackCreatedLayerAfterFailure() {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 7),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder, contentResult: .failure(.emptyInput)),
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
            )
        )

        let result = service.applyPixels(
            Data(repeating: 0xff, count: 64 * 64 * 4),
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
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
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
            )
        )

        let textLayer = try #require(TextLayerData(
            validatingText: "Hello",
            positionX: 10,
            positionY: 20,
            fontPostScriptName: "Helvetica",
            fontDisplayName: "Helvetica",
            fontSize: 24,
            red: 1,
            green: 1,
            blue: 1,
            alpha: 1
        ))
        let result = service.applyTextLayer(
            textLayer,
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
    queryGateway(activeLayerIndex: activeLayerIndex, layerCount: 0)
}

private func queryGateway(
    activeLayerIndex: Int,
    layerCount: Int,
    lockedLayerIndexes: Set<Int> = []
) -> DocumentQueryGateway {
    var indices = Array(0..<layerCount)
    if !indices.contains(activeLayerIndex) {
        indices.append(activeLayerIndex)
    }
    let rows = indices.map { layerRow(index: $0, isLocked: lockedLayerIndexes.contains($0)) }
    let presentation = PaintDocumentPresentation(
        validatingCanvasSize: CGSize(width: 64, height: 64),
        activeLayerIndex: activeLayerIndex,
        layerRows: rows,
        layerSidebarRows: rows.map { .layer($0, depth: 0) },
        renderSnapshot: nil
    )!
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

private func layerRow(index: Int, isLocked: Bool = false) -> LayerRowModel {
    LayerRowModel(
        validatingIndex: index,
        name: "Layer \(index)",
        visible: true,
        opacity: UnitInterval(1)!,
        isLocked: isLocked,
        isAlphaLocked: false,
        isClipped: false,
        blendMode: .normal,
        folderID: nil,
        hasMask: false,
        isTextLayer: false,
        textLayer: nil
    )!
}

private func mutationGateway(recorder: CallRecorder) -> DocumentMutationGateway {
    DocumentMutationGateway(
        resizeCanvas: { _, _ in .success(()) },
        resizeCanvasExtent: { _, _ in .success(()) },
        addLayer: { _ in
            recorder.record("addLayer")
            return .success(1)
        },
        deleteLayer: { _ in
            recorder.record("deleteLayer")
            return .success(())
        },
        setActiveLayer: { _ in
            recorder.record("setActiveLayer")
            return .success(())
        },
        setLayerName: { _, _ in .success(()) },
        setLayerVisibility: { _, _ in .success(()) },
        revealLayerForEditing: { _ in .success(()) },
        replaceLayerPixels: { _, _ in
            recorder.record("replaceLayerPixels")
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

private func editingGateway(
    recorder: CallRecorder,
    contentResult: DocumentMutationResult = .success(())
) -> DocumentEditingGateway {
    DocumentEditingGateway { request in
        switch request {
        case let .content(command):
            switch command {
            case let .replacePixels(index, _):
                recorder.record("replaceLayerPixels:\(index)")
            case let .setTextLayer(index, textLayer):
                recorder.record("setTextLayer:\(index):\(textLayer.text)")
            case let .clear(index):
                recorder.record("clearLayer:\(index)")
            case let .applyProcessing(index, _):
                recorder.record("applyLayerProcessing:\(index)")
            case let .replaceMask(index, _):
                recorder.record("replaceLayerMask:\(index)")
            case let .clearMask(index):
                recorder.record("clearLayerMask:\(index)")
            case let .applyMask(index):
                recorder.record("applyLayerMask:\(index)")
            }
            return contentResult.map { .content(LayerContentMutationPlan()) }
        case .structure, .attribute:
            return .failure(.bridgeMutationFailed("unexpected"))
        }
    }
}
