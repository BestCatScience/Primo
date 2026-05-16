import PrimoCoreTypes
import PrimoDocumentEngineInfrastructure
import PrimoDocumentRuntime
import PrimoSystemClients

public enum DocumentApplicationRuntimeFactory {
    public static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentApplicationRuntime {
        DocumentApplicationRuntime(
            composition: DocumentRuntimeLiveCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }

    public static func liveWorkflows(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentApplicationWorkflowRuntime {
        live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        ).workflows
    }
}

public enum DocumentRuntimeFactory {
    public static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentRuntime {
        DocumentRuntime(
            composition: DocumentRuntimeLiveCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}
