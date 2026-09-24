import SwiftUI

/// The rest countdown pinned above the bottom edge while a rest is running,
/// and a one-tap "rest over" strip once it ends.
struct TimerBar: View {
    @EnvironmentObject private var timer: RestTimer

    var body: some View {
        if timer.isRunning {
            VStack(spacing: 0) {
                Rectangle().fill(Theme.outlineVariant).frame(height: 1)
                GeometryReader { geo in
                    Rectangle()
                        .fill(Theme.primary)
                        .frame(width: geo.size.width * timer.progress, height: 3)
                }
                .frame(height: 3)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REST").font(.caption2.weight(.semibold)).foregroundStyle(Theme.onSurfaceVariant)
                        Text(timer.label).font(.subheadline).lineLimit(1)
                    }
                    Spacer()
                    Text(RestTimer.format(timer.remaining))
                        .font(.system(size: 34, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(Theme.onSurface)
                    Button("+30s") { timer.add(seconds: 30) }
                        .buttonStyle(OutlinedButton())
                    Button {
                        timer.stop()
                    } label: {
                        Image(systemName: "xmark").font(.body.weight(.semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(OutlinedButton(tint: Theme.onSurfaceVariant))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.surfaceLow)
            }
        } else if timer.justFinished {
            HStack {
                Image(systemName: "checkmark").font(.body.weight(.bold))
                Text("Rest over. Go.").font(.subheadline.weight(.semibold))
                Spacer()
                Button("OK") { timer.acknowledge() }
                    .buttonStyle(OutlinedButton(tint: Theme.onPrimaryContainer))
            }
            .foregroundStyle(Theme.onPrimaryContainer)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.primaryContainer)
            .overlay(alignment: .top) { Rectangle().fill(Theme.outlineVariant).frame(height: 1) }
        }
    }
}
