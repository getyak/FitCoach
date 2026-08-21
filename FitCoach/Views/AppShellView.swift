import SwiftUI

enum AppTab: Hashable {
    case today
    case clients
    case templates
    case profile
}

struct AppShellView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView()
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
    }
}
