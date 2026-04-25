#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild \
  -resolvePackageDependencies \
  -project Primo.xcodeproj \
  -scheme Primo \
  -clonedSourcePackagesDirPath build/SourcePackages

scripts/patch-swift-navigation-package.sh

xcodebuild \
  -project Primo.xcodeproj \
  -scheme Primo \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages \
  CODE_SIGNING_ALLOWED=NO \
  build
