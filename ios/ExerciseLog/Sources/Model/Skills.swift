import Foundation

/// The skills panel. Six skills for now; every level uses the OSRS table in
/// `Quest`. XP is derived from the logs on every read and never stored, so
/// the phone and the Mac can both rewrite the file without drift. Rules
/// live here and in `lib/skills.py`; change both or neither.
enum Skill: String, CaseIterable, Codable, Identifiable {
    case hitpoints, strength, agility, firemaking, crafting, cooking

    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var icon: String { title + "_icon" }
    var jingle: String { "levelup_" + rawValue }

    var blurb: String {
        switch self {
        case .hitpoints: return "Nights you hit your sleep goal (consecutive nights are worth more), healthy meals, and a third of all Strength and Agility XP."
        case .strength: return "The exercise log. Every set is 10 XP plus the reps; hitting an exercise's weekly target is 100 more."
        case .agility: return "The running quest. Couch to 5K, verified against Fitbit."
        case .firemaking: return "Fires you made. Fancier fires burn for more XP."
        case .crafting: return "Cool things you made. The more ambitious, the more XP."
        case .cooking: return "Dishes you cooked. Complex or exotic dishes give more XP, and a healthy one feeds Hitpoints too."
        }
    }
}

// MARK: - Logs

struct SleepNight: Codable, Equatable, Identifiable {
    /// The morning you woke, `yyyy-MM-dd` (Fitbit's dateOfSleep).
    var date: String
    var minutes: Int?
    var goalMet: Bool
    /// True when the Mac wrote it from Fitbit; false for a night you claimed.
    var verified: Bool
    var id: String { date }
}

struct MealEntry: Codable, Equatable, Identifiable {
    var id: String
    var date: String
    var note: String
    var loggedAt: Date
}

enum FireKind: String, Codable, CaseIterable, Identifiable {
    case candle, fireplace, campfire, bonfire, noLighter, rain
    var id: String { rawValue }
    var title: String {
        switch self {
        case .candle: return "Candle or stove"
        case .fireplace: return "Fireplace"
        case .campfire: return "Campfire"
        case .bonfire: return "Bonfire"
        case .noLighter: return "No lighter (flint, bow drill)"
        case .rain: return "In the rain"
        }
    }
    var xp: Int {
        switch self {
        case .candle: return 10
        case .fireplace: return 40
        case .campfire: return 90
        case .bonfire: return 135
        case .noLighter: return 202
        case .rain: return 304
        }
    }
}

struct FireEntry: Codable, Equatable, Identifiable {
    var id: String
    var date: String
    var kind: FireKind
    var note: String
    var loggedAt: Date
}

enum CraftTier: String, Codable, CaseIterable, Identifiable {
    case trinket, project, ambitious, masterwork
    var id: String { rawValue }
    var title: String {
        switch self {
        case .trinket: return "Small thing (an evening)"
        case .project: return "Real project (days)"
        case .ambitious: return "Ambitious (weeks)"
        case .masterwork: return "Masterwork"
        }
    }
    var xp: Int {
        switch self {
        case .trinket: return 50
        case .project: return 200
        case .ambitious: return 600
        case .masterwork: return 1500
        }
    }
}

struct CraftEntry: Codable, Equatable, Identifiable {
    var id: String
    var date: String
    var name: String
    var tier: CraftTier
    var note: String
    var loggedAt: Date
}

enum CookTier: String, Codable, CaseIterable, Identifiable {
    case simple, everyday, involved, exotic, feast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .simple: return "Simple (toast, a bowl)"
        case .everyday: return "Everyday meal"
        case .involved: return "Involved (from scratch)"
        case .exotic: return "Exotic or new cuisine"
        case .feast: return "Feast for others"
        }
    }
    var xp: Int {
        switch self {
        case .simple: return 30
        case .everyday: return 70
        case .involved: return 120
        case .exotic: return 210
        case .feast: return 300
        }
    }
}

struct CookEntry: Codable, Equatable, Identifiable {
    var id: String
    var date: String
    var dish: String
    var tier: CookTier
    var healthy: Bool
    var note: String
    var loggedAt: Date
}

struct SkillsState: Codable, Equatable {
    var nights: [SleepNight] = []
    var meals: [MealEntry] = []
    var fires: [FireEntry] = []
    var crafts: [CraftEntry] = []
    var cooks: [CookEntry] = []

    enum CodingKeys: String, CodingKey { case nights, meals, fires, crafts, cooks }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nights = try c.decodeIfPresent([SleepNight].self, forKey: .nights) ?? []
        meals = try c.decodeIfPresent([MealEntry].self, forKey: .meals) ?? []
        fires = try c.decodeIfPresent([FireEntry].self, forKey: .fires) ?? []
        crafts = try c.decodeIfPresent([CraftEntry].self, forKey: .crafts) ?? []
        cooks = try c.decodeIfPresent([CookEntry].self, forKey: .cooks) ?? []
    }
}

// MARK: - Rules

enum Skills {
    /// Hitpoints starts at level 10, as in the game.
    static let hitpointsBaseXP = 1154
    static let setBaseXP = 10
    static let weeklyTargetXP = 100
    static let sleepBaseXP = 60
    static let sleepStepXP = 20
    static let sleepMaxXP = 200
    static let mealXP = 40
    static let combatShare = 3

    static func strengthXP(_ f: LogFile) -> Int {
        var total = 0
        for w in f.weeks {
            for d in w.days {
                for (_, e) in d.entries { total += e.sets.reduce(0) { $0 + setBaseXP + $1.reps } }
            }
            for ex in f.exercises where ex.weeklySets > 0 && w.totalSets(for: ex.id) >= ex.weeklySets {
                total += weeklyTargetXP
            }
        }
        return total
    }

    /// Nights in date order; a night is worth more for every consecutive
    /// goal-met night before it, up to the cap. A miss resets the run, never
    /// the XP already earned.
    static func sleepXP(_ nights: [SleepNight]) -> Int {
        let sorted = nights.sorted { $0.date < $1.date }
        var total = 0
        var run = 0
        var previous: String?
        for n in sorted {
            if n.goalMet {
                if let p = previous, LogDates.shift(day: p, by: 1) == n.date, run > 0 { run += 1 } else { run = 1 }
                total += min(sleepBaseXP + sleepStepXP * (run - 1), sleepMaxXP)
            } else {
                run = 0
            }
            previous = n.date
        }
        return total
    }

    /// Length of the goal-met run ending on the most recent night.
    static func currentSleepRun(_ nights: [SleepNight]) -> Int {
        let sorted = nights.sorted { $0.date < $1.date }
        var run = 0
        var previous: String?
        for n in sorted {
            if n.goalMet {
                if let p = previous, LogDates.shift(day: p, by: 1) == n.date, run > 0 { run += 1 } else { run = 1 }
            } else {
                run = 0
            }
            previous = n.date
        }
        return run
    }

    static func hitpointsXP(_ f: LogFile) -> Int {
        let s = f.skills
        let meals = s.meals.count * mealXP + s.cooks.filter { $0.healthy }.count * mealXP
        let combat = (strengthXP(f) + f.quest.xp) / combatShare
        return hitpointsBaseXP + sleepXP(s.nights) + meals + combat
    }

    static func xp(_ skill: Skill, _ f: LogFile) -> Int {
        switch skill {
        case .hitpoints: return hitpointsXP(f)
        case .strength: return strengthXP(f)
        case .agility: return f.quest.xp
        case .firemaking: return f.skills.fires.reduce(0) { $0 + $1.kind.xp }
        case .crafting: return f.skills.crafts.reduce(0) { $0 + $1.tier.xp }
        case .cooking: return f.skills.cooks.reduce(0) { $0 + $1.tier.xp }
        }
    }

    static func level(_ skill: Skill, _ f: LogFile) -> Int { Quest.level(forXP: xp(skill, f)) }

    static func levels(_ f: LogFile) -> [Skill: Int] {
        Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, level($0, f)) })
    }

    static func totalLevel(_ f: LogFile) -> Int { levels(f).values.reduce(0, +) }
}

extension LogDates {
    static func shift(day: String, by days: Int) -> String {
        guard let d = date(day), let s = Calendar.current.date(byAdding: .day, value: days, to: d) else { return day }
        return dayString(s)
    }
}

/// A level gained, queued by the store for the banner.
struct LevelUp: Identifiable, Equatable {
    let skill: Skill
    let level: Int
    var id: String { "\(skill.rawValue)-\(level)" }
}
