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

    /// Neue Notizen werden versetzt, dürfen aber nie aus dem Bildschirm wandern.
    @Test func cascadedNotesStayOnScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
        // Startplatz der ersten Notiz: 40 pt vom rechten und oberen Rand
        var frame = CGRect(x: 1440 - 340 - 40, y: 875 - 520 - 40, width: 340, height: 520)
        for _ in 0..<30 {
            frame = cascadedFrame(from: frame, within: screen)
            #expect(screen.contains(frame))
        }
    }

    @Test func cascadeGoesRightAndDownWhenThereIsRoom() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
        let frame = cascadedFrame(from: CGRect(x: 100, y: 300, width: 340, height: 520), within: screen)
        #expect(frame.origin == CGPoint(x: 130, y: 270))
    }

    @Test func cascadeTurnsAroundAtTheEdges() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
        let frame = cascadedFrame(from: CGRect(x: 1090, y: 10, width: 340, height: 520), within: screen)
        #expect(frame.origin == CGPoint(x: 1060, y: 40))
    }

    @Test func cascadeOnSecondScreen() {
        let screen = CGRect(x: -1920, y: 0, width: 1920, height: 1055)
        let frame = cascadedFrame(from: CGRect(x: -360, y: 300, width: 340, height: 520), within: screen)
        #expect(screen.contains(frame))
        #expect(frame.origin == CGPoint(x: -390, y: 270))
    }
}
