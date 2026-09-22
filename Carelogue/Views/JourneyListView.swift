import SwiftUI
import SwiftData

/// P1 · Journey 列表（启动页）
struct JourneyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Journey.updatedAt, order: .reverse) private var journeys: [Journey]

    @State private var showingCreateSheet = false
    @State private var showingProfile = false
    @State private var renamingJourney: Journey?
    @State private var renameText = ""

    private var activeCount: Int {
        journeys.filter { $0.status == .active }.count
    }

    var body: some View {
        NavigationStack {
            List {
                header
                    .canvasListRow(top: 4, bottom: 16)

                ForEach(journeys) { journey in
                    journeyRow(journey)
                        .canvasListRow()
                }

                NewJourneyCard { showingCreateSheet = true }
                    .canvasListRow(top: 4, bottom: 20)

                profileEntry
                    .canvasListRow(bottom: 32)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Journeys")
            .navigationDestination(for: Journey.self) { journey in
                JourneyTimelineView(journey: journey)
            }
            .sheet(isPresented: $showingCreateSheet) {
                JourneyCreationSheet()
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
            .alert("重命名 Journey", isPresented: isRenamingBinding) {
                TextField("名称", text: $renameText)
                Button("取消", role: .cancel) {}
                Button("保存", action: commitRename)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.accent)
                Text(Date.now.formatted(.dateTime.month().day().weekday(.wide).locale(Theme.locale)))
            }
            .font(.footnote)
            .foregroundStyle(Theme.inkSecondary)
            if journeys.isEmpty {
                Text("创建一段旅程，开始记录就医的每一步")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkPrimary)
            } else {
                (Text("记录就医、检查与健康历程 · ")
                    .foregroundStyle(Theme.inkPrimary)
                 + Text("\(activeCount) 个进行中")
                    .foregroundStyle(Theme.accent)
                    .fontWeight(.semibold))
                    .font(.subheadline)
            }
        }
    }

    private func journeyRow(_ journey: Journey) -> some View {
        // Hidden NavigationLink behind the card: keeps value-based navigation
        // without List's default disclosure chevron.
        ZStack {
            NavigationLink(value: journey) { EmptyView() }
                .opacity(0)
            JourneyCard(journey: journey)
        }
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

    private var profileEntry: some View {
        Button {
            showingProfile = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(Theme.accent)
                Text("档案与设置")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkPrimary)
                Text("Profile & Settings")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

private struct JourneyCard: View {
    let journey: Journey

    private var isActive: Bool { journey.status == .active }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(journey.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.inkPrimary)
                            .lineLimit(1)
                        if let label = journey.template.englishLabel {
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(isActive ? Theme.accent : Theme.inkSecondary)
                                .lineLimit(1)
                        }
                    }
                    Text("\(journey.template.displayName) · 始于 \(journey.createdAt.formatted(.dateTime.year().month(.defaultDigits).day().locale(Theme.locale)))")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 8)
                StatusPill(status: journey.status)
            }

            statsRow

            if isActive, let next = journey.nextAppointment {
                NextAppointmentBanner(log: next)
            }
        }
        .cardSurface()
        .overlay(alignment: .leading) {
            // Active journeys carry the 3pt apricot edge marker (DESIGN.md).
            if isActive {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 3)
                    .padding(.vertical, 18)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            if let latest = journey.latestPastLog {
                stat(icon: "calendar", text: "最近 \(latest.occurredAt.shortDay)")
                dot
            }
            stat(icon: "doc.text", text: "\(journey.logs.count) 条记录")
            if journey.artifactCount > 0 {
                dot
                stat(icon: "photo", text: "\(journey.artifactCount) 份附件")
            }
        }
    }

    private var dot: some View {
        Circle().fill(Theme.border).frame(width: 4, height: 4)
    }

    private func stat(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(Theme.inkPrimary)
            .labelStyle(StatLabelStyle())
            .lineLimit(1)
    }
}

private struct StatLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.foregroundStyle(Theme.accent)
            configuration.title
        }
    }
}

/// "下次就诊：10月14日 · 距今 11 天" strip inside an active Journey card.
private struct NextAppointmentBanner: View {
    let log: Log

    private var detail: String? {
        let parts = [log.location, log.doctor, log.note]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(systemName: "calendar.badge.clock", size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("下次\(log.type.isEmpty ? "就诊" : log.type)：\(log.occurredAt.shortDay)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkPrimary)
                    TagPill(text: log.daysFromToday == 1 ? "明天" : "距今 \(log.daysFromToday) 天", tinted: true)
                }
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))
    }
}

/// Soft grey "新建健康旅程 · New Journey" card with a round apricot +.
private struct NewJourneyCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Theme.accent))
                    .shadow(color: Theme.accent.opacity(0.3), radius: 8, y: 4)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("新建健康旅程")
                        .font(.headline)
                        .foregroundStyle(Theme.inkPrimary)
                    Text("· New Journey")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
                Text("孕期 · 术后康复 · 慢病随访 · 年度体检")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.border.opacity(0.45))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    JourneyListView()
        .modelContainer(for: [Journey.self, Log.self, Artifact.self, Profile.self], inMemory: true)
}
