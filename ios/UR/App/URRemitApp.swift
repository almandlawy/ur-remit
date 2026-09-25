import SwiftUI

@main
struct URRemitApp: App {
    private let container = AppContainer.live
    @StateObject private var auth = URAuthService.live

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .tint(URColor.royalBlue)
                .environmentObject(auth)
                .onOpenURL { auth.handle(url: $0) }
        }
    }
}
