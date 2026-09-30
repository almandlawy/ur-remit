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

// MARK: - Google "G" brand mark
/// Draws Google's official four-color "G" logomark from vector paths so the sign-in button matches
/// Google's brand guidelines without bundling an image asset or the GoogleSignIn SDK (this app signs
/// in via Supabase OAuth, not the native Google SDK). Colors match Google's published palette.
struct GoogleLogoMark: View {
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 48
            context.scaleBy(x: scale, y: scale)

            var blue = Path()
            blue.move(to: CGPoint(x: 46.98, y: 24.55))
            blue.addLine(to: CGPoint(x: 46.98, y: 20.09))
            blue.addLine(to: CGPoint(x: 24.48, y: 20.09))
            blue.addLine(to: CGPoint(x: 24.48, y: 29.09))
            blue.addLine(to: CGPoint(x: 37.4, y: 29.09))
            blue.addCurve(to: CGPoint(x: 32.42, y: 37.09),
                           control1: CGPoint(x: 36.83, y: 32.55),
                           control2: CGPoint(x: 35.06, y: 35.33))
            blue.addLine(to: CGPoint(x: 32.4, y: 37.22))
            blue.addLine(to: CGPoint(x: 39.28, y: 42.56))
            blue.addLine(to: CGPoint(x: 39.75, y: 42.6))
            blue.addCurve(to: CGPoint(x: 46.98, y: 24.55),
                           control1: CGPoint(x: 44.34, y: 38.35),
                           control2: CGPoint(x: 46.98, y: 32.02))
            blue.closeSubpath()
            context.fill(blue, with: .color(Color(red: 0.259, green: 0.522, blue: 0.957)))

            var green = Path()
            green.move(to: CGPoint(x: 24, y: 48))
            green.addCurve(to: CGPoint(x: 39.75, y: 42.6),
                            control1: CGPoint(x: 30.48, y: 48),
                            control2: CGPoint(x: 35.93, y: 45.87))
            green.addLine(to: CGPoint(x: 32.42, y: 37.09))
            green.addCurve(to: CGPoint(x: 24, y: 39.5),
                            control1: CGPoint(x: 30.18, y: 38.59),
                            control2: CGPoint(x: 27.32, y: 39.5))
            green.addCurve(to: CGPoint(x: 9.98, y: 29.51),
                            control1: CGPoint(x: 16.98, y: 39.5),
                            control2: CGPoint(x: 11.02, y: 35.19))
            green.addLine(to: CGPoint(x: 9.71, y: 29.53))
            green.addLine(to: CGPoint(x: 2.6, y: 34.99))
            green.addLine(to: CGPoint(x: 2.51, y: 35.24))
            green.addCurve(to: CGPoint(x: 24, y: 48),
                            control1: CGPoint(x: 7.02, y: 44.06),
                            control2: CGPoint(x: 14.84, y: 48))
            green.closeSubpath()
            context.fill(green, with: .color(Color(red: 0.204, green: 0.659, blue: 0.325)))

            var yellow = Path()
            yellow.move(to: CGPoint(x: 9.98, y: 29.51))
            yellow.addCurve(to: CGPoint(x: 9.02, y: 24),
                             control1: CGPoint(x: 9.36, y: 27.69),
                             control2: CGPoint(x: 9.02, y: 25.79))
            yellow.addCurve(to: CGPoint(x: 9.98, y: 18.49),
                             control1: CGPoint(x: 9.02, y: 22.21),
                             control2: CGPoint(x: 9.36, y: 20.31))
            yellow.addLine(to: CGPoint(x: 9.96, y: 18.23))
            yellow.addLine(to: CGPoint(x: 2.72, y: 12.7))
            yellow.addLine(to: CGPoint(x: 2.51, y: 12.76))
            yellow.addCurve(to: CGPoint(x: 0, y: 24),
                             control1: CGPoint(x: 0.92, y: 15.94),
                             control2: CGPoint(x: 0, y: 19.86))
            yellow.addCurve(to: CGPoint(x: 2.51, y: 35.24),
                             control1: CGPoint(x: 0, y: 28.14),
                             control2: CGPoint(x: 0.92, y: 32.06))
            yellow.addLine(to: CGPoint(x: 9.98, y: 29.51))
            yellow.closeSubpath()
            context.fill(yellow, with: .color(Color(red: 0.988, green: 0.737, blue: 0.020)))

            var red = Path()
            red.move(to: CGPoint(x: 24, y: 9.5))
            red.addCurve(to: CGPoint(x: 33.83, y: 13.33),
                         control1: CGPoint(x: 27.63, y: 9.5),
                         control2: CGPoint(x: 30.91, y: 10.77))
            red.addLine(to: CGPoint(x: 40.55, y: 6.6))
            red.addCurve(to: CGPoint(x: 24, y: 0),
                         control1: CGPoint(x: 36.35, y: 2.38),
                         control2: CGPoint(x: 30.68, y: 0))
            red.addCurve(to: CGPoint(x: 2.51, y: 12.76),
                         control1: CGPoint(x: 14.84, y: 0),
                         control2: CGPoint(x: 7.02, y: 3.94))
            red.addLine(to: CGPoint(x: 9.96, y: 18.23))
            red.addCurve(to: CGPoint(x: 24, y: 9.5),
                         control1: CGPoint(x: 11.98, y: 13.15),
                         control2: CGPoint(x: 17.55, y: 9.5))
            red.closeSubpath()
            context.fill(red, with: .color(Color(red: 0.918, green: 0.263, blue: 0.208)))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Google's "Continue with Google" button per Google's Sign In branding guidelines: white surface,
/// a hairline neutral border, the official multicolor "G" mark, and Google-styled type — distinct
/// from UR's gold/blue gradient primary action so it reads as a third-party identity provider.
struct GoogleSignInButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color(red: 0.259, green: 0.259, blue: 0.259))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(red: 0.796, green: 0.796, blue: 0.796), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
