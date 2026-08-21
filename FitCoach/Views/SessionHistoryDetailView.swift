import SwiftUI
import SwiftData

/// 训练历史只负责呈现已经保存的数据。进行中的课程统一回到训练现场，
/// 避免从历史入口绕过逐组记录与课时状态机。
struct SessionHistoryDetailView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @State private var activeSession: WorkoutSession?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                summaryCard

                ForEach(session.sortedExercises) { exercise in
                    exerciseCard(exercise)
                }

                if session.status == .inProgress || session.status == .planned {
                    Button {
                        startOrResume()
                    } label: {
                        Label(session.status == .planned ? "开始本节训练" : "继续本节训练", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("history.resumeWorkout")
                }
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 32)
        }
        .background(AppTheme.canvas)
        .navigationTitle(session.title.isEmpty ? "训练记录" : session.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeSession) { workout in
            ActiveWorkoutView(session: workout)
        }
        .alert("无法开始", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
    }

    private var summaryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(statusText, systemImage: statusIcon)
                        .font(.headline)
                        .foregroundStyle(statusColor)
                    Spacer()
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    historyMetric(value: "\(session.completedSetCount)/\(session.totalSetCount)", label: "完成组数")
                    historyMetric(value: durationText, label: "训练时长")
                    historyMetric(value: session.consumesCredit ? "1 节" : "免费", label: "课时")
                }

                if !session.summary.isEmpty {
                    Divider()
                    Text("训练总结").font(.headline)
                    Text(session.summary).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func exerciseCard(_ exercise: ExerciseEntry) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(exercise.name).font(.title3.bold())
                    Spacer()
                    Text("\(exercise.sets.filter(\.isCompleted).count)/\(exercise.sets.count) 组")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                ForEach(exercise.sortedSets) { set in
                    HStack(spacing: 10) {
                        Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(set.isCompleted ? AppTheme.success : Color.secondary)
                            .accessibilityHidden(true)
                        Text("第 \(set.sortIndex + 1) 组")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(setDescription(set))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }

                if !exercise.notes.isEmpty {
                    Label(exercise.notes, systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func historyMetric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func setDescription(_ set: WorkoutSet) -> String {
        let weight = set.actualWeightKg ?? set.plannedWeightKg
        let reps = set.actualReps ?? set.plannedReps
        var parts: [String] = []
        if let weight { parts.append("\(weight.formatted()) kg") }
        if let reps { parts.append("\(reps) 次") }
        if let rpe = set.rpe { parts.append("RPE \(rpe.formatted())") }
        return parts.isEmpty ? "未记录" : parts.joined(separator: " · ")
    }

    private var durationText: String {
        guard let start = session.startedAt else { return "—" }
        let end = session.completedAt ?? Date()
        return "\(max(1, Int(end.timeIntervalSince(start) / 60))) 分"
    }

    private var statusText: String {
        switch session.status {
        case .planned: "计划中"
        case .inProgress: "进行中"
        case .completed: "已完成"
        case .cancelled: "已取消"
        }
    }

    private var statusIcon: String {
        switch session.status {
        case .planned: "calendar"
        case .inProgress: "play.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .cancelled: "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .inProgress: AppTheme.brand
        case .completed: AppTheme.success
        case .planned, .cancelled: .secondary
        }
    }

    private func startOrResume() {
        do {
            try SessionService(context: modelContext).start(session)
            activeSession = session
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
