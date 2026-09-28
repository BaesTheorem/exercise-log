import SwiftUI
import UIKit

/// Two tabs: the paper log, and the running quest. The last tab opened is
/// remembered, so a run day reopens on the quest. `simctl launch ... -tab
/// quest` opens a tab for screenshots.
struct RootView: View {
    @AppStorage("tab") private var tab = "skills"
    @EnvironmentObject private var store: LogStore

    var body: some View {
        TabView(selection: $tab) {
            SkillsView()
                .tabItem { Label("Skills", systemImage: "square.grid.2x2.fill") }
                .tag("skills")
            LogView()
                .tabItem { Label("Strength", systemImage: "dumbbell.fill") }
                .tag("strength")
            QuestView()
                .tabItem { Label("Quest", systemImage: "figure.run") }
                .tag("quest")
            PlayerView()
                .tabItem { Label("Player", systemImage: "person.fill") }
                .tag("player")
        }
        .onAppear { if tab == "log" { tab = "strength" } }
        .sheet(item: Binding(get: { store.levelUps.first }, set: { _ in })) { lu in
            LevelUpBanner(levelUp: lu) { store.levelUps.removeAll { $0 == lu } }
                .interactiveDismissDisabled()
        }
    }
}
