import Foundation
import Testing
@testable import StickyToDo

/// Gespeicherte To-Dos dürfen nie verloren gehen, auch wenn die Datei nicht (mehr) passt.
@MainActor
struct TodoStoreTests {
    /// Eigener Ordner pro Test, damit nie die echten To-Dos berührt werden.
    private func tempFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("StickyToDoTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todos.json")
    }

    @Test func missingFieldsFallBackToDefaults() throws {
        let todos = try JSONDecoder().decode([TodoItem].self, from: Data(##"[{"text": "Milch"}, {"id": "6F1B2C3D-0000-4000-8000-000000000001", "done": true}]"##.utf8))
        #expect(todos.count == 2)
        #expect(todos[0].text == "Milch")
        #expect(todos[0].done == false)
        #expect(todos[1].text == "")
        #expect(todos[1].done == true)
    }

    @Test func unknownFieldsAreIgnored() throws {
        let todos = try JSONDecoder().decode([TodoItem].self, from: Data(##"[{"id": "6F1B2C3D-0000-4000-8000-000000000001", "text": "Milch", "done": false, "priority": 3}]"##.utf8))
        #expect(todos.first?.text == "Milch")
    }

    @Test func roundTrip() throws {
        let todos = [TodoItem(text: "Milch", done: true), TodoItem(text: "Eier")]
        #expect(try JSONDecoder().decode([TodoItem].self, from: JSONEncoder().encode(todos)) == todos)
    }

    @Test func savesAndLoads() throws {
        let url = try tempFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        TodoStore(url: url).add("Milch")
        #expect(TodoStore(url: url).items.map(\.text) == ["Milch"])
    }

    @Test func unreadableFileIsKeptAside() throws {
        let url = try tempFile()
        let dir = url.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("kaputt".utf8).write(to: url)

        let store = TodoStore(url: url)
        #expect(store.items.isEmpty)
        store.add("Neu")

        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let backup = try #require(files.first { $0.hasPrefix("todos.unreadable-") && $0.hasSuffix(".json") })
        #expect(try String(contentsOf: dir.appendingPathComponent(backup), encoding: .utf8) == "kaputt")
        #expect(TodoStore(url: url).items.map(\.text) == ["Neu"])
    }

    @Test func blankRowsAreDroppedOnLoad() throws {
        let url = try tempFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try JSONEncoder().encode([TodoItem(text: "Milch"), TodoItem(text: ""), TodoItem(text: "  ")]).write(to: url)
        #expect(TodoStore(url: url).items.map(\.text) == ["Milch"])
    }

    @Test func deletedStoreDoesNotWriteAgain() throws {
        let url = try tempFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TodoStore(url: url)
        store.add("Milch")
        store.deleteFile()
        store.add("Eier")
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
