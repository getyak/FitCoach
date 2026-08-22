import Foundation
import SwiftData

struct BackupArchiveV2: Codable {
    static let currentFormatVersion = 2

    var formatVersion = currentFormatVersion
    var backupID = UUID()
    var exportedAt = Date()
    var students: [StudentBackupV2]
    var templates: [TemplateBackupV2]

    init(students: [Student], templates: [WorkoutTemplate]) {
        self.students = students.map(StudentBackupV2.init)
        self.templates = templates.map(TemplateBackupV2.init)
    }
}

struct StudentBackupV2: Codable {
    var id: UUID
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
    var safetyNotes: String
    var createdDate: Date
    var isOwner: Bool
    var totalPurchasedSessions: Int?
    var tracksCredits: Bool?
    var sessions: [SessionBackupV2]
    var measurements: [MeasurementBackupV2]
    var credits: [CreditBackupV2]

    init(_ student: Student) {
        id = student.id
        name = student.name
        gender = student.gender
        age = student.age
        fitnessLevel = student.fitnessLevel
        weightKg = student.weightKg
        heightCm = student.heightCm
        bodyFatPercentage = student.bodyFatPercentage
        hipCm = student.hipCm
        chestCm = student.chestCm
        waistCm = student.waistCm
        fitnessGoal = student.fitnessGoal
        notes = student.notes
        safetyNotes = student.safetyNotes
        createdDate = student.createdDate
        isOwner = student.isOwner
        totalPurchasedSessions = student.totalPurchasedSessions
        tracksCredits = student.tracksCredits
        sessions = student.workoutSessions.map(SessionBackupV2.init)
        measurements = student.measurements.map(MeasurementBackupV2.init)
        credits = student.creditTransactions.map(CreditBackupV2.init)
    }
}

struct SessionBackupV2: Codable {
    var id: UUID
    var date: Date
    var title: String
    var statusCode: String?
    var startedAt: Date?
    var completedAt: Date?
    var summary: String
    var consumesCredit: Bool
    var completionEpoch: Int
    var activeExerciseIndex: Int
    var restEndsAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var exercises: [ExerciseBackupV2]

    init(_ session: WorkoutSession) {
        id = session.id
        date = session.date
        title = session.title
        statusCode = session.statusCode
        startedAt = session.startedAt
        completedAt = session.completedAt
        summary = session.summary
        consumesCredit = session.consumesCredit
        completionEpoch = session.completionEpoch
        activeExerciseIndex = session.activeExerciseIndex
        restEndsAt = session.restEndsAt
        createdAt = session.createdAt
        updatedAt = session.updatedAt
        exercises = session.sortedExercises.map(ExerciseBackupV2.init)
    }
}

struct ExerciseBackupV2: Codable {
    var id: UUID
    var sortIndex: Int
    var name: String
    var category: String
    var cardioIntensity: String?
    var plannedSets: Int
    var plannedReps: Int
    var plannedRestSeconds: Int
    var plannedDurationMinutes: Double
    var notes: String
    var targetRPE: Double?
    var actualSets: Int?
    var actualReps: Int?
    var actualRestSeconds: Int?
    var actualDurationMinutes: Double?
    var isCompleted: Bool?
    var sets: [SetBackupV2]

    init(_ exercise: ExerciseEntry) {
        id = exercise.id
        sortIndex = exercise.sortIndex
        name = exercise.name
        category = exercise.category
        cardioIntensity = exercise.cardioIntensity
        plannedSets = exercise.plannedSets
        plannedReps = exercise.plannedReps
        plannedRestSeconds = exercise.plannedRestSeconds
        plannedDurationMinutes = exercise.plannedDurationMinutes
        notes = exercise.notes
        targetRPE = exercise.targetRPE
        actualSets = exercise.actualSets
        actualReps = exercise.actualReps
        actualRestSeconds = exercise.actualRestSeconds
        actualDurationMinutes = exercise.actualDurationMinutes
        isCompleted = exercise.isCompleted
        sets = exercise.sortedSets.map(SetBackupV2.init)
    }
}

struct SetBackupV2: Codable {
    var id: UUID
    var sortIndex: Int
    var plannedWeightKg: Double?
    var plannedReps: Int?
    var actualWeightKg: Double?
    var actualReps: Int?
    var rpe: Double?
    var notes: String
    var isCompleted: Bool
    var completedAt: Date?

    init(_ set: WorkoutSet) {
        id = set.id
        sortIndex = set.sortIndex
        plannedWeightKg = set.plannedWeightKg
        plannedReps = set.plannedReps
        actualWeightKg = set.actualWeightKg
        actualReps = set.actualReps
        rpe = set.rpe
        notes = set.notes
        isCompleted = set.isCompleted
        completedAt = set.completedAt
    }
}

struct MeasurementBackupV2: Codable {
    var id: UUID
    var measuredAt: Date
    var weightKg: Double?
    var bodyFatPercentage: Double?
    var hipCm: Double?
    var chestCm: Double?
    var waistCm: Double?
    var notes: String

    init(_ value: BodyMeasurement) {
        id = value.id
        measuredAt = value.measuredAt
        weightKg = value.weightKg
        bodyFatPercentage = value.bodyFatPercentage
        hipCm = value.hipCm
        chestCm = value.chestCm
        waistCm = value.waistCm
        notes = value.notes
    }
}

struct CreditBackupV2: Codable {
    var id: UUID
    var idempotencyKey: String
    var amount: Int
    var kindCode: String
    var occurredAt: Date
    var note: String
    var sessionIDSnapshot: UUID?
    var reversesTransactionID: UUID?

    init(_ value: CreditTransaction) {
        id = value.id
        idempotencyKey = value.idempotencyKey
        amount = value.amount
        kindCode = value.kindCode
        occurredAt = value.occurredAt
        note = value.note
        sessionIDSnapshot = value.sessionIDSnapshot
        reversesTransactionID = value.reversesTransactionID
    }
}

struct TemplateBackupV2: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var studentID: UUID?
    var exercises: [TemplateExerciseBackupV2]

    init(_ value: WorkoutTemplate) {
        id = value.id
        name = value.name
        createdAt = value.createdAt
        updatedAt = value.updatedAt
        studentID = value.student?.id
        exercises = value.sortedExercises.map(TemplateExerciseBackupV2.init)
    }
}

struct TemplateExerciseBackupV2: Codable {
    var id: UUID
    var sortIndex: Int
    var name: String
    var categoryCode: String
    var setsCount: Int
    var reps: Int
    var weightKg: Double?
    var restSeconds: Int
    var targetRPE: Double?
    var durationMinutes: Double

    init(_ value: TemplateExercise) {
        id = value.id
        sortIndex = value.sortIndex
        name = value.name
        categoryCode = value.categoryCode
        setsCount = value.setsCount
        reps = value.reps
        weightKg = value.weightKg
        restSeconds = value.restSeconds
        targetRPE = value.targetRPE
        durationMinutes = value.durationMinutes
    }
}

struct BackupImportResult: Equatable {
    var importedStudents: Int
    var skippedStudents: Int
}

private enum BackupValidationError: LocalizedError {
    case duplicateParent(String)
    case conflictingParent(String)
    case invalidReference(String)

    var errorDescription: String? {
        switch self {
        case .duplicateParent(let object):
            "备份中存在重复的\(object)标识，无法安全导入。"
        case .conflictingParent(let object):
            "备份中的\(object)归属与现有数据冲突，未导入任何内容。"
        case .invalidReference(let object):
            "备份中的\(object)引用无效，未导入任何内容。"
        }
    }
}

@MainActor
enum BackupV2Service {
    static func encode(students: [Student], templates: [WorkoutTemplate]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(BackupArchiveV2(students: students, templates: templates))
    }

    static func decode(_ data: Data) throws -> BackupArchiveV2 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(BackupArchiveV2.self, from: data)
        guard archive.formatVersion == BackupArchiveV2.currentFormatVersion else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        return archive
    }

    static func insert(_ archive: BackupArchiveV2, into context: ModelContext) throws -> BackupImportResult {
        let existingStudents = try context.fetch(FetchDescriptor<Student>())
        let existingSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let existingExercises = try context.fetch(FetchDescriptor<ExerciseEntry>())
        let existingSets = try context.fetch(FetchDescriptor<WorkoutSet>())
        let existingMeasurements = try context.fetch(FetchDescriptor<BodyMeasurement>())
        let existingCredits = try context.fetch(FetchDescriptor<CreditTransaction>())
        let existingTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let existingTemplateExercises = try context.fetch(FetchDescriptor<TemplateExercise>())

        try validate(
            archive,
            existingStudents: existingStudents,
            existingSessions: existingSessions,
            existingExercises: existingExercises,
            existingSets: existingSets,
            existingMeasurements: existingMeasurements,
            existingCredits: existingCredits,
            existingTemplates: existingTemplates,
            existingTemplateExercises: existingTemplateExercises
        )

        var studentsByID = Dictionary(uniqueKeysWithValues: existingStudents.map { ($0.id, $0) })
        var sessionsByID = Dictionary(uniqueKeysWithValues: existingSessions.map { ($0.id, $0) })
        var measurementIDs = Set(existingMeasurements.map(\.id))
        var creditIDs = Set(existingCredits.map(\.id))
        var creditKeys = Set(existingCredits.map(\.idempotencyKey))
        var templatesByID = Dictionary(uniqueKeysWithValues: existingTemplates.map { ($0.id, $0) })
        var templateExerciseIDs = Set(existingTemplateExercises.map(\.id))
        var imported = 0
        var skipped = 0
        var importedStudents: [UUID: Student] = [:]
        var importedSessions = sessionsByID

        for backup in archive.students {
            let student: Student
            if let existing = studentsByID[backup.id] {
                student = existing
                skipped += 1
            } else {
                student = Student(
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
                    safetyNotes: backup.safetyNotes,
                    isOwner: backup.isOwner,
                    totalPurchasedSessions: backup.totalPurchasedSessions
                )
                student.id = backup.id
                student.createdDate = backup.createdDate
                if let tracksCredits = backup.tracksCredits {
                    student.tracksCredits = tracksCredits
                }
                context.insert(student)
                studentsByID[student.id] = student
                imported += 1
            }
            importedStudents[student.id] = student

            for item in backup.measurements where !measurementIDs.contains(item.id) {
                let measurement = BodyMeasurement(id: item.id, measuredAt: item.measuredAt, weightKg: item.weightKg, bodyFatPercentage: item.bodyFatPercentage, hipCm: item.hipCm, chestCm: item.chestCm, waistCm: item.waistCm, notes: item.notes)
                measurement.student = student
                context.insert(measurement)
                measurementIDs.insert(item.id)
            }
            for item in backup.sessions {
                if let existing = sessionsByID[item.id] {
                    mergeMissingExercises(item.exercises, into: existing, context: context)
                } else {
                    let session = WorkoutSession(date: item.date, title: item.title, status: item.statusCode.flatMap(WorkoutSessionStatus.init(rawValue:)) ?? .planned, consumesCredit: item.consumesCredit)
                    session.id = item.id
                    session.startedAt = item.startedAt
                    session.completedAt = item.completedAt
                    session.summary = item.summary
                    session.completionEpoch = item.completionEpoch
                    session.activeExerciseIndex = item.activeExerciseIndex
                    session.restEndsAt = item.restEndsAt
                    session.createdAt = item.createdAt
                    session.updatedAt = item.updatedAt
                    session.student = student
                    context.insert(session)
                    importedSessions[session.id] = session
                    sessionsByID[session.id] = session
                    insertExercises(item.exercises, into: session, context: context)
                }
            }
            for item in backup.credits where !creditIDs.contains(item.id) && !creditKeys.contains(item.idempotencyKey) {
                let credit = CreditTransaction(id: item.id, idempotencyKey: item.idempotencyKey, amount: item.amount, kind: CreditTransactionKind(rawValue: item.kindCode) ?? .adjustment, occurredAt: item.occurredAt, note: item.note, sessionIDSnapshot: item.sessionIDSnapshot, reversesTransactionID: item.reversesTransactionID)
                credit.student = student
                credit.session = item.sessionIDSnapshot.flatMap { importedSessions[$0] }
                context.insert(credit)
                creditIDs.insert(item.id)
                creditKeys.insert(item.idempotencyKey)
            }
        }

        for item in archive.templates {
            let template: WorkoutTemplate
            if let existing = templatesByID[item.id] {
                template = existing
            } else {
                template = WorkoutTemplate(id: item.id, name: item.name, createdAt: item.createdAt)
                template.updatedAt = item.updatedAt
                template.student = item.studentID.flatMap { importedStudents[$0] ?? studentsByID[$0] }
                context.insert(template)
                templatesByID[item.id] = template
            }
            for exerciseItem in item.exercises where !templateExerciseIDs.contains(exerciseItem.id) {
                let exercise = TemplateExercise(id: exerciseItem.id, sortIndex: exerciseItem.sortIndex, name: exerciseItem.name, category: ExerciseCategory(rawValue: exerciseItem.categoryCode) ?? .strength, setsCount: exerciseItem.setsCount, reps: exerciseItem.reps, weightKg: exerciseItem.weightKg, restSeconds: exerciseItem.restSeconds, targetRPE: exerciseItem.targetRPE, durationMinutes: exerciseItem.durationMinutes)
                exercise.template = template
                context.insert(exercise)
                templateExerciseIDs.insert(exerciseItem.id)
            }
        }

        do {
            try context.save()
            return BackupImportResult(importedStudents: imported, skippedStudents: skipped)
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func validate(
        _ archive: BackupArchiveV2,
        existingStudents: [Student],
        existingSessions: [WorkoutSession],
        existingExercises: [ExerciseEntry],
        existingSets: [WorkoutSet],
        existingMeasurements: [BodyMeasurement],
        existingCredits: [CreditTransaction],
        existingTemplates: [WorkoutTemplate],
        existingTemplateExercises: [TemplateExercise]
    ) throws {
        let existingStudentIDs = Set(existingStudents.map(\.id))
        let archiveStudentIDs = Set(archive.students.map(\.id))
        guard archiveStudentIDs.count == archive.students.count else {
            throw BackupValidationError.duplicateParent("学员")
        }
        let knownStudentIDs = existingStudentIDs.union(archiveStudentIDs)

        let existingSessionsByID = Dictionary(uniqueKeysWithValues: existingSessions.map { ($0.id, $0) })
        let existingExercisesByID = Dictionary(uniqueKeysWithValues: existingExercises.map { ($0.id, $0) })
        let existingSetsByID = Dictionary(uniqueKeysWithValues: existingSets.map { ($0.id, $0) })
        let existingMeasurementsByID = Dictionary(uniqueKeysWithValues: existingMeasurements.map { ($0.id, $0) })
        let existingCreditsByID = Dictionary(uniqueKeysWithValues: existingCredits.map { ($0.id, $0) })
        let existingTemplatesByID = Dictionary(uniqueKeysWithValues: existingTemplates.map { ($0.id, $0) })
        let existingTemplateExercisesByID = Dictionary(uniqueKeysWithValues: existingTemplateExercises.map { ($0.id, $0) })

        var sessionOwners: [UUID: UUID] = [:]
        var exerciseOwners: [UUID: UUID] = [:]
        var setOwners: [UUID: UUID] = [:]
        var measurementOwners: [UUID: UUID] = [:]
        var creditOwners: [UUID: UUID] = [:]
        var templateExerciseOwners: [UUID: UUID] = [:]

        for student in archive.students {
            for measurement in student.measurements {
                try register(measurement.id, parent: student.id, as: "体测记录", in: &measurementOwners)
                if let existing = existingMeasurementsByID[measurement.id], existing.student?.id != student.id {
                    throw BackupValidationError.conflictingParent("体测记录")
                }
            }

            for session in student.sessions {
                try register(session.id, parent: student.id, as: "训练课程", in: &sessionOwners)
                if let existing = existingSessionsByID[session.id], existing.student?.id != student.id {
                    throw BackupValidationError.conflictingParent("训练课程")
                }
                for exercise in session.exercises {
                    try register(exercise.id, parent: session.id, as: "训练动作", in: &exerciseOwners)
                    if let existing = existingExercisesByID[exercise.id], existing.session?.id != session.id {
                        throw BackupValidationError.conflictingParent("训练动作")
                    }
                    for set in exercise.sets {
                        try register(set.id, parent: exercise.id, as: "训练组", in: &setOwners)
                        if let existing = existingSetsByID[set.id], existing.exercise?.id != exercise.id {
                            throw BackupValidationError.conflictingParent("训练组")
                        }
                    }
                }
            }

            for credit in student.credits {
                try register(credit.id, parent: student.id, as: "课时流水", in: &creditOwners)
                if let existing = existingCreditsByID[credit.id], existing.student?.id != student.id {
                    throw BackupValidationError.conflictingParent("课时流水")
                }
                if let sessionID = credit.sessionIDSnapshot {
                    let archiveOwner = sessionOwners[sessionID]
                    let existingOwner = existingSessionsByID[sessionID]?.student?.id
                    if let owner = archiveOwner ?? existingOwner, owner != student.id {
                        throw BackupValidationError.conflictingParent("课时流水课程")
                    }
                }
            }
        }

        // Credits can precede the referenced session's student in archive order,
        // so validate the finished ownership graph in a second pass.
        for student in archive.students {
            for credit in student.credits {
                guard let sessionID = credit.sessionIDSnapshot else { continue }
                let archiveOwner = sessionOwners[sessionID]
                let existingOwner = existingSessionsByID[sessionID]?.student?.id
                if let owner = archiveOwner ?? existingOwner, owner != student.id {
                    throw BackupValidationError.conflictingParent("课时流水课程")
                }
            }
        }

        let archiveTemplateIDs = Set(archive.templates.map(\.id))
        guard archiveTemplateIDs.count == archive.templates.count else {
            throw BackupValidationError.duplicateParent("训练模板")
        }
        for template in archive.templates {
            if let studentID = template.studentID, !knownStudentIDs.contains(studentID) {
                throw BackupValidationError.invalidReference("模板学员")
            }
            if let existing = existingTemplatesByID[template.id],
               let archivedStudentID = template.studentID,
               let existingStudentID = existing.student?.id,
               existingStudentID != archivedStudentID {
                throw BackupValidationError.conflictingParent("训练模板")
            }
            for exercise in template.exercises {
                try register(exercise.id, parent: template.id, as: "模板动作", in: &templateExerciseOwners)
                if let existing = existingTemplateExercisesByID[exercise.id], existing.template?.id != template.id {
                    throw BackupValidationError.conflictingParent("模板动作")
                }
            }
        }
    }

    private static func register(
        _ id: UUID,
        parent: UUID,
        as object: String,
        in owners: inout [UUID: UUID]
    ) throws {
        if let existingParent = owners[id], existingParent != parent {
            throw BackupValidationError.conflictingParent(object)
        }
        owners[id] = parent
    }

    private static func insertExercises(_ items: [ExerciseBackupV2], into session: WorkoutSession, context: ModelContext) {
        var insertedExerciseIDs = Set<UUID>()
        for item in items {
            guard insertedExerciseIDs.insert(item.id).inserted else { continue }
            let exercise = ExerciseEntry(name: item.name, category: ExerciseCategory(rawValue: item.category) ?? .strength, cardioIntensity: item.cardioIntensity.flatMap(CardioIntensity.init(rawValue:)), sortIndex: item.sortIndex, plannedSets: item.plannedSets, plannedReps: item.plannedReps, plannedRestSeconds: item.plannedRestSeconds, plannedDurationMinutes: item.plannedDurationMinutes)
            exercise.id = item.id
            exercise.notes = item.notes
            exercise.targetRPE = item.targetRPE
            exercise.actualSets = item.actualSets ?? 0
            exercise.actualReps = item.actualReps ?? 0
            exercise.actualRestSeconds = item.actualRestSeconds ?? 0
            exercise.actualDurationMinutes = item.actualDurationMinutes ?? 0
            exercise.isCompleted = item.isCompleted ?? false
            exercise.session = session
            context.insert(exercise)
            var insertedSetIDs = Set<UUID>()
            for setItem in item.sets {
                guard insertedSetIDs.insert(setItem.id).inserted else { continue }
                let set = WorkoutSet(id: setItem.id, sortIndex: setItem.sortIndex, plannedWeightKg: setItem.plannedWeightKg, plannedReps: setItem.plannedReps, actualWeightKg: setItem.actualWeightKg, actualReps: setItem.actualReps, rpe: setItem.rpe, notes: setItem.notes, isCompleted: setItem.isCompleted, completedAt: setItem.completedAt)
                set.exercise = exercise
                context.insert(set)
            }
        }
    }

    /// 导入采用 local-wins：保留本地已有字段，只补齐备份中缺失的动作和组。
    private static func mergeMissingExercises(_ items: [ExerciseBackupV2], into session: WorkoutSession, context: ModelContext) {
        var exercisesByID = Dictionary(uniqueKeysWithValues: session.exercises.map { ($0.id, $0) })
        var insertedExerciseIDs = Set<UUID>()
        for item in items {
            guard let existing = exercisesByID[item.id] else {
                guard insertedExerciseIDs.insert(item.id).inserted else { continue }
                insertExercises([item], into: session, context: context)
                continue
            }

            var existingSetIDs = Set(existing.sets.map(\.id))
            for setItem in item.sets where !existingSetIDs.contains(setItem.id) {
                let set = WorkoutSet(id: setItem.id, sortIndex: setItem.sortIndex, plannedWeightKg: setItem.plannedWeightKg, plannedReps: setItem.plannedReps, actualWeightKg: setItem.actualWeightKg, actualReps: setItem.actualReps, rpe: setItem.rpe, notes: setItem.notes, isCompleted: setItem.isCompleted, completedAt: setItem.completedAt)
                set.exercise = existing
                context.insert(set)
                existingSetIDs.insert(setItem.id)
            }
            exercisesByID[item.id] = existing
        }
    }
}
