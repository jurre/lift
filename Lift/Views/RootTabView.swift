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

            PlaceholderTabView(
                title: "History",
                message: "No completed workouts yet.",
                systemImage: "clock.arrow.circlepath"
            )
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            PlaceholderTabView(
                title: "Settings",
                message: "Coming soon.",
                systemImage: "gear"
            )
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
    }
}

private struct PlaceholderTabView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(message)
            )
            .navigationTitle(title)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewSupport.container)
}
