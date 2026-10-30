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
./build.sh release 1.5      # Version setzen, testen, ALLES committen (-am), pushen, GitHub-Release mit build/ToDo.zip
```

- Releases und Betas nur nach ausdrücklicher Freigabe des Users (öffentlich, ein Release landet per Auto-Update bei anderen).
- Danach `./build.sh install`, damit die lokale App dieselbe Version hat.
- Der In-App-Updater (`Updater.swift`) liest `releases/latest` von `NOX2912/sticky-todo` und braucht ein `.zip`-Asset und einen Tag `vX.Y`. Pre-Releases zählen dort nicht als `latest`.
- **Kaputtes Release zurückholen:** Der Updater installiert nur höhere Versionen. Also den Code des letzten guten Tags auschecken (`git checkout vX.Y -- Sources Package.swift`) und als nächste Version veröffentlichen.

## Vor „fertig“ prüfen

- `swift build` ohne Warnungen und `swift test` grün.
- UI-Änderungen in der echten App ansehen (siehe unten) und das Ergebnis zeigen, nicht nur behaupten.
- Vor dem Commit den Diff mit `/code-review` oder einem Subagenten mit frischem Kontext prüfen. Höchstens drei Runden, danach nur noch den neuen Diff.
- Gründlich prüfen bei: `Updater.swift`, `build.sh`, `Info.plist`, den Codable-Typen in `Theme.swift`/`Models.swift`. Neue Felder dort bekommen einen Fall in `Tests/StickyToDoTests`.
- Findet ein Review dasselbe Problem zweimal: als Regel unter „Nicht kaputt machen“ oder als Test festhalten.

## Nicht kaputt machen

- **Bundle-ID** `io.github.nox2912.StickyToDo` nicht ändern: Einstellungen (UserDefaults) und Updates hängen daran.
- **Gespeicherte Daten:** To-Dos liegen in `~/Library/Application Support/StickyToDo/todos.json`. Neue Felder in `NoteTheme`/`NoteSettings` brauchen einen Standardwert im eigenen `init(from:)`, sonst gehen alte Einstellungen verloren.
- **To-Do-Zeilen über die ID binden, nie über den Index** (`text(of:)` in `NoteView`). Ein Index-Binding stürzt ab, wenn ein To-Do gelöscht wird, während sein Textfeld noch aktiv ist.
- `window.initialFirstResponder = host` verhindert, dass beim Aktivieren das erste To-Do komplett markiert wird. Backspace wird per `NSEvent`-Monitor abgefangen, weil das Textfeld die Taste schluckt.
- Keine persönlichen Daten (echte To-Dos, Mail-Adressen) ins öffentliche Repo.

## In der echten App testen

Die App hat kein Dock-Symbol und liegt auf Schreibtisch-Ebene, deshalb kann Computer Use sie nicht steuern. Zum Testen:

1. `todos.json` sichern, denn Tests laufen auf den echten Daten.
2. Vorübergehend `NSApp.setActivationPolicy(.regular)` und `window.level = .floating` setzen.
3. Mit `open "build/To Do.app"` starten.
4. Danach die Änderung zurücknehmen und `todos.json` zurückspielen.

Enter und Backspace kommen nur bei voller Bildschirmsteuerung zuverlässig an, nicht über die Hintergrund-Tools.
