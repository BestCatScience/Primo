import ComposableArchitecture
import Foundation
import PrimoCoreTypes

extension AppFeature {
    struct ShareExportFactory {
        let uuidClient: UUIDClient

        func makeShareExport(url: URL) -> ShareExport {
            ShareExport(id: uuidClient.generate(), url: url)
        }
    }

    var shareExportFactory: ShareExportFactory {
        ShareExportFactory(uuidClient: uuidClient)
    }

    func makeShareExport(url: URL) -> ShareExport {
        shareExportFactory.makeShareExport(url: url)
    }
}
