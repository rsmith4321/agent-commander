#!/bin/zsh
# Regenerates docs/menu.png from the example config. It briefly covers the
# top of your screen with a plain backdrop while it opens the menu.
# Needs Screen Recording permission for the app you run it from. It
# uses a Retina screen when one is connected.
set -euo pipefail
cd "${0:A:h}/.."
WORK=$(mktemp -d)
APP="$WORK/Agent Commander.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -D SCREENSHOT -o "$APP/Contents/MacOS/Agent Commander" Sources/*.swift Tools/MenuScreenshot.swift
sed 's/agent-commander</agent-commander.screenshot</' Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/example-config.json Resources/config-README.md Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP" 2>/dev/null
# Point the agents at /bin/echo so neither shows "(not found)".
sed 's#"command": "[^"]*"#"command": "/bin/echo"#' Resources/example-config.json > "$WORK/config.json"
AGENT_COMMANDER_CONFIG="$WORK/config.json" SHOT_OUT="$PWD/docs/menu.png" "$APP/Contents/MacOS/Agent Commander"
rm -rf "$WORK"
echo "Wrote docs/menu.png"
