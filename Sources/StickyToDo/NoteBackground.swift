import SwiftUI

/// Abstand der Karte zum Fensterrand. Oben bleibt Platz für die Fensterknöpfe.
func paperInsets(scale: CGFloat = 1) -> EdgeInsets {
    EdgeInsets(top: 40 * scale, leading: 18 * scale, bottom: 22 * scale, trailing: 18 * scale)
}

/// Zusätzlicher Innenabstand, damit der Text nicht auf Zacken oder Spitze liegt.
func cardContentInset(_ card: NoteTheme.Card) -> CGFloat {
    switch card {
    case .none, .paper: 0
    case .torn: 4
    case .stamp: 12
    case .lace: 30
    }
}

/// Equatable, damit der aufwendig gezeichnete Hintergrund nicht bei jedem Tastendruck neu gerendert wird.
struct NoteBackground: View, Equatable {
    let theme: NoteTheme
    let image: NSImage?
    var scale: CGFloat = 1

    static func == (a: Self, b: Self) -> Bool {
        a.theme == b.theme && a.image === b.image && a.scale == b.scale
    }

    var body: some View {
        ZStack {
            pattern
            if theme.card != .none {
                CardView(theme: theme, scale: scale)
                    .padding(paperInsets(scale: scale))
            }
        }
    }

    @ViewBuilder private var pattern: some View {
        let base = Color(hex: theme.backgroundColor)
        let pattern = Color(hex: theme.patternColor)
        switch theme.background {
        case .color:
            base
        case .stripes:
            Stripes(style: theme.stripeStyle, base: base, first: pattern,
                    second: Color(hex: theme.patternColor2), width: 12 * scale)
        case .dots:
            Dots(base: base, dot: pattern, scale: scale)
        case .zebra:
            Zebra(base: base, stripe: pattern, scale: scale)
        case .crumpled:
            Crumpled(base: base, scale: scale)
        case .image:
            if let image {
                Color.clear
                    .overlay(Image(nsImage: image).resizable().scaledToFill())
                    .clipped()
            } else {
                base
            }
        }
    }
}

// MARK: - Muster

/// Feine Querfäden, damit Flächen nach Stoff aussehen.
private func weave(_ ctx: GraphicsContext, _ size: CGSize, step: CGFloat) {
    var y: CGFloat = 0
    while y < size.height {
        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(.white.opacity(0.12)))
        y += step
    }
}

struct Stripes: View {
    let style: NoteTheme.StripeStyle
    let base: Color
    let first: Color
    let second: Color
    let width: CGFloat

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            let line = max(0.5, width / 12)
            let bands: [(Color?, CGFloat)] = switch style {
            case .even: [(first, width), (nil, width)]
            case .narrow: [(first, width * 0.6), (nil, width)]
            case .pinstripe: [(first, line), (nil, line * 1.4), (first, line), (nil, line * 1.4), (first, line), (nil, width * 1.6)]
            case .candy: [(first, width * 0.8), (nil, width * 0.25), (second, width * 0.5), (nil, width * 0.25)]
            }
            var x: CGFloat = 0
            while x < size.width {
                for (color, w) in bands {
                    if let color {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: w, height: size.height)), with: .color(color))
                    }
                    x += w
                }
            }
            weave(ctx, size, step: max(2, width / 4))
        }
    }
}

struct Dots: View {
    let base: Color
    let dot: Color
    let scale: CGFloat

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            let d = 22 * scale, dx = 64 * scale, dy = 34 * scale
            var y = dy / 2, row = 0
            while y - d < size.height {
                var x = row.isMultiple(of: 2) ? dx / 4 : dx * 3 / 4
                while x - d < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)), with: .color(dot))
                    x += dx
                }
                y += dy
                row += 1
            }
            weave(ctx, size, step: max(2, 3 * scale))
        }
    }
}

struct Zebra: View {
    let base: Color
    let stripe: Color
    let scale: CGFloat

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            var rng = SeededRandom(seed: 11)
            let spacing = 30 * scale
            let center = size.width / 2
            let slope: CGFloat = 0.4
            let first = -Int(center * slope / spacing) - 2
            let last = Int(size.height / spacing) + 2
            for i in first...last {
                let phase = Double.random(in: 0..<(2 * .pi), using: &rng)
                let amp = Double.random(in: 3...8, using: &rng) * scale
                let thickness = spacing * Double.random(in: 0.45...0.65, using: &rng)
                var path = Path()
                var x: CGFloat = -12
                while x <= size.width + 12 {
                    // Bögen zur Mitte hin wie beim Fellscheitel, dazu ein unregelmäßiges Wellen
                    let dx = x - center
                    let y = CGFloat(i) * spacing + (dx * dx + 400 * scale * scale).squareRoot() * slope
                        + amp * sin(x / (18 * scale) + phase)
                    x == -12 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                    x += 4
                }
                ctx.stroke(path, with: .color(stripe), style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
            }
            // Fellstruktur: kurze Härchen in beiden Farben
            for _ in 0..<Int(size.width * size.height / (14 * scale * scale)) {
                let x = Double.random(in: 0..<size.width, using: &rng)
                let y = Double.random(in: 0..<size.height, using: &rng)
                let angle = Double.random(in: 1.2...1.9, using: &rng)
                let length = Double.random(in: 2...5, using: &rng) * scale
                var hair = Path()
                hair.move(to: CGPoint(x: x, y: y))
                hair.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
                let light = Bool.random(using: &rng)
                ctx.stroke(hair, with: .color(light ? base.opacity(0.5) : stripe.opacity(0.35)), lineWidth: 0.6 * scale)
            }
        }
    }
}

struct Crumpled: View {
    let base: Color
    let scale: CGFloat

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            var rng = SeededRandom(seed: 5)
            let cell = 46 * scale
            let cols = Int(size.width / cell) + 2, rows = Int(size.height / cell) + 2
            // Verzogenes Gitter, dessen Dreiecke unterschiedlich hell sind – wirkt wie zerknülltes Papier
            let points: [[CGPoint]] = (0...rows).map { r in
                (0...cols).map { c in
                    CGPoint(x: (CGFloat(c) + .random(in: -0.4...0.4, using: &rng)) * cell,
                            y: (CGFloat(r) + .random(in: -0.4...0.4, using: &rng)) * cell)
                }
            }
            for r in 0..<rows {
                for c in 0..<cols {
                    let a = points[r][c], b = points[r][c + 1], d = points[r + 1][c], e = points[r + 1][c + 1]
                    for triangle in [[a, b, e], [a, e, d]] {
                        var p = Path()
                        p.addLines(triangle)
                        p.closeSubpath()
                        let shade = Double.random(in: -1...1, using: &rng)
                        ctx.fill(p, with: .color(shade > 0 ? .white.opacity(shade * 0.14) : .black.opacity(-shade * 0.12)))
                    }
                    // Knickkante mit Licht und Schatten
                    var crease = Path()
                    crease.move(to: a)
                    crease.addLine(to: e)
                    ctx.stroke(crease, with: .color(.white.opacity(0.25)), lineWidth: 0.6 * scale)
                    ctx.stroke(crease.offsetBy(dx: 0.8 * scale, dy: 0.8 * scale), with: .color(.black.opacity(0.1)), lineWidth: 0.6 * scale)
                }
            }
        }
    }
}

// MARK: - Karten

struct CardView: View {
    let theme: NoteTheme
    let scale: CGFloat

    private var color: Color { Color(hex: theme.cardColor) }
    private var starSize: CGFloat { 38 * scale }

    var body: some View {
        card
            .overlay(alignment: .topLeading) {
                StarDecoration(style: theme.stars, size: starSize)
                    .rotationEffect(.degrees(-14))
                    .offset(x: -15 * scale, y: -15 * scale)
            }
            .overlay(alignment: .bottomTrailing) {
                if theme.extras.contains(.heartButton) {
                    HeartButton(size: 44 * scale)
                        .rotationEffect(.degrees(-8))
                        .offset(x: 14 * scale, y: 14 * scale)
                } else if theme.stars != .felt {
                    StarDecoration(style: theme.stars, size: starSize)
                        .rotationEffect(.degrees(10))
                        .offset(x: 15 * scale, y: 15 * scale)
                }
            }
            .overlay(alignment: .topTrailing) {
                if theme.extras.contains(.starStickers) {
                    StarStickers(scale: scale).padding(10 * scale)
                }
            }
            .overlay(alignment: .topTrailing) {
                if theme.extras.contains(.washiTape) {
                    WashiTape(color: Color(hex: theme.checkColor), scale: scale)
                        .rotationEffect(.degrees(35))
                        .offset(x: 22 * scale, y: -6 * scale)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if theme.extras.contains(.washiTape) {
                    WashiTape(color: Color(hex: theme.checkColor), scale: scale)
                        .rotationEffect(.degrees(35))
                        .offset(x: -22 * scale, y: 6 * scale)
                }
            }
            .overlay(alignment: .topTrailing) {
                switch theme.clip {
                case .silver, .gold:
                    PaperClip()
                        .stroke(theme.clip == .gold ? Color(hex: "#B8892E") : Color(white: 0.28),
                                style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round, lineJoin: .round))
                        .frame(width: 16 * scale, height: 52 * scale)
                        .shadow(color: .black.opacity(0.25), radius: 1 * scale, x: 1 * scale, y: 1 * scale)
                        .offset(x: -22 * scale, y: -14 * scale)
                default:
                    EmptyView()
                }
            }
            .overlay(alignment: .top) {
                if theme.clip == .clipboard {
                    ClipboardClip(scale: scale).offset(y: -26 * scale)
                }
            }
    }

    @ViewBuilder private var card: some View {
        let shadow = Color.black.opacity(0.2)
        switch theme.card {
        case .none:
            Color.clear
        case .paper:
            Rectangle()
                .fill(color)
                .overlay(PaperGrain())
                .shadow(color: shadow, radius: 3 * scale, y: 1.5 * scale)
        case .torn:
            ZStack {
                TornEdge(seed: 3, depth: 3 * scale).fill(Color(hex: "#E4E8EE"))
                TornEdge(seed: 4, depth: 3 * scale)
                    .fill(color)
                    .overlay(PaperGrain(density: 40).clipShape(TornEdge(seed: 4, depth: 3 * scale)))
                    .padding(1.5 * scale)
            }
            .shadow(color: shadow, radius: 3 * scale, y: 1.5 * scale)
        case .stamp:
            Rectangle()
                .fill(color)
                .overlay(Rectangle().strokeBorder(Color.black.opacity(0.1), lineWidth: 1).padding(11 * scale))
                .mask(StampShape(radius: 5 * scale).fill(style: FillStyle(eoFill: true)))
                .shadow(color: shadow, radius: 3 * scale, y: 1.5 * scale)
        case .lace:
            LaceCard(color: color, scale: scale)
                .shadow(color: .black.opacity(0.3), radius: 3 * scale, y: 1.5 * scale)
        }
    }
}

/// Papierkante mit unregelmäßig gerissenem Rand.
struct TornEdge: Shape {
    let seed: UInt64
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let step = max(2, depth)
        var p = Path()
        func jitter() -> CGFloat { .random(in: 0...depth, using: &rng) }
        p.move(to: CGPoint(x: rect.minX + jitter(), y: rect.minY + jitter()))
        for x in stride(from: rect.minX, through: rect.maxX, by: step) { p.addLine(to: CGPoint(x: x, y: rect.minY + jitter())) }
        for y in stride(from: rect.minY, through: rect.maxY, by: step) { p.addLine(to: CGPoint(x: rect.maxX - jitter(), y: y)) }
        for x in stride(from: rect.maxX, through: rect.minX, by: -step) { p.addLine(to: CGPoint(x: x, y: rect.maxY - jitter())) }
        for y in stride(from: rect.maxY, through: rect.minY, by: -step) { p.addLine(to: CGPoint(x: rect.minX + jitter(), y: y)) }
        p.closeSubpath()
        return p
    }
}

/// Rechteck plus Kreise auf den Kanten; mit Even-Odd gefüllt ergibt das den Briefmarkenrand.
struct StampShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path(rect)
        let spacing = radius * 3
        func circle(_ c: CGPoint) { p.addEllipse(in: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)) }
        let nx = max(1, Int(rect.width / spacing)), ny = max(1, Int(rect.height / spacing))
        for i in 0..<nx {
            let x = rect.minX + rect.width * (CGFloat(i) + 0.5) / CGFloat(nx)
            circle(CGPoint(x: x, y: rect.minY))
            circle(CGPoint(x: x, y: rect.maxY))
        }
        for i in 0..<ny {
            let y = rect.minY + rect.height * (CGFloat(i) + 0.5) / CGFloat(ny)
            circle(CGPoint(x: rect.minX, y: y))
            circle(CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

/// Papierdeckchen: Bogenrand mit Lochmuster und glattem Innenfeld.
struct LaceCard: View {
    let color: Color
    let scale: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let r = 9 * scale
            let outer = CGRect(origin: .zero, size: size).insetBy(dx: r, dy: r)
            let band = r * 2.2
            let inner = outer.insetBy(dx: band, dy: band)
            func dot(_ c: CGPoint, _ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
            }

            ctx.fill(Path(outer), with: .color(color))
            for c in perimeter(outer, spacing: r * 1.5) { ctx.fill(dot(c, r), with: .color(color)) }

            // Löcher ausstanzen
            ctx.blendMode = .destinationOut
            for c in perimeter(outer, spacing: r * 1.5) { ctx.fill(dot(c, r * 0.22), with: .color(.black)) }
            for c in perimeter(outer.insetBy(dx: band * 0.55, dy: band * 0.55), spacing: r * 0.7) {
                ctx.fill(dot(c, r * 0.13), with: .color(.black))
            }
            let mesh = r * 0.55
            let keep = inner.insetBy(dx: -mesh, dy: -mesh)
            var y = outer.minY + mesh
            while y < outer.maxY {
                var x = outer.minX + mesh
                while x < outer.maxX {
                    let p = CGPoint(x: x, y: y)
                    if !keep.contains(p) { ctx.fill(dot(p, r * 0.07), with: .color(.black)) }
                    x += mesh
                }
                y += mesh
            }
            ctx.blendMode = .normal

            // Innenfeld mit gepunktetem Rand
            ctx.fill(Path(inner), with: .color(color))
            ctx.fill(Path(inner), with: .color(.black.opacity(0.03)))
            for c in perimeter(inner, spacing: r * 0.45) { ctx.fill(dot(c, r * 0.1), with: .color(.black.opacity(0.3))) }
        }
    }

    private func perimeter(_ rect: CGRect, spacing: CGFloat) -> [CGPoint] {
        let nx = max(1, Int((rect.width / spacing).rounded())), ny = max(1, Int((rect.height / spacing).rounded()))
        var points: [CGPoint] = []
        for i in 0...nx {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(nx)
            points += [CGPoint(x: x, y: rect.minY), CGPoint(x: x, y: rect.maxY)]
        }
        for i in 1..<ny {
            let y = rect.minY + rect.height * CGFloat(i) / CGFloat(ny)
            points += [CGPoint(x: rect.minX, y: y), CGPoint(x: rect.maxX, y: y)]
        }
        return points
    }
}

/// Leichte Papierstruktur aus zufälligen (aber stabilen) Punkten.
struct PaperGrain: View {
    var density: CGFloat = 80

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 42)
            let count = Int(size.width * size.height / density)
            for _ in 0..<count {
                let x = Double.random(in: 0..<size.width, using: &rng)
                let y = Double.random(in: 0..<size.height, using: &rng)
                let r = Double.random(in: 0.4...1.1, using: &rng)
                let dark = Bool.random(using: &rng)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(dark ? .black.opacity(0.06) : .white.opacity(0.25)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
