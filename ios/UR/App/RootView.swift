import SwiftUI

private enum URTab: String, CaseIterable, Identifiable {
    case home, offices, rates, support, more

    var id: Self { self }
    var title: String {
        switch self {
        case .home: "الرئيسية"
        case .offices: "مراكزنا"
        case .rates: "الأسعار"
        case .support: "الدعم"
        case .more: "المزيد"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .offices: "mappin.circle"
        case .rates: "chart.bar.fill"
        case .support: "headphones"
        case .more: "ellipsis"
        }
    }
}

struct RootView: View {
    let container: AppContainer
    @State private var selection: URTab

    init(container: AppContainer) {
        self.container = container
        let arguments = ProcessInfo.processInfo.arguments
        let initial: URTab = arguments.contains("-showRates") ? .rates
            : arguments.contains("-showOffices") ? .offices
            : arguments.contains("-showSupport") ? .support
            : arguments.contains("-showMore") ? .more
            : .home
        _selection = State(initialValue: initial)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView(repository: container.ratesRepository, api: container.apiClient) }
                .tag(URTab.home)
            NavigationStack { OfficesView(api: container.apiClient) }
                .tag(URTab.offices)
            NavigationStack { RatesView(repository: container.ratesRepository) }
                .tag(URTab.rates)
            NavigationStack { SupportView(repository: container.ratesRepository, api: container.apiClient) }
                .tag(URTab.support)
            NavigationStack { MoreView(api: container.apiClient) }
                .tag(URTab.more)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            URBottomNavigation(selection: $selection)
        }
    }
}

private struct URBottomNavigation: View {
    @Binding var selection: URTab
    @Namespace private var animationNamespace

    private func color(for tab: URTab) -> Color {
        selection == tab ? URColor.premiumGold : URColor.deepNavy.opacity(0.65)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(URTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 17, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 36, height: 26)
                            .background(
                                selection == tab
                                ? URColor.premiumGold.opacity(0.12)
                                : Color.clear,
                                in: Capsule()
                            )
                        
                        Text(tab.title)
                            .font(.caption2.weight(selection == tab ? .bold : .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(color(for: tab))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) {
                        if selection == tab {
                            Capsule()
                                .fill(URColor.premiumGold)
                                .frame(width: 32, height: 3)
                                .offset(y: 4)
                                .matchedGeometryEffect(id: "activeTabIndicator", in: animationNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(URColor.ivory.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Divider()
                .background(URColor.hairline)
        }
    }
}
