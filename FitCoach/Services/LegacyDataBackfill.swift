import Foundation
import SwiftData

/// 可重入的旧数据回填。每一步都以目标记录是否存在为判断，强退后再次运行不会重复。
@MainActor
enum LegacyDataBackfill {
    private static let markerKey = "legacy-v3-backfill"
    private static let uuidRepairMarkerKey = "legacy-uuid-repair-v1"

    static func run(in context: ModelContext) throws {
        do {
            try performRun(in: context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func performRun(in context: ModelContext) throws {
        let markers = try context.fetch(FetchDescriptor<MigrationMarker>())
        if !markers.contains(where: { $0.key == uuidRepairMarkerKey }) {
            let students = try context.fetch(FetchDescriptor<Student>())
            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntry>())
            repairLegacyDuplicateIDs(students: students, sessions: sessions, exercises: exercises)
            context.insert(MigrationMarker(key: uuidRepairMarkerKey))
            try context.save()
        }

        guard !markers.contains(where: { $0.key == markerKey }) else { return }

        let students = try context.fetch(FetchDescriptor<Student>())

        for student in students {
            if student.tracksCreditsFlag == nil {
                student.tracksCreditsFlag = student.totalPurchasedSessions != nil || !student.creditTransactions.isEmpty
            }
            if student.measurements.isEmpty,
               student.weightKg > 0 || student.bodyFatPercentage != nil || student.waistCm != nil {
                let measurement = BodyMeasurement(
                    measuredAt: student.createdDate,
                    weightKg: student.weightKg > 0 ? student.weightKg : nil,
                    bodyFatPercentage: student.bodyFatPercentage,
                    hipCm: student.hipCm,
                    chestCm: student.chestCm,
                    waistCm: student.waistCm,
                    notes: "旧版初始体测"
                )
                measurement.student = student
                context.insert(measurement)
            }

            for (sessionIndex, session) in student.workoutSessions.sorted(by: { $0.date < $1.date }).enumerated() {
                if session.statusCode == nil {
                    session.status = session.exercises.contains(where: \.isCompleted) ? .completed : .planned
                    if session.status == .completed {
                        session.startedAt = session.startedAt ?? session.date
                        session.completedAt = session.completedAt ?? session.date
                    }
                }

                for (exerciseIndex, exercise) in session.exercises.enumerated() {
                    if exercise.sortIndex == 0 && exerciseIndex > 0 { exercise.sortIndex = exerciseIndex }
                    guard exercise.categoryEnum != .cardio, exercise.sets.isEmpty else { continue }
                    let count = max(exercise.plannedSets, exercise.actualSets)
                    for setIndex in 0..<count {
                        let completed = exercise.isCompleted && setIndex < exercise.actualSets
                        let set = WorkoutSet(
                            sortIndex: setIndex,
                            plannedReps: exercise.plannedReps,
                            actualReps: setIndex < exercise.actualSets ? exercise.actualReps : exercise.plannedReps,
                            isCompleted: completed,
                            completedAt: completed ? (session.completedAt ?? session.date) : nil
                        )
                        set.exercise = exercise
                        context.insert(set)
                    }
                }

                if session.createdAt > session.date { session.createdAt = session.date }
                if sessionIndex == 0 && session.updatedAt < session.date { session.updatedAt = session.date }
            }

            if student.creditTransactions.isEmpty, let total = student.totalPurchasedSessions {
                let opening = CreditTransaction(
                    idempotencyKey: "student:\(student.id.uuidString):opening",
                    amount: total,
                    kind: .openingBalance,
                    occurredAt: student.createdDate,
                    note: "历史课时迁移"
                )
                opening.student = student
                context.insert(opening)

                for session in student.workoutSessions where session.status == .completed && session.consumesCredit {
                    let debit = CreditTransaction(
                        idempotencyKey: "session:\(session.id.uuidString):legacy-consume",
                        amount: -1,
                        kind: .consume,
                        occurredAt: session.completedAt ?? session.date,
                        note: "历史课程",
                        sessionIDSnapshot: session.id
                    )
                    debit.student = student
                    debit.session = session
                    context.insert(debit)
                }
            }
        }

        context.insert(MigrationMarker(key: markerKey))
        try context.save()
    }

    /// SwiftData evaluates a newly-added property default once while inferring a
    /// legacy migration, so every old row can receive the same UUID. Repair IDs
    /// before deriving ledger idempotency keys, then persist them with the marker.
    private static func repairLegacyDuplicateIDs(
        students: [Student],
        sessions: [WorkoutSession],
        exercises: [ExerciseEntry]
    ) {
        var studentIDs = Set<UUID>()
        for student in students {
            while studentIDs.contains(student.id) { student.id = UUID() }
            studentIDs.insert(student.id)
        }

        var sessionIDs = Set<UUID>()
        for session in sessions {
            let legacyID = session.id
            while sessionIDs.contains(session.id) { session.id = UUID() }
            if session.id != legacyID {
                for transaction in session.creditTransactions {
                    transaction.sessionIDSnapshot = session.id
                }
            }
            sessionIDs.insert(session.id)
        }

        var exerciseIDs = Set<UUID>()
        for exercise in exercises {
            while exerciseIDs.contains(exercise.id) { exercise.id = UUID() }
            exerciseIDs.insert(exercise.id)
        }
    }
}
