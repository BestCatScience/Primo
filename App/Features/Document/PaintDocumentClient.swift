import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentEngineInfrastructure

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

private enum DocumentInteractionServiceKey: DependencyKey {
    static var liveValue: DocumentInteractionService {
        @Dependency(\.documentRuntimeComposition) var composition
        return Self.makeService(from: composition)
    }

    private static func makeService(from composition: DocumentRuntimeComposition) -> DocumentInteractionService {
        DocumentInteractionService(
            queryGateway: composition.queryGateway,
            mutationGateway: composition.mutationGateway,
            strokeGateway: composition.strokeGateway,
            historyGateway: composition.historyGateway,
            persistenceGateway: composition.persistenceGateway
        )
    }
}

private extension DependencyValues {
    mutating func setDocumentRuntimeCompositionAndRefreshInteractionService(
        _ composition: DocumentRuntimeComposition
    ) {
        self[DocumentRuntimeCompositionKey.self] = composition
        self[DocumentInteractionServiceKey.self] = DocumentInteractionService(
            queryGateway: composition.queryGateway,
            mutationGateway: composition.mutationGateway,
            strokeGateway: composition.strokeGateway,
            historyGateway: composition.historyGateway,
            persistenceGateway: composition.persistenceGateway
        )
    }
}

extension DependencyValues {
    var documentRuntimeComposition: DocumentRuntimeComposition {
        get { self[DocumentRuntimeCompositionKey.self] }
        set { setDocumentRuntimeCompositionAndRefreshInteractionService(newValue) }
    }

    var documentQueryGateway: DocumentQueryGateway {
        get { documentRuntimeComposition.queryGateway }
        set {
            var composition = documentRuntimeComposition
            composition.queryGateway = newValue
            setDocumentRuntimeCompositionAndRefreshInteractionService(composition)
        }
    }

    var documentMutationGateway: DocumentMutationGateway {
        get { documentRuntimeComposition.mutationGateway }
        set {
            var composition = documentRuntimeComposition
            composition.mutationGateway = newValue
            setDocumentRuntimeCompositionAndRefreshInteractionService(composition)
        }
    }

    var strokeInputGateway: StrokeInputGateway {
        get { documentRuntimeComposition.strokeGateway }
        set {
            var composition = documentRuntimeComposition
            composition.strokeGateway = newValue
            setDocumentRuntimeCompositionAndRefreshInteractionService(composition)
        }
    }

    var documentHistoryGateway: DocumentHistoryGateway {
        get { documentRuntimeComposition.historyGateway }
        set {
            var composition = documentRuntimeComposition
            composition.historyGateway = newValue
            setDocumentRuntimeCompositionAndRefreshInteractionService(composition)
        }
    }

    var documentPersistenceGateway: DocumentPersistenceGateway {
        get { documentRuntimeComposition.persistenceGateway }
        set {
            var composition = documentRuntimeComposition
            composition.persistenceGateway = newValue
            setDocumentRuntimeCompositionAndRefreshInteractionService(composition)
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

    var documentInteractionService: DocumentInteractionService {
        get { self[DocumentInteractionServiceKey.self] }
        set { self[DocumentInteractionServiceKey.self] = newValue }
    }
}
