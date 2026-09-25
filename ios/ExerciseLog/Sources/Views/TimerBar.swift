import SwiftUI

/// Rest countdown as a stone strip: digits in yellow, a run-energy style
/// bar that drains green to red, and a game-message line when it ends.
struct TimerBar: View {
    @EnvironmentObject private var timer: RestTimer

    var body: some View {
        if timer.isRunning {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    SkillIcon(name: "Prayer_icon", size: 22)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Rest").rsText(16, color: RS.orange)
                        Text(timer.label).rsSmall(16).lineLimit(1)
                    }
                    Spacer()
                    Text(RestTimer.format(timer.remaining))
                        .rsText(36, bold: true, color: timer.remaining <= 10 ? RS.red : RS.yellow)
                        .monospacedDigit()
                    Button("+30s") { timer.add(seconds: 30) }.buttonStyle(StoneButton())
                    Button("X") { timer.stop() }.buttonStyle(StoneButton(color: RS.red))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(RS.stoneDarker)
                        Rectangle()
                            .fill(timer.remaining <= 10 ? RS.red : RS.green)
                            .frame(width: geo.size.width * (1 - timer.progress))
                    }
                }
                .frame(height: 8)
                .bevel(inset: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .stonePanel()
        } else if timer.justFinished {
            HStack {
                Text("Your rest is over. Next set.").rsText(16, color: RS.green)
                Spacer()
                Button("OK") { timer.acknowledge() }.buttonStyle(StoneButton())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .stonePanel()
        }
    }
}
