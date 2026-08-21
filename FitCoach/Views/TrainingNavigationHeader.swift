import SwiftUI

struct TrainingNavigationHeader: View {
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

struct WorkoutProgressHeader: View {
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

