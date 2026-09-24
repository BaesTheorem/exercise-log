import SwiftUI

/// One row of the sheet for the selected day: name and progression on the
/// left, the weekly tally, and the day's set cells.
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

    private static let minSlots = 5

    private var entry: Entry {
        store.week(weekOf)?.days[day - 1].entries[exercise.id] ?? Entry()
    }
    private var weekTotal: Int { store.week(weekOf)?.totalSets(for: exercise.id) ?? 0 }
    private var progression: String { store.progression(weekOf: weekOf, exerciseID: exercise.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.headline)
                    Button {
                        progressionDraft = progression
                        editingProgression = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(progression.isEmpty ? "Set progression" : progression)
                                .font(.subheadline)
                                .foregroundStyle(progression.isEmpty ? Theme.outline : Theme.onSurfaceVariant)
                            Image(systemName: "pencil").font(.caption2).foregroundStyle(Theme.outline)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(weekTotal)/\(exercise.weeklySets)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(weekTotal >= exercise.weeklySets ? Theme.primary : Theme.onSurface)
                    Text("rest \(RestTimer.format(exercise.restSeconds))")
                        .font(.caption).foregroundStyle(Theme.onSurfaceVariant)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<slotCount, id: \.self) { i in
                    slot(i)
                }
                Spacer(minLength: 0)
                Button {
                    store.toggleDone(weekOf: weekOf, day: day, exerciseID: exercise.id)
                } label: {
                    Image(systemName: entry.done ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(entry.done ? Theme.primary : Theme.outline)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.done ? "Done for today" : "Mark done for today")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(striped ? Theme.surfaceLow : Theme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.outlineVariant).frame(height: 1) }
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
        return 10
    }

    @ViewBuilder
    private func slot(_ i: Int) -> some View {
        if i < entry.sets.count {
            let set = entry.sets[i]
            Button { editingSet = i } label: {
                Text("\(set.reps)")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.onSecondaryContainer)
                    .frame(width: 44, height: 40)
                    .background(Theme.secondaryContainer)
                    .overlay(alignment: .topTrailing) {
                        if !set.note.isEmpty {
                            Rectangle().fill(Theme.primary).frame(width: 6, height: 6).padding(3)
                        }
                    }
            }
            .buttonStyle(.plain)
        } else if entry.done {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 44, height: 40)
                .hairline()
                .overlay {
                    // The paper strikethrough: the remaining boxes get a line.
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 20)); p.addLine(to: CGPoint(x: 44, y: 20))
                    }
                    .stroke(Theme.outline, lineWidth: 1)
                }
        } else if i == entry.sets.count {
            Button { loggingNew = true } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 44, height: 40)
                    .hairline(Theme.primary.opacity(0.6))
            }
            .buttonStyle(.plain)
        } else {
            Rectangle().fill(Color.clear).frame(width: 44, height: 40).hairline()
        }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
