import SwiftUI
import SwiftData

struct StudentDetailView: View {
    @Bindable var student: Student
    @State private var showingAddSession = false
    @State private var showingEditStudent = false
    @State private var isBasicInfoExpanded = true
    @State private var isSessionsExpanded = true
    @State private var showingSettings = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager

    private var sortedSessions: [WorkoutSession] {
        student.workoutSessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if !student.fitnessGoal.isEmpty {
                Section(loc.t("运动目标")) {
                    Text(student.fitnessGoal)
                }
            }

            Section {
                if isBasicInfoExpanded {
                    LabeledContent(loc.t("姓名"), value: student.name)
                    LabeledContent(loc.t("性别"), value: loc.t(student.genderEnum.rawValue))
                    LabeledContent(loc.t("年龄"), value: "\(student.age)\(loc.t("岁"))")
                    LabeledContent(loc.t("经验"), value: loc.t(student.fitnessLevelEnum.rawValue))
                    LabeledContent(loc.t("体重"), value: String(format: "%.1f kg", student.weightKg))
                    LabeledContent(loc.t("身高"), value: String(format: "%.1f cm", student.heightCm))
                    if let bodyFat = student.bodyFatPercentage {
                        LabeledContent(loc.t("体脂率"), value: String(format: "%.1f%%", bodyFat))
                    }
                    if let hip = student.hipCm {
                        LabeledContent(loc.t("臀围"), value: String(format: "%.1f cm", hip))
                    }
                    if let chest = student.chestCm {
                        LabeledContent(loc.t("胸围"), value: String(format: "%.1f cm", chest))
                    }
                    if let waist = student.waistCm {
                        LabeledContent(loc.t("腰围"), value: String(format: "%.1f cm", waist))
                    }
                    if let total = student.totalPurchasedSessions {
                        LabeledContent(loc.t("剩余课时"), value: "\(student.remainingSessions ?? 0) / \(total)")
                    }
                }
            } header: {
                HStack {
                    Button {
                        withAnimation { isBasicInfoExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(loc.t("基本资料"))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .rotationEffect(.degrees(isBasicInfoExpanded ? 90 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        showingEditStudent = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
                }
            }

            if !student.notes.isEmpty {
                Section(loc.t("备注")) {
                    Text(student.notes)
                }
            }

            Section {
                if isSessionsExpanded {
                    if sortedSessions.isEmpty {
                        Text(loc.t("还没有训练记录")).foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedSessions) { session in
                            NavigationLink(value: session) {
                                WorkoutSessionRow(session: session)
                            }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                }
            } header: {
                HStack {
                    Button {
                        withAnimation { isSessionsExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(loc.t("训练记录"))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .rotationEffect(.degrees(isSessionsExpanded ? 90 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        showingAddSession = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(student.name)
        .navigationDestination(for: WorkoutSession.self) { session in
            WorkoutSessionDetailView(session: session)
        }
        .toolbar {
            if student.isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSession) {
            AddWorkoutSessionView(student: student)
        }
        .sheet(isPresented: $showingEditStudent) {
            EditStudentView(student: student)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedSessions[index])
        }
    }
}

struct WorkoutSessionRow: View {
    @EnvironmentObject private var loc: LocalizationManager
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title.isEmpty ? loc.t("训练详情") : session.title)
                    .font(.headline)
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if session.isFullyCompleted {
                VStack(alignment: .trailing) {
                    Text(String(format: "%.0f kcal", session.totalCalories))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                    Text(loc.t("已完成"))
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            } else {
                Text(loc.t("进行中"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
