import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Student> { $0.isOwner == false },
        sort: \Student.createdDate,
        order: .reverse
    ) private var students: [Student]

    @State private var activeSession: WorkoutSession?
    @State private var showingAddStudent = false
    @State private var showingNewSession = false
    @State private var errorMessage: String?
    @State private var selectedStudentID: UUID?

    private var inProgressSession: WorkoutSession? {
        students
            .flatMap(\.workoutSessions)
            .filter { $0.status == .inProgress }
            .max { ($0.startedAt ?? $0.date) < ($1.startedAt ?? $1.date) }
    }

    private var focusStudent: Student? {
        students.first(where: { $0.id == selectedStudentID })
            ?? inProgressSession?.student
            ?? students.first(where: { !$0.workoutSessions.isEmpty })
            ?? students.first
    }

    private var lastCompletedSession: WorkoutSession? {
        focusStudent?.workoutSessions
            .filter { $0.status == .completed }
            .max { $0.date < $1.date }
    }

    private var focusedDraft: WorkoutSession? {
        guard let focusStudent else { return nil }
        return focusStudent.workoutSessions
            .filter { $0.status == .inProgress || $0.status == .planned }
            .max { ($0.startedAt ?? $0.date) < ($1.startedAt ?? $1.date) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                TodayHeader()

                if let student = focusStudent {
                    if students.count > 1 {
                        Menu {
                            ForEach(students) { candidate in
                                Button {
                                    selectedStudentID = candidate.id
                                } label: {
                                    if candidate.id == student.id {
                                        Label(candidate.name, systemImage: "checkmark")
                                    } else {
                                        Text(candidate.name)
                                    }
                                }
                            }
                        } label: {
                            Label("切换学员", systemImage: "person.2")
                        }
                        .minimumTapTarget()
                    }
                    FocusClientCard(
                        student: student,
                        previousSession: lastCompletedSession,
                        activeSession: focusedDraft,
                        onStart: { startTraining(for: student) },
                        onViewTrend: { }
                    )

                    if let previous = lastCompletedSession {
                        PreviousSessionSection(session: previous)
                    }
                } else {
                    EmptyTodayState {
                        showingAddStudent = true
                    }
                }
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 32)
        }
        .background(AppTheme.canvas)
        .navigationTitle("今天")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddStudent = true
                } label: {
                    Label("添加学员", systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("today.addClient")
            }
        }
        .sheet(isPresented: $showingAddStudent) {
            AddStudentView()
        }
        .sheet(isPresented: $showingNewSession) {
            if let focusStudent {
                AddWorkoutSessionView(student: focusStudent, startImmediately: true) { session in
                    activeSession = session
                }
            }
        }
        .fullScreenCover(item: $activeSession) { session in
            ActiveWorkoutView(session: session)
        }
        .alert("暂时无法开始", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
    }

    private func startTraining(for student: Student) {
        if let draft = student.workoutSessions
            .filter({ $0.status == .inProgress || $0.status == .planned })
            .max(by: { ($0.startedAt ?? $0.date) < ($1.startedAt ?? $1.date) }) {
            do {
                if draft.status == .planned {
                    try SessionService(context: modelContext).start(draft)
                }
                activeSession = draft
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }
        guard let lastCompletedSession else {
            showingNewSession = true
            return
        }
        do {
            activeSession = try SessionService(context: modelContext)
                .startByCopying(source: lastCompletedSession, for: student)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TodayHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if !dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }
}

private struct FocusClientCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let student: Student
    let previousSession: WorkoutSession?
    let activeSession: WorkoutSession?
    let onStart: () -> Void
    let onViewTrend: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        clientIdentity
                        primaryAction
                        if let remaining = student.remainingSessions {
                            MetricPill(label: "剩余课时", value: "\(remaining) 节")
                                .accessibilityIdentifier("today.remainingCredits")
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        clientIdentity
                        Spacer(minLength: 8)
                        if let remaining = student.remainingSessions {
                            MetricPill(label: "剩", value: "\(remaining) 节")
                                .accessibilityIdentifier("today.remainingCredits")
                        }
                    }
                }

                if let previousSession {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("上次 · \(previousSession.date.formatted(date: .abbreviated, time: .omitted))", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline.weight(.semibold))
                        Text(previousSession.title.isEmpty ? "训练记录" : previousSession.title)
                            .font(.headline)
                        Text(previousSession.sortedExercises.prefix(3).map(\.name).joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                if !student.safetyNotes.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "cross.case.fill")
                            .foregroundStyle(AppTheme.warning)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("训练提醒")
                                .font(.subheadline.weight(.semibold))
                            Text(student.safetyNotes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityElement(children: .combine)
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    primaryAction
                }
            }
        }
    }

    private var clientIdentity: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusCaption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(activeSession?.status == .inProgress ? AppTheme.success : AppTheme.brand)
                    Text(student.name)
                        .font(.headline)
                        .accessibilityIdentifier("today.focusName")
                }
            } else {
                HStack(spacing: 12) {
                    Text(String(student.name.prefix(1)))
                        .font(.title2.bold())
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.white)
                        .background(AppTheme.brand, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusCaption)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(activeSession?.status == .inProgress ? AppTheme.success : AppTheme.brand)
                        Text(student.name)
                            .font(.title2.bold())
                            .accessibilityIdentifier("today.focusName")
                    }
                }
            }
        }
    }

    private var primaryAction: some View {
        Button(action: onStart) {
            Label(
                primaryActionTitle,
                systemImage: activeSession == nil ? "play.fill" : "arrow.right"
            )
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .accessibilityIdentifier("today.startWorkout")
    }

    private var statusCaption: String {
        switch activeSession?.status {
        case .planned: "计划已保存"
        case .inProgress: "训练进行中"
        default: "快速继续"
        }
    }

    private var primaryActionTitle: String {
        switch activeSession?.status {
        case .planned: "开始已保存计划"
        case .inProgress: "继续本节训练"
        default: previousSession == nil ? "创建第一节训练" : "沿用上次并开始"
        }
    }
}

private struct PreviousSessionSection: View {
    let session: WorkoutSession
    @State private var isExpanded = false

    var body: some View {
        AppCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(session.sortedExercises.prefix(3)) { exercise in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name).font(.headline)
                                Text(exercise.previousSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                                .accessibilityLabel("已完成")
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack {
                    Label("上次训练详情", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    Spacer()
                    Text("\(session.completedSetCount) 组")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.brand)
        }
    }
}

private struct EmptyTodayState: View {
    let addClient: () -> Void

    var body: some View {
        AppCard {
            VStack(spacing: 16) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(AppTheme.brand)
                    .accessibilityHidden(true)
                Text("先添加第一位学员")
                    .font(.title2.bold())
                Text("之后每次打开，都能直接从学员上一次训练继续。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("添加学员", action: addClient)
                    .buttonStyle(PrimaryActionButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }
}
