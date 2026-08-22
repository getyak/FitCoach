import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var currentExerciseIndex: Int
    @State private var focusedSetID: UUID?
    @State private var showingFinishConfirmation = false
    @State private var errorMessage: String?
    @State private var setCompletionHapticTrigger = 0
    @State private var setUndoHapticTrigger = 0
    @State private var sessionCompletionHapticTrigger = 0

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
                                        isResting: session.restEndsAt != nil,
                                        onFocusSet: { focus(on: $0.id) },
                                        onSetToggle: toggleSet,
                                        onDraftChange: { _ = saveDraft() }
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
                            proxy.scrollTo(focusedSetID, anchor: setScrollAnchor)
                        }
                        .onChange(of: focusedSetID) { _, target in
                            guard let target else { return }
                            Task { @MainActor in
                                await Task.yield()
                                if reduceMotion {
                                    proxy.scrollTo(target, anchor: setScrollAnchor)
                                } else {
                                    withAnimation(.snappy(duration: 0.24)) {
                                        proxy.scrollTo(target, anchor: setScrollAnchor)
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
                            completedSetNumber: restCompletedSetNumber,
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
        .sensoryFeedback(.impact(weight: .light), trigger: setCompletionHapticTrigger)
        .sensoryFeedback(.warning, trigger: setUndoHapticTrigger)
        .sensoryFeedback(.success, trigger: sessionCompletionHapticTrigger)
        .task {
            await RestTimerCoordinator.shared.reconcile(
                sessionID: session.id,
                exerciseName: currentExercise?.name ?? "训练",
                restEndsAt: session.restEndsAt
            )
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

    private var setScrollAnchor: UnitPoint {
        dynamicTypeSize.isAccessibilitySize ? .top : .center
    }

    private var restCompletedSetNumber: Int? {
        guard session.restEndsAt != nil else { return nil }
        return currentExercise?.sortedSets
            .filter(\.isCompleted)
            .max(by: { $0.sortIndex < $1.sortIndex })
            .map { $0.sortIndex + 1 }
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
                setUndoHapticTrigger += 1
                stopSystemRestMirrors()
                focus(on: set.id)
            } else {
                try service.completeSet(set, in: session, restSeconds: restSeconds)
                setCompletionHapticTrigger += 1
                focus(on: currentExercise?.sortedSets.first(where: { !$0.isCompleted })?.id)
                if let restEndsAt = session.restEndsAt {
                    let operation = RestTimerCoordinator.shared.prepareStart(
                        sessionID: session.id,
                        exerciseName: set.exercise?.name ?? "训练",
                        endDate: restEndsAt
                    )
                    Task {
                        let scheduled = await RestTimerCoordinator.shared.performStart(operation)
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
        session.restEndsAt = nil
        guard saveDraft() else { return }
        stopSystemRestMirrors()
    }

    @discardableResult
    private func saveDraft() -> Bool {
        session.updatedAt = Date()
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func cancelSession() {
        do {
            try SessionService(context: modelContext).cancel(session)
            stopSystemRestMirrors()
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
        guard saveDraft() else {
            currentExerciseIndex = session.activeExerciseIndex
            focusedSetID = currentExercise?.sortedSets.first(where: { !$0.isCompleted })?.id
            return
        }
    }

    private func completeSession() {
        do {
            try SessionService(context: modelContext).complete(session)
            stopSystemRestMirrors()
            sessionCompletionHapticTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopSystemRestMirrors() {
        let operation = RestTimerCoordinator.shared.prepareStop(sessionID: session.id)
        Task { await RestTimerCoordinator.shared.performStop(operation) }
    }
}
