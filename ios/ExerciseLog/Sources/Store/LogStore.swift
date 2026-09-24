import Foundation
import Combine

/// Owns the in-memory log, persists it to the app's Documents folder and
/// mirrors it to the sync folder.
///
/// Documents is the source of truth on the phone (it is visible in Files
/// too, thanks to `UIFileSharingEnabled`). The cloud copy is a mirror that
/// is pushed a moment after every edit and reconciled on foreground:
/// whichever copy carries the newer `updatedAt` wins wholesale. The phone is
/// the only regular writer, so this is enough; a script editing the file
/// while the app is closed is picked up on the next launch.
@MainActor
final class LogStore: ObservableObject {
    @Published private(set) var file: LogFile
    @Published private(set) var lastSync: Date?
    @Published private(set) var syncError: String?
    @Published private(set) var syncing = false

    private var saveTask: Task<Void, Never>?
    private var pushTask: Task<Void, Never>?

    static let localURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(CloudFolderSync.fileName)
    }()

    init() {
        if let data = try? Data(contentsOf: LogStore.localURL),
           let decoded = try? LogJSON.decoder.decode(LogFile.self, from: data) {
            file = decoded
        } else {
            file = LogFile()
        }
    }

    // MARK: - Mutation

    /// Every edit funnels through here so the timestamp, the local save and
    /// the cloud push cannot be forgotten.
    func mutate(_ body: (inout LogFile) -> Void) {
        var copy = file
        body(&copy)
        guard copy != file else { return }
        copy.updatedAt = Date()
        file = copy
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            self.saveLocal()
            self.schedulePush()
        }
    }

    private func saveLocal() {
        do {
            let data = try LogJSON.encoder.encode(file)
            try data.write(to: LogStore.localURL, options: .atomic)
        } catch {
            syncError = "Local save failed: \(error.localizedDescription)"
        }
    }

    private func schedulePush() {
        guard CloudFolderSync.isConfigured else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.push()
        }
    }

    // MARK: - Sync

    func push() {
        guard CloudFolderSync.isConfigured else { return }
        do {
            try CloudFolderSync.write(file)
            lastSync = Date()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    /// Foreground reconcile: adopt the cloud copy if it is newer, otherwise
    /// push ours so the folder is never behind.
    func sync() {
        guard CloudFolderSync.isConfigured else { return }
        syncing = true
        defer { syncing = false }
        do {
            if let remote = try CloudFolderSync.read() {
                if remote.updatedAt > file.updatedAt {
                    file = remote
                    saveLocal()
                } else if remote != file {
                    try CloudFolderSync.write(file)
                }
            } else {
                try CloudFolderSync.write(file)
            }
            lastSync = Date()
            syncError = nil
        } catch CloudFolderSync.CloudError.stillDownloading {
            syncError = CloudFolderSync.CloudError.stillDownloading.localizedDescription
        } catch {
            syncError = error.localizedDescription
        }
    }

    func chooseFolder(_ url: URL) {
        do {
            try CloudFolderSync.remember(url)
            syncError = nil
            sync()
        } catch {
            syncError = error.localizedDescription
        }
    }

    func forgetFolder() {
        CloudFolderSync.forget()
        lastSync = nil
        syncError = nil
    }

    /// A copy of the JSON for the share sheet.
    func exportData() -> Data? {
        try? LogJSON.encoder.encode(file)
    }

    // MARK: - Convenience

    func week(_ weekOf: String) -> Week? { file.week(of: weekOf) }

    func logSet(weekOf: String, day: Int, exerciseID: String, reps: Int, note: String = "") {
        mutate { f in
            let w = f.ensureWeek(weekOf)
            let d = day - 1
            var entry = f.weeks[w].days[d].entries[exerciseID] ?? Entry()
            entry.sets.append(SetRecord(reps: reps, loggedAt: Date(), note: note))
            f.weeks[w].days[d].entries[exerciseID] = entry
            if f.weeks[w].days[d].date == nil {
                f.weeks[w].days[d].date = LogDates.dayString(Date())
            }
        }
    }

    func updateSet(weekOf: String, day: Int, exerciseID: String, index: Int, reps: Int, note: String) {
        mutate { f in
            guard let w = f.weeks.firstIndex(where: { $0.weekOf == weekOf }) else { return }
            let d = day - 1
            guard var entry = f.weeks[w].days[d].entries[exerciseID], entry.sets.indices.contains(index) else { return }
            entry.sets[index].reps = reps
            entry.sets[index].note = note
            f.weeks[w].days[d].entries[exerciseID] = entry
        }
    }

    func deleteSet(weekOf: String, day: Int, exerciseID: String, index: Int) {
        mutate { f in
            guard let w = f.weeks.firstIndex(where: { $0.weekOf == weekOf }) else { return }
            let d = day - 1
            guard var entry = f.weeks[w].days[d].entries[exerciseID], entry.sets.indices.contains(index) else { return }
            entry.sets.remove(at: index)
            f.weeks[w].days[d].entries[exerciseID] = entry
        }
    }

    func toggleDone(weekOf: String, day: Int, exerciseID: String) {
        mutate { f in
            let w = f.ensureWeek(weekOf)
            let d = day - 1
            var entry = f.weeks[w].days[d].entries[exerciseID] ?? Entry()
            entry.done.toggle()
            f.weeks[w].days[d].entries[exerciseID] = entry
            if entry.done, f.weeks[w].days[d].date == nil {
                f.weeks[w].days[d].date = LogDates.dayString(Date())
            }
        }
    }

    func setDayDate(weekOf: String, day: Int, date: Date?) {
        mutate { f in
            let w = f.ensureWeek(weekOf)
            f.weeks[w].days[day - 1].date = date.map(LogDates.dayString)
        }
    }

    /// Progression shown on a week is that week's snapshot; editing it also
    /// moves the exercise's current value forward, so next week inherits it.
    func progression(weekOf: String, exerciseID: String) -> String {
        if let p = file.week(of: weekOf)?.progressions[exerciseID] { return p }
        return file.exercise(exerciseID)?.progression ?? ""
    }

    func setProgression(weekOf: String, exerciseID: String, text: String) {
        mutate { f in
            let w = f.ensureWeek(weekOf)
            f.weeks[w].progressions[exerciseID] = text
            if let i = f.exercises.firstIndex(where: { $0.id == exerciseID }) {
                f.exercises[i].progression = text
            }
        }
    }

    func setWeekNotes(weekOf: String, text: String) {
        mutate { f in
            let w = f.ensureWeek(weekOf)
            f.weeks[w].notes = text
        }
    }

    func replaceExercises(_ exercises: [Exercise]) {
        mutate { f in f.exercises = exercises }
    }

    /// Which "Day N" to open on: today's, else the first with nothing logged.
    func suggestedDay(weekOf: String) -> Int {
        let today = LogDates.dayString(Date())
        guard let week = file.week(of: weekOf) else { return 1 }
        if let d = week.days.first(where: { $0.date == today }) { return d.day }
        if let d = week.days.first(where: { $0.date == nil && $0.entries.values.allSatisfy { $0.sets.isEmpty } }) {
            return d.day
        }
        return week.days.last?.day ?? 1
    }
}
