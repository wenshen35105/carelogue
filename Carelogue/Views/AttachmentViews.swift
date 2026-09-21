import SwiftUI
import UIKit

// Shared attachment building blocks used by the Log editor (T10) and the
// Log detail page (T11). Stitch reference: report_explanation "原始报告凭单".

extension Artifact {
    var isImage: Bool { mime.hasPrefix("image/") }
    var isPDF: Bool { mime == AttachmentMime.pdf }
}

enum AttachmentFormat {
    /// "1.2 MB"
    static func size(of data: Data) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }

    static func kindLabel(mime: String) -> String {
        if mime == AttachmentMime.pdf { return "PDF" }
        if mime.hasPrefix("image/") { return "图片" }
        return "文件"
    }
}

/// Square thumbnail decoded off the main thread; falls back to a file tile
/// while loading or when the bytes aren't an image.
struct AttachmentThumbnail: View {
    let data: Data
    let mime: String
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 10

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                AttachmentFileTile(mime: mime, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: data.count) {
            guard mime.hasPrefix("image/") else { return }
            // Decode at 2x the display size for a sharp retina thumbnail.
            let pixelSize = CGSize(width: size * 2, height: size * 2)
            let source = data
            image = await Task.detached(priority: .utility) {
                AttachmentThumbnail.decodeThumbnail(source, pixelSize: pixelSize)
            }.value
        }
    }
}

extension AttachmentThumbnail {
    nonisolated static func decodeThumbnail(_ data: Data, pixelSize: CGSize) -> UIImage? {
        UIImage(data: data)?.preparingThumbnail(of: pixelSize)
    }
}

/// Apricot icon on a tinted rounded tile (PDF / image / generic file).
struct AttachmentFileTile: View {
    let mime: String
    var size: CGFloat = 44

    private var systemName: String {
        if mime == AttachmentMime.pdf { return "doc.richtext" }
        if mime.hasPrefix("image/") { return "photo" }
        return "doc"
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(Theme.accent)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accentTint))
    }
}

/// Icon + file name + "1.2 MB · PDF" meta line.
struct AttachmentInfoRow: View {
    let data: Data
    let fileName: String
    let mime: String

    var body: some View {
        HStack(spacing: 12) {
            AttachmentThumbnail(data: data, mime: mime)
            VStack(alignment: .leading, spacing: 3) {
                Text(fileName.isEmpty ? "未命名附件" : fileName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(AttachmentFormat.size(of: data)) · \(AttachmentFormat.kindLabel(mime: mime))")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
    }
}
