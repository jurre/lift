import SwiftData
import SwiftUI

@main
struct LiftApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(LiftModelContainer.shared)
    }
}
