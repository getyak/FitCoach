import SwiftUI
import SwiftData

struct StudentListView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @Query(
        filter: #Predicate<Student> { $0.isOwner == false },
        sort: \Student.createdDate,
        order: .reverse
    ) private var students: [Student]
    @State private var showingAddStudent = false

    var body: some View {
        Group {
            if students.isEmpty {
                ContentUnavailableView {
                    Label(loc.t("还没有学员"), systemImage: "person.2.badge.plus")
                } description: {
                    Text("添加第一位学员后，就能从上次训练直接继续。")
                } actions: {
                    Button("添加学员") { showingAddStudent = true }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.brand)
                }
            } else {
                List(students) { student in
                    NavigationLink(value: student) {
                        StudentRow(student: student)
                    }
                    .listRowBackground(AppTheme.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppTheme.canvas)
        .navigationTitle("学员")
        .navigationDestination(for: Student.self) { student in
            StudentDetailView(student: student)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddStudent = true
                } label: {
                    Label("添加学员", systemImage: "person.badge.plus")
                }
                .minimumTapTarget()
                .accessibilityIdentifier("clients.add")
            }
        }
        .sheet(isPresented: $showingAddStudent) { AddStudentView() }
    }
}

struct LanguageSwitcher: View {
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    loc.language = language
                } label: {
                    if loc.language == language {
                        Label(language.rawValue, systemImage: "checkmark")
                    } else {
                        Text(language.rawValue)
                    }
                }
            }
        } label: {
            Label(loc.language.shortLabel, systemImage: "globe")
        }
        .minimumTapTarget()
    }
}

struct StudentRow: View {
    let student: Student

    private var lastSession: WorkoutSession? {
        student.workoutSessions
            .filter { $0.status == .completed }
            .max { $0.date < $1.date }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(student.name.prefix(1)))
                .font(.headline)
                .foregroundStyle(AppTheme.brand)
                .frame(width: 42, height: 42)
                .background(AppTheme.brand.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(student.name).font(.headline)
                Text(lastSessionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let remaining = student.remainingSessions {
                MetricPill(label: "剩", value: "\(remaining) 节")
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private var lastSessionText: String {
        guard let lastSession else { return "还没有训练记录" }
        let title = lastSession.title.isEmpty ? "训练" : lastSession.title
        return "上次 · \(title) · \(lastSession.date.formatted(date: .abbreviated, time: .omitted))"
    }
}
