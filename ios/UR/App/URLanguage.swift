import SwiftUI

enum URLanguage: String, CaseIterable, Identifiable {
    case arabic = "ar"
    case english = "en"
    case kurdish = "ckb"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var direction: LayoutDirection { self == .english ? .leftToRight : .rightToLeft }

    var nativeName: String {
        switch self {
        case .arabic: "العربية"
        case .english: "English"
        case .kurdish: "کوردی"
        }
    }
}
