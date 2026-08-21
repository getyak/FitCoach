import Foundation
import SwiftData

enum WorkoutSessionStatus: String, Codable, CaseIterable, Hashable {
    case planned
    case inProgress
    case completed
    case cancelled
}

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var date: Date
    var title: String
    /// 先保持可选以兼容旧数据库；nil 时由旧动作完成状态推断。
    var statusCode: String?
    var startedAt: Date?
    var completedAt: Date?
    var summary: String = ""
    var consumesCredit: Bool = true
    var completionEpoch: Int = 0
    var activeExerciseIndex: Int = 0
    /// 使用绝对时间，进入后台后仍能恢复准确倒计时。
    var restEndsAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.session)
    var exercises: [ExerciseEntry] = []

    var student: Student?

    @Relationship(deleteRule: .nullify, inverse: \CreditTransaction.session)
    var creditTransactions: [CreditTransaction] = []

    init(
        date: Date = Date(),
        title: String = "",
        status: WorkoutSessionStatus = .planned,
        consumesCredit: Bool = true
    ) {
        self.date = date
        self.title = title
        self.statusCode = status.rawValue
        self.consumesCredit = consumesCredit
    }


    var status: WorkoutSessionStatus {
        get {
            if let statusCode, let value = WorkoutSessionStatus(rawValue: statusCode) {
                return value
            }
            return exercises.contains(where: { $0.isCompleted }) ? .completed : .planned
        }
        set { statusCode = newValue.rawValue }
    }

    var sortedExercises: [ExerciseEntry] {
        exercises.sorted { lhs, rhs in
            if lhs.sortIndex == rhs.sortIndex { return lhs.name < rhs.name }
            return lhs.sortIndex < rhs.sortIndex
        }
    }

    /// 本次训练课程的总消耗卡路里（基于每个动作的实际完成数据）
    var totalCalories: Double {
        guard let weight = student?.weightKg else { return 0 }
        return exercises.reduce(0) { $0 + $1.caloriesBurned(studentWeightKg: weight) }
    }

    /// 只要有一个动作被标记"已完成"，这次训练就算已完成——
    /// 计划里的动作不一定会全部做完，不能要求全部打勾才算完成。
    var isFullyCompleted: Bool {
        status == .completed
    }

    var countsTowardCredit: Bool {
        status == .completed && consumesCredit
    }

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var progress: Double {
        guard totalSetCount > 0 else { return 0 }
        return Double(completedSetCount) / Double(totalSetCount)
    }
}
