import ComposableArchitecture
import Foundation

struct BrushPresetImportRequest: Equatable, OperationRequest {
    let urls: [URL]
    let language: AppLanguage
}

struct BrushPresetImportResult: Equatable, OperationResult {
    let presets: [BrushPreset]
    let failureMessages: [String]
}

enum BrushPresetImportContract: OperationContract {
    typealias Request = BrushPresetImportRequest
    typealias Result = BrushPresetImportResult
    typealias Failure = NeverOperationFailure
}

struct TextFontImportRequest: Equatable, OperationRequest {
    let urls: [URL]
}

struct TextFontImportResult: Equatable, OperationResult {
    let fonts: [TextFontOption]
    let failureMessages: [String]
}

enum TextFontImportContract: OperationContract {
    typealias Request = TextFontImportRequest
    typealias Result = TextFontImportResult
    typealias Failure = NeverOperationFailure
}

enum BrushTipImportFailure: LocalizedError, Equatable, OperationFailure {
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case let .loadFailed(message):
            return message
        }
    }
}

struct BrushImportClient: Sendable {
    var importBrushPresets: @Sendable (BrushPresetImportRequest) -> BrushPresetImportResult
    var importTextFonts: @Sendable (TextFontImportRequest) -> TextFontImportResult
    var loadCustomTip: @Sendable (URL) -> Result<BrushTipRaster, BrushTipImportFailure>

    static func live(
        brushTipLibraryClient: BrushTipLibraryClient,
        textFontLibraryClient: TextFontLibraryClient,
        securityScopedResourceClient: SecurityScopedResourceClient
    ) -> BrushImportClient {
        BrushImportClient(
            importBrushPresets: { request in
                var imported: [BrushPreset] = []
                var failures: [String] = []

                for url in request.urls {
                    let didAccess = securityScopedResourceClient.startAccessing(url)
                    defer {
                        if didAccess {
                            securityScopedResourceClient.stopAccessing(url)
                        }
                    }
                    do {
                        if url.pathExtension.lowercased() == "abr" {
                            let brushes = try brushTipLibraryClient
                                .importPhotoshopBrushes(url)
                                .map(\.preset)
                            if brushes.isEmpty {
                                failures.append(
                                    "\(url.lastPathComponent): \(request.language.localized("対応している先端が見つかりませんでした。"))"
                                )
                            } else {
                                imported.append(contentsOf: brushes)
                            }
                            continue
                        }

                        let brushName = url.deletingPathExtension().lastPathComponent
                        let tip = try brushTipLibraryClient.loadRaster(url)
                        imported.append(
                            BrushPreset.photoshopImported(name: brushName, tip: tip)
                        )
                    } catch {
                        failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }

                return BrushPresetImportResult(presets: imported, failureMessages: failures)
            },
            importTextFonts: { request in
                var importedFonts: [TextFontOption] = []
                var failures: [String] = []

                for url in request.urls {
                    let didAccess = securityScopedResourceClient.startAccessing(url)
                    defer {
                        if didAccess {
                            securityScopedResourceClient.stopAccessing(url)
                        }
                    }
                    do {
                        importedFonts.append(
                            contentsOf: try textFontLibraryClient.importFonts([url])
                        )
                    } catch {
                        failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }

                return TextFontImportResult(fonts: importedFonts, failureMessages: failures)
            },
            loadCustomTip: { url in
                let didAccess = securityScopedResourceClient.startAccessing(url)
                defer {
                    if didAccess {
                        securityScopedResourceClient.stopAccessing(url)
                    }
                }
                do {
                    return .success(try brushTipLibraryClient.loadRaster(url))
                } catch {
                    return .failure(
                        .loadFailed("\(url.lastPathComponent): \(error.localizedDescription)")
                    )
                }
            }
        )
    }
}

private enum BrushImportClientKey: DependencyKey {
    static var liveValue: BrushImportClient {
        @Dependency(\.brushTipLibraryClient) var brushTipLibraryClient
        @Dependency(\.textFontLibraryClient) var textFontLibraryClient
        @Dependency(\.securityScopedResourceClient) var securityScopedResourceClient
        return .live(
            brushTipLibraryClient: brushTipLibraryClient,
            textFontLibraryClient: textFontLibraryClient,
            securityScopedResourceClient: securityScopedResourceClient
        )
    }
}

extension DependencyValues {
    var brushImportClient: BrushImportClient {
        get { self[BrushImportClientKey.self] }
        set { self[BrushImportClientKey.self] = newValue }
    }
}

enum NeverOperationFailure: OperationFailure, Equatable {}
