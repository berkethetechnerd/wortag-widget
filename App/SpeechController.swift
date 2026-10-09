import AVFoundation
import SwiftUI

/// App-owned synthesizer: retain it during playback, replace queued speech, and
/// never ask for microphone access. Previews do not inspect or play system voices.
@MainActor
final class SpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    @Published private(set) var message: String?
    private let synthesizer = AVSpeechSynthesizer()
    private let preview: Bool
    private var activeUtterance: AVSpeechUtterance?

    init(preview: Bool = false) {
        self.preview = preview
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, slowly: Bool = false) {
        guard !preview, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "de-DE" })
                ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("de-") }) else {
            message = "No German voice is available. Add a German voice in System Settings → Accessibility → Spoken Content / Read & Speak."
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = slowly ? 0.35 : AVSpeechUtteranceDefaultSpeechRate
        message = nil
        activeUtterance = utterance
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() { activeUtterance = nil; synthesizer.stopSpeaking(at: .immediate); isSpeaking = false }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.activeUtterance === utterance { self.activeUtterance = nil; self.isSpeaking = false }
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.activeUtterance === utterance { self.activeUtterance = nil; self.isSpeaking = false }
        }
    }
}

struct PronunciationControls: View {
    @EnvironmentObject private var speech: SpeechController
    let text: String
    var compact = false
    var body: some View {
        HStack(spacing: 10) {
            Button { speech.speak(text) } label: {
                Label(compact ? "Listen" : "Pronounce", systemImage: "speaker.wave.2")
            }.help("Hear this German text")
            Button("Slow") { speech.speak(text, slowly: true) }.help("Hear this German text more slowly")
            if speech.isSpeaking {
                Button { speech.stop() } label: { Image(systemName: "stop.fill") }
                    .accessibilityLabel("Stop pronunciation")
            }
        }.buttonStyle(.borderless).font(.system(size: 11)).foregroundStyle(WortagTheme.accent)
    }
}
