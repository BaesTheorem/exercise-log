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
        .background(Theme.surface)
        .presentationCornerRadius(0)
    }

    // MARK: - Running

    private var running: some View {
        let seg = timer.current
        return VStack(spacing: 0) {
            HStack {
                if let p = timer.plan {
                    Text("Week \(p.week), day \(p.day)").font(.subheadline.weight(.medium))
                }
                Spacer()
                Text("\(RestTimer.format(timer.elapsed)) / \(RestTimer.format(timer.total))")
                    .font(.subheadline).monospacedDigit().foregroundStyle(Theme.onSurfaceVariant)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.surfaceLow)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.outlineVariant).frame(height: 1) }

            segmentBar

            Spacer()
            VStack(spacing: 8) {
                Text((seg?.label ?? "").uppercased())
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(foreground(for: seg?.kind))
                Text(RestTimer.format(timer.segmentRemaining))
                    .font(.system(size: 96, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(foreground(for: seg?.kind))
                if let next = timer.next {
                    Text("Next: \(next.label.lowercased()) \(Quest.short(next.seconds))")
                        .font(.subheadline).foregroundStyle(foreground(for: seg?.kind).opacity(0.8))
                } else {
                    Text("Last segment").font(.subheadline).foregroundStyle(foreground(for: seg?.kind).opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(background(for: seg?.kind))
            Spacer()

            HStack(spacing: 12) {
                Button("Skip segment") { timer.skipSegment() }
                    .buttonStyle(OutlinedButton())
                Spacer()
                Button("End run") { confirmStop = true }
                    .buttonStyle(OutlinedButton(tint: Theme.error))
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
                        .fill(i < timer.currentIndex ? Theme.primary
                              : i == timer.currentIndex ? Theme.primary.opacity(0.5)
                              : background(for: seg.kind))
                        .frame(width: max(2, geo.size.width * Double(seg.seconds) / Double(total)))
                }
            }
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.onSurface).frame(width: 2)
                    .offset(x: geo.size.width * timer.progress)
            }
        }
        .frame(height: 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.outlineVariant).frame(height: 1) }
    }

    private func background(for kind: Segment.Kind?) -> Color {
        switch kind {
        case .jog: return Theme.primaryContainer
        case .walk: return Theme.secondaryContainer
        default: return Theme.surfaceHigh
        }
    }

    private func foreground(for kind: Segment.Kind?) -> Color {
        switch kind {
        case .jog: return Theme.onPrimaryContainer
        case .walk: return Theme.onSecondaryContainer
        default: return Theme.onSurface
        }
    }

    // MARK: - Summary

    private var summary: some View {
        let session = store.quest.sessions.first { $0.id == timer.sessionID }
        let xp = session.map { Quest.xp(for: $0) } ?? 0
        let completed = session?.completed ?? false
        return VStack(spacing: 20) {
            Spacer()
            Image(systemName: completed ? "checkmark.seal" : "flag")
                .font(.system(size: 56)).foregroundStyle(Theme.primary)
            Text(completed ? "Quest complete" : "Run ended").font(.title2.weight(.semibold))
            VStack(spacing: 6) {
                Text("+\(xp) xp").font(.system(size: 40, weight: .medium, design: .rounded)).monospacedDigit()
                Text("Level \(store.quest.level), \(store.quest.xp.formatted()) xp total")
                    .font(.subheadline).foregroundStyle(Theme.onSurfaceVariant)
            }
            if let s = session {
                HStack(spacing: 24) {
                    stat("Ran", RestTimer.format(s.elapsedSeconds))
                    stat("Jogged", RestTimer.format(s.jogSecondsDone))
                }
            }
            Text(completed
                 ? "If you started a Run on the watch, end it. The Mac checks Fitbit within the hour and adds \(Quest.verifiedXP) xp plus active minutes when it matches."
                 : "Everything run so far is banked. The quest stays on the map.")
                .font(.footnote).foregroundStyle(Theme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Done") {
                timer.dismiss()
                dismiss()
            }
            .buttonStyle(FilledButton())
            .padding(16)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Theme.onSurfaceVariant)
            Text(value).font(.headline).monospacedDigit()
        }
    }
}
