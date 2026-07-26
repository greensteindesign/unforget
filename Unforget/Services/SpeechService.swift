import Foundation
import AVFoundation

/// Speaks the event title aloud — a second sensory channel for unmissability
/// without adding visual glare. Fully on-device.
@MainActor
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    private static let voiceLanguages = ["de": "de-DE", "en": "en-US", "es": "es-ES"]

    func announce(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        if let code = Self.voiceLanguages[L.code],
           let voice = AVSpeechSynthesisVoice(language: code) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.preUtteranceDelay = 0.8 // sound ramp-up first, then the voice
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
