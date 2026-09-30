import Foundation

struct Rate: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let routeNameArabic: String
    let routeNameEnglish: String
    let sourceCurrency: String
    let destinationCurrency: String
    let buy: Decimal?
    let sell: Decimal?
    let feeFixed: Decimal?
    let feePercent: Decimal?
    let updatedAt: Date
    let sourceTimestamp: Date
    let version: Int
    let staleAfter: Date

    func displayName(locale: Locale) -> String {
        locale.language.languageCode?.identifier == "ar" ? routeNameArabic : routeNameEnglish
    }

    /// True once the source's own reported price age has passed the server-computed `staleAfter`
    /// cutoff (`sourceTimestamp + 15 minutes`, see `backend/src/store.ts`). Deliberately compares
    /// against the real source timestamp only — never the local device's fetch/render time — so a
    /// genuinely old upstream price is always surfaced as stale rather than appearing falsely live.
    func isStale(asOf now: Date = .now) -> Bool { now >= staleAfter }
}
