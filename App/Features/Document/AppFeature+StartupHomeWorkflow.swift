import ComposableArchitecture
import Foundation

extension AppFeature {
    func makeShareExport(url: URL) -> ShareExport {
        ShareExport(id: uuidClient.generate(), url: url)
    }
}
