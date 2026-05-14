#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/Packages/PrimoModules"
SNAPSHOT_DIR="$PACKAGE_DIR/Tests/PrimoDocumentEngineInfrastructureTests/__Snapshots__/SymbolGraphs"
SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/primo-symbolgraph.XXXXXX")"

cleanup() {
  rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT

mkdir -p "$SNAPSHOT_DIR"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

dump_status=0
swift package \
  --package-path "$PACKAGE_DIR" \
  --scratch-path "$SCRATCH_DIR" \
  dump-symbol-graph \
  --minimum-access-level public \
  --skip-synthesized-members || dump_status=$?

for module in PrimoDocumentRuntime PrimoWorkspaceRuntime; do
  symbol_graph="$(
    find "$SCRATCH_DIR" \
      -name "$module.symbols.json" \
      ! -name '*@*' \
      -print \
      -quit
  )"
  if [[ -z "$symbol_graph" ]]; then
    echo "missing symbol graph for $module" >&2
    exit "$dump_status"
  fi
  "$ROOT_DIR/scripts/normalize-symbolgraph.swift" "$symbol_graph" > "$SNAPSHOT_DIR/$module.symbols.tsv"
done
