import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import CoreGraphics
import SwiftUI

extension PrimoRootFeature {
    typealias SelectionTransformCommit = CrossFeatureIntegrationReducer.SelectionTransformCommit
    typealias SelectionTransformService = CrossFeatureIntegrationReducer.SelectionTransformService

    typealias WorkspacePersistenceIssue = CrossFeatureIntegrationReducer.WorkspacePersistenceIssue
    typealias WorkspacePersistenceFailureReason = CrossFeatureIntegrationReducer.WorkspacePersistenceFailureReason
    typealias WorkspacePersistenceFailure = CrossFeatureIntegrationReducer.WorkspacePersistenceFailure
    typealias WorkspaceDirtyPresentationRequest = CrossFeatureIntegrationReducer.WorkspaceDirtyPresentationRequest
    typealias WorkspaceDocumentSavePurpose = CrossFeatureIntegrationReducer.WorkspaceDocumentSavePurpose
    typealias WorkspaceDocumentSaveRequest = CrossFeatureIntegrationReducer.WorkspaceDocumentSaveRequest
    typealias WorkspaceDocumentSaveResult = CrossFeatureIntegrationReducer.WorkspaceDocumentSaveResult
    typealias WorkspaceDocumentReplacementRequest = CrossFeatureIntegrationReducer.WorkspaceDocumentReplacementRequest
    typealias LoadedWorkspaceFollowUpPersistenceRequest = CrossFeatureIntegrationReducer.LoadedWorkspaceFollowUpPersistenceRequest
    typealias LoadedWorkspaceFollowUpPersistenceResult = CrossFeatureIntegrationReducer.LoadedWorkspaceFollowUpPersistenceResult
    typealias WorkspaceCloseTabsSaveRequest = CrossFeatureIntegrationReducer.WorkspaceCloseTabsSaveRequest
    typealias WorkspaceCloseTabsSaveResult = CrossFeatureIntegrationReducer.WorkspaceCloseTabsSaveResult
    typealias WorkspaceArtifactDiscardRequest = CrossFeatureIntegrationReducer.WorkspaceArtifactDiscardRequest
    typealias WorkspaceTabReservationRequest = CrossFeatureIntegrationReducer.WorkspaceTabReservationRequest
    typealias WorkspaceSavedProjectMoveRequest = CrossFeatureIntegrationReducer.WorkspaceSavedProjectMoveRequest
    typealias WorkspaceSavedProjectMoveResult = CrossFeatureIntegrationReducer.WorkspaceSavedProjectMoveResult
    typealias WorkspaceAutosaveEntryDiscardRequest = CrossFeatureIntegrationReducer.WorkspaceAutosaveEntryDiscardRequest
    typealias WorkspaceSaveHistoryLoadRequest = CrossFeatureIntegrationReducer.WorkspaceSaveHistoryLoadRequest
    typealias WorkspaceCatalogFailureReason = CrossFeatureIntegrationReducer.WorkspaceCatalogFailureReason
    typealias WorkspaceCatalogFailure = CrossFeatureIntegrationReducer.WorkspaceCatalogFailure
    typealias WorkspacePersistenceRequest = CrossFeatureIntegrationReducer.WorkspacePersistenceRequest
    typealias WorkspacePersistenceResult = CrossFeatureIntegrationReducer.WorkspacePersistenceResult
    typealias WorkspaceCatalogRequest = CrossFeatureIntegrationReducer.WorkspaceCatalogRequest
    typealias WorkspaceCatalogResult = CrossFeatureIntegrationReducer.WorkspaceCatalogResult
    typealias LoadedWorkspaceProjectPlan = CrossFeatureIntegrationReducer.LoadedWorkspaceProjectPlan
    typealias WorkspacePersistenceUseCase = CrossFeatureIntegrationReducer.WorkspacePersistenceUseCase
    typealias WorkspaceCatalogUseCase = CrossFeatureIntegrationReducer.WorkspaceCatalogUseCase
    typealias WorkspaceBackingStoreService = CrossFeatureIntegrationReducer.WorkspaceBackingStoreService
    typealias WorkspaceCatalogService = CrossFeatureIntegrationReducer.WorkspaceCatalogService
    typealias WorkspaceArtifactService = CrossFeatureIntegrationReducer.WorkspaceArtifactService
    typealias WorkspaceIdentityService = CrossFeatureIntegrationReducer.WorkspaceIdentityService
    typealias WorkspaceApplicationServices = CrossFeatureIntegrationReducer.WorkspaceApplicationServices
    typealias PreparedWorkspaceTab = CrossFeatureIntegrationReducer.PreparedWorkspaceTab
    typealias WorkspaceLoadedProjectFollowUpPlanner = CrossFeatureIntegrationReducer.WorkspaceLoadedProjectFollowUpPlanner
    typealias WorkspaceApplicationWorkflowService = CrossFeatureIntegrationReducer.WorkspaceApplicationWorkflowService
    typealias WorkspaceDocumentContext = CrossFeatureIntegrationReducer.WorkspaceDocumentContext
    typealias PendingWorkspaceTabReservation = CrossFeatureIntegrationReducer.PendingWorkspaceTabReservation
    typealias PendingLoadedWorkspaceProject = CrossFeatureIntegrationReducer.PendingLoadedWorkspaceProject
    typealias PendingFreshDocumentMutation = CrossFeatureIntegrationReducer.PendingFreshDocumentMutation
    typealias LoadedWorkspacePresentation = CrossFeatureIntegrationReducer.LoadedWorkspacePresentation
    typealias WorkspaceFeedbackMapper = CrossFeatureIntegrationReducer.WorkspaceFeedbackMapper
    typealias WorkspaceLoadFailureContext = CrossFeatureIntegrationReducer.WorkspaceLoadFailureContext

    typealias CanvasLifecycleContractFailure = CrossFeatureIntegrationReducer.CanvasLifecycleContractFailure
    typealias CanvasDimensions = CrossFeatureIntegrationReducer.CanvasDimensions
    typealias ImportedCanvasPlan = CrossFeatureIntegrationReducer.ImportedCanvasPlan
    typealias CanvasResizePlan = CrossFeatureIntegrationReducer.CanvasResizePlan
    typealias CanvasResizeValidation = CrossFeatureIntegrationReducer.CanvasResizeValidation
    typealias CanvasHistoryOperation = CrossFeatureIntegrationReducer.CanvasHistoryOperation
    typealias FreshDocumentReplacementContract = CrossFeatureIntegrationReducer.FreshDocumentReplacementContract
    typealias PreparedFreshDocumentReplacement = CrossFeatureIntegrationReducer.PreparedFreshDocumentReplacement
    typealias FreshDocumentReservationCoordinator = CrossFeatureIntegrationReducer.FreshDocumentReservationCoordinator
    typealias FreshDocumentWorkspaceCoordinator = CrossFeatureIntegrationReducer.FreshDocumentWorkspaceCoordinator
    typealias FreshDocumentActivationCoordinator = CrossFeatureIntegrationReducer.FreshDocumentActivationCoordinator
    typealias FreshDocumentReplacementCoordinator = CrossFeatureIntegrationReducer.FreshDocumentReplacementCoordinator
    typealias CanvasLifecycleFeedbackMapper = CrossFeatureIntegrationReducer.CanvasLifecycleFeedbackMapper

    typealias DocumentPresentationQueryService = CrossFeatureIntegrationReducer.DocumentPresentationQueryService
    typealias DocumentPaperStyleSyncClient = CrossFeatureIntegrationReducer.DocumentPaperStyleSyncClient

    typealias DocumentCanvasMutation = CrossFeatureIntegrationReducer.DocumentCanvasMutation
    typealias DocumentPresentationRefresh = CrossFeatureIntegrationReducer.DocumentPresentationRefresh
    typealias LayerMutationFinalization = CrossFeatureIntegrationReducer.LayerMutationFinalization
    typealias DocumentMutationContract = CrossFeatureIntegrationReducer.DocumentMutationContract
    typealias LayerWorkflowService = CrossFeatureIntegrationReducer.LayerWorkflowService
    typealias DocumentCanvasMutationCoordinator = CrossFeatureIntegrationReducer.DocumentCanvasMutationCoordinator
    typealias DocumentPresentationRefreshCoordinator = CrossFeatureIntegrationReducer.DocumentPresentationRefreshCoordinator
    typealias DocumentMutationFeedbackCoordinator = CrossFeatureIntegrationReducer.DocumentMutationFeedbackCoordinator
    typealias DocumentMutationFeedbackMapper = CrossFeatureIntegrationReducer.DocumentMutationFeedbackMapper

    typealias WorkspaceProjectLoadIssue = CrossFeatureIntegrationReducer.WorkspaceProjectLoadIssue
    typealias WorkspaceProjectLoadFailureReason = CrossFeatureIntegrationReducer.WorkspaceProjectLoadFailureReason
    typealias WorkspaceProjectLoadOperation = CrossFeatureIntegrationReducer.WorkspaceProjectLoadOperation
    typealias WorkspaceImportedProjectLoadOperation = CrossFeatureIntegrationReducer.WorkspaceImportedProjectLoadOperation
    typealias WorkspaceProjectLoadRequest = CrossFeatureIntegrationReducer.WorkspaceProjectLoadRequest
    typealias WorkspaceProjectLoadResult = CrossFeatureIntegrationReducer.WorkspaceProjectLoadResult
    typealias WorkspaceProjectLoadFailure = CrossFeatureIntegrationReducer.WorkspaceProjectLoadFailure
    typealias WorkspaceProjectPreparationUseCase = CrossFeatureIntegrationReducer.WorkspaceProjectPreparationUseCase
    typealias WorkspaceProjectLoadUseCase = CrossFeatureIntegrationReducer.WorkspaceProjectLoadUseCase
    typealias WorkspaceProjectLoadCommand = CrossFeatureIntegrationReducer.WorkspaceProjectLoadCommand
    typealias WorkspaceProjectLoadingService = CrossFeatureIntegrationReducer.WorkspaceProjectLoadingService

    typealias GradientMapStop = CrossFeatureIntegrationReducer.GradientMapStop
    typealias InpaintCrop = CrossFeatureIntegrationReducer.InpaintCrop
    typealias ImportedCanvasImage = CrossFeatureIntegrationReducer.ImportedCanvasImage
    typealias LayerContentMutationTarget = CrossFeatureIntegrationReducer.LayerContentMutationTarget
    typealias AppliedLayerContentMutation = CrossFeatureIntegrationReducer.AppliedLayerContentMutation
    typealias LayerContentWorkflowService = CrossFeatureIntegrationReducer.LayerContentWorkflowService
    typealias CanvasStrokeContext = CrossFeatureIntegrationReducer.CanvasStrokeContext
    typealias StrokeCommitResolution = CrossFeatureIntegrationReducer.StrokeCommitResolution
    typealias CanvasStrokeContextResolver = CrossFeatureIntegrationReducer.CanvasStrokeContextResolver
    typealias CanvasStrokeStateCoordinator = CrossFeatureIntegrationReducer.CanvasStrokeStateCoordinator
    typealias CanvasStrokeEffectCoordinator = CrossFeatureIntegrationReducer.CanvasStrokeEffectCoordinator
    typealias CanvasStrokeInteractionCoordinator = CrossFeatureIntegrationReducer.CanvasStrokeInteractionCoordinator
    typealias ShareExportFactory = CrossFeatureIntegrationReducer.ShareExportFactory
    typealias ActiveLayerPixelContext = CrossFeatureIntegrationReducer.ActiveLayerPixelContext
    typealias AdjustmentWorkflowService = CrossFeatureIntegrationReducer.AdjustmentWorkflowService
    typealias StartupPresentationService = CrossFeatureIntegrationReducer.StartupPresentationService

    static func optionalErrorMessage(_ error: Error) -> String? {
        CrossFeatureIntegrationReducer.optionalErrorMessage(error)
    }

    static func documentMutationFailureMessage(
        _ failure: DocumentMutationFailure,
        language: AppLanguage
    ) -> String {
        CrossFeatureIntegrationReducer.documentMutationFailureMessage(failure, language: language)
    }

    static func pngData(fromLayerPixelData pixelData: Data, width: Int, height: Int) -> Data? {
        CrossFeatureIntegrationReducer.pngData(fromLayerPixelData: pixelData, width: width, height: height)
    }

    static func color(from sampledColor: SampledColor) -> Color {
        CrossFeatureIntegrationReducer.color(from: sampledColor)
    }

    static func clampUnit(_ value: CGFloat) -> CGFloat {
        CrossFeatureIntegrationReducer.clampUnit(value)
    }

    static func interpolate(_ from: CGFloat, _ to: CGFloat, amount: CGFloat) -> CGFloat {
        CrossFeatureIntegrationReducer.interpolate(from, to, amount: amount)
    }

    static func rasterizedLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        CrossFeatureIntegrationReducer.rasterizedLuminance(red: red, green: green, blue: blue)
    }

    static func nanoBananaFailureFeedback(_ failure: NanoBananaEditFailure) -> ApplicationFeature.Feedback {
        CrossFeatureIntegrationReducer.nanoBananaFailureFeedback(failure)
    }

    static func gradientMapStops(for preset: GradientMapPreset) -> [GradientMapStop] {
        CrossFeatureIntegrationReducer.gradientMapStops(for: preset)
    }

    static func gradientMapStops(for settings: GradientMapSettings) -> [GradientMapStop] {
        CrossFeatureIntegrationReducer.gradientMapStops(for: settings)
    }

    static func gradientMapSettings(for preset: GradientMapPreset) -> GradientMapSettings {
        CrossFeatureIntegrationReducer.gradientMapSettings(for: preset)
    }

    static func normalizeGradientMapSettings(_ settings: GradientMapSettings) -> GradientMapSettings {
        CrossFeatureIntegrationReducer.normalizeGradientMapSettings(settings)
    }

    static func mappedGradientColor(
        for value: Double,
        stops: [GradientMapStop]
    ) -> (red: UInt8, green: UInt8, blue: UInt8) {
        CrossFeatureIntegrationReducer.mappedGradientColor(for: value, stops: stops)
    }

    static func renderedCompositeSurface(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuOperations: DocumentGpuOperationGateway
    ) -> DocumentCompositeSurface {
        CrossFeatureIntegrationReducer.renderedCompositeSurface(
            snapshot: snapshot,
            paperStyle: paperStyle,
            gpuOperations: gpuOperations
        )
    }

    static func layerMaskData(
        from selection: CanvasSelection?,
        canvasSize: CGSize,
        gpuOperations: DocumentGpuOperationGateway
    ) -> Data? {
        CrossFeatureIntegrationReducer.layerMaskData(
            from: selection,
            canvasSize: canvasSize,
            gpuOperations: gpuOperations
        )
    }

    static func transformationBounds(
        selection: CanvasSelection?,
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        gpuOperations: DocumentGpuOperationGateway
    ) -> CGRect? {
        CrossFeatureIntegrationReducer.transformationBounds(
            selection: selection,
            pixelData: pixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            gpuOperations: gpuOperations
        )
    }
}
