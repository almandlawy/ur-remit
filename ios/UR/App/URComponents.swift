import SwiftUI

// MARK: - URCard
struct URCard<Content: View>: View {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                URColor.surface.opacity(0.92),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(URColor.hairline, lineWidth: 1)
            )
            .shadow(color: URColor.deepNavy.opacity(0.045), radius: 10, y: 4)
    }
}

// MARK: - URBrandLogo
struct URBrandLogo: View {
    var size: CGFloat = 44
    var showsBorder = true

    var body: some View {
        Image("URBrandLogo")
            .resizable().scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(URColor.premiumGold.opacity(0.55), lineWidth: 1)
                }
            }
            .shadow(color: URColor.deepNavy.opacity(0.13), radius: 6, y: 3)
            .accessibilityLabel("شعار أور جلوبال")
    }
}

// MARK: - URPageTitle
struct URPageTitle: View {
    let title: String
    let subtitle: String
    var symbol: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let symbol {
                URIconBadge(symbol: symbol, size: 46)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.black))
                    .foregroundStyle(URColor.deepNavy)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(URColor.deepNavy.opacity(0.60))
            }

            Spacer()

            URBrandLogo(size: 42)
        }
    }
}

// MARK: - URIconBadge
struct URIconBadge: View {
    var symbol: String
    var size: CGFloat = 40
    var tint: Color = URColor.deepNavy
    var background: Color = URColor.premiumGold.opacity(0.16)

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .frame(width: size, height: size)
            .foregroundStyle(tint)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(URColor.hairline, lineWidth: 1)
            )
    }
}

// MARK: - URPrimaryButtonStyle
struct URPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .background(
                isEnabled
                ? AnyShapeStyle(
                    LinearGradient(
                        colors: [URColor.premiumGold, URColor.royalBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                : AnyShapeStyle(URColor.deepNavy.opacity(0.25)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(
                color: isEnabled ? URColor.premiumGold.opacity(0.30) : .clear,
                radius: configuration.isPressed ? 4 : 8,
                y: configuration.isPressed ? 3 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
