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
            NanoBananaSettingsClient.apiKeyStorageKey: "secret"
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
                apiKey: "secret"
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
                apiKey: "persisted-key"
            )
        )

        #expect(storage.values[NanoBananaSettingsClient.accessModeStorageKey] == NanoBananaAccessMode.appManaged.rawValue)
        #expect(storage.values[NanoBananaSettingsClient.apiKeyStorageKey] == "persisted-key")
    }
}
