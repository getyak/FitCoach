import SwiftUI
import SwiftData

struct AddStudentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var loc: LocalizationManager

    @State private var name = ""
    @State private var gender: Gender = .male
    @State private var age = 25
    @State private var fitnessLevel: FitnessLevel = .beginner
    @State private var weightKg = 60.0
    @State private var heightCm = 170.0
    @State private var bodyFatPercentage = ""
    @State private var hipCm = ""
    @State private var chestCm = ""
    @State private var waistCm = ""
    @State private var fitnessGoal = ""
    @State private var notes = ""
    @State private var safetyNotes = ""
    @State private var purchasedSessions = 10
    @State private var tracksCredits = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(loc.t("基本资料")) {
                    TextField(loc.t("姓名"), text: $name)
                    Picker(loc.t("性别"), selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { g in
                            Text(loc.t(g.rawValue)).tag(g)
                        }
                    }
                    Stepper("\(loc.t("年龄"))：\(age)\(loc.t("岁"))", value: $age, in: 6...100)
                    Picker(loc.t("运动经验"), selection: $fitnessLevel) {
                        ForEach(FitnessLevel.allCases, id: \.self) { level in
                            Text(loc.t(level.rawValue)).tag(level)
                        }
                    }
                }

                Section(loc.t("首次体测")) {
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
                }

                Section(loc.t("运动目标")) {
                    TextField(loc.t("例如：减脂、增肌、提升体能..."), text: $fitnessGoal, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("课时") {
                    Toggle("追踪剩余课时", isOn: $tracksCredits)
                    if tracksCredits {
                        Stepper("初始课时：\(purchasedSessions) 节", value: $purchasedSessions, in: 0...200)
                    }
                }

                Section("训练提醒") {
                    TextField("伤病、动作限制或需要先确认的情况", text: $safetyNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(loc.t("备注")) {
                    TextField(loc.t("其他需要记录的信息"), text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(loc.t("添加学员"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t("取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t("保存学员")) { saveStudent() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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

    private func saveStudent() {
        let student = Student(
            name: name,
            gender: gender,
            age: age,
            fitnessLevel: fitnessLevel,
            weightKg: weightKg,
            heightCm: heightCm,
            bodyFatPercentage: Double(bodyFatPercentage),
            hipCm: Double(hipCm),
            chestCm: Double(chestCm),
            waistCm: Double(waistCm),
            fitnessGoal: fitnessGoal,
            notes: notes,
            safetyNotes: safetyNotes,
            totalPurchasedSessions: tracksCredits ? purchasedSessions : nil
        )
        modelContext.insert(student)

        let measurement = BodyMeasurement(
            weightKg: weightKg,
            bodyFatPercentage: Double(bodyFatPercentage),
            hipCm: Double(hipCm),
            chestCm: Double(chestCm),
            waistCm: Double(waistCm),
            notes: "首次体测"
        )
        measurement.student = student
        modelContext.insert(measurement)

        do {
            if tracksCredits {
                try SessionService(context: modelContext)
                    .createOpeningBalance(for: student, amount: purchasedSessions)
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
    AddStudentView()
        .environmentObject(LocalizationManager.shared)
        .modelContainer(for: [Student.self, WorkoutSession.self, ExerciseEntry.self, WorkoutSet.self, BodyMeasurement.self, CreditTransaction.self, WorkoutTemplate.self, TemplateExercise.self], inMemory: true)
}
