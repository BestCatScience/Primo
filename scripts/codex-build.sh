#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
DERIVED_DATA_PATH=${DERIVED_DATA_PATH:-/tmp/atelierprime-codex-build}
PACKAGE_CACHE_PATH=${PACKAGE_CACHE_PATH:-/tmp/atelierprime-package-cache}
SOURCE_PACKAGES_DIR=${SOURCE_PACKAGES_DIR:-$HOME/Library/Developer/Xcode/DerivedData/atelierprime-gruuszhkrmiexzgjfbedzywqxddp/SourcePackages}

if [[ ! -d "$SOURCE_PACKAGES_DIR/checkouts" ]]; then
  echo "Missing SourcePackages checkouts at: $SOURCE_PACKAGES_DIR" >&2
  echo "Set SOURCE_PACKAGES_DIR to a populated Xcode SourcePackages directory before running this script." >&2
  exit 1
fi

mkdir -p "$DERIVED_DATA_PATH" "$PACKAGE_CACHE_PATH"

cd "$REPO_ROOT"

exec xcodebuild \
  -project atelierprime.xcodeproj \
  -scheme atelierprime \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
  -packageCachePath "$PACKAGE_CACHE_PATH" \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO \
  build \
  "$@"
