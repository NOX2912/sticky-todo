import SwiftUI

struct StarDecoration: View {
    let style: NoteTheme.Stars
    let size: CGFloat

    var body: some View {
        switch style {
        case .none: EmptyView()
        case .gold: GoldStar(size: size)
        case .silver: SilverStar(size: size)
        case .stitched: StitchedStar(size: size)
        case .felt: FeltStar(size: size)
        }
    }
}

struct StarShape: Shape {
    var innerRatio: CGFloat = 0.5

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<10 {
            let angle = Double(i) * .pi / 5 - .pi / 2
            let r = i.isMultiple(of: 2) ? outer : outer * innerRatio
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// Goldfolien-Stern
struct GoldStar: View {
    let size: CGFloat
    private let gold = LinearGradient(colors: [Color(hex: "#F3D46A"), Color(hex: "#D9AE35"), Color(hex: "#B98E22")],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        StarShape()
            .fill(gold)
            .overlay(StarShape().stroke(gold, style: StrokeStyle(lineWidth: size * 0.08, lineJoin: .round)))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.2), radius: size * 0.04, y: size * 0.03)
    }
}

/// Aufgeblähter Chromstern
struct SilverStar: View {
    let size: CGFloat

    var body: some View {
        StarShape(innerRatio: 0.48)
            .fill(RadialGradient(colors: [Color(hex: "#2E2F35"), Color(hex: "#7C7E88"), Color(hex: "#E9EAEE"), .white, Color(hex: "#A9AAB3")],
                                 center: .center, startRadius: 0, endRadius: size * 0.5))
            .overlay(StarShape(innerRatio: 0.48).stroke(
                LinearGradient(colors: [.white, Color(hex: "#C4C5CC"), Color(hex: "#7E7F88")], startPoint: .topLeading, endPoint: .bottomTrailing),
                style: StrokeStyle(lineWidth: size * 0.14, lineJoin: .round)))
            .overlay(
                Ellipse().fill(.white.opacity(0.85))
                    .frame(width: size * 0.14, height: size * 0.06)
                    .rotationEffect(.degrees(-35))
                    .offset(x: -size * 0.12, y: -size * 0.2))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.3), radius: size * 0.05, y: size * 0.04)
    }
}

/// Gestickter Aufnäher-Stern mit Fadenstruktur
struct StitchedStar: View {
    let size: CGFloat

    var body: some View {
        StarShape()
            .fill(LinearGradient(colors: [Color(hex: "#F5D86E"), Color(hex: "#D6AE3C")], startPoint: .top, endPoint: .bottom))
            .overlay(
                Canvas { ctx, s in
                    var x = -s.width
                    while x < s.width * 2 {
                        var thread = Path()
                        thread.move(to: CGPoint(x: x, y: 0))
                        thread.addLine(to: CGPoint(x: x + s.height * 0.6, y: s.height))
                        ctx.stroke(thread, with: .color(Color(hex: "#A8842A").opacity(0.3)), lineWidth: max(0.4, size * 0.012))
                        x += max(1, size * 0.03)
                    }
                }
                .clipShape(StarShape()))
            .overlay(StarShape().stroke(Color(hex: "#B8922E"), style: StrokeStyle(lineWidth: size * 0.05, lineJoin: .round)))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.25), radius: size * 0.04, y: size * 0.03)
    }
}

/// Roter Filzstern mit Ziernaht
struct FeltStar: View {
    let size: CGFloat

    var body: some View {
        StarShape()
            .fill(LinearGradient(colors: [Color(hex: "#B23A3A"), Color(hex: "#8A2326")], startPoint: .top, endPoint: .bottom))
            .overlay(StarShape().stroke(Color(hex: "#7A1F22"), style: StrokeStyle(lineWidth: size * 0.06, lineJoin: .round)))
            .overlay(
                StarShape()
                    .stroke(Color(hex: "#F0E2C8"), style: StrokeStyle(lineWidth: max(0.5, size * 0.02), dash: [size * 0.04, size * 0.03]))
                    .scaleEffect(0.78))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.3), radius: size * 0.04, y: size * 0.03)
    }
}

/// Mehrere kleine Goldsterne als Sticker-Gruppe
struct StarStickers: View {
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            GoldStar(size: 22 * scale).offset(x: 40 * scale, y: 0)
            GoldStar(size: 12 * scale).offset(x: 0, y: 8 * scale)
            GoldStar(size: 15 * scale).offset(x: 16 * scale, y: 26 * scale)
            GoldStar(size: 17 * scale).offset(x: 50 * scale, y: 44 * scale)
        }
        .frame(width: 70 * scale, height: 64 * scale, alignment: .topLeading)
    }
}

struct HeartShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.3),
                   control1: CGPoint(x: r.midX - w * 0.1, y: r.maxY - h * 0.15),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.6))
        p.addArc(center: CGPoint(x: r.minX + w * 0.25, y: r.minY + h * 0.3), radius: w * 0.25,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: r.minX + w * 0.75, y: r.minY + h * 0.3), radius: w * 0.25,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + h * 0.6),
                   control2: CGPoint(x: r.midX + w * 0.1, y: r.maxY - h * 0.15))
        p.closeSubpath()
        return p
    }
}

/// Roter Herzknopf mit vier Löchern
struct HeartButton: View {
    let size: CGFloat

    var body: some View {
        HeartShape()
            .fill(LinearGradient(colors: [Color(hex: "#E04A3C"), Color(hex: "#A81F18")], startPoint: .top, endPoint: .bottom))
            .overlay(HeartShape().stroke(Color(hex: "#8A1712"), lineWidth: size * 0.04))
            .overlay(HeartShape().stroke(.white.opacity(0.25), lineWidth: size * 0.03).scaleEffect(0.78))
            .overlay(
                Grid(horizontalSpacing: size * 0.07, verticalSpacing: size * 0.07) {
                    ForEach(0..<2, id: \.self) { _ in
                        GridRow {
                            ForEach(0..<2, id: \.self) { _ in
                                Circle().fill(Color(hex: "#F6E9E4")).frame(width: size * 0.11, height: size * 0.11)
                            }
                        }
                    }
                }
                .offset(y: size * 0.02))
            .frame(width: size, height: size * 0.92)
            .shadow(color: .black.opacity(0.3), radius: size * 0.05, y: size * 0.04)
    }
}

/// Washi-Tape-Streifen mit gezackten Enden
struct WashiTape: View {
    let color: Color
    let scale: CGFloat

    var body: some View {
        Rectangle()
            .fill(color.opacity(0.88))
            .overlay(PaperGrain(density: 30))
            .mask(TapeShape(tooth: 3 * scale))
            .frame(width: 74 * scale, height: 24 * scale)
            .shadow(color: .black.opacity(0.12), radius: 1 * scale, y: 0.5 * scale)
    }
}

struct TapeShape: Shape {
    let tooth: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        var y = rect.minY
        var out = false
        while y < rect.maxY {
            y = min(rect.maxY, y + tooth)
            p.addLine(to: CGPoint(x: rect.maxX - (out ? 0 : tooth), y: y))
            out.toggle()
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        while y > rect.minY {
            y = max(rect.minY, y - tooth)
            p.addLine(to: CGPoint(x: rect.minX + (out ? 0 : tooth), y: y))
            out.toggle()
        }
        p.closeSubpath()
        return p
    }
}

/// Bronzefarbene Klemmbrett-Klammer oben mittig
struct ClipboardClip: View {
    let scale: CGFloat
    private let bronze = LinearGradient(colors: [Color(hex: "#E6BA7C"), Color(hex: "#B07C3E"), Color(hex: "#8A5A28")],
                                        startPoint: .top, endPoint: .bottom)

    var body: some View {
        VStack(spacing: 0) {
            UnevenRoundedRectangle(topLeadingRadius: 8 * scale, topTrailingRadius: 8 * scale)
                .fill(bronze)
                .frame(width: 30 * scale, height: 20 * scale)
                .overlay(Circle().fill(Color(hex: "#F4EBDD")).frame(width: 5 * scale, height: 5 * scale).offset(y: -3 * scale))
            RoundedRectangle(cornerRadius: 3 * scale)
                .fill(bronze)
                .frame(width: 76 * scale, height: 20 * scale)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.35)).frame(height: max(0.5, scale)) }
        }
        .shadow(color: .black.opacity(0.35), radius: 2 * scale, y: 1.5 * scale)
    }
}

/// Senkrechte Büroklammer
struct PaperClip: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let outer = w / 2, inner = w * 3 / 8
        var p = Path()
        // innerer Schenkel runter, unten herum, rechts hoch, oben herum, langer linker Schenkel runter
        p.move(to: CGPoint(x: rect.minX + w / 4, y: rect.minY + h * 0.35))
        p.addLine(to: CGPoint(x: rect.minX + w / 4, y: rect.maxY - inner))
        p.addArc(center: CGPoint(x: rect.minX + w / 4 + inner, y: rect.maxY - inner),
                 radius: inner, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + outer))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + outer),
                 radius: outer, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - inner * 0.8))
        return p
    }
}
