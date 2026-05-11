import SwiftData
import SwiftUI

@main
struct LiftApp: App {
    @State private var persistenceService = PersistenceService()

    var body: some Scene {
        WindowGroup {
            AppRootView(persistenceService: persistenceService)
                .modelContainer(persistenceService.container)
        }
    }
}

private struct AppRootView: View {
    @Bindable var persistenceService: PersistenceService

    var body: some View {
        Group {
            if persistenceService.isBootstrapped {
                ContentView()
            } else {
                ProgressView()
            }
        }
        .task {
            persistenceService.bootstrap()
        }
        .fullScreenCover(isPresented: $persistenceService.shouldShowOnboarding) {
            FirstRunWizard(persistenceService: persistenceService)
        }
    }
}
