import SwiftUI
import SwiftData

struct WorkoutSessionDetailView: View {
    @Bindable var session: WorkoutSession
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddExtraExercise = false

    var body: some View {
        List {
            Section(loc.t("课程信息")) {
                LabeledContent(loc.t("日期"), value: session.date.formatted(date: .abbreviated, time: .shortened))
                HStack {
                    Text(loc.t("课程名称（可选）"))
                    Spacer()
                    TextField(loc.t("课程名称（可选）"), text: $session.title)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color.accentColor)
                }
            }

            ForEach(session.exercises) { exercise in
                Section(exercise.name) {
                    ExerciseEntryEditor(exercise: exercise, studentWeightKg: session.student?.weightKg ?? 0)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button {
                        showingAddExtraExercise = true
                    } label: {
                        Label(loc.t("添加计划外动作"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                HStack {
                    Text(loc.t("本次训练总消耗"))
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.0f kcal", session.totalCalories))
                        .font(.title3.bold())
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .navigationTitle(session.title.isEmpty ? loc.t("训练详情") : session.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddExtraExercise) {
            AddExtraExerciseView { entry in
                entry.session = session
                modelContext.insert(entry)
            }
        }
    }
}

struct ExerciseEntryEditor: View {
    @Bindable var exercise: ExerciseEntry
    let studentWeightKg: Double
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(loc.t(exercise.categoryEnum.rawValue))
                if exercise.categoryEnum == .cardio, let intensity = exercise.cardioIntensityEnum {
                    Text("· \(loc.t(intensity.rawValue))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // 表头
            HStack {
                Text("").frame(width: 68, alignment: .leading)
                Text(loc.t("计划"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(loc.t("实际"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if exercise.categoryEnum != .cardio {
                CompareRow(
                    label: loc.t("组数"),
                    planned: "\(exercise.plannedSets)",
                    actualInt: $exercise.actualSets
                )
                CompareRow(
                    label: loc.t("次数"),
                    planned: "\(exercise.plannedReps)",
                    actualInt: $exercise.actualReps
                )
                CompareRow(
                    label: loc.t("间歇(秒)"),
                    planned: "\(exercise.plannedRestSeconds)",
                    actualInt: $exercise.actualRestSeconds
                )
            }
            CompareRow(
                label: loc.t("时长(分)"),
                planned: exercise.plannedDurationMinutes.formatted(),
                actualDouble: $exercise.actualDurationMinutes
            )

            Toggle(loc.t("已完成"), isOn: $exercise.isCompleted)
                .padding(.top, 4)

            if exercise.isCompleted && exercise.actualDurationMinutes > 0 {
                HStack {
                    Text(loc.t("本动作消耗"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(String(format: "%.0f", exercise.caloriesBurned(studentWeightKg: studentWeightKg))) kcal")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 一行里左边是标签，中间是计划值（灰色，只读），右边是实际完成值（可编辑，橙色高亮）
/// 计划和实际并排显示，方便一眼对比
struct CompareRow: View {
    let label: String
    let planned: String
    var actualInt: Binding<Int>? = nil
    var actualDouble: Binding<Double>? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 68, alignment: .leading)

            Text(planned)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Group {
                if let actualInt {
                    TextField("0", text: intTextBinding(actualInt))
                        .keyboardType(.numberPad)
                } else if let actualDouble {
                    TextField("0", text: doubleTextBinding(actualDouble))
                        .keyboardType(.decimalPad)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.10))
            .foregroundStyle(Color.accentColor)
            .fontWeight(.semibold)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    /// 输入框绑定：值为 0 时显示空白，不需要先手动删掉那个 "0" 再输入
    private func intTextBinding(_ binding: Binding<Int>) -> Binding<String> {
        Binding<String>(
            get: { binding.wrappedValue == 0 ? "" : String(binding.wrappedValue) },
            set: { newValue in
                binding.wrappedValue = Int(newValue.filter(\.isNumber)) ?? 0
            }
        )
    }

    private func doubleTextBinding(_ binding: Binding<Double>) -> Binding<String> {
        Binding<String>(
            get: {
                if binding.wrappedValue == 0 { return "" }
                return binding.wrappedValue.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(binding.wrappedValue))
                    : String(binding.wrappedValue)
            },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber || $0 == "." }
                binding.wrappedValue = Double(filtered) ?? 0
            }
        )
    }
}

/// 训练过程中临时增加的、原计划里没有的动作。
/// 没有"计划"这一列，只需要填写实际完成的数据，一样会计入总卡路里消耗。
struct AddExtraExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    var onAdd: (ExerciseEntry) -> Void

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var cardioIntensity: CardioIntensity = .moderate
    @State private var actualSets = 3
    @State private var actualReps = 12
    @State private var actualRestSeconds = 60
    @State private var actualDurationMinutes = 15.0

    var body: some View {
        NavigationStack {
            Form {
                if category == .cardio {
                    HStack {
                        Text(loc.t("动作名称"))
                        Spacer()
                        Text(name)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    TextField(loc.t("动作名称，例如：杠铃深蹲"), text: $name)
                }
                Picker(loc.t("类型"), selection: $category) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { c in
                        Text(loc.t(c.rawValue)).tag(c)
                    }
                }

                if category == .cardio {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loc.t("强度"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(CardioIntensity.allCases, id: \.self) { level in
                                    IntensityPill(
                                        title: loc.t(level.rawValue),
                                        isSelected: cardioIntensity == level
                                    ) {
                                        cardioIntensity = level
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                } else {
                    Stepper("\(loc.t("组数"))：\(actualSets)", value: $actualSets, in: 1...20)
                    Stepper("\(loc.t("每组次数"))：\(actualReps)", value: $actualReps, in: 1...100)
                    Stepper("\(loc.t("组间间歇"))：\(actualRestSeconds)\(loc.t("秒"))", value: $actualRestSeconds, in: 0...600, step: 15)
                }

                HStack {
                    Text(loc.t("实际完成时间"))
                    Spacer()
                    TextField(loc.t("分钟"), value: $actualDurationMinutes, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text(loc.t("分钟"))
                }
            }
            .navigationTitle(loc.t("计划外动作"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: category) { _, newValue in
                if newValue == .cardio {
                    name = loc.t(cardioIntensity.rawValue)
                } else {
                    name = ""
                }
            }
            .onChange(of: cardioIntensity) { _, newValue in
                if category == .cardio {
                    name = loc.t(newValue.rawValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t("取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.language == .zh ? "添加" : "Add") {
                        let entry: ExerciseEntry
                        if category == .cardio {
                            entry = ExerciseEntry(
                                name: name,
                                category: category,
                                cardioIntensity: cardioIntensity,
                                plannedDurationMinutes: 0
                            )
                        } else {
                            entry = ExerciseEntry(
                                name: name,
                                category: category,
                                plannedSets: 0,
                                plannedReps: 0,
                                plannedRestSeconds: 0,
                                plannedDurationMinutes: 0
                            )
                        }
                        entry.actualSets = actualSets
                        entry.actualReps = actualReps
                        entry.actualRestSeconds = actualRestSeconds
                        entry.actualDurationMinutes = actualDurationMinutes
                        entry.isCompleted = true
                        onAdd(entry)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
