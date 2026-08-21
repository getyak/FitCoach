import SwiftUI
import SwiftData

@main
struct FitCoachApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(LocalizationManager.shared)
                .fontDesign(.rounded)
        }
        .modelContainer(for: [Student.self, WorkoutSession.self, ExerciseEntry.self])
    }
}
