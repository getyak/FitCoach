import SwiftUI
import SwiftData

struct WorkoutCompletionView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    let onDismiss: () -> Void

    @State private var showingTrend = false
    @State private var showingReopenConfirmation = false
    @State private var errorMessage: String?
    @State private var summaryDraft: String = ""
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 6 : 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(
                                size: dynamicTypeSize.isAccessibilitySize ? 42 : 64,
                                weight: .semibold
                            ))
                            .foregroundStyle(AppTheme.success)
                            .accessibilityHidden(true)
                        Text("本节训练完成")
                            .font(.largeTitle.bold())
                        Text("已安全保存到 \(session.student?.name ?? "学员") 的训练记录")
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, dynamicTypeSize.isAccessibilitySize ? 8 : 20)

                    if dynamicTypeSize.isAccessibilitySize {
                        AppCard {
                            VStack(spacing: 10) {
                                CompletionMetricRow(value: durationText, label: "训练时长")
                                Divider()
                                CompletionMetricRow(value: "\(session.completedSetCount)", label: "完成组数")
                                Divider()
                                CompletionMetricRow(value: remainingText, label: "剩余课时")
                                    .accessibilityIdentifier("completion.remainingCredits")
                            }
                        }
                    } else {
                        HStack(spacing: 10) { completionMetrics }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("给学员的总结")
                            .font(dynamicTypeSize.isAccessibilitySize ? .headline : .title3.bold())
                        TextEditor(text: $summaryDraft)
                            .frame(minHeight: 108)
                            .padding(10)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityIdentifier("completion.summary")
                            .onChange(of: summaryDraft) { _, newValue in
                                session.summary = newValue
                                do {
                                    try modelContext.save()
                                } catch {
                                    modelContext.rollback()
                                    errorMessage = error.localizedDescription
                                }
                            }
                    }

                    completionActions

                    Button("撤销完成并继续训练") { showingReopenConfirmation = true }
                        .foregroundStyle(.primary)
                        .minimumTapTarget()
                        .accessibilityIdentifier("completion.reopen")
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, 32)
            }
            .background(AppTheme.canvas)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    Button("返回今天", action: onDismiss)
                        .font(.body.weight(.semibold))
                        .minimumTapTarget()
                        .accessibilityIdentifier("completion.done")
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .background(AppTheme.canvas)
            }
            .toolbar(.hidden, for: .navigationBar)
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
            .confirmationDialog(
                "撤销完成？",
                isPresented: $showingReopenConfirmation,
                titleVisibility: .visible
            ) {
                Button(reopenConfirmationTitle, role: .destructive) { reopenSession() }
                Button("保持已完成", role: .cancel) { }
            } message: {
                Text(reopenConfirmationMessage)
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

    private var reopenConfirmationTitle: String {
        session.consumesCredit && session.student?.tracksCredits == true
            ? "撤销并返还 1 节课"
            : "撤销并继续训练"
    }

    private var reopenConfirmationMessage: String {
        session.consumesCredit && session.student?.tracksCredits == true
            ? "课程将恢复为训练中，本次扣除的 1 节课会通过退款流水返还。"
            : "课程将恢复为训练中，已保存的逐组记录会保留。"
    }

    @ViewBuilder private var completionMetrics: some View {
        CompletionMetric(value: durationText, label: "训练时长")
        CompletionMetric(value: "\(session.completedSetCount)", label: "完成组数")
        CompletionMetric(value: remainingText, label: "剩余课时")
            .accessibilityIdentifier("completion.remainingCredits")
    }

    @ViewBuilder private var completionActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                shareButton
                trendButton
            }
        } else {
            HStack(spacing: 10) {
                shareButton
                trendButton
            }
        }
    }

    private var shareButton: some View {
        ShareLink(item: summaryDraft) {
            Label("分享总结", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .accessibilityLabel("分享训练总结")
        .accessibilityIdentifier("completion.share")
    }

    private var trendButton: some View {
        Button(action: { showingTrend = true }) {
            Label("体测趋势", systemImage: "chart.xyaxis.line")
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .accessibilityLabel("查看体测趋势")
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
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct CompletionMetricRow: View {
    let value: String
    let label: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer(minLength: 16)
                Text(value)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(value)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
