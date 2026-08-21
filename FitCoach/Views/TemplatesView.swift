import SwiftUI
import SwiftData
import UIKit

struct TemplatesView: View {
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @State private var showingCreate = false
    @State private var selectedTemplate: WorkoutTemplate?

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView {
                    Label("还没有模板", systemImage: "square.stack.3d.up")
                } description: {
                    Text("从一次已完成训练创建，之后可为任意学员快速开始。")
                } actions: {
                    Button("从历史训练创建") { showingCreate = true }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.brand)
                }
            } else {
                List(templates) { template in
                    Button { selectedTemplate = template } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.brand)
                                .frame(width: 42, height: 42)
                                .background(AppTheme.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name).font(.headline).foregroundStyle(.primary)
                                Text("\(template.exercises.count) 个动作 · 点击选择学员")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.fill").foregroundStyle(AppTheme.brand)
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("模板")
        .background(AppTheme.canvas)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("创建模板", systemImage: "plus") { showingCreate = true }
                    .minimumTapTarget()
            }
        }
        .sheet(isPresented: $showingCreate) { TemplateCreationView() }
        .sheet(item: $selectedTemplate) { template in TemplateStartView(template: template) }
    }
}

private struct TemplateCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedSessionID: UUID?
    @State private var name = ""
    @State private var errorMessage: String?

    private var completedSessions: [WorkoutSession] { sessions.filter { $0.status == .completed } }

    var body: some View {
        NavigationStack {
            Form {
                Section("模板名称") {
                    TextField("例如：下肢力量 A", text: $name)
                }
                Section("选择历史训练") {
                    if completedSessions.isEmpty {
                        Text("暂无可用的已完成训练").foregroundStyle(.secondary)
                    } else {
                        ForEach(completedSessions) { session in
                            Button {
                                selectedSessionID = session.id
                                if name.isEmpty { name = session.title.isEmpty ? "训练模板" : session.title }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(session.title.isEmpty ? "训练" : session.title).foregroundStyle(.primary)
                                        Text("\(session.student?.name ?? "学员") · \(session.exercises.count) 个动作")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedSessionID == session.id { Image(systemName: "checkmark").foregroundStyle(AppTheme.brand) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("创建模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(selectedSessionID == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("保存失败", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("好", role: .cancel) {} } message: { Text(errorMessage ?? "请重试") }
        }
    }

    private func save() {
        guard let source = completedSessions.first(where: { $0.id == selectedSessionID }) else { return }
        let template = WorkoutTemplate(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(template)
        for (index, sourceExercise) in source.sortedExercises.enumerated() {
            let bestSet = sourceExercise.sortedSets.last(where: { $0.isCompleted }) ?? sourceExercise.sortedSets.first
            let exercise = TemplateExercise(
                sortIndex: index,
                name: sourceExercise.name,
                category: sourceExercise.categoryEnum,
                setsCount: max(1, sourceExercise.sets.count),
                reps: bestSet?.actualReps ?? bestSet?.plannedReps ?? sourceExercise.plannedReps,
                weightKg: bestSet?.actualWeightKg ?? bestSet?.plannedWeightKg,
                restSeconds: sourceExercise.plannedRestSeconds,
                targetRPE: sourceExercise.targetRPE,
                durationMinutes: sourceExercise.plannedDurationMinutes
            )
            exercise.template = template
            modelContext.insert(exercise)
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct TemplateStartView: View {
    let template: WorkoutTemplate
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Student> { !$0.isOwner }, sort: \Student.createdDate, order: .reverse)
    private var students: [Student]
    @State private var activeSession: WorkoutSession?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(students) { student in
                Button { start(for: student) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(student.name).font(.headline).foregroundStyle(.primary)
                            Text(student.remainingSessions.map { "剩余 \($0) 节" } ?? "不追踪课时")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.fill").foregroundStyle(AppTheme.brand)
                    }
                }
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .overlay {
                if students.isEmpty {
                    ContentUnavailableView("还没有学员", systemImage: "person.2", description: Text("请先添加一位学员。"))
                }
            }
        }
        .fullScreenCover(item: $activeSession) { session in ActiveWorkoutView(session: session) }
        .alert("无法开始", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("好", role: .cancel) {} } message: { Text(errorMessage ?? "请重试") }
    }

    private func start(for student: Student) {
        do {
            activeSession = try SessionService(context: modelContext).startFromTemplate(template, for: student)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProfileView: View {
    @AppStorage(RestNotificationService.enabledKey) private var restNotificationsEnabled = false
    @State private var notificationMessage: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section("偏好") {
                LabeledContent("语言", value: "简体中文")
                Text("MVP 首发聚焦中文教练场景，其他语言将在完整适配后开放。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("休息结束提醒", isOn: $restNotificationsEnabled)
                    .onChange(of: restNotificationsEnabled) { _, enabled in
                        Task {
                            guard enabled else {
                                await RestNotificationService.cancelAll()
                                return
                            }
                            let granted = await RestNotificationService.requestAuthorization()
                            if !granted {
                                restNotificationsEnabled = false
                                notificationMessage = "通知权限未开启，可稍后在系统设置中允许 FitCoach 通知。"
                            }
                        }
                    }
                Text("仅在你主动开启后，于组间休息结束时发送提醒。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("数据") {
                NavigationLink { SettingsView() } label: {
                    Label("备份与恢复", systemImage: "externaldrive")
                }
            }
            Section { LabeledContent("版本", value: "1.0 MVP") }
        }
        .navigationTitle("我的")
        .task {
            guard restNotificationsEnabled else { return }
            if !(await RestNotificationService.isAuthorized()) {
                restNotificationsEnabled = false
                notificationMessage = "系统通知权限已关闭。训练计时仍可使用；需要后台提醒时可前往设置开启。"
            }
        }
        .alert("无法开启提醒", isPresented: Binding(
            get: { notificationMessage != nil },
            set: { if !$0 { notificationMessage = nil } }
        )) {
            Button("前往设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
                notificationMessage = nil
            }
            Button("好", role: .cancel) { notificationMessage = nil }
        } message: {
            Text(notificationMessage ?? "请稍后重试")
        }
    }
}
