#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
SPARKLE_HOME="$(bash tools/sparkle.sh)"
BUILD_ROOT="${BUILD_ROOT:-${TMPDIR:-/private/tmp}/morning-canvas-build}"
APP_DIR="${BUILD_ROOT}/Morning Canvas.app"
ARCHIVE_PATH="${BUILD_ROOT}/Morning-Canvas.zip"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

rm -rf "${APP_DIR}" "${ARCHIVE_PATH}"
mkdir -p "${MACOS_DIR}"
clang -fobjc-arc -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 MorningCanvas.m -o "${MACOS_DIR}/MorningCanvas" -I "$(xcrun --show-sdk-path)/usr/include/libxml2" -lxml2 -F "$SPARKLE_HOME" -framework Sparkle -Wl,-rpath,@executable_path/../Frameworks -framework Cocoa -framework QuartzCore -framework WebKit -framework AVKit -framework AVFoundation -framework UniformTypeIdentifiers -framework LocalAuthentication -framework Security
cp Info.plist "${CONTENTS_DIR}/Info.plist"
ditto Resources "${CONTENTS_DIR}/Resources"
mkdir -p "${CONTENTS_DIR}/Frameworks"
ditto "${SPARKLE_HOME}/Sparkle.framework" "${CONTENTS_DIR}/Frameworks/Sparkle.framework"
codesign --force --sign - "${APP_DIR}"
codesign --verify --deep --strict "${APP_DIR}"
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ARCHIVE_PATH}"

echo "Built ${APP_DIR}"
echo "Packaged ${ARCHIVE_PATH}"
