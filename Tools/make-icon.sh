#!/bin/zsh
# Rebuilds Resources/AppIcon.icns and docs/icon.png from Sources/Glyph.swift.
set -euo pipefail
cd "${0:A:h}/.."
WORK=$(mktemp -d)
swiftc -O -swift-version 5 -o "$WORK/make-icon" Sources/Glyph.swift Tools/make-icon/main.swift
"$WORK/make-icon" "$WORK/AppIcon.iconset"
iconutil -c icns -o Resources/AppIcon.icns "$WORK/AppIcon.iconset"
cp "$WORK/AppIcon.iconset/icon_128x128@2x.png" docs/icon.png
rm -rf "$WORK"
echo "Wrote Resources/AppIcon.icns and docs/icon.png"
