import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LogStore
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    panel("Sync") {
                        if CloudFolderSync.isConfigured {
                            line("Folder", CloudFolderSync.displayName ?? "chosen")
                            if let last = store.lastSync {
                                line("Last sync", last.formatted(date: .abbreviated, time: .shortened))
                            }
                            Button("Sync now") { store.sync() }.buttonStyle(StoneButton(fill: true))
                            Button("Change folder") { showPicker = true }.buttonStyle(StoneButton(fill: true))
                            Button("Stop syncing") { store.forgetFolder() }.buttonStyle(StoneButton(color: RS.red, fill: true))
                        } else {
                            Button("Choose sync folder") { showPicker = true }.buttonStyle(StoneButton(color: RS.orange, fill: true))
                        }
                        if let err = store.syncError {
                            Text(err).rsSmall(16, color: RS.red)
                        }
                        Text("Pick a folder in iCloud Drive or Google Drive. The app keeps \(CloudFolderSync.fileName) there, and the same file appears on the Mac for MIST to read. The app's own Documents folder is also visible in Files.")
                            .rsSmall(16, color: RS.grey)
                    }

                    panel("Data") {
                        Button("Export JSON") {
                            guard let data = store.exportData() else { return }
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent(CloudFolderSync.fileName)
                            try? data.write(to: url)
                            shareURL = url
                        }
                        .buttonStyle(StoneButton(fill: true))
                        line("Exercises", "\(store.file.activeExercises.count)")
                        line("Weeks logged", "\(store.file.weeks.filter { $0.hasAnySets }.count)")
                    }

                    panel("Timer") {
                        Button("Allow notifications") { RestTimer.requestPermission() }.buttonStyle(StoneButton(fill: true))
                        Text("The rest timer fires a notification when it ends, so it works with the screen locked.")
                            .rsSmall(16, color: RS.grey)
                    }

                    panel("About") {
                        line("Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        Text("A digital copy of the paper exercise log: one page per week, three days, reps per set, weekly set targets and rest per exercise. Skinned after Old School RuneScape; fonts from RuneLite, icons from the OSRS Wiki.")
                            .rsSmall(16, color: RS.grey)
                    }
                }
                .padding(8)
            }
            .background(RS.darkImage().ignoresSafeArea())
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { Text("Done").rsText(18) } }
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

    private func panel<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).rsText(20, bold: true, color: RS.orange)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .stonePanel()
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).rsText(16, color: RS.orange)
            Spacer()
            Text(value).rsText(16, color: RS.white)
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
