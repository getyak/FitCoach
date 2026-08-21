import SwiftUI
import SwiftData

@main
struct FitCoachApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-uiTestAX5") {
                RootView()
                    .dynamicTypeSize(.accessibility5)
                    .environmentObject(LocalizationManager.shared)
            } else {
                RootView()
                    .environmentObject(LocalizationManager.shared)
            }
        }
        .modelContainer(for: [
            Student.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            WorkoutSet.self,
            BodyMeasurement.self,
            CreditTransaction.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            MigrationMarker.self
        ])
    }
}
