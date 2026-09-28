import AVFoundation
import Combine
import MediaPlayer
import UIKit

/// The game's music tab: bundled OSRS tracks, one playing at a time,
/// looping through the list. Uses the playback category so it keeps going
/// with the screen locked, publishes Now Playing to the lock screen, and
/// answers the lock-screen play/pause/next buttons.
@MainActor
final class MusicPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    struct Track: Identifiable, Equatable {
        let file: String
        var title: String { file.replacingOccurrences(of: "_", with: " ") }
        var id: String { file }
    }

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var current: Track?
    @Published private(set) var isPlaying = false
    @Published var loopOne = false {
        didSet { UserDefaults.standard.set(loopOne, forKey: "music-loop-one") }
    }
    @Published var autoplay = false {
        didSet { UserDefaults.standard.set(autoplay, forKey: "music-autoplay") }
    }
    /// The track the app opens on (and autoplays), whatever played last.
    @Published private(set) var defaultTrack: Track?

    private var player: AVAudioPlayer?

    override init() {
        super.init()
        let urls = Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: nil) ?? []
        // Jingles live next to the music; keep only the tracks.
        tracks = urls.map { Track(file: $0.deletingPathExtension().lastPathComponent) }
            // Jingles are not tracks, and a stale build product can still
            // carry the old jingle names.
            .filter { !$0.file.hasPrefix("levelup_") && !$0.file.contains("level_up") && $0.file != "Fanfare" }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        loopOne = UserDefaults.standard.bool(forKey: "music-loop-one")
        autoplay = UserDefaults.standard.bool(forKey: "music-autoplay")
        if let d = UserDefaults.standard.string(forKey: "music-default"), let t = tracks.first(where: { $0.file == d }) {
            defaultTrack = t
        }
        if let d = defaultTrack {
            current = d
        } else if let last = UserDefaults.standard.string(forKey: "music-track"), let t = tracks.first(where: { $0.file == last }) {
            current = t
        } else {
            current = tracks.first { $0.file == "Sea_Shanty_2" } ?? tracks.first
        }
        installRemoteCommands()
    }

    /// Called on launch: start the default (else the remembered) track if
    /// autoplay is on.
    func resumeIfWanted() {
        if autoplay, !isPlaying, let t = defaultTrack ?? current { play(t) }
    }

    /// Star a track as the default; starring it again clears it.
    func setDefault(_ track: Track?) {
        defaultTrack = (track == defaultTrack) ? nil : track
        if let d = defaultTrack {
            UserDefaults.standard.set(d.file, forKey: "music-default")
        } else {
            UserDefaults.standard.removeObject(forKey: "music-default")
        }
    }

    func play(_ track: Track) {
        guard let url = Bundle.main.url(forResource: track.file, withExtension: "m4a") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.numberOfLoops = loopOne ? -1 : 0
            player?.play()
            current = track
            isPlaying = true
            UserDefaults.standard.set(track.file, forKey: "music-track")
            publishNowPlaying()
        } catch {
            isPlaying = false
        }
    }

    func toggle() {
        if isPlaying {
            player?.pause()
            isPlaying = false
            publishNowPlaying()
        } else if let p = player, let _ = current {
            p.play()
            isPlaying = true
            publishNowPlaying()
        } else if let t = current {
            play(t)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func next() { step(1) }
    func previous() { step(-1) }

    private func step(_ delta: Int) {
        guard !tracks.isEmpty else { return }
        let i = current.flatMap { c in tracks.firstIndex(of: c) } ?? 0
        let n = ((i + delta) % tracks.count + tracks.count) % tracks.count
        play(tracks[n])
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if self.loopOne { self.player?.play() } else { self.next() }
        }
    }

    // MARK: - Lock screen

    private func publishNowPlaying() {
        guard let t = current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: t.title,
            MPMediaItemPropertyArtist: "Old School RuneScape",
            MPMediaItemPropertyAlbumTitle: "Exercise Log",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let p = player {
            info[MPMediaItemPropertyPlaybackDuration] = p.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = p.currentTime
        }
        if let icon = UIImage(named: "Strength_icon") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: icon.size) { _ in icon }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func installRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == false { self?.toggle() } }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == true { self?.toggle() } }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
}
