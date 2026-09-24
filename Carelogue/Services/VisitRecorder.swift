import AVFoundation
import Foundation

/// Recording an appointment you are sitting in (T32).
///
/// The file is written straight to disk while recording — an hour-long visit
/// is far too much to hold in memory, and a crash mid-visit should still
/// leave something behind. It is read back into an `Artifact` only when the
/// recording is finished, so it travels and syncs like any other attachment.
///
/// Bitrate is deliberately low: speech in a quiet consulting room, not music.
/// ~24 kbps mono AAC is around 11 MB an hour, small enough to sit in a private
/// iCloud library without anyone thinking about it.
@MainActor
@Observable
final class VisitRecorder {
    enum State: Equatable {
        case idle
        case recording
        case paused
    }

    enum RecorderError: LocalizedError, Equatable {
        case microphoneDenied
        case sessionUnavailable
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .microphoneDenied:
                return String(localized: "麦克风权限被关闭了，去「设置 → Carelogue」打开后就能录音")
            case .sessionUnavailable:
                return String(localized: "现在录不了音，可能有别的 app 正在用麦克风")
            case .writeFailed:
                return String(localized: "录音没有保存成功，请再试一次")
            }
        }
    }

    private(set) var state: State = .idle
    /// Seconds recorded so far, excluding paused time.
    private(set) var elapsed: TimeInterval = 0
    /// Recent input levels, 0...1, newest last — the live waveform.
    private(set) var levels: [Double] = []

    static let levelWindow = 36
    /// 24 kHz mono is the shape the on-device transcriber wants anyway.
    static let sampleRate = 24_000.0
    static let bitRate = 24_000

    private var recorder: AVAudioRecorder?
    private var ticker: Timer?
    private var fileURL: URL?

    /// Asks once, the first time someone taps 录音.
    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    static var permissionDenied: Bool {
        AVAudioApplication.shared.recordPermission == .denied
    }

    func start() throws {
        guard state == .idle else { return }
        if Self.permissionDenied { throw RecorderError.microphoneDenied }

        let session = AVAudioSession.sharedInstance()
        do {
            // .spokenAudio keeps the system from applying music-shaped
            // processing, and ducks other audio rather than stopping it.
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            throw RecorderError.sessionUnavailable
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("visit-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: Self.bitRate,
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record() else { throw RecorderError.sessionUnavailable }
            self.recorder = recorder
            self.fileURL = url
        } catch let error as RecorderError {
            throw error
        } catch {
            throw RecorderError.sessionUnavailable
        }

        state = .recording
        elapsed = 0
        levels = []
        startTicking()
    }

    func pause() {
        guard state == .recording else { return }
        recorder?.pause()
        state = .paused
        ticker?.invalidate()
        ticker = nil
    }

    func resume() {
        guard state == .paused, let recorder else { return }
        guard recorder.record() else { return }
        state = .recording
        startTicking()
    }

    /// Stops, reads the file back, and cleans up. Returns nil when nothing
    /// usable was captured (a tap that immediately became a stop).
    struct Recording: Sendable {
        var data: Data
        var duration: TimeInterval
        var fileName: String
    }

    @discardableResult
    func finish() -> Recording? {
        defer { reset() }
        guard let recorder, let url = fileURL else { return nil }
        let duration = recorder.currentTime > 0 ? recorder.currentTime : elapsed
        recorder.stop()
        guard let data = try? Data(contentsOf: url), !data.isEmpty, duration >= 1 else { return nil }
        return Recording(data: data, duration: duration, fileName: Self.fileName(for: .now))
    }

    /// Throws the recording away — used when the sheet is dismissed without
    /// saving, so nothing is left on disk.
    func cancel() {
        recorder?.stop()
        reset()
    }

    static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "visit-\(formatter.string(from: date)).m4a"
    }

    private func reset() {
        ticker?.invalidate()
        ticker = nil
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        recorder = nil
        fileURL = nil
        state = .idle
        levels = []
    }

    private func startTicking() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard let recorder, state == .recording else { return }
        elapsed = recorder.currentTime
        recorder.updateMeters()
        // averagePower is dBFS: -160 (silence) ... 0 (clipping). Speech in a
        // room sits around -40, so that is where the bar starts moving.
        let decibels = Double(recorder.averagePower(forChannel: 0))
        let normalized = max(0, min(1, (decibels + 50) / 50))
        levels = (levels + [normalized]).suffix(Self.levelWindow)
    }
}

extension TimeInterval {
    /// "32:14" — the duration form used on the recording card.
    var clockString: String {
        let total = Int(rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
