import XCTest
import SwiftData
@testable import FitCoach

@MainActor
final class SessionServiceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Student.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            WorkoutSet.self,
            BodyMeasurement.self,
            CreditTransaction.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            configurations: configuration
        )
    }

    func testCompletingSessionConsumesExactlyOneCredit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = Student(
            name: "小林",
            gender: .female,
            age: 29,
            fitnessLevel: .intermediate,
            weightKg: 62,
            heightCm: 168,
            totalPurchasedSessions: 10
        )
        context.insert(student)

        let service = SessionService(context: context, now: { Date(timeIntervalSince1970: 1_000) })
        try service.createOpeningBalance(for: student, amount: 10)

        let session = makeSession(for: student, in: context)
        try service.complete(session)
        try service.complete(session)

        XCTAssertEqual(student.remainingSessions, 9)
        XCTAssertEqual(student.creditTransactions.filter { $0.kind == .consume }.count, 1)
        XCTAssertEqual(session.status, .completed)
    }

    func testReopenRefundsOnceAndRecompleteKeepsNetSingleDebit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = makeStudent(in: context)
        let service = SessionService(context: context)
        try service.createOpeningBalance(for: student, amount: 10)
        let session = makeSession(for: student, in: context)

        try service.complete(session)
        try service.reopen(session)
        try service.reopen(session)
        XCTAssertEqual(student.remainingSessions, 10)

        try service.complete(session)
        XCTAssertEqual(student.remainingSessions, 9)
        XCTAssertEqual(student.creditTransactions.reduce(0) { $0 + $1.amount }, 9)
    }

    func testCopyUsesPreviousActualValuesAndClearsCompletion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = makeStudent(in: context)
        let previous = makeSession(for: student, in: context)
        let previousSet = try XCTUnwrap(previous.exercises.first?.sets.first)
        previousSet.actualWeightKg = 42.5
        previousSet.actualReps = 8
        previousSet.rpe = 9
        previousSet.isCompleted = true
        previousSet.completedAt = Date()

        let copied = try SessionService(context: context).startByCopying(source: previous, for: student)
        let copiedSet = try XCTUnwrap(copied.exercises.first?.sets.first)

        XCTAssertEqual(copiedSet.plannedWeightKg, 42.5)
        XCTAssertEqual(copiedSet.actualWeightKg, 42.5)
        XCTAssertEqual(copiedSet.actualReps, 8)
        XCTAssertNil(copiedSet.rpe)
        XCTAssertFalse(copiedSet.isCompleted)
        XCTAssertNil(copiedSet.completedAt)
        XCTAssertEqual(copied.status, .inProgress)
    }

    func testMeasurementHistoryDoesNotOverwriteEarlierRecords() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = makeStudent(in: context)

        let first = BodyMeasurement(measuredAt: Date(timeIntervalSince1970: 100), weightKg: 65.2)
        first.student = student
        context.insert(first)
        let second = BodyMeasurement(measuredAt: Date(timeIntervalSince1970: 200), weightKg: 62.4)
        second.student = student
        context.insert(second)
        try context.save()

        XCTAssertEqual(student.sortedMeasurements.count, 2)
        XCTAssertEqual(student.latestMeasurement?.weightKg, 62.4)
        XCTAssertEqual(student.sortedMeasurements.first?.weightKg, 65.2)
    }

    private func makeStudent(in context: ModelContext) -> Student {
        let student = Student(
            name: "小林",
            gender: .female,
            age: 29,
            fitnessLevel: .intermediate,
            weightKg: 62,
            heightCm: 168,
            totalPurchasedSessions: 10
        )
        context.insert(student)
        return student
    }

    private func makeSession(for student: Student, in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(title: "下肢力量", status: .inProgress)
        session.student = student
        context.insert(session)

        let exercise = ExerciseEntry(
            name: "高脚杯深蹲",
            category: .strength,
            plannedSets: 1,
            plannedReps: 10,
            plannedRestSeconds: 75,
            plannedDurationMinutes: 8
        )
        exercise.session = session
        context.insert(exercise)

        let set = WorkoutSet(
            sortIndex: 0,
            plannedWeightKg: 20,
            plannedReps: 10,
            actualWeightKg: 20,
            actualReps: 10
        )
        set.exercise = exercise
        context.insert(set)
        return session
    }
}
