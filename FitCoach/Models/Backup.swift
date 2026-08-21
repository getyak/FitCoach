import Foundation
import SwiftData

/// 导出/导入用的数据结构，跟 SwiftData 的 @Model 分开，方便编码成 JSON 文件。

struct ExerciseEntryBackup: Codable {
    var name: String
    var category: String
    var cardioIntensity: String?
    var plannedSets: Int
    var plannedReps: Int
    var plannedRestSeconds: Int
    var plannedDurationMinutes: Double
    var actualSets: Int
    var actualReps: Int
    var actualRestSeconds: Int
    var actualDurationMinutes: Double
    var isCompleted: Bool
}

struct WorkoutSessionBackup: Codable {
    var date: Date
    var title: String
    var exercises: [ExerciseEntryBackup]
}

struct StudentBackup: Codable {
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
    var isOwner: Bool
    var totalPurchasedSessions: Int?
    var workoutSessions: [WorkoutSessionBackup]
}

struct BackupPayload: Codable {
    var exportedAt: Date
    var students: [StudentBackup]
}

extension ExerciseEntry {
    func toBackup() -> ExerciseEntryBackup {
        ExerciseEntryBackup(
            name: name,
            category: category,
            cardioIntensity: cardioIntensity,
            plannedSets: plannedSets,
            plannedReps: plannedReps,
            plannedRestSeconds: plannedRestSeconds,
            plannedDurationMinutes: plannedDurationMinutes,
            actualSets: actualSets,
            actualReps: actualReps,
            actualRestSeconds: actualRestSeconds,
            actualDurationMinutes: actualDurationMinutes,
            isCompleted: isCompleted
        )
    }
}

extension WorkoutSession {
    func toBackup() -> WorkoutSessionBackup {
        WorkoutSessionBackup(
            date: date,
            title: title,
            exercises: exercises.map { $0.toBackup() }
        )
    }
}

extension Student {
    func toBackup() -> StudentBackup {
        StudentBackup(
            name: name,
            gender: gender,
            age: age,
            fitnessLevel: fitnessLevel,
            weightKg: weightKg,
            heightCm: heightCm,
            bodyFatPercentage: bodyFatPercentage,
            hipCm: hipCm,
            chestCm: chestCm,
            waistCm: waistCm,
            fitnessGoal: fitnessGoal,
            notes: notes,
            isOwner: isOwner,
            totalPurchasedSessions: totalPurchasedSessions,
            workoutSessions: workoutSessions.map { $0.toBackup() }
        )
    }
}

/// 把一份导入的学员数据插入到 SwiftData 数据库里（连同它的训练记录、动作）
func insertBackupStudent(_ backup: StudentBackup, into context: ModelContext) {
    let student = Student(
        name: backup.name,
        gender: Gender(rawValue: backup.gender) ?? .other,
        age: backup.age,
        fitnessLevel: FitnessLevel(rawValue: backup.fitnessLevel) ?? .beginner,
        weightKg: backup.weightKg,
        heightCm: backup.heightCm,
        bodyFatPercentage: backup.bodyFatPercentage,
        hipCm: backup.hipCm,
        chestCm: backup.chestCm,
        waistCm: backup.waistCm,
        fitnessGoal: backup.fitnessGoal,
        notes: backup.notes,
        isOwner: backup.isOwner,
        totalPurchasedSessions: backup.totalPurchasedSessions
    )
    context.insert(student)

    for sessionBackup in backup.workoutSessions {
        let isCompleted = sessionBackup.exercises.contains(where: \.isCompleted)
        let session = WorkoutSession(
            date: sessionBackup.date,
            title: sessionBackup.title,
            status: isCompleted ? .completed : .planned,
            consumesCredit: backup.totalPurchasedSessions != nil
        )
        if isCompleted {
            session.startedAt = sessionBackup.date
            session.completedAt = sessionBackup.date
        }
        session.student = student
        context.insert(session)

        for exerciseBackup in sessionBackup.exercises {
            let category = ExerciseCategory(rawValue: exerciseBackup.category) ?? .strength
            let intensity = exerciseBackup.cardioIntensity.flatMap { CardioIntensity(rawValue: $0) }
            let exercise = ExerciseEntry(
                name: exerciseBackup.name,
                category: category,
                cardioIntensity: intensity,
                plannedSets: exerciseBackup.plannedSets,
                plannedReps: exerciseBackup.plannedReps,
                plannedRestSeconds: exerciseBackup.plannedRestSeconds,
                plannedDurationMinutes: exerciseBackup.plannedDurationMinutes
            )
            exercise.actualSets = exerciseBackup.actualSets
            exercise.actualReps = exerciseBackup.actualReps
            exercise.actualRestSeconds = exerciseBackup.actualRestSeconds
            exercise.actualDurationMinutes = exerciseBackup.actualDurationMinutes
            exercise.isCompleted = exerciseBackup.isCompleted
            exercise.session = session
            context.insert(exercise)

            if category != .cardio {
                for index in 0..<max(exerciseBackup.plannedSets, exerciseBackup.actualSets) {
                    let set = WorkoutSet(
                        sortIndex: index,
                        plannedReps: exerciseBackup.plannedReps,
                        actualReps: index < exerciseBackup.actualSets ? exerciseBackup.actualReps : nil,
                        isCompleted: index < exerciseBackup.actualSets && exerciseBackup.isCompleted,
                        completedAt: index < exerciseBackup.actualSets && exerciseBackup.isCompleted ? sessionBackup.date : nil
                    )
                    set.exercise = exercise
                    context.insert(set)
                }
            }
        }
    }

    if let total = backup.totalPurchasedSessions {
        let opening = CreditTransaction(
            idempotencyKey: "student:\(student.id.uuidString):opening",
            amount: total,
            kind: .openingBalance,
            occurredAt: student.createdDate,
            note: "旧版备份课时"
        )
        opening.student = student
        context.insert(opening)

        for session in student.workoutSessions where session.status == .completed {
            let debit = CreditTransaction(
                idempotencyKey: "session:\(session.id.uuidString):legacy-consume",
                amount: -1,
                kind: .consume,
                occurredAt: session.completedAt ?? session.date,
                note: "旧版备份课程",
                sessionIDSnapshot: session.id
            )
            debit.student = student
            debit.session = session
            context.insert(debit)
        }
    }
}
