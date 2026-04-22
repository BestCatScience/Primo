import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoLocalization

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
