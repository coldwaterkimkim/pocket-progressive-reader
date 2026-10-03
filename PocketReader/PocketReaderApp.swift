import SwiftUI

@main
struct PocketReaderApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .statusBarHidden()
        }
    }
}
