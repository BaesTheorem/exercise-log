import SwiftUI
import UIKit

/// Two tabs: the skills panel (every log lives under its skill) and the
/// player. `simctl launch ... -tab player` opens a tab for screenshots.
struct RootView: View {
    @AppStorage("tab") private var tab = "skills"
    @EnvironmentObject private var store: LogStore

    var body: some View {
        TabView(selection: $tab) {
            SkillsView()
                .tabItem { Label("Skills", systemImage: "square.grid.2x2.fill") }
                .tag("skills")
            PlayerView()
                .tabItem { Label("Player", systemImage: "person.fill") }
                .tag("player")
        }
        .onAppear { if tab != "player" { tab = "skills" } }
        .sheet(item: Binding(get: { store.levelUps.first }, set: { _ in })) { lu in
            LevelUpBanner(levelUp: lu) { store.levelUps.removeAll { $0 == lu } }
                .interactiveDismissDisabled()
        }
    }
}
