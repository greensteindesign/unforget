import Foundation
import AVFoundation

/// Plays alert sounds with a gentle ramp-up (no jarring onset — sensory sensitivity).
/// Repeats subtly for as long as an alert is unacknowledged ("Nag").
@MainActor
final class SoundService {
    private var player: AVAudioPlayer?
    private var nagTimer: Timer?

    func playOnce(name: String, rampUp: Bool = true) {
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        player = p
        p.volume = rampUp ? 0.15 : 0.7
        p.play()
        if rampUp {
            p.setVolume(0.9, fadeDuration: 1.5)
        }
    }

    func startNagging(name: String, repeats: Bool) {
        stop()
        playOnce(name: name, rampUp: true)
        guard repeats else { return }
        nagTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.playOnce(name: name, rampUp: false)
            }
        }
    }

    func stop() {
        nagTimer?.invalidate()
        nagTimer = nil
        player?.stop()
        player = nil
    }
}
