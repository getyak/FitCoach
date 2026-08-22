import SwiftUI

struct WorkoutSetRow: View {
    @Bindable var set: WorkoutSet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var valueHapticTrigger = 0
    @State private var editingMetric: WorkoutMetric?
    @State private var showingNotes = false
    @FocusState private var notesFocused: Bool
    let isResting: Bool
    let onDraftChange: () -> Void

    var body: some View {
        AppCard {
            VStack(spacing: 12) {
                setNumber
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) { valueControls }

                if !isResting {
                    if showingNotes || !set.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本组备注（可选）")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.secondaryText)
                            TextField("", text: Binding(
                                get: { set.notes },
                                set: { set.notes = $0; onDraftChange() }
                            ))
                            .focused($notesFocused)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .accessibilityLabel("第 \(set.sortIndex + 1) 组备注")
                        }
                        .transition(.opacity)
                    } else {
                        Button {
                            showingNotes = true
                            Task { @MainActor in
                                await Task.yield()
                                notesFocused = true
                            }
                        } label: {
                            Label("添加备注", systemImage: "note.text.badge.plus")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .minimumTapTarget()
                        .accessibilityLabel("为第 \(set.sortIndex + 1) 组添加备注")
                        .accessibilityIdentifier("workout.set.\(set.sortIndex).addNote")
                    }
                }
            }
        }
        .opacity(set.isCompleted ? 0.78 : 1)
        .sensoryFeedback(.selection, trigger: valueHapticTrigger)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout.set.\(set.sortIndex).editor")
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: showingNotes)
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
            .accessibilityIdentifier("workout.currentSetTitle")
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
        onDraftChange()
    }

    private func changeReps(by amount: Int) {
        let current = set.actualReps ?? set.plannedReps ?? 0
        set.actualReps = min(10_000, max(0, current + amount))
        valueHapticTrigger += 1
        onDraftChange()
    }

    private func changeRPE(by amount: Double) {
        if let current = set.rpe {
            set.rpe = min(10, max(1, current + amount))
        }
        valueHapticTrigger += 1
        onDraftChange()
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
        onDraftChange()
    }
}

enum WorkoutMetric: String, Identifiable {
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
