#!/bin/bash
# ./build.sh                  baut "build/To Do.app"
# ./build.sh install          baut und kopiert die App nach ~/Applications
# ./build.sh release 1.1      setzt die Version, committet, pusht und veröffentlicht ein GitHub-Release
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "release" ]; then
    VERSION="${2:?Version fehlt, z. B.: ./build.sh release 1.1}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" Resources/Info.plist
fi

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
release)
    ditto -c -k --keepParent "$APP" build/ToDo.zip
    git commit -qam "Version $VERSION"
    git push -q
    gh release create "v$VERSION" build/ToDo.zip --title "$VERSION" --generate-notes
    ;;
esac
