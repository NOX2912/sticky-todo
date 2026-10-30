import AppKit
import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var done = false
}

/// Ablage im Application-Support-Ordner, z. B. ~/Library/Application Support/StickyToDo
enum Storage {
    static let directory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StickyToDo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
}

/// Kennung einer Notiz. Die erste Notiz behält die Dateinamen und Schlüssel von Version 1.x,
/// damit bestehende To-Dos, Einstellungen und die Fensterposition erhalten bleiben.
struct NoteID: Hashable {
    let uuid: UUID?

    static let main = NoteID(uuid: nil)
    static func new() -> NoteID { NoteID(uuid: UUID()) }

    private var suffix: String { uuid.map { "-\($0.uuidString)" } ?? "" }
    var todosFile: String { "todos\(suffix).json" }
    var settingsKey: String { "settings\(suffix)" }
    /// Name für die gespeicherte Fensterposition, zugleich Kennung des Fensters
    var windowName: String { "NoteWindow\(suffix)" }
}

@MainActor
final class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = [] {
        didSet { save() }
    }

    private let url: URL
    /// Nach dem Löschen der Notiz nichts mehr schreiben, sonst entsteht die Datei beim Schließen des Fensters neu.
    private var deleted = false

    init(id: NoteID) {
        url = Storage.directory.appendingPathComponent(id.todosFile)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = decoded
        }
    }

    func add(_ text: String) {
        items.append(TodoItem(text: text))
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    func toggle(_ id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) { items[index].done.toggle() }
    }

    func removeDone() {
        items.removeAll(where: \.done)
    }

    func deleteFile() {
        deleted = true
        try? FileManager.default.removeItem(at: url)
    }

    private func save() {
        guard !deleted, let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: NoteSettings {
        // Vor dem Veröffentlichen, damit alle Beobachter schon die neue Sprache sehen.
        // Die Sprache gilt für die ganze App und kommt aus der ersten Notiz.
        willSet { if id == .main { Language.current = newValue.language } }
        didSet {
            save()
            if oldValue.theme.imagePath != settings.theme.imagePath { loadImage() }
        }
    }

    /// Zwischengespeichert, damit das Bild nicht bei jedem Tastendruck neu geladen wird.
    @Published private(set) var backgroundImage: NSImage?

    let id: NoteID
    private var deleted = false

    init(id: NoteID) {
        self.id = id
        if let data = UserDefaults.standard.data(forKey: id.settingsKey),
           let decoded = try? JSONDecoder().decode(NoteSettings.self, from: data) {
            settings = decoded
        } else {
            settings = NoteSettings()
        }
        if id == .main { Language.current = settings.language }
        loadImage()
    }

    func apply(_ preset: ThemePreset) {
        var theme = preset.theme
        theme.imagePath = settings.theme.imagePath
        settings.theme = theme
    }

    func importImage(from source: URL) throws {
        let target = Storage.directory.appendingPathComponent("background-\(UUID().uuidString).\(source.pathExtension)")
        try FileManager.default.copyItem(at: source, to: target)
        if let old = settings.theme.imagePath { try? FileManager.default.removeItem(atPath: old) }
        settings.theme.imagePath = target.path
        settings.theme.background = .image
    }

    func deleteStored() {
        deleted = true
        UserDefaults.standard.removeObject(forKey: id.settingsKey)
        if let image = settings.theme.imagePath { try? FileManager.default.removeItem(atPath: image) }
    }

    private func loadImage() {
        backgroundImage = settings.theme.imagePath.flatMap(NSImage.init(contentsOfFile:))
    }

    private func save() {
        guard !deleted, let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: id.settingsKey)
    }
}
