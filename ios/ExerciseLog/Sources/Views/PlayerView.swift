import SwiftUI

/// The Player tab: the character, the music tab, and lifetime stats.
struct PlayerView: View {
    @EnvironmentObject private var store: LogStore
    @EnvironmentObject private var music: MusicPlayer
    @State private var showDesign = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    character
                    musicPanel
                    stats
                }
                .padding(8)
            }
            .background(RS.darkImage().ignoresSafeArea())
            .navigationTitle("Player")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDesign) { CharacterDesignView() }
            // `simctl launch ... -design` opens the design screen for screenshots.
            .onAppear { if CommandLine.arguments.contains("-design") { showDesign = true } }
        }
    }

    private var character: some View {
        HStack(spacing: 14) {
            AvatarView(avatar: store.avatar, scale: 5)
                .padding(8)
                .parchmentPanel()
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    SkillIcon(name: "Ironman_helm", size: 22)
                    Text(store.avatar.name).rsText(24, bold: true, color: RS.orange)
                }
                Text("Total level \(Skills.totalLevel(store.file))").rsText(16, color: RS.white)
                Text("Total sets \(totalSets)").rsText(16, color: RS.white)
                Button("Character design") { showDesign = true }
                    .buttonStyle(StoneButton())
            }
            Spacer()
        }
        .padding(10)
        .stonePanel()
    }

    private var musicPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Music").rsText(20, bold: true, color: RS.orange)
                Spacer()
                Button("|<") { music.previous() }.buttonStyle(StoneButton())
                Button(music.isPlaying ? "||" : ">") { music.toggle() }
                    .buttonStyle(StoneButton(color: music.isPlaying ? RS.green : RS.yellow))
                Button(">|") { music.next() }.buttonStyle(StoneButton())
            }
            if let t = music.current {
                Text(music.isPlaying ? "Now playing: \(t.title)" : "Selected: \(t.title)")
                    .rsSmall(16, color: music.isPlaying ? RS.green : RS.grey)
            }
            Text(music.defaultTrack.map { "Default: \($0.title). Tap the star on a track to change it." } ?? "No default. Tap the star on a track to open on it every launch.")
                .rsSmall(16, color: RS.grey)
            HStack(spacing: 8) {
                Toggle(isOn: $music.loopOne) { Text("Loop track").rsSmall(16, color: RS.white) }
                    .tint(RS.green)
                Toggle(isOn: $music.autoplay) { Text("Play on launch").rsSmall(16, color: RS.white) }
                    .tint(RS.green)
            }
            .onChange(of: music.loopOne) { _, _ in if music.isPlaying, let t = music.current { music.play(t) } }
            VStack(spacing: 0) {
                ForEach(music.tracks) { t in
                    HStack(spacing: 0) {
                        Button { music.play(t) } label: {
                            HStack {
                                Text(t.title).rsSmall(16, color: t == music.current ? RS.white : RS.green)
                                Spacer()
                                if t == music.current && music.isPlaying { Text("playing").rsSmall(16, color: RS.grey) }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button { music.setDefault(t) } label: {
                            Text(t == music.defaultTrack ? "★" : "☆")
                                .font(.system(size: 16))
                                .foregroundStyle(t == music.defaultTrack ? RS.yellow : RS.grey)
                                .frame(width: 36, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(t == music.defaultTrack ? "Default track" : "Set as default")
                    }
                    .background(t == music.current ? RS.stoneDark : Color.clear)
                }
            }
            .stoneSlot()
            Text("Tracks from the OSRS Wiki, for personal use. Keeps playing with the screen locked; the lock screen buttons work.")
                .rsSmall(16, color: RS.grey)
        }
        .padding(10)
        .stonePanel()
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adventure log").rsText(20, bold: true, color: RS.orange)
            ForEach(Skill.allCases) { sk in
                HStack(spacing: 6) {
                    SkillIcon(name: sk.icon, size: 18)
                    Text(sk.title).rsText(16, color: RS.orange)
                    Spacer()
                    Text("\(Skills.level(sk, store.file))").rsText(16, color: RS.white).monospacedDigit()
                    Text("\(Skills.xp(sk, store.file).formatted()) xp").rsSmall(16, color: RS.grey).monospacedDigit()
                }
            }
            line("Weeks trained", "\(store.file.weeks.filter { $0.hasAnySets }.count)")
            line("Sets logged", "\(totalSets)")
            line("Quests done", "\(store.quest.sessions.filter { $0.completed }.count)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .stonePanel()
    }

    private var totalSets: Int {
        store.file.weeks.reduce(0) { acc, w in acc + w.days.reduce(0) { $0 + $1.entries.values.reduce(0) { $0 + $1.sets.count } } }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).rsText(16, color: RS.orange)
            Spacer()
            Text(value).rsText(16, color: RS.white).monospacedDigit()
        }
    }
}
