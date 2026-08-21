import SwiftUI
import SwiftData

struct WorkoutCompletionView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    let onDismiss: () -> Void

    @State private var showingTrend = false
    @State private var errorMessage: String?
    @State private var summaryDraft: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64, weight: .semibold))
                            .foregroundStyle(AppTheme.success)
                            .accessibilityHidden(true)
                        Text("本节训练完成")
                            .font(.largeTitle.bold())
                        Text("已安全保存到 \(session.student?.name ?? "学员") 的训练记录")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    HStack(spacing: 10) {
                        CompletionMetric(value: durationText, label: "训练时长")
                        CompletionMetric(value: "\(session.completedSetCount)", label: "完成组数")
                        CompletionMetric(value: remainingText, label: "剩余课时")
                            .accessibilityIdentifier("completion.remainingCredits")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("给学员的总结")
                            .font(.title3.bold())
                        TextEditor(text: $summaryDraft)
                            .frame(minHeight: 140)
                            .padding(10)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityIdentifier("completion.summary")
                            .onChange(of: summaryDraft) { _, newValue in
                                session.summary = newValue
                                try? modelContext.save()
                            }
                    }

                    ShareLink(item: summaryDraft) {
                        Label("分享训练总结", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("completion.share")

                    Button("查看体测趋势") { showingTrend = true }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                    Button("撤销完成并继续训练") { reopenSession() }
                        .foregroundStyle(.secondary)
                        .minimumTapTarget()

                    Button("返回今天", action: onDismiss)
                        .minimumTapTarget()
                        .accessibilityIdentifier("completion.done")
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, 32)
            }
            .background(AppTheme.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingTrend) {
                if let student = session.student {
                    NavigationStack {
                        MeasurementTrendView(student: student)
                    }
                }
            }
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "请稍后重试")
            }
            .onAppear {
                summaryDraft = session.summary
            }
        }
    }

    private var durationText: String {
        guard let startedAt = session.startedAt, let completedAt = session.completedAt else { return "—" }
        return "\(max(1, Int(completedAt.timeIntervalSince(startedAt) / 60))) 分"
    }

    private var remainingText: String {
        session.student?.remainingSessions.map { "\($0) 节" } ?? "不追踪"
    }

    private func reopenSession() {
        do {
            try SessionService(context: modelContext).reopen(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CompletionMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
