import SwiftUI
import SwiftData

/// App的真正入口：先看有没有"App使用者本人"的档案。
/// 没有 → 说明是第一次打开，先走 OnboardingView 填个人信息。
/// 有 → 直接进"我的学员"主页面，以后每次打开都会走这条路。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AppShellView()
            .task {
                if !ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                    try? LegacyDataBackfill.run(in: modelContext)
                }
                DemoDataSeeder.prepareIfNeeded(in: modelContext)
            }
    }
}
