import SwiftUI
import UIKit
import PDFKit

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
        if mime.hasPrefix("image/") { return String(localized: "图片") }
        return String(localized: "文件")
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
                Text(fileName.isEmpty ? String(localized: "未命名附件") : fileName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(verbatim: "\(AttachmentFormat.size(of: data)) · \(AttachmentFormat.kindLabel(mime: mime))")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail page gallery (T11)

/// "附件 Attachments (n)" card: image thumbnails in a grid, then one row per
/// PDF / other file (Stitch "原始报告凭单" rows with a trailing eye icon).
struct AttachmentGalleryCard: View {
    let artifacts: [Artifact]
    let onOpen: (Artifact) -> Void
    let onDelete: (Artifact) -> Void

    private var images: [Artifact] { artifacts.filter(\.isImage) }
    private var files: [Artifact] { artifacts.filter { !$0.isImage } }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                BilingualTitle(primary: String(localized: "附件 (\(artifacts.count))"), secondary: AppLanguage.gloss(String(localized: "Attachments")))
            }

            if !images.isEmpty {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(images) { artifact in
                        Button { onOpen(artifact) } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    GeometryReader { proxy in
                                        AttachmentThumbnail(data: artifact.fileData, mime: artifact.mime,
                                                            size: proxy.size.width, cornerRadius: Theme.Radius.inset)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu { menu(for: artifact) }
                        .accessibilityLabel("图片 \(artifact.fileName)")
                        .accessibilityIdentifier("attachment.image")
                    }
                }
            }

            ForEach(files) { artifact in
                Button { onOpen(artifact) } label: {
                    HStack(spacing: 12) {
                        AttachmentInfoRow(data: artifact.fileData, fileName: artifact.fileName, mime: artifact.mime)
                        Spacer(minLength: 4)
                        Image(systemName: "eye")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { menu(for: artifact) }
                .accessibilityIdentifier("attachment.file")
            }

            Text("长按附件可删除")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .cardSurface()
    }

    @ViewBuilder
    private func menu(for artifact: Artifact) -> some View {
        Button("查看", systemImage: "eye") { onOpen(artifact) }
        Button("删除附件", systemImage: "trash", role: .destructive) { onDelete(artifact) }
    }
}

// MARK: - Full-screen preview (T11)

/// Full-screen viewer: pinch-zoomable image or a PDFKit document. It copies
/// the artifact's bytes up front so it never touches the model after the
/// artifact has been deleted.
struct AttachmentPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    private let data: Data
    private let fileName: String
    private let mime: String
    private let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    init(artifact: Artifact, onDelete: @escaping () -> Void) {
        data = artifact.fileData
        fileName = artifact.fileName
        mime = artifact.mime
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            content
                .accessibilityIdentifier("attachment.preview")
                .ignoresSafeArea(edges: .bottom)
                .background(Theme.background)
                .navigationTitle(fileName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("删除附件")
                    }
                }
                .confirmationDialog("删除这份附件？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("删除后无法恢复")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if mime == AttachmentMime.pdf {
            PDFKitView(data: data)
        } else if mime.hasPrefix("image/"), let image = UIImage(data: data) {
            ZoomableImageView(image: image)
        } else {
            ContentUnavailableView("无法预览此文件", systemImage: "doc.questionmark")
        }
    }
}

/// UIScrollView-backed image viewer: pinch to zoom, double-tap to toggle.
private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            if scrollView.zoomScale > 1 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let size = CGSize(width: scrollView.bounds.width / 2.5, height: scrollView.bounds.height / 2.5)
                scrollView.zoom(to: CGRect(origin: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), size: size),
                                animated: true)
            }
        }
    }
}

/// PDFKit document view (continuous vertical scroll, pinch to zoom).
private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(Theme.background)
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
