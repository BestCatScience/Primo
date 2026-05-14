import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication
import PrimoWorkspaceApplication
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
            opacity: UnitInterval(1.0)!,
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
            validatingCanvasSize: canvasSize,
            activeLayerIndex: activeLayerIndex,
            layerRows: resolvedLayerRows,
            layerSidebarRows: resolvedLayerRows.map { .layer($0, depth: 0) },
            renderSnapshot: renderSnapshot
        )!
    }

    static func renderedTestValue(
        width: Int = 4,
        height: Int = 4,
        activeLayerIndex: Int = 0
    ) -> Self {
        testValue(
            canvasSize: CGSize(width: width, height: height),
            activeLayerIndex: activeLayerIndex,
            renderSnapshot: MetalDocumentSnapshot.unsafeUnchecked(
                width: width,
                height: height,
                revision: 1,
                compositePixelData: Data(repeating: 0, count: width * height * 4),
                layers: [
                    MetalLayerSnapshot.unsafeUnchecked(
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

extension DocumentCompositeSurface {
    init(unsafeUncheckedWidth width: Int, height: Int, pixelData: Data) {
        self.init(validatingWidth: width, height: height, pixelData: pixelData)!
    }
}

extension MetalLayerSnapshot {
    static func unsafeUnchecked(
        index: Int,
        opacity: Float,
        visible: Bool,
        isClipped: Bool,
        blendMode: LayerBlendMode,
        thumbnailSurface: DocumentCompositeSurface? = nil,
        thumbnailData: Data?,
        gpuBufferHandle: MetalBufferHandle? = nil,
        pixelData: Data
    ) -> Self {
        Self(
            validatingIndex: index,
            opacity: opacity,
            visible: visible,
            isClipped: isClipped,
            blendMode: blendMode,
            canvasWidth: gpuBufferHandle?.width ?? max(pixelData.count / 4, 1),
            canvasHeight: gpuBufferHandle?.height ?? 1,
            thumbnailSurface: thumbnailSurface,
            thumbnailData: thumbnailData,
            gpuBufferHandle: gpuBufferHandle,
            pixelData: pixelData
        )!
    }
}

extension MetalDocumentSnapshot {
    static func unsafeUnchecked(
        width: Int,
        height: Int,
        revision: Int,
        transferKind: MetalSnapshotTransferKind = .fullSnapshot,
        compositeBufferHandle: MetalBufferHandle? = nil,
        compositePixelData: Data,
        layers: [MetalLayerSnapshot]
    ) -> Self {
        Self(
            validatingWidth: width,
            height: height,
            revision: revision,
            transferKind: transferKind,
            compositeBufferHandle: compositeBufferHandle,
            compositePixelData: compositePixelData,
            layers: layers
        )!
    }
}

extension IncrementalLayerUpdate {
    static func unsafeUnchecked(
        id: UUID = UUID(),
        layerIndex: Int,
        originX: Int,
        originY: Int,
        width: Int,
        height: Int,
        transferKind: MetalSnapshotTransferKind = .dirtyRect,
        gpuBufferHandle: MetalBufferHandle? = nil,
        pixelData: Data
    ) -> Self {
        Self(
            validatingID: id,
            layerIndex: layerIndex,
            originX: originX,
            originY: originY,
            width: width,
            height: height,
            transferKind: transferKind,
            gpuBufferHandle: gpuBufferHandle,
            pixelData: pixelData
        )!
    }
}

extension MetalBufferHandle {
    static func unsafeUnchecked(id: UUID = UUID(), width: Int, height: Int, bytesPerRow: Int) -> Self {
        Self(validatingWidth: width, height: height, bytesPerRow: bytesPerRow, id: id)!
    }
}

extension CanvasSelection {
    static func unsafeUnchecked(
        bounds: CGRect,
        maskWidth: Int,
        maskHeight: Int,
        maskData: Data,
        mode: SelectionToolMode
    ) -> Self {
        Self(
            validatingBounds: bounds,
            maskWidth: maskWidth,
            maskHeight: maskHeight,
            maskData: maskData,
            mode: mode
        )!
    }
}

extension LayerPixelRect {
    static func unsafeUnchecked(originX: Int, originY: Int, width: Int, height: Int) -> Self {
        Self(validatingOriginX: originX, originY: originY, width: width, height: height)!
    }
}

extension GpuSurfaceRegion {
    init(originX: Int, originY: Int, width: Int, height: Int) {
        self.init(validatingOriginX: originX, originY: originY, width: width, height: height)!
    }
}

extension GpuLayerSurface {
    init(layerIndex: Int, width: Int, height: Int, handle: GpuSurfaceHandle, pixelData: Data? = nil) {
        self.init(
            validatingLayerIndex: layerIndex,
            width: width,
            height: height,
            handle: handle,
            pixelData: pixelData
        )!
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
        try! Self(validating: rawValue)
    }
}

extension DocumentQueryGateway {
    static func stub(
        presentation: PaintDocumentPresentation = .testValue()
    ) -> Self {
        Self(
            lightweightPresentation: { presentation },
            presentation: { presentation }
        )
    }
}

extension DocumentRenderGateway {
    static func stub(
        compositePixelData: @escaping @Sendable () -> Data = { Data() },
        compositeSurface: @escaping @Sendable () -> DocumentCompositeSurface = {
            DocumentCompositeSurface(unsafeUncheckedWidth: 1, height: 1, pixelData: Data([0, 0, 0, 0]))
        },
        pixelDataForLayer: @escaping @Sendable (Int) -> Data = { _ in Data() }
    ) -> Self {
        Self(
            compositePixelData: compositePixelData,
            compositeSurface: compositeSurface,
            pixelDataForLayer: pixelDataForLayer
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
        cancelBlurStroke: @escaping @Sendable () -> Void = {},
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
            cancelBlurStroke: cancelBlurStroke,
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

private struct TestCanvasPreviewRenderer: CanvasPreviewRendering, SelectionMaskProcessing {
    let gateway: DocumentGpuOperationGateway

    func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        gateway.eyedropperLoupeRGBA(
            sourcePixelData,
            canvasWidth,
            canvasHeight,
            centerX,
            centerY,
            gridSize,
            paperStyle,
            blendWithPaper
        ).value.flatMap { DocumentCompositeSurface(validatingWidth: gridSize, height: gridSize, pixelData: $0) }
    }

    func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        gateway.selectionOverlayRGBA(maskData, width, height).value.flatMap {
            DocumentCompositeSurface(validatingWidth: width, height: height, pixelData: $0)
        }
    }

    func compositePreviewImageData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        gateway.compositedPreviewPixelData(snapshot, activeLayerIndex, adjustedActiveLayerPixels).value
    }

    func paperCompositeSurface(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
        gateway.compositedPaperPreviewRGBA(pixelData, width, height, paperStyle).value.flatMap {
            DocumentCompositeSurface(validatingWidth: width, height: height, pixelData: $0)
        }
    }

    func shapePreviewSurface(stroke: Stroke, style: PreviewStrokeStyle, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface? {
        nil
    }

    func transformedTextPreviewSurface(textLayer: TextLayerData, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface? {
        nil
    }

    func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? {
        nil
    }
}

private struct TestLayerTransformProcessor: LayerTransformProcessing {
    let gateway: DocumentGpuOperationGateway

    func transformedLayerPixels(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets
    ) -> Data? {
        let sourceQuad = TransformQuad(
            topLeft: .zero,
            topRight: CGPoint(x: canvasWidth, y: 0),
            bottomLeft: CGPoint(x: 0, y: canvasHeight),
            bottomRight: CGPoint(x: canvasWidth, y: canvasHeight)
        )
        let destinationQuad = quadOffsets.applying(to: sourceQuad)
        return gateway.transformedLayerPixelData(
            TransformedLayerPixelDataRequest(
                source: source,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                expandedSelectionMask: selection.map { Array($0.maskData) },
                translation: translation,
                scaleX: scaleX,
                scaleY: scaleY,
                rotationDegrees: rotationDegrees,
                pivot: pivot ?? sourceQuad.center,
                sourceQuad: sourceQuad,
                destinationQuad: destinationQuad,
                usesFreeformQuad: !quadOffsets.isZero
            )
        ).value
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
        nil
    }

    func transformationBounds(
        selection: CanvasSelection?,
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect? {
        nil
    }
}

extension DocumentRuntime {
    static func stub(
        queryGateway: DocumentQueryGateway = .stub(),
        renderGateway: DocumentRenderGateway = .stub(),
        mutationGateway: DocumentMutationGateway = .stub(),
        strokeGateway: StrokeInputGateway = .stub(),
        historyGateway: DocumentHistoryGateway = .stub(),
        persistenceGateway: DocumentPersistenceGateway = .stub(),
        exportGateway: DocumentExportGateway = .stub(),
        documentTextLayerService: TextLayerGateway = .stub(),
        layerEffectsGateway: DocumentLayerEffectsGateway = .stub(),
        editingGateway: DocumentEditingGateway? = nil,
        strokeSessionUseCase: DocumentStrokeSessionUseCase? = nil,
        gpuOperationGateway: DocumentGpuOperationGateway = .stub(),
        canvasPreviewRenderer: (any CanvasPreviewRendering)? = nil,
        layerTransformProcessor: (any LayerTransformProcessing)? = nil,
        selectionMaskProcessor: (any SelectionMaskProcessing)? = nil
    ) -> Self {
        let resolvedEditingGateway = editingGateway ?? DocumentEditingGateway.stub()
        let canvasCommands = DocumentCanvasCommandService(
            queryGateway: queryGateway,
            renderGateway: renderGateway,
            mutationGateway: mutationGateway,
            persistenceGateway: persistenceGateway
        )
        let layerCommands = DocumentLayerCommandService(mutationGateway: mutationGateway)
        let strokeCommands = DocumentStrokeCommandService(strokeGateway: strokeGateway)
        let canvasStrokeInteractionService = CanvasStrokeInteractionService(
            sessionUseCase: strokeSessionUseCase ?? .stub()
        )
        let historyCommands = DocumentHistoryCommandService(historyGateway: historyGateway)
        let mutationWorkflow = DocumentMutationWorkflowService(
            documentEditingGateway: resolvedEditingGateway,
            documentLayerEffectsGateway: layerEffectsGateway,
            documentMutationGateway: mutationGateway,
            textLayerGateway: documentTextLayerService
        )
        let contentService = DocumentContentService(
            documentQueryGateway: queryGateway,
            documentRenderGateway: renderGateway,
            documentMutationGateway: mutationGateway,
            textLayerGateway: documentTextLayerService
        )
        let defaultCanvasPreviewRenderer = TestCanvasPreviewRenderer(gateway: gpuOperationGateway)
        let canvasPreviewRenderer = canvasPreviewRenderer ?? defaultCanvasPreviewRenderer
        let layerTransformProcessor = layerTransformProcessor ?? TestLayerTransformProcessor(gateway: gpuOperationGateway)
        let selectionMaskProcessor = selectionMaskProcessor ?? defaultCanvasPreviewRenderer
        let canvasEditingWorkflow = CanvasEditingWorkflowService(
            documentContentService: contentService,
            layerTransformProcessor: layerTransformProcessor
        )
        let selectionWorkflow = SelectionWorkflowService(operations: gpuOperationGateway.selectionMaskOperations)
        let canvasPresentationEnvironment = CanvasPresentationEnvironment(
            previewRenderer: canvasPreviewRenderer,
            eyedropperSampler: GpuCanvasEyedropperSampler(),
            selectionProcessor: selectionMaskProcessor
        )
        return Self(
            execute: { command in
                switch command {
                case let .presentation(request):
                    switch request {
                    case .lightweight:
                        return .presentation(queryGateway.lightweightPresentation())
                    case .full, .current:
                        return .presentation(queryGateway.presentation())
                    }
                case let .canvas(command):
                    switch command {
                    case let .create(width, height):
                        return .mutation(canvasCommands.createCanvas(width, height).map { .completed })
                    case let .resize(width, height):
                        return .mutation(canvasCommands.resizeCanvas(width, height).map { .completed })
                    case let .resizeExtent(width, height):
                        return .mutation(canvasCommands.resizeCanvasExtent(width, height).map { .completed })
                    case let .initializeImported(request, layerName):
                        return .mutation(canvasCommands.initializeImportedCanvas(request, layerName).map { .completed })
                    case .compositeSurface:
                        return .compositeSurface(canvasCommands.compositeSurface())
                    case let .setPaperStyle(style):
                        persistenceGateway.setPaperStyle(style)
                        return .none
                    }
                case let .layer(command):
                    switch command {
                    case let .edit(request):
                        return .mutation(resolvedEditingGateway.execute(request).map { _ in .completed })
                    case let .mergeLayerDown(index):
                        return .mutation(layerEffectsGateway.mergeLayerDown(index).map { .completed })
                    case let .setTextLayer(index, textLayer):
                        return .mutation(documentTextLayerService.setTextLayer(index, textLayer).map { .completed })
                    case .applyProcessing:
                        return .mutation(.success(.completed))
                    }
                case let .stroke(command):
                    switch command {
                    case let .begin(sample, settings):
                        strokeGateway.beginStroke(sample, settings)
                        return .none
                    case let .append(sample):
                        strokeGateway.appendStroke(sample)
                        return .none
                    case .end:
                        return .mutation(strokeGateway.endStroke().map { .completed })
                    case .cancel:
                        strokeGateway.cancelStroke()
                        return .none
                    case let .fill(sample, settings):
                        return .mutation(strokeGateway.fill(sample, settings).map { .completed })
                    }
                case let .history(command):
                    switch command {
                    case .state:
                        return .history(
                            DocumentHistoryState(
                                canUndo: historyGateway.canUndo(),
                                canRedo: historyGateway.canRedo()
                            )
                        )
                    case .undo:
                        return .mutation(historyGateway.undo().map { .completed })
                    case .redo:
                        return .mutation(historyGateway.redo().map { .completed })
                    }
                }
            },
            observePresentation: {
                AsyncStream { continuation in
                    continuation.yield(queryGateway.lightweightPresentation())
                    continuation.finish()
                }
            },
            canvasCommands: canvasCommands,
            layerCommands: layerCommands,
            strokeCommands: strokeCommands,
            canvasStrokeInteractionService: canvasStrokeInteractionService,
            historyCommands: historyCommands,
            mutationWorkflow: mutationWorkflow,
            contentService: contentService,
            canvasEditingWorkflow: canvasEditingWorkflow,
            selectionWorkflow: selectionWorkflow,
            canvasPreviewRenderer: canvasPreviewRenderer,
            layerTransformProcessor: layerTransformProcessor,
            selectionMaskProcessor: selectionMaskProcessor,
            canvasPresentationEnvironment: canvasPresentationEnvironment,
            presentationReader: DocumentPresentationReader(
                lightweightPresentation: queryGateway.lightweightPresentation,
                presentation: queryGateway.presentation
            ),
            renderingWorkflow: DocumentRenderingWorkflow(operations: gpuOperationGateway.renderingOperations),
            textLayerService: DocumentTextLayerService(
                textLayerData: documentTextLayerService.textLayerData,
                setTextLayer: documentTextLayerService.setTextLayer,
                clearTextLayerData: documentTextLayerService.clearTextLayerData
            ),
            exportClient: DocumentExportClient(
                compositeSurface: exportGateway.compositeSurface,
                compositePNGData: exportGateway.compositePNGData,
                timelapseCapture: exportGateway.timelapseCapture
            ),
            persistenceClient: DocumentPersistenceClient(
                saveProject: persistenceGateway.saveProject,
                loadProject: persistenceGateway.loadProject,
                setPaperStyle: persistenceGateway.setPaperStyle,
                newCanvas: persistenceGateway.newCanvas,
                prewarmDrawingResources: persistenceGateway.prewarmDrawingResources
            )
        )
    }
}

extension DocumentGpuOperationGateway {
    static func stub(
        compositedPaperPreviewRGBA: @escaping @Sendable (Data, Int, Int, CanvasPaperStyle) -> Data? = { _, _, _, _ in nil },
        compositedPreviewPixelData: @escaping @Sendable (MetalDocumentSnapshot, Int, Data) -> Data? = { _, _, _ in nil },
        compositedPreviewIncrementalUpdate: @escaping @Sendable (MetalDocumentSnapshot, Int, Data, LayerPixelRect) -> IncrementalLayerUpdate? = { _, _, _, _ in nil },
        selectionOverlayRGBA: @escaping @Sendable (Data, Int, Int) -> Data? = { _, _, _ in nil },
        eyedropperLoupeRGBA: @escaping @Sendable (Data, Int, Int, Int, Int, Int, CanvasPaperStyle, Bool) -> Data? = { _, _, _, _, _, _, _, _ in nil },
        shapePreviewSurface: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Int) -> DocumentCompositeSurface? = { _, _, _, _ in nil },
        textLayerSurface: @escaping @Sendable (TextLayerData, CGSize) -> DocumentCompositeSurface? = { _, _ in nil },
        textLayoutRect: @escaping @Sendable (TextLayerData, CGSize) -> CGRect? = { _, _ in nil },
        processedLayerPixelData: @escaping @Sendable (Data, Int, Int, LayerProcessingRequest) -> Data? = { _, _, _, _ in nil },
        alphaMask: @escaping @Sendable (Data, Int, Int) -> [UInt8]? = { _, _, _ in nil },
        croppedSelectionMask: @escaping @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask? = { _, _, _ in nil },
        combinedSelectionMask: @escaping @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> [UInt8]? = { _, _, _, _, _ in nil },
        expandedSelectionMask: @escaping @Sendable (ExpandedSelectionMaskRequest) -> [UInt8]? = { _ in nil },
        lassoSelection: @escaping @Sendable ([CGPoint], Int, Int) -> [UInt8]? = { _, _, _ in nil },
        autoSelection: @escaping @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> [UInt8]? = { _, _, _, _, _, _, _, _, _ in nil },
        colorRangeSelection: @escaping @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> [UInt8]? = { _, _, _, _ in nil },
        expandedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> [UInt8]? = { _, _, _, _ in nil },
        contractedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> [UInt8]? = { _, _, _, _ in nil },
        featheredMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> [UInt8]? = { _, _, _, _ in nil },
        invertMask: @escaping @Sendable ([UInt8]) -> [UInt8]? = { _ in nil },
        transformedSelectionMask: @escaping @Sendable (TransformedSelectionMaskRequest) -> [UInt8]? = { _ in nil },
        transformedLayerPixelData: @escaping @Sendable (TransformedLayerPixelDataRequest) -> Data? = { _ in nil },
        scaledPixelData: @escaping @Sendable (Data, Int, Int, Int, Int) -> Data? = { _, _, _, _, _ in nil },
        translatedPixelData: @escaping @Sendable (Data, Int, Int, Int, Int, Int, Int) -> Data? = { _, _, _, _, _, _, _ in nil },
        releaseSurfaceHandle: @escaping @Sendable (MetalBufferHandle?) -> Void = { _ in }
    ) -> Self {
        Self(
            compositedPaperPreviewRGBA: { pixelData, width, height, paperStyle in
                stubRenderingResult(compositedPaperPreviewRGBA(pixelData, width, height, paperStyle))
            },
            compositedPreviewPixelData: { snapshot, activeLayerIndex, adjustedActiveLayerPixels in
                stubRenderingResult(compositedPreviewPixelData(snapshot, activeLayerIndex, adjustedActiveLayerPixels))
            },
            compositedPreviewIncrementalUpdate: { snapshot, activeLayerIndex, adjustedActiveLayerPixels, dirtyRect in
                stubRenderingResult(compositedPreviewIncrementalUpdate(snapshot, activeLayerIndex, adjustedActiveLayerPixels, dirtyRect))
            },
            selectionOverlayRGBA: { maskData, width, height in
                stubRenderingResult(selectionOverlayRGBA(maskData, width, height))
            },
            eyedropperLoupeRGBA: { sourcePixelData, canvasWidth, canvasHeight, centerX, centerY, gridSize, paperStyle, blendWithPaper in
                stubRenderingResult(
                    eyedropperLoupeRGBA(
                        sourcePixelData,
                        canvasWidth,
                        canvasHeight,
                        centerX,
                        centerY,
                        gridSize,
                        paperStyle,
                        blendWithPaper
                    )
                )
            },
            shapePreviewSurface: { samples, brush, canvasWidth, canvasHeight in
                stubRenderingResult(shapePreviewSurface(samples, brush, canvasWidth, canvasHeight))
            },
            textLayerSurface: { textLayer, canvasSize in
                stubRenderingResult(textLayerSurface(textLayer, canvasSize))
            },
            textLayoutRect: textLayoutRect,
            processedLayerPixelData: { pixelData, width, height, request in
                stubRenderingResult(processedLayerPixelData(pixelData, width, height, request))
            },
            alphaMask: { pixelData, width, height in
                stubRenderingResult(alphaMask(pixelData, width, height))
            },
            croppedSelectionMask: croppedSelectionMask,
            combinedSelectionMask: { base, incoming, mode, width, height in
                stubRenderingResult(combinedSelectionMask(base, incoming, mode, width, height))
            },
            expandedSelectionMask: { request in
                stubRenderingResult(expandedSelectionMask(request))
            },
            lassoSelection: { points, width, height in
                stubRenderingResult(lassoSelection(points, width, height))
            },
            autoSelection: { pixelData, width, height, seedX, seedY, thresholdMode, opacityTolerance, colorTolerance, expansion in
                stubRenderingResult(
                    autoSelection(
                        pixelData,
                        width,
                        height,
                        seedX,
                        seedY,
                        thresholdMode,
                        opacityTolerance,
                        colorTolerance,
                        expansion
                    )
                )
            },
            colorRangeSelection: { pixelData, width, height, request in
                stubRenderingResult(colorRangeSelection(pixelData, width, height, request))
            },
            expandedMask: { mask, width, height, expansion in
                stubRenderingResult(expandedMask(mask, width, height, expansion))
            },
            contractedMask: { mask, width, height, contraction in
                stubRenderingResult(contractedMask(mask, width, height, contraction))
            },
            featheredMask: { mask, width, height, radius in
                stubRenderingResult(featheredMask(mask, width, height, radius))
            },
            invertMask: { mask in
                stubRenderingResult(invertMask(mask))
            },
            transformedSelectionMask: { request in
                stubRenderingResult(transformedSelectionMask(request))
            },
            transformedLayerPixelData: { request in
                stubRenderingResult(transformedLayerPixelData(request))
            },
            scaledPixelData: { source, sourceWidth, sourceHeight, targetWidth, targetHeight in
                stubRenderingResult(scaledPixelData(source, sourceWidth, sourceHeight, targetWidth, targetHeight))
            },
            translatedPixelData: { source, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY in
                stubRenderingResult(
                    translatedPixelData(source, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY)
                )
            },
            releaseSurfaceHandle: releaseSurfaceHandle
        )
    }

    private static func stubRenderingResult<Value>(_ value: Value?) -> DocumentRenderingResult<Value> {
        value.map(DocumentRenderingResult.success) ?? .failure(.kernelFailed(operation: "stub"))
    }
}

extension DocumentRenderingWorkflow {
    static func stub(
        compositedPaperPreviewRGBA: @escaping @Sendable (Data, Int, Int, CanvasPaperStyle) -> Data? = { _, _, _, _ in nil },
        compositedPreviewPixelData: @escaping @Sendable (MetalDocumentSnapshot, Int, Data) -> Data? = { _, _, _ in nil },
        processedLayerPixelData: @escaping @Sendable (Data, Int, Int, LayerProcessingRequest) -> Data? = { _, _, _, _ in nil },
        alphaMask: @escaping @Sendable (Data, Int, Int) -> [UInt8]? = { _, _, _ in nil },
        croppedSelectionMask: @escaping @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask? = { _, _, _ in nil },
        scaledPixelData: @escaping @Sendable (Data, Int, Int, Int, Int) -> Data? = { _, _, _, _, _ in nil },
        translatedPixelData: @escaping @Sendable (Data, Int, Int, Int, Int, Int, Int) -> Data? = { _, _, _, _, _, _, _ in nil }
    ) -> Self {
        Self(
            compositedPaperPreviewRGBA: { pixelData, width, height, paperStyle in
                stubRenderingResult(compositedPaperPreviewRGBA(pixelData, width, height, paperStyle))
            },
            compositedPreviewPixelData: { snapshot, activeLayerIndex, adjustedActiveLayerPixels in
                stubRenderingResult(compositedPreviewPixelData(snapshot, activeLayerIndex, adjustedActiveLayerPixels))
            },
            processedLayerPixelData: { pixelData, width, height, request in
                stubRenderingResult(processedLayerPixelData(pixelData, width, height, request))
            },
            alphaMask: { pixelData, width, height in
                stubRenderingResult(alphaMask(pixelData, width, height))
            },
            croppedSelectionMask: croppedSelectionMask,
            scaledPixelData: { source, sourceWidth, sourceHeight, targetWidth, targetHeight in
                stubRenderingResult(scaledPixelData(source, sourceWidth, sourceHeight, targetWidth, targetHeight))
            },
            translatedPixelData: { source, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY in
                stubRenderingResult(translatedPixelData(source, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY))
            }
        )
    }

    private static func stubRenderingResult<Value>(_ value: Value?) -> DocumentRenderingResult<Value> {
        value.map(DocumentRenderingResult.success) ?? .failure(.kernelFailed(operation: "stub"))
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

extension WorkspaceApplicationCapability {
    static func stub(
        documentPersistenceGateway: DocumentPersistenceGateway = .stub(),
        documentWorkspaceClient: DocumentWorkspaceClient = .stub(),
        uuidClient: UUIDClient = UUIDClient(generate: {
            UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!
        })
    ) -> Self {
        WorkspaceApplicationCapability(
            services: WorkspaceApplicationServices(
                documentPersistenceGateway: documentPersistenceGateway,
                documentWorkspaceClient: documentWorkspaceClient,
                uuidClient: uuidClient
            )
        )
    }
}

extension WorkspaceArtifactCapability {
    static func stub(
        writePNGToTemporaryDirectory: @escaping @Sendable (Data) throws -> URL = { _ in
            URL(fileURLWithPath: "/tmp/export.png")
        },
        timelapseTemporaryDirectory: @escaping @Sendable () -> URL = {
            URL(fileURLWithPath: "/tmp")
        }
    ) -> Self {
        Self(
            writePNGToTemporaryDirectory: writePNGToTemporaryDirectory,
            timelapseTemporaryDirectory: timelapseTemporaryDirectory
        )
    }
}

extension TimelapseExportCapability {
    static func stub(
        exportVideo: @escaping @Sendable (
            TimelapseCapture,
            @escaping @Sendable (TimelapseExportProgress) -> Void
        ) throws -> TimelapseExportResult = { _, _ in
            TimelapseExportResult(url: URL(fileURLWithPath: "/tmp/timelapse.mov"))
        }
    ) -> Self {
        Self(exportVideo: exportVideo)
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
