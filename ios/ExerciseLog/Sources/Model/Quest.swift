import Foundation

// MARK: - The plan

/// One timed stretch of a session: jog, walk, or the warm-up / cool-down walk.
struct Segment: Codable, Equatable, Hashable {
    enum Kind: String, Codable { case warmup, jog, walk, cooldown }
    var kind: Kind
    var seconds: Int

    var label: String {
        switch kind {
        case .warmup: return "Warm up"
        case .jog: return "Jog"
        case .walk: return "Walk"
        case .cooldown: return "Cool down"
        }
    }

    /// The spoken cue at the start of the segment.
    var cue: String {
        switch kind {
        case .warmup: return "Warm up. Brisk walk."
        case .jog: return "Jog."
        case .walk: return "Walk."
        case .cooldown: return "Cool down. Easy walk."
        }
    }
}

/// A plan session: week N, day M, and its segments in order.
struct PlanSession: Identifiable, Hashable {
    var week: Int
    var day: Int
    var segments: [Segment]

    var id: String { "\(week)-\(day)" }
    var totalSeconds: Int { segments.reduce(0) { $0 + $1.seconds } }
    var jogSeconds: Int { segments.filter { $0.kind == .jog }.reduce(0) { $0 + $1.seconds } }

    /// "8 x (60s jog, 90s walk)" style summary of the working part.
    var summary: String {
        let work = segments.filter { $0.kind == .jog || $0.kind == .walk }
        guard let first = work.first else { return "Walk" }
        // Detect a simple repeat of a two-segment pattern.
        if work.count >= 4, work.count % 2 == 0 {
            let pair = Array(work.prefix(2))
            let repeats = stride(from: 0, to: work.count, by: 2).allSatisfy { i in
                Array(work[i..<min(i + 2, work.count)]) == pair
            }
            if repeats, pair[1].kind == .walk {
                return "\(work.count / 2) x (\(Quest.short(pair[0].seconds)) jog, \(Quest.short(pair[1].seconds)) walk)"
            }
        }
        if work.count == 1 { return "\(Quest.short(first.seconds)) \(first.label.lowercased())" }
        return work.map { "\(Quest.short($0.seconds)) \($0.label.lowercased())" }.joined(separator: ", ")
    }
}

/// Couch to 5K, the nine-week NHS structure: three sessions a week, each
/// bracketed by a five-minute brisk walk, building from 60-second jogs to
/// 30 minutes continuous. Week 9 day 3 is the boss.
enum Plan {
    static let weeks = 9
    static let daysPerWeek = 3
    static let warmup = Segment(kind: .warmup, seconds: 300)
    static let cooldown = Segment(kind: .cooldown, seconds: 300)

    private static func jog(_ s: Int) -> Segment { Segment(kind: .jog, seconds: s) }
    private static func walk(_ s: Int) -> Segment { Segment(kind: .walk, seconds: s) }
    private static func reps(_ n: Int, _ pattern: [Segment]) -> [Segment] {
        Array(repeating: pattern, count: n).flatMap { $0 }
    }

    /// Working segments (without warm-up and cool-down) per week and day.
    private static func work(week: Int, day: Int) -> [Segment] {
        switch week {
        case 1: return reps(8, [jog(60), walk(90)])
        case 2: return reps(6, [jog(90), walk(120)])
        case 3: return reps(2, [jog(90), walk(90), jog(180), walk(180)])
        case 4: return [jog(180), walk(90), jog(300), walk(150), jog(180), walk(90), jog(300)]
        case 5:
            switch day {
            case 1: return [jog(300), walk(180), jog(300), walk(180), jog(300)]
            case 2: return [jog(480), walk(300), jog(480)]
            default: return [jog(1200)]
            }
        case 6:
            switch day {
            case 1: return [jog(300), walk(180), jog(480), walk(180), jog(300)]
            case 2: return [jog(600), walk(180), jog(600)]
            default: return [jog(1500)]
            }
        case 7: return [jog(1500)]
        case 8: return [jog(1680)]
        default: return [jog(1800)]
        }
    }

    static func session(week: Int, day: Int) -> PlanSession {
        PlanSession(week: week, day: day, segments: [warmup] + work(week: week, day: day) + [cooldown])
    }

    static let all: [PlanSession] = (1...weeks).flatMap { w in (1...daysPerWeek).map { d in session(week: w, day: d) } }

    /// Chapter titles and the short story beat that unlocks with each week.
    static let chapters: [(title: String, story: String)] = [
        ("Tutorial Island",
         "Nobody starts with a level. You start with boots. Sixty seconds at a time, the island teaches the only rule that matters: leave the house and the rest follows."),
        ("The Lumbridge Road",
         "The road out of town is flat and the guards are bored. Ninety seconds of jogging feels longer than it is. That is the point. The road is measuring you, not the other way around."),
        ("The Draynor Marsh",
         "Uneven ground and longer stretches. Three minutes is where the lungs start to argue. Let them. The marsh gives way to firm ground every time you keep moving."),
        ("The Varrock Gate",
         "Five minutes without stopping, twice. The gate guards let through anyone who does not walk up to it. You do not walk up to it."),
        ("The Wilderness Ditch",
         "One session this week is twenty minutes, no walking. Everyone remembers the first time they crossed. Nobody remembers it being graceful."),
        ("The Barbarian Village",
         "Twenty-five minutes at the end of the week. The barbarians do not train for fun. They train because the alternative is being slow when it counts."),
        ("The Falador Wall",
         "Three runs of twenty-five. The wall does not get shorter. You get taller. That is the whole trick and it took seven weeks to see it."),
        ("The Taverley Dungeon",
         "Twenty-eight minutes, three times. Down here it is just you and the count. Loot is at the far end and it does not come to you."),
        ("The Boss",
         "Thirty minutes continuous, three times. The last one is the fight. When it is done you will have run a 5K, and the level you finished at is only where the next skill starts."),
    ]
}

// MARK: - Progress

/// What the Fitbit-side verifier found for a session. Written by the Mac
/// script, never by the phone; field names are shared with `lib/quest.py`.
struct Verification: Codable, Equatable {
    var logId: Int64
    var source: String
    var activityName: String
    var startTime: Date
    var durationSeconds: Int
    var distanceKm: Double
    var averageHeartRate: Int?
    /// Fitbit "fairly" + "very" active minutes during the activity.
    var activeMinutes: Int
    var verifiedAt: Date
}

/// One attempt at a quest. Plan sessions carry week and day; a free run the
/// verifier found on Fitbit with no matching attempt has neither.
struct QuestSession: Codable, Equatable, Identifiable {
    var id: String
    var week: Int?
    var day: Int?
    var startedAt: Date
    var endedAt: Date?
    var elapsedSeconds: Int = 0
    var jogSecondsDone: Int = 0
    /// The timer reached the end of the cool-down.
    var completed: Bool = false
    var verification: Verification?

    enum CodingKeys: String, CodingKey {
        case id, week, day, startedAt, endedAt, elapsedSeconds, jogSecondsDone, completed, verification
    }

    init(id: String = UUID().uuidString.lowercased(), week: Int?, day: Int?, startedAt: Date) {
        self.id = id; self.week = week; self.day = day; self.startedAt = startedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        week = try c.decodeIfPresent(Int.self, forKey: .week)
        day = try c.decodeIfPresent(Int.self, forKey: .day)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        elapsedSeconds = try c.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0
        jogSecondsDone = try c.decodeIfPresent(Int.self, forKey: .jogSecondsDone) ?? 0
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        verification = try c.decodeIfPresent(Verification.self, forKey: .verification)
    }

    var isPlan: Bool { week != nil && day != nil }
    var isVerified: Bool { verification != nil }
}

/// The quest side of the log file. Everything here is derivable from
/// `sessions`; levels and XP are computed, never stored, so the phone and the
/// Mac verifier can both rewrite parts of it without drifting.
struct QuestState: Codable, Equatable {
    static let planID = "c25k"

    var plan: String = QuestState.planID
    var startedAt: Date?
    var sessions: [QuestSession] = []

    enum CodingKeys: String, CodingKey { case plan, startedAt, sessions }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plan = try c.decodeIfPresent(String.self, forKey: .plan) ?? QuestState.planID
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        sessions = try c.decodeIfPresent([QuestSession].self, forKey: .sessions) ?? []
    }

    // MARK: Derived

    var xp: Int { sessions.reduce(0) { $0 + Quest.xp(for: $1) } }
    var level: Int { Quest.level(forXP: xp) }

    func sessions(week: Int, day: Int) -> [QuestSession] {
        sessions.filter { $0.week == week && $0.day == day }
    }

    func isDone(week: Int, day: Int) -> Bool {
        sessions(week: week, day: day).contains { $0.completed }
    }

    func isVerified(week: Int, day: Int) -> Bool {
        sessions(week: week, day: day).contains { $0.completed && $0.isVerified }
    }

    func chapterDone(_ week: Int) -> Bool {
        (1...Plan.daysPerWeek).allSatisfy { isDone(week: week, day: $0) }
    }

    /// The first plan session without a completed attempt.
    var next: PlanSession? {
        Plan.all.first { !isDone(week: $0.week, day: $0.day) }
    }

    /// Highest week with any completed session, else 1: the chapter shown open.
    var currentWeek: Int {
        next?.week ?? Plan.weeks
    }

    /// Completed plan sessions in the calendar week containing `date`.
    func completedThisWeek(_ date: Date = Date()) -> Int {
        let weekOf = LogDates.weekOf(date)
        return sessions.filter { s in
            s.completed && s.isPlan && LogDates.weekOf(s.startedAt) == weekOf
        }.count
    }

    var lastAttempt: QuestSession? {
        sessions.filter { $0.isPlan }.max { $0.startedAt < $1.startedAt }
    }
}

// MARK: - XP rules

/// The XP rules, kept small enough to restate in the README and mirrored
/// exactly in `lib/quest.py`. Change both or neither.
enum Quest {
    /// Finished the warm-up: you left the house.
    static let bootsOnXP = 1000
    static let bootsOnSeconds = 300
    /// The timer ran to the end of the cool-down.
    static let completeXP = 1500
    /// Fitbit shows a matching activity.
    static let verifiedXP = 1500
    /// Per Fitbit "fairly" or "very" active minute in a verified activity.
    static let activeMinuteXP = 50
    /// A free run the verifier found with no phone session.
    static let freeRunXP = 500

    static func xp(for s: QuestSession) -> Int {
        var total = 0
        if s.isPlan {
            if s.elapsedSeconds >= bootsOnSeconds { total += bootsOnXP }
            if s.completed { total += completeXP }
            if s.isVerified { total += verifiedXP }
        } else if s.isVerified {
            total += freeRunXP
        }
        if let v = s.verification { total += v.activeMinutes * activeMinuteXP }
        return total
    }

    /// OSRS experience table: level L needs sum over n < L of
    /// floor(n + 300 * 2^(n/7)) / 4, floored.
    static let xpTable: [Int] = {
        var table = [0, 0]  // index 1 = level 1 = 0 xp
        var points = 0.0
        for n in 1..<99 {
            points += floor(Double(n) + 300 * pow(2, Double(n) / 7))
            table.append(Int(floor(points / 4)))
        }
        return table
    }()

    static func xp(forLevel level: Int) -> Int {
        xpTable[max(1, min(99, level))]
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while level < 99, xpTable[level + 1] <= xp { level += 1 }
        return level
    }

    /// Progress into the current level, 0...1.
    static func levelProgress(xp: Int) -> Double {
        let level = level(forXP: xp)
        guard level < 99 else { return 1 }
        let lo = xpTable[level], hi = xpTable[level + 1]
        return Double(xp - lo) / Double(hi - lo)
    }

    static func short(_ seconds: Int) -> String {
        if seconds % 60 == 0 { return "\(seconds / 60) min" }
        if seconds < 60 { return "\(seconds)s" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
