import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoLocalization

typealias CanvasPaperStyle = PrimoDocumentDomain.CanvasPaperStyle
typealias DocumentProjectPath = PrimoDocumentDomain.DocumentProjectPath
typealias WorkspaceItemID = PrimoDocumentDomain.WorkspaceItemID
typealias RelativeProjectFolderPath = PrimoDocumentDomain.RelativeProjectFolderPath
typealias DocumentWorkspaceError = PrimoDocumentDomain.DocumentWorkspaceError
typealias SavedProjectSummary = PrimoDocumentDomain.SavedProjectSummary
typealias WorkspacePane = PrimoDocumentDomain.WorkspacePane
typealias OpenDocumentTab = PrimoDocumentDomain.OpenDocumentTab
typealias AutosaveRecoveryItem = PrimoDocumentDomain.AutosaveRecoveryItem
typealias SaveHistoryTrigger = PrimoDocumentDomain.SaveHistoryTrigger
typealias SaveHistoryEntry = PrimoDocumentDomain.SaveHistoryEntry
typealias TextFontOption = PrimoDocumentDomain.TextFontOption
typealias TextLayerData = PrimoDocumentDomain.TextLayerData
typealias TextLayerDraft = PrimoDocumentDomain.TextLayerDraft
typealias DocumentLayerIndex = PrimoDocumentDomain.DocumentLayerIndex
typealias DocumentFolderID = PrimoDocumentDomain.DocumentFolderID
typealias ColorRangeSelectionSource = PrimoDocumentDomain.ColorRangeSelectionSource
typealias ColorRangeSelectionRequest = PrimoDocumentDomain.ColorRangeSelectionRequest

typealias PaintDocumentPresentation = PrimoDocumentContracts.PaintDocumentPresentation
typealias LoadedPaintProject = PrimoDocumentContracts.LoadedPaintProject
typealias TransformQuad = PrimoDocumentContracts.TransformQuad
typealias TransformQuadOffsets = PrimoDocumentContracts.TransformQuadOffsets

enum WorkspaceLayoutMode: Equatable, Sendable {
    case single
    case split
}

extension SaveHistoryTrigger {
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

extension ColorRangeSelectionSource {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .activeLayer:
            return language.localized("アクティブレイヤー")
        case .canvas:
            return language.localized("キャンバス合成")
        }
    }
}

enum CanvasTransformMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case standard
    case freeform

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .standard:
            return language.localized("拡大、縮小、回転")
        case .freeform:
            return language.localized("自由変形")
        }
    }
}
