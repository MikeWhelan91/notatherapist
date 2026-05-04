import Foundation
import WhisperKit

@MainActor
final class VoiceModelManager: ObservableObject {
    static let shared = VoiceModelManager()

    enum Status: Equatable {
        case notEnabled
        case ready
        case downloading(Double)
        case failed(String)
    }

    @Published private(set) var status: Status

    private let enabledKey = "voiceJournalingEnabled"
    private let modelPathKey = "whisperTinyModelFolderPath"
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.bool(forKey: enabledKey), Self.hasModelFiles(at: defaults.string(forKey: modelPathKey)) {
            status = .ready
        } else {
            status = .notEnabled
        }
    }

    var isVoiceEnabled: Bool {
        if case .ready = status { return true }
        return false
    }

    var statusLabel: String {
        switch status {
        case .notEnabled:
            return "Not enabled"
        case .ready:
            return "Ready"
        case .downloading(let progress):
            return "Downloading \(Int(progress * 100))%"
        case .failed:
            return "Needs attention"
        }
    }

    var modelFolderURL: URL? {
        guard Self.hasModelFiles(at: defaults.string(forKey: modelPathKey)),
              let path = defaults.string(forKey: modelPathKey) else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    var downloadBaseURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "WhisperKit", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    func refresh() {
        if defaults.bool(forKey: enabledKey), Self.hasModelFiles(at: defaults.string(forKey: modelPathKey)) {
            status = .ready
        } else {
            status = .notEnabled
        }
    }

    func downloadTinyModel() async {
        guard case .downloading = status else {
            status = .downloading(0)
            do {
                let folder = try await WhisperKit.download(
                    variant: "tiny",
                    downloadBase: downloadBaseURL
                ) { progress in
                    Task { @MainActor in
                        self.status = .downloading(progress.fractionCompleted)
                    }
                }

                let config = WhisperKitConfig(
                    model: "tiny",
                    modelFolder: folder.path,
                    tokenizerFolder: downloadBaseURL,
                    verbose: false,
                    prewarm: true,
                    load: true,
                    download: false
                )
                _ = try await WhisperKit(config)

                defaults.set(true, forKey: enabledKey)
                defaults.set(folder.path, forKey: modelPathKey)
                status = .ready
            } catch {
                defaults.set(false, forKey: enabledKey)
                status = .failed("The voice model could not download. Check your connection and try again.")
            }
            return
        }
    }

    func disableVoice() {
        defaults.set(false, forKey: enabledKey)
        status = .notEnabled
    }

    private static func hasModelFiles(at path: String?) -> Bool {
        guard let path else { return false }
        let folder = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(
            atPath: folder.appending(path: "AudioEncoder.mlmodelc", directoryHint: .isDirectory).path
        )
    }
}
