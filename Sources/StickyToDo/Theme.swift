import AppKit
import SwiftUI

/// Auswahl-Enums, die in den Einstellungen als Picker erscheinen.
protocol Labeled: CaseIterable, Identifiable, Hashable where AllCases: RandomAccessCollection {
    var label: String { get }
}

extension Labeled {
    var id: Self { self }
}

struct NoteTheme: Equatable {
    enum Background: String, Codable, Labeled {
        case color, stripes, dots, zebra, crumpled, image
        var label: String {
            switch self {
            case .color: "Farbe"
            case .stripes: "Streifen"
            case .dots: "Punkte"
            case .zebra: "Zebra"
            case .crumpled: "Knitterpapier"
            case .image: "Eigenes Bild"
            }
        }
    }

    enum StripeStyle: String, Codable, Labeled {
        case even, narrow, pinstripe, candy
        var label: String {
            switch self {
            case .even: "Gleichmäßig"
            case .narrow: "Schmal"
            case .pinstripe: "Nadelstreifen"
            case .candy: "Bunt"
            }
        }
    }

    enum Card: String, Codable, Labeled {
        case none, paper, torn, stamp, lace
        var label: String {
            switch self {
            case .none: "Keine"
            case .paper: "Papier"
            case .torn: "Gerissen"
            case .stamp: "Briefmarke"
            case .lace: "Spitze"
            }
        }
    }

    enum Stars: String, Codable, Labeled {
        case none, gold, silver, stitched, felt
        var label: String {
            switch self {
            case .none: "Keine"
            case .gold: "Gold"
            case .silver: "Silber"
            case .stitched: "Gestickt"
            case .felt: "Filz"
            }
        }
    }

    enum Clip: String, Codable, Labeled {
        case none, silver, gold, clipboard
        var label: String {
            switch self {
            case .none: "Keine"
            case .silver: "Büroklammer silber"
            case .gold: "Büroklammer gold"
            case .clipboard: "Klemmbrett"
            }
        }
    }

    enum Extra: String, Codable, Labeled {
        case washiTape, starStickers, heartButton
        var label: String {
            switch self {
            case .washiTape: "Washi-Tape"
            case .starStickers: "Sternsticker"
            case .heartButton: "Herzknopf"
            }
        }
    }

    var background = Background.color
    var backgroundColor = "#AAB2CC"
    /// Streifen, Punkte bzw. dunkle Zebrastreifen
    var patternColor = "#F2C4CB"
    /// Zweite Streifenfarbe für bunte Streifen
    var patternColor2 = "#F8D79E"
    var stripeStyle = StripeStyle.even
    var imagePath: String?
    var card = Card.none
    var cardColor = "#EAE5DA"
    var stars = Stars.none
    var clip = Clip.none
    var extras: Set<Extra> = []
    var textColor = "#3D434F"
    var checkColor = "#8F8A62"
}

extension NoteTheme: Codable {
    private enum CodingKeys: String, CodingKey {
        case background, backgroundColor, patternColor, patternColor2, stripeStyle, imagePath
        case card, cardColor, stars, clip, extras, textColor, checkColor
    }

    /// Schlüssel aus Version 1.0
    private enum LegacyKeys: String, CodingKey {
        case stripeColor, paper, paperColor, decorations
    }

    /// Fehlende Schlüssel fallen auf Standardwerte zurück, damit gespeicherte Einstellungen nach Updates erhalten bleiben.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let d = NoteTheme()
        background = c.value(.background) ?? d.background
        backgroundColor = c.value(.backgroundColor) ?? d.backgroundColor
        patternColor = c.value(.patternColor) ?? legacy.value(.stripeColor) ?? d.patternColor
        patternColor2 = c.value(.patternColor2) ?? d.patternColor2
        stripeStyle = c.value(.stripeStyle) ?? d.stripeStyle
        imagePath = c.value(.imagePath)
        let hadPaper: Bool = legacy.value(.paper) ?? false
        let hadDecorations: Bool = legacy.value(.decorations) ?? false
        card = c.value(.card) ?? (hadPaper ? .paper : d.card)
        cardColor = c.value(.cardColor) ?? legacy.value(.paperColor) ?? d.cardColor
        stars = c.value(.stars) ?? (hadDecorations ? .gold : d.stars)
        clip = c.value(.clip) ?? (hadDecorations ? .silver : d.clip)
        extras = c.value(.extras) ?? d.extras
        textColor = c.value(.textColor) ?? d.textColor
        checkColor = c.value(.checkColor) ?? d.checkColor
    }
}

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

struct ThemePreset: Identifiable {
    let name: String
    let theme: NoteTheme
    var id: String { name }

    static let all: [ThemePreset] = [
        .init(name: "Lavendel", theme: NoteTheme()),
        .init(name: "Papier", theme: NoteTheme(
            background: .stripes, backgroundColor: "#FBEFEF", patternColor: "#F0BFC6",
            card: .paper, cardColor: "#E9E4D9", stars: .gold, clip: .silver,
            textColor: "#4A433D", checkColor: "#C9A23A")),
        .init(name: "Silberstern", theme: NoteTheme(
            background: .stripes, backgroundColor: "#F9EEEA", patternColor: "#F3C5C6",
            card: .torn, cardColor: "#F1EFE8", stars: .silver,
            textColor: "#55504A", checkColor: "#9C98A3")),
        .init(name: "Briefmarke", theme: NoteTheme(
            background: .stripes, backgroundColor: "#F2A9C3", patternColor: "#D94676", stripeStyle: .narrow,
            card: .stamp, cardColor: "#F3F1EF", stars: .felt, extras: [.heartButton],
            textColor: "#5A2A35", checkColor: "#C8364E")),
        .init(name: "Washi", theme: NoteTheme(
            background: .stripes, backgroundColor: "#F6F2EC", patternColor: "#97A6C6", stripeStyle: .pinstripe,
            card: .paper, cardColor: "#EFE6DD", extras: [.washiTape, .starStickers],
            textColor: "#5A5058", checkColor: "#C49AAA")),
        .init(name: "Orange", theme: NoteTheme(
            background: .stripes, backgroundColor: "#FBF3E4", patternColor: "#F4AE78", patternColor2: "#F8D79E",
            stripeStyle: .candy, card: .paper, cardColor: "#E9E4DA", stars: .stitched, clip: .silver,
            textColor: "#5A4A3A", checkColor: "#E8975A")),
        .init(name: "Himmel", theme: NoteTheme(
            background: .crumpled, backgroundColor: "#7FA2C6",
            card: .paper, cardColor: "#E8DDC2", stars: .gold, clip: .gold,
            textColor: "#4A4030", checkColor: "#C9A23A")),
        .init(name: "Spitze", theme: NoteTheme(
            background: .dots, backgroundColor: "#5A392D", patternColor: "#E7DCCD",
            card: .lace, cardColor: "#F4ECDD",
            textColor: "#4A3428", checkColor: "#8B5E3C")),
        .init(name: "Zebra", theme: NoteTheme(
            background: .zebra, backgroundColor: "#EEE4CF", patternColor: "#161514",
            card: .paper, cardColor: "#E7E3DB", stars: .gold, clip: .silver,
            textColor: "#3E3A35", checkColor: "#C9A23A")),
        .init(name: "Zebra Spitze", theme: NoteTheme(
            background: .zebra, backgroundColor: "#EEE4CF", patternColor: "#161514",
            card: .lace, cardColor: "#EBDDBD", clip: .clipboard,
            textColor: "#4A3E2E", checkColor: "#A47B45")),
        .init(name: "Butter", theme: NoteTheme(backgroundColor: "#FFF0A6", textColor: "#4B4430", checkColor: "#C7A02A")),
        .init(name: "Minze", theme: NoteTheme(backgroundColor: "#CBEADB", textColor: "#2E4A3F", checkColor: "#4E9B7D")),
        .init(name: "Pfirsich", theme: NoteTheme(backgroundColor: "#FFD9C4", textColor: "#5A3B2E", checkColor: "#E07A5F")),
        .init(name: "Nacht", theme: NoteTheme(backgroundColor: "#2A2D3A", textColor: "#E7E9F0", checkColor: "#9CA6FF")),
    ]
}

enum FontChoice: String, Codable, Labeled {
    case system, rounded, serif, noteworthy, markerFelt, bradleyHand

    var label: String {
        switch self {
        case .system: "System"
        case .rounded: "Gerundet"
        case .serif: "Serif"
        case .noteworthy: "Noteworthy"
        case .markerFelt: "Marker Felt"
        case .bradleyHand: "Bradley Hand"
        }
    }

    func font(size: CGFloat, bold: Bool = false) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        switch self {
        case .system: return .system(size: size, weight: weight)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .noteworthy: return .custom(bold ? "Noteworthy-Bold" : "Noteworthy-Light", size: size)
        case .markerFelt: return .custom(bold ? "MarkerFelt-Wide" : "MarkerFelt-Thin", size: size)
        case .bradleyHand: return .custom("BradleyHandITCTT-Bold", size: size)
        }
    }
}

enum WindowLayer: String, Codable, Labeled {
    case desktop, normal, floating

    var label: String {
        switch self {
        case .desktop: "Auf dem Schreibtisch"
        case .normal: "Wie normales Fenster"
        case .floating: "Immer im Vordergrund"
        }
    }

    var level: NSWindow.Level {
        switch self {
        // Direkt über den Schreibtisch-Symbolen, aber unter allen App-Fenstern – wie ein Widget.
        case .desktop: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .normal: .normal
        case .floating: .floating
        }
    }
}

struct NoteSettings: Equatable {
    var theme = NoteTheme()
    var title = "To Do ✨"
    var font = FontChoice.system
    var fontSize: Double = 20
    var padding: Double = 24
    var layer = WindowLayer.desktop
    var opacity: Double = 1
    var showWindowButtons = true
    var showPlaceholder = true
}

extension NoteSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case theme, title, font, fontSize, padding, layer, opacity, showWindowButtons, showPlaceholder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = NoteSettings()
        theme = c.value(.theme) ?? d.theme
        title = c.value(.title) ?? d.title
        font = c.value(.font) ?? d.font
        fontSize = c.value(.fontSize) ?? d.fontSize
        padding = c.value(.padding) ?? d.padding
        layer = c.value(.layer) ?? d.layer
        opacity = c.value(.opacity) ?? d.opacity
        showWindowButtons = c.value(.showWindowButtons) ?? d.showWindowButtons
        showPlaceholder = c.value(.showPlaceholder) ?? d.showPlaceholder
    }
}

extension Color {
    init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")), radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    var hex: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}
