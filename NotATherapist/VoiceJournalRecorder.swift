import AVFoundation
import Foundation
import WhisperKit

@MainActor
final class VoiceJournalRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum RecorderState: Equatable {
        case idle
        case preparingModel
        case requestingPermission
        case recording
        case transcribing
        case unavailable(String)
    }

    @Published private(set) var state: RecorderState = .idle
    @Published private(set) var transcript = ""

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var whisperKit: WhisperKit?
    private let voiceModelManager: VoiceModelManager

    override init() {
        self.voiceModelManager = VoiceModelManager.shared
        super.init()
    }

    var isRecording: Bool {
        state == .recording
    }

    func toggleRecording() {
        if isRecording {
            stopAndTranscribe()
        } else {
            Task { await start() }
        }
    }

    func start() async {
        guard voiceModelManager.isVoiceEnabled else {
            state = .unavailable("Voice journaling is optional. Enable it in Settings to download the on-device model.")
            return
        }

        state = .requestingPermission
        let granted = await requestMicrophoneAccess()
        guard granted else {
            state = .unavailable("Microphone permission is required for private voice journaling.")
            return
        }

        do {
            let url = try makeRecordingURL()
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.record()

            self.recorder = recorder
            recordingURL = url
            transcript = ""
            state = .recording
        } catch {
            state = .unavailable("Voice recording could not start.")
        }
    }

    func stopAndTranscribe() {
        guard isRecording else { return }
        recorder?.stop()
        recorder = nil
        Task { await transcribeRecording() }
    }

    func resetTranscript() {
        transcript = ""
    }

    private func transcribeRecording() async {
        guard let recordingURL else {
            state = .idle
            return
        }

        do {
            state = .preparingModel
            let kit = try await loadWhisperKit()
            state = .transcribing
            let results = try await kit.transcribe(audioPath: recordingURL.path)
            transcript = results
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            try? FileManager.default.removeItem(at: recordingURL)
            self.recordingURL = nil
            state = .idle
        } catch {
            state = .unavailable("WhisperKit could not transcribe this recording.")
        }
    }

    private func loadWhisperKit() async throws -> WhisperKit {
        if let whisperKit {
            return whisperKit
        }
        guard let modelFolder = voiceModelManager.modelFolderURL else {
            throw VoiceJournalRecorderError.modelNotDownloaded
        }
        let config = WhisperKitConfig(
            model: "tiny",
            modelFolder: modelFolder.path,
            tokenizerFolder: voiceModelManager.downloadBaseURL,
            verbose: false,
            prewarm: true,
            load: true,
            download: false
        )
        let kit = try await WhisperKit(config)
        whisperKit = kit
        return kit
    }

    private func makeRecordingURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "AnchorVoice", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "voice-\(UUID().uuidString).m4a")
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private enum VoiceJournalRecorderError: Error {
    case modelNotDownloaded
}
