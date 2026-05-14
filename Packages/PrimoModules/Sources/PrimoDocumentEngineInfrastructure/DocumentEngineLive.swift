import CoreGraphics
import Foundation
import os
import PrimoBrushRuntimeContracts
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentInfrastructure

package struct DocumentEngineLive: Sendable {
    package let queryGateway: DocumentQueryGateway
    package let renderGateway: DocumentRenderGateway
    package let dirtyUpdateQueue: DocumentDirtyUpdateQueue
    package let mutationGateway: DocumentMutationGateway
    package let strokeGateway: StrokeInputGateway
    package let historyGateway: DocumentHistoryGateway
    package let persistenceGateway: DocumentPersistenceGateway
    package let exportGateway: DocumentExportGateway
    package let textLayerGateway: TextLayerGateway

    package let duplicateLayer: @Sendable (Int, String) -> DocumentIndexedMutationResult
    package let moveLayer: @Sendable (Int, Int) -> DocumentMutationResult
    package let createFolder: @Sendable (String, LayerAnchorIndex) -> DocumentIndexedMutationResult
    package let deleteFolder: @Sendable (Int) -> DocumentMutationResult
    package let setFolderVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    package let setFolderName: @Sendable (Int, String) -> DocumentMutationResult
    package let setFolderExpanded: @Sendable (Int, Bool) -> DocumentMutationResult
    package let assignLayerToFolder: @Sendable (ExistingLayerIndex, ExistingFolderID?) -> DocumentMutationResult
    package let setLayerLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    package let setLayerAlphaLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    package let setLayerClipped: @Sendable (Int, Bool) -> DocumentMutationResult
    package let setLayerOpacity: @Sendable (Int, Double) -> DocumentMutationResult
    package let setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> DocumentMutationResult
    package let mergeLayerDown: @Sendable (Int) -> DocumentMutationResult
}

package enum DocumentEngineFactory {
    private static let logger = Logger(subsystem: "com.primo.app", category: "DocumentEngineFactory")

    package static func live(
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
        let runtimeExecutor = LockedDocumentRuntimeExecutor(
            runtime: SwiftDocumentRuntime(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient,
                gpuServices: gpuServices
            )
        )

        let queryGateway = DocumentQueryGateway(
            lightweightPresentation: { runtimeExecutor.perform { $0.lightweightPresentation() } },
            presentation: { runtimeExecutor.perform { $0.presentation() } }
        )
        let renderGateway = DocumentRenderGateway(
            compositePixelData: {
                let snapshot = runtimeExecutor.perform { $0.materializedSnapshot() }
                return SwiftDocumentRuntime.compositeSurface(
                    forMaterializedSnapshot: snapshot,
                    gpuServices: gpuServices
                ).pixelData
            },
            compositeSurface: {
                let snapshot = runtimeExecutor.perform { $0.materializedSnapshot() }
                return SwiftDocumentRuntime.compositeSurface(
                    forMaterializedSnapshot: snapshot,
                    gpuServices: gpuServices
                )
            },
            pixelDataForLayer: { index in runtimeExecutor.perform { $0.pixelDataForLayer(index: index) } }
        )
        let dirtyUpdateQueue = DocumentDirtyUpdateQueue(
            consumeDirtyUpdate: { runtimeExecutor.perform { $0.consumeDirtyUpdate() } }
        )

        let mutationGateway = DocumentMutationGateway(
            resizeCanvas: { width, height in
                performResizeCanvas(width: width, height: height, runtimeExecutor: runtimeExecutor)
            },
            resizeCanvasExtent: { width, height in
                performResizeCanvasExtent(width: width, height: height, runtimeExecutor: runtimeExecutor)
            },
            addLayer: { name in runtimeExecutor.perform { $0.addLayer(name: name) } },
            deleteLayer: { index in runtimeExecutor.perform { $0.deleteLayer(index: index) } },
            setActiveLayer: { index in runtimeExecutor.perform { $0.setActiveLayer(index: index) } },
            setLayerName: { index, name in runtimeExecutor.perform { $0.setLayerName(index: index, name: name) } },
            setLayerVisibility: { index, isVisible in
                runtimeExecutor.perform { $0.setLayerVisibility(index: index, isVisible: isVisible) }
            },
            revealLayerForEditing: { index in runtimeExecutor.perform { $0.revealLayerForEditing(index: index) } },
            replaceLayerPixels: { index, data in runtimeExecutor.perform { $0.replaceLayerPixels(index: index, data: data) } },
            replaceLayerPixelsInRect: { index, rect, data in
                runtimeExecutor.perform { $0.replaceLayerPixels(index: index, in: rect, data: data) }
            },
            applyLayerSurfaceMutation: { index, payload in
                runtimeExecutor.perform { $0.applyLayerSurfaceMutation(index: index, payload: payload) }
            },
            applyLayerMutation: { index, payload in
                runtimeExecutor.perform { $0.applyLayerMutation(index: index, payload: payload) }
            },
            applyTextLayerMutation: { index, textLayer, payload in
                runtimeExecutor.perform { $0.applyTextLayerMutation(index: index, textLayer: textLayer, payload: payload) }
            },
            replaceLayerMask: { index, data in runtimeExecutor.perform { $0.replaceLayerMask(index: index, data: data) } },
            clearLayerMask: { index in runtimeExecutor.perform { $0.clearLayerMask(index: index) } },
            applyLayerMask: { index in runtimeExecutor.perform { $0.applyLayerMask(index: index) } },
            clearLayer: { index in runtimeExecutor.perform { $0.clearLayer(index: index) } },
            applyLayerProcessing: { index, request in
                performLayerProcessing(index: index, request: request, runtimeExecutor: runtimeExecutor)
            }
        )

        let strokeGateway = StrokeInputGateway(
            beginStroke: { sample, brush in runtimeExecutor.perform { $0.beginStroke(sample: sample, brush: brush) } },
            appendStroke: { sample in runtimeExecutor.perform { $0.appendStroke(sample: sample) } },
            endStroke: {
                performCurrentStrokeCommit(runtimeExecutor: runtimeExecutor)
            },
            cancelStroke: { runtimeExecutor.perform { $0.cancelStroke() } },
            blurStroke: { samples, brush, layerIndex, captureTimelapse in
                performBlur(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse, runtimeExecutor: runtimeExecutor)
            },
            endBlurStroke: { runtimeExecutor.perform { $0.endBlurStroke() } },
            cancelBlurStroke: { runtimeExecutor.perform { $0.cancelBlurStroke() } },
            fill: { sample, brush in
                performFill(sample: sample, brush: brush, runtimeExecutor: runtimeExecutor)
            },
            applyGpuStrokeSurface: { samples, brush, layerIndex in
                performStrokeCommit(samples: samples, brush: brush, layerIndex: layerIndex, runtimeExecutor: runtimeExecutor)
            }
        )

        let historyGateway = DocumentHistoryGateway(
            canUndo: { runtimeExecutor.perform { $0.canUndo() } },
            canRedo: { runtimeExecutor.perform { $0.canRedo() } },
            undo: { runtimeExecutor.perform { $0.undo() } },
            redo: { runtimeExecutor.perform { $0.redo() } },
            trimForMemoryPressure: { runtimeExecutor.perform { $0.trimUndoHistoryForMemoryPressure() } }
        )

        let persistenceGateway = DocumentPersistenceGateway(
            saveProject: { url, paperStyle in
                let snapshot = runtimeExecutor.perform { $0.projectSaveSnapshot(paperStyle: paperStyle) }
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
                runtimeExecutor.replaceRuntime(with: runtime)
                return loadedProject
            },
            setPaperStyle: { style in runtimeExecutor.perform { $0.setPaperStyle(style) } },
            newCanvas: { width, height in
                runtimeExecutor.replaceRuntime(
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
                let snapshot = runtimeExecutor.perform { $0.materializedSnapshot() }
                _ = SwiftDocumentRuntime.compositeSurface(
                    forMaterializedSnapshot: snapshot,
                    gpuServices: gpuServices
                )
            }
        )

        let exportGateway = DocumentExportGateway(
            compositeSurface: { style in
                let snapshot = runtimeExecutor.perform { $0.materializedSnapshot() }
                return SwiftDocumentRuntime.compositeExportSurface(
                    forMaterializedSnapshot: snapshot,
                    paperStyle: style,
                    gpuServices: gpuServices
                )
            },
            compositePNGData: { style in
                let snapshot = runtimeExecutor.perform { $0.materializedSnapshot() }
                return SwiftDocumentRuntime.compositePNGData(
                    forMaterializedSnapshot: snapshot,
                    paperStyle: style,
                    gpuServices: gpuServices
                )
            },
            timelapseCapture: { runtimeExecutor.perform { $0.timelapseCapture() } }
        )

        let textLayerGateway = TextLayerGateway(
            textLayerData: { index in runtimeExecutor.perform { $0.textLayerData(index: index) } },
            setTextLayer: { index, textLayer in
                runtimeExecutor.perform { $0.setTextLayer(index: index, textLayer: textLayer) }
            },
            clearTextLayerData: { index in runtimeExecutor.perform { $0.clearTextLayerData(index: index) } }
        )

        return DocumentEngineLive(
            queryGateway: queryGateway,
            renderGateway: renderGateway,
            dirtyUpdateQueue: dirtyUpdateQueue,
            mutationGateway: mutationGateway,
            strokeGateway: strokeGateway,
            historyGateway: historyGateway,
            persistenceGateway: persistenceGateway,
            exportGateway: exportGateway,
            textLayerGateway: textLayerGateway,
            duplicateLayer: { index, name in runtimeExecutor.perform { $0.duplicateLayer(index: index, name: name) } },
            moveLayer: { index, destination in runtimeExecutor.perform { $0.moveLayer(from: index, to: destination) } },
            createFolder: { name, anchor in runtimeExecutor.perform { $0.createFolder(name: name, anchorLayerIndex: anchor) } },
            deleteFolder: { folderID in runtimeExecutor.perform { $0.deleteFolder(folderID: folderID) } },
            setFolderVisibility: { folderID, isVisible in
                runtimeExecutor.perform { $0.setFolderVisibility(folderID: folderID, isVisible: isVisible) }
            },
            setFolderName: { folderID, name in runtimeExecutor.perform { $0.setFolderName(folderID: folderID, name: name) } },
            setFolderExpanded: { folderID, isExpanded in
                runtimeExecutor.perform { $0.setFolderExpanded(folderID: folderID, isExpanded: isExpanded) }
            },
            assignLayerToFolder: { index, folderID in
                runtimeExecutor.perform { $0.assignLayerToFolder(index: index, folderID: folderID) }
            },
            setLayerLocked: { index, isLocked in
                runtimeExecutor.perform { $0.setLayerLocked(index: index, isLocked: isLocked) }
            },
            setLayerAlphaLocked: { index, isAlphaLocked in
                runtimeExecutor.perform { $0.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked) }
            },
            setLayerClipped: { index, isClipped in
                runtimeExecutor.perform { $0.setLayerClipped(index: index, isClipped: isClipped) }
            },
            setLayerOpacity: { index, opacity in
                runtimeExecutor.perform { $0.setLayerOpacity(index: index, opacity: opacity) }
            },
            setLayerBlendMode: { index, blendMode in
                runtimeExecutor.perform { $0.setLayerBlendMode(index: index, blendMode: blendMode) }
            },
            mergeLayerDown: { index in runtimeExecutor.perform { $0.mergeLayerDown(index: index) } }
        )
    }

    private static func performResizeCanvas(
        width: Int,
        height: Int,
        runtimeExecutor: LockedDocumentRuntimeExecutor<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeExecutor.perform { $0.makeResizeCanvasPlan(width: width, height: height) }
        switch planResult {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let plan else { return .success(()) }
            guard let layers = plan.resizedLayers() else {
                return .failure(.gpu(.kernelFailed(operation: "resizeCanvas")))
            }
            return runtimeExecutor.perform { $0.applyResizeCanvasPlan(plan, layers: layers) }
        }
    }

    private static func performResizeCanvasExtent(
        width: Int,
        height: Int,
        runtimeExecutor: LockedDocumentRuntimeExecutor<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeExecutor.perform { $0.makeResizeCanvasExtentPlan(width: width, height: height) }
        switch planResult {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let plan else { return .success(()) }
            guard let layers = plan.resizedLayers() else {
                return .failure(.gpu(.kernelFailed(operation: "resizeCanvasExtent")))
            }
            return runtimeExecutor.perform { $0.applyResizeCanvasPlan(plan, layers: layers) }
        }
    }

    private static func performLayerProcessing(
        index: Int,
        request: LayerProcessingRequest,
        runtimeExecutor: LockedDocumentRuntimeExecutor<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeExecutor.perform { $0.makeLayerProcessingPlan(index: index, request: request) }
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
            return runtimeExecutor.perform { $0.applyLayerProcessingPlan(plan, payload: payload) }
        }
    }

    private static func performFill(
        sample: StylusSample,
        brush: BrushRuntimeSettings,
        runtimeExecutor: LockedDocumentRuntimeExecutor<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeExecutor.perform { $0.makeFillPlan(sample: sample, brush: brush) }
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
            return runtimeExecutor.perform { $0.applyFillPlan(plan, payload: payload) }
        }
    }

    private static func performStrokeCommit(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int,
        runtimeExecutor: LockedDocumentRuntimeExecutor<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeExecutor.perform {
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
            return runtimeExecutor.perform { $0.applyStrokeCommitPlan(plan, gpuResult: result) }
        }
    }

    private static func performCurrentStrokeCommit(
        runtimeExecutor: LockedDocumentRuntimeExecutor<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeExecutor.perform { $0.currentStrokeCommitPlan() }
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
            let mutationResult = runtimeExecutor.perform { $0.applyStrokeCommitPlan(plan, gpuResult: result) }
            switch mutationResult {
            case .success:
                runtimeExecutor.perform { $0.clearCurrentStroke() }
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
        runtimeExecutor: LockedDocumentRuntimeExecutor<SwiftDocumentRuntime>
    ) -> DocumentMutationResult {
        let planResult = runtimeExecutor.perform {
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
            return runtimeExecutor.perform { $0.applyBlurPlan(plan, payload: payload) }
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
