import AVFoundation

/// The Strength level-up jingle, played when a progression is accepted.
/// Missing file means silence, never a crash.
enum Jingle {
    private static var player: AVAudioPlayer?

    static func levelUp() { play(Skill.strength.jingle) }
    static func questLevelUp() { play(Skill.agility.jingle) }
    static func levelUp(_ skill: Skill) { play(skill.jingle) }
    /// The game's quest-complete fanfare, from the Music folder.
    static func fanfare() { play("Fanfare") }

    static func play(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else { return }
        // Playback, not ambient: ambient would silence the music player
        // the moment the screen locks, since the category is app-wide.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
