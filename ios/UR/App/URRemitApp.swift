import SwiftUI
import AuthenticationServices
import OSLog

@main
struct URRemitApp: App {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "URRemit", category: "PriceAlerts")
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var auth = URAuthService.live
    @State private var favorites = FavoritesStore.shared
    @State private var showSplash = true
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if auth.isAuthenticated {
                        RootView(container: container)
                    } else {
                        AuthView()
                    }
                }
                .environmentObject(auth)
                .environment(favorites)
                .onOpenURL { url in
                    auth.handle(url: url)
                }
                .task {
                    let alertManager = PriceAlertManager.shared
                    await alertManager.requestPermissionIfNeeded()
                    alertManager.resetFiredIfNewDay()
                    await DailyReminderManager.shared.reschedule()

                    do {
                        let snapshot = try await container.ratesRepository.loadRates()
                        let usdIqd = snapshot.rates.first {
                            $0.sourceCurrency == "USD" && $0.destinationCurrency == "IQD"
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
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { URAnalytics.shared.activated() }
                else if phase == .background { URAnalytics.shared.backgrounded() }
            }
            .task {
                do {
                    try await Task.sleep(for: .seconds(1.2))
                } catch is CancellationError {
                    return
                } catch {
                    Self.logger.error("Splash delay failed: \(error.localizedDescription, privacy: .public)")
                }
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
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
                        subtitle: "سجّل الدخول لحفظ تفضيلاتك ومتابعة معلومات UR",
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

                                Button {
                                    Task { await auth.signInWithGoogle() }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "g.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(URColor.royalBlue)

                                        Text("تسجيل الدخول بواسطة Google")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(URColor.deepNavy)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(URColor.hairline, lineWidth: 1)
                                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                                    )
                                }
                                .buttonStyle(.plain)
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
