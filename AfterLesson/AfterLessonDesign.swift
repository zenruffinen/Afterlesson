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
}

// MARK: - Home Background (LockView-Gradient)

struct GrünbuchHomeBackground: View {
    var body: some View {
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

            Circle()
                .fill(ALColor.gold.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 55)
                .offset(x: -90, y: -180)

            Circle()
                .fill(ALColor.green.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 48)
                .offset(x: 110, y: 240)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Golf Bag Icon (Header)

struct GrünbuchBagIcon: View {
    var size: CGFloat = 36

    private var corner: CGFloat { size * 0.28 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "3A8A3E"), Color(hex: "1B4D1F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "bag.fill")
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.5)
        )
        .shadow(color: ALColor.green.opacity(0.30), radius: size * 0.10, y: size * 0.04)
    }
}

// MARK: - Home Header

struct GrünbuchHomeHeader: View {
    let roleLabel: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            GrünbuchBagIcon(size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("Grünbuch")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text(roleLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .alGlass(tint: ALColor.green.opacity(0.30), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }
}

// MARK: - Fairway Graphic (Home)

struct GrünbuchFairwayGraphic: View {
    @State private var sway = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "1A3D1E").opacity(0.55),
                            Color(hex: "0D160D").opacity(0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )

            // Fairway silhouette
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.72))
                    path.addQuadCurve(
                        to: CGPoint(x: w, y: h * 0.68),
                        control: CGPoint(x: w * 0.5, y: h * 0.52)
                    )
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [ALColor.fairway.opacity(0.85), ALColor.green.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Sand bunker accent
                Ellipse()
                    .fill(ALColor.sand.opacity(0.22))
                    .frame(width: w * 0.22, height: h * 0.10)
                    .offset(x: w * 0.62, y: h * 0.58)

                // Flag on green
                VStack(spacing: 0) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ALColor.gold)
                    Rectangle()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 1.5, height: 28)
                }
                .offset(x: w * 0.78, y: h * 0.28)

                // Golfer line art
                Image(systemName: "figure.golf")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.white.opacity(0.88))
                    .shadow(color: ALColor.green.opacity(0.35), radius: 12, y: 6)
                    .offset(x: w * 0.08, y: h * 0.10)
                    .rotationEffect(.degrees(sway ? -2 : 2))
                    .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: sway)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .onAppear { sway = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Composer-Orb (die Drehscheibe als Aktionsfläche)
//
// Der große grüne Aktionsknopf des Startbildschirms: eine runde
// "Drehscheibe" aus Liquid Glass mit langsam rotierendem Ring und
// sanftem Puls — beim Tippen öffnet sich der Composer, der die
// gesammelten Lerninhalte den Schülern zuweist.

private struct OrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GrünbuchComposerOrb: View {
    let action: () -> Void

    @State private var spin = false
    @State private var breathe = false

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    // Weicher Glow-Atem hinter der Scheibe
                    Circle()
                        .fill(ALColor.green.opacity(breathe ? 0.45 : 0.20))
                        .frame(width: 150, height: 150)
                        .blur(radius: 24)

                    // Glasring außen
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        .frame(width: 138, height: 138)
                        .background(Circle().fill(Color.white.opacity(0.06)))

                    // Rotierender Drehscheiben-Ring
                    Circle()
                        .stroke(
                            ALColor.gold.opacity(0.75),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [1, 14])
                        )
                        .frame(width: 122, height: 122)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(.linear(duration: 24).repeatForever(autoreverses: false), value: spin)

                    // Die grüne Scheibe selbst
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ALColor.fairway, ALColor.green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 104, height: 104)
                        .overlay(
                            // Lichtkante oben — das Liquid-Glass-Gefühl
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: ALColor.green.opacity(0.55), radius: 18, y: 8)

                    // Motiv: Inhalte fliegen zum Schüler
                    VStack(spacing: 3) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        Text("Composer")
                            .font(.system(size: 13, weight: .bold, design: .serif))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }

                Text("Lerninhalte zuweisen")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .buttonStyle(OrbPressStyle())
        .onAppear {
            spin = true
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .accessibilityLabel("Composer — Lerninhalte zuweisen")
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
