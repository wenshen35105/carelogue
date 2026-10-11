import SwiftData
import SwiftUI

/// M8 T54 · 连接 Apple 健康 for one journey: tick the readings to bring in,
/// connect (the system asks for exactly those), and see what came in.
/// T61: only on the device of the person the journey records — an
/// unspecified journey is claimed first, someone else's can't connect here.
struct HealthLinkSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let journey: Journey

    @State private var selected: Set<HealthMetric>
    @State private var isLinked: Bool
    @State private var working = false
    @State private var result: String?
    @State private var confirmingClaim = false
    #if DEBUG
    @State private var exported: Int?
    #endif

    init(journey: Journey) {
        self.journey = journey
        let link = HealthSync.link(for: journey)
        _selected = State(initialValue: Set(link?.metrics ?? [.weight, .bloodPressure]))
        _isLinked = State(initialValue: link != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    ownershipSection
                    Section {
                        ForEach(HealthMetric.allCases) { metric in
                            Toggle(isOn: Binding(
                                get: { selected.contains(metric) },
                                set: { on in if on { selected.insert(metric) } else { selected.remove(metric) } }
                            )) {
                                Text(metric.displayName)
                            }
                            .tint(Theme.accent)
                            .disabled(isSomeoneElses)
                            .accessibilityIdentifier("health.metric.\(metric.rawValue)")
                        }
                    } header: {
                        Text("读取哪些数据")
                    } footer: {
                        Text("只读取你勾选的类型，从这段旅程开始那天起。读到的数值会成为这段旅程里的测量记录；心率读取的是每天的静息心率。")
                    }

                    Section {
                        Button {
                            if journey.subject == .unspecified {
                                confirmingClaim = true
                            } else {
                                Task { await connect() }
                            }
                        } label: {
                            HStack {
                                Label(isLinked ? String(localized: "更新并立即同步") : String(localized: "连接并导入"),
                                      systemImage: "heart.text.square")
                                if working {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(selected.isEmpty || working || !HealthSync.isAvailable || isSomeoneElses)
                        .accessibilityIdentifier("health.connect")

                        if isLinked {
                            Button("停止读取", role: .destructive) {
                                HealthSync.disconnect(journey)
                                isLinked = false
                                result = String(localized: "已停止读取。已经导入的记录保留在旅程里。")
                            }
                            .accessibilityIdentifier("health.disconnect")
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            if let result {
                                Text(result)
                                    .foregroundStyle(Theme.inkPrimary)
                                    .accessibilityIdentifier("health.result")
                            }
                            if !HealthSync.isAvailable {
                                Text("这台设备不支持 Apple 健康。")
                            }
                            Text("连接后，每次打开这段旅程都会自动带入新的读数；你在这段旅程里记录的测量也会写入你的「健康」（设置里可关）。数据只在这台设备和你自己的 iCloud 里，不经过我们的服务器。可以随时在「设置 › 健康 › 数据访问与设备」里修改权限。")
                            #if DEBUG
                            if let exported {
                                Text(verbatim: "Exported to Health: \(exported)")
                                    .accessibilityIdentifier("debug.healthExported")
                            }
                            #endif
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .warmFormChrome()
            .confirmationDialog("这段旅程记录的是你本人的健康数据吗？", isPresented: $confirmingClaim,
                                titleVisibility: .visible) {
                Button("是，记录的是我") {
                    journey.claimAsMine()
                    try? modelContext.save()
                    Task { await connect() }
                }
                .accessibilityIdentifier("health.claim")
                Button("不是", role: .cancel) {
                    result = String(localized: "没有连接。可以在「编辑概要与目标日 › 记录对象」里写明这段旅程是谁的。")
                }
            } message: {
                Text("确认后，这段旅程的记录对象会设为你；之后只有你的 iPhone 能为它连接 Apple 健康。")
            }
            .navigationTitle(String(localized: "Apple 健康"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            #if DEBUG
            .task { exported = await HealthSync.exportedCount(context: modelContext) }
            #endif
        }
    }

    private var isSomeoneElses: Bool {
        if case .someoneElse = journey.subject { return true }
        return false
    }

    /// Says plainly whose data Health holds, and — for someone else's
    /// journey — why connecting is off here.
    @ViewBuilder
    private var ownershipSection: some View {
        Section {
            if case .someoneElse(let name) = journey.subject {
                Label {
                    Text("这段旅程记录的是 \(name ?? String(localized: "其他成员")) 的健康，只能在 TA 本人的 iPhone 上连接 Apple 健康。")
                } icon: {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(Theme.warning)
                }
                .accessibilityIdentifier("health.someoneElse")
            }
            Text("Apple 健康里的数据属于这台 iPhone 的主人。只在这段旅程记录的是你本人时连接。")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
            if journey.isShared {
                Text("其他成员录入的测量不会写入你的「健康」；你录入的测量只写入你自己的「健康」。")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
        } footer: {
            if isSomeoneElses {
                Text("记录对象可以在「编辑概要与目标日」里修改。")
            }
        }
    }

    private func connect() async {
        working = true
        defer { working = false }
        do {
            let metrics = HealthMetric.allCases.filter(selected.contains)
            let count = try await HealthSync.connect(journey, metrics: metrics, context: modelContext)
            isLinked = true
            result = count > 0
                ? String(localized: "已导入 \(count) 条读数。")
                : String(localized: "已连接，暂时没有新的读数。")
        } catch {
            result = error.localizedDescription
        }
    }
}
