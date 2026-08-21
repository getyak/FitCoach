import SwiftUI
import SwiftData

struct StudentListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    @Query(
        filter: #Predicate<Student> { $0.isOwner == false },
        sort: \Student.createdDate,
        order: .reverse
    ) private var students: [Student]
    @Query(filter: #Predicate<Student> { $0.isOwner == true }) private var ownerStudents: [Student]
    @State private var showingAddStudent = false

    private var owner: Student? { ownerStudents.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 标题跟顶部工具栏留一点距离
                Spacer().frame(height: 16)

                HStack(spacing: 6) {
                    Text(loc.t("我的学员"))
                        .font(.title.bold())
                    Button {
                        showingAddStudent = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Group {
                    if students.isEmpty {
                        ContentUnavailableView(
                            loc.t("还没有学员"),
                            systemImage: "person.crop.circle.badge.plus",
                            description: Text(loc.t("点击右上角 + 添加你的第一位学员"))
                        )
                    } else {
                        List {
                            ForEach(students) { student in
                                NavigationLink(value: student) {
                                    StudentRow(student: student)
                                }
                            }
                            .onDelete(perform: deleteStudents)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Student.self) { student in
                StudentDetailView(student: student)
            }
            .toolbar {
                if let owner {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(value: owner) {
                            OwnerChip(name: owner.name)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageSwitcher()
                }
            }
            .sheet(isPresented: $showingAddStudent) {
                AddStudentView()
            }
        }
    }

    private func deleteStudents(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(students[index])
        }
    }
}

/// 右上角最左边的"我自己"入口：显示App使用者本人的名字，点进去是他自己的详情页
/// （跟学员详情页完全一样的功能：基本资料 + 训练记录）
struct OwnerChip: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor)
            .foregroundStyle(Color.white)
            .clipShape(Capsule())
    }
}

/// 右上角的小语言切换框：中文 / English
struct LanguageSwitcher: View {
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    loc.language = lang
                } label: {
                    if loc.language == lang {
                        Label(lang.rawValue, systemImage: "checkmark")
                    } else {
                        Text(lang.rawValue)
                    }
                }
            }
        } label: {
            Text(loc.language.shortLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.14))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
        }
    }
}

struct StudentRow: View {
    @EnvironmentObject private var loc: LocalizationManager
    let student: Student

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(student.name).font(.headline)
                Text("\(loc.t(student.genderEnum.rawValue)) · \(student.age)\(loc.t("岁")) · \(loc.t(student.fitnessLevelEnum.rawValue))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let remaining = student.remainingSessions {
                Text(remainingBadgeText(remaining))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(remaining == 0 ? Color.red.opacity(0.12) : Color.accentColor.opacity(0.12))
                    .foregroundStyle(remaining == 0 ? .red : Color.accentColor)
                    .clipShape(Capsule())
            } else {
                Text("\(student.workoutSessions.count) \(loc.t("次训练"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func remainingBadgeText(_ remaining: Int) -> String {
        switch loc.language {
        case .zh: return "剩\(remaining)节"
        case .en: return "\(remaining) left"
        case .es: return "\(remaining) restantes"
        }
    }
}

#Preview {
    StudentListView()
        .environmentObject(LocalizationManager.shared)
        .modelContainer(for: [Student.self, WorkoutSession.self, ExerciseEntry.self], inMemory: true)
}
