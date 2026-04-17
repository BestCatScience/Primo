import Foundation

extension AppFeature {
    func handleExportDocumentRequest(state: inout State) {
        guard let pngData = compositePNGData(state: state) else {
            state.application.presentBanner(state.application.appLanguage.localized("Export failed"))
            return
        }
        do {
            let url = try workspaceStorageService.writePNGToTemporaryDirectory(pngData)
            state.export.presentShareSheet(makeShareExport(url: url))
        } catch {
            state.application.presentBanner(state.application.appLanguage.localized("Export failed"))
        }
    }
}
