#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tests/DesignerTests.py
if [[ "$(uname -s)" == Darwin ]]; then
  executable="$(mktemp -t MorningCanvasDesignerTests)"
  trap 'rm -f "$executable"' EXIT
  clang -fobjc-arc -mmacosx-version-min=14.0 tests/DesignerTests.m -framework Cocoa -o "$executable"
  "$executable"
fi
