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
    @FocusState private var repsFocused: Bool

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
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.headline)
                    Text(existing == nil ? "Set \(setNumber)" : "Edit set \(setNumber)")
                        .font(.caption).foregroundStyle(Theme.onSurfaceVariant)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(OutlinedButton(tint: Theme.onSurfaceVariant))
            }

            HStack(spacing: 0) {
                Button { reps = max(0, reps - 1) } label: {
                    Image(systemName: "minus").frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)
                .hairline()
                TextField("reps", value: $reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 40, weight: .medium, design: .monospaced))
                    .focused($repsFocused)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .hairline()
                Button { reps += 1 } label: {
                    Image(systemName: "plus").frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)
                .hairline()
            }
            .foregroundStyle(Theme.onSurface)

            HStack(spacing: 8) {
                ForEach([6, 8, 10, 12, 15, 20], id: \.self) { n in
                    Button("\(n)") { reps = n }
                        .buttonStyle(OutlinedButton(tint: reps == n ? Theme.primary : Theme.onSurfaceVariant))
                }
            }

            TextField("Note (e.g. felt heavy, 90kg on this one)", text: $note)
                .textFieldStyle(.plain)
                .padding(10)
                .hairline()

            if existing == nil {
                Button("Log & rest \(RestTimer.format(exercise.restSeconds))") {
                    onLog(reps, note, true); dismiss()
                }
                .buttonStyle(FilledButton())
                Button("Log without timer") { onLog(reps, note, false); dismiss() }
                    .buttonStyle(OutlinedButton())
            } else {
                Button("Save") { onLog(reps, note, false); dismiss() }
                    .buttonStyle(FilledButton())
                Button("Delete set") { onDelete?(); dismiss() }
                    .buttonStyle(OutlinedButton(tint: Theme.error))
            }
        }
        .padding(20)
        .background(Theme.surface)
        .presentationDetents([.height(existing == nil ? 420 : 400)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(0)
    }

}
