import Foundation

extension AppFeature {
    func handleExportDocumentRequest(state: inout State) {
        guard let pngData = paintDocumentClient.compositePNGData(state.resolvedPaperStyle()) else {
            state.application.presentBanner(state.appLanguage.localized("Export failed"))
            return
        }
        do {
            let url = try documentWorkspaceClient.writePNGToTemporaryDirectory(pngData)
            state.export.shareSheet = makeShareExport(url: url)
        } catch {
            state.application.presentBanner(state.appLanguage.localized("Export failed"))
        }
    }
}
