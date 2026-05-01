import CoreGraphics
import Foundation
import os
import PrimoCoreTypes
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentInfrastructure

public struct DocumentEngineLive: Sendable {
    public let queryGateway: DocumentQueryGateway
    public let mutationGateway: DocumentMutationGateway
    public let strokeGateway: StrokeInputGateway
    public let historyGateway: DocumentHistoryGateway
    public let persistenceGateway: DocumentPersistenceGateway
    public let exportGateway: DocumentExportGateway
    public let textLayerGateway: TextLayerGateway

    public let duplicateLayer: @Sendable (Int, String) -> DocumentIndexedMutationResult
    public let moveLayer: @Sendable (Int, Int) -> DocumentMutationResult
    public let createFolder: @Sendable (String, Int) -> DocumentIndexedMutationResult
    public let deleteFolder: @Sendable (Int) -> DocumentMutationResult
    public let setFolderVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    public let setFolderName: @Sendable (Int, String) -> DocumentMutationResult
    public let setFolderExpanded: @Sendable (Int, Bool) -> DocumentMutationResult
    public let assignLayerToFolder: @Sendable (Int, Int) -> DocumentMutationResult
    public let setLayerLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    public let setLayerAlphaLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    public let setLayerClipped: @Sendable (Int, Bool) -> DocumentMutationResult
    public let setLayerOpacity: @Sendable (Int, Double) -> DocumentMutationResult
    public let setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> DocumentMutationResult
    public let mergeLayerDown: @Sendable (Int) -> DocumentMutationResult
}

public enum DocumentEngineFactory {
    private static let logger = Logger(subsystem: "com.primo.app", category: "DocumentEngineFactory")

    public static func live(
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live
    ) -> DocumentEngineLive {
        live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient,
            gpuServices: DocumentRuntimeGpuServicesFactory.live()
        )
    }

    static func live(
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live,
        gpuServices: DocumentRuntimeGpuServices
    ) -> DocumentEngineLive {
        let runtimeBox = LockedDocumentRuntimeBox(
            runtime: SwiftDocumentRuntime(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient,
                gpuServices: gpuServices
            )
        )

        let queryGateway = DocumentQueryGateway(
            lightweightPresentation: { runtimeBox.withRuntime { $0.lightweightPresentation() } },
            presentation: { runtimeBox.withRuntime { $0.presentation() } },
            compositePixelData: {
                let snapshot = runtimeBox.withRuntime { $0.materializedSnapshot() }
                return SwiftDocumentRuntime.compositeSurface(
                    forMaterializedSnapshot: snapshot,
                    gpuServices: gpuServices
                ).pixelData
            },
            compositeSurface: {
                let snapshot = runtimeBox.withRuntime { $0.materializedSnapshot() }
                return SwiftDocumentRuntime.compositeSurface(
                    forMaterializedSnapshot: snapshot,
                    gpuServices: gpuServices
                )
            },
            pixelDataForLayer: { index in runtimeBox.withRuntime { $0.pixelDataForLayer(index: index) } },
            consumeDirtyUpdate: { runtimeBox.withRuntime { $0.consumeDirtyUpdate() } }
        )

        let mutationGateway = DocumentMutationGateway(
            resizeCanvas: { width, height in
                performResizeCanvas(width: width, height: height, runtimeBox: runtimeBox)
            },
            resizeCanvasExtent: { width, height in
                performResizeCanvasExtent(width: width, height: height, runtimeBox: runtimeBox)
            },
            addLayer: { name in runtimeBox.withRuntime { $0.addLayer(name: name) } },
            deleteLayer: { index in runtimeBox.withRuntime { $0.deleteLayer(index: index) } },
            setActiveLayer: { index in runtimeBox.withRuntime { $0.setActiveLayer(index: index) } },
            setLayerName: { index, name in runtimeBox.withRuntime { $0.setLayerName(index: index, name: name) } },
            setLayerVisibility: { index, isVisible in
                runtimeBox.withRuntime { $0.setLayerVisibility(index: index, isVisible: isVisible) }
            },
            revealLayerForEditing: { index in runtimeBox.withRuntime { $0.revealLayerForEditing(index: index) } },
            replaceLayerPixels: { index, data in runtimeBox.withRuntime { $0.replaceLayerPixels(index: index, data: data) } },
            replaceLayerPixelsInRect: { index, rect, data in
                runtimeBox.withRuntime { $0.replaceLayerPixels(index: index, in: rect, data: data) }
            },
            applyLayerSurfaceMutation: { index, payload in
                runtimeBox.withRuntime { $0.applyLayerSurfaceMutation(index: index, payload: payload) }
            },
            applyLayerMutation: { index, payload in
                runtimeBox.withRuntime { $0.applyLayerMutation(index: index, payload: payload) }
            },
            applyTextLayerMutation: { index, textLayer, payload in
                runtimeBox.withRuntime { $0.applyTextLayerMutation(index: index, textLayer: textLayer, payload: payload) }
            },
            replaceLayerMask: { index, data in runtimeBox.withRuntime { $0.replaceLayerMask(index: index, data: data) } },
            clearLayerMask: { index in runtimeBox.withRuntime { $0.clearLayerMask(index: index) } },
            applyLayerMask: { index in runtimeBox.withRuntime { $0.applyLayerMask(index: index) } },
            clearLayer: { index in runtimeBox.withRuntime { $0.clearLayer(index: index) } },
            applyLayerProcessing: { index, request in
                performLayerProcessing(index: index, request: request, runtimeBox: runtimeBox)
            }
        )

        let strokeGateway = StrokeInputGateway(
            beginStroke: { sample, brush in runtimeBox.withRuntime { $0.beginStroke(sample: sample, brush: brush) } },
            appendStroke: { sample in runtimeBox.withRuntime { $0.appendStroke(sample: sample) } },
            endStroke: {
                performCurrentStrokeCommit(runtimeBox: runtimeBox)
            },
            cancelStroke: { runtimeBox.withRuntime { $0.cancelStroke() } },
            blurStroke: { samples, brush, layerIndex, captureTimelapse in
                performBlur(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse, runtimeBox: runtimeBox)
            },
            endBlurStroke: { runtimeBox.withRuntime { $0.endBlurStroke() } },
            cancelBlurStroke: { runtimeBox.withRuntime { $0.cancelBlurStroke() } },
            fill: { sample, brush in
                performFill(sample: sample, brush: brush, runtimeBox: runtimeBox)
            },
            applyGpuStrokeSurface: { samples, brush, layerIndex in
                performStrokeCommit(samples: samples, brush: brush, layerIndex: layerIndex, runtimeBox: runtimeBox)
            }
        )

        let historyGateway = DocumentHistoryGateway(
            canUndo: { runtimeBox.withRuntime { $0.canUndo() } },
            canRedo: { runtimeBox.withRuntime { $0.canRedo() } },
            undo: { runtimeBox.withRuntime { $0.undo() } },
            redo: { runtimeBox.withRuntime { $0.redo() } },
            trimForMemoryPressure: { runtimeBox.withRuntime { $0.trimUndoHistoryForMemoryPressure() } }
        )

        let persistenceGateway = DocumentPersistenceGateway(
            saveProject: { url, paperStyle in
                let snapshot = runtimeBox.withRuntime { $0.projectSaveSnapshot(paperStyle: paperStyle) }
                try snapshot.write(to: url, fileClient: fileClient, uuidClient: uuidClient)
            },
            loadProject: { url in
                let runtime = try SwiftDocumentRuntime.loadProject(
                    from: url,
                    fileClient: fileClient,
                    dateClient: dateClient,
                    uuidClient: uuidClient,
                    gpuServices: gpuServices
                )
                let loadedProject = LoadedPaintProject(
                    presentation: runtime.presentation(),
                    paperStyle: runtime.currentPaperStyle
                )
                runtimeBox.replaceRuntime(with: runtime)
                return loadedProject
            },
            setPaperStyle: { style in runtimeBox.withRuntime { $0.setPaperStyle(style) } },
            newCanvas: { width, height in
                runtimeBox.replaceRuntime(
                    with: SwiftDocumentRuntime(
                        width: width,
                        height: height,
                        fileClient: fileClient,
                        dateClient: dateClient,
                        uuidClient: uuidClient,
                        gpuServices: gpuServices
                    )
                )
            },
            prewarmDrawingResources: {
                let snapshot = runtimeBox.withRuntime { $0.materializedSnapshot() }
                _ = SwiftDocumentRuntime.compositeSurface(
                    forMaterializedSnapshot: snapshot,
                    gpuServices: gpuServices
                )
            }
        )

        let exportGateway = DocumentExportGateway(
            compositeSurface: { style in
                let snapshot = runtimeBox.withRuntime { $0.materializedSnapshot() }
                return SwiftDocumentRuntime.compositeExportSurface(
                    forMaterializedSnapshot: snapshot,
                    paperStyle: style,
                    gpuServices: gpuServices
                )
            },
            compositePNGData: { style in
                let snapshot = runtimeBox.withRuntime { $0.materializedSnapshot() }
                return SwiftDocumentRuntime.compositePNGData(
                    forMaterializedSnapshot: snapshot,
                    paperStyle: style,
                    gpuServices: gpuServices
                )
            },
            timelapseCapture: { runtimeBox.withRuntime { $0.timelapseCapture() } }
        )

        let textLayerGateway = TextLayerGateway(
            textLayerData: { index in runtimeBox.withRuntime { $0.textLayerData(index: index) } },
            setTextLayer: { index, textLayer in
                runtimeBox.withRuntime { $0.setTextLayer(index: index, textLayer: textLayer) }
            },
            clearTextLayerData: { index in runtimeBox.withRuntime { $0.clearTextLayerData(index: index) } }
        )

        return DocumentEngineLive(
            queryGateway: queryGateway,
            mutationGateway: mutationGateway,
            strokeGateway: strokeGateway,
            historyGateway: historyGateway,
            persistenceGateway: persistenceGateway,
            exportGateway: exportGateway,
            textLayerGateway: textLayerGateway,
            duplicateLayer: { index, name in runtimeBox.withRuntime { $0.duplicateLayer(index: index, name: name) } },
            moveLayer: { index, destination in runtimeBox.withRuntime { $0.moveLayer(from: index, to: destination) } },
            createFolder: { name, layerIndex in runtimeBox.withRuntime { $0.createFolder(name: name, layerIndex: layerIndex) } },
            deleteFolder: { folderID in runtimeBox.withRuntime { $0.deleteFolder(folderID: folderID) } },
            setFolderVisibility: { folderID, isVisible in
                runtimeBox.withRuntime { $0.setFolderVisibility(folderID: folderID, isVisible: isVisible) }
            },
            setFolderName: { folderID, name in runtimeBox.withRuntime { $0.setFolderName(folderID: folderID, name: name) } },
            setFolderExpanded: { folderID, isExpanded in
                runtimeBox.withRuntime { $0.setFolderExpanded(folderID: folderID, isExpanded: isExpanded) }
            },
            assignLayerToFolder: { index, folderID in
                runtimeBox.withRuntime { $0.assignLayerToFolder(index: index, folderID: folderID) }
            },
            setLayerLocked: { index, isLocked in
                runtimeBox.withRuntime { $0.setLayerLocked(index: index, isLocked: isLocked) }
            },
            setLayerAlphaLocked: { index, isAlphaLocked in
                runtimeBox.withRuntime { $0.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked) }
            },
            setLayerClipped: { index, isClipped in
                runtimeBox.withRuntime { $0.setLayerClipped(index: index, isClipped: isClipped) }
            },
            setLayerOpacity: { index, opacity in
                runtimeBox.withRuntime { $0.setLayerOpacity(index: index, opacity: opacity) }
            },
            setLayerBlendMode: { index, blendMode in
                runtimeBox.withRuntime { $0.setLayerBlendMode(index: index, blendMode: blendMode) }
            },
            mergeLayerDown: { index in runtimeBox.withRuntime { $0.mergeLayerDown(index: index) } }
        )
    }

    private static func performResizeCanvas(
        width: Int,
        height: Int,
        runtimeBox: LockedDocumentRuntimeBox<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeBox.withRuntime { $0.makeResizeCanvasPlan(width: width, height: height) }
        switch planResult {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let plan else { return .success(()) }
            guard let layers = plan.resizedLayers() else {
                return .failure(.gpu(.kernelFailed(operation: "resizeCanvas")))
            }
            return runtimeBox.withRuntime { $0.applyResizeCanvasPlan(plan, layers: layers) }
        }
    }

    private static func performResizeCanvasExtent(
        width: Int,
        height: Int,
        runtimeBox: LockedDocumentRuntimeBox<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeBox.withRuntime { $0.makeResizeCanvasExtentPlan(width: width, height: height) }
        switch planResult {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let plan else { return .success(()) }
            guard let layers = plan.resizedLayers() else {
                return .failure(.gpu(.kernelFailed(operation: "resizeCanvasExtent")))
            }
            return runtimeBox.withRuntime { $0.applyResizeCanvasPlan(plan, layers: layers) }
        }
    }

    private static func performLayerProcessing(
        index: Int,
        request: LayerProcessingRequest,
        runtimeBox: LockedDocumentRuntimeBox<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeBox.withRuntime { $0.makeLayerProcessingPlan(index: index, request: request) }
        switch planResult {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let payload = plan.gpuServices.processLayer(
                pixelData: plan.pixelData,
                canvasWidth: plan.canvasWidth,
                canvasHeight: plan.canvasHeight,
                request: plan.request
            ) else {
                return .failure(.gpu(.kernelFailed(operation: "applyLayerProcessing")))
            }
            return runtimeBox.withRuntime { $0.applyLayerProcessingPlan(plan, payload: payload) }
        }
    }

    private static func performFill(
        sample: StylusSample,
        brush: BrushRuntimeSettings,
        runtimeBox: LockedDocumentRuntimeBox<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeBox.withRuntime { $0.makeFillPlan(sample: sample, brush: brush) }
        switch planResult {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let payload = plan.gpuServices.fillPixels(
                pixelData: plan.pixelData,
                sourceBufferHandle: plan.sourceBufferHandle,
                canvasWidth: plan.canvasWidth,
                canvasHeight: plan.canvasHeight,
                sample: plan.sample,
                brush: plan.brush
            ) else {
                return .failure(.gpu(.kernelFailed(operation: "fill")))
            }
            return runtimeBox.withRuntime { $0.applyFillPlan(plan, payload: payload) }
        }
    }

    private static func performStrokeCommit(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int,
        runtimeBox: LockedDocumentRuntimeBox<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeBox.withRuntime {
            $0.makeStrokeCommitPlan(samples: samples, brush: brush, layerIndex: layerIndex)
        }
        switch planResult {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let result = plan.gpuServices.commitStrokeMutation(
                basePixelData: plan.pixelData,
                baseBufferHandle: plan.baseBufferHandle,
                canvasWidth: plan.canvasWidth,
                canvasHeight: plan.canvasHeight,
                samples: plan.samples,
                brush: plan.brush,
                snapshotRevision: plan.revision,
                activeLayerIndex: plan.layerIndex
            ) else {
                return .failure(.gpu(.kernelFailed(operation: "applyCommittedStroke")))
            }
            return runtimeBox.withRuntime { $0.applyStrokeCommitPlan(plan, gpuResult: result) }
        }
    }

    private static func performCurrentStrokeCommit(
        runtimeBox: LockedDocumentRuntimeBox<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeBox.withRuntime { $0.currentStrokeCommitPlan() }
        switch planResult {
        case let .failure(failure):
            Self.logger.error("Current stroke commit plan failed: \(String(describing: failure), privacy: .public)")
            return .failure(failure)
        case .success(nil):
            return .success(())
        case let .success(plan?):
            guard let result = plan.gpuServices.commitStrokeMutation(
                basePixelData: plan.pixelData,
                baseBufferHandle: plan.baseBufferHandle,
                canvasWidth: plan.canvasWidth,
                canvasHeight: plan.canvasHeight,
                samples: plan.samples,
                brush: plan.brush,
                snapshotRevision: plan.revision,
                activeLayerIndex: plan.layerIndex
            ) else {
                let failure = DocumentMutationFailure.gpu(.kernelFailed(operation: "applyCommittedStroke"))
                Self.logger.error("Current stroke GPU commit failed: \(String(describing: failure), privacy: .public)")
                return .failure(failure)
            }
            let mutationResult = runtimeBox.withRuntime { $0.applyStrokeCommitPlan(plan, gpuResult: result) }
            switch mutationResult {
            case .success:
                runtimeBox.withRuntime { $0.clearCurrentStroke() }
            case let .failure(failure):
                Self.logger.error("Current stroke apply failed: \(String(describing: failure), privacy: .public)")
            }
            return mutationResult
        }
    }

    private static func performBlur(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int,
        captureTimelapse: Bool,
        runtimeBox: LockedDocumentRuntimeBox<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeBox.withRuntime {
            $0.makeBlurPlan(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse)
        }
        switch planResult {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let payload = plan.gpuServices.blurPixels(
                pixelData: plan.pixelData,
                sourceBufferHandle: plan.sourceBufferHandle,
                canvasWidth: plan.canvasWidth,
                canvasHeight: plan.canvasHeight,
                samples: plan.samples,
                brush: plan.brush
            ) else {
                return .failure(.gpu(.kernelFailed(operation: "blurStroke")))
            }
            return runtimeBox.withRuntime { $0.applyBlurPlan(plan, payload: payload) }
        }
    }
}

public final class DocumentTimelapseReplayService {
    private let runtime: SwiftDocumentRuntime
    private var folderIDMap: [DocumentFolderID: Int] = [:]

    public init(
        canvasSize: CGSize,
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live
    ) {
        self.runtime = SwiftDocumentRuntime(
            width: max(Int(canvasSize.width.rounded()), 1),
            height: max(Int(canvasSize.height.rounded()), 1),
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient,
            gpuServices: DocumentRuntimeGpuServicesFactory.live()
        )
    }

    public func replaySurface(_ operation: TimelapseOperation) -> DocumentCompositeSurface? {
        runtime.replayTimelapseOperation(operation, folderIDMap: &folderIDMap)
        return runtime.timelapseCompositeSurface()
    }

    // Legacy convenience retained for callers that still expect CGImage.
    // Replay/export code should prefer `replaySurface(_:)`.
    @available(*, deprecated, message: "Prefer replaySurface(_:) for live replay paths.")
    public func replay(_ operation: TimelapseOperation) -> CGImage? {
        guard let surface = replaySurface(operation) else { return nil }
        return runtime.cgImage(from: surface.pixelData, width: surface.width, height: surface.height)
    }
}
