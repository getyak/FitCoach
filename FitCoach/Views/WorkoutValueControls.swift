import SwiftUI

struct NumericValueEditor: View {
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
        VStack(spacing: 0) {
            ZStack {
                Text(metric.title)
                    .font(.headline)

                HStack {
                    Button("取消") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .minimumTapTarget()
                        .accessibilityIdentifier("workout.directInput.cancel")
                    Spacer()
                }
            }
            .frame(minHeight: 52)
            .padding(.horizontal, 16)

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
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .background(
                            Color(uiColor: .label),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .opacity(parsedValue == nil ? 0.35 : 1)
                .disabled(parsedValue == nil)
                .accessibilityIdentifier("workout.directInput.save")
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemBackground))
        .task { isFocused = true }
    }
}

struct SetValueControl: View {
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

struct UnsetMetricControl: View {
    let label: String
    let edit: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)
            Button(action: edit) {
                Label("记录 \(label)", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.elevatedSurface, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("记录 \(label)")
            .accessibilityValue("未记录")
            .accessibilityHint("点按直接输入")
            .accessibilityIdentifier("workout.control.\(label)")
        }
        .frame(maxWidth: .infinity)
    }
}
