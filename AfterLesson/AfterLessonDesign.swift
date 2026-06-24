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

    func alCardBackground(tint: Color = ALColor.green, cornerRadius: CGFloat = AfterLessonDesign.cornerRadius) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.08))
                }
        }
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
