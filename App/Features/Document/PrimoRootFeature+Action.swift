import CasePaths
import Foundation

extension PrimoRootFeature {
    @CasePathable
    enum Action: Equatable {
        case application(ApplicationFeature.Action)
        case workspace(WorkspaceFeature.Action)
        case document(DocumentFeature.Action)
        case importExport(ImportExportFeature.Action)
        case aiImage(AIImageFeature.Action)
    }
}
