import ComposableArchitecture
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoBrushInfrastructure

private enum TextFontLibraryClientKey: DependencyKey {
    static var liveValue: PrimoBrushInfrastructure.TextFontLibraryClient {
        @Dependency(\.fileClient) var fileClient
        return .live(fileClient: fileClient)
    }
}

extension DependencyValues {
    var textFontLibraryClient: PrimoBrushInfrastructure.TextFontLibraryClient {
        get { self[TextFontLibraryClientKey.self] }
        set { self[TextFontLibraryClientKey.self] = newValue }
    }
}
