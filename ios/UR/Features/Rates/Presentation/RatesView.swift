import SwiftUI

struct RatesView: View {
    @StateObject private var model: RatesViewModel
    @AppStorage("com.urremit.rates.favoriteIDs") private var storedFavoriteIDs = ""
    @Environment(\.locale) private var locale
    @State private var searchText = ""
    @State private var favoritesOnly = false

    init(repository: any RatesRepository) {
        _model = StateObject(wrappedValue: RatesViewModel(repository: repository))
    }

    private var favoriteIDs: Set<UUID> {
        Set(storedFavoriteIDs.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading(nil):
                List(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16).fill(.quaternary).frame(height: 110).redacted(reason: .placeholder)
                }.accessibilityLabel(Text("rates"))
            case .loading(let snapshot):
                if let snapshot {
                    ratesList(snapshot, isRefreshing: true, hasError: false)
                }
            case .loaded(let snapshot) where snapshot.rates.isEmpty:
                ContentUnavailableView {
                    Label("no_rates", systemImage: "chart.line.downtrend.xyaxis")
                } actions: {
                    Button("retry") { Task { await model.load() } }
                }
            case .loaded(let snapshot):
                ratesList(snapshot, isRefreshing: false, hasError: false)
            case .failed(let snapshot) where snapshot?.rates.isEmpty == true:
                ContentUnavailableView {
                    Label("rates_load_failed", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("retry") { Task { await model.load() } }
                }
            case .failed(let snapshot):
                if let snapshot {
                    ratesList(snapshot, isRefreshing: false, hasError: true)
                } else {
                    ContentUnavailableView {
                        Label("rates_load_failed", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("retry") { Task { await model.load() } }
                    }
                }
            }
        }
        .navigationTitle("rates")
        .searchable(text: $searchText, prompt: Text("search_rates_prompt"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesOnly.toggle()
                } label: {
                    Label(
                        favoritesOnly ? "show_all_rates" : "show_favorites",
                        systemImage: favoritesOnly ? "star.fill" : "star"
                    )
                }
                .accessibilityHint(Text(favoritesOnly ? "show_all_rates_hint" : "show_favorites_hint"))
            }
        }
        .task { if case .idle = model.state { await model.load() } }
    }

    private func ratesList(_ snapshot: RatesSnapshot, isRefreshing: Bool, hasError: Bool) -> some View {
        List {
            if isRefreshing {
                ProgressView("refreshing").frame(maxWidth: .infinity, alignment: .center)
            }
            if hasError {
                Label("refresh_failed_showing_saved", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
            }
            if snapshot.isFromCache {
                Label("offline_notice", systemImage: "wifi.slash").foregroundStyle(.secondary)
            }
            if snapshot.cacheWriteFailed {
                Label("rates_not_saved_for_offline", systemImage: "externaldrive.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
            let visibleRates = RateListFilter.matchingRates(
                snapshot.rates,
                searchText: searchText,
                favoriteIDs: favoriteIDs,
                favoritesOnly: favoritesOnly,
                locale: locale
            )
            if visibleRates.isEmpty {
                ContentUnavailableView {
                    Label(favoritesOnly ? "no_favorite_rates" : "no_matching_rates", systemImage: "magnifyingglass")
                } actions: {
                    if favoritesOnly {
                        Button("show_all_rates") { favoritesOnly = false }
                    } else if !searchText.isEmpty {
                        Button("clear_search") { searchText = "" }
                    }
                }
            }
            ForEach(visibleRates) { rate in
                URCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(rate.displayName(locale: locale)).font(.headline)
                            Text("\(rate.sourceCurrency) / \(rate.destinationCurrency)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            toggleFavorite(rate.id)
                        } label: {
                            Image(systemName: favoriteIDs.contains(rate.id) ? "star.fill" : "star")
                                .foregroundStyle(favoriteIDs.contains(rate.id) ? URColor.premiumGold : .secondary)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(favoriteIDs.contains(rate.id) ? "remove_favorite" : "add_favorite"))
                    }
                    if let buy = rate.buy { LabeledContent("buy_rate", value: buy.formatted()) }
                    if let sell = rate.sell { LabeledContent("sell_rate", value: sell.formatted()) }
                    if let fee = rate.feeFixed {
                        LabeledContent("fixed_fee", value: "\(fee >= 0 ? "+" : "")\(fee.formatted()) USD")
                    }
                    HStack(spacing: 4) {
                        Text("last_updated")
                        Text(rate.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption)
                    .foregroundStyle(Date.now >= rate.staleAfter ? .orange : .secondary)
                    if Date.now >= rate.staleAfter {
                        Label("rate_may_be_outdated", systemImage: "clock.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .listRowSeparator(.hidden)
            }
            if hasError {
                Button("retry") { Task { await model.load() } }
            }
        }
        .listStyle(.plain)
        .refreshable { await model.load() }
    }

    private func toggleFavorite(_ rateID: UUID) {
        var updatedIDs = favoriteIDs
        if updatedIDs.contains(rateID) {
            updatedIDs.remove(rateID)
        } else {
            updatedIDs.insert(rateID)
        }
        storedFavoriteIDs = updatedIDs.map(\.uuidString).sorted().joined(separator: ",")
    }
}
