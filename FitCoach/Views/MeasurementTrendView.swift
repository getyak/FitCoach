import SwiftUI
import Charts

struct MeasurementTrendView: View {
    let student: Student
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddMeasurement = false

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
            ToolbarItem(placement: .topBarLeading) {
                Button("记录体测", systemImage: "plus") { showingAddMeasurement = true }
                    .minimumTapTarget()
                    .accessibilityIdentifier("measurement.add")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
        .sheet(isPresented: $showingAddMeasurement) {
            AddMeasurementView(student: student)
        }
    }
}

private struct AddMeasurementView: View {
    let student: Student
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var measuredAt = Date()
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var waist = ""
    @State private var hip = ""
    @State private var chest = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("日期", selection: $measuredAt, displayedComponents: [.date, .hourAndMinute])
                Section("核心指标") {
                    measurementField("体重", unit: "kg", text: $weight)
                    measurementField("体脂率", unit: "%", text: $bodyFat)
                    measurementField("腰围", unit: "cm", text: $waist)
                }
                Section("其他围度（可选）") {
                    measurementField("臀围", unit: "cm", text: $hip)
                    measurementField("胸围", unit: "cm", text: $chest)
                }
                Section("备注") {
                    TextField("例如：晨起空腹", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("记录体测")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(allValuesEmpty)
                }
            }
            .alert("保存失败", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("好", role: .cancel) {} } message: { Text(errorMessage ?? "请重试") }
        }
    }

    private var allValuesEmpty: Bool {
        [weight, bodyFat, waist, hip, chest].allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func measurementField(_ title: String, unit: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField("—", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 70)
                    .accessibilityLabel("\(title)，单位 \(unit)")
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        let weightValue = Double(weight)
        let bodyFatValue = Double(bodyFat)
        let waistValue = Double(waist)
        let hipValue = Double(hip)
        let chestValue = Double(chest)
        guard valid(weight, value: weightValue, range: 20...400),
              valid(bodyFat, value: bodyFatValue, range: 1...75),
              valid(waist, value: waistValue, range: 30...300),
              valid(hip, value: hipValue, range: 30...300),
              valid(chest, value: chestValue, range: 30...300) else {
            errorMessage = "请检查输入：体重 20–400 kg，体脂率 1–75%，围度 30–300 cm。"
            return
        }
        let record = BodyMeasurement(
            measuredAt: measuredAt,
            weightKg: weightValue,
            bodyFatPercentage: bodyFatValue,
            hipCm: hipValue,
            chestCm: chestValue,
            waistCm: waistValue,
            notes: notes
        )
        record.student = student
        modelContext.insert(record)
        if let value = record.weightKg { student.weightKg = value }
        if let value = record.bodyFatPercentage { student.bodyFatPercentage = value }
        if let value = record.waistCm { student.waistCm = value }
        if let value = record.hipCm { student.hipCm = value }
        if let value = record.chestCm { student.chestCm = value }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func valid(_ raw: String, value: Double?, range: ClosedRange<Double>) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || value.map(range.contains) == true
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
                    if points.count >= 2, let latest = points.last?.value, let delta {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(latest.formatted()) \(unit)")
                                .font(.title3.bold())
                                .monospacedDigit()
                            Text("\(delta >= 0 ? "+" : "")\(delta.formatted(.number.precision(.fractionLength(1)))) \(unit)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if points.count >= 2 {
                    Chart(points, id: \.date) { point in
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value(title, point.value)
                        )
                        .interpolationMethod(.linear)
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
                    .accessibilityLabel("\(title)变化趋势，共 \(points.count) 个数据点")
                    .accessibilityValue(trendAccessibilityValue)
                } else {
                    Label("该指标至少需要两次有效记录", systemImage: "chart.line.downtrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var trendAccessibilityValue: String {
        guard let first = points.first, let last = points.last else { return "数据不足" }
        return "从 \(first.value.formatted()) \(unit) 变化到 \(last.value.formatted()) \(unit)"
    }
}
