import SwiftUI

/// Edit the template rows: name, weekly sets, rest, order. Archiving hides
/// a row without losing its history.
struct ExerciseEditor: View {
    @EnvironmentObject private var store: LogStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [Exercise] = []
    @State private var showArchived = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($draft) { $ex in
                        if !ex.archived || showArchived {
                            row($ex)
                        }
                    }
                    .onMove { from, to in draft.move(fromOffsets: from, toOffset: to) }
                }
                Section {
                    Button {
                        draft.append(Exercise(id: Exercise.slug("new-\(UUID().uuidString.prefix(6))"),
                                              name: "", weeklySets: 5, restSeconds: 60, progression: ""))
                    } label: { Label("Add exercise", systemImage: "plus") }
                    Toggle("Show archived", isOn: $showArchived)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var cleaned = draft.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                        // A fresh row gets an id from its name so the JSON reads well.
                        for i in cleaned.indices where cleaned[i].id.hasPrefix("new-") {
                            var id = Exercise.slug(cleaned[i].name)
                            while cleaned.contains(where: { $0.id == id }) { id += "-2" }
                            cleaned[i].id = id
                        }
                        store.replaceExercises(cleaned)
                        dismiss()
                    }
                }
            }
            .onAppear { draft = store.file.exercises }
        }
        .presentationCornerRadius(0)
    }

    private func row(_ ex: Binding<Exercise>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name", text: ex.name).font(.headline)
            HStack(spacing: 12) {
                Stepper(value: ex.weeklySets, in: 1...30) {
                    Text("\(ex.wrappedValue.weeklySets) sets/wk").font(.subheadline).monospacedDigit()
                }
                .fixedSize()
                Picker("Rest", selection: ex.restSeconds) {
                    ForEach([30, 45, 60, 90, 120, 150, 180, 240, 300], id: \.self) { s in
                        Text(RestTimer.format(s)).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
            HStack {
                TextField("Progression", text: ex.progression).font(.subheadline)
                Toggle("Archived", isOn: ex.archived).labelsHidden().tint(Theme.outline)
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
        .opacity(ex.wrappedValue.archived ? 0.5 : 1)
    }
}
