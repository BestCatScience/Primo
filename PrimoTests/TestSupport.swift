import ComposableArchitecture
import CoreGraphics
import Foundation
@testable import Primo

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
        layerRows: [LayerRowModel]? = nil
    ) -> Self {
        let resolvedLayerRows = layerRows ?? [LayerRowModel.testValue(index: activeLayerIndex)]
        return Self(
            canvasSize: canvasSize,
            activeLayerIndex: activeLayerIndex,
            layerRows: resolvedLayerRows,
            layerSidebarRows: resolvedLayerRows.map { .layer($0, depth: 0) },
            renderSnapshot: nil
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
        .unchecked(rawValue)
    }
}

extension PaintDocumentClient {
    static func stub(
        presentation: PaintDocumentPresentation = .testValue(),
        compositePNGData: @escaping @Sendable (CanvasPaperStyle) -> Data? = { _ in nil },
        saveProject: @escaping @Sendable (URL, CanvasPaperStyle) throws -> Void = { _, _ in },
        loadProject: @escaping @Sendable (URL) throws -> LoadedPaintProject = { _ in .testValue() },
        addLayer: @escaping @Sendable (String) -> DocumentIndexedMutationResult = { _ in .success(0) },
        deleteLayer: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .success(()) },
        setActiveLayer: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .success(()) },
        setLayerVisibility: @escaping @Sendable (Int, Bool) -> DocumentMutationResult = { _, _ in .success(()) },
        setTextLayer: @escaping @Sendable (Int, TextLayerData) -> DocumentMutationResult = { _, _ in .success(()) },
        replaceLayerPixels: @escaping @Sendable (Int, Data) -> DocumentMutationResult = { _, _ in .success(()) },
        applySoftwareStroke: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult = { _, _, _ in .success(()) },
        revealLayerForEditing: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .success(()) },
        blurStroke: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult = { _, _, _, _ in .success(()) },
        fill: @escaping @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult = { _, _ in .success(()) }
    ) -> Self {
        Self(
            lightweightPresentation: { presentation },
            presentation: { presentation },
            compositePixelData: { Data() },
            prewarmDrawingResources: {},
            compositePNGData: compositePNGData,
            timelapseCapture: { nil },
            saveProject: saveProject,
            loadProject: loadProject,
            setPaperStyle: { _ in },
            newCanvas: { _, _ in },
            resizeCanvas: { _, _ in .success(()) },
            resizeCanvasExtent: { _, _ in .success(()) },
            beginStroke: { _, _ in },
            appendStroke: { _ in },
            endStroke: {},
            cancelStroke: {},
            blurStroke: blurStroke,
            endBlurStroke: {},
            fill: fill,
            canUndo: { true },
            canRedo: { true },
            undo: { .success(()) },
            redo: { .success(()) },
            addLayer: addLayer,
            duplicateLayer: { _, _ in .success(0) },
            deleteLayer: deleteLayer,
            moveLayer: { _, _ in .success(()) },
            createFolder: { _, _ in .success(0) },
            deleteFolder: { _ in .success(()) },
            setFolderVisibility: { _, _ in .success(()) },
            setFolderName: { _, _ in .success(()) },
            setFolderExpanded: { _, _ in .success(()) },
            assignLayerToFolder: { _, _ in .success(()) },
            setActiveLayer: setActiveLayer,
            setLayerName: { _, _ in .success(()) },
            setLayerVisibility: setLayerVisibility,
            setLayerLocked: { _, _ in .success(()) },
            setLayerAlphaLocked: { _, _ in .success(()) },
            setLayerClipped: { _, _ in .success(()) },
            revealLayerForEditing: revealLayerForEditing,
            setLayerOpacity: { _, _ in .success(()) },
            setLayerBlendMode: { _, _ in .success(()) },
            mergeLayerDown: { _ in .success(()) },
            textLayerData: { _ in nil },
            setTextLayer: setTextLayer,
            clearTextLayerData: { _ in },
            applyLayerProcessing: { _, _ in .success(()) },
            applySoftwareStroke: applySoftwareStroke,
            pixelDataForLayer: { _ in Data() },
            replaceLayerPixels: replaceLayerPixels,
            replaceLayerMask: { _, _ in .success(()) },
            clearLayerMask: { _ in .success(()) },
            applyLayerMask: { _ in .success(()) },
            clearLayer: { _ in .success(()) },
            consumeDirtyUpdate: { nil }
        )
    }
}

extension DocumentQueryGateway {
    static func stub(
        presentation: PaintDocumentPresentation = .testValue(),
        compositePixelData: @escaping @Sendable () -> Data = { Data() },
        pixelDataForLayer: @escaping @Sendable (Int) -> Data = { _ in Data() }
    ) -> Self {
        Self(
            lightweightPresentation: { presentation },
            presentation: { presentation },
            compositePixelData: compositePixelData,
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
        applySoftwareStroke: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult = { _, _, _ in .success(()) }
    ) -> Self {
        Self(
            beginStroke: { _, _ in },
            appendStroke: { _ in },
            endStroke: {},
            cancelStroke: {},
            blurStroke: blurStroke,
            endBlurStroke: {},
            fill: fill,
            applySoftwareStroke: applySoftwareStroke
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
        compositePNGData: @escaping @Sendable (CanvasPaperStyle) -> Data? = { _ in nil },
        timelapseCapture: @escaping @Sendable () -> TimelapseCapture? = { nil }
    ) -> Self {
        Self(
            compositePNGData: compositePNGData,
            timelapseCapture: timelapseCapture
        )
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
