import Foundation
import SwiftData

@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    var plannedWeightKg: Double?
    var plannedReps: Int?
    var actualWeightKg: Double?
    var actualReps: Int?
    var rpe: Double?
    var notes: String = ""
    var isCompleted: Bool
    var completedAt: Date?
    var exercise: ExerciseEntry?

    init(
        id: UUID = UUID(),
        sortIndex: Int,
        plannedWeightKg: Double? = nil,
        plannedReps: Int? = nil,
        actualWeightKg: Double? = nil,
        actualReps: Int? = nil,
        rpe: Double? = nil,
        notes: String = "",
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.plannedWeightKg = plannedWeightKg
        self.plannedReps = plannedReps
        self.actualWeightKg = actualWeightKg
        self.actualReps = actualReps
        self.rpe = rpe
        self.notes = notes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

@Model
final class BodyMeasurement {
    @Attribute(.unique) var id: UUID
    var measuredAt: Date
    var weightKg: Double?
    var bodyFatPercentage: Double?
    var hipCm: Double?
    var chestCm: Double?
    var waistCm: Double?
    var notes: String
    var student: Student?

    init(
        id: UUID = UUID(),
        measuredAt: Date = Date(),
        weightKg: Double? = nil,
        bodyFatPercentage: Double? = nil,
        hipCm: Double? = nil,
        chestCm: Double? = nil,
        waistCm: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.hipCm = hipCm
        self.chestCm = chestCm
        self.waistCm = waistCm
        self.notes = notes
    }
}

enum CreditTransactionKind: String, Codable, Hashable {
    case purchase
    case consume
    case refund
    case adjustment
    case openingBalance
}

@Model
final class CreditTransaction {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var idempotencyKey: String
    var amount: Int
    var kindCode: String
    var occurredAt: Date
    var note: String
    var sessionIDSnapshot: UUID?
    var reversesTransactionID: UUID?
    var student: Student?
    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        idempotencyKey: String,
        amount: Int,
        kind: CreditTransactionKind,
        occurredAt: Date = Date(),
        note: String = "",
        sessionIDSnapshot: UUID? = nil,
        reversesTransactionID: UUID? = nil
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.amount = amount
        self.kindCode = kind.rawValue
        self.occurredAt = occurredAt
        self.note = note
        self.sessionIDSnapshot = sessionIDSnapshot
        self.reversesTransactionID = reversesTransactionID
    }

    var kind: CreditTransactionKind {
        CreditTransactionKind(rawValue: kindCode) ?? .adjustment
    }
}

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var student: Student?

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise] = []

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var sortedExercises: [TemplateExercise] {
        exercises.sorted { $0.sortIndex < $1.sortIndex }
    }
}

@Model
final class TemplateExercise {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    var name: String
    var categoryCode: String
    var setsCount: Int
    var reps: Int
    var weightKg: Double?
    var restSeconds: Int
    var targetRPE: Double?
    var durationMinutes: Double
    var template: WorkoutTemplate?

    init(
        id: UUID = UUID(),
        sortIndex: Int,
        name: String,
        category: ExerciseCategory,
        setsCount: Int,
        reps: Int,
        weightKg: Double? = nil,
        restSeconds: Int,
        targetRPE: Double? = nil,
        durationMinutes: Double = 0
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.name = name
        self.categoryCode = category.rawValue
        self.setsCount = setsCount
        self.reps = reps
        self.weightKg = weightKg
        self.restSeconds = restSeconds
        self.targetRPE = targetRPE
        self.durationMinutes = durationMinutes
    }

    var category: ExerciseCategory {
        ExerciseCategory(rawValue: categoryCode) ?? .strength
    }
}
