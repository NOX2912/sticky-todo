import Foundation
import Testing
@testable import StickyToDo

struct NoteTests {
    /// Die erste Notiz muss die Ablageorte von Version 1.x behalten, sonst sind To-Dos und Einstellungen weg.
    @Test func mainNoteKeepsLegacyStorage() {
        #expect(NoteID.main.todosFile == "todos.json")
        #expect(NoteID.main.settingsKey == "settings")
        #expect(NoteID.main.windowName == "NoteWindow")
    }

    @Test func otherNotesGetTheirOwnStorage() {
        let a = NoteID.new(), b = NoteID.new()
        #expect(a.todosFile != NoteID.main.todosFile)
        #expect(a.todosFile != b.todosFile)
        #expect(a.settingsKey != b.settingsKey)
        #expect(a.windowName != b.windowName)
        #expect(a.todosFile.contains(a.uuid!.uuidString))
    }

    @Test func newNoteGetsUnusedTheme() {
        let used = [ThemePreset.all[0].theme, ThemePreset.all[1].theme]
        #expect(ThemePreset.unused(by: used).id == ThemePreset.all[2].id)
    }

    @Test func customImageDoesNotCountAsDifferentTheme() {
        var theme = ThemePreset.all[0].theme
        theme.imagePath = "/tmp/bild.png"
        #expect(ThemePreset.unused(by: [theme]).id == ThemePreset.all[1].id)
    }

    @Test func allThemesUsedStillGivesOne() {
        let themes = ThemePreset.all.map(\.theme)
        #expect(ThemePreset.all.contains { $0.id == ThemePreset.unused(by: themes).id })
    }
}
