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
///   -uitest-seed-demo             a realistic two-Journey store for the
///                                 documentation screenshots (docs/screenshots):
///                                 a running pregnancy Journey with an upcoming
///                                 appointment, encounters, quick notes, an
///                                 explained lab report and a measurement
///                                 series, plus an archived wisdom-tooth
///                                 Journey and a filled Profile
///   -uitest-subscription <state>  pin Carelogue Plus to active | none, so the
///                                 paywall and the locked card can be driven
///                                 without the App Store
///   -uitest-fake-ai <mode>        explain through a scripted provider instead
///                                 of DeepSeek: success | slow | fail | invalid
///   env UITEST_API_KEY=<key>      store this key in the Keychain at launch
///   -selftest-explain             explain the seeded report photo twice (needs
///                                 -uitest-seed-attachments, a key and
///                                 -ai.consent granted) and
///                                 write Documents/selftest-explain.txt
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
        if arguments.contains("-uitest-seed-demo") {
            seedDemo(context)
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
        if arguments.contains("-selftest-explain") {
            Task { await runExplainSelfTest(context) }
        }
    }

    /// Set by -uitest-fake-ai; AISettings.makeService(entitlement:) prefers it.
    static var fakeAIService: FakeAIService?

    /// -uitest-subscription active | none. Nil when the flag is absent, and
    /// then SubscriptionService talks to StoreKit as usual.
    @MainActor
    static var forcedSubscriptionStatus: SubscriptionService.Status? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uitest-subscription"),
              index + 1 < arguments.count else { return nil }
        switch arguments[index + 1] {
        case "active":
            return .subscribed(expires: Calendar.current.date(byAdding: .month, value: 1, to: .now))
        case "none":
            return .notSubscribed
        default:
            return nil
        }
    }

    private static func runExplainSelfTest(_ context: ModelContext) async {
        var report = ""
        let artifacts = (try? context.fetch(FetchDescriptor<Artifact>())) ?? []
        if let photo = artifacts.first(where: { $0.fileName == "seed_photo_1.jpg" }) {
            for attempt in 1...2 {
                let start = Date.now
                do {
                    let outcome = try await ExplainService.explain(photo, in: context)
                    report += "== attempt \(attempt): \(outcome) (\(Int(Date.now.timeIntervalSince(start) * 1000))ms)\n"
                } catch {
                    report += "== attempt \(attempt) ERROR \(error): \(error.localizedDescription)\n"
                }
            }
            report += "\n== stored aiExplainJSON:\n\(photo.aiExplainJSON ?? "nil")\n"
        } else {
            report += "no seeded photo\n"
        }
        let url = URL.documentsDirectory.appendingPathComponent("selftest-explain.txt")
        try? report.write(to: url, atomically: true, encoding: .utf8)
    }

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

    // MARK: - Demo store (documentation screenshots)

    /// Content-rich store for docs/screenshots: the Stitch screens show a
    /// Journey in full swing, so the shots need a Journey in full swing too.
    /// Everything here goes through the normal models — no schema additions,
    /// and the app cannot tell this apart from data the user typed.
    static let demoJourneyName = "孕期档案"
    static let demoArchivedJourneyName = "拔智齿记录"
    /// The explained attachment's timeline card, used to open it in tests.
    static let demoReportNote = "孕早期综合筛查 First Trimester Screen：血检 + NT 超声，报告当天出。"

    private static func seedDemo(_ context: ModelContext) {
        let calendar = Calendar.current
        func day(_ offset: Int, hour: Int = 10, minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: .now)!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        // 1. The running pregnancy Journey.
        let pregnancy = Journey(name: demoJourneyName, template: .pregnancy,
                                createdAt: day(-84), updatedAt: day(-1, hour: 22, minute: 15))
        context.insert(pregnancy)

        add(Log(kind: .encounter, type: "体检", occurredAt: day(11),
                note: "大排畸超声检查；记得带上 CareCard (PHN) 与 NT 报告纸质件。",
                location: "妇幼保健院 产科二诊室", doctor: "Dr. Chen"),
            to: pregnancy, context: context)

        add(Log(kind: .quick, type: "症状", occurredAt: day(-1, hour: 22, minute: 15),
                note: "晚上腰又开始酸，坐久了明显。垫了孕妇枕侧睡感觉好一点。"),
            to: pregnancy, context: context)

        let report = Log(kind: .encounter, type: "验血", occurredAt: day(-3, hour: 9, minute: 30),
                         note: demoReportNote, location: "Lab Health BC", doctor: "Dr. Chen")
        add(report, to: pregnancy, context: context)
        let files: [(Data, String, String)] = [
            (reportImage(), "lab_report.jpg", AttachmentMime.jpeg),
            (ultrasoundImage(), "nt_ultrasound.jpg", AttachmentMime.jpeg),
            (demoPDF(), "requisition.pdf", AttachmentMime.pdf),
        ]
        for (offset, file) in files.enumerated() {
            let artifact = Artifact(fileData: file.0, fileName: file.1, mime: file.2,
                                    createdAt: day(-3, hour: 9, minute: 30 + offset))
            // The lab report is the explained one; the explanation is stored
            // exactly as ExplainService would cache it.
            if offset == 0 {
                artifact.aiExplainJSON = demoExplanationJSON(createdAt: day(-3, hour: 12))
            }
            context.insert(artifact)
            artifact.log = report
        }

        add(Log(kind: .encounter, type: "面诊", occurredAt: day(-7),
                note: "胎心音正常 152 bpm。下次做 NT 超声 + 血检筛查，已开具 Requisition 检查单。",
                location: "BC Women's Hospital", doctor: "Dr. Chen"),
            to: pregnancy, context: context)

        add(Log(kind: .quick, type: "情绪", occurredAt: day(-12, hour: 16, minute: 40),
                note: "第一次听到胎心，走出诊室在车里坐了十分钟才缓过来。"),
            to: pregnancy, context: context)

        add(Log(kind: .encounter, type: "面诊", occurredAt: day(-21),
                note: "电话预约，等待 12 天。OB 转诊信已由 Family Doctor 诊所确认接收。",
                location: "Family Doctor 诊所", doctor: "Dr. Wong"),
            to: pregnancy, context: context)

        // Weekly weight (a real curve, not a straight line), a few blood
        // pressures, one temperature.
        let weights = [58.2, 58.4, 58.1, 58.9, 59.6, 59.4, 60.3, 61.0, 61.4, 62.3, 62.1, 63.0]
        for (week, weight) in weights.enumerated() {
            add(Log(kind: .measurement, type: "体重", occurredAt: day(-7 * (weights.count - 1 - week) - 2, hour: 7),
                    value: weight, unit: "kg"),
                to: pregnancy, context: context)
        }
        for (index, value) in [114.0, 118, 111].enumerated() {
            add(Log(kind: .measurement, type: "血压", occurredAt: day(-10 * index - 3, hour: 8),
                    value: value, unit: "mmHg"),
                to: pregnancy, context: context)
        }
        add(Log(kind: .measurement, type: "体温", occurredAt: day(-4, hour: 21),
                value: 36.7, unit: "°C"),
            to: pregnancy, context: context)

        // 2. A finished Journey, so the list shows both states.
        let tooth = Journey(name: demoArchivedJourneyName, template: .toothExtraction,
                            status: .done, createdAt: day(-146), updatedAt: day(-100))
        context.insert(tooth)
        add(Log(kind: .encounter, type: "面诊", occurredAt: day(-146),
                note: "右下阻生智齿，拍了全景片，安排微创拔除。",
                location: "UBC 口腔外科", doctor: "Dr. Patel"),
            to: tooth, context: context)
        add(Log(kind: .encounter, type: "其他", occurredAt: day(-140),
                note: "局麻微创拔除，约 40 分钟。医嘱：24 小时内不漱口，冰敷。",
                location: "UBC 口腔外科", doctor: "Dr. Patel"),
            to: tooth, context: context)
        add(Log(kind: .quick, type: "症状", occurredAt: day(-139, hour: 20),
                note: "第二天肿得厉害，冰敷 + 布洛芬 400mg，晚上能睡。"),
            to: tooth, context: context)
        add(Log(kind: .quick, type: "备注", occurredAt: day(-100, hour: 11),
                note: "复查：牙槽窝愈合良好，可以正常咀嚼，结案。"),
            to: tooth, context: context)

        // 3. Profile, so P4 isn't an empty form in the screenshots.
        context.insert(Profile(
            allergies: "青霉素 Penicillin — 皮疹（2016 年）",
            medications: "叶酸 0.8mg 每日一次 · 孕期多元维生素",
            vaccines: "流感疫苗 2025/10 · Tdap 2026/06",
            history: "2019 右下阻生智齿拔除术，无并发症。无慢性病史。",
            updatedAt: day(-30)
        ))
    }

    /// A cached explanation for the seeded lab report: the same shape
    /// ExplainService writes, so the card and the timeline summary line
    /// render without a provider.
    private static func demoExplanationJSON(createdAt: Date) -> String? {
        let explanation = Explanation(
            summaryPlain: "这次检查整体平稳。血红蛋白 112 g/L，略低于参考范围（115–150），孕中期常见，多是生理性血液稀释；白细胞和血小板都在正常范围内。NT 颈项透明层 1.4 mm，低于 2.5 mm 的参考上限。",
            terms: [
                .init(original: "Hb · 血红蛋白", plain: "血液里运送氧气的蛋白，偏低时容易疲劳"),
                .init(original: "WBC · 白细胞", plain: "免疫细胞数量，反映有没有感染"),
                .init(original: "PLT · 血小板", plain: "帮助止血的细胞"),
                .init(original: "NT · 颈项透明层", plain: "孕早期超声测量的胎儿颈后积液厚度"),
            ],
            questions: [
                "血红蛋白 112 g/L 需要补铁吗？还是先从饮食调整？",
                "如果要补铁，多久后复查一次血常规比较合适？",
                "NT 结果正常，后续还需要做哪些筛查？",
            ],
            model: "deepseek-chat",
            createdAt: createdAt
        )
        return (try? ExplainService.encoder.encode(explanation)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// The seeded PDF attachment: a lab requisition, so the preview shot
    /// reads as a real document instead of the "UITest report" fixture that
    /// `pdf()` writes for the functional tests.
    private static func demoPDF() -> Data {
        let pages: [(String, [String])] = [
            ("Lab Health BC · 检验申请单 Requisition", [
                "患者 Patient: L. Wang        PHN: 9xxx xxx xxx",
                "开单医生 Ordering: Dr. Chen, BC Women's Hospital",
                "日期 Date: 2026-09-18",
                "项目 Tests: CBC · 血常规",
                "         First Trimester Screen · 孕早期筛查",
                "         NT Ultrasound · 颈项透明层超声",
            ]),
            ("检验结果 Results", reportLines),
        ]
        return UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { context in
            for (title, lines) in pages {
                context.beginPage()
                (title as NSString).draw(
                    at: CGPoint(x: 60, y: 80),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 22, weight: .semibold)]
                )
                for (index, line) in lines.enumerated() {
                    (line as NSString).draw(
                        at: CGPoint(x: 60, y: 140 + CGFloat(index) * 34),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 15)]
                    )
                }
            }
        }
    }

    /// Greyscale scan-looking image for the attachment gallery: a fan-shaped
    /// sweep on black, which reads as an ultrasound at thumbnail size.
    private static func ultrasoundImage() -> Data {
        let size = CGSize(width: 1000, height: 750)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let fan = UIBezierPath()
            let apex = CGPoint(x: size.width / 2, y: 40)
            fan.move(to: apex)
            fan.addArc(withCenter: apex, radius: 660, startAngle: .pi / 3, endAngle: .pi * 2 / 3, clockwise: true)
            fan.close()
            context.cgContext.saveGState()
            fan.addClip()
            for band in 0..<26 {
                UIColor(white: 0.10 + CGFloat(band % 7) * 0.055, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: CGFloat(band) * 29, width: size.width, height: 22))
            }
            UIColor(white: 0.85, alpha: 0.9).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 430, y: 300, width: 190, height: 140))
            UIColor(white: 0.55, alpha: 0.8).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 380, y: 420, width: 260, height: 180))
            context.cgContext.restoreGState()

            let caption = "NT 1.4 mm   BC Women's   12w+3"
            (caption as NSString).draw(
                at: CGPoint(x: 40, y: size.height - 60),
                withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 26, weight: .regular),
                                 .foregroundColor: UIColor(white: 0.9, alpha: 1)]
            )
        }
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
            try await Task.sleep(for: .milliseconds(1500))
            throw AIServiceError.timeout
        case "invalid":
            return "{\"summary_plain\": \"\"}"
        case "count":
            // Summary carries the request number, so a test can tell a cached
            // (throttled) result from a fresh one.
            try await Task.sleep(for: .milliseconds(400))
            return Self.sampleJSON.replacingOccurrences(of: "参考上限。", with: "参考上限。[#\(FakeAIService.requestCount)]")
        case "long":
            try await Task.sleep(for: .milliseconds(300))
            let summary = String(repeating: "这是一段用来测试长文本排版的白话总结，包含很多很多字，确保卡片在内容很长时也不会破版。", count: 8)
            let terms = (1...10).map { "{\"original\": \"LongTerm\($0) · 一个名字特别特别长的医学术语缩写示例\($0)\", \"plain\": \"解释\($0)\"}" }
            let questions = (1...5).map { "\"第 \($0) 个问题：" + String(repeating: "这是一个很长的问题，", count: 6) + "\"" }
            return "{\"summary_plain\": \"\(summary)\", \"terms\": [\(terms.joined(separator: ","))], \"questions\": [\(questions.joined(separator: ","))]}"
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
