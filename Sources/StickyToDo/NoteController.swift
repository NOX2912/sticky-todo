import AppKit
import Combine
import SwiftUI

/// Eine Notiz auf dem Schreibtisch: eigene To-Dos, eigenes Aussehen, eigenes Fenster und Einstellungsfenster.
@MainActor
final class NoteController: NSObject, NSWindowDelegate {
    let id: NoteID
    let store: TodoStore
    let settings: SettingsStore
    let window: NSWindow
    /// Einstellungen der ersten Notiz; dort liegt die Sprache der ganzen App.
    private let mainSettings: SettingsStore
    private var settingsWindow: NSWindow?
    private var cancellable: AnyCancellable?
    /// Wird aufgerufen, wenn die Notiz oder ihre Einstellungen nach vorne kommen.
    var onActivate: (NoteController) -> Void = { _ in }

    init(settings: SettingsStore, mainSettings: SettingsStore, updater: Updater, cascadingFrom previous: NSWindow? = nil,
         newNote: @escaping () -> Void, delete: (() -> Void)?) {
        id = settings.id
        store = TodoStore(id: settings.id)
        self.settings = settings
        self.mainSettings = mainSettings
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        super.init()

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 220, height: 180)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.identifier = NSUserInterfaceItemIdentifier(id.windowName)
        window.delegate = self

        let host = NSHostingView(rootView: NoteView(
            id: id, store: store, settings: settings, updater: updater,
            openSettings: { [weak self] in self?.openSettings() }, newNote: newNote, deleteNote: delete))
        host.sizingOptions = []
        window.contentView = host
        // Sonst macht AppKit beim Aktivieren das erste To-Do zum Eingabefeld und markiert dessen ganzen Text.
        window.initialFirstResponder = host

        if !window.setFrameUsingName(id.windowName) {
            if let previous {
                // Neue Notizen leicht versetzt über die aktuelle legen, damit man sie sofort sieht.
                window.setFrame(previous.frame.offsetBy(dx: 30, dy: -30), display: false)
            } else if let screen = NSScreen.main?.visibleFrame {
                window.setFrameOrigin(NSPoint(x: screen.maxX - window.frame.width - 40,
                                              y: screen.maxY - window.frame.height - 40))
            }
        }
        window.setFrameAutosaveName(id.windowName)

        cancellable = settings.$settings.sink { [weak self] in self?.apply($0) }
        window.orderFrontRegardless()
    }

    private func apply(_ s: NoteSettings) {
        window.level = s.layer.level
        window.collectionBehavior = s.layer == .desktop
            ? [.canJoinAllSpaces, .stationary, .ignoresCycle]
            : [.canJoinAllSpaces, .ignoresCycle]
        window.alphaValue = s.opacity
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = !s.showWindowButtons
        }
        settingsWindow?.title = settingsTitle(s)
    }

    /// Nach einem Sprachwechsel in der ersten Notiz auch diese Notiz neu zeichnen.
    func languageChanged() {
        settings.objectWillChange.send()
        settingsWindow?.title = settingsTitle(settings.settings)
    }

    private func settingsTitle(_ s: NoteSettings) -> String {
        let name = s.title.isEmpty ? "To Do" : s.title
        return tr("\(name) – Einstellungen", "\(name) – Settings")
    }

    /// Schließen versteckt die Notiz nur; über das Menüleisten-Symbol kommt sie zurück.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === window else { return true }
        sender.orderOut(nil)
        return false
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onActivate(self)
    }

    func show() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 680),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false)
            window.title = settingsTitle(settings.settings)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings, main: mainSettings))
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Notiz endgültig entfernen: Fenster schließen und alles Gespeicherte löschen.
    func destroy() {
        cancellable = nil
        store.deleteFile()
        settings.deleteStored()
        settingsWindow?.close()
        window.delegate = nil
        window.close()
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame \(id.windowName)")
    }
}
