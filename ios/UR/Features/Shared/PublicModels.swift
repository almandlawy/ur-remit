import Foundation

struct Office: Codable, Identifiable, Sendable {
    let id: UUID; let publicCode: String; let nameArabic: String; let nameEnglish: String
    let countryArabic: String; let countryEnglish: String; let cityArabic: String; let cityEnglish: String
    let addressArabic: String; let addressEnglish: String; let latitude: String?; let longitude: String?
    let phone: String?; let whatsapp: String?; let verified: Bool
}

struct TransferTracking: Codable, Sendable {
    let reference: String; let origin: String; let destination: String; let status: String
    let lastUpdate: Date; let estimatedCompletion: Date?
}

struct AgentVerification: Codable, Sendable {
    struct LocalizedPlace: Codable, Sendable { let ar: String; let en: String }
    let tradeName: String?; let country: LocalizedPlace?; let city: LocalizedPlace?; let status: String
}
