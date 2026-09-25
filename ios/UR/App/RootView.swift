import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        TabView {
            NavigationStack { HomeView(repository: container.ratesRepository) }
                .tabItem { Label("home", systemImage: "house") }
            NavigationStack { RatesView(repository: container.ratesRepository) }
                .tabItem { Label("rates", systemImage: "chart.line.uptrend.xyaxis") }
            NavigationStack { CalculatorView(repository: container.ratesRepository) }
                .tabItem { Label("calculator", systemImage: "function") }
            NavigationStack { TrackingView(api: container.apiClient) }
                .tabItem { Label("tracking", systemImage: "shippingbox") }
            NavigationStack { MoreView(api: container.apiClient) }
                .tabItem { Label("more", systemImage: "ellipsis") }
        }
    }
}
