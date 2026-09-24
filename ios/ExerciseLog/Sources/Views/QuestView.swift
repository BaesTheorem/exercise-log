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
            .background(Theme.surface)
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
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AGILITY").font(.caption.weight(.semibold)).foregroundStyle(Theme.onSurfaceVariant)
                    Text("Level \(level)").font(.system(size: 34, weight: .semibold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(xp.formatted()) xp").font(.headline).monospacedDigit()
                    if level < 99 {
                        Text("\((Quest.xp(forLevel: level + 1) - xp).formatted()) to \(level + 1)")
                            .font(.caption).foregroundStyle(Theme.onSurfaceVariant).monospacedDigit()
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.surfaceHigh)
                    Rectangle().fill(Theme.primary).frame(width: geo.size.width * Quest.levelProgress(xp: xp))
                }
            }
            .frame(height: 8)
            .hairline()
            HStack {
                Text("\(quest.completedThisWeek()) of \(Plan.daysPerWeek) quests this week")
                Spacer()
                let free = quest.sessions.filter { !$0.isPlan }.count
                if free > 0 { Text("\(free) free run\(free == 1 ? "" : "s")") }
            }
            .font(.caption).foregroundStyle(Theme.onSurfaceVariant)
        }
        .padding(16)
        .background(Theme.surfaceLow)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.outlineVariant).frame(height: 1) }
    }

    // MARK: - Next quest

    @ViewBuilder
    private var nextQuestCard: some View {
        if let plan = quest.next {
            let chapter = Plan.chapters[plan.week - 1]
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("NEXT QUEST").font(.caption.weight(.semibold)).foregroundStyle(Theme.onSurfaceVariant)
                    Spacer()
                    Text("Week \(plan.week), day \(plan.day)").font(.caption).foregroundStyle(Theme.onSurfaceVariant)
                }
                Text(chapter.title).font(.title3.weight(.semibold))
                Text(plan.summary).font(.subheadline)
                HStack(spacing: 16) {
                    stat("Total", Quest.short(plan.totalSeconds))
                    stat("Jogging", Quest.short(plan.jogSeconds))
                    stat("Warm up", Quest.short(Plan.warmup.seconds))
                }
                lastAttemptLine
                Button {
                    start(plan)
                } label: {
                    Label("Start quest", systemImage: "figure.run")
                }
                .buttonStyle(FilledButton())
                .disabled(timer.isRunning)
            }
            .padding(16)
            .background(Theme.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.outlineVariant).frame(height: 1) }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plan complete").font(.title3.weight(.semibold))
                Text("Every chapter is done. Free runs still earn XP once Fitbit sees them, and any quest can be replayed from the map.")
                    .font(.subheadline).foregroundStyle(Theme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.outlineVariant).frame(height: 1) }
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
            Text("Last: week \(w) day \(d), \(when), \(status).")
                .font(.caption).foregroundStyle(Theme.onSurfaceVariant)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Theme.onSurfaceVariant)
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit()
        }
    }

    // MARK: - Map

    private var chapterMap: some View {
        LazyVStack(spacing: 0) {
            ForEach(1...Plan.weeks, id: \.self) { week in
                chapterRow(week)
            }
        }
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
                HStack(spacing: 12) {
                    Text("\(week)")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .frame(width: 28, height: 28)
                        .background(done ? Theme.primary : unlocked ? Theme.secondaryContainer : Theme.surfaceHigh)
                        .foregroundStyle(done ? Theme.onPrimary : unlocked ? Theme.onSecondaryContainer : Theme.outline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chapter.title).font(.subheadline.weight(.medium))
                            .foregroundStyle(unlocked ? Theme.onSurface : Theme.outline)
                        Text(Plan.session(week: week, day: 1).summary + (week >= 5 ? " and up" : ""))
                            .font(.caption).foregroundStyle(Theme.onSurfaceVariant).lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(1...Plan.daysPerWeek, id: \.self) { day in
                            node(week: week, day: day)
                        }
                    }
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(Theme.outline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 10) {
                    Text(unlocked ? chapter.story : "Locked. Finish the chapter before it.")
                        .font(.subheadline).foregroundStyle(unlocked ? Theme.onSurface : Theme.outline)
                    ForEach(1...Plan.daysPerWeek, id: \.self) { day in
                        dayLine(week: week, day: day, unlocked: unlocked)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            Rectangle().fill(Theme.outlineVariant).frame(height: 1)
        }
        .background(open ? Theme.surfaceLow : Theme.surface)
    }

    private func node(week: Int, day: Int) -> some View {
        let verified = quest.isVerified(week: week, day: day)
        let done = quest.isDone(week: week, day: day)
        let isNext = quest.next?.week == week && quest.next?.day == day
        return Rectangle()
            .fill(verified ? Theme.primary : done ? Theme.primaryContainer : isNext ? Theme.tertiaryContainer : Color.clear)
            .frame(width: 12, height: 12)
            .hairline(done || isNext ? Theme.primary : Theme.outlineVariant)
    }

    private func dayLine(week: Int, day: Int, unlocked: Bool) -> some View {
        let plan = Plan.session(week: week, day: day)
        let attempts = quest.sessions(week: week, day: day)
        let verified = quest.isVerified(week: week, day: day)
        let done = quest.isDone(week: week, day: day)
        return HStack(spacing: 10) {
            Image(systemName: verified ? "checkmark.seal.fill" : done ? "checkmark" : "circle")
                .font(.subheadline)
                .foregroundStyle(verified || done ? Theme.primary : Theme.outline)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text("Day \(day): \(plan.summary)").font(.subheadline)
                Text(attemptText(attempts, plan: plan)).font(.caption).foregroundStyle(Theme.onSurfaceVariant)
            }
            Spacer()
            if unlocked {
                Button(done ? "Again" : "Run") {
                    if done { confirmReplay = plan } else { start(plan) }
                }
                .buttonStyle(OutlinedButton())
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
            Text("How XP works").font(.subheadline.weight(.semibold))
            Text("Finish the warm-up: \(Quest.bootsOnXP). Finish the session: \(Quest.completeXP) more. Fitbit confirms it: \(Quest.verifiedXP) more, plus \(Quest.activeMinuteXP) per active minute. A run Fitbit saw that you never started here still earns \(Quest.freeRunXP) plus active minutes. Levels use the OSRS table.")
                .font(.caption).foregroundStyle(Theme.onSurfaceVariant)
            Text("Fitbit auto-detect is enough to verify a session. Starting a Run on the watch adds GPS distance and full active-minute credit.")
                .font(.caption).foregroundStyle(Theme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

extension QuestTimer {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
