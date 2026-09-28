import SwiftUI

/// Hitpoints: sleep nights, healthy meals, and the share from combat.
struct HitpointsView: View {
    @EnvironmentObject private var store: LogStore
    @State private var showMeal = false
    @State private var mealNote = ""
    @State private var mealDate = Date()

    private var nights: [SleepNight] { store.skills.nights }
    private var today: String { LogDates.dayString(Date()) }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                SkillHeader(skill: .hitpoints)
                sleepPanel
                mealsPanel
                breakdown
            }
            .padding(8)
        }
        .background(RS.darkImage().ignoresSafeArea())
        .navigationTitle("Hitpoints")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMeal) { mealSheet }
    }

    private var sleepPanel: some View {
        let run = Skills.currentSleepRun(nights)
        let claimedToday = nights.contains { $0.date == today && $0.goalMet }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sleep").rsText(20, bold: true, color: RS.orange)
                Spacer()
                Text(run > 0 ? "\(run) night run" : "no run").rsText(16, color: run > 0 ? RS.green : RS.grey)
            }
            HStack(spacing: 3) {
                ForEach(lastDays(14), id: \.self) { d in
                    let n = nights.first { $0.date == d }
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(n == nil ? RS.stoneDarker : n!.goalMet ? (n!.verified ? RS.green : RS.yellow) : RS.red.opacity(0.7))
                            .frame(height: 18)
                            .bevel(inset: true)
                        Text(String(d.suffix(2))).rsSmall(16, color: RS.grey)
                    }
                }
            }
            Text("Green: Fitbit saw the goal met. Yellow: claimed here, waiting for the Mac. Red: short night.")
                .rsSmall(16, color: RS.grey)
            if claimedToday {
                Button("Undo last night's claim") { store.unclaimSleepGoal(date: today) }
                    .buttonStyle(StoneButton(color: RS.grey, fill: true))
            } else {
                Button("I hit my sleep goal last night") { store.claimSleepGoal() }
                    .buttonStyle(StoneButton(color: RS.orange, fill: true))
            }
            Text("Night 1 is \(Skills.sleepBaseXP) xp, each consecutive night adds \(Skills.sleepStepXP), capped at \(Skills.sleepMaxXP). A miss resets the run, not the XP.")
                .rsSmall(16, color: RS.grey)
        }
        .padding(10)
        .stonePanel()
    }

    private var mealsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Healthy meals").rsText(20, bold: true, color: RS.orange)
                Spacer()
                Button("Log a meal") { mealNote = ""; mealDate = Date(); showMeal = true }
                    .buttonStyle(StoneButton(color: RS.green))
            }
            let recent = store.skills.meals.sorted { $0.loggedAt > $1.loggedAt }.prefix(8)
            if recent.isEmpty {
                Text("Nothing yet. \(Skills.mealXP) xp each; a healthy dish logged under Cooking counts too.").rsSmall(16, color: RS.grey)
            }
            ForEach(Array(recent)) { m in
                HStack {
                    Text(LogDates.humanDay(m.date)).rsSmall(16, color: RS.grey).frame(width: 70, alignment: .leading)
                    Text(m.note.isEmpty ? "Healthy meal" : m.note).rsSmall(16, color: RS.white)
                    Spacer()
                    Text("+\(Skills.mealXP)").rsSmall(16, color: RS.green)
                    Button("x") { store.deleteSkillEntry(m.id) }.buttonStyle(StoneButton(color: RS.red))
                }
            }
        }
        .padding(10)
        .stonePanel()
    }

    private var breakdown: some View {
        let f = store.file
        let combat = (Skills.strengthXP(f) + f.quest.xp) / Skills.combatShare
        let meals = f.skills.meals.count * Skills.mealXP + f.skills.cooks.filter { $0.healthy }.count * Skills.mealXP
        return VStack(alignment: .leading, spacing: 4) {
            Text("Where it comes from").rsText(18, bold: true, color: RS.orange)
            line("Base (level 10)", Skills.hitpointsBaseXP)
            line("Sleep", Skills.sleepXP(nights))
            line("Healthy meals", meals)
            line("Strength and Agility, a third", combat)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .stonePanel()
    }

    private func line(_ label: String, _ xp: Int) -> some View {
        HStack {
            Text(label).rsText(16, color: RS.white)
            Spacer()
            Text("\(xp.formatted()) xp").rsText(16, color: RS.yellow).monospacedDigit()
        }
    }

    private var mealSheet: some View {
        VStack(spacing: 12) {
            Text("Healthy meal").rsText(20, bold: true, color: RS.orange)
            TextField("What was it?", text: $mealNote)
                .textFieldStyle(.plain).rsText(18, color: RS.white).tint(RS.yellow).padding(8).stoneSlot()
            DatePicker("Date", selection: $mealDate, displayedComponents: .date)
                .rsText(16, color: RS.white).tint(RS.yellow)
            Button("Log it (+\(Skills.mealXP) xp)") {
                store.addMeal(note: mealNote.trimmingCharacters(in: .whitespaces), date: LogDates.dayString(mealDate))
                showMeal = false
            }
            .buttonStyle(StoneButton(color: RS.orange, fill: true))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RS.stoneImage().ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationCornerRadius(0)
    }

    private func lastDays(_ n: Int) -> [String] {
        (0..<n).reversed().map { LogDates.shift(day: today, by: -$0) }
    }
}
