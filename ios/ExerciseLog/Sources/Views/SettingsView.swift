import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LogStore
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if CloudFolderSync.isConfigured {
                        LabeledContent("Folder", value: CloudFolderSync.displayName ?? "chosen")
                        if let last = store.lastSync {
                            LabeledContent("Last sync", value: last.formatted(date: .abbreviated, time: .shortened))
                        }
                        Button("Sync now") { store.sync() }
                        Button("Change folder") { showPicker = true }
                        Button("Stop syncing", role: .destructive) { store.forgetFolder() }
                    } else {
                        Button("Choose sync folder") { showPicker = true }
                    }
                    if let err = store.syncError {
                        Text(err).font(.footnote).foregroundStyle(Theme.error)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Pick a folder in iCloud Drive or Google Drive. The app keeps \(CloudFolderSync.fileName) there, and the same file appears on the Mac for MIST to read. The app's own Documents folder is also visible in Files as a fallback.")
                }

                Section("Data") {
                    Button("Export JSON") {
                        guard let data = store.exportData() else { return }
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(CloudFolderSync.fileName)
                        try? data.write(to: url)
                        shareURL = url
                    }
                    LabeledContent("Exercises", value: "\(store.file.activeExercises.count)")
                    LabeledContent("Weeks logged", value: "\(store.file.weeks.filter { $0.hasAnySets }.count)")
                }

                Section("Timer") {
                    Button("Allow notifications") { RestTimer.requestPermission() }
                    Text("The rest timer fires a notification when it ends, so it works with the screen locked.")
                        .font(.footnote).foregroundStyle(Theme.onSurfaceVariant)
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                    Text("A digital copy of the paper exercise log: one page per week, three days, reps per set, weekly set targets and rest per exercise.")
                        .font(.footnote).foregroundStyle(Theme.onSurfaceVariant)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPicker) {
                FolderPicker { url in store.chooseFolder(url) }
                    .ignoresSafeArea()
            }
            .sheet(item: $shareURL) { url in
                ShareSheet(items: [url])
            }
        }
        .presentationCornerRadius(0)
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
