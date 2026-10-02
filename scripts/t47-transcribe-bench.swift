// T47: run one visit recording through the on-device speech models the app
// uses, under several configurations, and write each transcript side by side.
//
//   swift scripts/t47-transcribe-bench.swift <recording.m4a> [out-dir]
//
// Everything stays on this Mac (SpeechAnalyzer is on-device). Point out-dir at
// build/ — recordings and transcripts are patient data and never go in git.
import AVFoundation
import Foundation
import Speech

struct Config {
    let name: String
    let locale: String
    let kind: Kind
    enum Kind { case transcriber(SpeechTranscriber.Preset), dictation }
}

nonisolated(unsafe) var lastConfidence = Double.nan

let configs: [Config] = [
    // What the app does today (Chinese UI).
    Config(name: "app-zh-transcription", locale: "zh-CN", kind: .transcriber(.transcription)),
    Config(name: "zh-dictation", locale: "zh-CN", kind: .dictation),
    Config(name: "en-transcription", locale: "en-US", kind: .transcriber(.transcription)),
    Config(name: "yue-transcription", locale: "zh-HK", kind: .transcriber(.transcription)),
]

func transcribe(_ url: URL, _ config: Config) async throws -> String {
    let module: any SpeechModule
    let results: AsyncThrowingStream<AttributedString, Error>
    switch config.kind {
    case .transcriber(let preset):
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: config.locale)) else {
            throw NSError(domain: "bench", code: 1, userInfo: [NSLocalizedDescriptionKey: "locale unsupported: \(config.locale)"])
        }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: preset.transcriptionOptions,
                                            reportingOptions: preset.reportingOptions,
                                            attributeOptions: preset.attributeOptions.union([.transcriptionConfidence]))
        module = transcriber
        results = AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await result in transcriber.results where result.isFinal { continuation.yield(result.text) }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    case .dictation:
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: config.locale)) else {
            throw NSError(domain: "bench", code: 1, userInfo: [NSLocalizedDescriptionKey: "locale unsupported: \(config.locale)"])
        }
        let transcriber = DictationTranscriber(locale: locale, preset: .longDictation)
        module = transcriber
        results = AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await result in transcriber.results where result.isFinal { continuation.yield(result.text) }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }

    if let installation = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
        print("   downloading model for \(config.locale)…")
        try await installation.downloadAndInstall()
    }

    let analyzer = SpeechAnalyzer(modules: [module])
    let collected = Task {
        var text = AttributedString()
        for try await piece in results { text += piece; text += AttributedString("\n") }
        // Character-weighted mean of the per-run confidence, where reported.
        var weighted = 0.0, chars = 0
        for run in text.runs {
            guard let confidence = run.transcriptionConfidence else { continue }
            let count = text[run.range].characters.count
            weighted += confidence * Double(count); chars += count
        }
        lastConfidence = chars > 0 ? weighted / Double(chars) : .nan
        return String(text.characters)
    }
    let file = try AVAudioFile(forReading: url)
    _ = try await analyzer.analyzeSequence(from: file)
    try await analyzer.finalizeAndFinishThroughEndOfInput()
    return try await collected.value
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: swift scripts/t47-transcribe-bench.swift <recording.m4a> [out-dir]")
    exit(2)
}
let input = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args.count >= 3 ? args[2] : "build/t47")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for config in configs {
    print("==> \(config.name)")
    let started = Date()
    do {
        let text = try await transcribe(input, config)
        let out = outDir.appendingPathComponent("\(input.deletingPathExtension().lastPathComponent).\(config.name).txt")
        try text.write(to: out, atomically: true, encoding: .utf8)
        print(String(format: "   %d chars, %.0fs, mean confidence %.2f -> %@", text.count, Date().timeIntervalSince(started),
                     lastConfidence, out.path))
    } catch {
        print("   failed: \(error.localizedDescription)")
    }
}
