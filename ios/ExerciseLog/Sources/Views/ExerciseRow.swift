import SwiftUI

/// One row of the sheet for the selected day, drawn as a skill panel: icon
/// and name, the progression underneath, the weekly tally as an XP bar, and
/// the day's set slots as inventory slots.
struct ExerciseRow: View {
    let exercise: Exercise
    let weekOf: String
    let day: Int
    let striped: Bool

    @EnvironmentObject private var store: LogStore
    @EnvironmentObject private var timer: RestTimer
    @State private var editingSet: Int? = nil
    @State private var loggingNew = false
    @State private var editingProgression = false
    @State private var progressionDraft = ""
    @State private var showLevelUp = false

    private static let minSlots = 5

    private var entry: Entry {
        store.week(weekOf)?.days[day - 1].entries[exercise.id] ?? Entry()
    }
    private var weekTotal: Int { store.week(weekOf)?.totalSets(for: exercise.id) ?? 0 }
    private var progression: String { store.progression(weekOf: weekOf, exerciseID: exercise.id) }
    private var readyToProgress: Bool { store.week(weekOf)?.readyToProgress(exercise) ?? false }
    private var targetMet: Bool { weekTotal >= exercise.weeklySets }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                SkillIcon(name: exercise.skillIcon, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).rsText(20, bold: true, color: RS.orange)
                    Button {
                        progressionDraft = progression
                        editingProgression = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(progression.isEmpty ? "Set progression" : progression)
                                .rsSmall(16, color: progression.isEmpty ? RS.grey : RS.white)
                            Text("*").rsSmall(16, color: RS.cyan)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(weekTotal)/\(exercise.weeklySets)")
                        .rsText(20, bold: true, color: targetMet ? RS.green : RS.yellow)
                        .monospacedDigit()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(RS.stoneDarker)
                            Rectangle().fill(targetMet ? RS.green : RS.yellow)
                                .frame(width: geo.size.width * min(1, Double(weekTotal) / Double(max(1, exercise.weeklySets))))
                        }
                    }
                    .frame(width: 72, height: 6)
                    .bevel(inset: true)
                    Text("\(exercise.repMin)-\(exercise.repMax) reps, rest \(RestTimer.format(exercise.restSeconds))")
                        .rsSmall(16, color: RS.grey)
                }
            }

            if readyToProgress {
                Button { showLevelUp = true } label: {
                    HStack(spacing: 8) {
                        SkillIcon(name: exercise.skillIcon, size: 18)
                        Text("Congratulations! 3 sets of \(exercise.repMax). Click here to level up.")
                            .font(RS.font(16)).foregroundStyle(RS.parchmentInk)
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .parchmentPanel()
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 5) {
                ForEach(0..<slotCount, id: \.self) { i in
                    slot(i)
                }
                Spacer(minLength: 0)
                Button {
                    store.toggleDone(weekOf: weekOf, day: day, exerciseID: exercise.id)
                } label: {
                    Text(entry.done ? "✓" : " ")
                        .rsText(22, bold: true, color: RS.green)
                        .frame(width: 40, height: 40)
                        .stoneSlot()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.done ? "Done for today" : "Mark done for today")
            }
        }
        .padding(10)
        .stonePanel()
        .sheet(isPresented: $loggingNew) {
            RepsSheet(exercise: exercise, setNumber: entry.sets.count + 1, suggested: suggestedReps) { reps, note, rest in
                store.logSet(weekOf: weekOf, day: day, exerciseID: exercise.id, reps: reps, note: note)
                if rest {
                    RestTimer.requestPermission()
                    timer.start(seconds: exercise.restSeconds, label: exercise.name)
                }
            }
        }
        .sheet(item: $editingSet) { index in
            if entry.sets.indices.contains(index) {
                RepsSheet(exercise: exercise, existing: (index, entry.sets[index]), setNumber: index + 1,
                          suggested: entry.sets[index].reps) { reps, note, _ in
                    store.updateSet(weekOf: weekOf, day: day, exerciseID: exercise.id, index: index, reps: reps, note: note)
                } onDelete: {
                    store.deleteSet(weekOf: weekOf, day: day, exerciseID: exercise.id, index: index)
                }
            }
        }
        .sheet(isPresented: $showLevelUp) {
            LevelUpDialog(exercise: exercise, current: progression) { next in
                store.setProgression(weekOf: weekOf, exerciseID: exercise.id, text: next, advanced: true)
                Jingle.levelUp()
            } onSnooze: {
                store.snoozeProgression(weekOf: weekOf, exerciseID: exercise.id)
            }
        }
        .alert("Progression", isPresented: $editingProgression) {
            TextField("e.g. 100kg chest press", text: $progressionDraft)
            Button("Save") {
                store.setProgression(weekOf: weekOf, exerciseID: exercise.id, text: progressionDraft.trimmingCharacters(in: .whitespaces))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Load or variant for \(exercise.name) this week.")
        }
    }

    private var slotCount: Int { max(ExerciseRow.minSlots, entry.sets.count + (entry.done ? 0 : 1)) }

    /// Last set today, else last set this week, else last week's final set.
    private var suggestedReps: Int {
        if let last = entry.sets.last { return last.reps }
        if let week = store.week(weekOf) {
            for d in week.days.reversed() {
                if let s = d.entries[exercise.id]?.sets.last { return s.reps }
            }
        }
        let prev = LogDates.shift(weekOf: weekOf, by: -1)
        if let week = store.week(prev) {
            for d in week.days.reversed() {
                if let s = d.entries[exercise.id]?.sets.last { return s.reps }
            }
        }
        return exercise.repMin
    }

    @ViewBuilder
    private func slot(_ i: Int) -> some View {
        if i < entry.sets.count {
            let set = entry.sets[i]
            Button { editingSet = i } label: {
                Text("\(set.reps)")
                    .rsText(22, bold: true, color: set.reps >= exercise.repMax ? RS.green : RS.yellow)
                    .monospacedDigit()
                    .frame(width: 44, height: 40)
                    .stoneSlot()
                    .overlay(alignment: .topTrailing) {
                        if !set.note.isEmpty {
                            Rectangle().fill(RS.cyan).frame(width: 5, height: 5).padding(3)
                        }
                    }
            }
            .buttonStyle(.plain)
        } else if entry.done {
            Rectangle().fill(Color.clear)
                .frame(width: 44, height: 40)
                .stoneSlot()
                .overlay {
                    Path { p in
                        p.move(to: CGPoint(x: 4, y: 20)); p.addLine(to: CGPoint(x: 40, y: 20))
                    }
                    .stroke(RS.grey, lineWidth: 2)
                }
        } else if i == entry.sets.count {
            Button { loggingNew = true } label: {
                Text("+")
                    .rsText(24, bold: true, color: RS.green)
                    .frame(width: 44, height: 40)
                    .stoneSlot()
            }
            .buttonStyle(.plain)
        } else {
            Rectangle().fill(Color.clear).frame(width: 44, height: 40).stoneSlot()
        }
    }
}

/// The level-up dialog: parchment, the skill icon, the game's own wording,
/// and the next rung of the ladder or the bumped load, editable.
struct LevelUpDialog: View {
    let exercise: Exercise
    let current: String
    var onProgress: (String) -> Void
    var onSnooze: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var next = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                SkillIcon(name: exercise.skillIcon, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Congratulations, you just advanced a \(exercise.name) level.")
                        .font(RS.font(18, bold: true)).foregroundStyle(RS.parchmentInk)
                    Text("Three sets at \(exercise.repMax) reps. Move up so the first set lands near \(exercise.repMin).")
                        .font(RS.font(16)).foregroundStyle(RS.parchmentInk.opacity(0.8))
                }
            }
            .padding(12)
            .parchmentPanel()

            VStack(alignment: .leading, spacing: 4) {
                Text("Current level").rsText(16, color: RS.orange)
                Text(current.isEmpty ? "(none)" : current).rsText(18, color: RS.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Next level").rsText(16, color: RS.orange)
                TextField("e.g. 102.5kg chest press", text: $next)
                    .textFieldStyle(.plain)
                    .rsText(18, color: RS.white)
                    .tint(RS.yellow)
                    .padding(8)
                    .stoneSlot()
            }
            if !exercise.ladder.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ladder").rsText(16, color: RS.orange)
                    ForEach(exercise.ladder, id: \.self) { rung in
                        Button { next = rung } label: {
                            HStack {
                                Text(rung).rsSmall(16, color: rung == next ? RS.green : RS.white)
                                Spacer()
                                if rung.caseInsensitiveCompare(current) == .orderedSame {
                                    Text("now").rsSmall(16, color: RS.grey)
                                }
                            }
                            .padding(8)
                            .stoneSlot()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button("Level up") {
                let t = next.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { return }
                onProgress(t); dismiss()
            }
            .buttonStyle(StoneButton(color: RS.orange, fill: true))
            Button("Not yet") { onSnooze(); dismiss() }
                .buttonStyle(StoneButton(color: RS.grey, fill: true))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RS.stoneImage().ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(0)
        .onAppear { next = exercise.suggestedNext(after: current) ?? "" }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
