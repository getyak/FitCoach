import SwiftUI
import SwiftData

/// 编辑学员资料：姓名/性别/年龄 一旦创建就锁定，其余身体数据可以随时修改。
/// 体重等数据会被卡路里公式实时读取，改了立刻影响所有训练记录的消耗计算。
struct EditStudentView: View {
    @Bindable var student: Student
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager
    @Environment(\.modelContext) private var modelContext

    @State private var fitnessLevel: FitnessLevel
    @State private var weightKg: Double
    @State private var heightCm: Double
    @State private var bodyFatPercentage: String
    @State private var hipCm: String
    @State private var chestCm: String
    @State private var waistCm: String
    @State private var fitnessGoal: String
    @State private var notes: String
    @State private var totalPurchasedSessionsText: String
    @State private var errorMessage: String?

    init(student: Student) {
        self.student = student
        _fitnessLevel = State(initialValue: student.fitnessLevelEnum)
        _weightKg = State(initialValue: student.weightKg)
        _heightCm = State(initialValue: student.heightCm)
        _bodyFatPercentage = State(initialValue: student.bodyFatPercentage.map { String($0) } ?? "")
        _hipCm = State(initialValue: student.hipCm.map { String($0) } ?? "")
        _chestCm = State(initialValue: student.chestCm.map { String($0) } ?? "")
        _waistCm = State(initialValue: student.waistCm.map { String($0) } ?? "")
        _fitnessGoal = State(initialValue: student.fitnessGoal)
        _notes = State(initialValue: student.notes)
        _totalPurchasedSessionsText = State(initialValue: student.totalPurchasedSessions.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(loc.t("基本资料")) {
                    LabeledContent(loc.t("姓名"), value: student.name)
                        .foregroundStyle(.secondary)
                    LabeledContent(loc.t("性别"), value: loc.t(student.genderEnum.rawValue))
                        .foregroundStyle(.secondary)
                    LabeledContent(loc.t("年龄"), value: "\(student.age)\(loc.t("岁"))")
                        .foregroundStyle(.secondary)
                    Picker(loc.t("运动经验"), selection: $fitnessLevel) {
                        ForEach(FitnessLevel.allCases, id: \.self) { level in
                            Text(loc.t(level.rawValue)).tag(level)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("\(loc.t("体重")) (kg)")
                        Spacer()
                        TextField(loc.t("体重"), value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("\(loc.t("身高")) (cm)")
                        Spacer()
                        TextField(loc.t("身高"), value: $heightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("\(loc.t("体脂率")) % (\(loc.t("可选")))")
                        Spacer()
                        TextField(loc.t("例如 18.5"), text: $bodyFatPercentage)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("\(loc.t("臀围")) cm (\(loc.t("可选")))")
                        Spacer()
                        TextField("", text: $hipCm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("\(loc.t("胸围")) cm (\(loc.t("可选")))")
                        Spacer()
                        TextField("", text: $chestCm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("\(loc.t("腰围")) cm (\(loc.t("可选")))")
                        Spacer()
                        TextField("", text: $waistCm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } header: {
                    Text(loc.t("首次体测"))
                } footer: {
                    Text(loc.t("体重会实时用于计算训练消耗的卡路里，更新后所有训练记录会按最新体重重新计算。"))
                }

                if !student.isOwner {
                    Section {
                        HStack {
                            Text(loc.t("总课时数"))
                            Spacer()
                            TextField(loc.t("节（不追踪课时可留空）"), text: $totalPurchasedSessionsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        if let remaining = student.remainingSessions {
                            LabeledContent(loc.t("剩余课时"), value: "\(remaining) 节")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(loc.t("课时包"))
                    } footer: {
                        Text("增加总课时会写入一笔续费流水；减少则记录为人工调整，余额不会被静默重算。")
                    }
                }

                Section(loc.t("运动目标")) {
                    TextField(loc.t("例如：减脂、增肌、提升体能..."), text: $fitnessGoal, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(loc.t("备注")) {
                    TextField(loc.t("其他需要记录的信息"), text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(loc.t("编辑资料"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t("取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t("完成")) { save() }
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

    private func save() {
        student.fitnessLevel = fitnessLevel.rawValue
        student.weightKg = weightKg
        student.heightCm = heightCm
        student.bodyFatPercentage = Double(bodyFatPercentage)
        student.hipCm = Double(hipCm)
        student.chestCm = Double(chestCm)
        student.waistCm = Double(waistCm)
        student.fitnessGoal = fitnessGoal
        student.notes = notes
        do {
            if let newTotal = Int(totalPurchasedSessionsText) {
                try SessionService(context: modelContext).adjustPurchasedCredits(for: student, newTotal: newTotal)
            } else {
                try modelContext.save()
            }
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EditStudentView(student: Student(name: "测试学员", gender: .male, age: 28, fitnessLevel: .beginner, weightKg: 70, heightCm: 175))
        .environmentObject(LocalizationManager.shared)
        .modelContainer(for: [Student.self, WorkoutSession.self, ExerciseEntry.self], inMemory: true)
}
