import SwiftUI
import SwiftData

@main
struct FitCoachApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(LocalizationManager.shared)
        }
        .modelContainer(for: [
            Student.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            WorkoutSet.self,
            BodyMeasurement.self,
            CreditTransaction.self,
            WorkoutTemplate.self,
            TemplateExercise.self
        ])
    }
}
