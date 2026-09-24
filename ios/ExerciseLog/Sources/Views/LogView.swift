import SwiftUI

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
    private var dayDate: String? { week?.days[day - 1].date }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.file.activeExercises.enumerated()), id: \.element.id) { i, ex in
                            ExerciseRow(exercise: ex, weekOf: weekOf, day: day, striped: i % 2 == 1)
                        }
                        weekFooter
                    }
                }
                .background(Theme.surface)
                TimerBar()
            }
            .background(Theme.surface)
            .navigationTitle("Exercise Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showEditor = true } label: { Image(systemName: "list.bullet") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: store.syncError == nil ? "gearshape" : "exclamationmark.triangle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showEditor) { ExerciseEditor() }
            .onAppear { day = store.suggestedDay(weekOf: weekOf) }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Button { weekOf = LogDates.shift(weekOf: weekOf, by: -1); day = store.suggestedDay(weekOf: weekOf) } label: {
                    Image(systemName: "chevron.left").frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(spacing: 1) {
                    Text("Week of \(LogDates.humanWeek(weekOf))").font(.headline)
                    if weekOf != LogDates.weekOf() {
                        Button("Today") { weekOf = LogDates.weekOf(); day = store.suggestedDay(weekOf: weekOf) }
                            .font(.caption).foregroundStyle(Theme.primary)
                    } else {
                        Text("this week").font(.caption).foregroundStyle(Theme.onSurfaceVariant)
                    }
                }
                Spacer()
                Button { weekOf = LogDates.shift(weekOf: weekOf, by: 1); day = store.suggestedDay(weekOf: weekOf) } label: {
                    Image(systemName: "chevron.right").frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            HStack(spacing: 0) {
                ForEach(1...Week.daysPerWeek, id: \.self) { d in
                    let date = week?.days[d - 1].date
                    Button {
                        day = d
                    } label: {
                        VStack(spacing: 2) {
                            Text("Day \(d)").font(.subheadline.weight(day == d ? .semibold : .regular))
                            Text(date.map(LogDates.humanDay) ?? "—").font(.caption2)
                                .foregroundStyle(day == d ? Theme.onSecondaryContainer : Theme.onSurfaceVariant)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(day == d ? Theme.secondaryContainer : Color.clear)
                        .foregroundStyle(day == d ? Theme.onSecondaryContainer : Theme.onSurface)
                    }
                    .buttonStyle(.plain)
                    .hairline()
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
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            Rectangle().fill(Theme.outlineVariant).frame(height: 1)
        }
        .background(Theme.surfaceLow)
        .sheet(isPresented: $showDatePicker) {
            VStack(spacing: 16) {
                Text("Date for Day \(day)").font(.headline)
                DatePicker("", selection: $dateDraft, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                Button("Save") {
                    store.setDayDate(weekOf: weekOf, day: day, date: dateDraft)
                    showDatePicker = false
                }
                .buttonStyle(FilledButton())
            }
            .padding(20)
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(0)
        }
    }

    private var weekFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Week notes").font(.subheadline.weight(.semibold))
                Spacer()
                Button("Edit") {
                    notesDraft = week?.notes ?? ""
                    showNotes = true
                }
                .buttonStyle(OutlinedButton())
            }
            Text((week?.notes.isEmpty ?? true) ? "Nothing yet." : week!.notes)
                .font(.subheadline)
                .foregroundStyle((week?.notes.isEmpty ?? true) ? Theme.outline : Theme.onSurface)
            if let last = store.lastSync {
                Text("Synced \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(Theme.onSurfaceVariant)
            } else if !CloudFolderSync.isConfigured {
                Text("Not syncing. Pick a folder in settings so MIST can read this.")
                    .font(.caption).foregroundStyle(Theme.onSurfaceVariant)
            }
            if let err = store.syncError {
                Text(err).font(.caption).foregroundStyle(Theme.error)
            }
        }
        .padding(16)
        .sheet(isPresented: $showNotes) {
            VStack(spacing: 16) {
                Text("Week notes").font(.headline)
                TextEditor(text: $notesDraft)
                    .frame(minHeight: 160)
                    .padding(8)
                    .hairline()
                Button("Save") {
                    store.setWeekNotes(weekOf: weekOf, text: notesDraft)
                    showNotes = false
                }
                .buttonStyle(FilledButton())
            }
            .padding(20)
            .presentationDetents([.medium])
            .presentationCornerRadius(0)
        }
    }
}
