import SwiftUI
import WidgetKit

enum AppTab: Hashable {
    case today
    case clients
    case templates
    case profile
}

struct AppShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .today
    @State private var requestedWorkoutID: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(requestedWorkoutID: $requestedWorkoutID)
            }
            .tabItem { Label("今天", systemImage: "sun.max.fill") }
            .tag(AppTab.today)

            NavigationStack {
                StudentListView()
            }
            .tabItem { Label("学员", systemImage: "person.2.fill") }
            .tag(AppTab.clients)

            NavigationStack {
                TemplatesView()
            }
            .tabItem { Label("模板", systemImage: "square.stack.3d.up.fill") }
            .tag(AppTab.templates)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .tint(AppTheme.brand)
        .onOpenURL { url in
            guard url.scheme == "fitcoach",
                  url.host == "workout",
                  let idText = url.pathComponents.dropFirst().first,
                  let id = UUID(uuidString: idText) else { return }
            selectedTab = .today
            requestedWorkoutID = id
        }
        .onContinueUserActivity(NSUserActivityTypeLiveActivity) { _ in
            // Older system presentations may resume the app without forwarding
            // the widget URL. Keep the user on Today without guessing a session.
            selectedTab = .today
        }
        .task {
            await RestActivityService.endExpiredActivities()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await RestActivityService.endExpiredActivities() }
        }
    }
}
