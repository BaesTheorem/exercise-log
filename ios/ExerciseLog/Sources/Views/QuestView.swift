import SwiftUI

/// The quest tab: the Agility level, the next quest, and the chapter map.
struct QuestView: View {
    @EnvironmentObject private var store: LogStore
    @EnvironmentObject private var timer: QuestTimer
    @State private var openChapter: Int?
    @State private var showSession = false
    @State private var confirmReplay: PlanSession?

    private var quest: QuestState { store.quest }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    levelHeader
                    nextQuestCard
                    chapterMap
                    footer
                }
            }
            .background(RS.darkImage().ignoresSafeArea())
            .navigationTitle("Quest")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                store.closeStaleQuestSessions()
                openChapter = quest.currentWeek
            }
            .onChange(of: timer.isRunning) { _, running in
                if running { showSession = true }
            }
            .fullScreenCover(isPresented: $showSession) {
                QuestSessionView()
            }
            .alert("Run it again?", isPresented: Binding(get: { confirmReplay != nil }, set: { if !$0 { confirmReplay = nil } })) {
                Button("Start") { if let p = confirmReplay { start(p) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let p = confirmReplay {
                    Text("Week \(p.week), day \(p.day) is already done. A repeat still earns XP.")
                }
            }
        }
    }

    private func start(_ plan: PlanSession) {
        QuestTimer.requestPermission()
        let id = store.startQuestSession(week: plan.week, day: plan.day)
        timer.onEnd = { [weak store] sid, elapsed, jog, completed in
            store?.endQuestSession(id: sid, elapsed: elapsed, jogSeconds: jog, completed: completed)
        }
        timer.start(plan, sessionID: id)
        showSession = true
    }

    // MARK: - Header

    private var levelHeader: some View {
        let xp = quest.xp
        let level = quest.level
        return VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                SkillIcon(name: "Agility_icon", size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Agility").rsText(16, color: RS.orange)
                    Text("Level \(level)").rsText(32, bold: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(xp.formatted()) xp").rsText(18, color: RS.white).monospacedDigit()
                    if level < 99 {
                        Text("\((Quest.xp(forLevel: level + 1) - xp).formatted()) to \(level + 1)")
                            .rsSmall(16, color: RS.grey).monospacedDigit()
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
            HStack {
                Text("\(quest.completedThisWeek()) of \(Plan.daysPerWeek) quests this week").rsSmall(16, color: RS.grey)
                Spacer()
                let free = quest.sessions.filter { !$0.isPlan }.count
                if free > 0 { Text("\(free) free run\(free == 1 ? "" : "s")").rsSmall(16, color: RS.cyan) }
            }
        }
        .padding(10)
        .stonePanel()
        .padding(8)
    }

    // MARK: - Next quest

    @ViewBuilder
    private var nextQuestCard: some View {
        if let plan = quest.next {
            let chapter = Plan.chapters[plan.week - 1]
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Next quest").rsText(16, color: RS.orange)
                    Spacer()
                    Text("Week \(plan.week), day \(plan.day)").rsSmall(16, color: RS.grey)
                }
                Text(chapter.title).rsText(22, bold: true)
                Text(plan.summary).rsSmall(16)
                HStack(spacing: 16) {
                    stat("Total", Quest.short(plan.totalSeconds))
                    stat("Jogging", Quest.short(plan.jogSeconds))
                    stat("Warm up", Quest.short(Plan.warmup.seconds))
                }
                lastAttemptLine
                Button("Start quest") { start(plan) }
                    .buttonStyle(StoneButton(color: RS.orange, fill: true))
                    .disabled(timer.isRunning)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .parchmentPanel()
            .padding(.horizontal, 8)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quest complete!").rsText(22, bold: true, color: RS.orange)
                Text("Every chapter is done. Free runs still earn XP once Fitbit sees them, and any quest can be replayed from the map.")
                    .rsSmall(16, color: RS.grey)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .stonePanel()
            .padding(.horizontal, 8)
        }
    }

    @ViewBuilder
    private var lastAttemptLine: some View {
        if let last = quest.lastAttempt, let w = last.week, let d = last.day {
            let when = last.startedAt.formatted(date: .abbreviated, time: .shortened)
            let status: String = last.endedAt == nil ? "in progress"
                : last.isVerified ? "verified by Fitbit"
                : last.completed ? "done, waiting for Fitbit"
                : "stopped at \(Quest.short(last.elapsedSeconds))"
            Text("Last: week \(w) day \(d), \(when), \(status).").rsSmall(16, color: RS.grey)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).rsSmall(16, color: RS.orange)
            Text(value).rsText(18, color: RS.white).monospacedDigit()
        }
    }

    // MARK: - Map

    private var chapterMap: some View {
        LazyVStack(spacing: 4) {
            ForEach(1...Plan.weeks, id: \.self) { week in
                chapterRow(week)
            }
        }
        .padding(8)
    }

    private func chapterRow(_ week: Int) -> some View {
        let chapter = Plan.chapters[week - 1]
        let unlocked = week <= quest.currentWeek
        let done = quest.chapterDone(week)
        let open = openChapter == week
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.none) { openChapter = open ? nil : week }
            } label: {
                HStack(spacing: 10) {
                    Text("\(week)")
                        .rsText(18, bold: true, color: done ? RS.green : unlocked ? RS.yellow : RS.grey)
                        .monospacedDigit()
                        .frame(width: 30, height: 30)
                        .stoneSlot()
                    VStack(alignment: .leading, spacing: 0) {
                        Text(chapter.title).rsText(18, color: done ? RS.green : unlocked ? RS.white : RS.grey)
                        Text(Plan.session(week: week, day: 1).summary + (week >= 5 ? " and up" : ""))
                            .rsSmall(16, color: RS.grey).lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(1...Plan.daysPerWeek, id: \.self) { day in
                            node(week: week, day: day)
                        }
                    }
                    Text(open ? "-" : "+").rsText(18, color: RS.yellow)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    Text(unlocked ? chapter.story : "Locked. Finish the chapter before it.")
                        .font(RS.font(16)).foregroundStyle(RS.parchmentInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .parchmentPanel()
                    ForEach(1...Plan.daysPerWeek, id: \.self) { day in
                        dayLine(week: week, day: day, unlocked: unlocked)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .stonePanel()
    }

    private func node(week: Int, day: Int) -> some View {
        let verified = quest.isVerified(week: week, day: day)
        let done = quest.isDone(week: week, day: day)
        let isNext = quest.next?.week == week && quest.next?.day == day
        return Rectangle()
            .fill(verified ? RS.green : done ? RS.green.opacity(0.5) : isNext ? RS.yellow : RS.stoneDarker)
            .frame(width: 12, height: 12)
            .bevel(inset: true)
    }

    private func dayLine(week: Int, day: Int, unlocked: Bool) -> some View {
        let plan = Plan.session(week: week, day: day)
        let attempts = quest.sessions(week: week, day: day)
        let verified = quest.isVerified(week: week, day: day)
        let done = quest.isDone(week: week, day: day)
        return HStack(spacing: 8) {
            Text(verified ? "✓✓" : done ? "✓" : "·")
                .rsText(16, bold: true, color: verified || done ? RS.green : RS.grey)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text("Day \(day): \(plan.summary)").rsSmall(16, color: RS.white)
                Text(attemptText(attempts, plan: plan)).rsSmall(16, color: RS.grey)
            }
            Spacer()
            if unlocked {
                Button(done ? "Again" : "Run") {
                    if done { confirmReplay = plan } else { start(plan) }
                }
                .buttonStyle(StoneButton(color: done ? RS.white : RS.green))
                .disabled(timer.isRunning)
            }
        }
    }

    private func attemptText(_ attempts: [QuestSession], plan: PlanSession) -> String {
        guard let best = attempts.max(by: { Quest.xp(for: $0) < Quest.xp(for: $1) }) else {
            return "\(Quest.short(plan.totalSeconds)) total, \(Quest.short(plan.jogSeconds)) jogging"
        }
        var parts = ["\(Quest.xp(for: best)) xp"]
        if let v = best.verification {
            parts.append(String(format: "%.2f km", v.distanceKm))
            if let hr = v.averageHeartRate { parts.append("\(hr) bpm") }
        } else if best.completed {
            parts.append("waiting for Fitbit")
        } else if best.endedAt != nil {
            parts.append("stopped at \(Quest.short(best.elapsedSeconds))")
        }
        if attempts.count > 1 { parts.append("\(attempts.count) attempts") }
        return parts.joined(separator: ", ")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How XP works").rsText(18, bold: true, color: RS.orange)
            Text("Finish the warm-up: \(Quest.bootsOnXP). Finish the session: \(Quest.completeXP) more. Fitbit confirms it: \(Quest.verifiedXP) more, plus \(Quest.activeMinuteXP) per active minute. A run Fitbit saw that you never started here still earns \(Quest.freeRunXP) plus active minutes. Levels use the OSRS table.")
                .rsSmall(16, color: RS.grey)
            Text("Fitbit auto-detect is enough to verify a session. Starting a Run on the watch adds GPS distance and full active-minute credit.")
                .rsSmall(16, color: RS.grey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .stonePanel()
        .padding(8)
    }
}

extension QuestTimer {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
