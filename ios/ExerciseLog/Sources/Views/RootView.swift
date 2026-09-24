import SwiftUI

/// Two tabs: the paper log, and the running quest. The last tab opened is
/// remembered, so a run day reopens on the quest.
struct RootView: View {
    @AppStorage("tab") private var tab = "log"

    var body: some View {
        TabView(selection: $tab) {
            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
                .tag("log")
            QuestView()
                .tabItem { Label("Quest", systemImage: "figure.run") }
                .tag("quest")
        }
    }
}
