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
                    .onOpenURL { url in handleIncomingFile(url) }
            } else {
                OnboardingView(hasSelectedMode: $hasSelectedMode)
                    .environmentObject(store)
                    .onOpenURL { url in handleIncomingFile(url) }
            }
        }
    }

    private func handleIncomingFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "afterlessonsession":
            _ = store.importSessionShare(from: url)
        case "afterlesson":
            _ = store.importLesson(from: url)
        default:
            break
        }
    }
}
