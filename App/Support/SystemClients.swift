import Foundation
import os
import PrimoCoreTypes
import PrimoLocalization

enum AppDiagnostics {
    static func isVerboseLoggingEnabled(
        processEnvironmentClient: ProcessEnvironmentClient
    ) -> Bool {
        if let rawValue = processEnvironmentClient.stringValue("PRIMO_VERBOSE_LOGGING") {
            let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on"
        }
        return false
    }

    static func debug(
        _ logger: Logger,
        _ message: String,
        processEnvironmentClient: ProcessEnvironmentClient
    ) {
        guard isVerboseLoggingEnabled(processEnvironmentClient: processEnvironmentClient) else { return }
        logger.debug("\(message)")
    }
}

struct AppLanguageClient: Sendable {
    let load: @Sendable () -> AppLanguage
    let persist: @Sendable (AppLanguage) -> Void

    static func live(keyValueStoreClient: KeyValueStoreClient) -> AppLanguageClient {
        AppLanguageClient(
            load: {
                guard
                    let rawValue = keyValueStoreClient.stringForKey(AppLanguage.storageKey),
                    let language = AppLanguage(rawValue: rawValue)
                else {
                    return .japanese
                }
                return language
            },
            persist: { language in
                keyValueStoreClient.setString(language.rawValue, AppLanguage.storageKey)
            }
        )
    }
}
