import Foundation

/// The whole log, exactly as it is written to disk.
///
/// One JSON file holds everything so a reader outside the app (MIST, a
/// script, a spreadsheet import) needs no schema beyond this struct. Field
/// names are the contract: change them only with a `schemaVersion` bump and
/// a reader update. See README.md for the documented shape.
struct LogFile: Codable, Equatable {
    static let appID = "exercise-log"
    static let currentSchema = 1

    var app: String = LogFile.appID
    var schemaVersion: Int = LogFile.currentSchema
    /// ISO-8601 with fractional seconds; newest copy wins when two disagree.
    var updatedAt: Date = Date()
    var exercises: [Exercise] = Exercise.defaults
    var weeks: [Week] = []

    // MARK: - Lookup

    func week(of weekOf: String) -> Week? {
        weeks.first { $0.weekOf == weekOf }
    }

    func exercise(_ id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }

    /// Active exercises in display order.
    var activeExercises: [Exercise] {
        exercises.filter { !$0.archived }
    }

    /// Returns the week, creating it with the current progressions
    /// snapshotted if it does not exist yet.
    mutating func ensureWeek(_ weekOf: String) -> Int {
        if let i = weeks.firstIndex(where: { $0.weekOf == weekOf }) { return i }
        var week = Week(weekOf: weekOf)
        for ex in exercises where !ex.archived {
            week.progressions[ex.id] = ex.progression
        }
        weeks.append(week)
        weeks.sort { $0.weekOf < $1.weekOf }
        return weeks.firstIndex { $0.weekOf == weekOf }!
    }
}

/// A row on the paper sheet: the movement pattern, its weekly set target
/// and the rest between sets.
struct Exercise: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var name: String
    /// Weekly target. The sheet's "Sets" column: 10 for the big compounds,
    /// 5 for isolation work.
    var weeklySets: Int
    var restSeconds: Int
    /// Current load or variant, free text ("100kg chest press",
    /// "hanging leg raises"). Snapshotted into each week.
    var progression: String
    var archived: Bool = false
    /// Working rep range. Progress when three sets in one session reach
    /// `repMax`; the next load should drop reps back near `repMin`.
    var repMin: Int = 10
    var repMax: Int = 15
    /// Ordered harder forms to offer after the current progression, e.g.
    /// ["incline pushups", "pushups", "decline pushups"]. Optional.
    var ladder: [String] = []
    /// Load increase to suggest when the progression starts with a number
    /// ("100kg chest press" -> "102.5kg chest press"). 0 disables it.
    var loadStep: Double = 2.5

    enum CodingKeys: String, CodingKey {
        case id, name, weeklySets, restSeconds, progression, archived, repMin, repMax, ladder, loadStep
    }

    init(id: String, name: String, weeklySets: Int, restSeconds: Int, progression: String,
         archived: Bool = false, repMin: Int = 10, repMax: Int = 15, ladder: [String] = [], loadStep: Double = 2.5) {
        self.id = id; self.name = name; self.weeklySets = weeklySets; self.restSeconds = restSeconds
        self.progression = progression; self.archived = archived; self.repMin = repMin; self.repMax = repMax
        self.ladder = ladder; self.loadStep = loadStep
    }

    /// Older files lack the progression fields; fill defaults instead of failing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        weeklySets = try c.decode(Int.self, forKey: .weeklySets)
        restSeconds = try c.decode(Int.self, forKey: .restSeconds)
        progression = try c.decodeIfPresent(String.self, forKey: .progression) ?? ""
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        repMin = try c.decodeIfPresent(Int.self, forKey: .repMin) ?? 10
        repMax = try c.decodeIfPresent(Int.self, forKey: .repMax) ?? 15
        ladder = try c.decodeIfPresent([String].self, forKey: .ladder) ?? []
        loadStep = try c.decodeIfPresent(Double.self, forKey: .loadStep) ?? 2.5
    }

    /// What to offer when the trigger fires: the next rung of the ladder,
    /// else the current load plus `loadStep`, else nothing automatic.
    func suggestedNext(after current: String) -> String? {
        if let i = ladder.firstIndex(where: { $0.caseInsensitiveCompare(current) == .orderedSame }),
           ladder.indices.contains(i + 1) {
            return ladder[i + 1]
        }
        if current.isEmpty, let first = ladder.first { return first }
        return Exercise.bumpLoad(current, by: loadStep)
    }

    /// "100kg chest press" + 2.5 -> "102.5kg chest press". Nil when the text
    /// does not start with a number.
    static func bumpLoad(_ text: String, by step: Double) -> String? {
        guard step > 0 else { return nil }
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = .whitespaces
        guard let value = scanner.scanDouble() else { return nil }
        let rest = String(text[scanner.currentIndex...])
        let bumped = value + step
        let number = bumped == bumped.rounded() ? String(Int(bumped)) : String(format: "%g", bumped)
        return number + rest
    }

    static func slug(_ name: String) -> String {
        let lowered = name.lowercased()
        let allowed = lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let collapsed = String(allowed).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? UUID().uuidString.lowercased() : collapsed
    }

    /// The sheet as printed, top to bottom.
    static let defaults: [Exercise] = [
        Exercise(id: "horizontal-push", name: "Horizontal Push", weeklySets: 10, restSeconds: 180, progression: "", repMin: 10, repMax: 15),
        Exercise(id: "vertical-push", name: "Vertical Push", weeklySets: 10, restSeconds: 180, progression: "", repMin: 10, repMax: 15),
        Exercise(id: "vertical-pull", name: "Vertical Pull", weeklySets: 5, restSeconds: 180, progression: "", repMin: 10, repMax: 15),
        Exercise(id: "horizontal-pull", name: "Horizontal Pull", weeklySets: 5, restSeconds: 180, progression: "", repMin: 10, repMax: 15),
        Exercise(id: "squats", name: "Squats", weeklySets: 10, restSeconds: 180, progression: "", repMin: 10, repMax: 15),
        Exercise(id: "bicep-curls", name: "Bicep Curls", weeklySets: 5, restSeconds: 60, progression: "", repMin: 12, repMax: 15),
        Exercise(id: "lower-abs", name: "Lower Abs", weeklySets: 5, restSeconds: 60, progression: "", repMin: 12, repMax: 15),
        Exercise(id: "upper-abs", name: "Upper Abs", weeklySets: 5, restSeconds: 60, progression: "", repMin: 12, repMax: 15),
        Exercise(id: "obliques", name: "Obliques", weeklySets: 5, restSeconds: 60, progression: "", repMin: 12, repMax: 15),
        Exercise(id: "tricep-extension", name: "Tricep Extension", weeklySets: 5, restSeconds: 60, progression: "", repMin: 12, repMax: 15),
        Exercise(id: "side-delt-raises", name: "Side Delt Raises", weeklySets: 5, restSeconds: 60, progression: "", repMin: 12, repMax: 15),
        Exercise(id: "rear-delt-raises", name: "Rear Delt Raises", weeklySets: 5, restSeconds: 60, progression: "", repMin: 12, repMax: 15),
        Exercise(id: "calves", name: "Calves", weeklySets: 10, restSeconds: 60, progression: "", repMin: 12, repMax: 15),
    ]
}

/// One paper page: a week with three training days.
struct Week: Codable, Equatable, Identifiable {
    static let daysPerWeek = 3

    /// First day of the calendar week, `yyyy-MM-dd`. Doubles as the id.
    var weekOf: String
    var days: [Day]
    /// Progression text per exercise id, as written on this page. Editing it
    /// mid-week updates the exercise's current value too.
    var progressions: [String: String] = [:]
    /// When the progression was last advanced this week, per exercise. Sets
    /// logged before it belong to the old load and do not count toward the
    /// next prompt.
    var progressedAt: [String: Date] = [:]
    var notes: String = ""

    var id: String { weekOf }

    init(weekOf: String) {
        self.weekOf = weekOf
        self.days = (1...Week.daysPerWeek).map { Day(day: $0) }
    }

    enum CodingKeys: String, CodingKey { case weekOf, days, progressions, progressedAt, notes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekOf = try c.decode(String.self, forKey: .weekOf)
        days = try c.decode([Day].self, forKey: .days)
        progressions = try c.decodeIfPresent([String: String].self, forKey: .progressions) ?? [:]
        progressedAt = try c.decodeIfPresent([String: Date].self, forKey: .progressedAt) ?? [:]
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    /// The double-progression trigger: some day this week has three or more
    /// sets at or above the ceiling, all logged after the last progression.
    func readyToProgress(_ ex: Exercise) -> Bool {
        let since = progressedAt[ex.id] ?? .distantPast
        return days.contains { d in
            let sets = d.entries[ex.id]?.sets ?? []
            return sets.filter { $0.loggedAt > since && $0.reps >= ex.repMax }.count >= 3
        }
    }

    func totalSets(for exerciseID: String) -> Int {
        days.reduce(0) { $0 + ($1.entries[exerciseID]?.sets.count ?? 0) }
    }

    var hasAnySets: Bool {
        days.contains { day in day.entries.values.contains { !$0.sets.isEmpty } }
    }
}

/// One of the three "Day N" column groups.
struct Day: Codable, Equatable {
    var day: Int
    /// Stamped `yyyy-MM-dd` the first time a set is logged on it, so the
    /// paper's "Day 2" gains a real date.
    var date: String?
    /// Keyed by exercise id so a reader can join without positional guessing.
    var entries: [String: Entry] = [:]

    init(day: Int) { self.day = day }
}

struct Entry: Codable, Equatable {
    var sets: [SetRecord] = []
    /// The strikethrough on paper: no more sets of this today.
    var done: Bool = false
}

struct SetRecord: Codable, Equatable, Identifiable {
    var reps: Int
    var loggedAt: Date
    /// Optional per-set override of the progression ("did 90kg on the last
    /// one"). Empty means the week's progression applies.
    var note: String = ""

    var id: Date { loggedAt }
}

// MARK: - Dates

enum LogDates {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }

    static func date(_ s: String) -> Date? { dayFormatter.date(from: s) }

    /// Start of the calendar week containing `date`, honouring the user's
    /// first weekday (Sunday in the US, which is how the paper log was kept).
    static func weekOf(_ date: Date = Date()) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = cal.date(from: comps) ?? date
        return dayString(start)
    }

    static func shift(weekOf: String, by weeks: Int) -> String {
        guard let d = date(weekOf),
              let shifted = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: d)
        else { return weekOf }
        return dayString(shifted)
    }

    static func humanWeek(_ weekOf: String) -> String {
        guard let d = date(weekOf) else { return weekOf }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    static func humanDay(_ day: String) -> String {
        guard let d = date(day) else { return day }
        let f = DateFormatter()
        f.dateFormat = "EEE M/d"
        return f.string(from: d)
    }
}

// MARK: - JSON

enum LogJSON {
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(iso.string(from: date))
        }
        return e
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        // Accept both fractional and whole-second timestamps so a hand or
        // script-edited file still loads.
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            if let d = iso.date(from: s) ?? isoPlain.date(from: s) { return d }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date \(s)")
        }
        return d
    }
}
