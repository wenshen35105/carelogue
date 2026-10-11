import SwiftData
import SwiftUI

/// M8 T54 · 连接 Apple 健康 for one journey: tick the readings to bring in,
/// connect (the system asks for exactly those), and see what came in.
struct HealthLinkSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let journey: Journey

    @State private var selected: Set<HealthMetric>
    @State private var isLinked: Bool
    @State private var working = false
    @State private var result: String?
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
                    Section {
                        ForEach(HealthMetric.allCases) { metric in
                            Toggle(isOn: Binding(
                                get: { selected.contains(metric) },
                                set: { on in if on { selected.insert(metric) } else { selected.remove(metric) } }
                            )) {
                                Text(metric.displayName)
                            }
                            .tint(Theme.accent)
                            .accessibilityIdentifier("health.metric.\(metric.rawValue)")
                        }
                    } header: {
                        Text("读取哪些数据")
                    } footer: {
                        Text("只读取你勾选的类型，从这段旅程开始那天起。读到的数值会成为这段旅程里的测量记录；心率读取的是每天的静息心率。")
                    }

                    Section {
                        Button {
                            Task { await connect() }
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
                        .disabled(selected.isEmpty || working || !HealthSync.isAvailable)
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
                            Text("连接后，每次打开这段旅程都会自动带入新的读数。数据只在这台设备和你自己的 iCloud 里，不经过我们的服务器。可以随时在「设置 › 健康 › 数据访问与设备」里修改权限。")
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
