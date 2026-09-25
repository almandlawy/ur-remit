import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        TabView {
            NavigationStack { HomeView(repository: container.ratesRepository) }
                .tabItem { Label("home", systemImage: "house") }
            NavigationStack { RatesView(repository: container.ratesRepository) }
                .tabItem { Label("rates", systemImage: "chart.line.uptrend.xyaxis") }
            NavigationStack { PlaceholderView(title: "calculator", symbol: "function") }
                .tabItem { Label("calculator", systemImage: "function") }
            NavigationStack { PlaceholderView(title: "tracking", symbol: "shippingbox") }
                .tabItem { Label("tracking", systemImage: "shippingbox") }
            NavigationStack { PlaceholderView(title: "more", symbol: "ellipsis") }
                .tabItem { Label("more", systemImage: "ellipsis") }
        }
    }
}

private struct PlaceholderView: View {
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol)
            .navigationTitle(title)
    }
}

