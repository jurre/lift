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
                if persistenceService.shouldShowOnboarding {
                    FirstRunWizard(persistenceService: persistenceService)
                } else {
                    RootTabView()
                }
            } else {
                ProgressView()
            }
        }
        .task {
            persistenceService.bootstrap()
        }
    }
}
