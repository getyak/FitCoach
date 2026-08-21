import SwiftUI
import SwiftData

struct StudentDetailView: View {
    @Bindable var student: Student
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSession = false
    @State private var startNewSessionImmediately = false
    @State private var showingEditStudent = false
    @State private var showingTrend = false
    @State private var activeSession: WorkoutSession?
    @State private var errorMessage: String?

    private var sortedSessions: [WorkoutSession] {
        student.workoutSessions.sorted { $0.date > $1.date }
    }
    private var activeDraft: WorkoutSession? {
        sortedSessions.first { $0.status == .inProgress }
            ?? sortedSessions.first { $0.status == .planned }
    }
    private var lastCompleted: WorkoutSession? { sortedSessions.first { $0.status == .completed } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                statusCard
                if !student.safetyNotes.isEmpty { safetyCard }
                measurementCard
                historySection
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 32)
        }
        .background(AppTheme.canvas)
        .navigationTitle(student.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: WorkoutSession.self) { session in
            SessionHistoryDetailView(session: session)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑", systemImage: "square.and.pencil") { showingEditStudent = true }
                    .minimumTapTarget()
            }
        }
        .sheet(isPresented: $showingAddSession) {
            AddWorkoutSessionView(student: student, startImmediately: startNewSessionImmediately) { session in
                if startNewSessionImmediately { activeSession = session }
            }
        }
        .sheet(isPresented: $showingEditStudent) { EditStudentView(student: student) }
        .sheet(isPresented: $showingTrend) {
            NavigationStack { MeasurementTrendView(student: student) }
        }
        .fullScreenCover(item: $activeSession) { session in ActiveWorkoutView(session: session) }
        .alert("暂时无法开始", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
    }

    private var statusCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(student.fitnessGoal.isEmpty ? "训练档案" : student.fitnessGoal)
                            .font(.title2.bold())
                        Text(lastCompleted.map { "上次训练 · \($0.date.formatted(date: .abbreviated, time: .omitted))" } ?? "还没有训练记录")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let remaining = student.remainingSessions {
                        MetricPill(label: "剩余", value: "\(remaining) 节")
                    }
                }
                Button(action: beginWorkout) {
                    Label(primaryActionTitle, systemImage: activeDraft == nil ? "play.fill" : "arrow.right")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .accessibilityIdentifier("client.startWorkout")
                Button("新建不同训练计划", systemImage: "plus") {
                    startNewSessionImmediately = false
                    showingAddSession = true
                }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cross.case.fill")
                .foregroundStyle(AppTheme.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("训练提醒").font(.headline)
                Text(student.safetyNotes).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var measurementCard: some View {
        Button { showingTrend = true } label: {
            AppCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("体测趋势").font(.headline).foregroundStyle(.primary)
                        Text(measurementSummary).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(AppTheme.brand)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("client.measurementTrend")
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("训练记录").font(.title3.bold())
                Spacer()
                Text("\(sortedSessions.count) 节").foregroundStyle(.secondary)
            }
            if sortedSessions.isEmpty {
                Text("完成第一节训练后，记录会出现在这里。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(sortedSessions.prefix(12)) { session in
                    NavigationLink(value: session) { WorkoutSessionRow(session: session) }
                        .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private var primaryActionTitle: String {
        if activeDraft?.status == .inProgress { return "继续本节训练" }
        if activeDraft?.status == .planned { return "开始已保存计划" }
        if lastCompleted != nil { return "沿用上次并开始" }
        return "创建第一节训练"
    }

    private var measurementSummary: String {
        guard let latest = student.latestMeasurement else { return "还没有历史记录" }
        var values: [String] = []
        if let weight = latest.weightKg { values.append("\(weight.formatted()) kg") }
        if let bodyFat = latest.bodyFatPercentage { values.append("体脂 \(bodyFat.formatted())%") }
        if let waist = latest.waistCm { values.append("腰围 \(waist.formatted()) cm") }
        return values.isEmpty ? "还没有历史记录" : values.joined(separator: " · ")
    }

    private func beginWorkout() {
        if let activeDraft {
            do {
                if activeDraft.status == .planned {
                    try SessionService(context: modelContext).start(activeDraft)
                }
                activeSession = activeDraft
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }
        guard let lastCompleted else {
            startNewSessionImmediately = true
            showingAddSession = true
            return
        }
        do {
            activeSession = try SessionService(context: modelContext)
                .startByCopying(source: lastCompleted, for: student)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct WorkoutSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title.isEmpty ? "训练" : session.title).font(.headline)
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(statusText).font(.caption.weight(.semibold)).foregroundStyle(statusColor)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        switch session.status {
        case .planned: "计划中"
        case .inProgress: "进行中"
        case .completed: "已完成"
        case .cancelled: "已取消"
        }
    }
    private var statusIcon: String {
        switch session.status {
        case .planned: "calendar"
        case .inProgress: "play.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .cancelled: "xmark.circle"
        }
    }
    private var statusColor: Color {
        switch session.status {
        case .planned: .secondary
        case .inProgress: AppTheme.brand
        case .completed: AppTheme.success
        case .cancelled: .secondary
        }
    }
}
