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
        textFontLibraryClient: TextFontLibraryClient
    ) -> BrushImportClient {
        BrushImportClient(
            importBrushPresets: { request in
                var imported: [BrushPreset] = []
                var failures: [String] = []

                for url in request.urls {
                    withSecurityScopedAccess(to: url) {
                        if url.pathExtension.lowercased() == "abr" {
                            do {
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
                            } catch {
                                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                            }
                            return
                        }

                        let brushName = url.deletingPathExtension().lastPathComponent
                        do {
                            let tip = try brushTipLibraryClient.loadRaster(url)
                            imported.append(
                                BrushPreset.photoshopImported(name: brushName, tip: tip)
                            )
                        } catch {
                            failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        }
                    }
                }

                return BrushPresetImportResult(presets: imported, failureMessages: failures)
            },
            importTextFonts: { request in
                var importedFonts: [TextFontOption] = []
                var failures: [String] = []

                for url in request.urls {
                    withSecurityScopedAccess(to: url) {
                        do {
                            importedFonts.append(
                                contentsOf: try textFontLibraryClient.importFonts([url])
                            )
                        } catch {
                            failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        }
                    }
                }

                return TextFontImportResult(fonts: importedFonts, failureMessages: failures)
            },
            loadCustomTip: { url in
                withSecurityScopedAccess(to: url) {
                    do {
                        return .success(try brushTipLibraryClient.loadRaster(url))
                    } catch {
                        return .failure(
                            .loadFailed("\(url.lastPathComponent): \(error.localizedDescription)")
                        )
                    }
                }
            }
        )
    }
}

private enum BrushImportClientKey: DependencyKey {
    static var liveValue: BrushImportClient {
        @Dependency(\.brushTipLibraryClient) var brushTipLibraryClient
        @Dependency(\.textFontLibraryClient) var textFontLibraryClient
        return .live(
            brushTipLibraryClient: brushTipLibraryClient,
            textFontLibraryClient: textFontLibraryClient
        )
    }
}

extension DependencyValues {
    var brushImportClient: BrushImportClient {
        get { self[BrushImportClientKey.self] }
        set { self[BrushImportClientKey.self] = newValue }
    }
}

func withSecurityScopedAccess<T>(to url: URL, _ work: () -> T) -> T {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
        if didAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
    return work()
}

enum NeverOperationFailure: OperationFailure, Equatable {}
