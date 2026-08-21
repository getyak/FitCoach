import SwiftUI

struct ExerciseSetEditor: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @AccessibilityFocusState private var accessibilityFocusedSetID: UUID?
    let exercise: ExerciseEntry
    let focusedSetID: UUID?
    let isResting: Bool
    let onFocusSet: (WorkoutSet) -> Void
    let onSetToggle: (WorkoutSet, Int) -> Void
    let onDraftChange: () -> Void

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
                ForEach(displayedSets) { set in
                    Group {
                        if set.id == focusedSetID && !set.isCompleted {
                            WorkoutSetRow(
                                set: set,
                                onDraftChange: onDraftChange
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

            if !isResting {
                VStack(alignment: .leading, spacing: 6) {
                    Text("动作备注（可选）")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    TextField("", text: Binding(
                        get: { exercise.notes },
                        set: { exercise.notes = $0; onDraftChange() }
                    ), axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("动作备注")
                    .accessibilityHint("例如：右膝感觉良好")
                }
            }
        }
        .task(id: accessibilityFocusRequestID) {
            guard voiceOverEnabled, !isResting, let focusedSetID else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            accessibilityFocusedSetID = focusedSetID
        }
    }

    private var accessibilityFocusRequestID: String {
        "\(focusedSetID?.uuidString ?? "none"):\(isResting)"
    }

    private var displayedSets: [WorkoutSet] {
        let sets = exercise.sortedSets
        guard let focusedSetID,
              let focusedIndex = sets.firstIndex(where: { $0.id == focusedSetID }) else {
            return Array(sets.suffix(2))
        }
        let lowerBound = max(sets.startIndex, focusedIndex - 1)
        let upperBound = min(sets.endIndex, focusedIndex + 2)
        return Array(sets[lowerBound..<upperBound])
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

struct CompactWorkoutSetRow: View {
    let set: WorkoutSet
    let onSelect: () -> Void
    let onUndo: () -> Void

    var body: some View {
        Group {
            if set.isCompleted {
                completedRow
            } else {
                Button(action: onSelect) {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityLabel("第 \(set.sortIndex + 1) 组")
                .accessibilityValue("计划 \(accessibilitySummary)")
                .accessibilityHint("点按编辑本组")
                .accessibilityIdentifier("workout.set.\(set.sortIndex).select")
            }
        }
        .contentShape(Rectangle())
    }

    private var completedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)
                .accessibilityHidden(true)

            setSummary
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("第 \(set.sortIndex + 1) 组，已完成")
                .accessibilityValue(accessibilitySummary)

            Spacer(minLength: 8)

            Button("撤销", action: onUndo)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .minimumTapTarget()
                .accessibilityLabel("撤销第 \(set.sortIndex + 1) 组完成")
                .accessibilityIdentifier("workout.set.\(set.sortIndex).complete")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .foregroundStyle(.primary)
                .accessibilityHidden(true)

            setSummary
            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var setSummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("第 \(set.sortIndex + 1) 组")
                .font(.subheadline.weight(.semibold))
            Text(summary)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    private var accessibilitySummary: String {
        let weight = set.actualWeightKg ?? set.plannedWeightKg
        let reps = set.actualReps ?? set.plannedReps
        var parts: [String] = []
        if let weight { parts.append("\(weight.formatted()) 千克") }
        if let reps { parts.append("\(reps) 次") }
        if let rpe = set.rpe { parts.append("RPE \(rpe.formatted())") }
        return parts.isEmpty ? (set.isCompleted ? "已完成" : "待记录") : parts.joined(separator: "，")
    }
}
