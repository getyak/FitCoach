import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var requestedWorkoutID: UUID?
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

    private var inProgressSessionIDs: [UUID] {
        students
            .flatMap(\.workoutSessions)
            .filter { $0.status == .inProgress }
            .map(\.id)
            .sorted { $0.uuidString < $1.uuidString }
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
            LazyVStack(alignment: .leading, spacing: 28) {
                TodayHeader()

                if let student = focusStudent {
                    FocusClientCard(
                        student: student,
                        previousSession: lastCompletedSession,
                        activeSession: focusedDraft,
                        students: students,
                        onSelectStudent: { selectedStudentID = $0 },
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
        .background(AppTheme.paper)
        .navigationTitle("")
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
            if ProcessInfo.processInfo.arguments.contains("-uiTestAX5") {
                ActiveWorkoutView(session: session)
                    .dynamicTypeSize(.accessibility5)
            } else {
                ActiveWorkoutView(session: session)
            }
        }
        .task(id: requestedWorkoutID) {
            openRequestedWorkoutIfAvailable()
        }
        .onChange(of: inProgressSessionIDs) {
            openRequestedWorkoutIfAvailable()
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

    private func openRequestedWorkoutIfAvailable() {
        guard let requestedWorkoutID,
              let session = students
                .flatMap(\.workoutSessions)
                .first(where: { $0.id == requestedWorkoutID && $0.status == .inProgress })
        else { return }
        selectedStudentID = session.student?.id
        activeSession = session
        self.requestedWorkoutID = nil
    }
}

private struct TodayHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let headerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))

        headerLayout {
            Text("今天")
                .font(.largeTitle.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(
                    maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                    alignment: .leading
                )
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
    let students: [Student]
    let onSelectStudent: (UUID) -> Void
    let onStart: () -> Void
    let onViewTrend: () -> Void
    @State private var showsSafetyNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppTheme.brand)
                .frame(width: 34, height: 3)
                .accessibilityHidden(true)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 18) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        clientIdentity
                        primaryAction
                        if let remaining = student.remainingSessions {
                            remainingCredits(remaining)
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        clientIdentity
                        Spacer(minLength: 8)
                        if let remaining = student.remainingSessions {
                            remainingCredits(remaining)
                        }
                    }
                }

                if let previousSession {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("上次训练  ·  \(previousSession.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryText)
                        Text(previousSession.title.isEmpty ? "训练记录" : previousSession.title)
                            .font(.title3.weight(.semibold))
                        Text(previousSession.sortedExercises.prefix(3).map(\.name).joined(separator: " / "))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                }

                if !student.safetyNotes.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                            showsSafetyNote.toggle()
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "cross.case")
                                .foregroundStyle(AppTheme.warning)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("训练前确认")
                                    .font(.subheadline.weight(.semibold))
                                if showsSafetyNote {
                                    Text(student.safetyNotes)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: showsSafetyNote ? "minus" : "plus")
                                .font(.caption.weight(.semibold))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .minimumTapTarget()
                    .accessibilityLabel(showsSafetyNote ? "收起训练提醒" : "展开训练提醒")
                    .accessibilityValue(showsSafetyNote ? student.safetyNotes : "有一条提醒")
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    primaryAction
                }
            }
            .padding(.vertical, 18)
        }
        .padding(.horizontal, 4)
    }

    private var clientIdentity: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusCaption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    studentMenu
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusCaption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                    studentMenu
                }
            }
        }
    }

    private func remainingCredits(_ remaining: Int) -> some View {
        HStack(spacing: 5) {
            Text("剩余")
            Text("\(remaining) 节")
                .monospacedDigit()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(AppTheme.secondaryText)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.remainingCredits")
    }

    @ViewBuilder
    private var studentMenu: some View {
        if students.count > 1 {
            Menu {
                ForEach(students) { candidate in
                    Button {
                        onSelectStudent(candidate.id)
                    } label: {
                        if candidate.id == student.id {
                            Label(candidate.name, systemImage: "checkmark")
                        } else {
                            Text(candidate.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    studentName
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("当前学员 \(student.name)，切换学员")
        } else {
            studentName
                .accessibilityLabel("当前学员 \(student.name)")
        }
    }

    private var studentName: some View {
        Text(student.name)
            .font(dynamicTypeSize.isAccessibilitySize ? .headline : .title2.weight(.semibold))
            .accessibilityIdentifier("today.focusName")
    }

    private var primaryAction: some View {
        Button(action: onStart) {
            HStack {
                Text(primaryActionTitle)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(AppTheme.paper.opacity(0.32), lineWidth: 1))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(EditorialPrimaryButtonStyle())
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
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text("上次训练")
                        .font(.headline)
                    Text("\(session.completedSetCount) 组")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Image(systemName: isExpanded ? "minus" : "plus")
                        .font(.caption.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .minimumTapTarget()
            .accessibilityLabel(isExpanded ? "收起上次训练详情" : "展开上次训练详情")

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(session.sortedExercises.prefix(3)) { exercise in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name).font(.headline)
                                Text(exercise.previousSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
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
                .padding(.bottom, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 4)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.hairline).frame(height: 0.75) }
        .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.hairline).frame(height: 0.75) }
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
                    .foregroundStyle(AppTheme.secondaryText)
                Button("添加学员", action: addClient)
                    .buttonStyle(PrimaryActionButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }
}
