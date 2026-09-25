import SwiftUI

/// The paper log tab: week header, day tabs, one skill panel per exercise.
struct LogView: View {
    @EnvironmentObject private var store: LogStore
    @EnvironmentObject private var timer: RestTimer
    @State private var weekOf = LogDates.weekOf()
    @State private var day = 1
    @State private var showSettings = false
    @State private var showEditor = false
    @State private var showNotes = false
    @State private var showDatePicker = false
    @State private var notesDraft = ""
    @State private var dateDraft = Date()

    private var week: Week? { store.week(weekOf) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(store.file.activeExercises.enumerated()), id: \.element.id) { i, ex in
                            ExerciseRow(exercise: ex, weekOf: weekOf, day: day, striped: i % 2 == 1)
                        }
                        weekFooter
                    }
                    .padding(8)
                }
                TimerBar()
            }
            .background(RS.darkImage().ignoresSafeArea())
            .navigationTitle("Exercise Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showEditor = true } label: { Text("Skills").rsText(18) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Text(store.syncError == nil ? "Options" : "Options!").rsText(18, color: store.syncError == nil ? RS.yellow : RS.red)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showEditor) { ExerciseEditor() }
            .onAppear { day = store.suggestedDay(weekOf: weekOf) }
        }
    }

    private func go(_ delta: Int) {
        weekOf = delta == 0 ? LogDates.weekOf() : LogDates.shift(weekOf: weekOf, by: delta)
        day = store.suggestedDay(weekOf: weekOf)
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Button("<") { go(-1) }.buttonStyle(StoneButton())
                Spacer()
                VStack(spacing: 0) {
                    Text("Week of \(LogDates.humanWeek(weekOf))").rsText(22, bold: true, color: RS.orange)
                    if weekOf != LogDates.weekOf() {
                        Button("Back to this week") { go(0) }.buttonStyle(.plain).rsSmall(16, color: RS.cyan)
                    } else {
                        Text("this week").rsSmall(16, color: RS.grey)
                    }
                }
                Spacer()
                Button(">") { go(1) }.buttonStyle(StoneButton())
            }

            HStack(spacing: 4) {
                ForEach(1...Week.daysPerWeek, id: \.self) { d in
                    let date = week?.days[d - 1].date
                    Button {
                        day = d
                    } label: {
                        VStack(spacing: 0) {
                            Text("Day \(d)").rsText(18, bold: day == d, color: day == d ? RS.yellow : RS.white)
                            Text(date.map(LogDates.humanDay) ?? "-").rsSmall(16, color: day == d ? RS.green : RS.grey)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(day == d ? RS.stoneDark : RS.stone)
                        .bevel(inset: day == d)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Set date") {
                            dateDraft = date.flatMap(LogDates.date) ?? Date()
                            showDatePicker = true
                        }
                        if date != nil {
                            Button("Clear date", role: .destructive) {
                                store.setDayDate(weekOf: weekOf, day: d, date: nil)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .stonePanel()
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .sheet(isPresented: $showDatePicker) {
            VStack(spacing: 12) {
                Text("Date for Day \(day)").rsText(20, bold: true, color: RS.orange)
                DatePicker("", selection: $dateDraft, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(RS.yellow)
                Button("Save") {
                    store.setDayDate(weekOf: weekOf, day: day, date: dateDraft)
                    showDatePicker = false
                }
                .buttonStyle(StoneButton(color: RS.orange, fill: true))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(RS.stoneImage().ignoresSafeArea())
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(0)
        }
    }

    private var weekFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Week notes").rsText(18, bold: true, color: RS.orange)
                Spacer()
                Button("Edit") {
                    notesDraft = week?.notes ?? ""
                    showNotes = true
                }
                .buttonStyle(StoneButton())
            }
            Text((week?.notes.isEmpty ?? true) ? "Nothing yet." : week!.notes)
                .rsSmall(16, color: (week?.notes.isEmpty ?? true) ? RS.grey : RS.white)
            if let last = store.lastSync {
                Text("Synced \(last.formatted(date: .omitted, time: .shortened))").rsSmall(16, color: RS.grey)
            } else if !CloudFolderSync.isConfigured {
                Text("Not syncing. Pick a folder in Options so MIST can read this.").rsSmall(16, color: RS.cyan)
            }
            if let err = store.syncError {
                Text(err).rsSmall(16, color: RS.red)
            }
        }
        .padding(10)
        .stonePanel()
        .sheet(isPresented: $showNotes) {
            VStack(spacing: 12) {
                Text("Week notes").rsText(20, bold: true, color: RS.orange)
                TextEditor(text: $notesDraft)
                    .scrollContentBackground(.hidden)
                    .rsSmall(16)
                    .tint(RS.yellow)
                    .frame(minHeight: 160)
                    .padding(8)
                    .stoneSlot()
                Button("Save") {
                    store.setWeekNotes(weekOf: weekOf, text: notesDraft)
                    showNotes = false
                }
                .buttonStyle(StoneButton(color: RS.orange, fill: true))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(RS.stoneImage().ignoresSafeArea())
            .presentationDetents([.medium])
            .presentationCornerRadius(0)
        }
    }
}
