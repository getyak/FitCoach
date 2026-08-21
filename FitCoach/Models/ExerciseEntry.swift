import Foundation
import SwiftData

/// 动作类型，用于估算卡路里消耗（MET 值：代谢当量）
enum ExerciseCategory: String, Codable, CaseIterable, Hashable {
    case strength = "力量训练"
    case cardio = "有氧训练"
    case flexibility = "拉伸/柔韧"
    case core = "核心训练"
    case hiit = "高强度间歇(HIIT)"

    /// 常见的 MET（代谢当量）参考值。有氧训练的 MET 由 CardioIntensity 决定，这里的值只是兜底。
    var metValue: Double {
        switch self {
        case .strength: return 5.0
        case .cardio: return 6.0
        case .flexibility: return 2.5
        case .core: return 4.0
        case .hiit: return 8.5
        }
    }
}

/// 有氧训练的强度分档（替代组数/次数/间歇这些力量训练才需要的参数）
enum CardioIntensity: String, Codable, CaseIterable, Hashable {
    case light = "轻度有氧"
    case moderate = "中度有氧"
    case high = "高度有氧"

    /// 常见的 MET（代谢当量）参考值
    var metValue: Double {
        switch self {
        case .light: return 3.5
        case .moderate: return 6.0
        case .high: return 9.0
        }
    }
}

@Model
final class ExerciseEntry {
    var name: String
    var category: String
    /// 只有当 category 是"有氧训练"时才有值：轻度/中度/高度
    var cardioIntensity: String?

    // 训练计划（教练提前设计）—— 力量类动作才用得到组数/次数/间歇
    var plannedSets: Int
    var plannedReps: Int
    var plannedRestSeconds: Int
    var plannedDurationMinutes: Double

    // 实际完成情况（训练后填写）
    var actualSets: Int
    var actualReps: Int
    var actualRestSeconds: Int
    var actualDurationMinutes: Double
    var isCompleted: Bool

    var session: WorkoutSession?

    init(
        name: String,
        category: ExerciseCategory,
        cardioIntensity: CardioIntensity? = nil,
        plannedSets: Int = 0,
        plannedReps: Int = 0,
        plannedRestSeconds: Int = 0,
        plannedDurationMinutes: Double
    ) {
        self.name = name
        self.category = category.rawValue
        self.cardioIntensity = cardioIntensity?.rawValue
        self.plannedSets = plannedSets
        self.plannedReps = plannedReps
        self.plannedRestSeconds = plannedRestSeconds
        self.plannedDurationMinutes = plannedDurationMinutes
        self.actualSets = 0
        self.actualReps = 0
        self.actualRestSeconds = 0
        self.actualDurationMinutes = 0
        self.isCompleted = false
    }

    var categoryEnum: ExerciseCategory {
        ExerciseCategory(rawValue: category) ?? .strength
    }

    var cardioIntensityEnum: CardioIntensity? {
        cardioIntensity.flatMap { CardioIntensity(rawValue: $0) }
    }

    /// 根据实际完成的训练时长 + 动作强度(MET) + 学员体重 估算本动作消耗的卡路里
    /// 公式：卡路里(kcal) = MET × 体重(kg) × 时长(小时)
    /// 有氧训练用它自己选的强度档位算 MET，其他类型用类型固定的 MET。
    func caloriesBurned(studentWeightKg: Double) -> Double {
        guard isCompleted, actualDurationMinutes > 0, studentWeightKg > 0 else { return 0 }
        let hours = actualDurationMinutes / 60.0
        let met = (categoryEnum == .cardio ? cardioIntensityEnum?.metValue : nil) ?? categoryEnum.metValue
        return met * studentWeightKg * hours
    }
}
