#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

typeset -a candidates
candidates=(
  "$ROOT_DIR/build/SourcePackages/checkouts/swift-navigation/Package.swift"
)

if [[ -n "${BUILD_DIR:-}" ]]; then
  DERIVED_DATA_DIR="${BUILD_DIR%%/Build/*}"
  if [[ "$DERIVED_DATA_DIR" != "$BUILD_DIR" ]]; then
    candidates+=("$DERIVED_DATA_DIR/SourcePackages/checkouts/swift-navigation/Package.swift")
  fi
fi

setopt NULL_GLOB
candidates+=("$HOME"/Library/Developer/Xcode/DerivedData/Primo-*/SourcePackages/checkouts/swift-navigation/Package.swift)

for package_file in "${candidates[@]}"; do
  [[ -f "$package_file" ]] || continue
  if ! grep -q 'CasePathsCore", package: "swift-case-paths"' "$package_file"; then
    # Xcode 26 links package products dynamically; SwiftNavigation imports CasePathsCore directly.
    perl -0pi -e 's/\.product\(name: "CasePaths", package: "swift-case-paths"\),/\.product(name: "CasePaths", package: "swift-case-paths"),\n        .product(name: "CasePathsCore", package: "swift-case-paths"),/' "$package_file"
  fi
done
