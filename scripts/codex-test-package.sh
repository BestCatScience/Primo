#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR/Packages/PrimoModules"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

swift test
