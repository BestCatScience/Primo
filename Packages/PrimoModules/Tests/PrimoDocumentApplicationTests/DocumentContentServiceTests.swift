import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
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

        let pixelData = LayerPixelData(
            width: 64,
            height: 64,
            rgba: Data(repeating: 0xff, count: 64 * 64 * 4)
        )!
        let result = service.applyPixels(
            pixelData,
            to: .existingLayer(index: EditableLayerIndex(4))
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
    func canvasEditingTransformReturnsFailureWhenLayerPixelReadFails() {
        let recorder = CallRecorder()
        let contentService = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 7, layerCount: 1),
            documentRenderGateway: renderGateway(pixelDataForLayer: { _ in .failure(.invalidLayerIndex(7)) }),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )
        let transformProcessor = RecordingLayerTransformProcessor()
        let service = CanvasEditingWorkflowService(
            documentContentService: contentService,
            layerTransformProcessor: transformProcessor
        )

        let outcome = service.execute(
            .applyTransform,
            state: CanvasEditingContext(
                transformHasPreview: true,
                transformPreviewOffset: CGSize(width: 1, height: 0),
                transformPreviewScaleX: 1,
                transformPreviewScaleY: 1,
                transformPreviewRotationDegrees: 0,
                transformMode: .standard,
                transformPivot: nil,
                transformQuadOffsets: .zero,
                activeLayerIndex: 7,
                activeTextLayer: nil,
                selection: nil,
                canvasSize: CGSize(width: 2, height: 2)
            )
        )

        #expect(outcome == .failure(.invalidLayerIndex(7)))
        #expect(transformProcessor.transformedLayerPixelsCallCount == 0)
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
    func typedPixelReplacementExecutesValidatedContentMutation() throws {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 0, layerCount: 1),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )
        let index = try #require(editableLayerIndex(0, layerCount: 1))
        let pixelData = try #require(LayerPixelData(width: 64, height: 64, rgba: Data(repeating: 0xff, count: 64 * 64 * 4)))

        let result = service.replaceLayerPixels(
            LayerPixelReplacementCommand(index: index, pixelData: pixelData)
        )

        try result.get()
        #expect(recorder.values == ["replaceLayerPixels:0"])
    }

    @Test
    func typedPixelReplacementRejectsStaleLayerIndexBeforeMutationGateway() throws {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 0, layerCount: 1, revision: .initial.advanced()),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )
        let index = try #require(editableLayerIndex(0, revision: .initial, layerCount: 1))
        let pixelData = try #require(LayerPixelData(width: 64, height: 64, rgba: Data(repeating: 0xff, count: 64 * 64 * 4)))

        let result = service.replaceLayerPixels(
            LayerPixelReplacementCommand(index: index, pixelData: pixelData)
        )

        switch result {
        case let .failure(failure):
            #expect(failure == .staleLayerIndex(index: 0, validationRevision: .initial, currentRevision: .initial.advanced()))
        case .success:
            Issue.record("Expected stale layer index failure")
        }
        #expect(recorder.values.isEmpty)
    }

    @Test
    func typedPixelReplacementRejectsLayerThatIsNoLongerEditableBeforeMutationGateway() throws {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 0, layerCount: 1),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )
        let index = try #require(editableLayerIndex(1, layerCount: 2))
        let pixelData = try #require(LayerPixelData(width: 64, height: 64, rgba: Data(repeating: 0xff, count: 64 * 64 * 4)))

        let result = service.replaceLayerPixels(
            LayerPixelReplacementCommand(index: index, pixelData: pixelData)
        )

        switch result {
        case let .failure(failure):
            #expect(failure == .invalidLayerIndex(1))
        case .success:
            Issue.record("Expected invalid layer index failure")
        }
        #expect(recorder.values.isEmpty)
    }

    @Test
    func typedPixelReplacementRejectsLayerThatBecameLockedBeforeMutationGateway() throws {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 0, layerCount: 1, lockedLayerIndexes: [0]),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )
        let index = try #require(editableLayerIndex(0, layerCount: 1))
        let pixelData = try #require(LayerPixelData(width: 64, height: 64, rgba: Data(repeating: 0xff, count: 64 * 64 * 4)))

        let result = service.replaceLayerPixels(
            LayerPixelReplacementCommand(index: index, pixelData: pixelData)
        )

        switch result {
        case let .failure(failure):
            #expect(failure == .layerLocked(0))
        case .success:
            Issue.record("Expected locked layer failure")
        }
        #expect(recorder.values.isEmpty)
    }

    @Test
    func typedPixelReplacementRejectsPixelDataWithDifferentGeometryBeforeMutationGateway() throws {
        let recorder = CallRecorder()
        let service = DocumentContentService(
            documentQueryGateway: queryGateway(activeLayerIndex: 0, layerCount: 1),
            documentRenderGateway: renderGateway(),
            documentEditingGateway: editingGateway(recorder: recorder),
            documentMutationGateway: mutationGateway(recorder: recorder)
        )
        let index = try #require(editableLayerIndex(0, layerCount: 1))
        let pixelData = try #require(LayerPixelData(width: 1, height: 1, rgba: Data(repeating: 0xff, count: 4)))

        let result = service.replaceLayerPixels(
            LayerPixelReplacementCommand(index: index, pixelData: pixelData)
        )

        guard case let .failure(.gpu(.invalidPayloadSize(operation, expected, actual))) = result else {
            Issue.record("Expected invalid payload size failure")
            return
        }
        #expect(operation == "replaceLayerPixels")
        #expect(expected == 64 * 64 * 4)
        #expect(actual == 4)
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
    lockedLayerIndexes: Set<Int> = [],
    revision: DocumentRevision = .initial
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
        renderSnapshot: nil,
        revision: revision
    )!
    return DocumentQueryGateway(
        lightweightPresentation: { .success(presentation) },
        presentation: { .success(presentation) }
    )
}

private func renderGateway(
    pixelDataForLayer: @escaping @Sendable (Int) -> Result<Data, DocumentMutationFailure> = { _ in .success(Data()) }
) -> DocumentRenderGateway {
    DocumentRenderGateway(
        compositePixelData: { .success(Data()) },
        compositeSurface: { .success(DocumentCompositeSurface(unsafeUncheckedWidth: 0, height: 0, pixelData: Data())) },
        pixelDataForLayer: pixelDataForLayer
    )
}

private final class RecordingLayerTransformProcessor: LayerTransformProcessing, @unchecked Sendable {
    private let lock = NSLock()
    private var transformedLayerPixelsCalls = 0

    var transformedLayerPixelsCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return transformedLayerPixelsCalls
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
        lock.lock()
        transformedLayerPixelsCalls += 1
        lock.unlock()
        return source.data
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
        selection
    }

    func transformationBounds(
        selection: CanvasSelection?,
        surface: RgbaSurface
    ) -> CGRect? {
        nil
    }
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

private func editableLayerIndex(
    _ rawValue: Int,
    revision: DocumentRevision = .initial,
    layerCount: Int,
    lockedLayerIndexes: Set<Int> = []
) -> EditableLayerIndex? {
    DocumentLayerMutationContext(
        revision: revision,
        layerCount: layerCount,
        folderIDs: [],
        isLayerLocked: { lockedLayerIndexes.contains($0) }
    )
    .editableLayerIndex(rawValue)
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
