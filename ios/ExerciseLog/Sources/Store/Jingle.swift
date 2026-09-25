import AVFoundation

/// The Strength level-up jingle, played when a progression is accepted.
/// Missing file means silence, never a crash.
enum Jingle {
    private static var player: AVAudioPlayer?

    static func levelUp() { play("level_up") }
    static func questLevelUp() { play("quest_level_up") }

    private static func play(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
