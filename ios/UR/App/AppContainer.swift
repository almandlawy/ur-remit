import Foundation

struct AppContainer: Sendable {
    let ratesRepository: any RatesRepository
    let apiClient: any APIClient

    static let live: AppContainer = {
        let configuration = APIConfiguration.current
        let client = URLSessionAPIClient(configuration: configuration)
        let cache = FileRatesCache()
        return AppContainer(ratesRepository: DefaultRatesRepository(remote: client, cache: cache), apiClient: client)
    }()
}
