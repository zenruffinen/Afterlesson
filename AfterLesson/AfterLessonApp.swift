import SwiftUI

@main
struct AfterLessonApp: App {
    @StateObject private var store = AppStore()
    @AppStorage("hasSelectedMode") var hasSelectedMode: Bool = false

    var body: some Scene {
        WindowGroup {
            if hasSelectedMode {
                ContentView()
                    .environmentObject(store)
            } else {
                OnboardingView(hasSelectedMode: $hasSelectedMode)
                    .environmentObject(store)
            }
        }
    }
}
