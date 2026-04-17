import Foundation

struct ShareExport: Equatable, Identifiable {
    let id: UUID
    let url: URL

    init(id: UUID, url: URL) {
        self.id = id
        self.url = url
    }
}

struct TimelapseExportPreview: Equatable {
    var progress: Double
    var previewImageData: Data?
}

enum StudioPanelKind: String, CaseIterable, Equatable {
    case brush
    case layers

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .brush:
            return language.localized("ブラシ")
        case .layers:
            return language.localized("レイヤー")
        }
    }
}

enum HomeSidebarSection: String, CaseIterable, Equatable {
    case home
    case learn

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .home:
            return language.localized("ホーム")
        case .learn:
            return language.localized("学ぶ")
        }
    }

    var iconSystemName: String {
        switch self {
        case .home:
            return "house.fill"
        case .learn:
            return "lightbulb"
        }
    }
}

struct StudioPanelLayoutState: Equatable {
    var isCollapsed: Bool = false
}

enum PendingCloseOperation: Equatable {
    case tab(OpenDocumentTab.ID)
    case closeOtherTabs(OpenDocumentTab.ID)
    case closeTabsToRight(OpenDocumentTab.ID)
}

struct PendingCloseConfirmationState: Equatable {
    let operation: PendingCloseOperation
    let tabIDs: [OpenDocumentTab.ID]
    let tabTitles: [String]
}
