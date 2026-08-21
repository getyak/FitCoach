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
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
