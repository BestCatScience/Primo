# Forked Dependencies

Primo pins selected Swift package dependencies by revision in `project.yml` and
`Primo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
Revision pins keep local builds reproducible, but forked dependencies need an
extra review trail before external distribution.

## Current Forks

| Package | Fork revision | Upstream | Why the fork is used |
| --- | --- | --- | --- |
| `swift-composable-architecture` | `8970b5088dbcde3c4e8d2c88e52f46a74f2f6071` | `pointfreeco/swift-composable-architecture` | The fork's `Package.swift` points its `swift-navigation` dependency at the Primo `BestCatScience/swift-navigation` fork revision. |
| `swift-navigation` | `86539f79492bd7188da219a96dc0053a6e3a327b` | `pointfreeco/swift-navigation` | The fork adds the missing `CasePathsCore` product dependency to `SwiftNavigation` so the project resolves and builds with the pinned package graph. |

## Upstream Differences

- `BestCatScience/swift-composable-architecture`
  changes only `Package.swift` from the checked-out revision: it replaces the
  upstream `swift-navigation` version requirement with the pinned
  `BestCatScience/swift-navigation` revision.
- `BestCatScience/swift-navigation`
  changes only `Package.swift` from the checked-out revision: it adds
  `.product(name: "CasePathsCore", package: "swift-case-paths")` to the
  `SwiftNavigation` target dependencies.

When either fork is bumped, verify the difference with:

```bash
git -C build/SourcePackages/checkouts/swift-composable-architecture show --stat --patch HEAD -- Package.swift
git -C build/SourcePackages/checkouts/swift-navigation show --stat --patch HEAD -- Package.swift
```

## Returning Upstream

Move back to upstream packages when both conditions are true:

- Upstream `swift-navigation` declares the `CasePathsCore` dependency needed by
  Primo's pinned package graph, or Primo no longer needs that dependency edge.
- Upstream `swift-composable-architecture` can resolve against the upstream
  `swift-navigation` release without a local manifest override.

The return path is to replace the fork URLs in `project.yml` with upstream
URLs and version requirements, regenerate `Primo.xcodeproj` / `Package.resolved`,
then run the quality gate documented in `README.md`.

## Security Updates

- Review upstream releases and security advisories before app distribution
  milestones and whenever Swift / Xcode is upgraded.
- Prefer upstream releases over fork bumps. If the fork must stay, merge or
  cherry-pick only the minimum upstream security fix into the fork and pin the
  resulting revision.
- Every fork bump must include the new revision, a short reason, and a summary
  of the upstream diff in this file.

## Third-Party Notices

`App/Support/ThirdPartyNotices.json` is the in-app license source. When a
package URL, revision, version, package name, or license changes:

- update the matching entry in `App/Support/ThirdPartyNotices.json`;
- keep forked package locations pointing at the actual fork URL used by
  `project.yml`;
- verify the license text against the dependency checkout before release.
