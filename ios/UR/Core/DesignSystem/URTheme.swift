import SwiftUI
import UIKit

enum URColor {
    static let deepNavy = Color(red: 0.02, green: 0.07, blue: 0.15)
    static let royalBlue = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            UIColor(red: 0.48, green: 0.64, blue: 0.98, alpha: 1)
        } else {
            UIColor(red: 0.05, green: 0.25, blue: 0.67, alpha: 1)
        }
    })
    static let premiumGold = Color(red: 0.78, green: 0.62, blue: 0.23)
}

struct URCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.separator.opacity(0.35)))
    }
}
