import Foundation
import Combine
import UserNotifications
import AudioToolbox
import UIKit

/// The rest countdown between sets.
///
/// Wall-clock based: only the end date is stored, so backgrounding or a
/// locked screen cannot drift it. A local notification is scheduled for the
/// end so the phone buzzes in a pocket; when the app is in front at zero it
/// plays a sound and haptic itself.
@MainActor
final class RestTimer: ObservableObject {
    @Published private(set) var endDate: Date?
    @Published private(set) var label: String = ""
    @Published private(set) var total: Int = 0
    @Published private(set) var now = Date()
    @Published private(set) var justFinished = false

    private var ticker: AnyCancellable?
    private static let notificationID = "rest-timer"

    var isRunning: Bool { endDate != nil }

    var remaining: Int {
        guard let endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
    }

    var progress: Double {
        guard total > 0 else { return 0 }
        return 1 - Double(remaining) / Double(total)
    }

    func start(seconds: Int, label: String) {
        cancelNotification()
        self.label = label
        self.total = seconds
        self.endDate = Date().addingTimeInterval(TimeInterval(seconds))
        self.justFinished = false
        now = Date()
        scheduleNotification(in: seconds)
        ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
            .sink { [weak self] date in self?.tick(date) }
    }

    func add(seconds: Int) {
        guard let endDate else { return }
        let base = max(endDate, Date())
        self.endDate = base.addingTimeInterval(TimeInterval(seconds))
        total += seconds
        cancelNotification()
        scheduleNotification(in: remaining)
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        endDate = nil
        cancelNotification()
    }

    func acknowledge() { justFinished = false }

    private func tick(_ date: Date) {
        now = date
        guard let endDate, date >= endDate else { return }
        ticker?.cancel()
        ticker = nil
        self.endDate = nil
        justFinished = true
        cancelNotification()
        if UIApplication.shared.applicationState == .active {
            AudioServicesPlaySystemSound(1007)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Notifications

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(in seconds: Int) {
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = label.isEmpty ? "Next set." : "Next set of \(label)."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: RestTimer.notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [RestTimer.notificationID])
    }

    static func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
