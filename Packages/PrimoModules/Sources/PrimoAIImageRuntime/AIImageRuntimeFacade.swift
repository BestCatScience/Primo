import Foundation
import PrimoAIImageApplication
import PrimoAIImageInfrastructure
import PrimoCoreTypes

public extension AIImageSettingsClient {
    static func live(
        keyValueStoreClient: KeyValueStoreClient,
        secretStoreClient: SecretStoreClient
    ) -> AIImageSettingsClient {
        PrimoAIImageInfrastructure.AIImageRuntimeFactory.settingsClient(
            keyValueStoreClient: keyValueStoreClient,
            secretStoreClient: secretStoreClient
        )
    }
}

public extension AIImageCommerceClient {
    @available(macOS 12.0, iOS 15.0, *)
    static func live(bundle: Bundle = .main) -> AIImageCommerceClient {
        PrimoAIImageInfrastructure.AIImageRuntimeFactory.commerceClient(bundle: bundle)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension AIImageRemoteEditClient {
    static func live(httpClient: HTTPClient) -> AIImageRemoteEditClient {
        PrimoAIImageInfrastructure.AIImageRuntimeFactory.remoteEditClient(httpClient: httpClient)
    }
}
