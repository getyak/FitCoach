import ActivityKit
import SwiftUI
import WidgetKit

struct RestActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("组间休息")
                        .font(.headline)
                    countdown(until: context.state.endsAt)
                        .font(.title2.weight(.semibold))
                }

                Spacer(minLength: 8)
                Text("FitCoach")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .widgetURL(workoutURL(for: context.attributes.sessionID))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("组间休息倒计时")
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("组间休息", systemImage: "timer")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(until: context.state.endsAt)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("返回 FitCoach 继续下一组")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                countdown(until: context.state.endsAt)
                    .font(.caption.monospacedDigit())
                    .frame(maxWidth: 54)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
            .widgetURL(workoutURL(for: context.attributes.sessionID))
        }
    }

    private func workoutURL(for sessionID: String) -> URL {
        URL(string: "fitcoach://workout/\(sessionID)")!
    }

    private func countdown(until endDate: Date) -> some View {
        let now = Date()
        return Text(timerInterval: now...max(endDate, now), countsDown: true)
            .monospacedDigit()
            .lineLimit(1)
    }
}
