import Foundation
import SwiftData

enum SessionServiceError: LocalizedError, Equatable {
    case missingStudent
    case noExercises
    case noCompletedWork
    case invalidState
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .missingStudent: return "课程没有关联学员"
        case .noExercises: return "训练中还没有动作"
        case .noCompletedWork: return "请至少完成一组后再结束训练"
        case .invalidState: return "当前课程状态不允许此操作"
        case .saveFailed: return "数据保存失败，请重试"
        }
    }
}

/// 所有会影响课程状态和课时余额的写入都集中在这里。
/// View 只发出意图，不能直接修改完成状态或课时流水。
@MainActor
struct SessionService {
    let context: ModelContext
    var now: () -> Date = Date.init

    @discardableResult
    func startByCopying(
        source: WorkoutSession,
        for student: Student,
        title: String? = nil
    ) throws -> WorkoutSession {
        let startedAt = now()
        let session = WorkoutSession(
            date: startedAt,
            title: title ?? source.title,
            status: .inProgress,
            consumesCredit: source.consumesCredit
        )
        session.startedAt = startedAt
        session.student = student
        context.insert(session)

        for (exerciseIndex, sourceExercise) in source.sortedExercises.enumerated() {
            let exercise = ExerciseEntry(
                name: sourceExercise.name,
                category: sourceExercise.categoryEnum,
                cardioIntensity: sourceExercise.cardioIntensityEnum,
                sortIndex: exerciseIndex,
                plannedSets: max(sourceExercise.sets.count, sourceExercise.plannedSets),
                plannedReps: sourceExercise.plannedReps,
                plannedRestSeconds: sourceExercise.plannedRestSeconds,
                plannedDurationMinutes: sourceExercise.plannedDurationMinutes
            )
            exercise.notes = ""
            exercise.targetRPE = sourceExercise.targetRPE
            exercise.session = session
            context.insert(exercise)

            let sourceSets = sourceExercise.sortedSets
            if sourceSets.isEmpty {
                for index in 0..<max(1, sourceExercise.plannedSets) {
                    let set = WorkoutSet(
                        sortIndex: index,
                        plannedReps: sourceExercise.actualReps > 0 ? sourceExercise.actualReps : sourceExercise.plannedReps,
                        actualReps: sourceExercise.actualReps > 0 ? sourceExercise.actualReps : sourceExercise.plannedReps
                    )
                    set.exercise = exercise
                    context.insert(set)
                }
            } else {
                for (index, sourceSet) in sourceSets.enumerated() {
                    let weight = sourceSet.actualWeightKg ?? sourceSet.plannedWeightKg
                    let reps = sourceSet.actualReps ?? sourceSet.plannedReps
                    let set = WorkoutSet(
                        sortIndex: index,
                        plannedWeightKg: weight,
                        plannedReps: reps,
                        actualWeightKg: weight,
                        actualReps: reps
                    )
                    set.exercise = exercise
                    context.insert(set)
                }
            }
        }

        try save()
        return session
    }

    @discardableResult
    func startFromTemplate(_ template: WorkoutTemplate, for student: Student) throws -> WorkoutSession {
        let startedAt = now()
        let session = WorkoutSession(
            date: startedAt,
            title: template.name,
            status: .inProgress,
            consumesCredit: student.tracksCredits
        )
        session.startedAt = startedAt
        session.student = student
        context.insert(session)

        for templateExercise in template.sortedExercises {
            let exercise = ExerciseEntry(
                name: templateExercise.name,
                category: templateExercise.category,
                sortIndex: templateExercise.sortIndex,
                plannedSets: templateExercise.setsCount,
                plannedReps: templateExercise.reps,
                plannedRestSeconds: templateExercise.restSeconds,
                plannedDurationMinutes: templateExercise.durationMinutes
            )
            exercise.targetRPE = templateExercise.targetRPE
            exercise.session = session
            context.insert(exercise)

            for index in 0..<templateExercise.setsCount {
                let set = WorkoutSet(
                    sortIndex: index,
                    plannedWeightKg: templateExercise.weightKg,
                    plannedReps: templateExercise.reps,
                    actualWeightKg: templateExercise.weightKg,
                    actualReps: templateExercise.reps
                )
                set.exercise = exercise
                context.insert(set)
            }
        }

        try save()
        return session
    }

    func completeSet(_ set: WorkoutSet, in session: WorkoutSession, restSeconds: Int) throws {
        guard session.status == .inProgress else { throw SessionServiceError.invalidState }
        let timestamp = now()
        set.isCompleted = true
        set.completedAt = timestamp
        session.status = .inProgress
        session.startedAt = session.startedAt ?? timestamp
        session.restEndsAt = timestamp.addingTimeInterval(TimeInterval(max(0, restSeconds)))
        session.updatedAt = timestamp
        try save()
    }

    func undoSet(_ set: WorkoutSet, in session: WorkoutSession) throws {
        guard session.status == .inProgress else { throw SessionServiceError.invalidState }
        set.isCompleted = false
        set.completedAt = nil
        session.restEndsAt = nil
        session.updatedAt = now()
        try save()
    }

    func complete(_ session: WorkoutSession, editedSummary: String? = nil) throws {
        guard session.status != .completed else { return }
        guard session.status == .inProgress else { throw SessionServiceError.invalidState }
        guard !session.exercises.isEmpty else { throw SessionServiceError.noExercises }
        guard session.completedSetCount > 0 || session.exercises.contains(where: \.isCompleted) else {
            throw SessionServiceError.noCompletedWork
        }
        guard let student = session.student else { throw SessionServiceError.missingStudent }

        let timestamp = now()
        session.completionEpoch += 1
        session.status = .completed
        session.completedAt = timestamp
        session.restEndsAt = nil
        session.summary = editedSummary ?? generatedSummary(for: session)
        session.updatedAt = timestamp

        ensureOpeningBalance(for: student, excluding: session)

        if session.consumesCredit && student.tracksCredits {
            let key = "session:\(session.id.uuidString):consume:\(session.completionEpoch)"
            if !student.creditTransactions.contains(where: { $0.idempotencyKey == key }) {
                let transaction = CreditTransaction(
                    idempotencyKey: key,
                    amount: -1,
                    kind: .consume,
                    occurredAt: timestamp,
                    note: session.title,
                    sessionIDSnapshot: session.id
                )
                transaction.student = student
                transaction.session = session
                context.insert(transaction)
            }
        }

        try save()
    }

    func start(_ session: WorkoutSession) throws {
        guard session.status == .planned else { return }
        let timestamp = now()
        session.status = .inProgress
        session.startedAt = timestamp
        session.date = timestamp
        session.updatedAt = timestamp
        try save()
    }

    func reopen(_ session: WorkoutSession) throws {
        guard session.status == .completed else { return }
        guard let student = session.student else { throw SessionServiceError.missingStudent }

        let activeDebit = student.creditTransactions
            .filter { $0.kind == .consume && $0.sessionIDSnapshot == session.id }
            .sorted { $0.occurredAt > $1.occurredAt }
            .first { debit in
                !student.creditTransactions.contains { $0.reversesTransactionID == debit.id }
            }

        if let activeDebit {
            let key = "reverse:\(activeDebit.id.uuidString)"
            if !student.creditTransactions.contains(where: { $0.idempotencyKey == key }) {
                let refund = CreditTransaction(
                    idempotencyKey: key,
                    amount: 1,
                    kind: .refund,
                    occurredAt: now(),
                    note: "撤销课程完成",
                    sessionIDSnapshot: session.id,
                    reversesTransactionID: activeDebit.id
                )
                refund.student = student
                refund.session = session
                context.insert(refund)
            }
        }

        session.status = .inProgress
        session.completedAt = nil
        session.updatedAt = now()
        try save()
    }

    func createOpeningBalance(for student: Student, amount: Int) throws {
        let key = "student:\(student.id.uuidString):opening"
        guard !student.creditTransactions.contains(where: { $0.idempotencyKey == key }) else { return }
        let transaction = CreditTransaction(
            idempotencyKey: key,
            amount: amount,
            kind: .openingBalance,
            occurredAt: student.createdDate,
            note: "初始课时"
        )
        transaction.student = student
        context.insert(transaction)
        try save()
    }

    /// 记录续费或人工调整，同时保留旧总课时字段用于兼容旧备份。
    func adjustPurchasedCredits(for student: Student, newTotal: Int) throws {
        let oldTotal = student.totalPurchasedSessions ?? 0
        let difference = newTotal - oldTotal
        student.totalPurchasedSessions = newTotal
        guard difference != 0 else {
            try save()
            return
        }

        if student.creditTransactions.isEmpty {
            let opening = CreditTransaction(
                idempotencyKey: "student:\(student.id.uuidString):opening",
                amount: newTotal,
                kind: .openingBalance,
                occurredAt: now(),
                note: "初始课时"
            )
            opening.student = student
            context.insert(opening)
        } else {
            let transaction = CreditTransaction(
                idempotencyKey: "student:\(student.id.uuidString):credit-adjustment:\(UUID().uuidString)",
                amount: difference,
                kind: difference > 0 ? .purchase : .adjustment,
                occurredAt: now(),
                note: difference > 0 ? "续费 \(difference) 节" : "调整课时 \(difference) 节"
            )
            transaction.student = student
            context.insert(transaction)
        }
        try save()
    }

    func cancel(_ session: WorkoutSession) throws {
        guard session.status == .planned || session.status == .inProgress else {
            throw SessionServiceError.invalidState
        }
        session.status = .cancelled
        session.restEndsAt = nil
        session.updatedAt = now()
        try save()
    }

    private func ensureOpeningBalance(for student: Student, excluding currentSession: WorkoutSession) {
        guard student.creditTransactions.isEmpty, let purchased = student.totalPurchasedSessions else { return }

        let opening = CreditTransaction(
            idempotencyKey: "student:\(student.id.uuidString):opening",
            amount: purchased,
            kind: .openingBalance,
            occurredAt: student.createdDate,
            note: "历史课时迁移"
        )
        opening.student = student
        context.insert(opening)

        for legacySession in student.workoutSessions where legacySession.id != currentSession.id && legacySession.countsTowardCredit {
            let debit = CreditTransaction(
                idempotencyKey: "session:\(legacySession.id.uuidString):legacy-consume",
                amount: -1,
                kind: .consume,
                occurredAt: legacySession.completedAt ?? legacySession.date,
                note: "历史课程",
                sessionIDSnapshot: legacySession.id
            )
            debit.student = student
            debit.session = legacySession
            context.insert(debit)
        }
    }

    private func generatedSummary(for session: WorkoutSession) -> String {
        let completedExercises = session.sortedExercises.filter { exercise in
            exercise.sets.contains(where: \.isCompleted) || exercise.isCompleted
        }
        let completedSets = completedExercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
        let exerciseNames = completedExercises.prefix(3).map(\.name).joined(separator: "、")
        let highlights = exerciseNames.isEmpty ? "完成本节训练" : "完成\(exerciseNames)"
        return "本次\(highlights)，共 \(completedExercises.count) 个动作、\(completedSets) 组。下次训练建议沿用本次实际数据并根据状态微调。"
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw SessionServiceError.saveFailed
        }
    }
}
