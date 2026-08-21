import SwiftUI
import Charts

struct MeasurementTrendView: View {
    let student: Student
    @Environment(\.dismiss) private var dismiss

    private var measurements: [BodyMeasurement] { student.sortedMeasurements }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if measurements.count >= 2 {
                    TrendSummaryCard(
                        title: "体重",
                        unit: "kg",
                        measurements: measurements,
                        value: { $0.weightKg }
                    )
                    TrendSummaryCard(
                        title: "腰围",
                        unit: "cm",
                        measurements: measurements,
                        value: { $0.waistCm }
                    )
                    TrendSummaryCard(
                        title: "体脂率",
                        unit: "%",
                        measurements: measurements,
                        value: { $0.bodyFatPercentage }
                    )
                } else {
                    ContentUnavailableView(
                        "趋势数据不足",
                        systemImage: "chart.xyaxis.line",
                        description: Text("至少记录两次体测后才能查看变化。")
                    )
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.canvas)
        .navigationTitle("\(student.name)的趋势")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
    }
}

private struct TrendSummaryCard: View {
    let title: String
    let unit: String
    let measurements: [BodyMeasurement]
    let value: (BodyMeasurement) -> Double?

    private var points: [(date: Date, value: Double)] {
        measurements.compactMap { measurement in
            value(measurement).map { (measurement.measuredAt, $0) }
        }
    }

    private var delta: Double? {
        guard let first = points.first?.value, let last = points.last?.value else { return nil }
        return last - first
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                        Text("最近 \(points.count) 次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let latest = points.last?.value, let delta {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(latest.formatted()) \(unit)")
                                .font(.title3.bold())
                                .monospacedDigit()
                            Text("\(delta >= 0 ? "+" : "")\(delta.formatted(.number.precision(.fractionLength(1)))) \(unit)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(delta <= 0 ? AppTheme.success : .secondary)
                        }
                    }
                }

                Chart(points, id: \.date) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value(title, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AppTheme.brand)
                    PointMark(
                        x: .value("日期", point.date),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(AppTheme.brand)
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(.clear)
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .accessibilityLabel("\(title)变化趋势")
            }
        }
    }
}
