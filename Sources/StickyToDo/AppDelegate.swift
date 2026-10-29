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

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMainMenu()
        setUpStatusItem()
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
                alert.messageText = "Version \(release.version) ist verfügbar"
                alert.informativeText = "Du hast Version \(updater.current)."
                alert.addButton(withTitle: "Installieren")
                alert.addButton(withTitle: "Später")
                if alert.runModal() == .alertFirstButtonReturn { updater.install() }
            } else {
                alert.messageText = "Du hast die neueste Version (\(updater.current))."
                alert.runModal()
            }
        }
    }

    // MARK: - Einstellungen

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 680),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false)
            window.title = "To Do – Einstellungen"
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "To Do")

        let menu = NSMenu()
        menu.addItem(item("Notiz anzeigen", #selector(showNote)))
        menu.addItem(item("Erledigte entfernen", #selector(removeDone)))
        menu.addItem(.separator())
        menu.addItem(item("Einstellungen …", #selector(openSettings), key: ","))
        menu.addItem(item("Nach Updates suchen …", #selector(checkForUpdates)))
        menu.addItem(item("Fehler melden …", #selector(reportBug)))
        menu.addItem(item("Funktion vorschlagen …", #selector(requestFeature)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    /// Unsichtbares Hauptmenü, damit ⌘C/⌘V/⌘Z, ⌘Q und die Emoji-Palette in den Textfeldern funktionieren.
    private func setUpMainMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(item("Einstellungen …", #selector(openSettings), key: ","))
        appMenu.addItem(NSMenuItem(title: "To Do beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        main.addItem(submenu(appMenu))

        let edit = NSMenu(title: "Bearbeiten")
        edit.addItem(NSMenuItem(title: "Widerrufen", action: Selector(("undo:")), keyEquivalent: "z"))
        edit.addItem(NSMenuItem(title: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "Z"))
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Einsetzen", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        edit.addItem(.separator())
        let emoji = NSMenuItem(title: "Emoji & Symbole", action: #selector(NSApplication.orderFrontCharacterPalette(_:)), keyEquivalent: " ")
        emoji.keyEquivalentModifierMask = [.control, .command]
        edit.addItem(emoji)
        main.addItem(submenu(edit))

        let window = NSMenu(title: "Fenster")
        window.addItem(NSMenuItem(title: "Schließen", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
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
