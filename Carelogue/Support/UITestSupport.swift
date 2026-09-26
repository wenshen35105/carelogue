#if DEBUG
import AVFoundation
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
///   -uitest-no-icloud             pin CloudSync to "signed out of iCloud"
///                                 (T39: the share fallback and the on-device
///                                 recording note)
///   -uitest-icloud-account        pin CloudSync to "signed in" for the copy
///                                 that mentions iCloud
///   -uitest-fake-share <state>    pin the first active Journey's CKShare
///                                 metadata without an account (T39): active |
///                                 ended. ShareChannel.simulated goes on, so
///                                 no network path runs and the share UI
///                                 renders purely from model fields
///   -uitest-subscription <state>  pin Carelogue Plus to active | none, so the
///                                 paywall and the locked card can be driven
///                                 without the App Store
///   -uitest-fake-ai <mode>        explain through a scripted provider instead
///                                 of the relay: success | slow | fail | invalid
///   -uitest-seed-visit            add a bare 面诊 Log (T32: the recording card
///                                 and 我的疑问 with nothing in them yet)
///   -uitest-seed-recording        the same visit, with a short silent
///                                 recording already attached and transcribed,
///                                 so the summarize step can be driven without
///                                 a microphone
///   -uitest-fake-transcript <m>   transcribe with a scripted recognizer
///                                 instead of the on-device one (T32):
///                                 success | slow | fail | empty
///   env INTERNAL_ACCESS_KEY=<key> unlock the internal channel at launch (T30),
///                                 so the relay chain can be driven unattended
///   -selftest-explain             explain the seeded report photo twice (needs
///                                 -uitest-seed-attachments, a way through the
///                                 relay — INTERNAL_ACCESS_KEY or a
///                                 subscription — and -ai.consent granted) and
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
            InternalAccess.setCredential(nil)
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("ai.") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        if let key = ProcessInfo.processInfo.environment["INTERNAL_ACCESS_KEY"], !key.isEmpty {
            InternalAccess.setCredential(key)
        }
        if arguments.contains("-uitest-no-icloud") {
            CloudSync.forcedNoAccount = true
        }
        if arguments.contains("-uitest-icloud-account") {
            CloudSync.forcedAccount = true
        }
        if let index = arguments.firstIndex(of: "-uitest-fake-ai"), index + 1 < arguments.count {
            fakeAIService = FakeAIService(mode: arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "-uitest-fake-transcript"), index + 1 < arguments.count {
            fakeTranscriber = FakeTranscriber(mode: arguments[index + 1])
        }
        if arguments.contains("-uitest-seed-demo") {
            seedDemo(context)
        }
        if arguments.contains("-uitest-seed-measurements") || arguments.contains("-uitest-seed-attachments")
            || arguments.contains("-uitest-seed-recording") || arguments.contains("-uitest-seed-visit") {
            let journey = Journey(name: seededJourneyName, template: .pregnancy)
            context.insert(journey)
            if arguments.contains("-uitest-seed-measurements") {
                seedMeasurements(in: journey, context: context)
            }
            if arguments.contains("-uitest-seed-attachments") {
                seedAttachments(in: journey, context: context)
            }
            if arguments.contains("-uitest-seed-recording") || arguments.contains("-uitest-seed-visit") {
                seedVisit(in: journey, context: context,
                          withRecording: arguments.contains("-uitest-seed-recording"))
            }
        }
        // After seeding, so the pinned journey exists to pin. (Also after
        // -uitest-seed-demo, whose first active journey is the one to stamp.)
        if let index = arguments.firstIndex(of: "-uitest-fake-share"), index + 1 < arguments.count {
            ShareChannel.simulated = true
            fakeShare(mode: arguments[index + 1], context: context)
        }
        try? context.save()
        if arguments.contains("-selftest-extract") {
            Task { await runExtractionSelfTest() }
        }
        if arguments.contains("-selftest-explain") {
            Task { await runExplainSelfTest(context) }
        }
    }

    /// Set by -uitest-fake-transcript; VisitTranscription prefers it, so the
    /// recording flow can be driven on a simulator that has no speech model
    /// and no microphone worth listening to.
    static var fakeTranscriber: FakeTranscriber?

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
    /// The store follows the launch language (T41: the English App Store
    /// listing needs English content, not Chinese records under English UI).
    /// Log types stay the stored Chinese keys — the app localises those.
    private static func l(_ zh: String, _ en: String) -> String {
        AppLanguage.isChinese ? zh : en
    }
    static var demoJourneyName: String { l("孕期档案", "Our First Baby") }
    static var demoArchivedJourneyName: String { l("拔智齿记录", "Wisdom Tooth") }
    /// The explained attachment's timeline card, used to open it in tests.
    static var demoReportNote: String {
        l("孕早期综合筛查 First Trimester Screen：血检 + NT 超声，报告当天出。",
          "First Trimester Screen: blood work + NT ultrasound, results the same day.")
    }

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
                note: l("大排畸超声检查；记得带上 CareCard (PHN) 与 NT 报告纸质件。",
                        "20-week anatomy scan. Bring the CareCard (PHN) and the paper NT report."),
                location: l("妇幼保健院 产科二诊室", "BC Women's Hospital, OB Clinic 2"), doctor: "Dr. Chen"),
            to: pregnancy, context: context)

        add(Log(kind: .quick, type: "症状", occurredAt: day(-1, hour: 22, minute: 15),
                note: l("晚上腰又开始酸，坐久了明显。垫了孕妇枕侧睡感觉好一点。",
                        "Lower back ached again tonight, worse after sitting. Side-sleeping with the pregnancy pillow helped.")),
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

        // The recorded visit (T32). The recording, its transcript, the summary
        // and the questions are all in place, because that is the state the
        // documentation screenshots need to show.
        let recordedVisit = Log(kind: .encounter, type: "面诊", occurredAt: day(-7),
                                note: l("胎心音正常 152 bpm。下次做 NT 超声 + 血检筛查，已开具 Requisition 检查单。",
                                        "Fetal heart rate normal, 152 bpm. NT ultrasound + blood screening next; requisition issued."),
                                location: "BC Women's Hospital", doctor: "Dr. Chen")
        add(recordedVisit, to: pregnancy, context: context)
        // 32:14 on the card, the way the design sheet shows it.
        if let audio = silentRecording(seconds: 32 * 60 + 14) {
            let recording = Artifact(fileData: audio, fileName: "visit-20260916-1030.m4a",
                                     mime: Artifact.audioMime,
                                     createdAt: day(-7, hour: 10, minute: 30),
                                     transcript: FakeTranscriber.sampleTranscript)
            context.insert(recording)
            recordedVisit.add(recording)
        }
        recordedVisit.visitSummaryJSON = demoVisitSummaryJSON(createdAt: day(-7, hour: 11))
        recordedVisit.questionsJSON = demoQuestionsJSON(updatedAt: day(-7, hour: 9))

        add(Log(kind: .quick, type: "情绪", occurredAt: day(-12, hour: 16, minute: 40),
                note: l("第一次听到胎心，走出诊室在车里坐了十分钟才缓过来。",
                        "Heard the heartbeat for the first time. Sat in the car for ten minutes before I could drive.")),
            to: pregnancy, context: context)

        add(Log(kind: .encounter, type: "面诊", occurredAt: day(-21),
                note: l("电话预约，等待 12 天。OB 转诊信已由 Family Doctor 诊所确认接收。",
                        "Booked by phone, 12-day wait. The clinic confirmed the OB referral letter was received."),
                location: l("Family Doctor 诊所", "Family Doctor Clinic"), doctor: "Dr. Wong"),
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
                note: l("右下阻生智齿，拍了全景片，安排微创拔除。",
                        "Impacted lower-right wisdom tooth. Panoramic X-ray taken; minimally invasive extraction booked."),
                location: l("UBC 口腔外科", "UBC Oral Surgery"), doctor: "Dr. Patel"),
            to: tooth, context: context)
        add(Log(kind: .encounter, type: "其他", occurredAt: day(-140),
                note: l("局麻微创拔除，约 40 分钟。医嘱：24 小时内不漱口，冰敷。",
                        "Extracted under local anesthetic, about 40 minutes. No rinsing for 24 hours; ice packs."),
                location: l("UBC 口腔外科", "UBC Oral Surgery"), doctor: "Dr. Patel"),
            to: tooth, context: context)
        add(Log(kind: .quick, type: "症状", occurredAt: day(-139, hour: 20),
                note: l("第二天肿得厉害，冰敷 + 布洛芬 400mg，晚上能睡。",
                        "Very swollen on day two. Ice + ibuprofen 400 mg; managed to sleep.")),
            to: tooth, context: context)
        add(Log(kind: .quick, type: "备注", occurredAt: day(-100, hour: 11),
                note: l("复查：牙槽窝愈合良好，可以正常咀嚼，结案。",
                        "Follow-up: socket healed well, chewing normally. Case closed.")),
            to: tooth, context: context)

        // 3. Profile, so P4 isn't an empty form in the screenshots.
        context.insert(Profile(
            allergies: l("青霉素 Penicillin — 皮疹（2016 年）", "Penicillin — rash (2016)"),
            medications: l("叶酸 0.8mg 每日一次 · 孕期多元维生素", "Folic acid 0.8 mg daily · prenatal multivitamin"),
            vaccines: l("流感疫苗 2025/10 · Tdap 2026/06", "Flu shot 2025/10 · Tdap 2026/06"),
            history: l("2019 右下阻生智齿拔除术，无并发症。无慢性病史。",
                       "2019 lower-right wisdom tooth extraction, no complications. No chronic conditions."),
            updatedAt: day(-30)
        ))
    }

    /// A cached explanation for the seeded lab report: the same shape
    /// ExplainService writes, so the card and the timeline summary line
    /// render without a provider.
    /// T32: what a finished 面诊总结 looks like on a real visit.
    private static func demoVisitSummaryJSON(createdAt: Date) -> String? {
        let summary = VisitSummary(
            saidPlain: l("这次产科面诊整体顺利。医生听诊胎心 152 次/分，说处于正常范围；宫高与腹围都符合 14 周的生长曲线。聊到最近的轻微腰酸，医生说是韧带拉伸引起的常见反应，建议避免久坐、侧睡时使用孕妇枕。血常规里血红蛋白偏低一点，医生让按现在的方式继续补充，两周后复查。下次产检会做 NT 超声与血检筛查，检查单当场开具。",
                         "The prenatal visit went well. The doctor heard a fetal heart rate of 152 bpm, which is in the normal range, and fundal height and belly size both match 14 weeks. The recent mild back pain is most likely ligaments stretching — common in pregnancy; avoid sitting for long and use a pregnancy pillow when sleeping on your side. Hemoglobin was a little low, so keep taking the current supplements and recheck in two weeks. The next visit includes an NT ultrasound and blood screening; the requisition was issued today."),
            keyPoints: [
                l("两周后复查血常规，看血红蛋白有没有回升", "Recheck the blood count in two weeks to see if hemoglobin is up"),
                l("下次产检带上 Lab Health BC 出具的纸质 NT 超声报告", "Bring the paper NT ultrasound report from Lab Health BC next time"),
                l("腰酸时避免久坐，侧睡垫孕妇枕", "For back pain: avoid long sitting, side-sleep with a pregnancy pillow"),
                l("出现持续腹痛或水肿加重，随时联系诊所护士", "Call the clinic nurse for ongoing belly pain or worsening swelling"),
            ],
            followUps: [
                l("复查血常规需要空腹吗？", "Do I need to fast for the blood recheck?"),
                l("下次大排畸超声的预约时间窗口是什么时候？", "When is the booking window for the anatomy scan?"),
            ],
            model: "carelogue-relay",
            createdAt: createdAt
        )
        return (try? ExplainService.encoder.encode(summary)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// T32: 我的疑问, already translated — the state the hand-off screen shows.
    private static func demoQuestionsJSON(updatedAt: Date) -> String? {
        let questions = VisitQuestions(
            items: [
                .init(text: "血糖偏高需要控制饮食吗？",
                      translated: "Do I need to watch my diet given the higher blood sugar levels?"),
                .init(text: "目前的轻微腰酸需要物理治疗还是卧床休息？",
                      translated: "Is the lower back pain normal at 14 weeks, or should I see a pelvic physiotherapist?"),
                .init(text: "下次大排畸超声检查需要空腹或憋尿吗？",
                      translated: "Does the 20-week anatomy scan require fasting or a full bladder?"),
            ],
            updatedAt: updatedAt
        )
        return (try? ExplainService.encoder.encode(questions)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func demoExplanationJSON(createdAt: Date) -> String? {
        let explanation = Explanation(
            summaryPlain: l("这次检查整体平稳。血红蛋白 112 g/L，略低于参考范围（115–150），孕中期常见，多是生理性血液稀释；白细胞和血小板都在正常范围内。NT 颈项透明层 1.4 mm，低于 2.5 mm 的参考上限。",
                            "Overall a steady result. Hemoglobin is 112 g/L, a little below the reference range (115–150) — common mid-pregnancy, usually because blood volume grows faster than red cells. White cells and platelets are both normal. The NT measurement is 1.4 mm, under the 2.5 mm upper limit."),
            terms: [
                .init(original: l("Hb · 血红蛋白", "Hb · Hemoglobin"),
                      plain: l("血液里运送氧气的蛋白，偏低时容易疲劳", "The protein that carries oxygen; low levels can make you tired")),
                .init(original: l("WBC · 白细胞", "WBC · White blood cells"),
                      plain: l("免疫细胞数量，反映有没有感染", "Immune cells; the count hints at infection")),
                .init(original: l("PLT · 血小板", "PLT · Platelets"),
                      plain: l("帮助止血的细胞", "Cells that help blood clot")),
                .init(original: l("NT · 颈项透明层", "NT · Nuchal translucency"),
                      plain: l("孕早期超声测量的胎儿颈后积液厚度", "Fluid thickness at the back of the baby's neck, measured by early ultrasound")),
            ],
            questions: [
                l("血红蛋白 112 g/L 需要补铁吗？还是先从饮食调整？", "Should I take iron for hemoglobin at 112 g/L, or start with diet?"),
                l("如果要补铁，多久后复查一次血常规比较合适？", "If I take iron, when should the blood count be rechecked?"),
                l("NT 结果正常，后续还需要做哪些筛查？", "The NT result is normal — which screenings come next?"),
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

    static let seededVisitNote = "UITest 面诊录音"

    /// T39: pins the first active Journey's share metadata so the marker,
    /// info sheet and fallback copy can be driven without an account.
    /// "ended" leaves `isShared` false — the steady state after a revoke.
    private static func fakeShare(mode: String, context: ModelContext) {
        let journeys = (try? context.fetch(FetchDescriptor<Journey>())) ?? []
        guard let journey = journeys.first(where: { $0.status == .active }) ?? journeys.first else { return }
        journey.shareRecordID = "share-fake"
        journey.ownerID = "user-fake"
        journey.shareZoneOwnerName = "__fakeOwner__"
        journey.isShared = mode == "active"
        journey.lastSharedUpdatedAt = .now
        try? context.save()
    }

    /// T32: a visit to hang the recording card off. With `withRecording`, the
    /// audio is a real (silent) m4a written here — small, valid, and enough
    /// for AVAudioPlayer to report a duration — with the transcript already
    /// filled in, which is the state the simulator cannot reach on its own.
    private static func seedVisit(in journey: Journey, context: ModelContext, withRecording: Bool) {
        let visit = Log(kind: .encounter, type: "面诊",
                        occurredAt: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                        note: seededVisitNote, location: "BC Women's Hospital", doctor: "Dr. Chen")
        add(visit, to: journey, context: context)
        guard withRecording, let audio = silentRecording() else { return }
        let artifact = Artifact(fileData: audio, fileName: "visit-uitest.m4a",
                                mime: Artifact.audioMime,
                                transcript: FakeTranscriber.sampleTranscript)
        context.insert(artifact)
        visit.add(artifact)
    }

    /// Silence, encoded as the app's own recording format — a real, valid
    /// m4a, just with nothing in it to hear.
    private static func silentRecording(seconds: Int = 2) -> Data? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uitest-silence-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: VisitRecorder.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: VisitRecorder.bitRate,
        ]
        guard let format = AVAudioFormat(standardFormatWithSampleRate: VisitRecorder.sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(VisitRecorder.sampleRate)) else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity
        // The writer has to go out of scope before the file is read: an m4a
        // is only finalised (and its duration readable) when it closes.
        do {
            guard let file = try? AVAudioFile(forWriting: url, settings: settings) else { return nil }
            for _ in 0..<seconds { try? file.write(from: buffer) }
        }
        let data = try? Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        return data
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

    func run(_ request: AIRequest) async throws -> String {
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
        return Self.sample(for: request.action)
    }

    static func sample(for action: String) -> String {
        switch action {
        case AIRequest.summarizeVisit: return visitSummaryJSON
        case AIRequest.translateQuestions: return translationsJSON
        default: return sampleJSON
        }
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

    /// T32: what summarize_visit comes back with.
    static let visitSummaryJSON = """
    {
      "said_plain": "这次产检整体顺利。医生听到胎心 152 次/分，说在正常范围；宫高和腹围都符合孕周。说到最近的腰酸，医生认为是韧带拉伸引起的常见反应，建议少久坐、侧睡时垫孕妇枕。血常规里血红蛋白偏低，医生让继续按现在的补充方式，两周后复查。",
      "key_points": [
        "两周后复查血常规，看血红蛋白有没有回升",
        "下次产检带上 Lab Health BC 出具的纸质 NT 超声报告",
        "腰酸时少久坐，侧睡垫孕妇枕",
        "出现持续腹痛或水肿加重，随时联系诊所护士"
      ],
      "follow_ups": [
        "复查血常规需要空腹吗？",
        "下次大排畸超声的预约时间窗口是什么时候？"
      ]
    }
    """

    /// T32: what translate_questions comes back with, for the seeded questions.
    static let translationsJSON = """
    {
      "translations": [
        {"original": "血糖偏高需要控制饮食吗？",
         "translated": "Do I need to watch my diet given the higher blood sugar levels?"},
        {"original": "目前的轻微腰酸需要物理治疗还是卧床休息？",
         "translated": "Is the lower back pain normal at 14 weeks, or should I see a pelvic physiotherapist?"},
        {"original": "下次大排畸超声检查需要空腹或憋尿吗？",
         "translated": "Does the 20-week anatomy scan require fasting or a full bladder?"}
      ]
    }
    """
}

/// Scripted stand-in for the on-device transcriber (T32). The simulator has
/// neither a microphone worth listening to nor a speech model, so the flow is
/// driven with a fixed transcript instead.
struct FakeTranscriber: VisitTranscribing {
    let mode: String

    func transcribe(fileURL: URL, locale: Locale) async throws -> String {
        switch mode {
        case "fail":
            try await Task.sleep(for: .milliseconds(600))
            throw TranscriptionError.modelUnavailable
        case "empty":
            try await Task.sleep(for: .milliseconds(400))
            throw TranscriptionError.nothingRecognized
        case "slow":
            try await Task.sleep(for: .seconds(4))
        default:
            try await Task.sleep(for: .milliseconds(700))
        }
        return Self.sampleTranscript
    }

    static let sampleTranscript = """
    医生：今天感觉怎么样？胎动有没有规律一些？
    患者：胎动还好，就是最近腰有点酸，坐久了especially 明显。
    医生：我先听一下胎心。嗯，152，很好，在正常范围里。宫高和腹围都跟孕周对得上。
    医生：腰酸这个多半是韧带拉伸，孕期很常见。建议你少久坐，侧睡的时候垫一个孕妇枕。
    患者：上次抽血的结果怎么样？
    医生：血常规里血红蛋白偏低一点，你先按现在的方式继续补，两周后我们复查一次血常规看看。
    医生：还有下次产检记得把 Lab Health BC 出的 NT 超声报告纸质件带过来。
    患者：好的。
    医生：如果出现持续的腹痛，或者水肿明显加重，随时打电话给诊所的护士。
    """
}
#endif
