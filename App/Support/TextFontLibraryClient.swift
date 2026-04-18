import ComposableArchitecture
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoBrushInfrastructure

typealias TextFontLibraryClient = PrimoBrushInfrastructure.TextFontLibraryClient

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
