#!/bin/bash
# Baut "build/To Do.app". Mit "./build.sh install" wird die App zusätzlich nach ~/Applications kopiert.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP="build/To Do.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/StickyToDo "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
codesign --force --sign - "$APP" >/dev/null
echo "Fertig: $APP"

if [ "${1:-}" = "install" ]; then
    mkdir -p ~/Applications
    rm -rf ~/Applications/"To Do.app"
    cp -R "$APP" ~/Applications/
    echo "Installiert: ~/Applications/To Do.app"
fi
