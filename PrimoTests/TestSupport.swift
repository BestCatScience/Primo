import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoDocumentGPUContracts
import PrimoDocumentStrokeApplication
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure
@testable import Primo

extension PrimoRootFeature.Action {
    static func workspacePersistenceRequested(_ request: WorkspaceFeature.WorkspacePersistenceRequest) -> Self {
        .workspace(.persistenceRequested(request))
    }

    static func workspaceCatalogRequested(_ request: WorkspaceFeature.WorkspaceCatalogRequest) -> Self {
        .workspace(.catalogRequested(request))
    }

    static func workspaceCatalogSucceeded(_ result: WorkspaceFeature.WorkspaceCatalogResult) -> Self {
        .workspace(.catalogSucceeded(result))
    }
}

enum TestError: LocalizedError, Equatable {
    case expected(String)

    var errorDescription: String? {
        switch self {
        case let .expected(message):
            return message
        }
    }
}

final class TestRecorder<Value>: @unchecked Sendable {
    private(set) var values: [Value] = []

    func record(_ value: Value) {
        values.append(value)
    }
}

extension LayerRowModel {
    static func testValue(
        index: Int = 0,
        isLocked: Bool = false,
        isAlphaLocked: Bool = false
    ) -> Self {
        Self(
            index: index,
            name: "Layer \(index + 1)",
            visible: true,
            opacity: 1.0,
            isLocked: isLocked,
            isAlphaLocked: isAlphaLocked,
            isClipped: false,
            blendMode: .normal,
            folderID: nil,
            hasMask: false,
            isTextLayer: false,
            textLayer: nil
        )
    }
}

extension PaintDocumentPresentation {
    static func testValue(
        canvasSize: CGSize = CanvasFeature.defaultCanvasSize,
        activeLayerIndex: Int = 0,
        layerRows: [LayerRowModel]? = nil,
        renderSnapshot: MetalDocumentSnapshot? = nil
    ) -> Self {
        let resolvedLayerRows = layerRows ?? [LayerRowModel.testValue(index: activeLayerIndex)]
        return Self(
            canvasSize: canvasSize,
            activeLayerIndex: activeLayerIndex,
            layerRows: resolvedLayerRows,
            layerSidebarRows: resolvedLayerRows.map { .layer($0, depth: 0) },
            renderSnapshot: renderSnapshot
        )
    }

    static func renderedTestValue(
        width: Int = 4,
        height: Int = 4,
        activeLayerIndex: Int = 0
    ) -> Self {
        testValue(
            canvasSize: CGSize(width: width, height: height),
            activeLayerIndex: activeLayerIndex,
            renderSnapshot: MetalDocumentSnapshot(
                width: width,
                height: height,
                revision: 1,
                compositePixelData: Data(repeating: 0, count: width * height * 4),
                layers: [
                    MetalLayerSnapshot(
                        index: activeLayerIndex,
                        opacity: 1,
                        visible: true,
                        isClipped: false,
                        blendMode: .normal,
                        thumbnailData: nil,
                        pixelData: Data(repeating: 0, count: width * height * 4)
                    )
                ]
            )
        )
    }
}

extension LoadedPaintProject {
    static func testValue(
        presentation: PaintDocumentPresentation = .testValue(),
        paperStyle: CanvasPaperStyle = .default
    ) -> Self {
        Self(
            presentation: presentation,
            paperStyle: paperStyle
        )
    }
}

extension OpenDocumentTab {
    static func testValue(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: String = "Test Document",
        backingStoreURL: DocumentProjectPath = DocumentProjectPath(URL(fileURLWithPath: "/tmp/backing.atelier")),
        sourceProjectURL: DocumentProjectPath? = DocumentProjectPath(URL(fileURLWithPath: "/tmp/source.atelier")),
        canvasSize: CGSize = CanvasFeature.defaultCanvasSize,
        isDirty: Bool = true,
        pane: WorkspacePane = .primary,
        previewImageData: Data? = nil
    ) -> Self {
        Self(
            id: id,
            title: title,
            backingStoreURL: backingStoreURL,
            sourceProjectURL: sourceProjectURL,
            canvasSize: canvasSize,
            isDirty: isDirty,
            pane: pane,
            previewImageData: previewImageData
        )
    }
}

extension StylusSample {
    static func testValue(
        point: CGPoint = CGPoint(x: 12, y: 18)
    ) -> Self {
        Self(
            point: point,
            pressure: 1.0,
            altitude: 0.0,
            azimuth: 0.0,
            timestamp: 0.0
        )
    }
}

extension WorkspaceItemID {
    static func testValue(_ rawValue: String = "workspace-item") -> Self {
        Self(unchecked: rawValue)
    }
}

extension DocumentQueryGateway {
    static func stub(
        presentation: PaintDocumentPresentation = .testValue(),
        compositePixelData: @escaping @Sendable () -> Data = { Data() },
        compositeSurface: @escaping @Sendable () -> DocumentCompositeSurface = {
            DocumentCompositeSurface(width: 1, height: 1, pixelData: Data([0, 0, 0, 0]))
        },
        pixelDataForLayer: @escaping @Sendable (Int) -> Data = { _ in Data() }
    ) -> Self {
        Self(
            lightweightPresentation: { presentation },
            presentation: { presentation },
            compositePixelData: compositePixelData,
            compositeSurface: compositeSurface,
            pixelDataForLayer: pixelDataForLayer,
            consumeDirtyUpdate: { nil }
        )
    }
}

extension DocumentMutationGateway {
    static func stub(
        resizeCanvas: @escaping @Sendable (Int, Int) -> DocumentMutationResult = { _, _ in .success(()) },
        resizeCanvasExtent: @escaping @Sendable (Int, Int) -> DocumentMutationResult = { _, _ in .success(()) },
        addLayer: @escaping @Sendable (String) -> DocumentIndexedMutationResult = { _ in .success(0) },
        deleteLayer: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .success(()) },
        setActiveLayer: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .success(()) },
        setLayerName: @escaping @Sendable (Int, String) -> DocumentMutationResult = { _, _ in .success(()) },
        setLayerVisibility: @escaping @Sendable (Int, Bool) -> DocumentMutationResult = { _, _ in .success(()) },
        revealLayerForEditing: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .success(()) },
        replaceLayerPixels: @escaping @Sendable (Int, Data) -> DocumentMutationResult = { _, _ in .success(()) },
        replaceLayerPixelsInRect: @escaping @Sendable (Int, LayerPixelRect, Data) -> DocumentMutationResult = { _, _, _ in .success(()) },
        applyLayerSurfaceMutation: @escaping @Sendable (Int, GpuLayerMutationPayload) -> DocumentMutationResult = { _, _ in .success(()) },
        applyLayerMutation: @escaping @Sendable (Int, DocumentLayerMutationPayload) -> DocumentMutationResult = { _, _ in .success(()) },
        applyTextLayerMutation: @escaping @Sendable (Int, TextLayerData, DocumentLayerMutationPayload) -> DocumentMutationResult = { _, _, _ in .success(()) },
        applyLayerProcessing: @escaping @Sendable (Int, LayerProcessingRequest) -> DocumentMutationResult = { _, _ in .success(()) }
    ) -> Self {
        Self(
            resizeCanvas: resizeCanvas,
            resizeCanvasExtent: resizeCanvasExtent,
            addLayer: addLayer,
            deleteLayer: deleteLayer,
            setActiveLayer: setActiveLayer,
            setLayerName: setLayerName,
            setLayerVisibility: setLayerVisibility,
            revealLayerForEditing: revealLayerForEditing,
            replaceLayerPixels: replaceLayerPixels,
            replaceLayerPixelsInRect: replaceLayerPixelsInRect,
            applyLayerSurfaceMutation: applyLayerSurfaceMutation,
            applyLayerMutation: applyLayerMutation,
            applyTextLayerMutation: applyTextLayerMutation,
            replaceLayerMask: { _, _ in .success(()) },
            clearLayerMask: { _ in .success(()) },
            applyLayerMask: { _ in .success(()) },
            clearLayer: { _ in .success(()) },
            applyLayerProcessing: applyLayerProcessing
        )
    }
}

extension StrokeInputGateway {
    static func stub(
        blurStroke: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult = { _, _, _, _ in .success(()) },
        fill: @escaping @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult = { _, _ in .success(()) },
        applyGpuStrokeSurface: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult = { _, _, _ in .success(()) }
    ) -> Self {
        Self(
            beginStroke: { _, _ in },
            appendStroke: { _ in },
            endStroke: { .success(()) },
            cancelStroke: {},
            blurStroke: blurStroke,
            endBlurStroke: { .success(()) },
            fill: fill,
            applyGpuStrokeSurface: applyGpuStrokeSurface
        )
    }
}

extension DocumentHistoryGateway {
    static func stub(
        undo: @escaping @Sendable () -> DocumentMutationResult = { .success(()) },
        redo: @escaping @Sendable () -> DocumentMutationResult = { .success(()) }
    ) -> Self {
        Self(
            canUndo: { true },
            canRedo: { true },
            undo: undo,
            redo: redo
        )
    }
}

extension DocumentLayerEffectsGateway {
    static func stub(
        mergeLayerDown: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .success(()) }
    ) -> Self {
        Self(mergeLayerDown: mergeLayerDown)
    }
}

extension DocumentEditingGateway {
    static func stub(
        execute: @escaping @Sendable (DocumentEditingRequest) -> Result<DocumentEditingResult, DocumentMutationFailure> = { request in
            switch request {
            case .structure:
                return .success(.structure(LayerStructureMutationPlan()))
            case .attribute:
                return .success(.attribute(LayerAttributeMutationPlan()))
            }
        }
    ) -> Self {
        Self(execute: execute)
    }
}

extension DocumentPersistenceGateway {
    static func stub(
        saveProject: @escaping @Sendable (URL, CanvasPaperStyle) throws -> Void = { _, _ in },
        loadProject: @escaping @Sendable (URL) throws -> LoadedPaintProject = { _ in .testValue() }
    ) -> Self {
        Self(
            saveProject: saveProject,
            loadProject: loadProject,
            setPaperStyle: { _ in },
            newCanvas: { _, _ in },
            prewarmDrawingResources: {}
        )
    }
}

extension DocumentExportGateway {
    static func stub(
        compositeSurface: @escaping @Sendable (CanvasPaperStyle) -> DocumentCompositeSurface? = { _ in nil },
        compositePNGData: @escaping @Sendable (CanvasPaperStyle) -> Data? = { _ in nil },
        timelapseCapture: @escaping @Sendable () -> TimelapseCapture? = { nil }
    ) -> Self {
        Self(
            compositeSurface: compositeSurface,
            compositePNGData: compositePNGData,
            timelapseCapture: timelapseCapture
        )
    }
}

extension DocumentRuntimeComposition {
    static func stub(
        queryGateway: DocumentQueryGateway = .stub(),
        mutationGateway: DocumentMutationGateway = .stub(),
        strokeGateway: StrokeInputGateway = .stub(),
        historyGateway: DocumentHistoryGateway = .stub(),
        persistenceGateway: DocumentPersistenceGateway = .stub(),
        exportGateway: DocumentExportGateway = .stub(),
        textLayerGateway: TextLayerGateway = .stub(),
        layerEffectsGateway: DocumentLayerEffectsGateway = .stub(),
        editingGateway: DocumentEditingGateway? = nil,
        strokeSessionUseCase: DocumentStrokeSessionUseCase? = nil,
        gpuOperationGateway: DocumentGpuOperationGateway = .stub()
    ) -> Self {
        let resolvedEditingGateway = editingGateway ?? DocumentEditingGateway.stub()
        return Self(
            queryGateway: queryGateway,
            mutationGateway: mutationGateway,
            strokeGateway: strokeGateway,
            historyGateway: historyGateway,
            persistenceGateway: persistenceGateway,
            exportGateway: exportGateway,
            textLayerGateway: textLayerGateway,
            layerEffectsGateway: layerEffectsGateway,
            editingGateway: resolvedEditingGateway,
            strokeSessionUseCase: strokeSessionUseCase ?? .stub(),
            gpuOperationGateway: gpuOperationGateway
        )
    }
}

extension DocumentGpuOperationGateway {
    static func stub() -> Self {
        Self(
            compositedPaperPreviewRGBA: { _, _, _, _ in nil },
            compositedPreviewPixelData: { _, _, _ in nil },
            compositedPreviewIncrementalUpdate: { _, _, _, _ in nil },
            selectionOverlayRGBA: { _, _, _ in nil },
            eyedropperLoupeRGBA: { _, _, _, _, _, _, _, _ in nil },
            shapePreviewSurface: { _, _, _, _ in nil },
            textLayerSurface: { _, _ in nil },
            textLayoutRect: { _, _ in nil },
            processedLayerPixelData: { _, _, _, _ in nil },
            alphaMask: { _, _, _ in nil },
            croppedSelectionMask: { _, _, _ in nil },
            combinedSelectionMask: { _, _, _, _, _ in nil },
            expandedSelectionMask: { _ in nil },
            lassoSelection: { _, _, _ in nil },
            autoSelection: { _, _, _, _, _, _, _, _, _ in nil },
            colorRangeSelection: { _, _, _, _ in nil },
            expandedMask: { _, _, _, _ in nil },
            contractedMask: { _, _, _, _ in nil },
            featheredMask: { _, _, _, _ in nil },
            invertMask: { _ in nil },
            transformedSelectionMask: { _ in nil },
            transformedLayerPixelData: { _ in nil },
            scaledPixelData: { _, _, _, _, _ in nil },
            translatedPixelData: { _, _, _, _, _, _, _ in nil },
            releaseSurfaceHandle: { _ in }
        )
    }
}

extension DocumentStrokeSessionUseCase {
    static func stub(
        execute: @escaping @Sendable (GpuStrokeSessionCommand) -> GpuStrokeSessionOutcome = { _ in .reset }
    ) -> Self {
        let adapter = StubStrokeSessionAdapter(execute: execute)
        return Self(
            preview: DocumentStrokePreviewUseCase(planner: adapter),
            commit: DocumentStrokeCommitUseCase(renderer: adapter),
            resetInteractiveStrokeState: {},
            executeOverride: execute
        )
    }
}

private final class StubStrokeSessionAdapter: StrokePreviewPlanning, StrokeCommitRendering, @unchecked Sendable {
    let execute: @Sendable (GpuStrokeSessionCommand) -> GpuStrokeSessionOutcome

    init(execute: @escaping @Sendable (GpuStrokeSessionCommand) -> GpuStrokeSessionOutcome) {
        self.execute = execute
    }

    func makePreview(_ request: StrokePreviewRequest) -> StrokePreviewResult? {
        guard case let .preview(mutation) = execute(
            .begin(
                sample: request.samples.first ?? StylusSample(point: .zero, pressure: 1, altitude: 0, azimuth: 0, timestamp: 0),
                baseSnapshot: request.snapshot,
                context: DocumentStrokeContext(
                    activeLayer: .testValue(index: request.activeLayerIndex),
                    activeLayerIndex: request.activeLayerIndex,
                    brush: request.brush,
                    previewBrush: request.brush
                ),
                usesResponsivePreview: request.usesResponsivePreview
            )
        ) else {
            return nil
        }
        return StrokePreviewResult(
            baseSnapshot: mutation.baseSnapshot,
            surface: mutation.surface,
            dirtyRegion: mutation.dirtyRegion,
            incrementalUpdate: mutation.incrementalUpdate,
            isApproximatePreview: mutation.isApproximatePreview
        )
    }

    func makeCommittedSurface(_ request: StrokeCommitRequest) -> StrokeCommitResult? {
        guard case let .commit(mutation) = execute(
            .finish(
                renderState: nil,
                baseSnapshot: request.snapshot,
                renderSnapshot: nil,
                samples: request.samples,
                context: DocumentStrokeContext(
                    activeLayer: .testValue(index: request.activeLayerIndex),
                    activeLayerIndex: request.activeLayerIndex,
                    brush: request.brush,
                    previewBrush: request.brush
                ),
                allowsApproximatePreviewCommit: true,
                refreshViaDirtyPresentation: true
            )
        ) else {
            return nil
        }
        return StrokeCommitResult(surface: mutation.surface, dirtyRegion: mutation.dirtyRegion)
    }
}

extension TextLayerGateway {
    static func stub(
        setTextLayer: @escaping @Sendable (Int, TextLayerData) -> DocumentMutationResult = { _, _ in .success(()) }
    ) -> Self {
        Self(
            textLayerData: { _ in nil },
            setTextLayer: setTextLayer,
            clearTextLayerData: { _ in }
        )
    }
}

extension DocumentWorkspaceClient {
    static func stub(
        createTabBackingStoreURL: @escaping @Sendable (UUID) throws -> DocumentProjectPath = {
            DocumentProjectPath(URL(fileURLWithPath: "/tmp/\($0.uuidString).atelier"))
        },
        createProjectURL: @escaping @Sendable () throws -> DocumentProjectPath = {
            DocumentProjectPath(URL(fileURLWithPath: "/tmp/project.atelier"))
        },
        writePNGToTemporaryDirectory: @escaping @Sendable (Data) throws -> URL = { _ in
            URL(fileURLWithPath: "/tmp/export.png")
        },
        timelapseTemporaryDirectory: @escaping @Sendable () -> URL = {
            URL(fileURLWithPath: "/tmp")
        },
        loadSavedProjects: @escaping @Sendable () throws -> [SavedProjectSummary] = { [] },
        moveSavedProject: @escaping @Sendable (DocumentProjectPath, RelativeProjectFolderPath?) throws -> DocumentProjectPath = { url, _ in
            url
        },
        loadAutosaveRecoveryItems: @escaping @Sendable () throws -> [AutosaveRecoveryItem] = { [] },
        discardAutosaveEntry: @escaping @Sendable (WorkspaceItemID) throws -> Void = { _ in },
        discardAutosaveSnapshot: @escaping @Sendable (OpenDocumentTab) throws -> Void = { _ in },
        persistAutosaveSnapshot: @escaping @Sendable (DocumentProjectPath, OpenDocumentTab) throws -> Void = { _, _ in },
        persistProjectSnapshot: @escaping @Sendable (DocumentProjectPath, DocumentProjectPath?) throws -> DocumentProjectPath = { sourceURL, preferredDestinationURL in
            preferredDestinationURL ?? sourceURL
        },
        loadSaveHistoryEntries: @escaping @Sendable (OpenDocumentTab) throws -> [SaveHistoryEntry] = { _ in [] },
        persistSaveHistorySnapshot: @escaping @Sendable (DocumentProjectPath, OpenDocumentTab, SaveHistoryTrigger) throws -> Void = { _, _, _ in },
        removeWorkspaceItem: @escaping @Sendable (DocumentProjectPath) throws -> Void = { _ in }
    ) -> Self {
        Self(
            createTabBackingStoreURL: createTabBackingStoreURL,
            createProjectURL: createProjectURL,
            writePNGToTemporaryDirectory: writePNGToTemporaryDirectory,
            timelapseTemporaryDirectory: timelapseTemporaryDirectory,
            loadSavedProjects: loadSavedProjects,
            moveSavedProject: moveSavedProject,
            loadAutosaveRecoveryItems: loadAutosaveRecoveryItems,
            discardAutosaveEntry: discardAutosaveEntry,
            discardAutosaveSnapshot: discardAutosaveSnapshot,
            persistAutosaveSnapshot: persistAutosaveSnapshot,
            persistProjectSnapshot: persistProjectSnapshot,
            loadSaveHistoryEntries: loadSaveHistoryEntries,
            persistSaveHistorySnapshot: persistSaveHistorySnapshot,
            removeWorkspaceItem: removeWorkspaceItem
        )
    }
}

extension DocumentImportClient {
    static func stub(
        stageImportedDocument: @escaping @Sendable (ImportedDocumentStageRequest) -> Result<ImportedDocumentStageResult, ImportedDocumentStageFailure> = { request in
            .success(
                ImportedDocumentStageResult(
                    stagedProjectURL: DocumentProjectPath(request.sourceURL),
                    suggestedTitle: request.sourceURL.deletingPathExtension().lastPathComponent
                )
            )
        },
        discardStagedDocument: @escaping @Sendable (DocumentProjectPath) -> Result<Void, ImportedDocumentStageFailure> = { _ in
            .success(())
        }
    ) -> Self {
        Self(
            stageImportedDocument: stageImportedDocument,
            discardStagedDocument: discardStagedDocument
        )
    }
}

extension FileClient {
    static func stub(
        temporaryDirectory: @escaping @Sendable () -> URL = {
            URL(fileURLWithPath: "/tmp")
        },
        urls: @escaping @Sendable (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask) -> [URL] = { _, _ in
            [URL(fileURLWithPath: "/tmp")]
        },
        fileExists: @escaping @Sendable (String) -> Bool = { _ in false },
        createDirectory: @escaping @Sendable (URL, Bool) throws -> Void = { _, _ in },
        removeItem: @escaping @Sendable (URL) throws -> Void = { _ in },
        copyItem: @escaping @Sendable (URL, URL) throws -> Void = { _, _ in },
        moveItem: @escaping @Sendable (URL, URL) throws -> Void = { _, _ in },
        replaceItem: @escaping @Sendable (URL, URL, String?) throws -> Void = { _, _, _ in },
        contentsOfDirectory: @escaping @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) throws -> [URL] = { _, _, _ in [] },
        enumerateURLs: @escaping @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) -> [URL] = { _, _, _ in [] },
        readData: @escaping @Sendable (URL) throws -> Data = { _ in Data() },
        writeData: @escaping @Sendable (Data, URL, Data.WritingOptions) throws -> Void = { _, _, _ in }
    ) -> Self {
        Self(
            temporaryDirectory: temporaryDirectory,
            urls: urls,
            fileExists: fileExists,
            createDirectory: createDirectory,
            removeItem: removeItem,
            copyItem: copyItem,
            moveItem: moveItem,
            replaceItem: replaceItem,
            contentsOfDirectory: contentsOfDirectory,
            enumerateURLs: enumerateURLs,
            readData: readData,
            writeData: writeData
        )
    }
}
