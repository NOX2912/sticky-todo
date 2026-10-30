#!/bin/bash
# ./build.sh                  baut "build/To Do.app"
# ./build.sh install          baut und kopiert die App nach ~/Applications
# ./build.sh beta 1.1         wie release, aber als Pre-Release: der In-App-Updater sieht es nicht
# ./build.sh promote 1.1      macht aus dem Pre-Release das neueste Release, ab dann kommt das Update bei allen an
# ./build.sh release 1.1      setzt die Version, testet, committet, pusht und veröffentlicht ein GitHub-Release
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-}" in
release | beta)
    VERSION="${2:?Version fehlt, z. B.: ./build.sh $1 1.1}"
    swift test
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" Resources/Info.plist
    ;;
promote)
    VERSION="${2:?Version fehlt, z. B.: ./build.sh promote 1.1}"
    gh release edit "v$VERSION" --prerelease=false --latest
    exit
    ;;
esac

swift build -c release
APP="build/To Do.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/StickyToDo "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
codesign --force --sign - "$APP" >/dev/null
echo "Fertig: $APP"

case "${1:-}" in
install)
    mkdir -p ~/Applications
    rm -rf ~/Applications/"To Do.app"
    cp -R "$APP" ~/Applications/
    echo "Installiert: ~/Applications/To Do.app"
    ;;
release | beta)
    ditto -c -k --keepParent "$APP" build/ToDo.zip
    git commit -qam "Version $VERSION"
    git push -q
    PRERELEASE=""
    if [ "$1" = beta ]; then PRERELEASE="--prerelease"; fi
    gh release create "v$VERSION" build/ToDo.zip --title "$VERSION" --generate-notes ${PRERELEASE:+"$PRERELEASE"}
    ;;
esac
