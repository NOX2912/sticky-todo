# To Do ✨

Eine To-Do-Liste im Stil einer Sticky Note, die wie ein Widget auf dem macOS-Schreibtisch liegt – aber direkt bearbeitbar ist.

- Liegt standardmäßig **auf dem Schreibtisch**, also hinter allen anderen Fenstern, und drängt sich nie nach vorne (kein Dock-Symbol, nicht im ⌘-Tab-Umschalter).
- Kreis anklicken → Haken. Der Text bleibt dabei unverändert, es wird nichts durchgestrichen.
- In die Zeile „Neues To-Do“ klicken, tippen, Enter. Mehrzeiliger eingefügter Text wird zu mehreren To-Dos.
- To-Dos direkt anklicken zum Bearbeiten; leeren + Enter/⌫ löscht sie. Rechtsklick: Abhaken, Löschen, Erledigte entfernen.
- Emojis über ⌃⌘Leertaste.
- 14 Themes (u. a. Papier, Silberstern, Briefmarke, Washi, Orange, Himmel, Spitze, Zebra) plus alles einzeln anpassbar: Muster (Farbe, Streifen, Punkte, Zebra, Knitterpapier, eigenes Bild), Karte (Papier, gerissen, Briefmarke, Spitze), Deko (Sterne in Gold/Silber/gestickt/Filz, Büroklammer, Klemmbrett, Washi-Tape, Sternsticker, Herzknopf), Schrift, Größe, Farben, Deckkraft, Fensterebene, Autostart.
- Menüleisten-Symbol (☑︎) für Einstellungen, „Notiz anzeigen“ und Beenden.

## Bauen & starten

Voraussetzung: macOS 14 (Sonoma) oder neuer und Xcode bzw. die Command Line Tools.

```bash
git clone https://github.com/NOX2912/sticky-todo.git
cd sticky-todo
```

```bash
./build.sh            # baut "build/To Do.app"
open "build/To Do.app"
./build.sh install    # kopiert die App zusätzlich nach ~/Applications
```

Für „Beim Anmelden öffnen“ die App am besten vorher mit `./build.sh install` installieren.

### Die App weitergeben

Die App ist nur ad-hoc signiert, nicht von Apple notarisiert. Wer sie als ZIP bekommt, muss sie beim ersten Start einmal freigeben: App öffnen, Hinweis mit „Fertig“ schließen, dann unter **Systemeinstellungen → Datenschutz & Sicherheit** auf **Dennoch öffnen** klicken.

```bash
ditto -c -k --keepParent "build/To Do.app" ToDo.zip
```

## Daten

- To-Dos: `~/Library/Application Support/StickyToDo/todos.json`
- Eigene Hintergrundbilder werden in denselben Ordner kopiert.
- Einstellungen: `defaults read io.github.nox2912.StickyToDo`

## Aufbau

| Datei | Inhalt |
| --- | --- |
| `AppDelegate.swift` | Start, Notizfenster (Ebene, Spaces), Menüleiste, Einstellungsfenster |
| `NoteView.swift` | Die Notiz: Liste, Haken, Eingabezeile |
| `NoteBackground.swift` | Muster (Streifen, Punkte, Zebra, Knitterpapier, Bild) und Karten |
| `Decorations.swift` | Sterne, Klammern, Herzknopf, Washi-Tape, Sternsticker |
| `SettingsView.swift` | Einstellungen |
| `Theme.swift` | Themes, Schriften, Fensterebenen |
| `Models.swift` | To-Do- und Einstellungs-Speicher |

## Lizenz

[MIT](LICENSE)
