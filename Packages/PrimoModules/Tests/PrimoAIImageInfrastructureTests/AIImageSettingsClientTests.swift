import PrimoCoreTypes
import PrimoAIImageDomain
import PrimoAIImageInfrastructure
import Testing

struct AIImageSettingsClientTests {
    private final class TestStorage: @unchecked Sendable {
        var values: [String: String]

        init(_ values: [String: String]) {
            self.values = values
        }
    }

    @Test
    func loadReturnsPersistedSettings() {
        let storage = TestStorage([
            AIImageSettingsClient.accessModeStorageKey: AIImageAccessMode.appManaged.rawValue,
            AIImageSettingsClient.apiKeyStorageKey: "gemini-secret",
            AIImageSettingsClient.openAIAPIKeyStorageKey: "openai-secret"
        ])
        let client = AIImageSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { storage.values[$0] },
                setString: { value, key in storage.values[key] = value }
            )
        )

        #expect(
            client.load() == AIImageSettings(
                accessMode: .appManaged,
                apiKey: "gemini-secret",
                openAIAPIKey: "openai-secret"
            )
        )
    }

    @Test
    func persistWritesBothFields() {
        let storage = TestStorage([:])
        let client = AIImageSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { storage.values[$0] },
                setString: { value, key in storage.values[key] = value }
            )
        )

        client.persist(
            AIImageSettings(
                accessMode: .appManaged,
                apiKey: "persisted-gemini-key",
                openAIAPIKey: "persisted-openai-key"
            )
        )

        #expect(storage.values[AIImageSettingsClient.accessModeStorageKey] == AIImageAccessMode.appManaged.rawValue)
        #expect(storage.values[AIImageSettingsClient.apiKeyStorageKey] == "persisted-gemini-key")
        #expect(storage.values[AIImageSettingsClient.openAIAPIKeyStorageKey] == "persisted-openai-key")
    }
}
