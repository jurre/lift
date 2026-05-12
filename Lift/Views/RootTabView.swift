import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var draftReopenCoordinator = DraftReopenCoordinator()

    var body: some View {
        TabView {
            TodayView(draftReopenCoordinator: draftReopenCoordinator)
                .tabItem {
                    Label("Today", systemImage: "figure.strengthtraining.traditional")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .task {
            draftReopenCoordinator.setModelContext(modelContext)
            draftReopenCoordinator.load()
        }
        .sheet(
            isPresented: Binding(
                get: { draftReopenCoordinator.pendingDraft != nil },
                set: { _ in }
            )
        ) {
            DraftReopenSheet(coordinator: draftReopenCoordinator)
        }
        .safeAreaInset(edge: .bottom) {
            if let confirmationMessage = draftReopenCoordinator.confirmationMessage {
                SnackbarView(message: confirmationMessage)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .task(id: draftReopenCoordinator.confirmationMessage) {
            guard draftReopenCoordinator.confirmationMessage != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            draftReopenCoordinator.clearConfirmationMessage()
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewSupport.container)
}
