import Foundation
import Combine

enum RateListFilter {
    static func matchingRates(
        _ rates: [Rate],
        searchText: String,
        favoriteIDs: Set<UUID>,
        favoritesOnly: Bool,
        locale: Locale
    ) -> [Rate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return rates
            .filter { rate in
                (!favoritesOnly || favoriteIDs.contains(rate.id))
                    && (query.isEmpty
                        || rate.displayName(locale: locale).localizedCaseInsensitiveContains(query)
                        || rate.sourceCurrency.localizedCaseInsensitiveContains(query)
                        || rate.destinationCurrency.localizedCaseInsensitiveContains(query))
            }
            .sorted { first, second in
                let firstIsFavorite = favoriteIDs.contains(first.id)
                let secondIsFavorite = favoriteIDs.contains(second.id)
                if firstIsFavorite != secondIsFavorite { return firstIsFavorite }
                return first.displayName(locale: locale)
                    .localizedCaseInsensitiveCompare(second.displayName(locale: locale)) == .orderedAscending
            }
    }
}

@MainActor
final class RatesViewModel: ObservableObject {
    enum State {
        case idle
        case loading(RatesSnapshot?)
        case loaded(RatesSnapshot)
        case failed(RatesSnapshot?)
    }

    private let repository: any RatesRepository
    @Published var state: State = .idle

    init(repository: any RatesRepository) { self.repository = repository }

    func load() async {
        let previousSnapshot: RatesSnapshot?
        switch state {
        case .loaded(let snapshot):
            previousSnapshot = snapshot
        case .loading(let snapshot), .failed(let snapshot):
            previousSnapshot = snapshot
        case .idle:
            previousSnapshot = nil
        }
        state = .loading(previousSnapshot)
        do { state = .loaded(try await repository.loadRates()) }
        catch is CancellationError {
            state = previousSnapshot.map(State.loaded) ?? .idle
        }
        catch { state = .failed(previousSnapshot) }
    }
}
