import SwiftUI

/// Log one set: reps, optional note, and whether to start the rest timer.
/// Also edits or deletes an existing set when `existing` is given.
struct RepsSheet: View {
    let exercise: Exercise
    let existing: (index: Int, set: SetRecord)?
    /// 1-based number of the set being logged or edited.
    let setNumber: Int
    let suggested: Int
    var onLog: (Int, String, Bool) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var reps: Int
    @State private var note: String

    init(exercise: Exercise, existing: (index: Int, set: SetRecord)? = nil, setNumber: Int, suggested: Int,
         onLog: @escaping (Int, String, Bool) -> Void, onDelete: (() -> Void)? = nil) {
        self.exercise = exercise
        self.existing = existing
        self.setNumber = setNumber
        self.suggested = suggested
        self.onLog = onLog
        self.onDelete = onDelete
        _reps = State(initialValue: existing?.set.reps ?? suggested)
        _note = State(initialValue: existing?.set.note ?? "")
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                SkillIcon(name: exercise.skillIcon, size: 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text(exercise.name).rsText(20, bold: true, color: RS.orange)
                    Text(existing == nil ? "Set \(setNumber)" : "Edit set \(setNumber)").rsSmall(16, color: RS.grey)
                }
                Spacer()
                Button("X") { dismiss() }.buttonStyle(StoneButton(color: RS.red))
            }

            HStack(spacing: 6) {
                Button("-") { reps = max(0, reps - 1) }.buttonStyle(StoneButton(color: RS.white))
                    .frame(width: 60)
                TextField("reps", value: $reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .rsText(40, bold: true)
                    .tint(RS.yellow)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .stoneSlot()
                Button("+") { reps += 1 }.buttonStyle(StoneButton(color: RS.white))
                    .frame(width: 60)
            }

            HStack(spacing: 6) {
                ForEach([6, 8, 10, 12, 15, 20], id: \.self) { n in
                    Button("\(n)") { reps = n }
                        .buttonStyle(StoneButton(color: reps == n ? RS.green : RS.white))
                }
            }

            TextField("Note (felt heavy, 90kg on this one)", text: $note)
                .textFieldStyle(.plain)
                .rsSmall(16)
                .tint(RS.yellow)
                .padding(8)
                .stoneSlot()

            if existing == nil {
                Button("Log & rest \(RestTimer.format(exercise.restSeconds))") { onLog(reps, note, true); dismiss() }
                    .buttonStyle(StoneButton(color: RS.orange, fill: true))
                Button("Log without timer") { onLog(reps, note, false); dismiss() }
                    .buttonStyle(StoneButton(fill: true))
            } else {
                Button("Save") { onLog(reps, note, false); dismiss() }
                    .buttonStyle(StoneButton(color: RS.orange, fill: true))
                Button("Delete set") { onDelete?(); dismiss() }
                    .buttonStyle(StoneButton(color: RS.red, fill: true))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RS.stoneImage().ignoresSafeArea())
        .presentationDetents([.height(existing == nil ? 440 : 420)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(0)
    }
}
