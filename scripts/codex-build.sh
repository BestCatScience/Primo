#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild \
  -project Primo.xcodeproj \
  -scheme Primo \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages \
  CODE_SIGNING_ALLOWED=NO \
  build
