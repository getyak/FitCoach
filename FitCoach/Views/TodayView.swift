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

    private var inProgressSession: WorkoutSession? {
        students
            .flatMap(\.workoutSessions)
            .filter { $0.status == .inProgress }
            .max { ($0.startedAt ?? $0.date) < ($1.startedAt ?? $1.date) }
    }

    private var focusStudent: Student? {
        inProgressSession?.student
            ?? students.first(where: { !$0.workoutSessions.isEmpty })
            ?? students.first
    }

    private var lastCompletedSession: WorkoutSession? {
        focusStudent?.workoutSessions
            .filter { $0.status == .completed }
            .max { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                TodayHeader()

                if let student = focusStudent {
                    FocusClientCard(
                        student: student,
                        previousSession: lastCompletedSession,
                        activeSession: inProgressSession,
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
                AddWorkoutSessionView(student: focusStudent)
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
        if let inProgressSession {
            activeSession = inProgressSession
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
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
            Text("把注意力留给学员")
                .font(.largeTitle.bold())
            Text("从上一次继续，不从空白开始。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }
}

private struct FocusClientCard: View {
    let student: Student
    let previousSession: WorkoutSession?
    let activeSession: WorkoutSession?
    let onStart: () -> Void
    let onViewTrend: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Text(String(student.name.prefix(1)))
                        .font(.title2.bold())
                        .frame(width: 52, height: 52)
                        .foregroundStyle(.white)
                        .background(AppTheme.brand, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(activeSession == nil ? "建议下一位" : "训练进行中")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(activeSession == nil ? AppTheme.brand : AppTheme.success)
                        Text(student.name)
                            .font(.title2.bold())
                    }
                    Spacer(minLength: 8)
                    if let remaining = student.remainingSessions {
                        MetricPill(label: "剩", value: "\(remaining) 节")
                            .accessibilityIdentifier("today.remainingCredits")
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

                Button(action: onStart) {
                    Label(
                        activeSession == nil ? (previousSession == nil ? "创建第一节训练" : "沿用上次并开始") : "继续本节训练",
                        systemImage: activeSession == nil ? "play.fill" : "arrow.right"
                    )
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .accessibilityIdentifier("today.startWorkout")
            }
        }
    }
}

private struct PreviousSessionSection: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("上次完成")
                    .font(.title3.bold())
                Spacer()
                Text("\(session.completedSetCount) 组")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(session.sortedExercises.prefix(3)) { exercise in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.headline)
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
