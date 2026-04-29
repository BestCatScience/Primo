import PrimoCoreTypes
import PrimoNanoBananaDomain
import PrimoNanoBananaInfrastructure
import Testing

struct NanoBananaSettingsClientTests {
    private final class TestStorage: @unchecked Sendable {
        var values: [String: String]

        init(_ values: [String: String]) {
            self.values = values
        }
    }

    @Test
    func loadReturnsPersistedSettings() {
        let storage = TestStorage([
            NanoBananaSettingsClient.accessModeStorageKey: NanoBananaAccessMode.appManaged.rawValue,
            NanoBananaSettingsClient.apiKeyStorageKey: "gemini-secret",
            NanoBananaSettingsClient.openAIAPIKeyStorageKey: "openai-secret"
        ])
        let client = NanoBananaSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { storage.values[$0] },
                setString: { value, key in storage.values[key] = value }
            )
        )

        #expect(
            client.load() == NanoBananaSettings(
                accessMode: .appManaged,
                apiKey: "gemini-secret",
                openAIAPIKey: "openai-secret"
            )
        )
    }

    @Test
    func persistWritesBothFields() {
        let storage = TestStorage([:])
        let client = NanoBananaSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { storage.values[$0] },
                setString: { value, key in storage.values[key] = value }
            )
        )

        client.persist(
            NanoBananaSettings(
                accessMode: .appManaged,
                apiKey: "persisted-gemini-key",
                openAIAPIKey: "persisted-openai-key"
            )
        )

        #expect(storage.values[NanoBananaSettingsClient.accessModeStorageKey] == NanoBananaAccessMode.appManaged.rawValue)
        #expect(storage.values[NanoBananaSettingsClient.apiKeyStorageKey] == "persisted-gemini-key")
        #expect(storage.values[NanoBananaSettingsClient.openAIAPIKeyStorageKey] == "persisted-openai-key")
    }
}
