import CoreGraphics
import Foundation
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoLocalization

enum WorkspaceLayoutMode: Equatable, Sendable {
    case single
    case splitRight
    case splitBelow
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
