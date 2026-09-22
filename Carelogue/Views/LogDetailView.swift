import SwiftUI
import SwiftData

/// 统一详情页（就诊/随手记/测量共用）.
struct LogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let log: Log

    @State private var showingEditor = false
    @State private var showingDeleteConfirm = false
    @State private var previewingArtifact: Artifact?
    @State private var artifactPendingDelete: Artifact?
    /// Delete requested from inside the full-screen viewer; applied only
    /// after the viewer has fully dismissed, so the cover's content is never
    /// re-evaluated against an already-deleted Artifact.
    @State private var artifactDeletedInViewer: Artifact?

    private var sortedArtifacts: [Artifact] {
        log.artifacts.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if log.kind == .measurement, let value = log.value {
                    card {
                        Text(verbatim: "\(value.formatted(.number.locale(AppLanguage.locale))) \(log.unit ?? "")")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(Theme.inkPrimary)
                    }
                }

                if log.kind == .encounter, hasLocationOrDoctor {
                    card {
                        VStack(alignment: .leading, spacing: 6) {
                            if let location = log.location, !location.isEmpty {
                                labeledRow(label: String(localized: "地点"), value: location)
                            }
                            if let doctor = log.doctor, !doctor.isEmpty {
                                labeledRow(label: String(localized: "医生"), value: doctor)
                            }
                        }
                    }
                }

                if let note = log.note, !note.isEmpty {
                    card {
                        Text(note)
                            .foregroundStyle(Theme.inkPrimary)
                    }
                }

                if !log.artifacts.isEmpty {
                    AttachmentGalleryCard(
                        artifacts: sortedArtifacts,
                        onOpen: { previewingArtifact = $0 },
                        onDelete: { artifactPendingDelete = $0 }
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Both direct taps, not behind a menu: List -> Timeline card ->
            // 编辑 is 3 taps total, matching the ≤3-tap edit requirement.
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") { showingEditor = true }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("删除记录")
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let journey = log.journey {
                LogEditorView(journey: journey, kind: log.kind, existingLog: log)
            }
        }
        .fullScreenCover(item: $previewingArtifact, onDismiss: {
            if let artifact = artifactDeletedInViewer {
                artifactDeletedInViewer = nil
                deleteArtifact(artifact)
            }
        }) { artifact in
            AttachmentPreviewView(artifact: artifact) {
                artifactDeletedInViewer = artifact
            }
        }
        .confirmationDialog(
            "删除这份附件？",
            isPresented: Binding(
                get: { artifactPendingDelete != nil },
                set: { if !$0 { artifactPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: artifactPendingDelete
        ) { artifact in
            Button("删除", role: .destructive) { deleteArtifact(artifact) }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("删除后无法恢复")
        }
        .confirmationDialog("删除这条记录？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                modelContext.deleteLog(log)
                try? modelContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    /// Stitch report-detail header: rounded icon tile + title + meta line.
    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: log.kind.iconName)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.accentTint))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(log.typeDisplayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.inkPrimary)
                    Spacer(minLength: 8)
                    TagPill(text: log.isUpcoming ? String(localized: "即将 Upcoming") : log.kind.pillLabel,
                            tinted: log.isUpcoming)
                }
                Text(log.occurredAt.formatted(.dateTime.year().month().day().hour().minute().locale(AppLanguage.locale)))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .cardSurface()
    }

    /// Deleting the Artifact row also lets SwiftData drop its external-storage
    /// file. It is removed from log.artifacts first so this page refreshes.
    private func deleteArtifact(_ artifact: Artifact) {
        previewingArtifact = nil
        log.artifacts.removeAll { $0.id == artifact.id }
        modelContext.delete(artifact)
        log.updatedAt = .now
        try? modelContext.save()
    }

    private var hasLocationOrDoctor: Bool {
        log.location?.isEmpty == false || log.doctor?.isEmpty == false
    }

    private func labeledRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 40, alignment: .leading)
            Text(value)
                .foregroundStyle(Theme.inkPrimary)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().cardSurface()
    }
}
