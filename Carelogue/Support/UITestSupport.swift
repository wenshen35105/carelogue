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
///                                 2 images + 1 PDF
enum UITestSupport {
    static let seededJourneyName = "UITest 孕期"

    static func prepare(_ context: ModelContext) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uitest-reset") {
            try? context.delete(model: Artifact.self)
            try? context.delete(model: Log.self)
            try? context.delete(model: Journey.self)
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
            (image(hue: 0.07), "seed_photo_1.jpg", AttachmentMime.jpeg),
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

    private static func pdf() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { context in
            for page in 1...2 {
                context.beginPage()
                ("UITest report — page \(page)" as NSString).draw(
                    at: CGPoint(x: 60, y: 80),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 28)]
                )
            }
        }
    }
}
#endif
