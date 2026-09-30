import SwiftUI
import AuthenticationServices
import OSLog

@main
struct URRemitApp: App {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "URRemit", category: "PriceAlerts")
    @StateObject private var auth = URAuthService.live
    @State private var favorites = FavoritesStore.shared
    @State private var showSplash = true
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Guests are never forced to sign in: rates, offices, tracking and the rest of
                // RootView's public tabs are available without an account. Sign-in is optional
                // and reachable from More → "حسابي / تسجيل الدخول الاختياري" (see AccountView).
                RootView(container: container)
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

