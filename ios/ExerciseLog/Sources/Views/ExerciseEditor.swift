import SwiftUI

/// Edit the template rows: name, weekly sets, rest, rep range, ladder,
/// order. Archiving hides a row without losing its history.
struct ExerciseEditor: View {
    @EnvironmentObject private var store: LogStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [Exercise] = []
    @State private var showArchived = false

    var body: some View {
        NavigationStack {
            List {
                ForEach($draft) { $ex in
                    if !ex.archived || showArchived {
                        row($ex)
                            .listRowBackground(RS.stone)
                            .listRowSeparatorTint(RS.bevelDark)
                    }
                }
                .onMove { from, to in draft.move(fromOffsets: from, toOffset: to) }

                Section {
                    Button {
                        draft.append(Exercise(id: Exercise.slug("new-\(UUID().uuidString.prefix(6))"),
                                              name: "", weeklySets: 5, restSeconds: 60, progression: ""))
                    } label: { Text("+ Add exercise").rsText(18, color: RS.green) }
                    Toggle(isOn: $showArchived) { Text("Show archived").rsText(16, color: RS.white) }
                        .tint(RS.green)
                }
                .listRowBackground(RS.stoneDark)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(RS.darkImage().ignoresSafeArea())
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("Cancel").rsText(18, color: RS.red) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        var cleaned = draft.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                        for i in cleaned.indices where cleaned[i].id.hasPrefix("new-") {
                            var id = Exercise.slug(cleaned[i].name)
                            while cleaned.contains(where: { $0.id == id }) { id += "-2" }
                            cleaned[i].id = id
                        }
                        store.replaceExercises(cleaned)
                        dismiss()
                    } label: { Text("Save").rsText(18, color: RS.green) }
                }
            }
            .onAppear { draft = store.file.exercises }
        }
        .presentationCornerRadius(0)
    }

    private func ladderBinding(_ ex: Binding<Exercise>) -> Binding<String> {
        Binding(
            get: { ex.wrappedValue.ladder.joined(separator: ", ") },
            set: { ex.wrappedValue.ladder = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }

    private func row(_ ex: Binding<Exercise>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SkillIcon(name: ex.wrappedValue.skillIcon, size: 20)
                TextField("Name", text: ex.name).rsText(20, bold: true, color: RS.orange).tint(RS.yellow)
            }
            HStack(spacing: 12) {
                Stepper(value: ex.weeklySets, in: 1...30) {
                    Text("\(ex.wrappedValue.weeklySets) sets/wk").rsText(16, color: RS.white)
                }
                .fixedSize()
                Picker("Rest", selection: ex.restSeconds) {
                    ForEach([30, 45, 60, 90, 120, 150, 180, 240, 300], id: \.self) { s in
                        Text(RestTimer.format(s)).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .tint(RS.yellow)
                .fixedSize()
            }
            HStack(spacing: 12) {
                Stepper(value: ex.repMin, in: 1...50) {
                    Text("\(ex.wrappedValue.repMin) min").rsText(16, color: RS.white)
                }
                .fixedSize()
                Stepper(value: ex.repMax, in: 1...50) {
                    Text("\(ex.wrappedValue.repMax) max").rsText(16, color: RS.white)
                }
                .fixedSize()
            }
            HStack {
                TextField("Progression", text: ex.progression).rsSmall(16).tint(RS.yellow)
                Toggle("Archived", isOn: ex.archived).labelsHidden().tint(RS.grey).scaleEffect(0.8)
            }
            HStack(spacing: 8) {
                Text("Load step").rsSmall(16, color: RS.grey)
                TextField("2.5", value: ex.loadStep, format: .number)
                    .keyboardType(.decimalPad).rsSmall(16).tint(RS.yellow).frame(width: 56)
                    .padding(4).stoneSlot()
                TextField("Ladder: comma-separated harder forms", text: ladderBinding(ex))
                    .rsSmall(16).tint(RS.yellow)
            }
        }
        .padding(.vertical, 4)
        .opacity(ex.wrappedValue.archived ? 0.5 : 1)
    }
}
