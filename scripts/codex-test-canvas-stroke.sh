#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

resolve_destination() {
  if [[ -n "${PRIMO_TEST_DESTINATION:-}" ]]; then
    print -r -- "$PRIMO_TEST_DESTINATION"
    return
  fi

  local destinations
  destinations="$(xcodebuild -project Primo.xcodeproj -scheme Primo -showdestinations 2>/dev/null || true)"

  local preferred_names=(
    "iPad Pro 11-inch (M5)"
    "iPad Pro 13-inch (M5)"
    "iPad Air 11-inch (M4)"
    "iPad Air 13-inch (M4)"
    "iPad (A16)"
    "iPad mini (A17 Pro)"
    "iPad Pro (11-inch)"
  )

  local name
  for name in "${preferred_names[@]}"; do
    if [[ "$destinations" == *"name:$name"* || "$destinations" == *"name: $name"* ]]; then
      print -r -- "platform=iOS Simulator,name=$name"
      return
    fi
  done

  local discovered_name
  discovered_name="$(
    print -r -- "$destinations" \
      | sed -nE 's/.*platform:iOS Simulator,.*name:([^,}]+).*/\1/p' \
      | head -n 1 \
      | xargs
  )"

  if [[ -n "$discovered_name" ]]; then
    print -r -- "platform=iOS Simulator,name=$discovered_name"
  else
    print -r -- "generic/platform=iOS Simulator"
  fi
}

DESTINATION="$(resolve_destination)"
print -r -- "Using test destination: $DESTINATION" >&2

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
