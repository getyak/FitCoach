import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {
    static func prepareIfNeeded(in context: ModelContext) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting") else { return }

        if arguments.contains("-resetStore") {
            reset(context)
        }

        let students = (try? context.fetch(FetchDescriptor<Student>())) ?? []
        guard students.isEmpty else { return }
        seedTodayScenario(in: context)
    }

    private static func reset(_ context: ModelContext) {
        deleteAll(CreditTransaction.self, in: context)
        deleteAll(WorkoutSet.self, in: context)
        deleteAll(TemplateExercise.self, in: context)
        deleteAll(ExerciseEntry.self, in: context)
        deleteAll(WorkoutSession.self, in: context)
        deleteAll(BodyMeasurement.self, in: context)
        deleteAll(WorkoutTemplate.self, in: context)
        deleteAll(Student.self, in: context)
        try? context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        guard let objects = try? context.fetch(FetchDescriptor<T>()) else { return }
        objects.forEach(context.delete)
    }

    private static func seedTodayScenario(in context: ModelContext) {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let student = Student(
            name: "林悦",
            gender: .female,
            age: 29,
            fitnessLevel: .intermediate,
            weightKg: 62.4,
            heightCm: 168,
            bodyFatPercentage: 23.1,
            waistCm: 71,
            fitnessGoal: "减脂并改善下肢力量",
            notes: "训练节奏稳定，偏好简洁明确的反馈。",
            safetyNotes: "右膝偶尔不适，深蹲控制幅度，训练前先询问今日状态。",
            totalPurchasedSessions: 10
        )
        context.insert(student)

        let opening = CreditTransaction(
            idempotencyKey: "student:\(student.id.uuidString):opening",
            amount: 10,
            kind: .openingBalance,
            occurredAt: calendar.date(byAdding: .month, value: -2, to: now) ?? now,
            note: "购买 10 节课"
        )
        opening.student = student
        context.insert(opening)

        let previous = WorkoutSession(
            date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
            title: "下肢力量",
            status: .completed
        )
        previous.startedAt = previous.date
        previous.completedAt = previous.date.addingTimeInterval(48 * 60)
        previous.summary = "动作稳定，右膝无明显不适。"
        previous.student = student
        context.insert(previous)

        addExercise(
            name: "高脚杯深蹲",
            sortIndex: 0,
            weight: 20,
            reps: 10,
            rpe: 7,
            rest: 75,
            session: previous,
            context: context
        )
        addExercise(
            name: "罗马尼亚硬拉",
            sortIndex: 1,
            weight: 32.5,
            reps: 10,
            rpe: 8,
            rest: 90,
            session: previous,
            context: context
        )
        addExercise(
            name: "保加利亚分腿蹲",
            sortIndex: 2,
            weight: 10,
            reps: 8,
            rpe: 8,
            rest: 75,
            session: previous,
            context: context
        )

        let consumed = CreditTransaction(
            idempotencyKey: "session:\(previous.id.uuidString):consume:1",
            amount: -1,
            kind: .consume,
            occurredAt: previous.completedAt ?? previous.date,
            note: previous.title,
            sessionIDSnapshot: previous.id
        )
        consumed.student = student
        consumed.session = previous
        context.insert(consumed)

        [
            (-56, 65.2, 76.0, 24.8),
            (-42, 64.4, 74.5, 24.3),
            (-28, 63.8, 73.2, 23.9),
            (-14, 63.1, 72.0, 23.5),
            (0, 62.4, 71.0, 23.1)
        ].forEach { offset, weight, waist, bodyFat in
            let measurement = BodyMeasurement(
                measuredAt: calendar.date(byAdding: .day, value: offset, to: now) ?? now,
                weightKg: weight,
                bodyFatPercentage: bodyFat,
                waistCm: waist
            )
            measurement.student = student
            context.insert(measurement)
        }

        try? context.save()
    }

    private static func addExercise(
        name: String,
        sortIndex: Int,
        weight: Double,
        reps: Int,
        rpe: Double,
        rest: Int,
        session: WorkoutSession,
        context: ModelContext
    ) {
        let exercise = ExerciseEntry(
            name: name,
            category: .strength,
            sortIndex: sortIndex,
            plannedSets: 3,
            plannedReps: reps,
            plannedRestSeconds: rest,
            plannedDurationMinutes: 10
        )
        exercise.targetRPE = rpe
        exercise.isCompleted = true
        exercise.session = session
        context.insert(exercise)

        for setIndex in 0..<3 {
            let set = WorkoutSet(
                sortIndex: setIndex,
                plannedWeightKg: weight,
                plannedReps: reps,
                actualWeightKg: weight,
                actualReps: reps,
                rpe: rpe,
                isCompleted: true,
                completedAt: session.completedAt
            )
            set.exercise = exercise
            context.insert(set)
        }
    }
}
