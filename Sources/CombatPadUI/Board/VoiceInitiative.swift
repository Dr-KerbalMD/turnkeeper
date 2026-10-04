import AVFoundation
import Observation
import Speech

/// Push-to-talk speech recognition for initiative numbers, on the device only.
///
/// The Speech and audio frameworks call back on their own queues. Those callbacks are built in `nonisolated`
/// helpers below: a closure written inside this main-actor class would be main-actor isolated, and Swift 6
/// traps when the framework calls it from another queue.
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
    @ObservationIgnored private var isFinal = false

    private init() {}

    /// Asks for speech and microphone permission; voice entry stays off if either is refused.
    func requestPermission() async {
        let speech = await Self.speechAuthorization()
        let microphone = await AVAudioApplication.requestRecordPermission()
        isAvailable = speech == .authorized && microphone && recognizer?.supportsOnDeviceRecognition == true
    }

    /// Starts listening. Numbers are primed as likely words, which makes them much more accurate.
    func listen(for id: UUID, names: [String] = []) {
        guard isAvailable, let recognizer, listeningFor == nil else { return }
        transcript = ""
        isFinal = false
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = (1...60).map(String.init) + names
        do {
            try startAudio(feeding: request)
        } catch {
            return
        }
        self.request = request
        listeningFor = id
        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(for: self))
    }

    /// Stops listening and returns what was heard, after waiting up to half a second for the final result.
    func finish() async -> String {
        guard listeningFor != nil else { return transcript }
        stopAudio()
        request?.endAudio()
        for _ in 0..<10 where !isFinal {
            try? await Task.sleep(for: .milliseconds(50))
        }
        let heard = transcript
        cancel()
        return heard
    }

    /// Stops listening and discards what was heard.
    func cancel() {
        stopAudio()
        task?.cancel()
        request = nil
        task = nil
        listeningFor = nil
    }

    private func receive(_ text: String, isFinal final: Bool) {
        transcript = text
        isFinal = isFinal || final
    }

    private func startAudio(feeding request: SFSpeechAudioBufferRecognitionRequest) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw VoiceError.noMicrophone }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(feeding: request))
        engine.prepare()
        try engine.start()
    }

    private func stopAudio() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: Callbacks that run on the frameworks' queues

    private nonisolated static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status) }
        }
    }

    private nonisolated static func tapBlock(
        feeding request: SFSpeechAudioBufferRecognitionRequest
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    private nonisolated static func resultHandler(
        for voice: VoiceInitiative
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak voice] result, error in
            guard let result else {
                if error != nil { Task { @MainActor in voice?.receive(voice?.transcript ?? "", isFinal: true) } }
                return
            }
            let text = result.bestTranscription.formattedString
            let isFinal = result.isFinal
            Task { @MainActor in voice?.receive(text, isFinal: isFinal) }
        }
    }
}

enum VoiceError: Error {
    case noMicrophone
}
