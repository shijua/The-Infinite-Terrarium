import SwiftUI

/// Application entry point. The full simulation stack is mounted from `RootView`.
@main
struct TerrariumApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
