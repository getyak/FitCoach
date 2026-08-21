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
            MigrationMarker.self,
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

    func testUntrackedStudentNeverGetsNegativeCreditLedger() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = Student(name: "阿青", gender: .other, age: 30, fitnessLevel: .beginner, weightKg: 70, heightCm: 175)
        context.insert(student)
        let session = makeSession(for: student, in: context)

        try SessionService(context: context).complete(session)

        XCTAssertNil(student.remainingSessions)
        XCTAssertTrue(student.creditTransactions.isEmpty)
    }

    func testPausingCreditTrackingPreservesLedgerAndPreventsNewDebit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = makeStudent(in: context)
        let service = SessionService(context: context)
        try service.createOpeningBalance(for: student, amount: 10)
        let existingBalance = student.creditTransactions.reduce(0) { $0 + $1.amount }
        student.tracksCredits = false
        try context.save()

        try service.complete(makeSession(for: student, in: context))

        XCTAssertNil(student.remainingSessions)
        XCTAssertEqual(student.creditTransactions.reduce(0) { $0 + $1.amount }, existingBalance)
        XCTAssertEqual(student.creditTransactions.filter { $0.kind == .consume }.count, 0)

        student.tracksCredits = true
        try context.save()
        XCTAssertEqual(student.remainingSessions, 10)
    }

    func testRenewalCreatesLedgerTransactionAndChangesBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = makeStudent(in: context)
        let service = SessionService(context: context)
        try service.createOpeningBalance(for: student, amount: 10)

        try service.adjustPurchasedCredits(for: student, newTotal: 20)

        XCTAssertEqual(student.remainingSessions, 20)
        XCTAssertEqual(student.creditTransactions.filter { $0.kind == .purchase }.map(\.amount), [10])
    }

    func testCannotCompleteWithoutRecordedWork() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = makeStudent(in: context)
        let session = makeSession(for: student, in: context, completed: false)

        XCTAssertThrowsError(try SessionService(context: context).complete(session)) { error in
            XCTAssertEqual(error as? SessionServiceError, .noCompletedWork)
        }
        XCTAssertEqual(session.status, .inProgress)
        XCTAssertTrue(student.creditTransactions.isEmpty)
    }

    func testCancelledAndPlannedSessionsRejectTrainingMutations() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = makeStudent(in: context)
        let service = SessionService(context: context)
        let planned = makeSession(for: student, in: context)
        planned.status = .planned
        let plannedSet = try XCTUnwrap(planned.exercises.first?.sets.first)

        XCTAssertThrowsError(try service.complete(planned)) { error in
            XCTAssertEqual(error as? SessionServiceError, .invalidState)
        }
        XCTAssertThrowsError(try service.completeSet(plannedSet, in: planned, restSeconds: 60)) { error in
            XCTAssertEqual(error as? SessionServiceError, .invalidState)
        }

        planned.status = .cancelled
        XCTAssertThrowsError(try service.complete(planned)) { error in
            XCTAssertEqual(error as? SessionServiceError, .invalidState)
        }
        XCTAssertThrowsError(try service.undoSet(plannedSet, in: planned)) { error in
            XCTAssertEqual(error as? SessionServiceError, .invalidState)
        }
        XCTAssertTrue(student.creditTransactions.isEmpty)
    }

    func testLegacyBackfillIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let student = makeStudent(in: context)
        let session = WorkoutSession(title: "旧训练", status: .planned)
        session.statusCode = nil
        session.student = student
        context.insert(session)
        let exercise = ExerciseEntry(name: "深蹲", category: .strength, plannedSets: 3, plannedReps: 8, plannedRestSeconds: 60, plannedDurationMinutes: 10)
        exercise.actualSets = 2
        exercise.actualReps = 8
        exercise.isCompleted = true
        exercise.session = session
        context.insert(exercise)
        try context.save()

        try LegacyDataBackfill.run(in: context)
        try LegacyDataBackfill.run(in: context)

        XCTAssertEqual(exercise.sets.count, 3)
        XCTAssertEqual(exercise.sets.filter(\.isCompleted).count, 2)
        XCTAssertEqual(student.measurements.count, 1)
        XCTAssertEqual(student.creditTransactions.filter { $0.kind == .openingBalance }.count, 1)
        XCTAssertEqual(student.creditTransactions.filter { $0.kind == .consume }.count, 1)
        XCTAssertEqual(student.remainingSessions, 9)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MigrationMarker>()), 2)
    }

    func testUUIDRepairRunsEvenWhenLegacyBackfillMarkerAlreadyExists() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let duplicateID = UUID()
        let first = makeStudent(in: context)
        first.id = duplicateID
        let second = makeStudent(in: context)
        second.name = "第二位"
        second.id = duplicateID
        let firstSession = WorkoutSession(title: "第一节", status: .completed)
        firstSession.id = duplicateID
        firstSession.student = first
        context.insert(firstSession)
        let secondSession = WorkoutSession(title: "第二节", status: .completed)
        secondSession.id = duplicateID
        secondSession.student = second
        context.insert(secondSession)
        for (index, session) in [firstSession, secondSession].enumerated() {
            let transaction = CreditTransaction(
                idempotencyKey: "pre-repair-\(index)",
                amount: -1,
                kind: .consume,
                sessionIDSnapshot: duplicateID
            )
            transaction.student = session.student
            transaction.session = session
            context.insert(transaction)
        }
        context.insert(MigrationMarker(key: "legacy-v3-backfill"))
        try context.save()

        try LegacyDataBackfill.run(in: context)
        try LegacyDataBackfill.run(in: context)

        XCTAssertEqual(Set([first.id, second.id]).count, 2)
        XCTAssertEqual(Set([firstSession.id, secondSession.id]).count, 2)
        XCTAssertTrue(firstSession.creditTransactions.allSatisfy { $0.sessionIDSnapshot == firstSession.id })
        XCTAssertTrue(secondSession.creditTransactions.allSatisfy { $0.sessionIDSnapshot == secondSession.id })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MigrationMarker>()), 2)
    }

    func testFileBackedStoreReopensWithoutRepeatingBackfill() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FitCoach-reopen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("FitCoach.store")
        var expectedStudentID: UUID?

        do {
            let container = try makeFileContainer(at: storeURL)
            let context = container.mainContext
            let student = makeStudent(in: context)
            expectedStudentID = student.id
            let session = WorkoutSession(title: "旧训练", status: .planned)
            session.statusCode = nil
            session.student = student
            context.insert(session)
            let exercise = ExerciseEntry(name: "深蹲", category: .strength, plannedSets: 2, plannedReps: 8, plannedDurationMinutes: 10)
            exercise.actualSets = 1
            exercise.actualReps = 8
            exercise.isCompleted = true
            exercise.session = session
            context.insert(exercise)
            try context.save()
            try LegacyDataBackfill.run(in: context)

            XCTAssertEqual(exercise.sets.count, 2)
            XCTAssertEqual(student.creditTransactions.count, 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MigrationMarker>()), 2)
        }

        do {
            let container = try makeFileContainer(at: storeURL)
            let context = container.mainContext
            try LegacyDataBackfill.run(in: context)

            let students = try context.fetch(FetchDescriptor<Student>())
            XCTAssertEqual(students.count, 1)
            XCTAssertEqual(students.first?.id, expectedStudentID)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSet>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<CreditTransaction>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MigrationMarker>()), 2)
        }
    }

    func testExactV1StoreMigratesBackfillsAndReopensIdempotently() throws {
        let sourceURL = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "FitCoachV1", withExtension: "store"),
            "Exact V1 fixture must be copied into the test bundle"
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FitCoach-v1-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("FitCoach.store")
        try FileManager.default.copyItem(at: sourceURL, to: storeURL)

        var studentIDs = Set<UUID>()
        var sessionIDs = Set<UUID>()
        var exerciseIDs = Set<UUID>()

        do {
            let container = try makeFileContainer(at: storeURL)
            let context = container.mainContext
            try LegacyDataBackfill.run(in: context)

            let students = try context.fetch(FetchDescriptor<Student>())
            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let exercises = try context.fetch(FetchDescriptor<ExerciseEntry>())
            studentIDs = Set(students.map(\.id))
            sessionIDs = Set(sessions.map(\.id))
            exerciseIDs = Set(exercises.map(\.id))

            XCTAssertEqual(students.count, 3)
            XCTAssertEqual(sessions.count, 3)
            XCTAssertEqual(exercises.count, 4)
            XCTAssertEqual(studentIDs.count, 3, "Every migrated legacy student needs a stable unique UUID")
            XCTAssertEqual(sessionIDs.count, 3, "Every migrated legacy session needs a stable unique UUID")
            XCTAssertEqual(exerciseIDs.count, 4, "Every migrated legacy exercise needs a stable unique UUID")
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSet>()), 9)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<BodyMeasurement>()), 3)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MigrationMarker>()), 2)

            let tracked = try XCTUnwrap(students.first { $0.name == "旧版林悦" })
            XCTAssertTrue(tracked.tracksCredits)
            XCTAssertEqual(tracked.remainingSessions, 11)
            XCTAssertEqual(tracked.creditTransactions.filter { $0.kind == .openingBalance }.count, 1)
            XCTAssertEqual(tracked.creditTransactions.filter { $0.kind == .consume }.count, 1)
            XCTAssertEqual(tracked.workoutSessions.filter { $0.status == .completed }.count, 1)
            XCTAssertEqual(tracked.workoutSessions.filter { $0.status == .planned }.count, 1)

            let untracked = try XCTUnwrap(students.first { $0.name == "旧版陈屿" })
            XCTAssertFalse(untracked.tracksCredits)
            XCTAssertTrue(untracked.creditTransactions.isEmpty)
        }

        do {
            let container = try makeFileContainer(at: storeURL)
            let context = container.mainContext
            try LegacyDataBackfill.run(in: context)

            XCTAssertEqual(Set(try context.fetch(FetchDescriptor<Student>()).map(\.id)), studentIDs)
            XCTAssertEqual(Set(try context.fetch(FetchDescriptor<WorkoutSession>()).map(\.id)), sessionIDs)
            XCTAssertEqual(Set(try context.fetch(FetchDescriptor<ExerciseEntry>()).map(\.id)), exerciseIDs)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSet>()), 9)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<BodyMeasurement>()), 3)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<CreditTransaction>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MigrationMarker>()), 2)
        }
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

    private func makeFileContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Student.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            WorkoutSet.self,
            BodyMeasurement.self,
            CreditTransaction.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            MigrationMarker.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    private func makeSession(for student: Student, in context: ModelContext, completed: Bool = true) -> WorkoutSession {
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
            actualReps: 10,
            isCompleted: completed,
            completedAt: completed ? Date() : nil
        )
        set.exercise = exercise
        context.insert(set)
        return session
    }
}
