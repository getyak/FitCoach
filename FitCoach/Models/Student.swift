import Foundation
import SwiftData

enum Gender: String, Codable, CaseIterable, Hashable {
    case male = "男"
    case female = "女"
    case other = "其他"
}

enum FitnessLevel: String, Codable, CaseIterable, Hashable {
    case beginner = "运动新手"
    case intermediate = "有一定基础"
    case advanced = "经验丰富"
}

@Model
final class Student {
    var name: String
    var gender: String
    var age: Int
    var fitnessLevel: String
    var weightKg: Double
    var heightCm: Double
    var bodyFatPercentage: Double?
    var hipCm: Double?
    var chestCm: Double?
    var waistCm: Double?
    var fitnessGoal: String
    var notes: String
    var createdDate: Date
    /// true = 这是App使用者自己（教练本人）的档案，不是学员，不出现在"我的学员"列表里
    var isOwner: Bool
    /// 学员购买的总课时数（比如买了20节课）。nil = 不追踪课时。
    var totalPurchasedSessions: Int?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSession.student)
    var workoutSessions: [WorkoutSession] = []

    init(
        name: String,
        gender: Gender,
        age: Int,
        fitnessLevel: FitnessLevel,
        weightKg: Double,
        heightCm: Double,
        bodyFatPercentage: Double? = nil,
        hipCm: Double? = nil,
        chestCm: Double? = nil,
        waistCm: Double? = nil,
        fitnessGoal: String = "",
        notes: String = "",
        isOwner: Bool = false,
        totalPurchasedSessions: Int? = nil
    ) {
        self.name = name
        self.gender = gender.rawValue
        self.age = age
        self.fitnessLevel = fitnessLevel.rawValue
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.bodyFatPercentage = bodyFatPercentage
        self.hipCm = hipCm
        self.chestCm = chestCm
        self.waistCm = waistCm
        self.fitnessGoal = fitnessGoal
        self.notes = notes
        self.createdDate = Date()
        self.isOwner = isOwner
        self.totalPurchasedSessions = totalPurchasedSessions
    }

    var genderEnum: Gender {
        Gender(rawValue: gender) ?? .other
    }

    var fitnessLevelEnum: FitnessLevel {
        FitnessLevel(rawValue: fitnessLevel) ?? .beginner
    }

    /// 剩余课时 = 总课时 - 已经记录过的训练次数。没设置总课时就返回 nil（不追踪）。
    var remainingSessions: Int? {
        guard let total = totalPurchasedSessions else { return nil }
        return max(0, total - workoutSessions.count)
    }
}
