import Foundation

extension AppFeature {
    func handleExportDocumentRequest(state: inout State) {
        guard let pngData = paintDocumentClient.compositePNGData(resolvedPaperStyle(for: state)) else {
            state.application.presentBanner(state.application.appLanguage.localized("Export failed"))
            return
        }
        do {
            let url = try documentWorkspaceClient.writePNGToTemporaryDirectory(pngData)
            state.export.presentShareSheet(makeShareExport(url: url))
        } catch {
            state.application.presentBanner(state.application.appLanguage.localized("Export failed"))
        }
    }
}
