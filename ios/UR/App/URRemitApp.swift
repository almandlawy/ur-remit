import SwiftUI
import AuthenticationServices
import GoogleSignInSwift
import OSLog
import WidgetKit
import FacebookCore

// The SDK is initialized only after a client token is configured in the built app.
// App-event auto logging and advertiser-ID collection remain disabled pending
// privacy review and explicit configuration approval.
final class URMetaAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "FacebookClientToken") as? String,
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        return true
    }
}

@main
struct URRemitApp: App {
    @UIApplicationDelegateAdaptor(URMetaAppDelegate.self) private var metaAppDelegate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "URRemit", category: "PriceAlerts")
    @StateObject private var auth = URAuthService.live
    @State private var favorites = FavoritesStore.shared
    @State private var showSplash = true
    @AppStorage("ur.onboarding.completed") private var onboardingCompleted = false
    @AppStorage("ur.app.language") private var appLanguage = URLanguage.arabic.rawValue
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    RootView(container: container)
                }
                .environmentObject(auth)
                .environment(favorites)
                .environment(\.locale, selectedLanguage.locale)
                .environment(\.layoutDirection, selectedLanguage.direction)
                .onAppear { syncWidgetLanguage() }
                .onChange(of: appLanguage) { _, _ in syncWidgetLanguage() }
                .onOpenURL { url in
                    auth.handle(url: url)
                }
                .task {
                    let alertManager = PriceAlertManager.shared
                    await alertManager.refreshAuthorizationStatus()
                    alertManager.resetFiredIfNewDay()
                    await SmartNotificationService.shared.scheduleDailySummaries()

                    do {
                        let snapshot = try await container.ratesRepository.loadRates()
                        let usdIqd = snapshot.rates.first {
                            $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD"
                        }
                        RateHistoryStore.shared.record(rates: snapshot.rates)
                        if let usdIqd {
                            let shared = UserDefaults(suiteName: "group.com.urremit.shared")
                            if let buy = usdIqd.buy { shared?.set(NSDecimalNumber(decimal: buy).stringValue, forKey: "usd_iqd_buy") }
                            if let sell = usdIqd.sell { shared?.set(NSDecimalNumber(decimal: sell).stringValue, forKey: "usd_iqd_sell") }
                            shared?.set(usdIqd.sourceTimestamp, forKey: "usd_iqd_source_timestamp")

                            let widgetGroups: [String] = [
                                "دبي", "عُمان", "الصين", "تركيا", "التحويلات"
                            ]
                            let widgetRows: [[String: String]] = widgetGroups.compactMap { group in
                                guard let rate = snapshot.rates.first(where: { rate in
                                    let ar = rate.routeNameArabic
                                    let en = rate.routeNameEnglish
                                    switch group {
                                    case "دبي": return ar.contains("دبي") || en.localizedCaseInsensitiveContains("Dubai")
                                    case "عُمان": return ar.contains("سلطنة عمان") || en.compare("Oman", options: .caseInsensitive) == .orderedSame
                                    case "الصين": return ar.contains("الصين") || en.localizedCaseInsensitiveContains("China")
                                    case "تركيا": return ar.contains("تركيا") || en.localizedCaseInsensitiveContains("Türkiye") || en.compare("Turkey", options: .caseInsensitive) == .orderedSame
                                    default: return ar.contains("الحوالات البنكية") || ar.contains("ويسترن") || ar.contains("موني") || en.localizedCaseInsensitiveContains("Transfer") || en.localizedCaseInsensitiveContains("Western") || en.localizedCaseInsensitiveContains("MoneyGram")
                                    }
                                }) else { return nil }
                                let value: Decimal?
                                let unit: String
                                if let fee = rate.feeFixed {
                                    value = fee
                                    unit = "عمولة/10K"
                                } else {
                                    value = rate.sell ?? rate.buy
                                    unit = "\(rate.destinationCurrency)/\(rate.sourceCurrency)"
                                }
                                guard let value else { return nil }
                                return [
                                    "name": group,
                                    "value": NSDecimalNumber(decimal: value).stringValue,
                                    "code": unit
                                ]
                            }
                            if let data = try? JSONSerialization.data(withJSONObject: widgetRows) {
                                shared?.set(data, forKey: "widget_featured_routes")
                            }
                            WidgetCenter.shared.reloadTimelines(ofKind: "URUSD-IQD")
                        }
                        await DailyReminderManager.shared.refreshContent(usdIqd: usdIqd)

                        guard alertManager.isAuthorized else { return }

                        for rate in snapshot.rates {
                            guard let threshold = alertManager.threshold(for: rate.id),
                                  let current = rate.sell ?? rate.buy,
                                  current >= threshold else { continue }
                            await alertManager.fire(rate: rate, current: current, threshold: threshold)
                        }
                    } catch is CancellationError {
                        return
                    } catch {
                        Self.logger.error("Price and alert refresh failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
                .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { !onboardingCompleted && !showSplash },
                set: { if !$0 { onboardingCompleted = true } }
            )) {
                OnboardingView(isPresented: Binding(
                    get: { !onboardingCompleted },
                    set: { if !$0 { onboardingCompleted = true } }
                ))
            }
            .task {
                do {
                    try await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 1_100))
                } catch is CancellationError {
                    return
                } catch {
                    Self.logger.error("Splash delay failed: \(error.localizedDescription, privacy: .public)")
                }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    showSplash = false
                }
            }
        }
    }

    private var selectedLanguage: URLanguage {
        URLanguage(rawValue: appLanguage) ?? .arabic
    }

    private func syncWidgetLanguage() {
        UserDefaults(suiteName: "group.com.urremit.shared")?.set(appLanguage, forKey: "widget_language")
        WidgetCenter.shared.reloadTimelines(ofKind: "URUSD-IQD")
    }
}

// ثم AuthView,// MARK: - AuthView
struct AuthView: View {
    @EnvironmentObject private var auth: URAuthService

    @State private var nonce = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            URColor.ivory.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    URPageTitle(
                        title: "مرحباً بك",
                        subtitle: "سجّل الدخول للوصول إلى خدمات التحويل",
                        symbol: "lock.shield.fill"
                    )

                    URCard {
                        VStack(spacing: 20) {

                            VStack(spacing: 12) {
                                SignInWithAppleButton(.signIn) { request in
                                    nonce = URAuthService.randomNonce()
                                    auth.prepareAppleRequest(request, nonce: nonce)
                                } onCompletion: { result in
                                    switch result {
                                    case .success(let authorization):
                                        Task {
                                            await auth.signInWithApple(authorization: authorization, nonce: nonce)
                                        }
                                    case .failure:
                                        auth.message = "تعذر إكمال تسجيل الدخول بواسطة Apple."
                                    }
                                }
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 50)
                                .cornerRadius(14)

                                GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .light, style: .wide, state: .normal)) {
                                    Task { await auth.signInWithGoogle() }
                                }
                                .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
                                .accessibilityLabel("تسجيل الدخول باستخدام Google")
                            }

                            HStack {
                                Rectangle().fill(URColor.hairline).frame(height: 1)
                                Text("أو باستخدام البريد")
                                    .font(.caption)
                                    .foregroundStyle(URColor.deepNavy.opacity(0.50))
                                Rectangle().fill(URColor.hairline).frame(height: 1)
                            }
                            .padding(.vertical, 4)

                            VStack(spacing: 14) {
                                URTextField(
                                    title: "البريد الإلكتروني",
                                    text: $email,
                                    placeholder: "name@example.com",
                                    symbol: "envelope.fill"
                                )

                                URTextField(
                                    title: "كلمة المرور",
                                    text: $password,
                                    placeholder: "••••••••",
                                    symbol: "key.fill",
                                    isSecure: true
                                )
                            }

                            if let message = auth.message {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text(message)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(URColor.error)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    URColor.error.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            Button {
                                // ربط تسجيل الدخول بالبريد لاحقاً
                            } label: {
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("تسجيل الدخول")
                                }
                            }
                            .buttonStyle(URPrimaryButtonStyle(isEnabled: !email.isEmpty && !password.isEmpty))
                            .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.message)
    }
}
