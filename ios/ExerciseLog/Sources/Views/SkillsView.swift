import SwiftUI

/// The skills panel: a tile per skill with its level and XP bar. Strength
/// and Agility open their own tabs; the rest push a log screen.
struct SkillsView: View {
    @EnvironmentObject private var store: LogStore
    @State private var path: [Skill] = []
    @State private var showSettings = false

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 8) {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(Skill.allCases) { skill in
                            Button { path = [skill] } label: { SkillTile(skill: skill) }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .stonePanel()

                    HStack {
                        Text("Total level").rsText(18, color: RS.orange)
                        Spacer()
                        Text("\(Skills.totalLevel(store.file))").rsText(22, bold: true)
                    }
                    .padding(10)
                    .stonePanel()
                }
                .padding(8)
            }
            .background(RS.darkImage().ignoresSafeArea())
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Skill.self) { skill in
                switch skill {
                case .strength: LogView()
                case .agility: QuestView()
                case .hitpoints: HitpointsView()
                default: SkillLogView(skill: skill)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Text(store.syncError == nil ? "Options" : "Options!").rsText(18, color: store.syncError == nil ? RS.yellow : RS.red)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            // `simctl launch ... -tab skills -skill hitpoints` for screenshots.
            .onAppear {
                let args = CommandLine.arguments
                if let i = args.firstIndex(of: "-skill"), i + 1 < args.count, let s = Skill(rawValue: args[i + 1]) { path = [s] }
            }
        }
    }
}

struct SkillTile: View {
    let skill: Skill
    @EnvironmentObject private var store: LogStore

    var body: some View {
        let xp = Skills.xp(skill, store.file)
        let level = Quest.level(forXP: xp)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                SkillIcon(name: skill.icon, size: 26)
                Text(skill.title).rsText(16, color: RS.orange)
                Spacer()
                Text("\(level)").rsText(24, bold: true)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(RS.stoneDarker)
                    Rectangle().fill(RS.green).frame(width: geo.size.width * Quest.levelProgress(xp: xp))
                }
            }
            .frame(height: 5)
            .bevel(inset: true)
            Text("\(xp.formatted()) xp").rsSmall(16, color: RS.grey)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RS.slot)
        .bevel(inset: true)
        .contentShape(Rectangle())
    }
}

/// Level, XP, bar and what is left to the next level.
struct SkillHeader: View {
    let skill: Skill
    @EnvironmentObject private var store: LogStore

    var body: some View {
        let xp = Skills.xp(skill, store.file)
        let level = Quest.level(forXP: xp)
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                SkillIcon(name: skill.icon, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(skill.title).rsText(16, color: RS.orange)
                    Text("Level \(level)").rsText(32, bold: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(xp.formatted()) xp").rsText(18, color: RS.white).monospacedDigit()
                    if level < 99 {
                        Text("\((Quest.xp(forLevel: level + 1) - xp).formatted()) to \(level + 1)").rsSmall(16, color: RS.grey)
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(RS.stoneDarker)
                    Rectangle().fill(RS.green).frame(width: geo.size.width * Quest.levelProgress(xp: xp))
                }
            }
            .frame(height: 8)
            .bevel(inset: true)
            Text(skill.blurb).rsSmall(16, color: RS.grey).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .stonePanel()
    }
}

/// "Congratulations, you just advanced a Cooking level."
struct LevelUpBanner: View {
    let levelUp: LevelUp
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                SkillIcon(name: levelUp.skill.icon, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Congratulations, you just advanced a \(levelUp.skill.title) level.")
                        .font(RS.font(18, bold: true)).foregroundStyle(RS.parchmentInk)
                    Text("Your \(levelUp.skill.title) level is now \(levelUp.level).")
                        .font(RS.font(16)).foregroundStyle(RS.parchmentInk)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .parchmentPanel()
            Button("Click here to continue") { onClose() }
                .buttonStyle(StoneButton(color: RS.orange, fill: true))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RS.stoneImage().ignoresSafeArea())
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(0)
        .onAppear { Jingle.levelUp(levelUp.skill) }
    }
}
