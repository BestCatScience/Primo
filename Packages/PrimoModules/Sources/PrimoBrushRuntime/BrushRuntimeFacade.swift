import Foundation
import PrimoBrushDomain
import PrimoBrushFileFormats
import PrimoBrushInfrastructure
import PrimoBrushRuntimeContracts
import PrimoCoreTypes
import PrimoDocumentDomain

public struct BrushTipLibraryClient: Sendable {
    public let loadRaster: @Sendable (URL) throws -> BrushTipRaster
    public let prepareBrushTipFile: @Sendable (URL) throws -> URL
    public let importPhotoshopBrushSamples: @Sendable (URL) throws -> [ImportedPhotoshopBrushSample]

    public init(
        loadRaster: @escaping @Sendable (URL) throws -> BrushTipRaster,
        prepareBrushTipFile: @escaping @Sendable (URL) throws -> URL,
        importPhotoshopBrushSamples: @escaping @Sendable (URL) throws -> [ImportedPhotoshopBrushSample]
    ) {
        self.loadRaster = loadRaster
        self.prepareBrushTipFile = prepareBrushTipFile
        self.importPhotoshopBrushSamples = importPhotoshopBrushSamples
    }

    public static func live(fileClient: FileClient) -> BrushTipLibraryClient {
        let client = PrimoBrushInfrastructure.BrushTipLibraryClient.live(fileClient: fileClient)
        return BrushTipLibraryClient(
            loadRaster: client.loadRaster,
            prepareBrushTipFile: client.prepareBrushTipFile,
            importPhotoshopBrushSamples: client.importPhotoshopBrushSamples
        )
    }

    fileprivate var infrastructureClient: PrimoBrushInfrastructure.BrushTipLibraryClient {
        PrimoBrushInfrastructure.BrushTipLibraryClient(
            loadRaster: loadRaster,
            prepareBrushTipFile: prepareBrushTipFile,
            importPhotoshopBrushSamples: importPhotoshopBrushSamples
        )
    }
}

public struct TextFontLibraryClient: Sendable {
    public let loadAvailableFonts: @Sendable () -> [TextFontOption]
    public let importFonts: @Sendable ([URL]) throws -> [TextFontOption]

    public init(
        loadAvailableFonts: @escaping @Sendable () -> [TextFontOption],
        importFonts: @escaping @Sendable ([URL]) throws -> [TextFontOption]
    ) {
        self.loadAvailableFonts = loadAvailableFonts
        self.importFonts = importFonts
    }

    public static func live(fileClient: FileClient) -> TextFontLibraryClient {
        let client = PrimoBrushInfrastructure.TextFontLibraryClient.live(fileClient: fileClient)
        return TextFontLibraryClient(
            loadAvailableFonts: client.loadAvailableFonts,
            importFonts: client.importFonts
        )
    }

    fileprivate var infrastructureClient: PrimoBrushInfrastructure.TextFontLibraryClient {
        PrimoBrushInfrastructure.TextFontLibraryClient(
            loadAvailableFonts: loadAvailableFonts,
            importFonts: importFonts
        )
    }
}

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

    public let importBrushTipSamples: @Sendable ([URL]) -> [Result<[ImportedPhotoshopBrushSample], ImportFailure>]
    public let importTextFonts: @Sendable ([URL]) -> [Result<[TextFontOption], ImportFailure>]
    public let loadCustomTip: @Sendable (URL) -> Result<BrushTipRaster, BrushTipImportFailure>

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
        let service = PrimoBrushInfrastructure.BrushImportService.live(
            brushTipLibraryClient: brushTipLibraryClient.infrastructureClient,
            textFontLibraryClient: textFontLibraryClient.infrastructureClient,
            securityScopedResourceClient: securityScopedResourceClient
        )
        return BrushImportService(
            importBrushTipSamples: { urls in
                service.importBrushTipSamples(urls).map { result in
                    result.mapError { ImportFailure(message: $0.message) }
                }
            },
            importTextFonts: { urls in
                service.importTextFonts(urls).map { result in
                    result.mapError { ImportFailure(message: $0.message) }
                }
            },
            loadCustomTip: { url in
                service.loadCustomTip(url).mapError { BrushTipImportFailure(message: $0.message) }
            }
        )
    }
}
