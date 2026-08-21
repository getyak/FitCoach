import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentExerciseIndex: Int
    @State private var showingFinishConfirmation = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = 0

    init(session: WorkoutSession) {
        self.session = session
        _currentExerciseIndex = State(initialValue: session.activeExerciseIndex)
    }

    private var exercises: [ExerciseEntry] { session.sortedExercises }

    private var currentExercise: ExerciseEntry? {
        guard exercises.indices.contains(currentExerciseIndex) else { return exercises.first }
        return exercises[currentExerciseIndex]
    }

    var body: some View {
        Group {
            if session.status == .completed {
                WorkoutCompletionView(session: session, onDismiss: { dismiss() })
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            WorkoutProgressHeader(
                                session: session,
                                currentIndex: currentExerciseIndex,
                                totalExercises: exercises.count
                            )

                            if let currentExercise {
                                ExerciseSetEditor(
                                    exercise: currentExercise,
                                    session: session,
                                    onSetToggle: toggleSet,
                                    onValueChange: saveDraft
                                )
                                .id(currentExercise.id)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                            } else {
                                ContentUnavailableView("没有训练动作", systemImage: "dumbbell")
                            }

                            if let restEndsAt = session.restEndsAt {
                                RestTimerCard(endDate: restEndsAt) {
                                    session.restEndsAt = nil
                                    saveDraft()
                                }
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, AppTheme.pagePadding)
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                    }
                    .background(AppTheme.canvas)
                    .navigationTitle(session.student?.name ?? "训练中")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("稍后继续") { dismiss() }
                                .minimumTapTarget()
                                .accessibilityIdentifier("workout.pause")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("取消本节", systemImage: "xmark", role: .destructive) {
                                    session.status = .cancelled
                                    saveDraft()
                                    dismiss()
                                }
                            } label: {
                                Label("更多操作", systemImage: "ellipsis")
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        WorkoutBottomControls(
                            isLastExercise: currentExerciseIndex >= exercises.count - 1,
                            onPrevious: previousExercise,
                            onNext: nextExercise,
                            onFinish: { showingFinishConfirmation = true }
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
        .confirmationDialog(
            "完成本节训练？",
            isPresented: $showingFinishConfirmation,
            titleVisibility: .visible
        ) {
            Button(finishButtonTitle) { completeSession() }
            Button("继续训练", role: .cancel) { }
        } message: {
            Text("只有确认完成后才会扣除课时，计划中和暂停中的课程不会扣课。")
        }
        .alert("保存失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
    }

    private var finishButtonTitle: String {
        guard session.consumesCredit, let remaining = session.student?.remainingSessions else {
            return "完成训练"
        }
        return "完成并扣课（\(remaining) → \(remaining - 1) 节）"
    }

    private func toggleSet(_ set: WorkoutSet, restSeconds: Int) {
        do {
            let service = SessionService(context: modelContext)
            if set.isCompleted {
                try service.undoSet(set, in: session)
            } else {
                try service.completeSet(set, in: session, restSeconds: restSeconds)
                hapticTrigger += 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveDraft() {
        session.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func previousExercise() {
        guard currentExerciseIndex > 0 else { return }
        move(to: currentExerciseIndex - 1)
    }

    private func nextExercise() {
        guard currentExerciseIndex < exercises.count - 1 else {
            showingFinishConfirmation = true
            return
        }
        move(to: currentExerciseIndex + 1)
    }

    private func move(to index: Int) {
        let animation: Animation? = reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88)
        withAnimation(animation) {
            currentExerciseIndex = index
            session.activeExerciseIndex = index
        }
        saveDraft()
    }

    private func completeSession() {
        do {
            try SessionService(context: modelContext).complete(session)
            hapticTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct WorkoutProgressHeader: View {
    let session: WorkoutSession
    let currentIndex: Int
    let totalExercises: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 10) {
                HStack {
                    Label(elapsedText(at: context.date), systemImage: "timer")
                        .font(.headline)
                        .monospacedDigit()
                        .accessibilityIdentifier("workout.elapsedTime")
                    Spacer()
                    Text("动作 \(min(currentIndex + 1, max(1, totalExercises))) / \(max(1, totalExercises))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: session.progress)
                    .tint(AppTheme.brand)
                    .accessibilityLabel("训练完成进度")
                    .accessibilityValue("\(Int(session.progress * 100)) 百分比")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func elapsedText(at date: Date) -> String {
        let start = session.startedAt ?? session.date
        let seconds = max(0, Int(date.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ExerciseSetEditor: View {
    let exercise: ExerciseEntry
    let session: WorkoutSession
    let onSetToggle: (WorkoutSet, Int) -> Void
    let onValueChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(exercise.name)
                        .font(.title.bold())
                    Spacer()
                    if let targetRPE = exercise.targetRPE {
                        MetricPill(label: "目标", value: "RPE \(targetRPE.formatted())")
                    }
                }
                Label("上次最佳 · \(exercise.previousSummary)", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("workout.previousPerformance")
            }

            ForEach(exercise.sortedSets) { set in
                WorkoutSetRow(
                    set: set,
                    restSeconds: exercise.plannedRestSeconds,
                    onToggle: { onSetToggle(set, exercise.plannedRestSeconds) },
                    onValueChange: onValueChange
                )
            }

            if exercise.sortedSets.isEmpty {
                Text("这个动作还没有组记录")
                    .foregroundStyle(.secondary)
            }

            TextField("动作备注，例如：右膝感觉良好", text: Binding(
                get: { exercise.notes },
                set: { exercise.notes = $0; onValueChange() }
            ), axis: .vertical)
            .lineLimit(2...4)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("动作备注")
        }
    }
}

private struct WorkoutSetRow: View {
    @Bindable var set: WorkoutSet
    let restSeconds: Int
    let onToggle: () -> Void
    let onValueChange: () -> Void

    var body: some View {
        AppCard {
            VStack(spacing: 12) {
                HStack {
                    Text("第 \(set.sortIndex + 1) 组")
                        .font(.headline)
                    Spacer()
                    Button(action: onToggle) {
                        Label(set.isCompleted ? "已完成" : "完成本组", systemImage: set.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(set.isCompleted ? AppTheme.success : AppTheme.brand)
                    }
                    .minimumTapTarget()
                    .accessibilityIdentifier("workout.set.\(set.sortIndex).complete")
                }

                HStack(spacing: 8) {
                    SetValueControl(
                        label: "重量",
                        value: weightText,
                        decrease: { changeWeight(by: -2.5) },
                        increase: { changeWeight(by: 2.5) }
                    )
                    SetValueControl(
                        label: "次数",
                        value: "\(set.actualReps ?? set.plannedReps ?? 0)",
                        decrease: { changeReps(by: -1) },
                        increase: { changeReps(by: 1) }
                    )
                    SetValueControl(
                        label: "RPE",
                        value: (set.rpe ?? 7).formatted(),
                        decrease: { changeRPE(by: -0.5) },
                        increase: { changeRPE(by: 0.5) }
                    )
                }

                TextField("本组备注（可选）", text: Binding(
                    get: { set.notes },
                    set: { set.notes = $0; onValueChange() }
                ))
                .textFieldStyle(.plain)
                .font(.subheadline)
                .accessibilityLabel("第 \(set.sortIndex + 1) 组备注")
            }
        }
        .opacity(set.isCompleted ? 0.78 : 1)
        .accessibilityElement(children: .contain)
    }

    private var weightText: String {
        let weight = set.actualWeightKg ?? set.plannedWeightKg ?? 0
        return "\(weight.formatted())"
    }

    private func changeWeight(by amount: Double) {
        let current = set.actualWeightKg ?? set.plannedWeightKg ?? 0
        set.actualWeightKg = max(0, current + amount)
        onValueChange()
    }

    private func changeReps(by amount: Int) {
        let current = set.actualReps ?? set.plannedReps ?? 0
        set.actualReps = max(0, current + amount)
        onValueChange()
    }

    private func changeRPE(by amount: Double) {
        set.rpe = min(10, max(1, (set.rpe ?? 7) + amount))
        onValueChange()
    }
}

private struct SetValueControl: View {
    let label: String
    let value: String
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                Button(action: decrease) {
                    Image(systemName: "minus")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .minimumTapTarget()
                .accessibilityLabel("减少\(label)")
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 32)
                    .accessibilityLabel("\(label) \(value)")
                Button(action: increase) {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .minimumTapTarget()
                .accessibilityLabel("增加\(label)")
            }
            .frame(height: 44)
            .background(AppTheme.elevatedSurface, in: Capsule())
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RestTimerCard: View {
    let endDate: Date
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(endDate.timeIntervalSince(context.date).rounded(.up)))
            HStack(spacing: 14) {
                Image(systemName: remaining > 0 ? "timer" : "checkmark")
                    .font(.title2.weight(.semibold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining > 0 ? "自动休息" : "休息完成")
                        .font(.subheadline.weight(.semibold))
                    Text(remaining > 0 ? "\(remaining) 秒" : "可以开始下一组")
                        .font(.title2.bold())
                        .monospacedDigit()
                }
                Spacer()
                if remaining > 0 {
                    Button("跳过", action: onSkip)
                        .buttonStyle(.bordered)
                        .minimumTapTarget()
                }
            }
            .padding(16)
            .foregroundStyle(remaining > 0 ? Color.primary : AppTheme.success)
            .background(AppTheme.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("workout.restTimer")
        }
    }
}

private struct WorkoutBottomControls: View {
    let isLastExercise: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("上一个动作")

            Button(action: isLastExercise ? onFinish : onNext) {
                Label(isLastExercise ? "完成本节" : "下一动作", systemImage: isLastExercise ? "checkmark" : "chevron.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.brand)
            .accessibilityIdentifier(isLastExercise ? "workout.finish" : "workout.nextExercise")
        }
        .floatingTrainingChrome()
    }
}
