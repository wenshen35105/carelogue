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
    func transcribe(fileURL: URL, locale: Locale) async throws -> Transcription
}

/// One recognizer pass. `confidence` is the recognizer's own 0...1 certainty,
/// averaged over the text (nil when it reports none) — it is how the
/// language of a visit is told apart (M7 T47).
struct Transcription: Sendable, Equatable {
    let text: String
    let confidence: Double?
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
    /// The languages a visit is tried in, the app language first (it wins a
    /// tie). The visit's language is not the app's: a Chinese-speaking
    /// patient in Canada hears English, and the Chinese model turns English
    /// into noise (M7 T47 — a 5-minute visit came back unreadable).
    static var candidateLocales: [Locale] {
        let chinese = Locale(identifier: "zh-CN"), english = Locale(identifier: "en-CA")
        return AppLanguage.isChinese ? [chinese, english] : [english, chinese]
    }

    /// How much of the recording is used to pick the language. Recordings not
    /// much longer than this are simply transcribed whole in each language.
    static let probeSeconds: Double = 60
    /// Below this the transcript is kept but not sent to the AI on its own —
    /// the card says the transcription may be unreliable.
    static let lowConfidence: Double = 0.6

    struct Outcome: Equatable {
        let text: String
        let locale: Locale
        let confidence: Double?

        var isLowConfidence: Bool {
            guard let confidence else { return false }
            return confidence < VisitTranscription.lowConfidence
        }
    }

    static func makeTranscriber() -> any VisitTranscribing {
        #if DEBUG
        if let fake = UITestSupport.fakeTranscriber { return fake }
        #endif
        if #available(iOS 26, *) { return AnalyzerTranscriber() }
        return LegacyTranscriber()
    }

    /// Transcribes a visit in whichever candidate language the recognizer is
    /// most sure of: each language hears the opening minute, the winner
    /// hears the whole recording.
    static func transcribe(fileURL: URL, with transcriber: any VisitTranscribing) async throws -> Outcome {
        let locales = candidateLocales
        let duration = (try? audioDuration(of: fileURL)) ?? 0
        let isShort = duration <= probeSeconds * 1.5
        let probeURL = isShort ? fileURL : try makeProbe(of: fileURL, seconds: probeSeconds)
        defer { if probeURL != fileURL { try? FileManager.default.removeItem(at: probeURL) } }

        var trials: [Transcription?] = []
        var firstError: Error?
        for locale in locales {
            do {
                trials.append(try await transcriber.transcribe(fileURL: probeURL, locale: locale))
            } catch {
                trials.append(nil)
                if firstError == nil { firstError = error }
            }
        }
        guard let winner = pick(trials) else {
            throw firstError ?? TranscriptionError.nothingRecognized
        }

        let full = isShort ? trials[winner]! : try await transcriber.transcribe(fileURL: fileURL, locale: locales[winner])
        return Outcome(text: full.text, locale: locales[winner], confidence: full.confidence)
    }

    /// The index of the trial to keep: highest confidence, earliest on a tie
    /// (the app language comes first). A trial without a confidence ranks
    /// below any that has one; nil when every trial failed.
    static func pick(_ trials: [Transcription?]) -> Int? {
        var best: (index: Int, score: Double)?
        for (index, trial) in trials.enumerated() {
            guard let trial, !trial.text.isEmpty else { continue }
            let score = trial.confidence ?? -1
            if best == nil || score > best!.score { best = (index, score) }
        }
        return best?.index
    }

    private static func audioDuration(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    /// The opening `seconds` of a recording, as a temporary PCM file.
    private static func makeProbe(of url: URL, seconds: Double) throws -> URL {
        let source = try AVAudioFile(forReading: url)
        let format = source.processingFormat
        let frames = AVAudioFrameCount(min(Double(source.length), seconds * format.sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw TranscriptionError.failed("probe")
        }
        try source.read(into: buffer, frameCount: frames)
        let probeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("probe-\(UUID().uuidString).caf")
        let probe = try AVAudioFile(forWriting: probeURL, settings: format.settings,
                                    commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        try probe.write(from: buffer)
        return probeURL
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

/// Character-weighted mean of per-piece confidences; nil when none reported.
private func weightedConfidence(_ pieces: [(characters: Int, confidence: Double)]) -> Double? {
    let total = pieces.reduce(0) { $0 + $1.characters }
    guard total > 0 else { return nil }
    return pieces.reduce(0) { $0 + Double($1.characters) * $1.confidence } / Double(total)
}

/// iOS 26+: the modern analyzer, which is built for exactly this — long audio,
/// more than one speaker, and terms in a second language.
@available(iOS 26, *)
private struct AnalyzerTranscriber: VisitTranscribing {
    func transcribe(fileURL: URL, locale: Locale) async throws -> Transcription {
        guard SpeechTranscriber.isAvailable else { throw TranscriptionError.modelUnavailable }
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriptionError.localeUnavailable
        }

        let preset = SpeechTranscriber.Preset.transcription
        let transcriber = SpeechTranscriber(locale: supported,
                                            transcriptionOptions: preset.transcriptionOptions,
                                            reportingOptions: preset.reportingOptions,
                                            attributeOptions: preset.attributeOptions.union([.transcriptionConfidence]))
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
            let pieces = text.runs.compactMap { run -> (characters: Int, confidence: Double)? in
                guard let confidence = run.transcriptionConfidence else { return nil }
                return (text[run.range].characters.count, confidence)
            }
            return Transcription(text: String(text.characters), confidence: weightedConfidence(pieces))
        }

        do {
            let file = try AVAudioFile(forReading: fileURL)
            _ = try await analyzer.analyzeSequence(from: file)
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            collected.cancel()
            throw TranscriptionError.failed(error.localizedDescription)
        }

        let result = try await collected.value
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.nothingRecognized }
        return Transcription(text: text, confidence: result.confidence)
    }
}

/// iOS 17–25: `SFSpeechRecognizer` pinned to on-device recognition. Nothing is
/// sent to Apple either — if the device cannot do it locally, this fails
/// rather than quietly falling back to the network.
private struct LegacyTranscriber: VisitTranscribing {
    func transcribe(fileURL: URL, locale: Locale) async throws -> Transcription {
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

        let result: Transcription = try await withCheckedThrowingContinuation { continuation in
            // A visit is minutes long, so only the final result is of interest;
            // `resume` must still happen exactly once on every path.
            let box = ResumeOnce(continuation)
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    box.fail(TranscriptionError.failed(error.localizedDescription))
                } else if let result, result.isFinal {
                    let best = result.bestTranscription
                    let pieces = best.segments.map { (characters: $0.substring.count, confidence: Double($0.confidence)) }
                    box.succeed(Transcription(text: best.formattedString, confidence: weightedConfidence(pieces)))
                }
            }
        }

        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranscriptionError.nothingRecognized }
        return Transcription(text: trimmed, confidence: result.confidence)
    }
}

/// `recognitionTask`'s callback can fire more than once; a continuation may
/// only be resumed once.
private final class ResumeOnce: @unchecked Sendable {
    private let continuation: CheckedContinuation<Transcription, Error>
    private var done = false
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Transcription, Error>) {
        self.continuation = continuation
    }

    func succeed(_ value: Transcription) {
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
