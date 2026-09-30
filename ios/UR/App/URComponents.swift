import SwiftUI
import UIKit

// MARK: - Numeric keyboard "Done" toolbar
/// `.decimalPad`/`.numberPad` keyboards have no built-in dismiss key on iOS, which leaves users
/// stuck unable to close the keyboard after entering an amount or code. Attach this to any numeric
/// `TextField` bound to a `@FocusState` boolean to add a localized "تم" button above the keyboard
/// (with a light haptic), matching tap-outside/scroll dismissal elsewhere in the app.
struct NumericKeyboardDoneToolbar: ViewModifier {
    var isFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("تم") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isFocused.wrappedValue = false
                }
                .font(.body.weight(.bold))
            }
        }
    }
}

extension View {
    /// Adds a "تم" (Done) button above `.decimalPad`/`.numberPad` keyboards and lets tapping
    /// anywhere outside the focused field dismiss it too.
    func numericKeyboardDoneToolbar(focused isFocused: FocusState<Bool>.Binding) -> some View {
        modifier(NumericKeyboardDoneToolbar(isFocused: isFocused))
    }
}

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
                .white.opacity(0.88),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(URColor.hairline, lineWidth: 1)
            )
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

            Text("UR")
                .font(.title.weight(.black))
                .foregroundStyle(URColor.deepNavy)
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
