import Foundation
import AuthenticationServices
import Security

/// خدمة حذف الحساب — تتعامل مع Supabase + Apple Sign In revocation
@MainActor
final class DeleteAccountService {

    static let shared = DeleteAccountService()
    private init() {}

    // MARK: - Configuration

    /// قراءة الإعدادات من Info.plist (نفس UR Auth)
    private var projectURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: raw) else {
            preconditionFailure("SUPABASE_URL missing in Info.plist")
        }
        return url
    }

    private var publishableKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty else {
            preconditionFailure("SUPABASE_PUBLISHABLE_KEY missing in Info.plist")
        }
        return key
    }

    /// اسم الـ Edge Function اللي تحذف الحساب من السيرفر
    /// (لازم تسويها في Supabase — الشرح تحت)
    private let deleteFunctionName = "delete-account"

    // MARK: - Public API

    /// حذف الحساب — يرمي خطأ إذا فشل أي شي
    func deleteAccount() async throws {
        // 1. جيب التوكن الحالي
        guard let token = currentAccessToken() else {
            throw DeleteAccountError.notAuthenticated
        }

        // 2. اطلب من Supabase حذف الحساب (عبر Edge Function)
        try await callDeleteEndpoint(token: token)

        // 3. (اختياري لكن مُستحسن) ألغِ صلاحية Apple token
        // ملاحظة: Supabase عادة يسوي هذا من السيرفر تلقائياً،
        // فحطيناها كخطوة اختيارية إذا الـ Edge Function ما سوته.
        // try await revokeAppleTokenIfNeeded()

        // 4. امسح بيانات محلية إضافية (Favorites, Reminders, Cache)
        clearLocalUserData()
    }

    // MARK: - Network

    private func callDeleteEndpoint(token: String) async throws {
        let url = projectURL.appending(path: "functions/v1/\(deleteFunctionName)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Body اختياري — مفيد للـ logging
        let body: [String: String] = ["reason": "user_initiated"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw DeleteAccountError.network
        }

        switch http.statusCode {
        case 200..<300:
            return // نجح
        case 401:
            throw DeleteAccountError.notAuthenticated
        case 404:
            throw DeleteAccountError.endpointMissing
        case 500..<600:
            throw DeleteAccountError.serverError
        default:
            // حاول نقرأ رسالة الخطأ من الـ response
            let serverMessage = String(data: data, encoding: .utf8) ?? ""
            throw DeleteAccountError.unknown(serverMessage)
        }
    }

    // MARK: - Token

    /// يرجّع التوكن الحالي من URAuthService
    private func currentAccessToken() -> String? {
        // URAuthService.currentAccessToken() اللي أضفناها قبل شوي
        return URAuthService.live.currentAccessToken()
    }

    // MARK: - Apple Token Revocation (احتياطي)

    /// إذا احتجت تلغي صلاحية Apple token من التطبيق مباشرة
    /// (Supabase عادة يسوي هذا server-side، بس خليناها هنا للاحتياط)
    private func revokeAppleTokenIfNeeded() async throws {
        // نحتاج الـ authorizationCode الأصلي — عادة ما يكون متاح لاحقاً،
        // لهذا الحذف من السيرفر هو الحل الأمثل.
        // اتركها فارغة — Supabase Edge Function راح تسوي هذا.
    }

    // MARK: - Local Cleanup

    /// مسح بيانات المستخدم المحلية (غير الجلسة — الجلسة تُمسح في URAuthService)
    private func clearLocalUserData() {
        let defaults = UserDefaults.standard

        // Favorites (من FavoritesStore)
        defaults.removeObject(forKey: "ur.favorites")

        // Reminders (من DailyReminderManager)
        defaults.removeObject(forKey: "ur.daily_reminder")
        defaults.removeObject(forKey: "ur.reminder_enabled")

        // Price alerts (من PriceAlertManager)
        defaults.removeObject(forKey: "ur.price_alerts")

        // Cache الملفات (من FileRatesCache)
        clearRatesCache()

        defaults.synchronize()
    }

    private func clearRatesCache() {
        // امسح مجلد الكاش إذا موجود
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let ratesCache = caches.appendingPathComponent("URRemit/Rates")

        try? FileManager.default.removeItem(at: ratesCache)
    }
}

// MARK: - Errors

enum DeleteAccountError: LocalizedError {
    case notAuthenticated
    case network
    case endpointMissing
    case serverError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "انتهت الجلسة. الرجاء تسجيل الدخول مرة أخرى ثم المحاولة."
        case .network:
            return "تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى."
        case .endpointMissing:
            return "تعذر إتمام حذف الحساب حالياً. الرجاء المحاولة بعد قليل."
        case .serverError:
            return "حدث خطأ في الخادم. الرجاء المحاولة لاحقاً."
        case .unknown(let msg):
            return msg.isEmpty ? "تعذر حذف الحساب. حاول مرة أخرى." : msg
        }
    }
}
