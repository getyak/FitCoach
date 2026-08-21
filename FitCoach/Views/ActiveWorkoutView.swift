import SwiftUI
import SwiftData
import UIKit

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentExerciseIndex: Int
    @State private var focusedSetID: UUID?
    @State private var showingFinishConfirmation = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = 0

    init(session: WorkoutSession) {
        self.session = session
        let exercises = session.sortedExercises
        let requestedIndex = session.activeExerciseIndex
        let safeIndex = exercises.indices.contains(requestedIndex) ? requestedIndex : 0
        let initialExercise = exercises.indices.contains(safeIndex) ? exercises[safeIndex] : nil
        _currentExerciseIndex = State(initialValue: safeIndex)
        _focusedSetID = State(initialValue: initialExercise?.sortedSets.first(where: { !$0.isCompleted })?.id)
    }

    private var exercises: [ExerciseEntry] { session.sortedExercises }

    private var currentExercise: ExerciseEntry? {
        guard exercises.indices.contains(currentExerciseIndex) else { return exercises.first }
        return exercises[currentExerciseIndex]
    }

    private var nextIncompleteSet: WorkoutSet? {
        currentExercise?.sortedSets.first(where: { !$0.isCompleted })
    }

    private var currentActionSet: WorkoutSet? {
        guard let currentExercise else { return nil }
        return currentExercise.sortedSets.first(where: { $0.id == focusedSetID && !$0.isCompleted })
            ?? nextIncompleteSet
    }

    var body: some View {
        Group {
            if session.status == .completed {
                WorkoutCompletionView(session: session, onDismiss: { dismiss() })
            } else {
                NavigationStack {
                    ScrollViewReader { proxy in
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
                                        focusedSetID: focusedSetID,
                                        onFocusSet: { focus(on: $0.id) },
                                        onSetToggle: toggleSet,
                                        onValueChange: saveDraft,
                                        onValueCommit: saveDraft,
                                        onTextChange: saveDraft
                                    )
                                    .id(currentExercise.id)
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                                } else {
                                    ContentUnavailableView("没有训练动作", systemImage: "dumbbell")
                                }
                            }
                            .padding(.horizontal, AppTheme.pagePadding)
                            .padding(.top, 8)
                            .padding(.bottom, 120)
                        }
                        .task(id: currentExercise?.id) {
                            await Task.yield()
                            guard let focusedSetID else { return }
                            proxy.scrollTo(focusedSetID, anchor: .center)
                        }
                        .onChange(of: focusedSetID) { _, target in
                            guard let target else { return }
                            Task { @MainActor in
                                await Task.yield()
                                if reduceMotion {
                                    proxy.scrollTo(target, anchor: .center)
                                } else {
                                    withAnimation(.snappy(duration: 0.24)) {
                                        proxy.scrollTo(target, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                    .background(AppTheme.canvas)
                    .toolbar(.hidden, for: .navigationBar)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        TrainingNavigationHeader(
                            title: session.student?.name ?? "训练中",
                            onPause: { dismiss() },
                            onCancel: cancelSession
                        )
                    }
                    .safeAreaInset(edge: .bottom) {
                        WorkoutBottomControls(
                            currentSetNumber: currentActionSet.map { $0.sortIndex + 1 },
                            restEndsAt: session.restEndsAt,
                            canGoPrevious: currentExerciseIndex > 0,
                            isLastExercise: currentExerciseIndex >= exercises.count - 1,
                            onSkipRest: skipRest,
                            onPrevious: previousExercise,
                            onCompleteCurrentSet: completeCurrentSet,
                            onNext: nextExercise,
                            onFinish: { showingFinishConfirmation = true }
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                        .background(AppTheme.canvas)
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
        .task {
            await RestActivityService.reconcile(sessionID: session.id, restEndsAt: session.restEndsAt)
        }
        .onDisappear {
            if modelContext.hasChanges { saveDraft() }
        }
        .confirmationDialog(
            "完成本节训练？",
            isPresented: $showingFinishConfirmation,
            titleVisibility: .visible
        ) {
            Button(finishButtonTitle) { completeSession() }
            Button("继续训练", role: .cancel) { }
        } message: {
            Text(finishConfirmationMessage)
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
        if remaining <= 0 { return "仍然完成并记为欠课（\(remaining - 1) 节）" }
        return "完成并扣课（\(remaining) → \(remaining - 1) 节）"
    }

    private var finishConfirmationMessage: String {
        if session.consumesCredit, let remaining = session.student?.remainingSessions, remaining <= 0 {
            return "当前课时不足。完成后会保留真实负余额，便于后续续费核对；不会把欠课隐藏为 0。"
        }
        return "只有确认完成后才会扣除课时，计划中和暂停中的课程不会扣课。"
    }

    private func toggleSet(_ set: WorkoutSet, restSeconds: Int) {
        do {
            let service = SessionService(context: modelContext)
            if set.isCompleted {
                try service.undoSet(set, in: session)
                RestNotificationService.cancel(for: session.id)
                Task { await RestActivityService.end(for: session.id) }
                focus(on: set.id)
            } else {
                try service.completeSet(set, in: session, restSeconds: restSeconds)
                hapticTrigger += 1
                focus(on: currentExercise?.sortedSets.first(where: { !$0.isCompleted })?.id)
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "第 \(set.sortIndex + 1) 组完成，休息 \(restSeconds) 秒"
                )
                if let restEndsAt = session.restEndsAt {
                    Task {
                        await RestActivityService.upsert(for: session.id, endDate: restEndsAt)
                        let scheduled = await RestNotificationService.schedule(
                            for: session.id,
                            exerciseName: set.exercise?.name ?? "训练",
                            endDate: restEndsAt
                        )
                        if !scheduled {
                            errorMessage = "休息提醒安排失败；计时仍会在 App 内继续。"
                        }
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeCurrentSet() {
        guard let set = currentActionSet, let exercise = currentExercise else { return }
        toggleSet(set, restSeconds: exercise.plannedRestSeconds)
    }

    private func focus(on setID: UUID?) {
        if reduceMotion {
            focusedSetID = setID
        } else {
            withAnimation(.snappy(duration: 0.22)) {
                focusedSetID = setID
            }
        }
    }

    private func skipRest() {
        RestNotificationService.cancel(for: session.id)
        Task { await RestActivityService.end(for: session.id) }
        session.restEndsAt = nil
        saveDraft()
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

    private func cancelSession() {
        do {
            try SessionService(context: modelContext).cancel(session)
            RestNotificationService.cancel(for: session.id)
            Task { await RestActivityService.end(for: session.id) }
            dismiss()
        } catch {
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
            focusedSetID = exercises.indices.contains(index)
                ? exercises[index].sortedSets.first(where: { !$0.isCompleted })?.id
                : nil
        }
        saveDraft()
    }

    private func completeSession() {
        do {
            try SessionService(context: modelContext).complete(session)
            RestNotificationService.cancel(for: session.id)
            Task { await RestActivityService.end(for: session.id) }
            hapticTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TrainingNavigationHeader: View {
    let title: String
    let onPause: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
            .accessibilityLabel("稍后继续")
            .accessibilityIdentifier("workout.pause")

            Spacer(minLength: 8)

            Text(title)
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 8)

            Menu {
                Button("取消本节", systemImage: "xmark", role: .destructive, action: onCancel)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
            .accessibilityLabel("更多操作")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(AppTheme.canvas)
    }
}

private struct WorkoutProgressHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: WorkoutSession
    let currentIndex: Int
    let totalExercises: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 6) {
                            elapsedLabel(at: context.date)
                            exerciseProgressLabel
                        }
                    } else {
                        HStack {
                            elapsedLabel(at: context.date)
                            Spacer()
                            exerciseProgressLabel
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func elapsedLabel(at date: Date) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(elapsedText(at: date))
            } else {
                Label(elapsedText(at: date), systemImage: "timer")
            }
        }
            .font(.headline)
            .monospacedDigit()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("workout.elapsedTime")
    }

    private var exerciseProgressLabel: some View {
        Text("动作 \(min(currentIndex + 1, max(1, totalExercises))) / \(max(1, totalExercises))")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
    }

    private func elapsedText(at date: Date) -> String {
        let start = session.startedAt ?? session.date
        let seconds = max(0, Int(date.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ExerciseSetEditor: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @AccessibilityFocusState private var accessibilityFocusedSetID: UUID?
    let exercise: ExerciseEntry
    let focusedSetID: UUID?
    let onFocusSet: (WorkoutSet) -> Void
    let onSetToggle: (WorkoutSet, Int) -> Void
    let onValueChange: () -> Void
    let onValueCommit: () -> Void
    let onTextChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            exerciseName
                            targetRPE
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            exerciseName
                            Spacer()
                            targetRPE
                        }
                    }
                }
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text("上次最佳 · \(exercise.previousSummary)")
                    } else {
                        Label("上次最佳 · \(exercise.previousSummary)", systemImage: "clock.arrow.circlepath")
                    }
                }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("workout.previousPerformance")
            }

            VStack(spacing: 0) {
                ForEach(exercise.sortedSets) { set in
                    Group {
                        if set.id == focusedSetID && !set.isCompleted {
                            WorkoutSetRow(
                                set: set,
                                onValueChange: onValueChange,
                                onValueCommit: onValueCommit,
                                onTextChange: onTextChange
                            )
                            .accessibilityFocused($accessibilityFocusedSetID, equals: set.id)
                            .padding(.vertical, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        } else {
                            CompactWorkoutSetRow(
                                set: set,
                                onSelect: { onFocusSet(set) },
                                onUndo: { onSetToggle(set, exercise.plannedRestSeconds) }
                            )
                        }
                    }
                    .id(set.id)
                }
            }

            if exercise.sortedSets.isEmpty {
                Text("这个动作还没有组记录")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("动作备注（可选）")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                TextField("", text: Binding(
                    get: { exercise.notes },
                    set: { exercise.notes = $0; onTextChange() }
                ), axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("动作备注")
                .accessibilityHint("例如：右膝感觉良好")
            }
        }
        .onChange(of: focusedSetID) { _, target in
            guard voiceOverEnabled, let target else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                accessibilityFocusedSetID = target
            }
        }
    }

    private var exerciseName: some View {
        Text(exercise.name)
            .font(.title.bold())
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var targetRPE: some View {
        if let targetRPE = exercise.targetRPE {
            MetricPill(label: "目标", value: "RPE \(targetRPE.formatted())")
        }
    }
}

private struct CompactWorkoutSetRow: View {
    let set: WorkoutSet
    let onSelect: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(set.isCompleted ? AppTheme.success : Color.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("第 \(set.sortIndex + 1) 组")
                    .font(.subheadline.weight(.semibold))
                Text(summary)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if set.isCompleted {
                Button("撤销", action: onUndo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .minimumTapTarget()
                    .accessibilityLabel("撤销第 \(set.sortIndex + 1) 组完成")
                    .accessibilityIdentifier("workout.set.\(set.sortIndex).complete")
            } else {
                Button(action: onSelect) {
                    Label("编辑", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.primary)
                }
                .minimumTapTarget()
                .accessibilityLabel("编辑第 \(set.sortIndex + 1) 组")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !set.isCompleted { onSelect() }
        }
        .accessibilityElement(children: .contain)
    }

    private var summary: String {
        let weight = set.actualWeightKg ?? set.plannedWeightKg
        let reps = set.actualReps ?? set.plannedReps
        var parts: [String] = []
        if let weight { parts.append("\(weight.formatted()) kg") }
        if let reps { parts.append("\(reps) 次") }
        if let rpe = set.rpe { parts.append("RPE \(rpe.formatted())") }
        return parts.isEmpty ? (set.isCompleted ? "已完成" : "待记录") : parts.joined(separator: " · ")
    }
}

private struct WorkoutSetRow: View {
    @Bindable var set: WorkoutSet
    @State private var valueHapticTrigger = 0
    @State private var editingMetric: WorkoutMetric?
    let onValueChange: () -> Void
    let onValueCommit: () -> Void
    let onTextChange: () -> Void

    var body: some View {
        AppCard {
            VStack(spacing: 12) {
                setNumber
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) { valueControls }

                VStack(alignment: .leading, spacing: 4) {
                    Text("本组备注（可选）")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    TextField("", text: Binding(
                        get: { set.notes },
                        set: { set.notes = $0; onTextChange() }
                    ))
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .accessibilityLabel("第 \(set.sortIndex + 1) 组备注")
                }
            }
        }
        .opacity(set.isCompleted ? 0.78 : 1)
        .sensoryFeedback(.selection, trigger: valueHapticTrigger)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout.set.\(set.sortIndex).editor")
        .sheet(item: $editingMetric) { metric in
            NumericValueEditor(
                metric: metric,
                initialValue: directInputValue(for: metric),
                onCommit: { applyDirectInput($0, for: metric) }
            )
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(uiColor: .systemBackground))
        }
    }

    private var setNumber: some View {
        Text("第 \(set.sortIndex + 1) 组")
            .font(.headline)
    }

    @ViewBuilder private var valueControls: some View {
                    SetValueControl(
                        label: "重量",
                        value: weightText,
                        unit: "千克",
                        stepDescription: "2.5 千克",
                        decrease: { changeWeight(by: -2.5) },
                        increase: { changeWeight(by: 2.5) },
                        edit: { editingMetric = .weight }
                    )
                    SetValueControl(
                        label: "次数",
                        value: "\(set.actualReps ?? set.plannedReps ?? 0)",
                        unit: "次",
                        stepDescription: "1 次",
                        decrease: { changeReps(by: -1) },
                        increase: { changeReps(by: 1) },
                        edit: { editingMetric = .reps }
                    )
                    if let rpe = set.rpe {
                        SetValueControl(
                            label: "RPE",
                            value: rpe.formatted(),
                            unit: "",
                            stepDescription: "0.5",
                            decrease: { changeRPE(by: -0.5) },
                            increase: { changeRPE(by: 0.5) },
                            edit: { editingMetric = .rpe }
                        )
                    } else {
                        UnsetMetricControl(
                            label: "RPE",
                            edit: { editingMetric = .rpe }
                        )
                    }
    }

    private var weightText: String {
        let weight = set.actualWeightKg ?? set.plannedWeightKg ?? 0
        return "\(weight.formatted())"
    }

    private func changeWeight(by amount: Double) {
        let current = set.actualWeightKg ?? set.plannedWeightKg ?? 0
        set.actualWeightKg = min(2_000, max(0, current + amount))
        valueHapticTrigger += 1
        onValueChange()
    }

    private func changeReps(by amount: Int) {
        let current = set.actualReps ?? set.plannedReps ?? 0
        set.actualReps = min(10_000, max(0, current + amount))
        valueHapticTrigger += 1
        onValueChange()
    }

    private func changeRPE(by amount: Double) {
        if let current = set.rpe {
            set.rpe = min(10, max(1, current + amount))
        }
        valueHapticTrigger += 1
        onValueChange()
    }

    private func directInputValue(for metric: WorkoutMetric) -> Double? {
        switch metric {
        case .weight:
            return set.actualWeightKg ?? set.plannedWeightKg
        case .reps:
            return Double(set.actualReps ?? set.plannedReps ?? 0)
        case .rpe:
            return set.rpe
        }
    }

    private func applyDirectInput(_ value: Double, for metric: WorkoutMetric) {
        switch metric {
        case .weight:
            set.actualWeightKg = max(0, value)
        case .reps:
            set.actualReps = max(0, Int(value.rounded()))
        case .rpe:
            set.rpe = min(10, max(1, value))
        }
        valueHapticTrigger += 1
        onValueCommit()
    }
}

private enum WorkoutMetric: String, Identifiable {
    case weight
    case reps
    case rpe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "重量"
        case .reps: "次数"
        case .rpe: "RPE"
        }
    }

    var unit: String {
        switch self {
        case .weight: "kg"
        case .reps: "次"
        case .rpe: ""
        }
    }

    var allowsDecimal: Bool { self != .reps }

    var validRange: ClosedRange<Double> {
        switch self {
        case .weight: 0...2_000
        case .reps: 0...10_000
        case .rpe: 1...10
        }
    }

    var rangeDescription: String {
        switch self {
        case .weight: "请输入 0–2000 kg"
        case .reps: "请输入 0–10000 次"
        case .rpe: "请输入 1–10"
        }
    }

    func accepts(_ value: Double) -> Bool {
        value.isFinite && validRange.contains(value)
    }

    func normalized(_ value: Double) -> Double {
        switch self {
        case .weight: value
        case .reps: value.rounded()
        case .rpe: value
        }
    }
}

private struct NumericValueEditor: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text: String

    let metric: WorkoutMetric
    let onCommit: (Double) -> Void

    init(metric: WorkoutMetric, initialValue: Double?, onCommit: @escaping (Double) -> Void) {
        self.metric = metric
        self.onCommit = onCommit
        _text = State(initialValue: initialValue.map {
            $0.formatted(.number.grouping(.never))
        } ?? "")
    }

    private var parsedValue: Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
              metric.accepts(value) else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    TextField("0", text: $text)
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .keyboardType(metric.allowsDecimal ? .decimalPad : .numberPad)
                        .focused($isFocused)
                        .accessibilityLabel(metric.title)
                        .accessibilityIdentifier("workout.directInput.field")

                    if !metric.unit.isEmpty {
                        Text(metric.unit)
                            .font(.headline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.primary)
                        }
                        .minimumTapTarget()
                        .accessibilityLabel("清除当前数值")
                        .accessibilityIdentifier("workout.directInput.clear")
                    }
                }
                .padding(.horizontal, 24)

                if !text.isEmpty, parsedValue == nil {
                    Label(metric.rangeDescription, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("workout.directInput.error")
                }

                Button {
                    guard let parsedValue else { return }
                    onCommit(metric.normalized(parsedValue))
                    dismiss()
                } label: {
                    Text("确认")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primaryAction)
                .disabled(parsedValue == nil)
                .accessibilityIdentifier("workout.directInput.save")
            }
            .padding(20)
            .navigationTitle(metric.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .task { isFocused = true }
    }
}

private struct SetValueControl: View {
    let label: String
    let value: String
    let unit: String
    let stepDescription: String
    let decrease: () -> Void
    let increase: () -> Void
    let edit: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            ZStack {
                HStack(spacing: 0) {
                    Button(action: decrease) {
                        Image(systemName: "minus")
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .minimumTapTarget()
                    .buttonRepeatBehavior(.enabled)

                    Button(action: increase) {
                        Image(systemName: "plus")
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .minimumTapTarget()
                    .buttonRepeatBehavior(.enabled)
                }

                Button(action: edit) {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 44)
            .background(AppTheme.elevatedSurface, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("上下轻扫，每次调整 \(stepDescription)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: increase()
            case .decrement: decrease()
            @unknown default: break
            }
        }
        .accessibilityAction(named: "直接输入") { edit() }
        .accessibilityIdentifier("workout.control.\(label)")
    }

    private var accessibilityValue: String {
        return unit.isEmpty ? value : "\(value) \(unit)"
    }
}

private struct UnsetMetricControl: View {
    let label: String
    let edit: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)
            Button(action: edit) {
                Image(systemName: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.elevatedSurface, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue("未记录")
            .accessibilityHint("点按直接输入")
            .accessibilityIdentifier("workout.control.\(label)")
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WorkoutBottomControls: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let currentSetNumber: Int?
    let restEndsAt: Date?
    let canGoPrevious: Bool
    let isLastExercise: Bool
    let onSkipRest: () -> Void
    let onPrevious: () -> Void
    let onCompleteCurrentSet: () -> Void
    let onNext: () -> Void
    let onFinish: () -> Void

    var body: some View {
        Group {
            if let restEndsAt {
                CompactRestStatus(endDate: restEndsAt, onSkip: onSkipRest)
            } else {
                HStack(spacing: 10) {
                    Group {
                        if canGoPrevious {
                            Button(action: onPrevious) {
                                Image(systemName: "chevron.left")
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("上一个动作")
                        } else {
                            Color.clear
                                .frame(width: 44, height: 44)
                                .accessibilityHidden(true)
                        }
                    }

                    Button(action: primaryAction) {
                        Group {
                            if dynamicTypeSize.isAccessibilitySize {
                                Text(currentSetNumber == nil ? primaryTitle : "完成本组")
                            } else {
                                Label(primaryTitle, systemImage: primaryIcon)
                            }
                        }
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityLabel(primaryTitle)
                    .accessibilityIdentifier(primaryIdentifier)
                }
            }
        }
        .floatingTrainingChrome()
    }

    private var primaryTitle: String {
        if let currentSetNumber { return "完成第 \(currentSetNumber) 组" }
        return isLastExercise ? "完成本节" : "下一动作"
    }

    private var primaryIcon: String {
        currentSetNumber == nil ? (isLastExercise ? "checkmark" : "chevron.right") : "checkmark.circle"
    }

    private var primaryIdentifier: String {
        if currentSetNumber != nil { return "workout.completeCurrentSet" }
        return isLastExercise ? "workout.finish" : "workout.nextExercise"
    }

    private func primaryAction() {
        if currentSetNumber != nil {
            onCompleteCurrentSet()
        } else if isLastExercise {
            onFinish()
        } else {
            onNext()
        }
    }
}

private struct CompactRestStatus: View {
    let endDate: Date
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(endDate.timeIntervalSince(context.date).rounded(.up)))
            HStack(spacing: 10) {
                Label {
                    Text(remaining > 0 ? "休息 \(remaining) 秒" : "休息完成")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: remaining > 0 ? "timer" : "checkmark.circle.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(remaining > 0 ? Color.primary : AppTheme.success)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("workout.restTimer")

                Spacer(minLength: 8)

                Button(remaining > 0 ? "跳过" : "收起", action: onSkip)
                    .font(.subheadline.weight(.semibold))
                    .minimumTapTarget()
                    .accessibilityLabel(remaining > 0 ? "跳过休息" : "收起休息状态")
                    .accessibilityIdentifier("workout.skipRest")
            }
            .sensoryFeedback(.success, trigger: remaining == 0)
        }
    }
}
