import SwiftUI
import SwiftData

struct AddWorkoutSessionView: View {
    @Bindable var student: Student
    var startImmediately = false
    var onSaved: (WorkoutSession) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager

    @State private var title = ""
    @State private var date = Date()
    @State private var plannedExercises: [PlannedExerciseDraft] = []
    @State private var showingAddExercise = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(loc.t("课程信息")) {
                    TextField(loc.t("课程名称（可选）"), text: $title)
                    DatePicker(loc.t("日期"), selection: $date)
                }

                Section(loc.t("训练计划")) {
                    if plannedExercises.isEmpty {
                        Text(loc.t("还没有添加动作")).foregroundStyle(.secondary)
                    } else {
                        ForEach(plannedExercises) { draft in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.name).font(.headline)
                                Text(draftSummary(draft))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { plannedExercises.remove(atOffsets: $0) }
                    }

                    Button {
                        showingAddExercise = true
                    } label: {
                        Label(loc.t("添加动作"), systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(loc.t(startImmediately ? "开始首次训练" : "新增训练计划"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t("取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(startImmediately ? "开始训练" : "保存计划")) { saveSession() }
                        .disabled(plannedExercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseDraftView { draft in
                    plannedExercises.append(draft)
                }
            }
            .alert("保存失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "请稍后重试")
            }
        }
    }

    private func saveSession() {
        let session = WorkoutSession(
            date: date,
            title: title,
            status: startImmediately ? .inProgress : .planned,
            consumesCredit: student.tracksCredits
        )
        if startImmediately { session.startedAt = Date() }
        session.student = student
        modelContext.insert(session)

        for (exerciseIndex, draft) in plannedExercises.enumerated() {
            let entry = ExerciseEntry(
                name: draft.name,
                category: draft.category,
                cardioIntensity: draft.cardioIntensity,
                sortIndex: exerciseIndex,
                plannedSets: draft.plannedSets,
                plannedReps: draft.plannedReps,
                plannedRestSeconds: draft.plannedRestSeconds,
                plannedDurationMinutes: draft.plannedDurationMinutes
            )
            entry.session = session
            modelContext.insert(entry)

            if draft.category != .cardio {
                for setIndex in 0..<draft.plannedSets {
                    let set = WorkoutSet(
                        sortIndex: setIndex,
                        plannedReps: draft.plannedReps,
                        actualReps: draft.plannedReps
                    )
                    set.exercise = entry
                    modelContext.insert(set)
                }
            }
        }
        do {
            try modelContext.save()
            onSaved(session)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func draftSummary(_ draft: PlannedExerciseDraft) -> String {
        if draft.category == .cardio {
            let intensity = draft.cardioIntensity.map { loc.t($0.rawValue) } ?? ""
            return "\(loc.t(draft.category.rawValue)) · \(intensity) · \(draft.plannedDurationMinutes.formatted())\(loc.t("分钟"))"
        } else {
            return "\(loc.t(draft.category.rawValue)) · \(loc.t("组数")) \(draft.plannedSets) × \(loc.t("每组次数")) \(draft.plannedReps) · \(loc.t("组间间歇")) \(draft.plannedRestSeconds)\(loc.t("秒")) · \(draft.plannedDurationMinutes.formatted())\(loc.t("分钟"))"
        }
    }
}

struct PlannedExerciseDraft: Identifiable {
    let id = UUID()
    var name: String
    var category: ExerciseCategory
    var cardioIntensity: CardioIntensity? = nil
    var plannedSets: Int = 0
    var plannedReps: Int = 0
    var plannedRestSeconds: Int = 0
    var plannedDurationMinutes: Double
}

struct AddExerciseDraftView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    var onAdd: (PlannedExerciseDraft) -> Void

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var cardioIntensity: CardioIntensity = .moderate
    @State private var sets = 3
    @State private var reps = 12
    @State private var restSeconds = 60
    @State private var durationMinutes = 15.0

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
                    Stepper("\(loc.t("组数"))：\(sets)", value: $sets, in: 1...20)
                    Stepper("\(loc.t("每组次数"))：\(reps)", value: $reps, in: 1...100)
                    Stepper("\(loc.t("组间间歇"))：\(restSeconds)\(loc.t("秒"))", value: $restSeconds, in: 0...600, step: 15)
                }

                HStack {
                    Text(loc.t("计划完成时间"))
                    Spacer()
                    TextField(loc.t("分钟"), value: $durationMinutes, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text(loc.t("分钟"))
                }
            }
            .navigationTitle(loc.t("添加动作"))
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
                        if category == .cardio {
                            onAdd(PlannedExerciseDraft(
                                name: name,
                                category: category,
                                cardioIntensity: cardioIntensity,
                                plannedDurationMinutes: durationMinutes
                            ))
                        } else {
                            onAdd(PlannedExerciseDraft(
                                name: name,
                                category: category,
                                plannedSets: sets,
                                plannedReps: reps,
                                plannedRestSeconds: restSeconds,
                                plannedDurationMinutes: durationMinutes
                            ))
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// 强度选择的小胶囊按钮，三个并排显示
struct IntensityPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.10))
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
