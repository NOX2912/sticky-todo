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

@MainActor
final class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = [] {
        didSet { save() }
    }

    private let url = Storage.directory.appendingPathComponent("todos.json")

    init() {
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

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: NoteSettings {
        didSet {
            save()
            if oldValue.theme.imagePath != settings.theme.imagePath { loadImage() }
        }
    }

    /// Zwischengespeichert, damit das Bild nicht bei jedem Tastendruck neu geladen wird.
    @Published private(set) var backgroundImage: NSImage?

    private static let key = "settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(NoteSettings.self, from: data) {
            settings = decoded
        } else {
            settings = NoteSettings()
        }
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

    private func loadImage() {
        backgroundImage = settings.theme.imagePath.flatMap(NSImage.init(contentsOfFile:))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
