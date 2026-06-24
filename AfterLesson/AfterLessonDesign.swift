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

// MARK: - Nav Pill (Home)

struct GrünbuchNavPill: View {
    let icon: String
    let label: String
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
                    if !value.isEmpty {
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
