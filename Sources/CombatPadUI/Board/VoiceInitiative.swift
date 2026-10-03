import AVFoundation
import Observation
import Speech

/// Push-to-talk speech recognition for initiative numbers, on the device only.
@Observable
@MainActor
final class VoiceInitiative {
    static let shared = VoiceInitiative()

    /// The combatant being listened for, or nil when not listening.
    private(set) var listeningFor: UUID?
    private(set) var transcript = ""
    private(set) var isAvailable = false

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?

    private init() {
        isAvailable = recognizer?.supportsOnDeviceRecognition == true
    }

    /// Asks for microphone and speech permission once; voice entry stays off if either is refused.
    func requestPermission() async {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let microphone = await AVAudioApplication.requestRecordPermission()
        isAvailable = speech == .authorized && microphone && recognizer?.supportsOnDeviceRecognition == true
    }

    /// Starts listening. Numbers are primed as likely words, which makes them much more accurate.
    func listen(for id: UUID, names: [String] = []) {
        guard isAvailable, let recognizer, listeningFor == nil else { return }
        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = (1...60).map(String.init) + names
        self.request = request
        do {
            try startAudio(feeding: request)
        } catch {
            return
        }
        listeningFor = id
        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let text = result?.bestTranscription.formattedString else { return }
            Task { @MainActor in self?.transcript = text }
        }
    }

    /// Stops listening and returns what was heard.
    @discardableResult
    func stop() -> String {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        listeningFor = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        return transcript
    }

    private func startAudio(feeding request: SFSpeechAudioBufferRecognitionRequest) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()
    }
}
