import Foundation
import UIKit
import UniformTypeIdentifiers

/// An attachment that has been imported and processed but not yet written to
/// SwiftData. The editor keeps these in memory until the user taps 保存, so
/// cancelling the editor leaves no orphaned Artifact rows behind.
struct PendingAttachment: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let fileName: String
    let mime: String
}

enum AttachmentMime {
    static let jpeg = "image/jpeg"
    static let pdf = "application/pdf"
}

enum AttachmentImportError: LocalizedError {
    case unreadableImage
    case unsupportedType
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "无法读取这张图片"
        case .unsupportedType: return "仅支持图片和 PDF"
        case .accessDenied: return "无法访问所选文件"
        }
    }
}

/// Turns raw picker / file-importer output into storable attachments.
/// Images are always re-encoded as JPEG (quality 0.8, long edge ≤ 2048px)
/// so full-resolution originals never end up in the store.
enum AttachmentImporter {
    nonisolated static let maxImageDimension: CGFloat = 2048
    nonisolated static let jpegQuality: CGFloat = 0.8

    /// Photo library item (HEIC/JPEG/PNG bytes) -> compressed JPEG.
    static func fromPhotoData(_ data: Data, index: Int) async throws -> PendingAttachment {
        let jpeg = try await compressImage(data)
        return PendingAttachment(data: jpeg, fileName: photoFileName(index: index), mime: AttachmentMime.jpeg)
    }

    /// File picked through `.fileImporter`. PDFs are stored as-is; images are
    /// compressed like photos. Handles the security-scoped URL lifecycle.
    static func fromFile(at url: URL) async throws -> PendingAttachment {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw AttachmentImportError.accessDenied
        }

        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .pdf) == true {
            return PendingAttachment(data: data, fileName: url.lastPathComponent, mime: AttachmentMime.pdf)
        }
        if type?.conforms(to: .image) == true {
            let jpeg = try await compressImage(data)
            let baseName = url.deletingPathExtension().lastPathComponent
            return PendingAttachment(data: jpeg, fileName: "\(baseName).jpg", mime: AttachmentMime.jpeg)
        }
        throw AttachmentImportError.unsupportedType
    }

    /// Decodes, downsizes and re-encodes off the main thread.
    static func compressImage(_ data: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try resizedJPEG(from: data)
        }.value
    }

    nonisolated private static func resizedJPEG(from data: Data) throws -> Data {
        guard let image = UIImage(data: data) else { throw AttachmentImportError.unreadableImage }

        let longEdge = max(image.size.width, image.size.height)
        let scale = min(1, maxImageDimension / longEdge)
        let targetSize = CGSize(width: (image.size.width * scale).rounded(),
                                height: (image.size.height * scale).rounded())

        // Redrawing also bakes EXIF orientation into the pixels.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpeg = resized.jpegData(compressionQuality: jpegQuality) else {
            throw AttachmentImportError.unreadableImage
        }
        return jpeg
    }

    private static func photoFileName(index: Int) -> String {
        let stamp = Date.now.formatted(.verbatim(
            "\(year: .defaultDigits)\(month: .twoDigits)\(day: .twoDigits)_\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)\(second: .twoDigits)",
            timeZone: .current,
            calendar: .current
        ))
        return "IMG_\(stamp)_\(index + 1).jpg"
    }
}
