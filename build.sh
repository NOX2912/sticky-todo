#!/bin/bash
# ./build.sh                  baut "build/To Do.app"
# ./build.sh install          baut und kopiert die App nach ~/Applications
# ./build.sh beta 1.1         wie release, aber als Pre-Release: der In-App-Updater sieht es nicht
# ./build.sh promote 1.1      macht aus dem Pre-Release das neueste Release, ab dann kommt das Update bei allen an
# ./build.sh release 1.1      setzt die Version, testet, committet, pusht und veröffentlicht ein GitHub-Release
#                             (nur von master aus, damit der Tag genau den ausgelieferten Code enthält)
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-}" in
release | beta)
    VERSION="${2:?Version fehlt, z. B.: ./build.sh $1 1.1}"
    [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "Ungültige Version: $VERSION" >&2; exit 1; }
    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    [ "$BRANCH" = master ] || { echo "Releases nur von master aus (aktuell: $BRANCH)." >&2; exit 1; }
    # git commit -a nimmt neue Dateien nicht mit, swift build aber schon: Der Tag hätte dann anderen Code als die ZIP.
    UNTRACKED="$(git ls-files --others --exclude-standard -- Sources Tests Resources Package.swift)"
    if [ -n "$UNTRACKED" ]; then
        echo "Neue Dateien sind noch nicht in Git, erst git add:" >&2
        echo "$UNTRACKED" >&2
        exit 1
    fi
    swift test
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" Resources/Info.plist
    ;;
promote)
    VERSION="${2:?Version fehlt, z. B.: ./build.sh promote 1.1}"
    gh release edit "v$VERSION" --prerelease=false --latest
    exit
    ;;
esac

# Universal-Binary, damit die App auch auf Intel-Macs startet
BINARIES=()
for ARCH in arm64 x86_64; do
    swift build -c release --arch "$ARCH"
    BINARIES+=("$(swift build -c release --arch "$ARCH" --show-bin-path)/StickyToDo")
done
APP="build/To Do.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/StickyToDo" "${BINARIES[@]}"
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
    # Beim zweiten Anlauf (z. B. nach einem Netzwerkfehler) ist die Version schon committet.
    git diff --quiet HEAD || git commit -qam "Version $VERSION"
    git push -q origin master
    PRERELEASE=""
    if [ "$1" = beta ]; then PRERELEASE="--prerelease"; fi
    # Ohne --target legt gh den Tag auf den Stand des Standard-Branches, nicht auf den gebauten Commit.
    gh release create "v$VERSION" build/ToDo.zip --target "$(git rev-parse HEAD)" --title "$VERSION" \
        --generate-notes ${PRERELEASE:+"$PRERELEASE"}
    ;;
esac
