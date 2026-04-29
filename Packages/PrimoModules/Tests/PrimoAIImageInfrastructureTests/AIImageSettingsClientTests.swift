import PrimoCoreTypes
import PrimoAIImageDomain
import PrimoAIImageInfrastructure
import Testing

struct AIImageSettingsClientTests {
    private enum TestSecretFailure: Error {
        case writeFailed
    }

    private final class TestStorage: @unchecked Sendable {
        var values: [String: String]

        init(_ values: [String: String]) {
            self.values = values
        }
    }

    @Test
    func loadReturnsAccessModeFromDefaultsAndSecretsFromSecretStore() {
        let defaults = TestStorage([
            AIImageSettingsClient.accessModeStorageKey: AIImageAccessMode.appManaged.rawValue,
        ])
        let secrets = TestStorage([
            AIImageSettingsClient.apiKeyStorageKey: "gemini-secret",
            AIImageSettingsClient.openAIAPIKeyStorageKey: "openai-secret",
        ])
        let client = AIImageSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { defaults.values[$0] },
                setString: { value, key in defaults.values[key] = value }
            ),
            secretStoreClient: SecretStoreClient(
                readSecret: { secrets.values[$0] },
                writeSecret: { value, key in secrets.values[key] = value }
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
    func persistWritesAccessModeToDefaultsAndSecretsToSecretStore() {
        let defaults = TestStorage([:])
        let secrets = TestStorage([:])
        let client = AIImageSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { defaults.values[$0] },
                setString: { value, key in defaults.values[key] = value }
            ),
            secretStoreClient: SecretStoreClient(
                readSecret: { secrets.values[$0] },
                writeSecret: { value, key in secrets.values[key] = value }
            )
        )

        client.persist(
            AIImageSettings(
                accessMode: .appManaged,
                apiKey: "persisted-gemini-key",
                openAIAPIKey: "persisted-openai-key"
            )
        )

        #expect(defaults.values[AIImageSettingsClient.accessModeStorageKey] == AIImageAccessMode.appManaged.rawValue)
        #expect(defaults.values[AIImageSettingsClient.apiKeyStorageKey] == nil)
        #expect(defaults.values[AIImageSettingsClient.openAIAPIKeyStorageKey] == nil)
        #expect(secrets.values[AIImageSettingsClient.apiKeyStorageKey] == "persisted-gemini-key")
        #expect(secrets.values[AIImageSettingsClient.openAIAPIKeyStorageKey] == "persisted-openai-key")
    }

    @Test
    func loadMigratesLegacyDefaultsSecretsToSecretStore() {
        let defaults = TestStorage([
            AIImageSettingsClient.accessModeStorageKey: AIImageAccessMode.userAPIKey.rawValue,
            AIImageSettingsClient.apiKeyStorageKey: "legacy-gemini-key",
            AIImageSettingsClient.openAIAPIKeyStorageKey: "legacy-openai-key",
        ])
        let secrets = TestStorage([:])
        let client = AIImageSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { defaults.values[$0] },
                setString: { value, key in
                    if let value {
                        defaults.values[key] = value
                    } else {
                        defaults.values.removeValue(forKey: key)
                    }
                }
            ),
            secretStoreClient: SecretStoreClient(
                readSecret: { secrets.values[$0] },
                writeSecret: { value, key in secrets.values[key] = value }
            )
        )

        let settings = client.load()

        #expect(settings.accessMode == .userAPIKey)
        #expect(settings.apiKey == "legacy-gemini-key")
        #expect(settings.openAIAPIKey == "legacy-openai-key")
        #expect(defaults.values[AIImageSettingsClient.apiKeyStorageKey] == nil)
        #expect(defaults.values[AIImageSettingsClient.openAIAPIKeyStorageKey] == nil)
        #expect(secrets.values[AIImageSettingsClient.apiKeyStorageKey] == "legacy-gemini-key")
        #expect(secrets.values[AIImageSettingsClient.openAIAPIKeyStorageKey] == "legacy-openai-key")
    }

    @Test
    func persistEmptyAPIKeysRemovesSecrets() {
        let defaults = TestStorage([:])
        let secrets = TestStorage([
            AIImageSettingsClient.apiKeyStorageKey: "old-gemini-key",
            AIImageSettingsClient.openAIAPIKeyStorageKey: "old-openai-key",
        ])
        let client = AIImageSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { defaults.values[$0] },
                setString: { value, key in defaults.values[key] = value }
            ),
            secretStoreClient: SecretStoreClient(
                readSecret: { secrets.values[$0] },
                writeSecret: { value, key in
                    if let value {
                        secrets.values[key] = value
                    } else {
                        secrets.values.removeValue(forKey: key)
                    }
                }
            )
        )

        client.persist(AIImageSettings(accessMode: .appManaged))

        #expect(secrets.values[AIImageSettingsClient.apiKeyStorageKey] == nil)
        #expect(secrets.values[AIImageSettingsClient.openAIAPIKeyStorageKey] == nil)
    }

    @Test
    func persistKeepsLegacyDefaultsWhenSecretWriteFails() {
        let defaults = TestStorage([
            AIImageSettingsClient.apiKeyStorageKey: "legacy-gemini-key",
            AIImageSettingsClient.openAIAPIKeyStorageKey: "legacy-openai-key",
        ])
        let secrets = TestStorage([:])
        let client = AIImageSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { defaults.values[$0] },
                setString: { value, key in defaults.values[key] = value }
            ),
            secretStoreClient: SecretStoreClient(
                readSecret: { secrets.values[$0] },
                writeSecret: { _, _ in throw TestSecretFailure.writeFailed }
            )
        )

        client.persist(
            AIImageSettings(
                accessMode: .appManaged,
                apiKey: "persisted-gemini-key",
                openAIAPIKey: "persisted-openai-key"
            )
        )

        #expect(defaults.values[AIImageSettingsClient.apiKeyStorageKey] == "legacy-gemini-key")
        #expect(defaults.values[AIImageSettingsClient.openAIAPIKeyStorageKey] == "legacy-openai-key")
        #expect(secrets.values.isEmpty)
    }

    @Test
    func loadKeepsLegacyDefaultsWhenMigrationWriteFails() {
        let defaults = TestStorage([
            AIImageSettingsClient.apiKeyStorageKey: "legacy-gemini-key",
        ])
        let secrets = TestStorage([:])
        let client = AIImageSettingsClient.live(
            keyValueStoreClient: KeyValueStoreClient(
                stringForKey: { defaults.values[$0] },
                setString: { value, key in defaults.values[key] = value }
            ),
            secretStoreClient: SecretStoreClient(
                readSecret: { secrets.values[$0] },
                writeSecret: { _, _ in throw TestSecretFailure.writeFailed }
            )
        )

        let settings = client.load()

        #expect(settings.apiKey == "legacy-gemini-key")
        #expect(defaults.values[AIImageSettingsClient.apiKeyStorageKey] == "legacy-gemini-key")
        #expect(secrets.values.isEmpty)
    }
}
