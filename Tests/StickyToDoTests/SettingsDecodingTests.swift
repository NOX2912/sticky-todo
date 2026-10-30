import Foundation
import Testing
@testable import StickyToDo

/// Gespeicherte Einstellungen aus älteren Versionen müssen nach Updates weiter lesbar sein.
struct SettingsDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test func emptySettingsFallBackToDefaults() throws {
        #expect(try decode(NoteSettings.self, "{}") == NoteSettings())
        #expect(try decode(NoteTheme.self, "{}") == NoteTheme())
    }

    @Test func missingFieldsKeepTheRest() throws {
        let settings = try decode(NoteSettings.self, ##"{"title": "Einkauf", "fontSize": 14, "theme": {"backgroundColor": "#FFFFFF"}}"##)
        #expect(settings.title == "Einkauf")
        #expect(settings.fontSize == 14)
        #expect(settings.theme.backgroundColor == "#FFFFFF")
        #expect(settings.padding == NoteSettings().padding)
        #expect(settings.theme.textColor == NoteTheme().textColor)
    }

    @Test func unknownValuesFallBackToDefaults() throws {
        let settings = try decode(NoteSettings.self, ##"{"title": "Einkauf", "font": "comicSans", "theme": {"background": "plaid"}}"##)
        #expect(settings.title == "Einkauf")
        #expect(settings.font == NoteSettings().font)
        #expect(settings.theme.background == NoteTheme().background)
    }

    @Test func legacyThemeFromVersion1() throws {
        let theme = try decode(NoteTheme.self, ##"{"stripeColor": "#111111", "paper": true, "paperColor": "#222222", "decorations": true}"##)
        #expect(theme.patternColor == "#111111")
        #expect(theme.card == .paper)
        #expect(theme.cardColor == "#222222")
        #expect(theme.stars == .gold)
        #expect(theme.clip == .silver)
    }

    @Test func roundTrip() throws {
        var settings = NoteSettings()
        settings.title = "Test"
        settings.layer = .floating
        settings.theme = ThemePreset.all[3].theme
        settings.theme.imagePath = "/tmp/bild.png"
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(NoteSettings.self, from: data) == settings)
    }

    @Test func todosFromDisk() throws {
        let todos = try decode([TodoItem].self, ##"[{"id": "6F1B2C3D-0000-4000-8000-000000000001", "text": "Milch", "done": true}]"##)
        #expect(todos.first?.text == "Milch")
        #expect(todos.first?.done == true)
    }
}
