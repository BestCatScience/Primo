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
            documentQueryGateway: queryGateway(layerCount: 2),
            documentEditingGateway: DocumentEditingGateway { request in
                switch request {
                case .structure(.duplicateLayer):
                    return .success(.structure(LayerStructureMutationPlan(result: .createdLayer(DocumentCreatedLayerIndex(4)))))
                default:
                    return .failure(.bridgeMutationFailed("unexpected"))
                }
            },
            documentLayerEffectsGateway: .unused
        )

        let sourceIndex = try #require(existingLayerIndex(1, layerCount: 2))
        let index = try service.duplicateLayer(sourceIndex, named: "Copy").get()

        #expect(index.rawValue == 4)
    }

    @Test
    func layerContentCommandsValidateBeforeMutationGateways() {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1),
            documentEditingGateway: .failing(with: .invalidLayerIndex(2)),
            documentLayerEffectsGateway: .unused
        )

        let index = EditableLayerIndex(2)
        let result = service.clearLayer(index)

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

        let index = EditableLayerIndex(0)
        let result = service.applyLayerMask(index)

        expectFailure(result, .layerLocked(0))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func layerProcessingTransformRequestRejectsInvalidScaleAtConstruction() {
        #expect(TransformScale(0) == nil)
    }

    @Test
    func layerProcessingTransformRequestRejectsNonFiniteTranslationAtConstruction() {
        #expect(FiniteTranslation(CGSize(width: CGFloat.nan, height: 0)) == nil)
    }

    @Test
    func layerContentCommandsRejectOutOfBoundsProcessingTransformSelectionBeforeMutationGateways() throws {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1),
            documentEditingGateway: .failing,
            documentLayerEffectsGateway: .unused
        )
        let selection = CanvasSelection.unsafeUnchecked(
            bounds: CGRect(x: 0, y: 0, width: 2, height: 1),
            maskWidth: 2,
            maskHeight: 1,
            maskData: Data(count: 2),
            mode: .rectangle
        )

        let index = try #require(editableLayerIndex(0, layerCount: 1))
        let result = service.applyLayerProcessing(
            index,
            request: .transform(
                try #require(layerTransformRequest(selection: selection))
            )
        )

        expectFailure(result, .invalidLayerProcessingRequest("transform"))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func layerContentCommandsRejectInvalidPixelPayloadBeforeMutationGateways() throws {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1),
            documentEditingGateway: .failing,
            documentLayerEffectsGateway: .unused
        )

        let index = try #require(editableLayerIndex(0, layerCount: 1))
        let pixelData = try #require(LayerPixelData(width: 2, height: 1, rgba: Data(repeating: 0xff, count: 8)))
        let result = service.replaceLayerPixels(LayerPixelReplacementCommand(index: index, pixelData: pixelData))

        expectFailure(
            result,
            .gpu(.invalidPayloadSize(operation: "replaceLayerPixels", expected: 4, actual: 8))
        )
        #expect(recorder.events.isEmpty)
    }

    @Test
    func layerContentCommandsRejectInvalidMaskPayloadBeforeMutationGateways() throws {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1),
            documentEditingGateway: .failing,
            documentLayerEffectsGateway: .unused
        )

        let index = try #require(editableLayerIndex(0, layerCount: 1))
        let mask = try #require(LayerMaskData(width: 2, height: 1, bytes: Data(repeating: 0xff, count: 2)))
        let result = service.replaceLayerMask(index, mask: mask)

        expectFailure(
            result,
            .gpu(.invalidPayloadSize(operation: "replaceLayerMask", expected: 1, actual: 2))
        )
        #expect(recorder.events.isEmpty)
    }

    @Test
    func layerContentCommandsRejectStaleValidatedIndexesBeforeMutationGateways() throws {
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

        let index = try #require(editableLayerIndex(0, revision: DocumentRevision(1), layerCount: 1))
        let result = service.clearLayer(index)

        expectFailure(result, .staleLayerIndex(
            index: 0,
            validationRevision: DocumentRevision(1),
            currentRevision: DocumentRevision(2)
        ))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func typedLayerCommandsRejectStaleIndexesBeforeRawMutation() throws {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1, revision: { DocumentRevision(2) }),
            documentEditingGateway: .recordingContent(recorder) { _ in .success(.content) },
            documentLayerEffectsGateway: .unused
        )
        let staleIndex = try #require(editableLayerIndex(0, revision: DocumentRevision(1), layerCount: 1))

        let result = service.clearLayer(staleIndex)

        expectFailure(result, .staleLayerIndex(
            index: 0,
            validationRevision: DocumentRevision(1),
            currentRevision: DocumentRevision(2)
        ))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func staleLayerIndexesAreRejectedAfterStructureMutationSequencesAndProjectLoad() throws {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 3, revision: { DocumentRevision(2) }),
            documentEditingGateway: .recordingStructure(recorder) { _ in .success(.structure(LayerStructureMutationPlan())) },
            documentLayerEffectsGateway: .unused
        )
        let staleIndex = try #require(existingLayerIndex(1, revision: DocumentRevision(1), layerCount: 3))
        let currentDestination = try #require(existingLayerIndex(2, revision: DocumentRevision(2), layerCount: 3))
        let expected = DocumentMutationFailure.staleLayerIndex(
            index: 1,
            validationRevision: DocumentRevision(1),
            currentRevision: DocumentRevision(2)
        )

        expectFailure(service.deleteLayer(staleIndex), expected)
        expectFailure(service.duplicateLayer(staleIndex, named: "Copy"), expected)
        expectFailure(service.moveLayer(staleIndex, to: currentDestination), expected)
        expectFailure(service.setActiveLayer(staleIndex), expected)

        #expect(
            recorder.events.isEmpty,
            "delete / duplicate / move / load-project revision changes must reject stale validated indexes before mutation"
        )
    }

    @Test
    func typedCreateFolderRejectsStaleAnchorBeforeRawMutation() throws {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1, revision: { DocumentRevision(2) }),
            documentEditingGateway: .recordingStructure(recorder) { _ in .success(.structure(LayerStructureMutationPlan())) },
            documentLayerEffectsGateway: .unused
        )
        let staleAnchor = try #require(anchorLayerIndex(0, revision: DocumentRevision(1), layerCount: 1))

        let result = service.createFolder(named: "Group", afterLayerAt: staleAnchor)

        expectFailure(result, .staleLayerAnchor(
            anchorLayerIndex: 0,
            validationRevision: DocumentRevision(1),
            currentRevision: DocumentRevision(2)
        ))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func typedCreateFolderRejectsStaleNilAnchorBeforeRawMutation() throws {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1, revision: { DocumentRevision(2) }),
            documentEditingGateway: .recordingStructure(recorder) { _ in .success(.structure(LayerStructureMutationPlan())) },
            documentLayerEffectsGateway: .unused
        )
        let staleAnchor = try #require(anchorLayerIndex(nil, revision: DocumentRevision(1), layerCount: 1))

        let result = service.createFolder(named: "Group", afterLayerAt: staleAnchor)

        expectFailure(result, .staleLayerAnchor(
            anchorLayerIndex: nil,
            validationRevision: DocumentRevision(1),
            currentRevision: DocumentRevision(2)
        ))
        #expect(recorder.events.isEmpty)
    }

    @Test
    func typedPixelReplacementRejectsMismatchedGeometryBeforeRawMutation() throws {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(layerCount: 1),
            documentEditingGateway: .recordingContent(recorder) { _ in .success(.content) },
            documentLayerEffectsGateway: .unused
        )
        let index = try #require(editableLayerIndex(0, layerCount: 1))
        let pixelData = try #require(LayerPixelData(width: 2, height: 1, rgba: Data(repeating: 0xff, count: 8)))

        let result = service.replaceLayerPixels(LayerPixelReplacementCommand(index: index, pixelData: pixelData))

        expectFailure(
            result,
            .gpu(.invalidPayloadSize(operation: "replaceLayerPixels", expected: 4, actual: 8))
        )
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
            documentEditingGateway: .recordingContent(recorder) { _ in .success(.content) },
            documentLayerEffectsGateway: .unused
        )

        let indexes = try (0..<7).map { rawValue in
            try #require(editableLayerIndex(rawValue, layerCount: 7))
        }
        let pixelData = try #require(LayerPixelData(width: 1, height: 1, rgba: Data(repeating: 1, count: 4)))
        let mask = try #require(LayerMaskData(width: 1, height: 1, bytes: Data([2])))

        try service.replaceLayerPixels(LayerPixelReplacementCommand(index: indexes[0], pixelData: pixelData)).get()
        try service.setTextLayer(indexes[1], textLayer: textLayer).get()
        try service.applyLayerProcessing(indexes[2], request: LayerProcessingRequest.luminanceToAlpha).get()
        try service.clearLayer(indexes[3]).get()
        try service.replaceLayerMask(indexes[4], mask: mask).get()
        try service.clearLayerMask(indexes[5]).get()
        try service.applyLayerMask(indexes[6]).get()

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
    func failedCommandsReturnFailureWithoutOutcomeSideEffects() throws {
        let service = DocumentMutationWorkflowService(
            documentQueryGateway: queryGateway(),
            documentEditingGateway: DocumentEditingGateway { _ in
                .failure(.layerLocked(7))
            },
            documentLayerEffectsGateway: .unused
        )

        let index = try #require(existingLayerIndex(0, layerCount: 1))
        let result: DocumentMutationResult = service.setLayerVisibility(index, visible: true)

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

private func expectFailure(_ result: DocumentCreatedLayerMutationResult, _ expected: DocumentMutationFailure) {
    guard case let .failure(failure) = result else {
        Issue.record("Expected \(expected)")
        return
    }
    #expect(failure == expected)
}

private func expectFailure(_ result: DocumentCreatedFolderMutationResult, _ expected: DocumentMutationFailure) {
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
        result: @escaping @Sendable (UncheckedLayerContentMutationCommand) -> Result<DocumentEditingResult, DocumentMutationFailure>
    ) -> DocumentEditingGateway {
        DocumentEditingGateway { request in
            guard case let .content(command) = request else {
                return .failure(.bridgeMutationFailed("unexpected"))
            }
            recorder.record(command.eventDescription)
            return result(command)
        }
    }

    static func recordingStructure(
        _ recorder: MutationRecorder,
        result: @escaping @Sendable (UncheckedLayerStructureCommand) -> Result<DocumentEditingResult, DocumentMutationFailure>
    ) -> DocumentEditingGateway {
        DocumentEditingGateway { request in
            guard case let .structure(command) = request else {
                return .failure(.bridgeMutationFailed("unexpected"))
            }
            recorder.record(command.eventDescription)
            return result(command)
        }
    }
}

private extension UncheckedLayerContentMutationCommand {
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

private extension UncheckedLayerStructureCommand {
    var eventDescription: String {
        switch self {
        case let .addLayer(name):
            return "addLayer:\(name)"
        case let .duplicateLayer(index, name):
            return "duplicateLayer:\(index):\(name)"
        case let .deleteLayer(index):
            return "deleteLayer:\(index)"
        case let .moveLayer(index, destinationIndex):
            return "moveLayer:\(index):\(destinationIndex)"
        case let .createFolder(name, anchorLayerIndex):
            return "createFolder:\(name):\(String(describing: anchorLayerIndex))"
        case let .deleteFolder(folderID):
            return "deleteFolder:\(folderID)"
        case let .assignLayerToFolder(index, folderID):
            return "assignLayerToFolder:\(index):\(String(describing: folderID))"
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
        canvasGeometry: PixelGeometry(width: 1, height: 1),
        isLayerLocked: { lockedLayerIndexes.contains($0) }
    )
    .editableLayerIndex(rawValue)
}

private func existingLayerIndex(
    _ rawValue: Int,
    revision: DocumentRevision = .initial,
    layerCount: Int
) -> ExistingLayerIndex? {
    DocumentLayerMutationContext(
        revision: revision,
        layerCount: layerCount,
        folderIDs: [],
        canvasGeometry: PixelGeometry(width: 1, height: 1),
        isLayerLocked: { _ in false }
    )
    .existingLayerIndex(rawValue)
}

private func anchorLayerIndex(
    _ rawValue: Int?,
    revision: DocumentRevision = .initial,
    layerCount: Int
) -> LayerAnchorIndex? {
    DocumentLayerMutationContext(
        revision: revision,
        layerCount: layerCount,
        folderIDs: [],
        canvasGeometry: PixelGeometry(width: 1, height: 1),
        isLayerLocked: { _ in false }
    )
    .anchorLayerIndex(rawValue)
}

private func layerTransformRequest(selection: CanvasSelection?) -> LayerTransformProcessingRequest? {
    guard let translation = FiniteTranslation(.zero),
          let scale = TransformScale(1),
          let rotationDegrees = RotationDegrees(0) else {
        return nil
    }
    return LayerTransformProcessingRequest(
        translation: translation,
        scale: scale,
        rotationDegrees: rotationDegrees,
        selection: selection
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
