import SwiftUI
import SwiftData

/// Log 编辑器（新建/编辑共用）. Minimal generic form from T4; T5 (就诊)
/// and T6 (随手记/测量) replace this with kind-specific layouts.
struct LogEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let journey: Journey
    let kind: LogKind
    var existingLog: Log?

    @State private var type: String = ""
    @State private var occurredAt: Date = .now
    @State private var note: String = ""
    @State private var valueText: String = ""
    @State private var unit: String = ""

    init(journey: Journey, kind: LogKind, existingLog: Log? = nil) {
        self.journey = journey
        self.kind = kind
        self.existingLog = existingLog
        if let existingLog {
            _type = State(initialValue: existingLog.type)
            _occurredAt = State(initialValue: existingLog.occurredAt)
            _note = State(initialValue: existingLog.note ?? "")
            _valueText = State(initialValue: existingLog.value.map { String($0) } ?? "")
            _unit = State(initialValue: existingLog.unit ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("类型") {
                    TextField("如：面诊", text: $type)
                }
                Section("时间") {
                    DatePicker("发生时间", selection: $occurredAt)
                }
                if kind == .measurement {
                    Section("数值") {
                        TextField("数值", text: $valueText)
                            .keyboardType(.decimalPad)
                        TextField("单位（如 kg）", text: $unit)
                    }
                } else {
                    Section("备注") {
                        TextEditor(text: $note)
                            .frame(minHeight: 100)
                    }
                }
            }
            .navigationTitle(existingLog == nil ? "新建记录" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
        }
    }

    private func save() {
        let log = existingLog ?? Log(kind: kind)
        if existingLog == nil {
            modelContext.insert(log)
            log.journey = journey
        }
        log.type = type
        log.occurredAt = occurredAt
        log.updatedAt = .now
        if kind == .measurement {
            log.value = Double(valueText)
            log.unit = unit
        } else {
            log.note = note
        }
        try? modelContext.save()
        dismiss()
    }
}
