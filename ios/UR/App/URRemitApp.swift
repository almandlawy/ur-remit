import SwiftUI

@main
struct URRemitApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .tint(URColor.royalBlue)
        }
    }
}

