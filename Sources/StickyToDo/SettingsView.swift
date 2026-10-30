import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    private var theme: Binding<NoteTheme> { $settings.settings.theme }

    var body: some View {
        Form {
            Section("Theme") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(ThemePreset.all) { preset in
                        presetButton(preset)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(tr("Hintergrund", "Background")) {
                picker(tr("Muster", "Pattern"), theme.background)

                switch settings.settings.theme.background {
                case .color, .crumpled:
                    colorPicker(tr("Farbe", "Color"), \.backgroundColor)
                case .stripes:
                    picker(tr("Streifen", "Stripes"), theme.stripeStyle)
                    colorPicker(tr("Grundfarbe", "Base color"), \.backgroundColor)
                    colorPicker(tr("Streifenfarbe", "Stripe color"), \.patternColor)
                    if settings.settings.theme.stripeStyle == .candy {
                        colorPicker(tr("Zweite Streifenfarbe", "Second stripe color"), \.patternColor2)
                    }
                case .dots:
                    colorPicker(tr("Grundfarbe", "Base color"), \.backgroundColor)
                    colorPicker(tr("Punktfarbe", "Dot color"), \.patternColor)
                case .zebra:
                    colorPicker(tr("Helle Farbe", "Light color"), \.backgroundColor)
                    colorPicker(tr("Streifenfarbe", "Stripe color"), \.patternColor)
                case .image:
                    LabeledContent(tr("Bild", "Image")) {
                        HStack {
                            if settings.settings.theme.imagePath == nil {
                                Text(tr("Kein Bild", "No image")).foregroundStyle(.secondary)
                            }
                            Button(tr("Bild wählen …", "Choose image …"), action: chooseImage)
                        }
                    }
                }

            }

            Section(tr("Karte & Deko", "Card & decorations")) {
                picker(tr("Karte", "Card"), theme.card)
                if settings.settings.theme.card != .none {
                    colorPicker(tr("Kartenfarbe", "Card color"), \.cardColor)
                    picker(tr("Sterne", "Stars"), theme.stars)
                    picker(tr("Klammer", "Clip"), theme.clip)
                    ForEach(Array(NoteTheme.Extra.allCases)) { extra in
                        Toggle(extra.label, isOn: Binding(
                            get: { settings.settings.theme.extras.contains(extra) },
                            set: { on in
                                if on { settings.settings.theme.extras.insert(extra) } else { settings.settings.theme.extras.remove(extra) }
                            }))
                    }
                }
            }

            Section("Text") {
                TextField(tr("Überschrift", "Title"), text: $settings.settings.title)
                Toggle(tr("„Neues To-Do“ anzeigen", "Show “New to-do”"), isOn: $settings.settings.showPlaceholder)
                picker(tr("Schrift", "Font"), $settings.settings.font)
                Slider(value: $settings.settings.fontSize, in: 13...32) {
                    Text(tr("Schriftgröße", "Font size"))
                }
                colorPicker(tr("Textfarbe", "Text color"), \.textColor)
                colorPicker(tr("Haken-Farbe", "Checkmark color"), \.checkColor)
            }

            Section(tr("Fenster", "Window")) {
                picker("Sprache / Language", $settings.settings.language)
                picker(tr("Ebene", "Layer"), $settings.settings.layer)
                Slider(value: $settings.settings.padding, in: 8...60) { Text(tr("Innenabstand", "Padding")) }
                Slider(value: $settings.settings.opacity, in: 0.4...1) { Text(tr("Deckkraft", "Opacity")) }
                Toggle(tr("Fensterknöpfe anzeigen", "Show window buttons"), isOn: $settings.settings.showWindowButtons)
                Toggle(tr("Beim Anmelden öffnen", "Open at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }

            if let error {
                Text(error).foregroundStyle(.red).font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 500)
    }

    private func presetButton(_ preset: ThemePreset) -> some View {
        var current = settings.settings.theme
        current.imagePath = nil
        let selected = current == preset.theme
        let scale: CGFloat = 0.3
        let edge = preset.theme.card == .none ? 0 : cardContentInset(preset.theme.card)

        return Button { settings.apply(preset) } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    NoteBackground(theme: preset.theme, image: nil, scale: scale)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            HStack(spacing: 4) {
                                Circle().strokeBorder(Color(hex: preset.theme.checkColor), lineWidth: 1)
                                    .frame(width: 7, height: 7)
                                Capsule().fill(Color(hex: preset.theme.textColor).opacity(0.6))
                                    .frame(width: 34, height: 3)
                            }
                        }
                    }
                    .padding(.top, preset.theme.card == .none ? 16 : (paperInsets().top + edge) * scale + 6)
                    .padding(.leading, preset.theme.card == .none ? 10 : (paperInsets().leading + edge) * scale + 6)
                }
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor : Color.black.opacity(0.1), lineWidth: selected ? 2.5 : 1))

                Text(preset.name).font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func picker<T: Labeled>(_ title: String, _ selection: Binding<T>) -> some View {
        Picker(title, selection: selection) {
            ForEach(T.allCases) { Text($0.label).tag($0) }
        }
    }

    private func colorPicker(_ title: String, _ keyPath: WritableKeyPath<NoteTheme, String>) -> some View {
        ColorPicker(title, selection: Binding(
            get: { Color(hex: settings.settings.theme[keyPath: keyPath]) },
            set: { settings.settings.theme[keyPath: keyPath] = $0.hex }
        ), supportsOpacity: false)
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try settings.importImage(from: url)
            error = nil
        } catch {
            self.error = tr("Bild konnte nicht übernommen werden: ", "Could not use image: ") + error.localizedDescription
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            error = nil
        } catch {
            self.error = tr("Autostart konnte nicht geändert werden: ", "Could not change launch at login: ") + error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
