import AVFoundation
import Foundation

@MainActor
final class AudioCueManager: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var players: [String: AVAudioPlayer] = [:]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func playAnnouncement(
        role: IntervalCueRole,
        phrase: String,
        audioMode: AudioMode,
        announcementType: AnnouncementType,
        language: AnnouncementLanguage,
        voiceIdentifier: String?
    ) {
        guard announcementType != .off else { return }

        configureSession(for: audioMode)

        if announcementType.includesSound {
            playSound(for: role)
        }

        if announcementType.includesVoice {
            speak(phrase, language: language, voiceIdentifier: voiceIdentifier)
        }
    }

    func speakCountdown(
        _ text: String,
        audioMode: AudioMode,
        announcementType: AnnouncementType,
        language: AnnouncementLanguage,
        voiceIdentifier: String?
    ) {
        guard announcementType.includesVoice else { return }
        configureSession(for: audioMode)
        speak(text, language: language, voiceIdentifier: voiceIdentifier)
    }

    private func configureSession(for audioMode: AudioMode) {
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions
        let mode: AVAudioSession.Mode

        switch audioMode {
        case .duck:
            options = [.duckOthers]
            mode = .spokenAudio
        case .mix:
            options = [.mixWithOthers]
            mode = .default
        case .interrupt:
            options = []
            mode = .spokenAudio
        }

        do {
            try session.setCategory(.playback, mode: mode, options: options)
            try session.setActive(true)
        } catch {
            // Audio cues are helpful, but the timer must keep running even if audio setup fails.
        }
    }

    private func playSound(for role: IntervalCueRole) {
        let resourceName = role.audioResourceName

        do {
            let player: AVAudioPlayer
            if let cachedPlayer = players[resourceName] {
                player = cachedPlayer
            } else {
                guard let url = Bundle.main.url(forResource: resourceName, withExtension: "caf") else { return }
                player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[resourceName] = player
            }

            player.currentTime = 0
            player.play()
        } catch {
            return
        }
    }

    private func speak(_ text: String, language: AnnouncementLanguage, voiceIdentifier: String?) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice(for: language, preferredIdentifier: voiceIdentifier)
        utterance.rate = language == .english ? 0.46 : 0.43
        utterance.pitchMultiplier = 0.92
        utterance.volume = 1
        synthesizer.speak(utterance)
    }

    private func bestVoice(for language: AnnouncementLanguage, preferredIdentifier: String?) -> AVSpeechSynthesisVoice? {
        if let preferredIdentifier,
           let preferredVoice = AVSpeechSynthesisVoice(identifier: preferredIdentifier) {
            return preferredVoice
        }

        let exactLanguage = language.localeIdentifier
        let matchingVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == exactLanguage }
            .sorted { lhs, rhs in
                if lhs.quality.rawValue != rhs.quality.rawValue {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }

        if let bestMatch = matchingVoices.first {
            return bestMatch
        }

        return AVSpeechSynthesisVoice(language: exactLanguage) ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}
