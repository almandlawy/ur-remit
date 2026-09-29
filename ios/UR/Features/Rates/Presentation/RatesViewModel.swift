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

    private var realtimeClient: SupabaseRealtimeClient?
    private var realtimeTask: Task<Void, Never>?

    init(repository: any RatesRepository) { self.repository = repository }

    deinit {
        realtimeTask?.cancel()
        let client = realtimeClient
        Task { await client?.stop() }
    }

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

    /// Opens a Supabase Realtime subscription on the `rates` table so an admin's price edit shows up
    /// for every open app the instant it's saved, instead of waiting for the user to pull-to-refresh.
    /// Safe to call multiple times (e.g. re-entering the tab): a running subscription is left alone.
    /// Silently does nothing if Supabase configuration isn't present (e.g. a build without secrets).
    func startObservingRemoteChanges() {
        guard realtimeTask == nil,
              let projectURL = APIConfiguration.supabaseProjectURL,
              let apiKey = APIConfiguration.supabasePublishableKey,
              let client = SupabaseRealtimeClient(projectURL: projectURL, apiKey: apiKey)
        else { return }
        realtimeClient = client
        realtimeTask = Task { [weak self] in
            let stream = await client.changes(table: "rates")
            for await _ in stream {
                guard let self, !Task.isCancelled else { return }
                await self.load()
            }
        }
    }
}
