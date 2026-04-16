import Foundation

extension AppFeature {
    func handleExportDocumentRequest(state: inout State) {
        guard let pngData = paintDocumentClient.compositePNGData(state.resolvedPaperStyle()) else {
            state.bannerMessage = state.appLanguage.localized("Export failed")
            return
        }
        do {
            let url = try documentWorkspaceClient.writePNGToTemporaryDirectory(pngData)
            state.exportSheet = makeShareExport(url: url)
        } catch {
            state.bannerMessage = state.appLanguage.localized("Export failed")
        }
    }
}
