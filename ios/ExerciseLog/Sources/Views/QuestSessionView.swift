import SwiftUI

/// The running screen: one big number, the segment you are in, the one that
/// comes next, and a bar with a tick per segment. Ends with the XP tally.
struct QuestSessionView: View {
    @EnvironmentObject private var timer: QuestTimer
    @EnvironmentObject private var store: LogStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmStop = false

    var body: some View {
        VStack(spacing: 0) {
            if timer.finished || timer.plan == nil {
                summary
            } else {
                running
            }
        }
        .background(RS.darkImage().ignoresSafeArea())
        .presentationCornerRadius(0)
    }

    // MARK: - Running

    private var running: some View {
        let seg = timer.current
        return VStack(spacing: 0) {
            HStack {
                SkillIcon(name: "Agility_icon", size: 22)
                if let p = timer.plan {
                    Text("Week \(p.week), day \(p.day)").rsText(18, color: RS.orange)
                }
                Spacer()
                Text("\(RestTimer.format(timer.elapsed)) / \(RestTimer.format(timer.total))")
                    .rsText(18, color: RS.white).monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .stonePanel()

            segmentBar

            Spacer()
            VStack(spacing: 6) {
                Text(seg?.label ?? "")
                    .rsText(28, bold: true, color: foreground(for: seg?.kind))
                Text(RestTimer.format(timer.segmentRemaining))
                    .rsText(96, bold: true, color: foreground(for: seg?.kind))
                    .monospacedDigit()
                if let next = timer.next {
                    Text("Next: \(next.label.lowercased()) \(Quest.short(next.seconds))")
                        .rsText(18, color: RS.white)
                } else {
                    Text("Last segment").rsText(18, color: RS.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(background(for: seg?.kind))
            .bevel()
            .padding(8)
            Spacer()

            HStack(spacing: 12) {
                Button("Skip segment") { timer.skipSegment() }
                    .buttonStyle(StoneButton())
                Spacer()
                Button("End run") { confirmStop = true }
                    .buttonStyle(StoneButton(color: RS.red))
            }
            .padding(16)
            .confirmationDialog("End the run early?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("End run", role: .destructive) { timer.stop() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Time already run still counts. The quest stays open to try again.")
            }
        }
    }

    private var segmentBar: some View {
        GeometryReader { geo in
            let total = max(1, timer.total)
            HStack(spacing: 1) {
                ForEach(Array(timer.segments.enumerated()), id: \.offset) { i, seg in
                    Rectangle()
                        .fill(i < timer.currentIndex ? RS.green
                              : i == timer.currentIndex ? RS.green.opacity(0.5)
                              : background(for: seg.kind))
                        .frame(width: max(2, geo.size.width * Double(seg.seconds) / Double(total)))
                }
            }
            .overlay(alignment: .leading) {
                Rectangle().fill(RS.yellow).frame(width: 2)
                    .offset(x: geo.size.width * timer.progress)
            }
        }
        .frame(height: 12)
        .bevel(inset: true)
        .padding(.horizontal, 8)
    }

    private func background(for kind: Segment.Kind?) -> Color {
        switch kind {
        case .jog: return Color(hex: 0x5A2A1A)
        case .walk: return RS.stone
        default: return RS.stoneDark
        }
    }

    private func foreground(for kind: Segment.Kind?) -> Color {
        switch kind {
        case .jog: return RS.orange
        case .walk: return RS.green
        default: return RS.yellow
        }
    }

    // MARK: - Summary

    private var summary: some View {
        let session = store.quest.sessions.first { $0.id == timer.sessionID }
        let xp = session.map { Quest.xp(for: $0) } ?? 0
        let completed = session?.completed ?? false
        return VStack(spacing: 16) {
            Spacer()
            SkillIcon(name: "Agility_icon", size: 64)
            Text(completed ? "Quest complete!" : "Run ended").rsText(32, bold: true, color: RS.orange)
            VStack(spacing: 2) {
                Text("+\(xp) xp").rsText(40, bold: true).monospacedDigit()
                Text("Level \(store.quest.level), \(store.quest.xp.formatted()) xp total")
                    .rsSmall(16, color: RS.grey)
            }
            .padding(12)
            .parchmentPanel()
            .onAppear { if completed { Jingle.questLevelUp() } }
            if let s = session {
                HStack(spacing: 24) {
                    stat("Ran", RestTimer.format(s.elapsedSeconds))
                    stat("Jogged", RestTimer.format(s.jogSecondsDone))
                }
            }
            Text(completed
                 ? "If you started a Run on the watch, end it. The Mac checks Fitbit within the hour and adds \(Quest.verifiedXP) xp plus active minutes when it matches."
                 : "Everything run so far is banked. The quest stays on the map.")
                .rsSmall(16, color: RS.grey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Done") {
                timer.dismiss()
                dismiss()
            }
            .buttonStyle(StoneButton(color: RS.orange, fill: true))
            .padding(16)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(label).rsSmall(16, color: RS.orange)
            Text(value).rsText(22, bold: true, color: RS.white).monospacedDigit()
        }
    }
}
