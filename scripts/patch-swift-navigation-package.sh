#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_PATH="${1:-$ROOT_DIR/build/SourcePackages/checkouts/swift-navigation/Package.swift}"

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "SwiftNavigation Package.swift not found at: $MANIFEST_PATH" >&2
  echo "Run xcodebuild -resolvePackageDependencies before this script." >&2
  exit 1
fi

chmod u+w "$MANIFEST_PATH"

python3 - "$MANIFEST_PATH" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
original = text

swift_navigation_old = '''        .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
        .product(name: "OrderedCollections", package: "swift-collections"),'''
swift_navigation_new = '''        .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
        .product(name: "OrderedCollections", package: "swift-collections"),'''

if swift_navigation_new not in text and swift_navigation_old in text:
    text = text.replace(swift_navigation_old, swift_navigation_new, 1)

uikit_navigation_old = '''        "SwiftNavigation",
        "UIKitNavigationShim",
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),'''
uikit_navigation_new = '''        "SwiftNavigation",
        "UIKitNavigationShim",
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "CasePathsCore", package: "swift-case-paths"),
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
        .product(name: "OrderedCollections", package: "swift-collections"),
        .product(name: "Perception", package: "swift-perception"),
        .product(name: "PerceptionCore", package: "swift-perception"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),'''

if uikit_navigation_new not in text and uikit_navigation_old in text:
    text = text.replace(uikit_navigation_old, uikit_navigation_new, 1)

if text != original:
    path.write_text(text)
    print(f"Patched SwiftNavigation manifest: {path}")
else:
    print(f"SwiftNavigation manifest already patched or did not need patching: {path}")
PY
