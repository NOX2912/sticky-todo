# Sticky ToDo

macOS-Sticky-Note-To-Do-App (SwiftUI + AppKit), Swift Package ohne Xcode-Projekt. UI-Texte auf Deutsch, README auf Englisch.

## Befehle

```bash
swift build                 # nur kompilieren
swift test                  # Tests (Swift Testing), vor jedem Release automatisch
./build.sh                  # baut "build/To Do.app"
./build.sh install          # baut und kopiert nach ~/Applications
./build.sh beta 1.5         # wie release, aber als Pre-Release: der Auto-Updater sieht es nicht
./build.sh promote 1.5      # Pre-Release zum neuesten Release machen, ab dann Auto-Update für alle
./build.sh release 1.5      # nur auf master: Version setzen, testen, ALLES committen (-am), pushen, GitHub-Release mit build/ToDo.zip
```

`build.sh` baut ein Universal-Binary (arm64 + x86_64). `release`/`beta` brechen ab, wenn nicht auf master oder wenn neue Dateien noch nicht mit `git add` aufgenommen sind (`-am` nähme sie nicht mit, die ZIP aber schon).

- Releases und Betas nur nach ausdrücklicher Freigabe des Users (öffentlich, ein Release landet per Auto-Update bei anderen).
- Danach `./build.sh install`, damit die lokale App dieselbe Version hat.
- Ohne Mac (Cloud-Sitzung, kein Swift): Die CI (`.github/workflows/ci.yml`) baut und testet jeden PR auf macOS, dort Warnungen und Tests prüfen. Veröffentlichen über den Workflow „Release“ (`release.yml`, Version und Kanal `beta`/`release`/`promote`), der `./build.sh` auf macOS ausführt und den Versions-Commit auf master pusht; danach lokal `git pull`.
- Der In-App-Updater (`Updater.swift`) liest `releases/latest` von `NOX2912/sticky-todo` und braucht ein `.zip`-Asset und einen Tag `vX.Y`. Pre-Releases zählen dort nicht als `latest`.
- **Kaputtes Release zurückholen:** Der Updater installiert nur höhere Versionen. Also `git fetch --tags`, den Code des letzten guten Tags holen (`git restore --source vX.Y -- Sources Tests Package.swift`) und als nächste Version veröffentlichen. Nicht `git checkout vX.Y -- …`: Das lässt neuere Dateien liegen, und der Build bricht ab.

## Vor „fertig“ prüfen

- `swift build` ohne Warnungen und `swift test` grün.
- UI-Änderungen in der echten App ansehen (siehe unten) und das Ergebnis zeigen, nicht nur behaupten.
- Vor dem Commit den Diff mit `/code-review` oder einem Subagenten mit frischem Kontext prüfen. Höchstens drei Runden, danach nur noch den neuen Diff.
- Gründlich prüfen bei: `Updater.swift`, `build.sh`, `Info.plist`, den Codable-Typen in `Theme.swift`/`Models.swift`. Neue Felder dort bekommen einen Fall in `Tests/StickyToDoTests`.
- Findet ein Review dasselbe Problem zweimal: als Regel unter „Nicht kaputt machen“ oder als Test festhalten.

## Nicht kaputt machen

- **Bundle-ID** `io.github.nox2912.StickyToDo` nicht ändern: Einstellungen (UserDefaults) und Updates hängen daran.
- **Gespeicherte Daten:** To-Dos liegen in `~/Library/Application Support/StickyToDo/`: `todos.json` für die erste Notiz, `todos-<UUID>.json` für weitere. Einstellungen stehen in UserDefaults unter `settings` bzw. `settings-<UUID>`, die IDs der weiteren Notizen unter `notes`. Neue Felder in `NoteTheme`/`NoteSettings`/`TodoItem` brauchen einen Standardwert im eigenen `init(from:)`, sonst gehen alte Einstellungen oder alle To-Dos verloren. Eine unlesbare To-Do-Datei wird als `todos.unreadable-….json` beiseitegelegt, nie überschrieben.
- **To-Do-Zeilen über die ID binden, nie über den Index** (`text(of:)` in `NoteView`). Ein Index-Binding stürzt ab, wenn ein To-Do gelöscht wird, während sein Textfeld noch aktiv ist.
- **Kontextmenü-Aktionen wirken auf ihre eigene Notiz**, nicht auf `currentNote` im AppDelegate. Ein Rechtsklick macht das Fenster nicht aktiv: Wer von dort den Fokus setzt, ruft vorher `activate()` auf, sonst landet das Getippte in einer anderen Notiz oder App.
- `window.initialFirstResponder = host` verhindert, dass beim Aktivieren das erste To-Do komplett markiert wird. Backspace wird per `NSEvent`-Monitor abgefangen, weil das Textfeld die Taste schluckt. Tastenwiederholungen (gehaltenes Backspace) löschen dort keine Zeilen.
- Keine persönlichen Daten (echte To-Dos, Mail-Adressen) ins öffentliche Repo.

## In der echten App testen

Die App hat kein Dock-Symbol und liegt auf Schreibtisch-Ebene, deshalb kann Computer Use sie nicht steuern. Zum Testen:

1. Daten sichern, denn Tests laufen auf den echten Daten: `cp -R ~/Library/Application\ Support/StickyToDo /tmp/StickyToDo-Sicherung` und `defaults export io.github.nox2912.StickyToDo /tmp/StickyToDo.plist` (Einstellungen, weitere Notizen, Fensterpositionen). Nur `todos.json` reicht nicht: „Notiz löschen“ entfernt die Dateien und Schlüssel der weiteren Notizen endgültig.
2. Vorübergehend `NSApp.setActivationPolicy(.regular)` setzen und in `NoteController.apply` `window.level = .floating` statt `s.layer.level`. An anderer Stelle überschreibt `apply` den Wert bei jeder Einstellungsänderung.
3. Mit `open "build/To Do.app"` starten.
4. Danach die App beenden, die Änderung zurücknehmen und beides zurückspielen: den Ordner ersetzen und `defaults import io.github.nox2912.StickyToDo /tmp/StickyToDo.plist`.

Enter und Backspace kommen nur bei voller Bildschirmsteuerung zuverlässig an, nicht über die Hintergrund-Tools.
