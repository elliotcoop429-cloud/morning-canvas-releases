#!/bin/bash
set -euo pipefail
SPARKLE_VERSION=2.9.6
SPARKLE_SHA256=52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192
SPARKLE_HOME="${HOME}/Library/Caches/MorningCanvasBuild/Sparkle-${SPARKLE_VERSION}"
if [[ ! -x "${SPARKLE_HOME}/bin/generate_appcast" ]]; then
    archive="$(mktemp -t morningcanvas-sparkle)"
    trap 'rm -f "$archive"' EXIT
    curl --fail --location --retry 3 "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" -o "$archive"
    actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
    [[ "$actual" == "$SPARKLE_SHA256" ]] || { echo 'Sparkle checksum mismatch' >&2; exit 1; }
    mkdir -p "$SPARKLE_HOME"
    tar -xf "$archive" -C "$SPARKLE_HOME"
fi
codesign --verify --deep --strict "${SPARKLE_HOME}/Sparkle.framework"
printf '%s\n' "$SPARKLE_HOME"
