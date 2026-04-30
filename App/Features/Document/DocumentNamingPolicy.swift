import Foundation

extension DocumentFeature {
    struct DocumentNamingPolicy: Equatable {
        let language: AppLanguage

        func defaultLayerName(for layerSidebar: LayerSidebarFeature.State) -> String {
            layerSidebar.numberedLayerName(prefix: "Layer")
        }

        func folderName(forOrdinal ordinal: Int) -> String {
            StudioStrings.folderName(ordinal, language)
        }

        func duplicatedLayerName(for originalName: String) -> String {
            language == .japanese ? "\(originalName) のコピー" : "\(originalName) Copy"
        }

        func photoLayerName(
            proposedName: String?,
            layerSidebar: LayerSidebarFeature.State
        ) -> String {
            let fallbackName = layerSidebar.numberedLayerName(
                prefix: language == .japanese ? "写真" : "Photo"
            )
            let trimmedName = proposedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmedName.isEmpty ? fallbackName : trimmedName
        }

        func textLayerName(from draftText: String) -> String {
            let trimmedLine = draftText
                .components(separatedBy: CharacterSet.newlines)
                .first?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if let trimmedLine, !trimmedLine.isEmpty {
                return trimmedLine
            }
            return language == .japanese ? "テキスト" : "Text"
        }

        func importedCanvasLayerName(from proposedName: String?) -> String {
            let trimmedName = proposedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedName.isEmpty {
                return trimmedName
            }
            return language == .japanese ? "画像 1" : "Image 1"
        }

        func aiImageLayerName(for layerSidebar: LayerSidebarFeature.State) -> String {
            layerSidebar.numberedLayerName(prefix: "AI Image")
        }
    }
}
