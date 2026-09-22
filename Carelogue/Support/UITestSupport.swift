#if DEBUG
import Foundation
import SwiftData
import UIKit

/// Launch-argument hooks for the CarelogueUITests target. Debug builds only;
/// a normal launch passes none of these flags and nothing happens.
///
///   -uitest-reset                 wipe all Journeys / Logs / Artifacts
///   -uitest-seed-measurements     add a Journey with 20 体重 + 3 血压 + 1 体温
///   -uitest-seed-attachments      add a Journey with an encounter holding
///                                 2 images (a zh/en lab report + a textless
///                                 photo) + 1 two-page PDF
///   -uitest-fake-ai <mode>        explain through a scripted provider instead
///                                 of DeepSeek: success | slow | fail | invalid
///   env UITEST_API_KEY=<key>      store this key in the Keychain at launch
///   -selftest-extract             run TextExtractor on generated samples and
///                                 write the results to
///                                 Documents/selftest-extract.txt
enum UITestSupport {
    static let seededJourneyName = "UITest 孕期"

    static func prepare(_ context: ModelContext) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uitest-reset") {
            try? context.delete(model: Artifact.self)
            try? context.delete(model: Log.self)
            try? context.delete(model: Journey.self)
            try? context.delete(model: Profile.self)
            AISettings.setAPIKey(nil)
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("ai.") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        if let key = ProcessInfo.processInfo.environment["UITEST_API_KEY"], !key.isEmpty {
            AISettings.setAPIKey(key)
        }
        if let index = arguments.firstIndex(of: "-uitest-fake-ai"), index + 1 < arguments.count {
            fakeAIService = FakeAIService(mode: arguments[index + 1])
        }
        if arguments.contains("-uitest-seed-measurements") || arguments.contains("-uitest-seed-attachments") {
            let journey = Journey(name: seededJourneyName, template: .pregnancy)
            context.insert(journey)
            if arguments.contains("-uitest-seed-measurements") {
                seedMeasurements(in: journey, context: context)
            }
            if arguments.contains("-uitest-seed-attachments") {
                seedAttachments(in: journey, context: context)
            }
        }
        try? context.save()
        if arguments.contains("-selftest-extract") {
            Task { await runExtractionSelfTest() }
        }
    }

    /// Set by -uitest-fake-ai; AISettings.makeService() prefers it.
    static var fakeAIService: FakeAIService?

    private static func runExtractionSelfTest() async {
        let samples: [(String, Data, String)] = [
            ("report-photo", reportImage(), AttachmentMime.jpeg),
            ("blank-photo", image(hue: 0.07), AttachmentMime.jpeg),
            ("text-pdf", pdf(), AttachmentMime.pdf),
            ("scanned-pdf", scannedPDF(), AttachmentMime.pdf),
            ("garbage", Data("not an image".utf8), AttachmentMime.jpeg),
        ]
        var report = ""
        for (name, data, mime) in samples {
            let start = Date.now
            do {
                let text = try await TextExtractor.extract(data: data, mime: mime)
                report += "== \(name) OK (\(Int(Date.now.timeIntervalSince(start) * 1000))ms)\n\(text)\n\n"
            } catch {
                report += "== \(name) ERROR \(error): \(error.localizedDescription)\n\n"
            }
        }
        let url = URL.documentsDirectory.appendingPathComponent("selftest-extract.txt")
        try? report.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func seedMeasurements(in journey: Journey, context: ModelContext) {
        let calendar = Calendar.current
        for i in 0..<20 {
            add(Log(kind: .measurement, type: "体重",
                    occurredAt: calendar.date(byAdding: .day, value: -7 * (20 - i) - 2, to: .now)!,
                    value: 58.0 + Double(i) * 0.5, unit: "kg"), to: journey, context: context)
        }
        for (i, value) in [114.0, 118, 111].enumerated() {
            add(Log(kind: .measurement, type: "血压",
                    occurredAt: calendar.date(byAdding: .day, value: -10 * i - 3, to: .now)!,
                    value: value, unit: "mmHg"), to: journey, context: context)
        }
        add(Log(kind: .measurement, type: "体温",
                occurredAt: calendar.date(byAdding: .day, value: -4, to: .now)!,
                value: 36.7, unit: "°C"), to: journey, context: context)
    }

    private static func seedAttachments(in journey: Journey, context: ModelContext) {
        let visit = Log(kind: .encounter, type: "验血",
                        occurredAt: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                        note: "UITest 附件就诊", location: "BC Women's", doctor: "Dr. Chen")
        add(visit, to: journey, context: context)
        let files: [(Data, String, String)] = [
            (reportImage(), "seed_photo_1.jpg", AttachmentMime.jpeg),
            (image(hue: 0.55), "seed_photo_2.jpg", AttachmentMime.jpeg),
            (pdf(), "seed_report.pdf", AttachmentMime.pdf),
        ]
        for (offset, file) in files.enumerated() {
            let artifact = Artifact(fileData: file.0, fileName: file.1, mime: file.2,
                                    createdAt: Date.now.addingTimeInterval(Double(offset)))
            context.insert(artifact)
            artifact.log = visit
        }
    }

    private static func add(_ log: Log, to journey: Journey, context: ModelContext) {
        context.insert(log)
        log.journey = journey
    }

    private static func image(hue: CGFloat) -> Data {
        let size = CGSize(width: 1200, height: 900)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { context in
            UIColor(hue: hue, saturation: 0.35, brightness: 0.95, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(hue: hue, saturation: 0.6, brightness: 0.7, alpha: 1).setFill()
            for i in 0..<10 {
                context.fill(CGRect(x: CGFloat(i) * 120 + 20, y: 250, width: 40, height: 400))
            }
        }
    }

    static let reportLines = [
        "BC Women's Hospital 检验报告 Laboratory Report",
        "项目 Test          结果 Result   参考范围 Range",
        "血红蛋白 Hemoglobin (Hb)   112 g/L   115-150",
        "白细胞 WBC   8.6 ×10^9/L   3.5-9.5",
        "血小板 PLT   210 ×10^9/L   125-350",
        "NT 颈项透明层 1.4 mm   < 2.5 mm",
    ]

    /// A photographed-looking lab report: mixed Chinese / English lines on
    /// an off-white page.
    static func reportImage() -> Data {
        let size = CGSize(width: 1400, height: 900)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.85) { context in
            UIColor(white: 0.97, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, line) in reportLines.enumerated() {
                (line as NSString).draw(
                    at: CGPoint(x: 70, y: 80 + CGFloat(index) * 120),
                    withAttributes: [.font: UIFont.systemFont(ofSize: index == 0 ? 44 : 38, weight: index == 0 ? .bold : .regular),
                                     .foregroundColor: UIColor(white: 0.12, alpha: 1)]
                )
            }
        }
    }

    /// Two text-layer pages (PDFKit path).
    static func pdf() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { context in
            for page in 1...2 {
                context.beginPage()
                ("UITest report — page \(page)" as NSString).draw(
                    at: CGPoint(x: 60, y: 80),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 28)]
                )
                let lines = page == 1 ? Array(reportLines.prefix(3)) : Array(reportLines.suffix(3))
                for (index, line) in lines.enumerated() {
                    (line as NSString).draw(
                        at: CGPoint(x: 60, y: 150 + CGFloat(index) * 40),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 16)]
                    )
                }
            }
        }
    }

    /// One page that is only an embedded photo — no text layer (OCR path).
    private static func scannedPDF() -> Data {
        guard let scan = UIImage(data: reportImage()) else { return Data() }
        return UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 700, height: 450)).pdfData { context in
            context.beginPage()
            scan.draw(in: CGRect(x: 0, y: 0, width: 700, height: 450))
        }
    }
}
/// Scripted provider for UI tests: no network, deterministic output.
struct FakeAIService: AIService {
    let mode: String
    var modelName: String { "fake-model" }

    /// Every request the app sent, so tests can check what left the device.
    static var requestCount = 0

    func complete(system: String, user: String, json: Bool) async throws -> String {
        FakeAIService.requestCount += 1
        switch mode {
        case "fail":
            try await Task.sleep(for: .milliseconds(600))
            throw AIServiceError.timeout
        case "invalid":
            return "{\"summary_plain\": \"\"}"
        case "slow":
            try await Task.sleep(for: .seconds(4))
        default:
            try await Task.sleep(for: .milliseconds(800))
        }
        return Self.sampleJSON
    }

    static let sampleJSON = """
    {
      "summary_plain": "这次检查整体情况平稳。血红蛋白 112 g/L，略低于参考范围（115–150），孕中期常见，属于生理性血液稀释；白细胞和血小板都在正常范围。NT 颈项透明层 1.4 mm，低于 2.5 mm 的参考上限。",
      "terms": [
        {"original": "Hb · 血红蛋白", "plain": "血液里运送氧气的蛋白，偏低时容易累"},
        {"original": "WBC · 白细胞", "plain": "免疫细胞数量，反映有没有感染"},
        {"original": "PLT · 血小板", "plain": "帮助止血的细胞"},
        {"original": "NT · 颈项透明层", "plain": "孕早期超声测量的胎儿颈后积液厚度"}
      ],
      "questions": [
        "血红蛋白 112 g/L 需要补铁吗？还是先从饮食调整？",
        "如果要补铁，多久后复查一次血常规比较合适？",
        "NT 结果正常，后续还需要做哪些筛查？"
      ]
    }
    """
}
#endif
