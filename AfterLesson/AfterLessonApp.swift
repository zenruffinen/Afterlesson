import SwiftUI

@main
struct AfterLessonApp: App {
    @StateObject private var store = AppStore()
    @AppStorage("hasSelectedMode") var hasSelectedMode: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var isUnlocked = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasSelectedMode {
                    ContentView()
                        .environmentObject(store)
                        .onOpenURL { url in handleIncomingFile(url) }
                } else {
                    OnboardingView(hasSelectedMode: $hasSelectedMode)
                        .environmentObject(store)
                        .onOpenURL { url in handleIncomingFile(url) }
                }

                if hasSelectedMode, store.lockEnabled, !isUnlocked {
                    LockView(isUnlocked: $isUnlocked)
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                        .zIndex(100)
                }
            }
            .animation(.easeOut(duration: 0.25), value: isUnlocked)
            .onAppear {
                if store.lockEnabled {
                    isUnlocked = !store.isLocked
                } else {
                    isUnlocked = true
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard store.lockEnabled else { return }
                if phase == .background || phase == .inactive {
                    isUnlocked = false
                    store.isLocked = true
                }
            }
            .onChange(of: isUnlocked) { _, unlocked in
                store.isLocked = !unlocked
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
        case "afterlessonfeedback":
            _ = store.importFeedbackShare(from: url)
        default:
            break
        }
    }
}
