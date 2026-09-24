import AVFoundation
import Foundation
import Speech

/// Turning a recorded visit into text, on this device (T32).
///
/// This is the whole reason the audio can stay private: the recording never
/// goes to a server, only the text does. Everything here runs locally —
/// `SpeechAnalyzer` where the OS has it (iOS 26+, much better at long,
/// two-person, code-switched conversation), and on-device `SFSpeechRecognizer`
/// below that.
protocol VisitTranscribing: Sendable {
    func transcribe(fileURL: URL, locale: Locale) async throws -> String
}

enum TranscriptionError: LocalizedError, Equatable {
    case notAuthorized
    case localeUnavailable
    case modelUnavailable
    case nothingRecognized
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return String(localized: "语音转文字的权限被关闭了，去「设置 → Carelogue」打开后可以重试")
        case .localeUnavailable:
            return String(localized: "这台设备还不支持这种语言的本地转写")
        case .modelUnavailable:
            return String(localized: "本地转写模型还没准备好，连上网络后会自动下载一次")
        case .nothingRecognized:
            return String(localized: "这段录音里没有听清的内容")
        case .failed(let reason):
            return String(localized: "转写没有完成（\(reason)）")
        }
    }
}

enum VisitTranscription {
    /// The recognizer's language. Follows the app language, which is also the
    /// language the summary comes back in — a visit in Chinese with English
    /// medical terms transcribes best with the Chinese model, and vice versa.
    static var preferredLocale: Locale {
        Locale(identifier: AppLanguage.isChinese ? "zh-CN" : "en-CA")
    }

    static func makeTranscriber() -> any VisitTranscribing {
        #if DEBUG
        if let fake = UITestSupport.fakeTranscriber { return fake }
        #endif
        if #available(iOS 26, *) { return AnalyzerTranscriber() }
        return LegacyTranscriber()
    }

    /// Permission for the speech models. The recorder asks for the microphone
    /// separately; both are requested before the first recording starts.
    static func requestPermission() async -> Bool {
        if #available(iOS 26, *) { return true }  // SpeechAnalyzer needs no prompt
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

/// iOS 26+: the modern analyzer, which is built for exactly this — long audio,
/// more than one speaker, and terms in a second language.
@available(iOS 26, *)
private struct AnalyzerTranscriber: VisitTranscribing {
    func transcribe(fileURL: URL, locale: Locale) async throws -> String {
        guard SpeechTranscriber.isAvailable else { throw TranscriptionError.modelUnavailable }
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriptionError.localeUnavailable
        }

        let transcriber = SpeechTranscriber(locale: supported, preset: .transcription)
        // The language model is downloaded once, by the OS, and then reused.
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installation.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let collected = Task {
            var text = AttributedString()
            for try await result in transcriber.results {
                text += result.text
            }
            return String(text.characters)
        }

        do {
            let file = try AVAudioFile(forReading: fileURL)
            _ = try await analyzer.analyzeSequence(from: file)
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            collected.cancel()
            throw TranscriptionError.failed(error.localizedDescription)
        }

        let text = try await collected.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.nothingRecognized }
        return text
    }
}

/// iOS 17–25: `SFSpeechRecognizer` pinned to on-device recognition. Nothing is
/// sent to Apple either — if the device cannot do it locally, this fails
/// rather than quietly falling back to the network.
private struct LegacyTranscriber: VisitTranscribing {
    func transcribe(fileURL: URL, locale: Locale) async throws -> String {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.notAuthorized
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw TranscriptionError.localeUnavailable
        }
        guard recognizer.isAvailable else { throw TranscriptionError.modelUnavailable }
        guard recognizer.supportsOnDeviceRecognition else { throw TranscriptionError.modelUnavailable }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        let text: String = try await withCheckedThrowingContinuation { continuation in
            // A visit is minutes long, so only the final result is of interest;
            // `resume` must still happen exactly once on every path.
            let box = ResumeOnce(continuation)
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    box.fail(TranscriptionError.failed(error.localizedDescription))
                } else if let result, result.isFinal {
                    box.succeed(result.bestTranscription.formattedString)
                }
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranscriptionError.nothingRecognized }
        return trimmed
    }
}

/// `recognitionTask`'s callback can fire more than once; a continuation may
/// only be resumed once.
private final class ResumeOnce: @unchecked Sendable {
    private let continuation: CheckedContinuation<String, Error>
    private var done = false
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func succeed(_ value: String) {
        lock.lock(); defer { lock.unlock() }
        guard !done else { return }
        done = true
        continuation.resume(returning: value)
    }

    func fail(_ error: Error) {
        lock.lock(); defer { lock.unlock() }
        guard !done else { return }
        done = true
        continuation.resume(throwing: error)
    }
}
