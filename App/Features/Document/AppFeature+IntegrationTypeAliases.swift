import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import CoreGraphics
import SwiftUI

extension AppFeature {
    typealias SelectionTransformCommit = AppIntegrationFeature.SelectionTransformCommit
    typealias SelectionTransformService = AppIntegrationFeature.SelectionTransformService

    typealias WorkspacePersistenceIssue = AppIntegrationFeature.WorkspacePersistenceIssue
    typealias WorkspacePersistenceFailureReason = AppIntegrationFeature.WorkspacePersistenceFailureReason
    typealias WorkspacePersistenceFailure = AppIntegrationFeature.WorkspacePersistenceFailure
    typealias WorkspaceDirtyPresentationRequest = AppIntegrationFeature.WorkspaceDirtyPresentationRequest
    typealias WorkspaceDocumentSavePurpose = AppIntegrationFeature.WorkspaceDocumentSavePurpose
    typealias WorkspaceDocumentSaveRequest = AppIntegrationFeature.WorkspaceDocumentSaveRequest
    typealias WorkspaceDocumentSaveResult = AppIntegrationFeature.WorkspaceDocumentSaveResult
    typealias WorkspaceDocumentReplacementRequest = AppIntegrationFeature.WorkspaceDocumentReplacementRequest
    typealias LoadedWorkspaceFollowUpPersistenceRequest = AppIntegrationFeature.LoadedWorkspaceFollowUpPersistenceRequest
    typealias LoadedWorkspaceFollowUpPersistenceResult = AppIntegrationFeature.LoadedWorkspaceFollowUpPersistenceResult
    typealias WorkspaceCloseTabsSaveRequest = AppIntegrationFeature.WorkspaceCloseTabsSaveRequest
    typealias WorkspaceCloseTabsSaveResult = AppIntegrationFeature.WorkspaceCloseTabsSaveResult
    typealias WorkspaceArtifactDiscardRequest = AppIntegrationFeature.WorkspaceArtifactDiscardRequest
    typealias WorkspaceTabReservationRequest = AppIntegrationFeature.WorkspaceTabReservationRequest
    typealias WorkspaceSavedProjectMoveRequest = AppIntegrationFeature.WorkspaceSavedProjectMoveRequest
    typealias WorkspaceSavedProjectMoveResult = AppIntegrationFeature.WorkspaceSavedProjectMoveResult
    typealias WorkspaceAutosaveEntryDiscardRequest = AppIntegrationFeature.WorkspaceAutosaveEntryDiscardRequest
    typealias WorkspaceSaveHistoryLoadRequest = AppIntegrationFeature.WorkspaceSaveHistoryLoadRequest
    typealias WorkspaceCatalogFailureReason = AppIntegrationFeature.WorkspaceCatalogFailureReason
    typealias WorkspaceCatalogFailure = AppIntegrationFeature.WorkspaceCatalogFailure
    typealias WorkspacePersistenceRequest = AppIntegrationFeature.WorkspacePersistenceRequest
    typealias WorkspacePersistenceResult = AppIntegrationFeature.WorkspacePersistenceResult
    typealias WorkspaceCatalogRequest = AppIntegrationFeature.WorkspaceCatalogRequest
    typealias WorkspaceCatalogResult = AppIntegrationFeature.WorkspaceCatalogResult
    typealias LoadedWorkspaceProjectPlan = AppIntegrationFeature.LoadedWorkspaceProjectPlan
    typealias WorkspacePersistenceUseCase = AppIntegrationFeature.WorkspacePersistenceUseCase
    typealias WorkspaceCatalogUseCase = AppIntegrationFeature.WorkspaceCatalogUseCase
    typealias WorkspaceBackingStoreService = AppIntegrationFeature.WorkspaceBackingStoreService
    typealias WorkspaceCatalogService = AppIntegrationFeature.WorkspaceCatalogService
    typealias WorkspaceArtifactService = AppIntegrationFeature.WorkspaceArtifactService
    typealias WorkspaceIdentityService = AppIntegrationFeature.WorkspaceIdentityService
    typealias WorkspaceApplicationServices = AppIntegrationFeature.WorkspaceApplicationServices
    typealias PreparedWorkspaceTab = AppIntegrationFeature.PreparedWorkspaceTab
    typealias WorkspaceLoadedProjectFollowUpPlanner = AppIntegrationFeature.WorkspaceLoadedProjectFollowUpPlanner
    typealias WorkspaceApplicationWorkflowService = AppIntegrationFeature.WorkspaceApplicationWorkflowService
    typealias WorkspaceDocumentContext = AppIntegrationFeature.WorkspaceDocumentContext
    typealias PendingWorkspaceTabReservation = AppIntegrationFeature.PendingWorkspaceTabReservation
    typealias PendingLoadedWorkspaceProject = AppIntegrationFeature.PendingLoadedWorkspaceProject
    typealias PendingFreshDocumentMutation = AppIntegrationFeature.PendingFreshDocumentMutation
    typealias LoadedWorkspacePresentation = AppIntegrationFeature.LoadedWorkspacePresentation
    typealias WorkspaceFeedbackMapper = AppIntegrationFeature.WorkspaceFeedbackMapper
    typealias WorkspaceLoadFailureContext = AppIntegrationFeature.WorkspaceLoadFailureContext

    typealias CanvasLifecycleContractFailure = AppIntegrationFeature.CanvasLifecycleContractFailure
    typealias CanvasDimensions = AppIntegrationFeature.CanvasDimensions
    typealias ImportedCanvasPlan = AppIntegrationFeature.ImportedCanvasPlan
    typealias CanvasResizePlan = AppIntegrationFeature.CanvasResizePlan
    typealias CanvasResizeValidation = AppIntegrationFeature.CanvasResizeValidation
    typealias CanvasHistoryOperation = AppIntegrationFeature.CanvasHistoryOperation
    typealias FreshDocumentReplacementContract = AppIntegrationFeature.FreshDocumentReplacementContract
    typealias PreparedFreshDocumentReplacement = AppIntegrationFeature.PreparedFreshDocumentReplacement
    typealias FreshDocumentReservationCoordinator = AppIntegrationFeature.FreshDocumentReservationCoordinator
    typealias FreshDocumentWorkspaceCoordinator = AppIntegrationFeature.FreshDocumentWorkspaceCoordinator
    typealias FreshDocumentActivationCoordinator = AppIntegrationFeature.FreshDocumentActivationCoordinator
    typealias FreshDocumentReplacementCoordinator = AppIntegrationFeature.FreshDocumentReplacementCoordinator
    typealias CanvasLifecycleFeedbackMapper = AppIntegrationFeature.CanvasLifecycleFeedbackMapper

    typealias DocumentPresentationQueryService = AppIntegrationFeature.DocumentPresentationQueryService
    typealias DocumentPaperStyleSyncClient = AppIntegrationFeature.DocumentPaperStyleSyncClient

    typealias DocumentCanvasMutation = AppIntegrationFeature.DocumentCanvasMutation
    typealias DocumentPresentationRefresh = AppIntegrationFeature.DocumentPresentationRefresh
    typealias LayerMutationFinalization = AppIntegrationFeature.LayerMutationFinalization
    typealias DocumentMutationContract = AppIntegrationFeature.DocumentMutationContract
    typealias LayerWorkflowService = AppIntegrationFeature.LayerWorkflowService
    typealias DocumentCanvasMutationCoordinator = AppIntegrationFeature.DocumentCanvasMutationCoordinator
    typealias DocumentPresentationRefreshCoordinator = AppIntegrationFeature.DocumentPresentationRefreshCoordinator
    typealias DocumentMutationFeedbackCoordinator = AppIntegrationFeature.DocumentMutationFeedbackCoordinator
    typealias DocumentMutationFeedbackMapper = AppIntegrationFeature.DocumentMutationFeedbackMapper

    typealias WorkspaceProjectLoadIssue = AppIntegrationFeature.WorkspaceProjectLoadIssue
    typealias WorkspaceProjectLoadFailureReason = AppIntegrationFeature.WorkspaceProjectLoadFailureReason
    typealias WorkspaceProjectLoadOperation = AppIntegrationFeature.WorkspaceProjectLoadOperation
    typealias WorkspaceImportedProjectLoadOperation = AppIntegrationFeature.WorkspaceImportedProjectLoadOperation
    typealias WorkspaceProjectLoadRequest = AppIntegrationFeature.WorkspaceProjectLoadRequest
    typealias WorkspaceProjectLoadResult = AppIntegrationFeature.WorkspaceProjectLoadResult
    typealias WorkspaceProjectLoadFailure = AppIntegrationFeature.WorkspaceProjectLoadFailure
    typealias WorkspaceProjectPreparationUseCase = AppIntegrationFeature.WorkspaceProjectPreparationUseCase
    typealias WorkspaceProjectLoadUseCase = AppIntegrationFeature.WorkspaceProjectLoadUseCase
    typealias WorkspaceProjectLoadCommand = AppIntegrationFeature.WorkspaceProjectLoadCommand
    typealias WorkspaceProjectLoadingService = AppIntegrationFeature.WorkspaceProjectLoadingService

    typealias GradientMapStop = AppIntegrationFeature.GradientMapStop
    typealias InpaintCrop = AppIntegrationFeature.InpaintCrop
    typealias ImportedCanvasImage = AppIntegrationFeature.ImportedCanvasImage
    typealias LayerContentMutationTarget = AppIntegrationFeature.LayerContentMutationTarget
    typealias AppliedLayerContentMutation = AppIntegrationFeature.AppliedLayerContentMutation
    typealias LayerContentWorkflowService = AppIntegrationFeature.LayerContentWorkflowService
    typealias CanvasStrokeContext = AppIntegrationFeature.CanvasStrokeContext
    typealias StrokeCommitResolution = AppIntegrationFeature.StrokeCommitResolution
    typealias CanvasStrokeContextResolver = AppIntegrationFeature.CanvasStrokeContextResolver
    typealias CanvasStrokeStateCoordinator = AppIntegrationFeature.CanvasStrokeStateCoordinator
    typealias CanvasStrokeEffectCoordinator = AppIntegrationFeature.CanvasStrokeEffectCoordinator
    typealias CanvasStrokeInteractionCoordinator = AppIntegrationFeature.CanvasStrokeInteractionCoordinator
    typealias ShareExportFactory = AppIntegrationFeature.ShareExportFactory
    typealias ActiveLayerPixelContext = AppIntegrationFeature.ActiveLayerPixelContext
    typealias AdjustmentWorkflowService = AppIntegrationFeature.AdjustmentWorkflowService
    typealias StartupPresentationService = AppIntegrationFeature.StartupPresentationService

    static func optionalErrorMessage(_ error: Error) -> String? {
        AppIntegrationFeature.optionalErrorMessage(error)
    }

    static func documentMutationFailureMessage(
        _ failure: DocumentMutationFailure,
        language: AppLanguage
    ) -> String {
        AppIntegrationFeature.documentMutationFailureMessage(failure, language: language)
    }

    static func pngData(fromLayerPixelData pixelData: Data, width: Int, height: Int) -> Data? {
        AppIntegrationFeature.pngData(fromLayerPixelData: pixelData, width: width, height: height)
    }

    static func color(from sampledColor: SampledColor) -> Color {
        AppIntegrationFeature.color(from: sampledColor)
    }

    static func clampUnit(_ value: CGFloat) -> CGFloat {
        AppIntegrationFeature.clampUnit(value)
    }

    static func interpolate(_ from: CGFloat, _ to: CGFloat, amount: CGFloat) -> CGFloat {
        AppIntegrationFeature.interpolate(from, to, amount: amount)
    }

    static func rasterizedLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        AppIntegrationFeature.rasterizedLuminance(red: red, green: green, blue: blue)
    }

    static func nanoBananaFailureFeedback(_ failure: NanoBananaEditFailure) -> ApplicationFeedback {
        AppIntegrationFeature.nanoBananaFailureFeedback(failure)
    }

    static func gradientMapStops(for preset: GradientMapPreset) -> [GradientMapStop] {
        AppIntegrationFeature.gradientMapStops(for: preset)
    }

    static func gradientMapStops(for settings: GradientMapSettings) -> [GradientMapStop] {
        AppIntegrationFeature.gradientMapStops(for: settings)
    }

    static func gradientMapSettings(for preset: GradientMapPreset) -> GradientMapSettings {
        AppIntegrationFeature.gradientMapSettings(for: preset)
    }

    static func normalizeGradientMapSettings(_ settings: GradientMapSettings) -> GradientMapSettings {
        AppIntegrationFeature.normalizeGradientMapSettings(settings)
    }

    static func mappedGradientColor(
        for value: Double,
        stops: [GradientMapStop]
    ) -> (red: UInt8, green: UInt8, blue: UInt8) {
        AppIntegrationFeature.mappedGradientColor(for: value, stops: stops)
    }

    static func renderedCompositeSurface(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuOperations: DocumentGpuOperationGateway
    ) -> DocumentCompositeSurface {
        AppIntegrationFeature.renderedCompositeSurface(
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
        AppIntegrationFeature.layerMaskData(
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
        AppIntegrationFeature.transformationBounds(
            selection: selection,
            pixelData: pixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            gpuOperations: gpuOperations
        )
    }
}
