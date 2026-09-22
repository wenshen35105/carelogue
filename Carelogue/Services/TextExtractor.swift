import Foundation
import ImageIO
import PDFKit
import UIKit
import Vision

enum TextExtractionError: LocalizedError, Equatable {
    /// The file decoded fine but carries no recognisable text (blank photo,
    /// picture without writing, empty scan).
    case noText
    /// Bytes could not be decoded as an image / PDF.
    case unreadable
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .noText: return String(localized: "没有识别到文字，请确认附件内容清晰")
        case .unreadable: return String(localized: "无法读取这份附件")
        case .unsupportedType: return String(localized: "仅支持图片和 PDF")
        }
    }
}

/// On-device text extraction (spec §5a): photos go through Vision OCR,
/// PDFs through PDFKit. Only this text ever leaves the device — never the
/// image itself. Pages are separated by a "[Page n]" line and lines keep
/// their reading order, so tables in lab reports stay row-by-row.
enum TextExtractor {
    static func extract(data: Data, mime: String) async throws -> String {
        let text: String
        if mime == AttachmentMime.pdf {
            text = try await Task.detached(priority: .userInitiated) { try extractPDF(data) }.value
        } else if mime.hasPrefix("image/") {
            text = try await Task.detached(priority: .userInitiated) { try extractImage(data) }.value
        } else {
            throw TextExtractionError.unsupportedType
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(where: { $0.isLetter || $0.isNumber }) else { throw TextExtractionError.noText }
        return trimmed
    }

    // MARK: - Image (Vision)

    nonisolated private static func extractImage(_ data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw TextExtractionError.unreadable
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
        return try recognize(image, orientation: orientation)
    }

    nonisolated private static func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)
        do {
            try handler.perform([request])
        } catch {
            throw TextExtractionError.unreadable
        }
        let lines = (request.results ?? []).compactMap { observation -> (box: CGRect, text: String)? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return (observation.boundingBox, text)
        }
        return joinIntoLines(lines)
    }

    /// Vision returns text boxes in normalised coordinates (origin bottom-
    /// left). Boxes whose vertical centres overlap are one visual row — e.g.
    /// "血红蛋白 | 112 | g/L" in a lab table — joined left to right.
    nonisolated static func joinIntoLines(_ boxes: [(box: CGRect, text: String)]) -> String {
        let sorted = boxes.sorted { $0.box.midY > $1.box.midY }
        var rows: [[(box: CGRect, text: String)]] = []
        for item in sorted {
            if let last = rows.last?.first,
               abs(last.box.midY - item.box.midY) < min(last.box.height, item.box.height) * 0.5 {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
            }
        }
        return rows
            .map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ") }
            .joined(separator: "\n")
    }

    // MARK: - PDF (PDFKit, OCR fallback for scanned pages)

    nonisolated private static func extractPDF(_ data: Data) throws -> String {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw TextExtractionError.unreadable
        }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            var text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty, let image = render(page) {
                // Scanned page: no text layer, so OCR the rendered page.
                text = (try? recognize(image, orientation: .up)) ?? ""
            }
            if !text.isEmpty {
                pages.append("[Page \(index + 1)]\n\(text)")
            }
        }
        return pages.joined(separator: "\n\n")
    }

    /// Renders a page at ~2x (long edge capped at 2400px) for OCR.
    nonisolated private static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = min(2, 2400 / max(bounds.width, bounds.height))
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        return image.cgImage
    }
}
