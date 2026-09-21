import SwiftUI
import SwiftData

/// P1 · Journey 列表（启动页）
struct JourneyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Journey.updatedAt, order: .reverse) private var journeys: [Journey]

    @State private var showingCreateSheet = false
    @State private var renamingJourney: Journey?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if journeys.isEmpty {
                    emptyState
                } else {
                    journeyList
                }
            }
            .background(Theme.background)
            .navigationTitle("Journeys")
            .toolbar {
                if !journeys.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .navigationDestination(for: Journey.self) { journey in
                JourneyTimelineView(journey: journey)
            }
            .sheet(isPresented: $showingCreateSheet) {
                JourneyCreationSheet()
            }
            .alert("重命名 Journey", isPresented: isRenamingBinding) {
                TextField("名称", text: $renameText)
                Button("取消", role: .cancel) {}
                Button("保存", action: commitRename)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "book.pages")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("还没有 Journey")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.inkPrimary)
            Text("创建一段旅程，开始记录就医的每一步")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            Button("开始你的第一个 Journey") {
                showingCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            Spacer()
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private var journeyList: some View {
        List {
            ForEach(journeys) { journey in
                NavigationLink(value: journey) {
                    JourneyRow(journey: journey)
                }
                .listRowBackground(Theme.card)
                .swipeActions(edge: .trailing) {
                    Button {
                        journey.status = journey.status == .active ? .done : .active
                        journey.updatedAt = .now
                        try? modelContext.save()
                    } label: {
                        Label(
                            journey.status == .active ? "归档" : "取消归档",
                            systemImage: journey.status == .active ? "archivebox" : "arrow.uturn.backward"
                        )
                    }
                    .tint(Theme.inkSecondary)

                    Button {
                        renameText = journey.name
                        renamingJourney = journey
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }
                    .tint(Theme.accent)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var isRenamingBinding: Binding<Bool> {
        Binding(
            get: { renamingJourney != nil },
            set: { if !$0 { renamingJourney = nil } }
        )
    }

    private func commitRename() {
        guard let journey = renamingJourney else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        journey.name = trimmed
        journey.updatedAt = .now
        try? modelContext.save()
        renamingJourney = nil
    }
}

private let relativeTimeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "zh_Hans")
    return formatter
}()

private struct JourneyRow: View {
    let journey: Journey

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(journey.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.inkPrimary)
                Text("\(journey.template.displayName) · 最近活动 \(relativeTimeFormatter.localizedString(for: journey.updatedAt, relativeTo: .now))")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                statusPill
                Text("\(journey.logs.count) 条记录")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusPill: some View {
        Text(journey.status.displayName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(journey.status == .active ? Theme.accent : Theme.inkSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(journey.status == .active ? Theme.accent.opacity(0.12) : Theme.border)
            )
    }
}

#Preview {
    JourneyListView()
        .modelContainer(for: [Journey.self, Log.self, Artifact.self, Profile.self], inMemory: true)
}
