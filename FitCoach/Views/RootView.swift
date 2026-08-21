import SwiftUI
import SwiftData

/// App 入口。旧数据回填完成后再准备演示数据，失败会明确告知用户。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var migrationError: String?

    var body: some View {
        AppShellView()
            .task {
                if !ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                    do {
                        try LegacyDataBackfill.run(in: modelContext)
                    } catch {
                        migrationError = "旧数据升级失败：\(error.localizedDescription)"
                    }
                }
                DemoDataSeeder.prepareIfNeeded(in: modelContext)
            }
            .alert("数据升级未完成", isPresented: Binding(
                get: { migrationError != nil },
                set: { if !$0 { migrationError = nil } }
            )) {
                Button("好", role: .cancel) { migrationError = nil }
            } message: {
                Text(migrationError ?? "请重新启动 App 后再试")
            }
    }
}
