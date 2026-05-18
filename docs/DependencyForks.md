# Forked Dependencies

Primo pins selected Swift package dependencies by revision in `project.yml` and
`Primo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
Revision pins keep local builds reproducible, but forked dependencies need an
extra review trail before external distribution.

`docs/dependency-forks.json` is the machine-readable source of truth for the
fork URL and revision pins. Keep this document human-readable, but update both
files in the same change whenever a fork is added, removed, or bumped.

## Current Forks

| Package | Fork revision | Upstream | Reason ID | Why the fork is used |
| --- | --- | --- | --- | --- |
| `ComposableArchitecture` / `swift-composable-architecture` | `8970b5088dbcde3c4e8d2c88e52f46a74f2f6071` | `https://github.com/pointfreeco/swift-composable-architecture` | `pins-swift-navigation-fork` | The `https://github.com/BestCatScience/swift-composable-architecture` fork's `Package.swift` points its `swift-navigation` dependency at the Primo `BestCatScience/swift-navigation` fork revision. |
| `SwiftNavigation` / `swift-navigation` | `86539f79492bd7188da219a96dc0053a6e3a327b` | `https://github.com/pointfreeco/swift-navigation` | `adds-casepathscore-target-dependency` | The `https://github.com/BestCatScience/swift-navigation` fork adds the missing `CasePathsCore` product dependency to `SwiftNavigation` so the project resolves and builds with the pinned package graph. |

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

## Required Guardrails

- Run `scripts/verify-forked-dependencies.sh` before merging any change that
  touches `project.yml`, `Package.resolved`, fork documentation, or fork pins.
- CI runs the same script so a fork bump cannot update only one of
  `project.yml`, `Package.resolved`, `docs/dependency-forks.json`, or this file.
- The fork repositories should stay as small manifest-only forks. Do not carry
  app behavior changes in these forks.
- Keep the fork revision pin at an audited commit. Avoid floating branches and
  avoid widening the dependency requirement unless the project has returned to
  upstream.

## Rebase and Patch Policy

- Prefer rebasing each fork on the matching upstream release or commit, with the
  local manifest delta reapplied as a minimal patch.
- If a security fix must land before a clean rebase is practical, cherry-pick
  only the upstream fix and record the reason in this document.
- After any fork bump, rebuild the app package graph, verify the generated
  `Package.resolved`, and run the quality gate documented in `README.md`.
- If the upstream package now resolves without the fork, use the returning
  upstream path below instead of bumping the fork.

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
- Treat TCA updates as control-plane updates: review reducer, dependency, macro,
  observation, and navigation release notes before accepting a fork bump.
- Prefer upstream releases over fork bumps. If the fork must stay, merge or
  cherry-pick only the minimum upstream security fix into the fork and pin the
  resulting revision.
- Every fork bump must include the new revision, a short reason ID, a summary
  of the upstream diff in this file, and matching updates to
  `docs/dependency-forks.json`, `project.yml`, and `Package.resolved`.

## Third-Party Notices

`App/Support/ThirdPartyNotices.json` is the in-app license source. When a
package URL, revision, version, package name, or license changes:

- update the matching entry in `App/Support/ThirdPartyNotices.json`;
- keep forked package locations pointing at the actual fork URL used by
  `project.yml`;
- verify the license text against the dependency checkout before release.
