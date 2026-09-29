import SwiftUI

// MARK: - URColor
enum URColor {
    // Primary Brand
    static let deepNavy = Color(red: 0.012, green: 0.08, blue: 0.21)
    static let royalBlue = Color(red: 0.015, green: 0.18, blue: 0.31)
    static let premiumGold = Color(red: 0.67, green: 0.49, blue: 0.16)

    // Surfaces
    static let ivory = Color(red: 0.993, green: 0.985, blue: 0.963)
    static let hairline = Color(red: 0.80, green: 0.77, blue: 0.68).opacity(0.48)

    // Semantic
    static let success = Color(red: 0.00, green: 0.50, blue: 0.27)
    static let error = Color(red: 0.78, green: 0.08, blue: 0.15)
    static let warning = Color.orange
}

// MARK: - URTextField
struct URTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var symbol: String? = nil
    var isSecure: Bool = false
    var helperText: String? = nil
    var errorMessage: String? = nil

    @State private var isRevealed = false

    private var hasError: Bool { errorMessage != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(URColor.deepNavy.opacity(0.70))

            HStack(spacing: 10) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(hasError ? URColor.error : URColor.deepNavy.opacity(0.55))
                        .frame(width: 20)
                }

                Group {
                    if isSecure && !isRevealed {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.body)
                .foregroundStyle(URColor.deepNavy)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(URColor.deepNavy.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(hasError ? URColor.error : URColor.hairline, lineWidth: 1)
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(URColor.error)
            } else if let helperText {
                Text(helperText)
                    .font(.caption2)
                    .foregroundStyle(URColor.deepNavy.opacity(0.50))
            }
        }
    }
}
