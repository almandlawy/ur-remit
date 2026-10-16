import SwiftUI

private enum URTab: String, CaseIterable, Identifiable {
    case home, offices, rates, transfers, support, more

    var id: Self { self }
    var title: LocalizedStringKey {
        switch self {
        case .home: "home"
        case .offices: "offices"
        case .rates: "rates"
        case .transfers: "transfers"
        case .support: "support"
        case .more: "more"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .offices: "mappin.circle"
        case .rates: "chart.bar.fill"
        case .transfers: "arrow.left.arrow.right.circle.fill"
        case .support: "headphones"
        case .more: "ellipsis"
        }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var nativeScenePhase
    let container: AppContainer
    @State private var selection: URTab
    @State private var homeNavigationID = UUID()

    init(container: AppContainer) {
        self.container = container
        let arguments = ProcessInfo.processInfo.arguments
        let initial: URTab = arguments.contains("-showHome") ? .home
            : arguments.contains("-showRates") ? .rates
            : arguments.contains("-showOffices") ? .offices
            : arguments.contains("-showTransfers") ? .transfers
            : arguments.contains("-showSupport") ? .support
            : arguments.contains("-showMore") ? .more
            : .home
        _selection = State(initialValue: initial)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView(repository: container.ratesRepository, api: container.apiClient) }
                .id(homeNavigationID)
                .tag(URTab.home)
            NavigationStack { OfficesView(api: container.apiClient) }
                .tag(URTab.offices)
            NavigationStack { URRatesWorkspace { RatesView(repository: container.ratesRepository) } }
                .tag(URTab.rates)
            NavigationStack { CustomerRemittanceView() }
                .tag(URTab.transfers)
            NavigationStack { SupportView(repository: container.ratesRepository, api: container.apiClient) }
                .tag(URTab.support)
            NavigationStack { MoreView(api: container.apiClient, repository: container.ratesRepository) }
                .tag(URTab.more)
        }
        .toolbar(.hidden, for: .tabBar)
        .task { await URNativeTelemetry.launch() }
        .onChange(of: nativeScenePhase) { _, phase in if phase == .active { Task { await URNativeTelemetry.send("app_open") } } }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            URBottomNavigation(selection: $selection) { tab in
                if tab == .home { homeNavigationID = UUID() }
            }
        }
    }
}

private struct URBottomNavigation: View {
    @Binding var selection: URTab
    let onSelect: (URTab) -> Void
    @Namespace private var animationNamespace

    private func color(for tab: URTab) -> Color {
        selection == tab ? URColor.premiumGold : URColor.deepNavy.opacity(0.65)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(URTab.allCases) { tab in
                Button {
                    onSelect(tab)
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
        .sensoryFeedback(.selection, trigger: selection)
    }
}
