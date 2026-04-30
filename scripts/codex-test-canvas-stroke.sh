#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

DESTINATION="${PRIMO_TEST_DESTINATION:-platform=iOS Simulator,name=iPad Pro (11-inch)}"

xcodebuild test \
  -project Primo.xcodeproj \
  -scheme Primo \
  -destination "$DESTINATION" \
  -only-testing:PrimoTests/CanvasStrokeWorkflowTests \
  -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  APP_INTENTS_METADATA_PROCESSOR_FLAGS=--quiet-warnings \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_APP_INTENTS_METADATA_GENERATION=NO \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO
