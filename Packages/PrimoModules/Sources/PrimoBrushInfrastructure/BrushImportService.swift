import Foundation
import PrimoBrushFileFormats
import PrimoCoreTypes
import PrimoDocumentDomain

public struct BrushImportService: Sendable {
    public struct ImportFailure: LocalizedError, Equatable, Sendable {
        public let message: String

        public init(message: String) {
            self.message = message
        }

        public var errorDescription: String? { message }
    }

    public struct BrushTipImportFailure: LocalizedError, Equatable, OperationFailure {
        public let message: String

        public init(message: String) {
            self.message = message
        }

        public var errorDescription: String? { message }
    }

    public var importBrushTipSamples: @Sendable ([URL]) -> [Result<[ImportedPhotoshopBrushSample], ImportFailure>]
    public var importTextFonts: @Sendable ([URL]) -> [Result<[TextFontOption], ImportFailure>]
    public var loadCustomTip: @Sendable (URL) -> Result<BrushTipRaster, BrushTipImportFailure>

    public init(
        importBrushTipSamples: @escaping @Sendable ([URL]) -> [Result<[ImportedPhotoshopBrushSample], ImportFailure>],
        importTextFonts: @escaping @Sendable ([URL]) -> [Result<[TextFontOption], ImportFailure>],
        loadCustomTip: @escaping @Sendable (URL) -> Result<BrushTipRaster, BrushTipImportFailure>
    ) {
        self.importBrushTipSamples = importBrushTipSamples
        self.importTextFonts = importTextFonts
        self.loadCustomTip = loadCustomTip
    }

    public static func live(
        brushTipLibraryClient: BrushTipLibraryClient,
        textFontLibraryClient: TextFontLibraryClient,
        securityScopedResourceClient: SecurityScopedResourceClient
    ) -> BrushImportService {
        BrushImportService(
            importBrushTipSamples: { urls in
                urls.map { url in
                    let didAccess = securityScopedResourceClient.startAccessing(url)
                    defer {
                        if didAccess {
                            securityScopedResourceClient.stopAccessing(url)
                        }
                    }
                    do {
                        if url.pathExtension.lowercased() == "abr" {
                            return .success(try brushTipLibraryClient.importPhotoshopBrushSamples(url))
                        }

                        let brushName = url.deletingPathExtension().lastPathComponent
                        let tip = try brushTipLibraryClient.loadRaster(url)
                        return .success([ImportedPhotoshopBrushSample(name: brushName, tip: tip)])
                    } catch {
                        return .failure(
                            ImportFailure(message: "\(url.lastPathComponent): \(error.localizedDescription)")
                        )
                    }
                }
            },
            importTextFonts: { urls in
                urls.map { url in
                    let didAccess = securityScopedResourceClient.startAccessing(url)
                    defer {
                        if didAccess {
                            securityScopedResourceClient.stopAccessing(url)
                        }
                    }
                    do {
                        return .success(try textFontLibraryClient.importFonts([url]))
                    } catch {
                        return .failure(
                            ImportFailure(message: "\(url.lastPathComponent): \(error.localizedDescription)")
                        )
                    }
                }
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
                        BrushTipImportFailure(message: "\(url.lastPathComponent): \(error.localizedDescription)")
                    )
                }
            }
        )
    }
}
