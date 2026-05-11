import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
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
