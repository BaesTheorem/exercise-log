import SwiftUI
import UserNotifications

@main
struct ExerciseLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = LogStore()
    @StateObject private var timer = RestTimer()
    @StateObject private var quest = QuestTimer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(timer)
                .environmentObject(quest)
                .tint(RS.yellow)
                .preferredColorScheme(.dark)
                .onAppear { store.sync() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.sync() }
            if phase == .background { store.push() }
        }
    }
}

/// Shows the rest-over banner even when the app is in front, so a glance at
/// the top of the screen answers "was that mine" without opening anything.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        RSAppearance.install()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
