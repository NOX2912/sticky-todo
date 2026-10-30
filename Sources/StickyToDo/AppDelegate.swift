import AppKit
import Combine
import SwiftUI

@main
enum StickyToDoApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Kein Dock-Symbol und kein Eintrag im App-Umschalter – die Notiz soll sich nie nach vorne drängen.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mainSettings = SettingsStore(id: .main)
    private let updater = Updater()
    private var notes: [NoteController] = []
    /// Die zuletzt benutzte Notiz; Menüleisten-Befehle wirken auf sie.
    private weak var activeNote: NoteController?
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var menuLanguage: Language?

    /// IDs der weiteren Notizen; die erste Notiz ist immer da.
    private static let notesKey = "notes"

    private var currentNote: NoteController { activeNote ?? notes[0] }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "To Do")
        addNote(mainSettings)
        for uuid in (UserDefaults.standard.stringArray(forKey: Self.notesKey) ?? []).compactMap(UUID.init) {
            addNote(SettingsStore(id: NoteID(uuid: uuid)))
        }
        mainSettings.$settings
            .sink { [weak self] in self?.apply($0) }
            .store(in: &cancellables)
        updater.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showNotes()
        return false
    }

    private func apply(_ s: NoteSettings) {
        guard menuLanguage != s.language else { return }
        let changed = menuLanguage != nil
        menuLanguage = s.language
        setUpMainMenu()
        setUpStatusItem()
        if changed { notes.forEach { $0.languageChanged() } }
    }

    // MARK: - Notizen

    @discardableResult
    private func addNote(_ settings: SettingsStore, cascadingFrom previous: NSWindow? = nil) -> NoteController {
        let id = settings.id
        let note = NoteController(
            settings: settings, mainSettings: mainSettings, updater: updater, cascadingFrom: previous,
            newNote: { [weak self] in self?.newNote() },
            // Erst nach dem Kontextmenü, damit das Fenster nicht mitten in dessen Aktion verschwindet.
            delete: id == .main ? nil : { [weak self] in DispatchQueue.main.async { self?.deleteNote(id) } })
        note.onActivate = { [weak self] in self?.activeNote = $0 }
        notes.append(note)
        return note
    }

    /// Neue Notiz mit einem Theme, das noch keine andere trägt; Schrift, Ebene usw. kommen von der aktuellen.
    @objc private func newNote() {
        let source = currentNote
        var s = source.settings.settings
        s.theme = ThemePreset.unused(by: notes.map(\.settings.settings.theme)).theme
        s.title = NoteSettings().title
        let settings = SettingsStore(id: .new())
        settings.settings = s
        let note = addNote(settings, cascadingFrom: source.window)
        saveNoteList()
        note.show()
    }

    private func deleteNote(_ id: NoteID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[index]
        if !note.store.items.isEmpty {
            NSApp.activate()
            let alert = NSAlert()
            let title = note.settings.settings.title
            alert.messageText = title.isEmpty
                ? tr("Notiz löschen?", "Delete note?")
                : tr("Notiz „\(title)“ löschen?", "Delete note “\(title)”?")
            alert.informativeText = tr("Ihre To-Dos werden ebenfalls gelöscht.", "Its to-dos will be deleted too.")
            alert.addButton(withTitle: tr("Löschen", "Delete")).hasDestructiveAction = true
            alert.addButton(withTitle: tr("Abbrechen", "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        notes.remove(at: index)
        if activeNote === note { activeNote = nil }
        note.destroy()
        saveNoteList()
    }

    private func saveNoteList() {
        UserDefaults.standard.set(notes.compactMap { $0.id.uuid?.uuidString }, forKey: Self.notesKey)
    }

    @objc private func showNotes() {
        // Jedes show() macht seine Notiz zur aktiven, deshalb die aktuelle vorher merken.
        let current = currentNote
        notes.forEach { $0.show() }
        current.show()
    }

    @objc private func removeDone() {
        currentNote.store.removeDone()
    }

    @objc private func checkForUpdates() {
        Task {
            await updater.check()
            NSApp.activate()
            let alert = NSAlert()
            if let release = updater.available {
                alert.messageText = tr("Version \(release.version) ist verfügbar", "Version \(release.version) is available")
                alert.informativeText = tr("Du hast Version \(updater.current).", "You have version \(updater.current).")
                alert.addButton(withTitle: tr("Installieren", "Install"))
                alert.addButton(withTitle: tr("Später", "Later"))
                if alert.runModal() == .alertFirstButtonReturn { updater.install() }
            } else {
                alert.messageText = tr("Du hast die neueste Version (\(updater.current)).", "You have the latest version (\(updater.current)).")
                alert.runModal()
            }
        }
    }

    // MARK: - Einstellungen

    @objc private func openSettings() {
        currentNote.openSettings()
    }

    @objc private func reportBug() { Feedback.bug.open() }
    @objc private func requestFeature() { Feedback.feature.open() }

    // MARK: - Menüs

    private func setUpStatusItem() {
        let menu = NSMenu()
        menu.addItem(item(tr("Notizen anzeigen", "Show notes"), #selector(showNotes)))
        menu.addItem(item(tr("Neue Notiz", "New note"), #selector(newNote), key: "n"))
        menu.addItem(item(tr("Erledigte entfernen", "Remove completed"), #selector(removeDone)))
        menu.addItem(.separator())
        menu.addItem(item(tr("Einstellungen …", "Settings …"), #selector(openSettings), key: ","))
        menu.addItem(item(tr("Nach Updates suchen …", "Check for updates …"), #selector(checkForUpdates)))
        menu.addItem(item(tr("Fehler melden …", "Report a bug …"), #selector(reportBug)))
        menu.addItem(item(tr("Funktion vorschlagen …", "Suggest a feature …"), #selector(requestFeature)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: tr("Beenden", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    /// Unsichtbares Hauptmenü, damit ⌘C/⌘V/⌘Z, ⌘Q und die Emoji-Palette in den Textfeldern funktionieren.
    private func setUpMainMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(item(tr("Einstellungen …", "Settings …"), #selector(openSettings), key: ","))
        appMenu.addItem(item(tr("Neue Notiz", "New note"), #selector(newNote), key: "n"))
        appMenu.addItem(NSMenuItem(title: tr("To Do beenden", "Quit To Do"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        main.addItem(submenu(appMenu))

        let edit = NSMenu(title: tr("Bearbeiten", "Edit"))
        edit.addItem(NSMenuItem(title: tr("Widerrufen", "Undo"), action: Selector(("undo:")), keyEquivalent: "z"))
        edit.addItem(NSMenuItem(title: tr("Wiederholen", "Redo"), action: Selector(("redo:")), keyEquivalent: "Z"))
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: tr("Ausschneiden", "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: tr("Kopieren", "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: tr("Einsetzen", "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: tr("Alles auswählen", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        edit.addItem(.separator())
        let emoji = NSMenuItem(title: tr("Emoji & Symbole", "Emoji & Symbols"), action: #selector(NSApplication.orderFrontCharacterPalette(_:)), keyEquivalent: " ")
        emoji.keyEquivalentModifierMask = [.control, .command]
        edit.addItem(emoji)
        main.addItem(submenu(edit))

        let window = NSMenu(title: tr("Fenster", "Window"))
        window.addItem(NSMenuItem(title: tr("Schließen", "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        main.addItem(submenu(window))

        NSApp.mainMenu = main
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}
