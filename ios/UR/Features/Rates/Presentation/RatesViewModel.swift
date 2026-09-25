import Foundation
import Combine

@MainActor
final class RatesViewModel: ObservableObject {
    enum State { case idle, loading, loaded(RatesSnapshot), failed }

    private let repository: any RatesRepository
    @Published var state: State = .idle

    init(repository: any RatesRepository) { self.repository = repository }

    func load() async {
        state = .loading
        do { state = .loaded(try await repository.loadRates()) }
        catch is CancellationError { return }
        catch { state = .failed }
    }
}
