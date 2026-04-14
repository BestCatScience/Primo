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
