import ComposableArchitecture
import CoreText
import Foundation
import Synchronization
import UIKit

struct TextFontLibraryClient: Sendable {
    var loadAvailableFonts: @Sendable () -> [TextFontOption]
    var importFonts: @Sendable ([URL]) throws -> [TextFontOption]

    static func live(fileClient: FileClient) -> TextFontLibraryClient {
        let storage = TextFontLibraryStorage(fileClient: fileClient)
        return TextFontLibraryClient(
            loadAvailableFonts: { storage.loadAvailableFonts() },
            importFonts: { try storage.importFonts(from: $0) }
        )
    }
}

private enum TextFontLibraryClientKey: DependencyKey {
    static var liveValue: TextFontLibraryClient {
        @Dependency(\.fileClient) var fileClient
        return .live(fileClient: fileClient)
    }
}

extension DependencyValues {
    var textFontLibraryClient: TextFontLibraryClient {
        get { self[TextFontLibraryClientKey.self] }
        set { self[TextFontLibraryClientKey.self] = newValue }
    }
}

private struct TextFontLibraryStorage {
    private static let importedFontsDirectoryName = "ImportedFonts"
    private static let registeredFontURLs = Mutex(Set<String>())

    let fileClient: FileClient

    func loadAvailableFonts() -> [TextFontOption] {
        registerImportedFontsIfNeeded()
        var options: [TextFontOption] = []
        for family in UIFont.familyNames.sorted() {
            for postScriptName in UIFont.fontNames(forFamilyName: family).sorted() {
                let font = UIFont(name: postScriptName, size: 14)
                options.append(
                    TextFontOption(
                        postScriptName: postScriptName,
                        displayName: font?.fontName ?? postScriptName,
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
                // Best-effort registration of previously imported fonts.
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
        let needsRegistration = Self.registeredFontURLs.withLock { registeredFontURLs in
            !registeredFontURLs.contains(url.path)
        }

        if needsRegistration {
            var registrationError: Unmanaged<CFError>?
            let didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registrationError)
            if !didRegister, let error = registrationError?.takeRetainedValue() {
                let description = CFErrorCopyDescription(error) as String
                if !description.localizedCaseInsensitiveContains("already") {
                    throw error
                }
            }
            Self.registeredFontURLs.withLock { registeredFontURLs in
                _ = registeredFontURLs.insert(url.path)
            }
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
}
