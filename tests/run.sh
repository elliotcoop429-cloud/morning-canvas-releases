#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SPARKLE_HOME="$(bash tools/sparkle.sh)"
for suite in Loading Media School; do
    executable="${TMPDIR:-/private/tmp}/MorningCanvas${suite}Tests"
    clang -fobjc-arc -mmacosx-version-min=14.0 "tests/${suite}Tests.m" -o "$executable" \
        -I "$(xcrun --show-sdk-path)/usr/include/libxml2" -lxml2 \
        -F "$SPARKLE_HOME" -framework Sparkle "-Wl,-rpath,$SPARKLE_HOME" \
        -framework Cocoa -framework QuartzCore -framework WebKit -framework AVKit \
        -framework AVFoundation -framework UniformTypeIdentifiers \
        -framework LocalAuthentication -framework Security
    "$executable"
done
