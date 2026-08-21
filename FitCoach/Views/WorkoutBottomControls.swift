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
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @AccessibilityFocusState private var timerFocused: Bool
    @State private var didFinish = false
    let completedSetNumber: Int?
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
                .accessibilityLabel(restAccessibilityLabel)
                .accessibilityValue(remaining > 0 ? "剩余 \(remaining) 秒" : "休息完成")
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
                finishIfNeeded(remaining: newValue)
            }
            .task {
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

    private func finishIfNeeded(remaining: Int) {
        guard remaining == 0, !didFinish else { return }
        didFinish = true
        onSkip()
    }
}

