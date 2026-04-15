import CoreGraphics
import Foundation

struct SavedProjectSummary: Equatable, Sendable, Identifiable {
    let url: URL
    let name: String
    let relativeFolderPath: String?
    let modifiedAt: Date
    let canvasSize: CGSize
    let layerCount: Int
    let previewImageData: Data?

    var id: URL { url }
}

struct PaintDocumentPresentation: Equatable, Sendable {
    var canvasSize: CGSize
    var activeLayerIndex: Int
    var layerRows: [LayerRowModel]
    var layerSidebarRows: [LayerSidebarRowModel]
    var renderSnapshot: MetalDocumentSnapshot?
}

struct LoadedPaintProject: Equatable, Sendable {
    var presentation: PaintDocumentPresentation
    var paperStyle: CanvasPaperStyle
}

enum WorkspacePane: String, CaseIterable, Equatable, Sendable {
    case primary
    case secondary
}

enum WorkspaceLayoutMode: Equatable, Sendable {
    case single
    case split
}

struct OpenDocumentTab: Equatable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var backingStoreURL: URL
    var sourceProjectURL: URL?
    var canvasSize: CGSize
    var isDirty: Bool
    var pane: WorkspacePane
    var previewImageData: Data?
}

struct AutosaveRecoveryItem: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let sourceProjectURL: URL?
    let autosaveProjectURL: URL
    let updatedAt: Date
    let previewImageData: Data?
}

enum SaveHistoryTrigger: String, Codable, Equatable, Sendable {
    case manualSave
    case autoSave
    case closeSave

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .manualSave:
            return language.localized("手動保存")
        case .autoSave:
            return language.localized("自動保存")
        case .closeSave:
            return language.localized("閉じる前に保存")
        }
    }
}

struct SaveHistoryEntry: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let projectURL: URL
    let createdAt: Date
    let trigger: SaveHistoryTrigger
    let previewImageData: Data?
}

enum ColorRangeSelectionSource: String, CaseIterable, Equatable, Sendable, Identifiable {
    case activeLayer
    case canvas

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .activeLayer:
            return language.localized("アクティブレイヤー")
        case .canvas:
            return language.localized("キャンバス合成")
        }
    }
}

struct ColorRangeSelectionRequest: Equatable, Sendable {
    let source: ColorRangeSelectionSource
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let tolerance: Double
    let minimumAlpha: Double
    let expansion: Int
}
