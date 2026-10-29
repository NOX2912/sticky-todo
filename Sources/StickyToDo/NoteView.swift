import SwiftUI

struct NoteView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settings: SettingsStore
    var openSettings: () -> Void

    @State private var draft = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case item(UUID)
        case new
    }

    private var s: NoteSettings { settings.settings }
    private var textColor: Color { Color(hex: s.theme.textColor) }
    private var checkColor: Color { Color(hex: s.theme.checkColor) }
    private var circleSize: CGFloat { (s.fontSize * 1.2).rounded() }
    /// Kreis vertikal an der ersten Textzeile ausrichten
    private var circleTop: CGFloat { max(0, (s.fontSize * 1.22 - circleSize) / 2) }
    private var rowSpacing: CGFloat { s.fontSize * 0.22 }

    private var contentInsets: EdgeInsets {
        let p = s.padding
        if s.theme.card != .none {
            let paper = paperInsets()
            let edge = cardContentInset(s.theme.card)
            return EdgeInsets(top: paper.top + edge + p * 0.8, leading: paper.leading + edge + p * 0.8,
                              bottom: paper.bottom + edge + p * 0.6, trailing: paper.trailing + edge + p * 0.6)
        }
        return EdgeInsets(top: 38 + p * 0.3, leading: p, bottom: p * 0.6, trailing: p * 0.6)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NoteBackground(theme: s.theme, image: settings.backgroundImage)
                .equatable()

            VStack(alignment: .leading, spacing: s.fontSize * 0.45) {
                if !s.title.isEmpty {
                    Text(s.title)
                        .font(s.font.font(size: s.fontSize * 1.6, bold: true))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                }
                list
            }
            .padding(contentInsets)
        }
        .ignoresSafeArea()
        .contextMenu { noteMenu }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: rowSpacing * 2) {
                ForEach($store.items) { $item in
                    row($item)
                }
                newRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        // Sonst fokussiert AppKit das erste To-Do und markiert dessen Text komplett.
        .defaultFocus($focus, .new)
        .onExitCommand { focus = nil }
    }

    private func row(_ item: Binding<TodoItem>) -> some View {
        let id = item.wrappedValue.id
        return HStack(alignment: .top, spacing: s.fontSize * 0.5) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { item.wrappedValue.done.toggle() }
            } label: {
                CheckCircle(done: item.wrappedValue.done, color: checkColor, size: circleSize)
            }
            .buttonStyle(.plain)
            .padding(.top, circleTop)

            // Erledigte To-Dos bleiben bewusst unverändert (kein Durchstreichen).
            TextField("", text: item.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(s.font.font(size: s.fontSize))
                .foregroundStyle(textColor)
                .focused($focus, equals: .item(id))
                .onSubmit { finishEditing(id) }
                .onChange(of: item.wrappedValue.text) { _, text in
                    // To-Dos sind einzeilig; ein Zeilenumbruch beendet die Bearbeitung.
                    guard text.contains(where: \.isNewline) else { return }
                    item.wrappedValue.text = text.filter { !$0.isNewline }
                    finishEditing(id)
                }
                .onKeyPress(.delete) {
                    guard item.wrappedValue.text.isEmpty else { return .ignored }
                    store.remove(id)
                    focus = .new
                    return .handled
                }
        }
        .contextMenu {
            Button(item.wrappedValue.done ? "Als offen markieren" : "Abhaken") { item.wrappedValue.done.toggle() }
            Button("Löschen", role: .destructive) { store.remove(id) }
            Divider()
            noteMenu
        }
    }

    private var newRow: some View {
        HStack(alignment: .top, spacing: s.fontSize * 0.5) {
            Image(systemName: "plus")
                .font(.system(size: circleSize * 0.45, weight: .semibold))
                .foregroundStyle(checkColor.opacity(0.7))
                .frame(width: circleSize, height: circleSize)
                .overlay(Circle().strokeBorder(checkColor.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
                .padding(.top, circleTop)
                .onTapGesture { focus = .new }

            // Eigener Platzhalter, weil der System-Platzhalter im Dark Mode fast weiß ist.
            TextField("", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(s.font.font(size: s.fontSize))
                .foregroundStyle(textColor)
                .background(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("Neues To-Do")
                            .font(s.font.font(size: s.fontSize))
                            .foregroundStyle(textColor.opacity(0.4))
                            .allowsHitTesting(false)
                    }
                }
                .focused($focus, equals: .new)
                .onSubmit(addDraft)
                .onChange(of: draft) { _, text in
                    // Eingefügter Text mit mehreren Zeilen wird zu mehreren To-Dos.
                    if text.contains(where: \.isNewline) { addDraft() }
                }
        }
    }

    @ViewBuilder private var noteMenu: some View {
        Button("Erledigte entfernen") { withAnimation { store.removeDone() } }
            .disabled(!store.items.contains(where: \.done))
        Button("Einstellungen …", action: openSettings)
    }

    private func finishEditing(_ id: UUID) {
        if store.items.first(where: { $0.id == id })?.text.trimmingCharacters(in: .whitespaces).isEmpty == true {
            store.remove(id)
        }
        focus = .new
    }

    private func addDraft() {
        let lines = draft.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        draft = ""
        lines.forEach(store.add)
        DispatchQueue.main.async { focus = .new }
    }
}

struct CheckCircle: View {
    let done: Bool
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(done ? color : Color.white.opacity(0.35))
            Circle().strokeBorder(color, lineWidth: 1.5)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}
