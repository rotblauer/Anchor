import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            PlanMapView()
                .tabItem { Label("Plan", systemImage: "map.fill") }
            PlacesListView()
                .tabItem { Label("Places", systemImage: "list.star") }
            ExploreView()
                .tabItem { Label("Explore", systemImage: "sparkles") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .task {
            await model.refreshIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // Coming back to the foreground: drop nights that ended while the
            // app slept, and refetch if the forecast has gone stale.
            model.pruneEndedNights()
            Task { await model.refreshIfNeeded() }
        }
    }
}
