import SwiftUI

private enum URTab: String, CaseIterable, Identifiable {
    case home, rates, calculator, tracking, more

    var id: Self { self }
    var title: LocalizedStringKey { LocalizedStringKey(rawValue) }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .rates: "chart.line.uptrend.xyaxis"
        case .calculator: "function"
        case .tracking: "shippingbox.fill"
        case .more: "ellipsis.circle.fill"
        }
    }
}

struct RootView: View {
    let container: AppContainer
    @State private var selection: URTab = .home

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView(repository: container.ratesRepository) }.tag(URTab.home)
            NavigationStack { RatesView(repository: container.ratesRepository) }.tag(URTab.rates)
            NavigationStack { CalculatorView(repository: container.ratesRepository) }.tag(URTab.calculator)
            NavigationStack { TrackingView(api: container.apiClient) }.tag(URTab.tracking)
            NavigationStack { MoreView(api: container.apiClient) }.tag(URTab.more)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            URBottomNavigation(selection: $selection)
        }
    }
}

private struct URBottomNavigation: View {
    @Binding var selection: URTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(URTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? URColor.royalBlue : .secondary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
