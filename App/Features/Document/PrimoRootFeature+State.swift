import ComposableArchitecture
import Foundation
import PrimoDocumentDomain

extension PrimoRootFeature {
    typealias WorkspaceState = WorkspaceFeature.State

    @ObservableState
    struct State: Equatable {
        var application = ApplicationFeature.State()
        var nanoBanana = NanoBananaFeature.State()
        var workspace = WorkspaceFeature.State()
        var document = DocumentFeature.State()
        var importExport = ImportExportFeature.State()
    }
}
