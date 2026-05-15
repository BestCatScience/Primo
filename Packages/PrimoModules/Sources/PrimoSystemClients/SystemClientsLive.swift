import Foundation
import Security
import PrimoSystemContracts

public extension ProcessEnvironmentClient {
    static let live = ProcessEnvironmentClient { key in
        ProcessInfo.processInfo.environment[key]
    }
}

public extension MainQueueClient {
    static let live = MainQueueClient { operation in
        DispatchQueue.main.async {
            operation()
        }
    }
}

public extension DateClient {
    static let live = DateClient(now: { Date() })
}

public extension UUIDClient {
    static let live = UUIDClient(generate: { UUID() })
}

public extension FileClient {
    static let live: FileClient = {
        FileClient(
            temporaryDirectory: { FileManager.default.temporaryDirectory },
            urls: { directory, domain in FileManager.default.urls(for: directory, in: domain) },
            fileExists: { path in FileManager.default.fileExists(atPath: path) },
            createDirectory: { url, createIntermediates in
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: createIntermediates)
            },
            removeItem: { url in
                try FileManager.default.removeItem(at: url)
            },
            copyItem: { sourceURL, destinationURL in
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            },
            moveItem: { sourceURL, destinationURL in
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            },
            replaceItem: { destinationURL, replacementURL, backupItemName in
                _ = try FileManager.default.replaceItemAt(
                    destinationURL,
                    withItemAt: replacementURL,
                    backupItemName: backupItemName,
                    options: backupItemName == nil ? [] : [.withoutDeletingBackupItem]
                )
            },
            contentsOfDirectory: { url, keys, options in
                try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: options
                )
            },
            enumerateURLs: { url, keys, options in
                guard let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: options
                ) else {
                    return []
                }
                return enumerator.compactMap { $0 as? URL }
            },
            readData: { url in
                try Data(contentsOf: url)
            },
            writeData: { data, url, options in
                try data.write(to: url, options: options)
            }
        )
    }()
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension HTTPClient {
    static let live = HTTPClient { request in
        try await URLSession.shared.data(for: request)
    }
}

public extension KeyValueStoreClient {
    static let live = KeyValueStoreClient(
        stringForKey: { key in
            UserDefaults.standard.string(forKey: key)
        },
        setString: { value, key in
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    )
}

public extension SecretStoreClient {
    static let live = SecretStoreClient(
        readSecret: { key in
            var query = keychainQuery(for: key)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecItemNotFound {
                return nil
            }
            guard status == errSecSuccess else {
                throw SecretStoreError.unhandledStatus(status)
            }
            guard
                let data = item as? Data,
                let secret = String(data: data, encoding: .utf8)
            else {
                throw SecretStoreError.invalidData
            }
            return secret
        },
        writeSecret: { secret, key in
            let query = keychainQuery(for: key)
            guard let secret else {
                let status = SecItemDelete(query as CFDictionary)
                guard status == errSecSuccess || status == errSecItemNotFound else {
                    throw SecretStoreError.unhandledStatus(status)
                }
                return
            }

            let data = Data(secret.utf8)
            let update = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            if updateStatus == errSecSuccess {
                return
            }
            guard updateStatus == errSecItemNotFound else {
                throw SecretStoreError.unhandledStatus(updateStatus)
            }

            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecretStoreError.unhandledStatus(addStatus)
            }
        }
    )
}

private func keychainQuery(for key: String) -> [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.bestcatscience.primo.secrets",
        kSecAttrAccount as String: key,
    ]
}

public extension SecurityScopedResourceClient {
    static let live = SecurityScopedResourceClient(
        startAccessing: { url in
            url.startAccessingSecurityScopedResource()
        },
        stopAccessing: { url in
            url.stopAccessingSecurityScopedResource()
        }
    )
}
