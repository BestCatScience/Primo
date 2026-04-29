import Foundation
import SwiftUI

struct ThirdPartyNotice: Decodable, Identifiable {
    let packageIdentity: String
    let name: String
    let location: String
    let version: String?
    let revision: String
    let licenseName: String
    let licenseText: String

    var id: String { packageIdentity }

    var versionLabel: String {
        if let version {
            return version
        }
        return String(revision.prefix(7))
    }
}

enum ThirdPartyNoticeLoader {
    static func load(bundle: Bundle = .main) -> [ThirdPartyNotice] {
        guard
            let url = bundle.url(forResource: "ThirdPartyNotices", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let notices = try? JSONDecoder().decode([ThirdPartyNotice].self, from: data)
        else {
            return []
        }
        return notices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

struct ThirdPartyLicensesView: View {
    let language: AppLanguage
    let onClose: () -> Void

    private let notices: [ThirdPartyNotice]

    init(
        language: AppLanguage,
        notices: [ThirdPartyNotice] = ThirdPartyNoticeLoader.load(),
        onClose: @escaping () -> Void
    ) {
        self.language = language
        self.notices = notices
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(StudioStrings.openSourceLicensesSummary(language, notices.count))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section(StudioStrings.openSourcePackages(language)) {
                    ForEach(notices) { notice in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 12) {
                                LabeledContent(StudioStrings.packageURL(language), value: notice.location)
                                LabeledContent(StudioStrings.packageVersion(language), value: notice.versionLabel)
                                LabeledContent(StudioStrings.licenseType(language), value: notice.licenseName)

                                Divider()

                                Text(notice.licenseText)
                                    .font(.system(.footnote, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 8)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(notice.name)
                                    .font(.body.weight(.medium))
                                Text("\(notice.packageIdentity) - \(notice.versionLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(StudioStrings.openSourceLicenses(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language), action: onClose)
                }
            }
        }
    }
}
