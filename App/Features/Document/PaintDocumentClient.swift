import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentEngineInfrastructure
import PrimoDocumentStrokeApplication

private enum DocumentRuntimeCompositionKey: DependencyKey {
    static var liveValue: DocumentRuntimeComposition {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient

        return DocumentRuntimeCompositionFactory.live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
    }
}

private enum DocumentCanvasCommandServiceKey: DependencyKey {
    static var liveValue: DocumentCanvasCommandService {
        @Dependency(\.documentRuntimeComposition) var composition
        return DocumentCanvasCommandService(
            queryGateway: composition.queryGateway,
            mutationGateway: composition.mutationGateway,
            persistenceGateway: composition.persistenceGateway
        )
    }
}

private enum DocumentLayerCommandServiceKey: DependencyKey {
    static var liveValue: DocumentLayerCommandService {
        @Dependency(\.documentRuntimeComposition) var composition
        return DocumentLayerCommandService(mutationGateway: composition.mutationGateway)
    }
}

private enum DocumentStrokeCommandServiceKey: DependencyKey {
    static var liveValue: DocumentStrokeCommandService {
        @Dependency(\.documentRuntimeComposition) var composition
        return DocumentStrokeCommandService(strokeGateway: composition.strokeGateway)
    }
}

private enum DocumentHistoryCommandServiceKey: DependencyKey {
    static var liveValue: DocumentHistoryCommandService {
        @Dependency(\.documentRuntimeComposition) var composition
        return DocumentHistoryCommandService(historyGateway: composition.historyGateway)
    }
}

private extension DependencyValues {
    mutating func setDocumentRuntimeCompositionAndRefreshCommandServices(
        _ composition: DocumentRuntimeComposition
    ) {
        self[DocumentRuntimeCompositionKey.self] = composition
        self[DocumentCanvasCommandServiceKey.self] = DocumentCanvasCommandService(
            queryGateway: composition.queryGateway,
            mutationGateway: composition.mutationGateway,
            persistenceGateway: composition.persistenceGateway
        )
        self[DocumentLayerCommandServiceKey.self] = DocumentLayerCommandService(
            mutationGateway: composition.mutationGateway
        )
        self[DocumentStrokeCommandServiceKey.self] = DocumentStrokeCommandService(
            strokeGateway: composition.strokeGateway
        )
        self[DocumentHistoryCommandServiceKey.self] = DocumentHistoryCommandService(
            historyGateway: composition.historyGateway
        )
    }
}

extension DependencyValues {
    var documentRuntimeComposition: DocumentRuntimeComposition {
        get { self[DocumentRuntimeCompositionKey.self] }
        set { setDocumentRuntimeCompositionAndRefreshCommandServices(newValue) }
    }

    var documentQueryGateway: DocumentQueryGateway {
        get { documentRuntimeComposition.queryGateway }
        set {
            var composition = documentRuntimeComposition
            composition.queryGateway = newValue
            setDocumentRuntimeCompositionAndRefreshCommandServices(composition)
        }
    }

    var documentMutationGateway: DocumentMutationGateway {
        get { documentRuntimeComposition.mutationGateway }
        set {
            var composition = documentRuntimeComposition
            composition.mutationGateway = newValue
            setDocumentRuntimeCompositionAndRefreshCommandServices(composition)
        }
    }

    var strokeInputGateway: StrokeInputGateway {
        get { documentRuntimeComposition.strokeGateway }
        set {
            var composition = documentRuntimeComposition
            composition.strokeGateway = newValue
            setDocumentRuntimeCompositionAndRefreshCommandServices(composition)
        }
    }

    var documentHistoryGateway: DocumentHistoryGateway {
        get { documentRuntimeComposition.historyGateway }
        set {
            var composition = documentRuntimeComposition
            composition.historyGateway = newValue
            setDocumentRuntimeCompositionAndRefreshCommandServices(composition)
        }
    }

    var documentPersistenceGateway: DocumentPersistenceGateway {
        get { documentRuntimeComposition.persistenceGateway }
        set {
            var composition = documentRuntimeComposition
            composition.persistenceGateway = newValue
            setDocumentRuntimeCompositionAndRefreshCommandServices(composition)
        }
    }

    var documentExportGateway: DocumentExportGateway {
        get { documentRuntimeComposition.exportGateway }
        set {
            var composition = documentRuntimeComposition
            composition.exportGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var textLayerGateway: TextLayerGateway {
        get { documentRuntimeComposition.textLayerGateway }
        set {
            var composition = documentRuntimeComposition
            composition.textLayerGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentLayerEffectsGateway: DocumentLayerEffectsGateway {
        get { documentRuntimeComposition.layerEffectsGateway }
        set {
            var composition = documentRuntimeComposition
            composition.layerEffectsGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentEditingGateway: DocumentEditingGateway {
        get { documentRuntimeComposition.editingGateway }
        set {
            var composition = documentRuntimeComposition
            composition.editingGateway = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentStrokeSessionUseCase: DocumentStrokeSessionUseCase {
        get { documentRuntimeComposition.strokeSessionUseCase }
        set {
            var composition = documentRuntimeComposition
            composition.strokeSessionUseCase = newValue
            documentRuntimeComposition = composition
        }
    }

    var documentCanvasCommandService: DocumentCanvasCommandService {
        get { self[DocumentCanvasCommandServiceKey.self] }
        set { self[DocumentCanvasCommandServiceKey.self] = newValue }
    }

    var documentLayerCommandService: DocumentLayerCommandService {
        get { self[DocumentLayerCommandServiceKey.self] }
        set { self[DocumentLayerCommandServiceKey.self] = newValue }
    }

    var documentStrokeCommandService: DocumentStrokeCommandService {
        get { self[DocumentStrokeCommandServiceKey.self] }
        set { self[DocumentStrokeCommandServiceKey.self] = newValue }
    }

    var documentHistoryCommandService: DocumentHistoryCommandService {
        get { self[DocumentHistoryCommandServiceKey.self] }
        set { self[DocumentHistoryCommandServiceKey.self] = newValue }
    }
}
