import SwiftUI
import SwiftData

/// 统一详情页（就诊/随手记/测量共用）.
struct LogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let log: Log

    @State private var showingEditor = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if log.kind == .measurement, let value = log.value {
                    card {
                        Text("\(value.formatted()) \(log.unit ?? "")")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(Theme.inkPrimary)
                    }
                }

                if log.kind == .encounter, hasLocationOrDoctor {
                    card {
                        VStack(alignment: .leading, spacing: 6) {
                            if let location = log.location, !location.isEmpty {
                                labeledRow(label: "地点", value: location)
                            }
                            if let doctor = log.doctor, !doctor.isEmpty {
                                labeledRow(label: "医生", value: doctor)
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
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let journey = log.journey {
                LogEditorView(journey: journey, kind: log.kind, existingLog: log)
            }
        }
        .confirmationDialog("删除这条记录？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                modelContext.delete(log)
                try? modelContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(log.type.isEmpty ? log.kind.rawValue : log.type)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.inkPrimary)
            Text(log.occurredAt.formatted(.dateTime.year().month().day().hour().minute().locale(Theme.locale)))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
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

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}
