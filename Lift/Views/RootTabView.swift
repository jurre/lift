import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.restTimer) private var restTimer
    @State private var draftReopenCoordinator = DraftReopenCoordinator()

    var body: some View {
        coreTabView
            .modifier(RestTimerAccessoryModifier(restTimer: restTimer))
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

    private var coreTabView: some View {
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
    }
}

private struct RestTimerAccessoryModifier: ViewModifier {
    let restTimer: RestTimerService?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabViewBottomAccessory {
                if let restTimer, restTimer.active != nil {
                    RestTimerOverlay(restTimer: restTimer)
                }
            }
        } else {
            content.safeAreaInset(edge: .bottom) {
                if let restTimer, restTimer.active != nil {
                    RestTimerOverlay(restTimer: restTimer)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewSupport.container)
}
