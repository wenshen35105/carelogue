import SwiftUI
import SwiftData

/// Log 编辑器（新建/编辑共用）.
struct LogEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let journey: Journey
    let kind: LogKind
    var existingLog: Log?

    @State private var type: String
    @State private var occurredAt: Date
    @State private var note: String
    @State private var location: String
    @State private var doctor: String
    @State private var valueText: String
    @State private var unit: String
    @State private var measurementCategory: String
    @State private var showingDeleteConfirm = false
    @FocusState private var noteFieldFocused: Bool

    init(journey: Journey, kind: LogKind, existingLog: Log? = nil) {
        self.journey = journey
        self.kind = kind
        self.existingLog = existingLog
        let defaultType = existingLog?.type ?? (kind == .quick ? "备注" : kind == .measurement ? "体重" : "")
        _type = State(initialValue: defaultType)
        _occurredAt = State(initialValue: existingLog?.occurredAt ?? .now)
        _note = State(initialValue: existingLog?.note ?? "")
        _location = State(initialValue: existingLog?.location ?? "")
        _doctor = State(initialValue: existingLog?.doctor ?? "")
        _valueText = State(initialValue: existingLog?.value.map { String($0) } ?? "")
        _unit = State(initialValue: existingLog?.unit ?? (kind == .measurement ? "kg" : ""))

        let presetNames = Self.measurementTypes.map(\.name).dropLast() // exclude 自定义
        if let existingType = existingLog?.type, presetNames.contains(existingType) {
            _measurementCategory = State(initialValue: existingType)
        } else if existingLog != nil {
            _measurementCategory = State(initialValue: "自定义")
        } else {
            _measurementCategory = State(initialValue: "体重")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                switch kind {
                case .encounter:
                    encounterFields
                case .quick:
                    quickFields
                case .measurement:
                    measurementFields
                }

                if existingLog != nil {
                    Section {
                        Button("删除记录", role: .destructive) {
                            showingDeleteConfirm = true
                        }
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
                        .disabled(kind != .quick && type.isEmpty)
                }
            }
            .confirmationDialog("删除这条记录？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive, action: delete)
                Button("取消", role: .cancel) {}
            }
            .onAppear {
                if kind == .quick {
                    noteFieldFocused = true
                }
            }
        }
    }

    // MARK: - Encounter

    private static let encounterTypes = ["面诊", "体检", "验血", "影像", "其他"]

    @ViewBuilder
    private var encounterFields: some View {
        Section("类型") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.encounterTypes, id: \.self) { option in
                        ChipButton(title: option, isSelected: type == option) {
                            type = option
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }

        Section("日期") {
            DatePicker("日期", selection: $occurredAt, displayedComponents: .date)
        }

        Section("地点 / 医生（可选）") {
            TextField("地点", text: $location)
            TextField("医生", text: $doctor)
        }

        Section("备注") {
            TextEditor(text: $note)
                .frame(minHeight: 80)
        }

        Section("附件") {
            Text("附件区（M2 实现）")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    // MARK: - Quick log
    // Design goal: open -> keyboard already up -> type -> save, in ~3s.
    // Type/time get sane defaults so neither needs to be touched.

    private static let quickTypes = ["症状", "情绪", "备注"]

    @ViewBuilder
    private var quickFields: some View {
        Section {
            TextEditor(text: $note)
                .frame(minHeight: 120)
                .focused($noteFieldFocused)
        }

        Section("类型") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.quickTypes, id: \.self) { option in
                        ChipButton(title: option, isSelected: type == option) {
                            type = option
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }

        Section("时间") {
            DatePicker("发生时间", selection: $occurredAt)
        }
    }

    // MARK: - Measurement

    private static let measurementTypes: [(name: String, unit: String)] = [
        ("体重", "kg"), ("血压", "mmHg"), ("体温", "°C"), ("自定义", "")
    ]

    @ViewBuilder
    private var measurementFields: some View {
        Section("类型") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.measurementTypes, id: \.name) { option in
                        ChipButton(title: option.name, isSelected: measurementCategory == option.name) {
                            measurementCategory = option.name
                            if option.name == "自定义" {
                                type = ""
                            } else {
                                type = option.name
                                unit = option.unit
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            if measurementCategory == "自定义" {
                TextField("自定义类型名称", text: $type)
            }
        }

        Section("数值") {
            TextField("数值", text: $valueText)
                .keyboardType(.decimalPad)
            TextField("单位（如 kg）", text: $unit)
        }

        Section("时间") {
            DatePicker("发生时间", selection: $occurredAt)
        }
    }

    // MARK: - Actions

    private func save() {
        let log = existingLog ?? Log(kind: kind)
        if existingLog == nil {
            modelContext.insert(log)
            log.journey = journey
        }
        log.type = type
        log.occurredAt = occurredAt
        log.updatedAt = .now
        switch kind {
        case .encounter:
            log.note = note
            log.location = location.isEmpty ? nil : location
            log.doctor = doctor.isEmpty ? nil : doctor
        case .measurement:
            log.value = Double(valueText)
            log.unit = unit
        case .quick:
            log.note = note
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let existingLog else { return }
        modelContext.delete(existingLog)
        try? modelContext.save()
        dismiss()
    }
}

private struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Theme.accent : Theme.inkSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Theme.accent.opacity(0.12) : Theme.card)
                )
                .overlay(
                    Capsule().stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
