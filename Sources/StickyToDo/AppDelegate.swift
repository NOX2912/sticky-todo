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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = TodoStore()
    private let settings = SettingsStore()
    private let updater = Updater()
    private var noteWindow: NSWindow!
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var menuLanguage: Language?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "To Do")
        setUpNoteWindow()
        settings.$settings
            .sink { [weak self] in self?.apply($0) }
            .store(in: &cancellables)
        updater.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showNote()
        return false
    }

    // MARK: - Notizfenster

    private func setUpNoteWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 220, height: 180)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.delegate = self

        let host = NSHostingView(rootView: NoteView(store: store, settings: settings, updater: updater, openSettings: { [weak self] in
            self?.openSettings()
        }))
        host.sizingOptions = []
        window.contentView = host
        // Sonst macht AppKit beim Aktivieren das erste To-Do zum Eingabefeld und markiert dessen ganzen Text.
        window.initialFirstResponder = host

        if !window.setFrameUsingName("NoteWindow"), let screen = NSScreen.main?.visibleFrame {
            window.setFrameOrigin(NSPoint(x: screen.maxX - window.frame.width - 40,
                                          y: screen.maxY - window.frame.height - 40))
        }
        window.setFrameAutosaveName("NoteWindow")

        noteWindow = window
        apply(settings.settings)
        window.orderFrontRegardless()
    }

    private func apply(_ s: NoteSettings) {
        if menuLanguage != s.language {
            menuLanguage = s.language
            setUpMainMenu()
            setUpStatusItem()
            settingsWindow?.title = settingsTitle
        }
        guard let window = noteWindow else { return }
        window.level = s.layer.level
        window.collectionBehavior = s.layer == .desktop
            ? [.canJoinAllSpaces, .stationary, .ignoresCycle]
            : [.canJoinAllSpaces, .ignoresCycle]
        window.alphaValue = s.opacity
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = !s.showWindowButtons
        }
    }

    /// Schließen versteckt die Notiz nur; über das Menüleisten-Symbol kommt sie zurück.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === noteWindow else { return true }
        sender.orderOut(nil)
        return false
    }

    @objc private func showNote() {
        if noteWindow.isMiniaturized { noteWindow.deminiaturize(nil) }
        NSApp.activate()
        noteWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func removeDone() {
        store.removeDone()
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

    private var settingsTitle: String { tr("To Do – Einstellungen", "To Do – Settings") }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 680),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false)
            window.title = settingsTitle
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func reportBug() { Feedback.bug.open() }
    @objc private func requestFeature() { Feedback.feature.open() }

    // MARK: - Menüs

    private func setUpStatusItem() {
        let menu = NSMenu()
        menu.addItem(item(tr("Notiz anzeigen", "Show note"), #selector(showNote)))
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
