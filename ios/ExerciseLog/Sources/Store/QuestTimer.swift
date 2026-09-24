import Foundation
import Combine
import UserNotifications
import AVFoundation
import AudioToolbox
import UIKit

/// The interval engine for a quest session.
///
/// Wall-clock based like `RestTimer`: segment boundaries are absolute dates
/// computed once at start, so a locked screen cannot drift them. Three things
/// keep the cues arriving with the phone in a pocket:
///
/// 1. A local notification is scheduled for every boundary (the system fires
///    those whether or not the app is alive).
/// 2. A looped silent track holds the audio session open, which is what lets
///    the ticker keep running in the background (`UIBackgroundModes: audio`).
/// 3. Cues are spoken with `AVSpeechSynthesizer` on that open session, so
///    "Jog" and "Walk" come through headphones over whatever is playing.
@MainActor
final class QuestTimer: ObservableObject {
    struct Boundary { let index: Int; let start: Date; let end: Date }

    @Published private(set) var plan: PlanSession?
    @Published private(set) var sessionID: String?
    @Published private(set) var startDate: Date?
    @Published private(set) var now = Date()
    @Published private(set) var currentIndex = 0
    @Published private(set) var finished = false

    private var boundaries: [Boundary] = []
    private var ticker: AnyCancellable?
    private var silence: AVAudioPlayer?
    private let speaker = AVSpeechSynthesizer()
    private static let notificationPrefix = "quest-"

    /// Called once when the cool-down ends or the run is stopped early.
    var onEnd: ((_ sessionID: String, _ elapsed: Int, _ jogSeconds: Int, _ completed: Bool) -> Void)?

    var isRunning: Bool { plan != nil && !finished }

    var segments: [Segment] { plan?.segments ?? [] }
    var current: Segment? { segments.indices.contains(currentIndex) ? segments[currentIndex] : nil }
    var next: Segment? { segments.indices.contains(currentIndex + 1) ? segments[currentIndex + 1] : nil }

    var segmentRemaining: Int {
        guard boundaries.indices.contains(currentIndex) else { return 0 }
        return max(0, Int(boundaries[currentIndex].end.timeIntervalSince(now).rounded(.up)))
    }

    var elapsed: Int {
        guard let startDate else { return 0 }
        return max(0, min(plan?.totalSeconds ?? 0, Int(now.timeIntervalSince(startDate))))
    }

    var total: Int { plan?.totalSeconds ?? 0 }

    var progress: Double { total > 0 ? Double(elapsed) / Double(total) : 0 }

    /// Jog seconds already run, counting the current segment partially.
    var jogSecondsDone: Int {
        var done = 0
        for b in boundaries {
            guard segments[b.index].kind == .jog else { continue }
            if now >= b.end { done += segments[b.index].seconds }
            else if now > b.start { done += Int(now.timeIntervalSince(b.start)) }
        }
        return done
    }

    // MARK: - Control

    func start(_ session: PlanSession, sessionID: String) {
        stopTicker()
        cancelNotifications()
        plan = session
        self.sessionID = sessionID
        finished = false
        currentIndex = 0
        let start = Date()
        startDate = start
        now = start
        var cursor = start
        boundaries = session.segments.enumerated().map { i, seg in
            let b = Boundary(index: i, start: cursor, end: cursor.addingTimeInterval(TimeInterval(seg.seconds)))
            cursor = b.end
            return b
        }
        scheduleNotifications()
        openAudio()
        speak(session.segments[0].cue)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
            .sink { [weak self] date in self?.tick(date) }
    }

    /// Jump to the start of the next segment: the remaining time of this one
    /// is dropped and every later boundary moves earlier by that much.
    func skipSegment() {
        guard isRunning, boundaries.indices.contains(currentIndex) else { return }
        let cut = boundaries[currentIndex].end.timeIntervalSince(Date())
        guard cut > 0 else { return }
        boundaries = boundaries.map { b in
            b.index < currentIndex ? b
            : b.index == currentIndex ? Boundary(index: b.index, start: b.start, end: b.end.addingTimeInterval(-cut))
            : Boundary(index: b.index, start: b.start.addingTimeInterval(-cut), end: b.end.addingTimeInterval(-cut))
        }
        // The plan's total shrinks by the cut so elapsed/progress stay honest.
        if var p = plan {
            p.segments[currentIndex].seconds -= Int(cut.rounded())
            plan = p
        }
        cancelNotifications()
        scheduleNotifications()
        tick(Date())
    }

    /// End early. Everything run so far still counts toward XP.
    func stop() {
        guard let sessionID, isRunning else { return }
        let elapsed = self.elapsed, jog = jogSecondsDone
        finish()
        onEnd?(sessionID, elapsed, jog, false)
    }

    /// Clear the finished state so the session sheet can close.
    func dismiss() {
        plan = nil
        sessionID = nil
        startDate = nil
        boundaries = []
        finished = false
    }

    private func tick(_ date: Date) {
        now = date
        guard let plan, let sessionID else { return }
        if let idx = boundaries.firstIndex(where: { date < $0.end }) {
            if idx != currentIndex {
                currentIndex = idx
                speak(plan.segments[idx].cue)
                if UIApplication.shared.applicationState == .active {
                    AudioServicesPlaySystemSound(1007)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }
        // Past the last boundary: the cool-down ended.
        currentIndex = plan.segments.count - 1
        let elapsed = plan.totalSeconds, jog = plan.jogSeconds
        finish()
        speak("Quest complete.")
        onEnd?(sessionID, elapsed, jog, true)
    }

    private func finish() {
        stopTicker()
        cancelNotifications()
        finished = true
        // Keep the audio session open a moment so the final cue can play.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.closeAudio() }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    // MARK: - Audio

    private func openAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
            silence = try AVAudioPlayer(contentsOf: QuestTimer.silentTrackURL())
            silence?.numberOfLoops = -1
            silence?.volume = 0.01
            silence?.play()
        } catch {
            // No background audio: notifications still carry every boundary.
        }
    }

    private func closeAudio() {
        silence?.stop()
        silence = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speaker.speak(utterance)
    }

    /// One second of 8 kHz mono silence, written once to the caches folder.
    /// Generated rather than bundled so the repo carries no binary asset.
    private static func silentTrackURL() throws -> URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("silence.wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let sampleRate: UInt32 = 8000, samples: UInt32 = 8000
        let dataSize = samples * 2
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + dataSize); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(dataSize)
        d.append(Data(count: Int(dataSize)))
        try d.write(to: url)
        return url
    }

    // MARK: - Notifications

    private func scheduleNotifications() {
        guard let plan else { return }
        let center = UNUserNotificationCenter.current()
        for b in boundaries.dropFirst() {
            let seg = plan.segments[b.index]
            let content = UNMutableNotificationContent()
            content.title = seg.label
            content.body = seg.cue + " " + Quest.short(seg.seconds) + "."
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let delay = b.start.timeIntervalSinceNow
            guard delay > 0 else { continue }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            center.add(UNNotificationRequest(identifier: "\(QuestTimer.notificationPrefix)\(b.index)", content: content, trigger: trigger))
        }
        if let last = boundaries.last {
            let content = UNMutableNotificationContent()
            content.title = "Quest complete"
            content.body = "Week \(plan.week), day \(plan.day) done. Fitbit will verify it."
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let delay = last.end.timeIntervalSinceNow
            if delay > 0 {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                center.add(UNNotificationRequest(identifier: "\(QuestTimer.notificationPrefix)end", content: content, trigger: trigger))
            }
        }
    }

    private func cancelNotifications() {
        let ids = (0..<40).map { "\(QuestTimer.notificationPrefix)\($0)" } + ["\(QuestTimer.notificationPrefix)end"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
