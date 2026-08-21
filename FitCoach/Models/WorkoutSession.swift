import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var date: Date
    var title: String

    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.session)
    var exercises: [ExerciseEntry] = []

    var student: Student?

    init(date: Date = Date(), title: String = "") {
        self.date = date
        self.title = title
    }

    /// 本次训练课程的总消耗卡路里（基于每个动作的实际完成数据）
    var totalCalories: Double {
        guard let weight = student?.weightKg else { return 0 }
        return exercises.reduce(0) { $0 + $1.caloriesBurned(studentWeightKg: weight) }
    }

    /// 只要有一个动作被标记"已完成"，这次训练就算已完成——
    /// 计划里的动作不一定会全部做完，不能要求全部打勾才算完成。
    var isFullyCompleted: Bool {
        exercises.contains { $0.isCompleted }
    }
}
