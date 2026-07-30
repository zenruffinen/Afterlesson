import SwiftUI

// MARK: - Design Tokens

enum AfterLessonDesign {
    static let cornerRadius: CGFloat = 20
    static let chipRadius: CGFloat = 14
    static let iconTileSize: CGFloat = 44
}

// MARK: - Glass Helpers (Arca-inspiriert, Golf-Farbwelt)

extension View {
    @ViewBuilder
    func alGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: some Shape = RoundedRectangle(cornerRadius: AfterLessonDesign.cornerRadius, style: .continuous)
    ) -> some View {
        let glass: Glass = {
            var base = Glass.regular
            if let tint { base = base.tint(tint) }
            if interactive { base = base.interactive() }
            return base
        }()
        self.glassEffect(glass, in: shape)
    }

    @ViewBuilder
    func alGlassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        alGlass(tint: tint, interactive: interactive, in: Capsule())
    }

    func alCardBackground(tint: Color = ALColor.green, cornerRadius: CGFloat = AfterLessonDesign.cornerRadius) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.10))
                }
        }
    }

    func alIconTile(tint: Color, size: CGFloat = AfterLessonDesign.iconTileSize) -> some View {
        frame(width: size, height: size)
            .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Grüner Seiten-Anstrich (22.07.): nachtgrüner Verlauf hinter
    /// Listen und Rastern — „die anderen Seiten sollen auch grün wie
    /// Grünbuch sein". Für Listen ersetzt er den grauen Systemgrund.
    func gruenbuchSeite() -> some View {
        scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "0C150D"),
                        Color(hex: "122415"),
                        Color(hex: "17301C")
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
    }

    /// Abendgarderobe-Karte (22.07.): Nachtgrün-Verlauf mit feiner
    /// Lichtkante — der gemeinsame Look aller Zeilen und Kacheln.
    func nachtKarte(radius: CGFloat = 14, hervorgehoben: Bool = false) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ALColor.nachtOben.opacity(0.92), ALColor.nachtUnten.opacity(0.95)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(hervorgehoben ? ALColor.goldHell.opacity(0.7) : Color.white.opacity(0.14),
                              lineWidth: hervorgehoben ? 1.2 : 0.5)
        )
    }
}

// MARK: - Gruppen-Icons (SF-Symbol ODER eigenes Golf-Bild)
// Eigene Bild-Icons werden im icon-Feld als "img:<Assetname>" gespeichert
// (z.B. "img:gb_ball_rot") — SF-Symbole bleiben wie gehabt reine Namen.

/// Zeichnet ein Gruppen-Icon: Golf-Bild aus dem Asset-Katalog oder SF-Symbol.
struct ClassIcon: View {
    let icon: String
    var color: Color = ALColor.green
    var side: CGFloat = 32          // Kantenlänge des Bild-Icons
    var symbolSize: CGFloat = 15    // Punktgröße des SF-Symbols

    /// Menü-taugliches SF-Symbol: Bild-Icons können in Menüs nicht
    /// gezeigt werden → Ordner-Symbol als Stellvertreter.
    static func menuSymbol(for icon: String) -> String {
        icon.hasPrefix("img:") ? "folder.fill" : icon
    }

    var body: some View {
        if icon.hasPrefix("img:") {
            Image(String(icon.dropFirst(4)))
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
        } else {
            Image(systemName: icon)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

/// Die 62 Golf-Bild-Icons für Lektionsgruppen (Hans' Bogen v2, 21.07.).
enum GruppenIcons {
    static let alle: [String] = [
        "gb_ball_rot", "gb_ball_blau", "gb_ball_schwarz", "gb_ball_weiss",
        "gb_ball_gruen", "gb_ball_gelb", "gb_ball_lila", "gb_ball_orange",
        "gb_driver", "gb_eisen", "gb_wedges", "gb_putter",
        "gb_bunker", "gb_rough", "gb_platz", "gb_fahne",
        "gb_entfernung", "gb_statistik", "gb_video", "gb_foto",
        "gb_notizen", "gb_uebungen", "gb_pokal", "gb_ziel",
        "gb_golfbag", "gb_cart", "gb_uhr", "gb_trackman",
        "gb_protipp", "gb_wetter", "gb_kalender", "gb_pfeife",
        "gb_abschlag", "gb_ballflug", "gb_schwung", "gb_routine",
        "gb_mental", "gb_fitness", "gb_trinken", "gb_team",
        "gb_course", "gb_checkliste", "gb_fitting", "gb_analyse",
        "gb_wissen", "gb_buecher", "gb_apps", "gb_sicherheit",
        "gb_cloud", "gb_sync", "gb_sprachaufnahme", "gb_videoaufnahme",
        "gb_pdf", "gb_erfassen_klein", "gb_gruppe_klein", "gb_schueler",
        "gb_trainer", "gb_lektionen", "gb_scorekarte", "gb_handicap",
        "gb_favoriten", "gb_suche",
    ]
}

// MARK: - Home Background (LockView-Gradient)

// Lebendiger Hintergrund (Hans' Golf-Studio-Briefing, 21.07.):
// ziehende Wolken, wandernde Lichtstrahlen und eine kaum merkliche
// Ken-Burns-Atmung — permanent, aber nie aufdringlich.
struct GrünbuchHomeBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "0D160D"),
                        Color(hex: "1B3D1F"),
                        Color(hex: "2D6A30").opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Atmende Schicht: Glühen, Wolken, Licht — ganz langsame
                // "Kamerafahrt" per Skalierung (Ken-Burns)
                ZStack {
                    Circle()
                        .fill(ALColor.gold.opacity(0.10))
                        .frame(width: 300, height: 300)
                        .blur(radius: 55)
                        .offset(x: -90 + 10 * sin(t / 23), y: -180 + 7 * sin(t / 17))

                    Circle()
                        .fill(ALColor.green.opacity(0.16))
                        .frame(width: 260, height: 260)
                        .blur(radius: 48)
                        .offset(x: 110 + 8 * sin(t / 29 + 2), y: 240 + 6 * sin(t / 21 + 1))

                    GrünbuchWolken(t: t)
                    GrünbuchLichtstrahlen(t: t)
                }
                .scaleEffect(1.06 + 0.045 * sin(t / 33))
            }
            .ignoresSafeArea()
        }
    }
}

/// Drei weiche Wolkenbänke, die in unterschiedlichem Tempo über den
/// Himmel ziehen (Rundlauf: links raus, rechts wieder rein).
private struct GrünbuchWolken: View {
    let t: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            wolke(w: w, period: 140, phase: 0.10, y: h * 0.10, breite: w * 0.75, hoehe: 54, alpha: 0.10)
            wolke(w: w, period: 95,  phase: 0.55, y: h * 0.20, breite: w * 0.55, hoehe: 40, alpha: 0.08)
            wolke(w: w, period: 180, phase: 0.80, y: h * 0.05, breite: w * 0.90, hoehe: 68, alpha: 0.07)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func wolke(w: CGFloat, period: Double, phase: Double,
                       y: CGFloat, breite: CGFloat, hoehe: CGFloat, alpha: Double) -> some View {
        let p = ((t / period) + phase).truncatingRemainder(dividingBy: 1)
        Capsule()
            .fill(Color.white.opacity(alpha))
            .frame(width: breite, height: hoehe)
            .blur(radius: 26)
            .position(x: (-0.4 + 1.8 * p) * w, y: y)
    }
}

/// Zwei schräge Lichtbahnen, die langsam über den Platz wandern —
/// wie Sonne durch Wolkenlücken.
private struct GrünbuchLichtstrahlen: View {
    let t: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            strahl(w: w, h: h, x: w * (0.30 + 0.22 * sin(t / 31)), breite: w * 0.34, alpha: 0.10)
            strahl(w: w, h: h, x: w * (0.72 + 0.18 * sin(t / 47 + 3)), breite: w * 0.22, alpha: 0.08)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func strahl(w: CGFloat, h: CGFloat, x: CGFloat, breite: CGFloat, alpha: Double) -> some View {
        LinearGradient(
            colors: [Color.white.opacity(alpha), Color.white.opacity(0)],
            startPoint: .top, endPoint: .bottom
        )
        .frame(width: breite, height: h * 0.85)
        .rotationEffect(.degrees(16))
        .blur(radius: 18)
        .position(x: x, y: h * 0.38)
    }
}

// MARK: - Fühlbare Tasten (Golf-Studio-Briefing: 1.03×, Glanz, Haptik, Feder)

struct GrünbuchTastenStyle: ButtonStyle {
    var radius: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                // Kurzer Glanz beim Drücken
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.26), Color.white.opacity(0.02)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .opacity(configuration.isPressed ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed ? 1.03 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

// MARK: - Golf Bag Icon (Header)

struct GrünbuchBagIcon: View {
    var size: CGFloat = 36

    private var corner: CGFloat { size * 0.28 }

    var body: some View {
        // Abendgarderobe: das goldene Buch auf Nachtgrün (22.07.)
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ALColor.nachtOben, ALColor.nachtUnten],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "book.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(ALColor.goldHell)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: size * 0.10, y: size * 0.05)
    }
}

// MARK: - Home Header

struct GrünbuchHomeHeader: View {
    let roleLabel: String
    var bellCount: Int = 0
    var onBell: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            GrünbuchBagIcon(size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("Grünbuch")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text(roleLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ALColor.goldHell.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Die Glocke: Frisches der letzten 24 Stunden, Antippen
            // springt dorthin, wo es liegt
            if let onBell {
                Button(action: onBell) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
                            .frame(width: 40, height: 40)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 40, height: 40)
                        if bellCount > 0 {
                            Text("\(min(bellCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: "0B150D"))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(ALColor.goldHell, in: Capsule())
                                .offset(x: 5, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .alGlass(tint: ALColor.nachtOben.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }
}

// MARK: - Fairway Graphic (Home)

struct GrünbuchFairwayGraphic: View {
    /// Von außen hochzählen (z.B. bei "Stunde erfassen") → der Ball
    /// fliegt erneut Richtung Fahne.
    var flightTrigger: Int = 0
    /// Kompakte Bühne für den Schüler-Start (kleiner, ohne Untertitel).
    var kompakt: Bool = false

    @State private var sway = false
    @State private var flug: CGFloat = 0        // 0…1 entlang der Flugbahn
    @State private var ballSichtbar = false
    @State private var kenBurns = false         // langsame Kamerafahrt im Foto

    var body: some View {
        // Abendgarderobe (22.07.): Nachtgrüne Bühne mit Schlagzeile links,
        // Golfer, gestrichelter Flugbahn und Fahne rechts.
        ZStack {
            // Das Bühnenbild: der Platz im Abendlicht (Hans' Foto, 22.07.)
            // mit langsamer Ken-Burns-Kamerafahrt und dunklem Schleier
            // links + unten, damit die Schlagzeile strahlen kann.
            Image("HeroPlatz")
                .resizable()
                .scaledToFill()
                .scaleEffect(kenBurns ? 1.10 : 1.02)
                .animation(.easeInOut(duration: 19).repeatForever(autoreverses: true), value: kenBurns)
                .frame(maxWidth: .infinity)
                .frame(height: kompakt ? 148 : 210)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ALColor.nachtUnten.opacity(0.88),
                                    ALColor.nachtUnten.opacity(0.45),
                                    ALColor.nachtUnten.opacity(0.05)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, ALColor.nachtUnten.opacity(0.55)],
                                startPoint: .center, endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
                )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // Schlagzeile (links)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Heute geht's los!")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ALColor.goldHell)
                    Text("Dein Spiel.\nDein Fortschritt.")
                        .font(.system(size: kompakt ? 19 : 23, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .fixedSize()
                    Rectangle()
                        .fill(ALColor.goldHell)
                        .frame(width: 42, height: 2)
                        .padding(.vertical, 3)
                    if !kompakt {
                        Text("Strukturiertes Training.\nMessbare Ergebnisse.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                }
                .frame(width: w * 0.55, alignment: .leading)
                .position(x: w * 0.30, y: h * 0.46)

                // Gestrichelte Flugbahn — die Strichel wandern langsam
                // Richtung Fahne (die Seite atmet, Hans, 22.07.)
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { ctx in
                    let phase = -CGFloat(ctx.date.timeIntervalSinceReferenceDate * 10)
                        .truncatingRemainder(dividingBy: 9)
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.66, y: h * 0.64))
                        path.addQuadCurve(
                            to: CGPoint(x: w * 0.88, y: h * 0.34),
                            control: CGPoint(x: w * 0.76, y: h * 0.10)
                        )
                    }
                    .stroke(ALColor.goldHell.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.4, dash: [4, 5], dashPhase: phase))
                }

                // Fahne auf dem Grün
                VStack(spacing: 0) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ALColor.goldHell)
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 1.5, height: 30)
                }
                .position(x: w * 0.885, y: h * 0.475)

                // Golfer
                Image(systemName: "figure.golf")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
                    .position(x: w * 0.665, y: h * 0.60)
                    .rotationEffect(.degrees(sway ? -1.5 : 1.5))
                    .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: sway)

                // Der Ball fliegt einmal die Bahn entlang, dann Ruhe.
                if ballSichtbar {
                    let startX = w * 0.66, endX = w * 0.88
                    let startY = h * 0.64, endY = h * 0.34
                    let bx = startX + (endX - startX) * flug
                    let by = startY + (endY - startY) * flug - sin(.pi * flug) * h * 0.30
                    Circle()
                        .fill(ALColor.goldHell)
                        .frame(width: 8, height: 8)
                        .shadow(color: ALColor.goldHell.opacity(0.8), radius: 3)
                        .position(x: bx, y: by)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: kompakt ? 148 : 210)
        .onAppear {
            sway = true
            kenBurns = true
            ballFliegt()
        }
        .onChange(of: flightTrigger) { _, _ in ballFliegt() }
        .accessibilityHidden(true)
    }

    private func ballFliegt() {
        flug = 0
        ballSichtbar = true
        withAnimation(.easeOut(duration: 1.7)) { flug = 1 }
        Task {
            try? await Task.sleep(for: .seconds(2.1))
            withAnimation(.easeOut(duration: 0.6)) { ballSichtbar = false }
        }
    }
}

// MARK: - Das ARCA-Wappen: A als Pfeil (Hans' Entwurf vom 19.07.2026)
//
// Die Spitze des A ist eine Pfeilspitze (aufwärts = Fortschritt),
// der Querbalken hält es als Buchstaben lesbar. Reine SwiftUI-Formen —
// skaliert verlustfrei vom Orb bis zum App-Icon.

struct GrünbuchEmblemHead: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX - rect.width * 0.42, y: rect.minY + rect.height * 0.30))
        p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.42, y: rect.minY + rect.height * 0.30))
        p.closeSubpath()
        return p
    }
}

struct GrünbuchEmblemLegs: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let apexY = rect.minY + rect.height * 0.26
        p.move(to: CGPoint(x: rect.midX - rect.width * 0.05, y: apexY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY))
        p.move(to: CGPoint(x: rect.midX + rect.width * 0.05, y: apexY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.maxY))
        p.move(to: CGPoint(x: rect.midX - rect.width * 0.24, y: rect.minY + rect.height * 0.66))
        p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.24, y: rect.minY + rect.height * 0.66))
        return p
    }
}

struct GrünbuchEmblemMark: View {
    var color: Color = .white

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GrünbuchEmblemHead().fill(color)
                GrünbuchEmblemLegs()
                    .stroke(color, style: StrokeStyle(lineWidth: geo.size.width * 0.16, lineCap: .round))
            }
        }
        .aspectRatio(0.82, contentMode: .fit)
    }
}

// MARK: - Composer-Orb (die Drehscheibe als Aktionsfläche)
//
// Der große grüne Aktionsknopf des Startbildschirms: eine runde
// "Drehscheibe" aus Liquid Glass mit langsam rotierendem Ring und
// sanftem Puls — beim Tippen öffnet sich der Composer, der die
// gesammelten Lerninhalte den Schülern zuweist.

// Abendgarderobe (22.07.): Der Composer als breite Karte — das Wappen
// wohnt in einem Medaillon mit dem rotierenden Punktring (der Ring bleibt!).
struct GrünbuchComposerCard: View {
    let action: () -> Void

    @State private var spin = false
    @State private var breathe = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Medaillon: Wappen + Punktring + Atem-Glühen
                ZStack {
                    Circle()
                        .fill(ALColor.goldHell.opacity(breathe ? 0.30 : 0.10))
                        .frame(width: 88, height: 88)
                        .blur(radius: 16)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: breathe)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ALColor.nachtOben, ALColor.nachtUnten],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 74, height: 74)
                        .overlay(Circle().strokeBorder(ALColor.goldHell.opacity(0.6), lineWidth: 1))
                    Circle()
                        .stroke(
                            ALColor.goldHell.opacity(0.7),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 11])
                        )
                        .frame(width: 62, height: 62)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: spin)
                    GrünbuchEmblemMark(color: ALColor.goldHell)
                        .frame(width: 34, height: 34)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Caddy")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    Text("Lerninhalte zusammenstellen")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ALColor.goldHell)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ALColor.nachtOben.opacity(0.95), ALColor.nachtUnten.opacity(0.98)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 7)
        }
        .buttonStyle(GrünbuchTastenStyle(radius: 24))
        .onAppear {
            spin = true
            breathe = true
        }
    }
}

// MARK: - Home-Werkzeugkacheln: Bücherregal & Golfer
//
// Die beiden Werkzeuge des Startbildschirms als Bild-Motive statt
// Icon-Zeilen: die Bibliothek als kleines Golfbücher-Regal, die
// Stunde als Golfer mit Ballflugbahn — gezeichnet mit SwiftUI-Formen,
// auf getöntem System-Glas (iOS-27-Designsprache).

struct GrünbuchBookshelfIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 3) {
                bookSpine(width: 13, height: 52, color: ALColor.green)
                bookSpine(width: 11, height: 60, color: ALColor.gold)
                bookSpine(width: 14, height: 46, color: Color(hex: "F2EDDC"))
                bookSpine(width: 12, height: 58, color: ALColor.fairway)
                bookSpine(width: 11, height: 48, color: Color(hex: "8D6E63"))
                    .rotationEffect(.degrees(9), anchor: .bottomLeading)
                    .padding(.leading, 2)
            }
            // Das Regalbrett
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 96, height: 3)
                .padding(.top, 1)
        }
        .accessibilityHidden(true)
    }

    private func bookSpine(width: CGFloat, height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(color)
            .frame(width: width, height: height)
            .overlay(alignment: .top) {
                // Goldene Titelbänder wie bei alten Lehrbüchern
                VStack(spacing: 3) {
                    Capsule().fill(Color.white.opacity(0.55)).frame(height: 1.5)
                    Capsule().fill(Color.white.opacity(0.35)).frame(height: 1.5)
                }
                .padding(.horizontal, 2)
                .padding(.top, 6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2.5)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 1)
    }
}

struct GrünbuchPlayerIllustration: View {
    @State private var sway = false

    var body: some View {
        ZStack {
            // Ballflugbahn — gestrichelt Richtung Fahne
            FlightPath()
                .stroke(
                    Color.white.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1, 6])
                )
            // Der Ball am Ende der Bahn
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .offset(x: 46, y: -24)
                .shadow(color: .white.opacity(0.6), radius: 3)

            // Der Golfer im Schwung
            Image(systemName: "figure.golf")
                .font(.system(size: 46, weight: .thin))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .rotationEffect(.degrees(sway ? -2 : 2))
                .offset(x: -24, y: 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                sway = true
            }
        }
        .accessibilityHidden(true)
    }

    private struct FlightPath: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX - 14, y: rect.midY + 18))
            p.addQuadCurve(
                to: CGPoint(x: rect.midX + 46, y: rect.midY - 24),
                control: CGPoint(x: rect.midX + 22, y: rect.midY - 34)
            )
            return p
        }
    }
}

struct GrünbuchToolTile<Illustration: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let tint: Color
    let action: () -> Void
    @ViewBuilder var illustration: Illustration

    var body: some View {
        // Abendgarderobe (22.07.): nachtgrüne Karte, Serifentitel mit
        // Goldstrich, goldener Pfeil-Chip unten rechts
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                illustration
                    .frame(height: 68)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Rectangle()
                        .fill(ALColor.goldHell.opacity(0.85))
                        .frame(width: 30, height: 1.5)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ALColor.nachtOben.opacity(0.95), ALColor.nachtUnten.opacity(0.98)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                        .frame(width: 28, height: 28)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ALColor.goldHell)
                }
                .padding(10)
            }
            .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
        }
        .buttonStyle(GrünbuchTastenStyle(radius: 22))
    }
}

// MARK: - Home Action Button

struct GrünbuchHomeActionButton: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 50, height: 50)
                    .background(tint.opacity(0.20), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .alGlass(tint: tint.opacity(0.28), interactive: true, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nav Pill (Home)

struct GrünbuchNavPill: View {
    let icon: String
    let label: String
    var subtitle: String? = nil
    let value: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .alIconTile(tint: tint, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.white.opacity(0.45))
                    } else if !value.isEmpty {
                        Text(value)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .alGlass(tint: tint.opacity(0.22), interactive: true, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Golf Ball Mark (Lock Screen)

struct AfterLessonGlassMark: View {
    var size: CGFloat = 96

    private var corner: CGFloat { size * 0.28 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "D4A840"), Color(hex: "8B6210")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "figure.golf")
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: ALColor.green.opacity(0.25), radius: size * 0.12, y: size * 0.06)
    }
}

// MARK: - Note Colors (Grünbuch-Palette)

enum ALNoteStyle {
    static let palette: [String] = [
        "2D6A30", "1B4D1F", "1565C0", "B8860B",
        "3A8A3E", "37474F", "E65100", "00695C"
    ]

    static func accent(hex: String) -> Color {
        switch hex.uppercased() {
        case "4A148C": return Color(hex: "3A8A3E")
        case "880E4F", "C2185B": return ALColor.gold
        default: return Color(hex: hex)
        }
    }
}

// MARK: - Status Badge

struct ShareStatusBadge: View {
    let status: ActivityStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(status.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.backgroundColor, in: Capsule())
    }
}

extension ActivityStatus {
    var foregroundColor: Color {
        switch self {
        case .sent:        return Color(hex: "1565C0")
        case .received:    return ALColor.green
        case .inProgress:  return Color(hex: "E65100")
        case .completed:   return ALColor.green
        case .new:         return ALColor.gold
        }
    }

    var backgroundColor: Color {
        foregroundColor.opacity(0.14)
    }
}
