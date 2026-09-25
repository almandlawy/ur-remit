import Foundation

struct Rate: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let routeNameArabic: String
    let routeNameEnglish: String
    let sourceCurrency: String
    let destinationCurrency: String
    let buy: Decimal?
    let sell: Decimal?
    let updatedAt: Date
    let sourceTimestamp: Date
    let version: Int
    let staleAfter: Date

    func displayName(locale: Locale) -> String {
        locale.language.languageCode?.identifier == "ar" ? routeNameArabic : routeNameEnglish
    }
}

