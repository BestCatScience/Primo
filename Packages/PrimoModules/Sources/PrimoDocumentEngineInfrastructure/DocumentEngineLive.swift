import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
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
    public static func live(
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live
    ) -> DocumentEngineLive {
        let runtimeBox = LockedDocumentRuntimeBox(
            runtime: SwiftDocumentRuntime(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient,
                gpuServices: DocumentRuntimeGpuServicesFactory.live()
            )
        )

        let queryGateway = DocumentQueryGateway(
            lightweightPresentation: { runtimeBox.withRuntime { $0.lightweightPresentation() } },
            presentation: { runtimeBox.withRuntime { $0.presentation() } },
            compositePixelData: { runtimeBox.withRuntime { $0.compositeSurface().pixelData } },
            compositeSurface: { runtimeBox.withRuntime { $0.compositeSurface() } },
            pixelDataForLayer: { index in runtimeBox.withRuntime { $0.pixelDataForLayer(index: index) } },
            consumeDirtyUpdate: { runtimeBox.withRuntime { $0.consumeDirtyUpdate() } }
        )

        let mutationGateway = DocumentMutationGateway(
            resizeCanvas: { width, height in runtimeBox.withRuntime { $0.resizeCanvas(width: width, height: height) } },
            resizeCanvasExtent: { width, height in
                runtimeBox.withRuntime { $0.resizeCanvasExtent(width: width, height: height) }
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
                runtimeBox.withRuntime { $0.applyLayerProcessing(index: index, request: request) }
            }
        )

        let strokeGateway = StrokeInputGateway(
            beginStroke: { sample, brush in runtimeBox.withRuntime { $0.beginStroke(sample: sample, brush: brush) } },
            appendStroke: { sample in runtimeBox.withRuntime { $0.appendStroke(sample: sample) } },
            endStroke: { runtimeBox.withRuntime { $0.endStroke() } },
            cancelStroke: { runtimeBox.withRuntime { $0.cancelStroke() } },
            blurStroke: { samples, brush, layerIndex, captureTimelapse in
                runtimeBox.withRuntime {
                    $0.blur(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse)
                }
            },
            endBlurStroke: { runtimeBox.withRuntime { $0.endBlurStroke() } },
            fill: { sample, brush in runtimeBox.withRuntime { $0.fill(sample: sample, brush: brush) } },
            applyGpuStrokeSurface: { samples, brush, layerIndex in
                runtimeBox.withRuntime { $0.applyGpuStrokeSurface(samples: samples, brush: brush, layerIndex: layerIndex) }
            }
        )

        let historyGateway = DocumentHistoryGateway(
            canUndo: { runtimeBox.withRuntime { $0.canUndo() } },
            canRedo: { runtimeBox.withRuntime { $0.canRedo() } },
            undo: { runtimeBox.withRuntime { $0.undo() } },
            redo: { runtimeBox.withRuntime { $0.redo() } }
        )

        let persistenceGateway = DocumentPersistenceGateway(
            saveProject: { url, paperStyle in
                try runtimeBox.withRuntime { session in
                    try session.saveProject(to: url, paperStyle: paperStyle)
                }
            },
            loadProject: { url in
                let runtime = try SwiftDocumentRuntime.loadProject(
                    from: url,
                    fileClient: fileClient,
                    dateClient: dateClient,
                    uuidClient: uuidClient
                )
                let loadedProject = LoadedPaintProject(
                    presentation: runtime.lightweightPresentation(),
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
                        gpuServices: DocumentRuntimeGpuServicesFactory.live()
                    )
                )
            },
            prewarmDrawingResources: { runtimeBox.withRuntime { $0.prewarmDrawingResources() } }
        )

        let exportGateway = DocumentExportGateway(
            compositeSurface: { style in runtimeBox.withRuntime { $0.compositeExportSurface(paperStyle: style) } },
            compositePNGData: { style in runtimeBox.withRuntime { $0.compositePNGData(paperStyle: style) } },
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
}

public final class DocumentTimelapseReplayService: @unchecked Sendable {
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
