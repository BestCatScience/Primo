import ComposableArchitecture
import Foundation
import PrimoBrushFileFormats
import PrimoBrushInfrastructure
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoLocalization

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
    let importBrushPresets: @Sendable (BrushPresetImportRequest) -> BrushPresetImportResult
    let importTextFonts: @Sendable (TextFontImportRequest) -> TextFontImportResult
    let loadCustomTip: @Sendable (URL) -> Result<BrushTipRaster, BrushTipImportFailure>

    static func live(
        brushTipLibraryClient: BrushTipLibraryClient,
        textFontLibraryClient: TextFontLibraryClient,
        securityScopedResourceClient: SecurityScopedResourceClient
    ) -> BrushImportClient {
        let packageBrushTipLibraryClient = PrimoBrushInfrastructure.BrushTipLibraryClient(
            loadRaster: brushTipLibraryClient.loadRaster,
            prepareBrushTipFile: brushTipLibraryClient.prepareBrushTipFile,
            importPhotoshopBrushSamples: { url in
                try brushTipLibraryClient.importPhotoshopBrushes(url).map {
                    ImportedPhotoshopBrushSample(name: $0.name, tip: $0.tip)
                }
            }
        )
        let packageTextFontLibraryClient = PrimoBrushInfrastructure.TextFontLibraryClient(
            loadAvailableFonts: textFontLibraryClient.loadAvailableFonts,
            importFonts: textFontLibraryClient.importFonts
        )
        let service = PrimoBrushInfrastructure.BrushImportService.live(
            brushTipLibraryClient: packageBrushTipLibraryClient,
            textFontLibraryClient: packageTextFontLibraryClient,
            securityScopedResourceClient: securityScopedResourceClient
        )
        return BrushImportClient(
            importBrushPresets: { request in
                var imported: [BrushPreset] = []
                var failures: [String] = []

                for result in service.importBrushTipSamples(request.urls) {
                    switch result {
                    case let .success(samples):
                        let brushes = samples.map {
                            BrushPreset.photoshopImported(name: $0.name, tip: $0.tip)
                        }
                        if brushes.isEmpty {
                            failures.append(request.language.localized("対応している先端が見つかりませんでした。"))
                        } else {
                            imported.append(contentsOf: brushes)
                        }
                    case let .failure(failure):
                        failures.append(failure.message)
                    }
                }

                return BrushPresetImportResult(presets: imported, failureMessages: failures)
            },
            importTextFonts: { request in
                var importedFonts: [TextFontOption] = []
                var failures: [String] = []

                for result in service.importTextFonts(request.urls) {
                    switch result {
                    case let .success(fonts):
                        importedFonts.append(contentsOf: fonts)
                    case let .failure(failure):
                        failures.append(failure.message)
                    }
                }

                return TextFontImportResult(fonts: importedFonts, failureMessages: failures)
            },
            loadCustomTip: { url in
                switch service.loadCustomTip(url) {
                case let .success(tip):
                    return .success(tip)
                case let .failure(failure):
                    return .failure(.loadFailed(failure.message))
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
