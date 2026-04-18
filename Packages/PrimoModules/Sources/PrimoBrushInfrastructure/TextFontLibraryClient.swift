import CoreText
import Foundation
import PrimoCoreTypes
import PrimoDocumentDomain
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct TextFontLibraryClient: Sendable {
    public var loadAvailableFonts: @Sendable () -> [TextFontOption]
    public var importFonts: @Sendable ([URL]) throws -> [TextFontOption]

    public init(
        loadAvailableFonts: @escaping @Sendable () -> [TextFontOption],
        importFonts: @escaping @Sendable ([URL]) throws -> [TextFontOption]
    ) {
        self.loadAvailableFonts = loadAvailableFonts
        self.importFonts = importFonts
    }

    public static func live(fileClient: FileClient) -> TextFontLibraryClient {
        let storage = TextFontLibraryStorage(fileClient: fileClient)
        return TextFontLibraryClient(
            loadAvailableFonts: { storage.loadAvailableFonts() },
            importFonts: { try storage.importFonts(from: $0) }
        )
    }
}

private struct TextFontLibraryStorage {
    private static let importedFontsDirectoryName = "ImportedFonts"
    private static let registry = RegisteredFontURLRegistry()

    let fileClient: FileClient

    func loadAvailableFonts() -> [TextFontOption] {
        registerImportedFontsIfNeeded()
        var options: [TextFontOption] = []
        for family in availableFontFamilies() {
            for postScriptName in fontNames(forFamilyName: family) {
                let displayName = displayName(forPostScriptName: postScriptName)
                options.append(
                    TextFontOption(
                        postScriptName: postScriptName,
                        displayName: displayName,
                        sourceFilename: nil
                    )
                )
            }
        }
        return options.sorted {
            ($0.displayName, $0.postScriptName) < ($1.displayName, $1.postScriptName)
        }
    }

    func importFonts(from urls: [URL]) throws -> [TextFontOption] {
        let directory = importedFontsDirectoryURL()
        try fileClient.createDirectory(directory, true)
        var imported: [TextFontOption] = []

        for url in urls {
            let destinationURL = uniqueImportedFontURL(for: url.lastPathComponent)
            if fileClient.fileExists(destinationURL.path) {
                try fileClient.removeItem(destinationURL)
            }
            try fileClient.copyItem(url, destinationURL)
            imported.append(
                contentsOf: try registerFont(
                    at: destinationURL,
                    sourceFilename: destinationURL.lastPathComponent
                )
            )
        }

        return imported
    }

    private func registerImportedFontsIfNeeded() {
        let urls: [URL]
        do {
            urls = try fileClient.contentsOfDirectory(
                importedFontsDirectoryURL(),
                [],
                [.skipsHiddenFiles]
            )
        } catch {
            return
        }

        for url in urls {
            do {
                _ = try registerFont(at: url, sourceFilename: url.lastPathComponent)
            } catch {
                continue
            }
        }
    }

    private func importedFontsDirectoryURL() -> URL {
        let baseURL = fileClient.urls(.applicationSupportDirectory, .userDomainMask).first
            ?? fileClient.temporaryDirectory()
        return baseURL.appendingPathComponent(Self.importedFontsDirectoryName, isDirectory: true)
    }

    private func uniqueImportedFontURL(for filename: String) -> URL {
        let directory = importedFontsDirectoryURL()
        let ext = (filename as NSString).pathExtension
        let stemSource = (filename as NSString).deletingPathExtension
        let stem = stemSource.isEmpty ? "ImportedFont" : stemSource
        var counter = 0
        while true {
            let candidateName = counter == 0
                ? "\(stem)\(ext.isEmpty ? "" : ".\(ext)")"
                : "\(stem)-\(counter)\(ext.isEmpty ? "" : ".\(ext)")"
            let candidateURL = directory.appendingPathComponent(candidateName, isDirectory: false)
            if !fileClient.fileExists(candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }

    private func registerFont(
        at url: URL,
        sourceFilename: String?
    ) throws -> [TextFontOption] {
        let needsRegistration = Self.registry.needsRegistration(for: url.path)

        if needsRegistration {
            var registrationError: Unmanaged<CFError>?
            let didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registrationError)
            if !didRegister, let error = registrationError?.takeRetainedValue() {
                let description = CFErrorCopyDescription(error) as String
                if !description.localizedCaseInsensitiveContains("already") {
                    throw error
                }
            }
            Self.registry.markRegistered(url.path)
        }

        guard let provider = CGDataProvider(url: url as CFURL), let cgFont = CGFont(provider) else {
            return []
        }
        let postScriptName = cgFont.postScriptName as String? ?? url.deletingPathExtension().lastPathComponent
        let displayName = CTFontCopyFullName(
            CTFontCreateWithGraphicsFont(cgFont, 14, nil, nil)
        ) as String
        return [
            TextFontOption(
                postScriptName: postScriptName,
                displayName: displayName,
                sourceFilename: sourceFilename
            )
        ]
    }

    private func availableFontFamilies() -> [String] {
        #if canImport(UIKit)
        return UIFont.familyNames.sorted()
        #elseif canImport(AppKit)
        return NSFontManager.shared.availableFontFamilies.sorted()
        #else
        return []
        #endif
    }

    private func fontNames(forFamilyName family: String) -> [String] {
        #if canImport(UIKit)
        return UIFont.fontNames(forFamilyName: family).sorted()
        #elseif canImport(AppKit)
        let members = NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []
        return members.compactMap { member in
            guard member.count > 0 else { return nil }
            return member[0] as? String
        }
        .sorted()
        #else
        return []
        #endif
    }

    private func displayName(forPostScriptName postScriptName: String) -> String {
        #if canImport(UIKit)
        return UIFont(name: postScriptName, size: 14)?.fontName ?? postScriptName
        #elseif canImport(AppKit)
        return NSFont(name: postScriptName, size: 14)?.fontName ?? postScriptName
        #else
        return postScriptName
        #endif
    }
}

private final class RegisteredFontURLRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var values = Set<String>()

    func needsRegistration(for path: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !values.contains(path)
    }

    func markRegistered(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        _ = values.insert(path)
    }
}
