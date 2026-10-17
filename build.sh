#!/bin/zsh
# Builds Agent Commander.app.
#   ./build.sh            build, install to ~/Applications and start it
#   ./build.sh --release  build a universal app and zip it in build/ (no install)
set -euo pipefail
cd "${0:A:h}"

NAME="Agent Commander"
APP="build/$NAME.app"
RELEASE=0
[[ "${1:-}" == "--release" ]] && RELEASE=1

rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if (( RELEASE )); then
  for arch in arm64 x86_64; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos13.0" -o "build/$arch" Sources/*.swift
  done
  lipo -create build/arm64 build/x86_64 -output "$APP/Contents/MacOS/$NAME"
  rm build/arm64 build/x86_64
else
  swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/$NAME" Sources/*.swift
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/example-config.json Resources/config-README.md Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

if (( RELEASE )); then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
  (cd build && ditto -c -k --keepParent "$NAME.app" "Agent-Commander-$VERSION.zip")
  echo "Built build/Agent-Commander-$VERSION.zip"
  exit 0
fi

DEST="$HOME/Applications/$NAME.app"
pkill -x "$NAME" 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST" && cp -R "$APP" "$DEST"
open "$DEST"
echo "Installed $DEST"
