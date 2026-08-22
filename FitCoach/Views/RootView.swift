import SwiftUI
import SwiftData

/// App 入口。旧数据回填完成后再准备演示数据，失败会明确告知用户。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var migrationError: String?
    @State private var isDataReady = false
    @State private var isPreparingData = false

    var body: some View {
        Group {
            if isDataReady {
                AppShellView()
            } else {
                ZStack {
                    AppTheme.paper.ignoresSafeArea()
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                        .accessibilityLabel("正在准备训练数据")
                }
            }
        }
            .task {
                guard !isDataReady, !isPreparingData else { return }
                isPreparingData = true
                defer { isPreparingData = false }
                do {
                    if !ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                        try LegacyDataBackfill.run(in: modelContext)
                    }
                    try DemoDataSeeder.prepareIfNeeded(in: modelContext)
                    isDataReady = true
                } catch {
                    migrationError = "数据准备失败：\(error.localizedDescription)"
                }
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
