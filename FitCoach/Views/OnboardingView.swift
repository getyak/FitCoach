import SwiftUI
import SwiftData

/// 首次打开App时显示：先填一遍自己（App使用者本人）的个人信息，
/// 填完保存后 RootView 会自动切换到"我的学员"主页面，以后不会再出现这个页面。
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(loc.t("欢迎使用"))
                            .font(.title2.bold())
                        Text(loc.t("先完善你自己的个人信息，之后就能记录你自己的训练日记了"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

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

                Section {
                    Button {
                        saveOwner()
                    } label: {
                        Text(loc.t("开始使用"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .listRowBackground(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.accentColor.opacity(0.3) : Color.accentColor)
                .foregroundStyle(.white)
            }
            .navigationTitle(loc.t("完善个人信息"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func saveOwner() {
        let owner = Student(
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
            isOwner: true
        )
        modelContext.insert(owner)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(LocalizationManager.shared)
        .modelContainer(for: [Student.self, WorkoutSession.self, ExerciseEntry.self], inMemory: true)
}
