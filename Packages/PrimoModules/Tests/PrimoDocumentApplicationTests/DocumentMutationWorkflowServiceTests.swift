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

struct DocumentMutationWorkflowServiceTests {
    @Test
    func layerStructureCommandsReturnResultingIndexes() throws {
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(),
            documentEditingGateway: DocumentEditingGateway { request in
                switch request {
                case .structure(.duplicateLayer):
                    return .success(.structure(LayerStructureMutationPlan(resultingIndex: 4)))
                default:
                    return .failure(.bridgeMutationFailed("unexpected"))
                }
            },
            documentLayerEffectsGateway: .unused
        )

        let index = try service.duplicateLayer(1, named: "Copy").get()

        #expect(index == 4)
    }

    @Test
    func layerContentCommandsValidateBeforeMutationGateways() {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1),
            documentEditingGateway: .failing(with: .invalidLayerIndex(2)),
            documentLayerEffectsGateway: .unused
        )

        let result = service.clearLayer(2)

        expectFailure(result, .invalidLayerIndex(2))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func layerContentCommandsRejectLockedLayersBeforeMutationGateways() {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1, lockedLayerIndexes: [0]),
            documentEditingGateway: .failing(with: .layerLocked(0)),
            documentLayerEffectsGateway: .unused
        )

        let result = service.applyLayerMask(0)

        expectFailure(result, .layerLocked(0))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func layerContentCommandsRejectInvalidProcessingTransformBeforeMutationGateways() {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1),
            documentEditingGateway: .failing,
            documentLayerEffectsGateway: .unused
        )

        let result = service.applyLayerProcessing(
            0,
            request: .transform(
                translation: .zero,
                scale: 0,
                rotationDegrees: 0,
                selection: nil
            )
        )

        expectFailure(result, .invalidLayerProcessingRequest("transform"))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func layerContentCommandsRejectInvalidPixelPayloadBeforeMutationGateways() {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1),
            documentEditingGateway: .failing,
            documentLayerEffectsGateway: .unused
        )

        let result = service.replaceLayerPixels(0, pixelData: Data(repeating: 0xff, count: 3))

        expectFailure(
            result,
            .gpu(.invalidPayloadSize(operation: "replaceLayerPixels", expected: 4, actual: 3))
        )
        #expect(recorder.events.isEmpty)
    }

    @Test
    func layerContentCommandsRejectInvalidMaskPayloadBeforeMutationGateways() {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1),
            documentEditingGateway: .failing,
            documentLayerEffectsGateway: .unused
        )

        let result = service.replaceLayerMask(0, maskData: Data(repeating: 0xff, count: 2))

        expectFailure(
            result,
            .gpu(.invalidPayloadSize(operation: "replaceLayerMask", expected: 1, actual: 2))
        )
        #expect(recorder.events.isEmpty)
    }

    @Test
    func layerContentCommandsRejectStaleValidatedIndexesBeforeMutationGateways() {
        let recorder = MutationRecorder()
        let revision = RevisionSequence([DocumentRevision(1), DocumentRevision(2)])
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1, revision: { revision.next() }),
            documentEditingGateway: .failing(
                with: .staleLayerIndex(
                    index: 0,
                    validationRevision: DocumentRevision(1),
                    currentRevision: DocumentRevision(2)
                )
            ),
            documentLayerEffectsGateway: .unused
        )

        let result = service.clearLayer(0)

        expectFailure(result, .staleLayerIndex(
            index: 0,
            validationRevision: DocumentRevision(1),
            currentRevision: DocumentRevision(2)
        ))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func validLayerContentCommandsRouteThroughValidatedIndexes() throws {
        let recorder = MutationRecorder()
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
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 7),
            documentEditingGateway: .recordingContent(recorder) { _ in .success(.content(LayerContentMutationPlan())) },
            documentLayerEffectsGateway: .unused
        )

        try service.replaceLayerPixels(0, pixelData: Data(repeating: 1, count: 4)).get()
        try service.setTextLayer(1, textLayer: textLayer).get()
        try service.applyLayerProcessing(2, request: LayerProcessingRequest.luminanceToAlpha).get()
        try service.clearLayer(3).get()
        try service.replaceLayerMask(4, maskData: Data([2])).get()
        try service.clearLayerMask(5).get()
        try service.applyLayerMask(6).get()

        #expect(recorder.events == [
            "replacePixels:0",
            "text:1:Hello",
            "process:2:true",
            "clear:3",
            "replaceMask:4",
            "clearMask:5",
            "applyMask:6",
        ])
    }

    @Test
    func failedCommandsReturnFailureWithoutOutcomeSideEffects() {
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(),
            documentEditingGateway: DocumentEditingGateway { _ in
                .failure(.layerLocked(7))
            },
            documentLayerEffectsGateway: .unused
        )

        let result: DocumentMutationResult = service.setLayerVisibility(7, visible: true)

        guard case let .failure(failure) = result else {
            Issue.record("Expected layerLocked failure")
            return
        }
        #expect(failure == .layerLocked(7))
    }
}

private final class MutationRecorder: @unchecked Sendable {
    var clearedLayerIndex: Int?
    var appliedMaskIndex: Int?
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private final class RevisionSequence: @unchecked Sendable {
    private var values: [DocumentRevision]

    init(_ values: [DocumentRevision]) {
        self.values = values
    }

    func next() -> DocumentRevision {
        values.isEmpty ? .initial : values.removeFirst()
    }
}

private func expectFailure(_ result: DocumentMutationResult, _ expected: DocumentMutationFailure) {
    guard case let .failure(failure) = result else {
        Issue.record("Expected \(expected)")
        return
    }
    #expect(failure == expected)
}

private extension DocumentEditingGateway {
    static let failing = DocumentEditingGateway { _ in
        .failure(.bridgeMutationFailed("unused"))
    }

    static func failing(with failure: DocumentMutationFailure) -> DocumentEditingGateway {
        DocumentEditingGateway { _ in .failure(failure) }
    }

    static func recordingContent(
        _ recorder: MutationRecorder,
        result: @escaping @Sendable (LayerContentMutationCommand) -> Result<DocumentEditingResult, DocumentMutationFailure>
    ) -> DocumentEditingGateway {
        DocumentEditingGateway { request in
            guard case let .content(command) = request else {
                return .failure(.bridgeMutationFailed("unexpected"))
            }
            recorder.record(command.eventDescription)
            return result(command)
        }
    }
}

private extension LayerContentMutationCommand {
    var eventDescription: String {
        switch self {
        case let .replacePixels(index, _):
            return "replacePixels:\(index)"
        case let .setTextLayer(index, textLayer):
            return "text:\(index):\(textLayer.text)"
        case let .clear(index):
            return "clear:\(index)"
        case let .applyProcessing(index, request):
            return "process:\(index):\(request == .luminanceToAlpha)"
        case let .replaceMask(index, _):
            return "replaceMask:\(index)"
        case let .clearMask(index):
            return "clearMask:\(index)"
        case let .applyMask(index):
            return "applyMask:\(index)"
        }
    }
}

private extension DocumentLayerEffectsGateway {
    static let unused = DocumentLayerEffectsGateway(
        mergeLayerDown: { _ in .failure(.bridgeMutationFailed("unused")) }
    )
}

private extension TextLayerGateway {
    static let unused = TextLayerGateway(
        textLayerData: { _ in .success(nil) },
        setTextLayer: { _, _ in .failure(.bridgeMutationFailed("unused")) },
        clearTextLayerData: { _ in .success(()) }
    )
}

private extension DocumentMutationGateway {
    static let unused = stub()

    static func stub(
        replaceLayerPixels: @escaping @Sendable (Int, Data) -> DocumentMutationResult = { _, _ in .failure(.bridgeMutationFailed("unused")) },
        replaceLayerMask: @escaping @Sendable (Int, Data) -> DocumentMutationResult = { _, _ in .failure(.bridgeMutationFailed("unused")) },
        clearLayerMask: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .failure(.bridgeMutationFailed("unused")) },
        clearLayer: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .failure(.bridgeMutationFailed("unused")) },
        applyLayerMask: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .failure(.bridgeMutationFailed("unused")) },
        applyLayerProcessing: @escaping @Sendable (Int, LayerProcessingRequest) -> DocumentMutationResult = { _, _ in .failure(.bridgeMutationFailed("unused")) }
    ) -> DocumentMutationGateway {
        DocumentMutationGateway(
            resizeCanvas: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            resizeCanvasExtent: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            addLayer: { _ in .failure(.bridgeMutationFailed("unused")) },
            deleteLayer: { _ in .failure(.bridgeMutationFailed("unused")) },
            setActiveLayer: { _ in .failure(.bridgeMutationFailed("unused")) },
            setLayerName: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            setLayerVisibility: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            revealLayerForEditing: { _ in .failure(.bridgeMutationFailed("unused")) },
            replaceLayerPixels: replaceLayerPixels,
            replaceLayerPixelsInRect: { _, _, _ in .failure(.bridgeMutationFailed("unused")) },
            applyLayerSurfaceMutation: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            applyLayerMutation: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            applyTextLayerMutation: { _, _, _ in .failure(.bridgeMutationFailed("unused")) },
            replaceLayerMask: replaceLayerMask,
            clearLayerMask: clearLayerMask,
            applyLayerMask: applyLayerMask,
            clearLayer: clearLayer,
            applyLayerProcessing: applyLayerProcessing
        )
    }
}

private func queryGateway(
    layerCount: Int = 1,
    lockedLayerIndexes: Set<Int> = [],
    revision: @escaping @Sendable () -> DocumentRevision = { .initial }
) -> DocumentQueryGateway {
    DocumentQueryGateway(
        lightweightPresentation: {
            .success(presentation(layerCount: layerCount, lockedLayerIndexes: lockedLayerIndexes, revision: revision()))
        },
        presentation: {
            .success(presentation(layerCount: layerCount, lockedLayerIndexes: lockedLayerIndexes, revision: revision()))
        }
    )
}

private func presentation(
    layerCount: Int,
    lockedLayerIndexes: Set<Int>,
    revision: DocumentRevision
) -> PaintDocumentPresentation {
    let rows = (0..<layerCount).map { index in
        LayerRowModel(
            validatingIndex: index,
            name: "Layer \(index + 1)",
            visible: true,
            opacity: UnitInterval(1)!,
            isLocked: lockedLayerIndexes.contains(index),
            isAlphaLocked: false,
            isClipped: false,
            blendMode: .normal,
            folderID: nil,
            hasMask: false,
            isTextLayer: false,
            textLayer: nil
        )!
    }
    return PaintDocumentPresentation(
        validatingCanvasSize: CGSize(width: 1, height: 1),
        activeLayerIndex: 0,
        layerRows: rows,
        layerSidebarRows: rows.map { .layer($0, depth: 0) },
        renderSnapshot: nil,
        revision: revision
    )!
}
