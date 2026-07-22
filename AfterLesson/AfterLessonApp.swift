import SwiftUI
import UserNotifications

// Nimmt das Apple-Gerätetoken entgegen und reicht es an die Cloud
// weiter — mehr Aufgaben hat dieser Delegate nicht.
final class PushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await CloudService.shared.registerDeviceToken(tokenHex) }
    }

    // Banner auch zeigen, wenn die App gerade offen ist
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

@main
struct AfterLessonApp: App {
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var pushDelegate
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
            // Abendgarderobe überall (Test 22.07.): Grünbuch erscheint
            // immer dunkel, Gold als Akzentfarbe — eine Zeile, jederzeit
            // rückgängig zu machen.
            .preferredColorScheme(.dark)
            .tint(ALColor.goldHell)
            .animation(.easeOut(duration: 0.25), value: isUnlocked)
            .onAppear {
                if store.lockEnabled {
                    isUnlocked = !store.isLocked
                } else {
                    isUnlocked = true
                }
                // Angemeldete Nutzer (Pro wie Schüler) für Push registrieren
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    CloudService.shared.enablePushIfPossible()
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
        case "gruenbuchbackup":
            store.pendingBackupURL = url
        case "gruenbuchnotiz":
            _ = store.importNote(from: url)
        default:
            break
        }
    }
}
