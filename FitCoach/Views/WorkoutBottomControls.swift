import SwiftUI

struct WorkoutBottomControls: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let currentSetNumber: Int?
    let completedSetNumber: Int?
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
                CompactRestStatus(
                    completedSetNumber: completedSetNumber,
                    endDate: restEndsAt,
                    onSkip: onSkipRest
                )
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

struct CompactRestStatus: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @AccessibilityFocusState private var timerFocused: Bool
    @State private var didFinish = false
    @State private var spokenRemaining: Int?
    let completedSetNumber: Int?
    let endDate: Date
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(endDate.timeIntervalSince(context.date).rounded(.up)))
            HStack(spacing: 10) {
                Label {
                    Text(restVisualText(remaining: remaining))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: remaining > 0 ? "timer" : "checkmark.circle.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(remaining > 0 ? Color.primary : AppTheme.success)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(restAccessibilityLabel)
                .accessibilityValue(restAccessibilityValue(remaining: remaining))
                .accessibilityFocused($timerFocused)
                .accessibilityIdentifier("workout.restTimer")

                Spacer(minLength: 8)

                Button("跳过", action: onSkip)
                    .font(.subheadline.weight(.semibold))
                    .minimumTapTarget()
                    .accessibilityLabel("跳过休息")
                    .accessibilityIdentifier("workout.skipRest")
            }
            .sensoryFeedback(.success, trigger: remaining == 0)
            .onChange(of: remaining) { _, newValue in
                updateSpokenRemaining(newValue)
                finishIfNeeded(remaining: newValue)
            }
            .task {
                updateSpokenRemaining(remaining)
                if voiceOverEnabled {
                    await Task.yield()
                    timerFocused = true
                }
                finishIfNeeded(remaining: remaining)
            }
        }
    }

    private var restAccessibilityLabel: String {
        completedSetNumber.map { "第 \($0) 组完成，休息计时" } ?? "休息计时"
    }

    private func restVisualText(remaining: Int) -> String {
        guard remaining > 0 else { return "休息完成" }
        return dynamicTypeSize.isAccessibilitySize ? "\(remaining) 秒" : "休息 \(remaining) 秒"
    }

    private func restAccessibilityValue(remaining: Int) -> String {
        guard remaining > 0 else { return "休息完成" }
        return "剩余 \(spokenRemaining ?? remaining) 秒"
    }

    private func updateSpokenRemaining(_ remaining: Int) {
        if spokenRemaining == nil || remaining == 10 || remaining == 0 {
            spokenRemaining = remaining
        }
    }

    private func finishIfNeeded(remaining: Int) {
        guard remaining == 0, !didFinish else { return }
        didFinish = true
        onSkip()
    }
}
