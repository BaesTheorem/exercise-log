import SwiftUI

/// Firemaking, Crafting and Cooking share one screen: a header, a log
/// button, and the entries newest first.
struct SkillLogView: View {
    let skill: Skill
    @EnvironmentObject private var store: LogStore
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                SkillHeader(skill: skill)
                Button(addLabel) { showAdd = true }
                    .buttonStyle(StoneButton(color: RS.orange, fill: true))
                entries
            }
            .padding(8)
        }
        .background(RS.darkImage().ignoresSafeArea())
        .navigationTitle(skill.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) { SkillEntrySheet(skill: skill) }
    }

    private var addLabel: String {
        switch skill {
        case .firemaking: return "Light a fire"
        case .crafting: return "Log a creation"
        case .cooking: return "Log a dish"
        default: return "Log"
        }
    }

    private struct Row: Identifiable {
        let id: String
        let date: String
        let title: String
        let detail: String
        let xp: Int
    }

    private var rows: [Row] {
        let s = store.skills
        let out: [Row]
        switch skill {
        case .firemaking:
            out = s.fires.sorted { $0.loggedAt > $1.loggedAt }.map { Row(id: $0.id, date: $0.date, title: $0.kind.title, detail: $0.note, xp: $0.kind.xp) }
        case .crafting:
            out = s.crafts.sorted { $0.loggedAt > $1.loggedAt }.map { Row(id: $0.id, date: $0.date, title: $0.name, detail: [$0.tier.title, $0.note].filter { !$0.isEmpty }.joined(separator: ". "), xp: $0.tier.xp) }
        case .cooking:
            out = s.cooks.sorted { $0.loggedAt > $1.loggedAt }.map { Row(id: $0.id, date: $0.date, title: $0.dish + ($0.healthy ? " (healthy)" : ""), detail: [$0.tier.title, $0.note].filter { !$0.isEmpty }.joined(separator: ". "), xp: $0.tier.xp) }
        default:
            out = []
        }
        return out
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Log").rsText(18, bold: true, color: RS.orange)
            if rows.isEmpty { Text("Nothing yet.").rsSmall(16, color: RS.grey) }
            ForEach(rows) { r in
                HStack(alignment: .top, spacing: 8) {
                    Text(LogDates.humanDay(r.date)).rsSmall(16, color: RS.grey).frame(width: 70, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(r.title).rsSmall(16, color: RS.white)
                        if !r.detail.isEmpty { Text(r.detail).rsSmall(16, color: RS.grey) }
                    }
                    Spacer()
                    Text("+\(r.xp)").rsSmall(16, color: RS.green)
                    Button("x") { store.deleteSkillEntry(r.id) }.buttonStyle(StoneButton(color: RS.red))
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .stonePanel()
    }
}

/// The add sheet, shaped per skill.
struct SkillEntrySheet: View {
    let skill: Skill
    @EnvironmentObject private var store: LogStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var fire: FireKind = .campfire
    @State private var craft: CraftTier = .project
    @State private var cook: CookTier = .everyday
    @State private var healthy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    SkillIcon(name: skill.icon, size: 26)
                    Text(title).rsText(20, bold: true, color: RS.orange)
                    Spacer()
                    Button("X") { dismiss() }.buttonStyle(StoneButton(color: RS.red))
                }
                if skill != .firemaking {
                    TextField(skill == .cooking ? "Dish" : "What did you make?", text: $name)
                        .textFieldStyle(.plain).rsText(18, color: RS.white).tint(RS.yellow).padding(8).stoneSlot()
                }
                tierPicker
                if skill == .cooking {
                    Toggle(isOn: $healthy) { Text("Healthy (feeds Hitpoints +\(Skills.mealXP))").rsSmall(16, color: RS.white) }.tint(RS.green)
                }
                TextField("Note", text: $note)
                    .textFieldStyle(.plain).rsSmall(16).tint(RS.yellow).padding(8).stoneSlot()
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .rsText(16, color: RS.white).tint(RS.yellow)
                Button("Log it (+\(xp) xp)") { save() }
                    .buttonStyle(StoneButton(color: RS.orange, fill: true))
                    .disabled(skill != .firemaking && name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .background(RS.stoneImage().ignoresSafeArea())
        .presentationDetents([.large])
        .presentationCornerRadius(0)
    }

    private var title: String {
        switch skill {
        case .firemaking: return "Light a fire"
        case .crafting: return "Log a creation"
        case .cooking: return "Log a dish"
        default: return skill.title
        }
    }

    private var xp: Int {
        switch skill {
        case .firemaking: return fire.xp
        case .crafting: return craft.xp
        case .cooking: return cook.xp
        default: return 0
        }
    }

    @ViewBuilder
    private var tierPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch skill {
            case .firemaking:
                ForEach(FireKind.allCases) { k in option(k.title, k.xp, k == fire) { fire = k } }
            case .crafting:
                ForEach(CraftTier.allCases) { t in option(t.title, t.xp, t == craft) { craft = t } }
            case .cooking:
                ForEach(CookTier.allCases) { t in option(t.title, t.xp, t == cook) { cook = t } }
            default:
                EmptyView()
            }
        }
    }

    private func option(_ label: String, _ xp: Int, _ selected: Bool, _ pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            HStack {
                Text(label).rsSmall(16, color: selected ? RS.green : RS.white)
                Spacer()
                Text("\(xp) xp").rsSmall(16, color: selected ? RS.green : RS.grey)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(selected ? RS.stoneDark : Color.clear)
            .stoneSlot()
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let d = LogDates.dayString(date)
        let n = note.trimmingCharacters(in: .whitespaces)
        let nm = name.trimmingCharacters(in: .whitespaces)
        switch skill {
        case .firemaking: store.addFire(kind: fire, note: n, date: d)
        case .crafting: store.addCraft(name: nm, tier: craft, note: n, date: d)
        case .cooking: store.addCook(dish: nm, tier: cook, healthy: healthy, note: n, date: d)
        default: break
        }
        dismiss()
    }
}
