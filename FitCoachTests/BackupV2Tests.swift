import XCTest
import SwiftData
@testable import FitCoach

@MainActor
final class BackupV2Tests: XCTestCase {
    func testRoundTripPreservesSetsMeasurementsTemplatesAndLedger() throws {
        let sourceContainer = try makeContainer()
        let source = sourceContainer.mainContext
        let student = Student(name: "林悦", gender: .female, age: 29, fitnessLevel: .intermediate, weightKg: 62.4, heightCm: 168, safetyNotes: "右膝", totalPurchasedSessions: 10)
        source.insert(student)
        try SessionService(context: source).createOpeningBalance(for: student, amount: 10)

        let measurement = BodyMeasurement(weightKg: 62.4, bodyFatPercentage: 23.1, waistCm: 71)
        measurement.student = student
        source.insert(measurement)

        let session = WorkoutSession(title: "下肢力量", status: .inProgress)
        session.student = student
        source.insert(session)
        let exercise = ExerciseEntry(name: "深蹲", category: .strength, sortIndex: 0, plannedSets: 1, plannedReps: 8, plannedRestSeconds: 90, plannedDurationMinutes: 10)
        exercise.session = session
        source.insert(exercise)
        let set = WorkoutSet(sortIndex: 0, plannedWeightKg: 60, plannedReps: 8, actualWeightKg: 62.5, actualReps: 8, rpe: 8.5, notes: "稳定", isCompleted: true)
        set.exercise = exercise
        source.insert(set)
        try SessionService(context: source).complete(session)

        let template = WorkoutTemplate(name: "下肢 A")
        source.insert(template)
        let templateExercise = TemplateExercise(sortIndex: 0, name: "深蹲", category: .strength, setsCount: 3, reps: 8, weightKg: 60, restSeconds: 90, targetRPE: 8)
        templateExercise.template = template
        source.insert(templateExercise)
        try source.save()

        let data = try BackupV2Service.encode(students: [student], templates: [template])
        let archive = try BackupV2Service.decode(data)
        let destinationContainer = try makeContainer()
        let destination = destinationContainer.mainContext
        let result = try BackupV2Service.insert(archive, into: destination)

        XCTAssertEqual(result, BackupImportResult(importedStudents: 1, skippedStudents: 0))
        let imported = try XCTUnwrap(try destination.fetch(FetchDescriptor<Student>()).first)
        XCTAssertEqual(imported.remainingSessions, 9)
        XCTAssertEqual(imported.measurements.first?.waistCm, 71)
        XCTAssertEqual(imported.workoutSessions.first?.exercises.first?.sets.first?.rpe, 8.5)
        XCTAssertEqual(try destination.fetch(FetchDescriptor<WorkoutTemplate>()).first?.exercises.count, 1)

        let duplicate = try BackupV2Service.insert(archive, into: destination)
        XCTAssertEqual(duplicate, BackupImportResult(importedStudents: 0, skippedStudents: 1))
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<Student>()), 1)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<CreditTransaction>()), 2)
    }

    func testRoundTripPreservesLegacyCardioActuals() throws {
        let sourceContainer = try makeContainer()
        let source = sourceContainer.mainContext
        let student = Student(name: "周教练", gender: .other, age: 31, fitnessLevel: .advanced, weightKg: 68, heightCm: 172)
        source.insert(student)
        let session = WorkoutSession(title: "有氧", status: .completed, consumesCredit: false)
        session.student = student
        source.insert(session)
        let cardio = ExerciseEntry(name: "跑步", category: .cardio, cardioIntensity: .moderate, plannedDurationMinutes: 30)
        cardio.actualDurationMinutes = 28
        cardio.isCompleted = true
        cardio.session = session
        source.insert(cardio)
        try source.save()

        let archive = try BackupV2Service.decode(BackupV2Service.encode(students: [student], templates: []))
        let destinationContainer = try makeContainer()
        let destination = destinationContainer.mainContext
        _ = try BackupV2Service.insert(archive, into: destination)
        let imported = try XCTUnwrap(try destination.fetch(FetchDescriptor<ExerciseEntry>()).first)

        XCTAssertEqual(imported.actualDurationMinutes, 28)
        XCTAssertTrue(imported.isCompleted)
        XCTAssertEqual(imported.cardioIntensityEnum, .moderate)
    }

    func testLegacyImportRestoresCompletedStatusSetsAndCredits() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let exercise = ExerciseEntryBackup(
            name: "深蹲", category: ExerciseCategory.strength.rawValue, cardioIntensity: nil,
            plannedSets: 3, plannedReps: 8, plannedRestSeconds: 90, plannedDurationMinutes: 10,
            actualSets: 2, actualReps: 8, actualRestSeconds: 90, actualDurationMinutes: 9,
            isCompleted: true
        )
        let backup = StudentBackup(
            name: "旧学员", gender: Gender.female.rawValue, age: 28,
            fitnessLevel: FitnessLevel.intermediate.rawValue, weightKg: 60, heightCm: 165,
            bodyFatPercentage: nil, hipCm: nil, chestCm: nil, waistCm: nil,
            fitnessGoal: "", notes: "", isOwner: false, totalPurchasedSessions: 10,
            workoutSessions: [WorkoutSessionBackup(date: Date(), title: "旧训练", exercises: [exercise])]
        )

        insertBackupStudent(backup, into: context)
        try context.save()

        let student = try XCTUnwrap(try context.fetch(FetchDescriptor<Student>()).first)
        let session = try XCTUnwrap(student.workoutSessions.first)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.exercises.first?.sets.filter(\.isCompleted).count, 2)
        XCTAssertEqual(student.remainingSessions, 9)
        XCTAssertEqual(student.measurements.count, 1)
        XCTAssertEqual(student.measurements.first?.weightKg, 60)
    }

    func testSameLegacyBackupImportedTwiceIsNoOp() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let backup = StudentBackup(
            name: "旧学员", gender: Gender.female.rawValue, age: 28,
            fitnessLevel: FitnessLevel.intermediate.rawValue, weightKg: 60, heightCm: 165,
            bodyFatPercentage: 22, hipCm: nil, chestCm: nil, waistCm: 70,
            fitnessGoal: "恢复训练", notes: "", isOwner: false, totalPurchasedSessions: 8,
            workoutSessions: []
        )
        let payload = BackupPayload(exportedAt: Date(timeIntervalSince1970: 1_700_000_000), students: [backup])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)

        let first = try LegacyBackupService.insert(payload, sourceData: data, into: context)
        let second = try LegacyBackupService.insert(payload, sourceData: data, into: context)

        XCTAssertEqual(first, LegacyBackupImportResult(importedStudents: 1, skippedStudents: 0))
        XCTAssertEqual(second, LegacyBackupImportResult(importedStudents: 0, skippedStudents: 1))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Student>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BodyMeasurement>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CreditTransaction>()), 1)
    }

    func testImportCompletesExistingStudentInsteadOfSkippingChildren() throws {
        let sourceContainer = try makeContainer()
        let source = sourceContainer.mainContext
        let sourceStudent = Student(name: "同一学员", gender: .female, age: 28, fitnessLevel: .intermediate, weightKg: 61, heightCm: 166, totalPurchasedSessions: 6)
        source.insert(sourceStudent)
        let measurement = BodyMeasurement(weightKg: 61)
        measurement.student = sourceStudent
        source.insert(measurement)
        let session = WorkoutSession(title: "补全训练", status: .planned)
        session.student = sourceStudent
        source.insert(session)
        try source.save()
        let archive = try BackupV2Service.decode(BackupV2Service.encode(students: [sourceStudent], templates: []))

        let destinationContainer = try makeContainer()
        let destination = destinationContainer.mainContext
        let existing = Student(name: "本地名称", gender: .female, age: 28, fitnessLevel: .intermediate, weightKg: 61, heightCm: 166, totalPurchasedSessions: 6)
        existing.id = sourceStudent.id
        destination.insert(existing)
        try destination.save()

        let result = try BackupV2Service.insert(archive, into: destination)

        XCTAssertEqual(result, BackupImportResult(importedStudents: 0, skippedStudents: 1))
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<Student>()), 1)
        XCTAssertEqual(existing.measurements.count, 1)
        XCTAssertEqual(existing.workoutSessions.count, 1)
    }

    func testImportDeepMergesMissingSetsIntoExistingSession() throws {
        let sourceContainer = try makeContainer()
        let source = sourceContainer.mainContext
        let sourceStudent = Student(name: "深合并", gender: .other, age: 30, fitnessLevel: .intermediate, weightKg: 70, heightCm: 175)
        source.insert(sourceStudent)
        let sourceSession = WorkoutSession(title: "已有课程", status: .inProgress)
        sourceSession.student = sourceStudent
        source.insert(sourceSession)
        let sourceExercise = ExerciseEntry(name: "深蹲", category: .strength, plannedSets: 2, plannedReps: 8, plannedDurationMinutes: 10)
        sourceExercise.session = sourceSession
        source.insert(sourceExercise)
        let first = WorkoutSet(sortIndex: 0, actualWeightKg: 60, actualReps: 8)
        first.exercise = sourceExercise
        source.insert(first)
        let second = WorkoutSet(sortIndex: 1, actualWeightKg: 62.5, actualReps: 8)
        second.exercise = sourceExercise
        source.insert(second)
        try source.save()
        let archive = try BackupV2Service.decode(BackupV2Service.encode(students: [sourceStudent], templates: []))

        let destinationContainer = try makeContainer()
        let destination = destinationContainer.mainContext
        let localStudent = Student(name: "本地", gender: .other, age: 30, fitnessLevel: .intermediate, weightKg: 70, heightCm: 175)
        localStudent.id = sourceStudent.id
        destination.insert(localStudent)
        let localSession = WorkoutSession(title: "本地课程", status: .inProgress)
        localSession.id = sourceSession.id
        localSession.student = localStudent
        destination.insert(localSession)
        let localExercise = ExerciseEntry(name: "本地深蹲", category: .strength, plannedSets: 2, plannedReps: 8, plannedDurationMinutes: 10)
        localExercise.id = sourceExercise.id
        localExercise.session = localSession
        destination.insert(localExercise)
        let localFirst = WorkoutSet(id: first.id, sortIndex: 0, actualWeightKg: 55, actualReps: 8)
        localFirst.exercise = localExercise
        destination.insert(localFirst)
        try destination.save()

        _ = try BackupV2Service.insert(archive, into: destination)

        XCTAssertEqual(localSession.exercises.count, 1)
        XCTAssertEqual(localExercise.sets.count, 2)
        XCTAssertEqual(localExercise.sortedSets.first?.actualWeightKg, 55, "已有本地值应保留")
        XCTAssertEqual(localExercise.sortedSets.last?.actualWeightKg, 62.5)
    }

    func testMalformedArchiveDuplicateSetIDDoesNotCreateDuplicateRows() throws {
        let sourceContainer = try makeContainer()
        let source = sourceContainer.mainContext
        let student = Student(name: "重复组", gender: .other, age: 30, fitnessLevel: .intermediate, weightKg: 70, heightCm: 175)
        source.insert(student)
        let session = WorkoutSession(title: "导入测试", status: .planned)
        session.student = student
        source.insert(session)
        let exercise = ExerciseEntry(name: "深蹲", category: .strength, plannedSets: 1, plannedReps: 8, plannedDurationMinutes: 10)
        exercise.session = session
        source.insert(exercise)
        let set = WorkoutSet(sortIndex: 0, actualWeightKg: 60, actualReps: 8)
        set.exercise = exercise
        source.insert(set)
        try source.save()

        var archive = try BackupV2Service.decode(BackupV2Service.encode(students: [student], templates: []))
        let duplicate = try XCTUnwrap(archive.students.first?.sessions.first?.exercises.first?.sets.first)
        archive.students[0].sessions[0].exercises[0].sets.append(duplicate)

        let destinationContainer = try makeContainer()
        let destination = destinationContainer.mainContext
        _ = try BackupV2Service.insert(archive, into: destination)

        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<WorkoutSet>()), 1)
    }

    func testRoundTripPreservesPausedCreditTrackingIntent() throws {
        let sourceContainer = try makeContainer()
        let source = sourceContainer.mainContext
        let student = Student(name: "暂停课时", gender: .other, age: 35, fitnessLevel: .intermediate, weightKg: 72, heightCm: 176, totalPurchasedSessions: 8)
        source.insert(student)
        try SessionService(context: source).createOpeningBalance(for: student, amount: 8)
        student.tracksCredits = false
        try source.save()

        let archive = try BackupV2Service.decode(BackupV2Service.encode(students: [student], templates: []))
        let destinationContainer = try makeContainer()
        let destination = destinationContainer.mainContext
        _ = try BackupV2Service.insert(archive, into: destination)
        let imported = try XCTUnwrap(try destination.fetch(FetchDescriptor<Student>()).first)

        XCTAssertFalse(imported.tracksCredits)
        XCTAssertNil(imported.remainingSessions)
        XCTAssertEqual(imported.creditTransactions.reduce(0) { $0 + $1.amount }, 8)
    }

    private func makeContainer() throws -> ModelContainer {
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
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
