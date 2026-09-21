import SwiftUI
import SwiftData

/// P4 · Profile（全局档案）. Single row, shared across all Journeys.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Singleton pattern: query for the profile, take the first row, and
    // create one lazily on first save if none exists yet.
    @Query private var profiles: [Profile]

    @State private var allergies = ""
    @State private var medications = ""
    @State private var vaccines = ""
    @State private var history = ""
    @State private var showingClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("过敏与不良反应") {
                    TextEditor(text: $allergies).frame(minHeight: 70)
                }
                Section("长期用药") {
                    TextEditor(text: $medications).frame(minHeight: 70)
                }
                Section("疫苗记录") {
                    TextEditor(text: $vaccines).frame(minHeight: 70)
                }
                Section("既往病史与手术史") {
                    TextEditor(text: $history).frame(minHeight: 70)
                }

                Section {
                    Text("只存本机；用于让 AI 解释更准确；可随时清空。")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }

                Section {
                    Button("清空档案", role: .destructive) {
                        showingClearConfirm = true
                    }
                }
            }
            .navigationTitle("档案 · Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear(perform: load)
            .onDisappear(perform: save)
            .confirmationDialog("清空所有档案内容？", isPresented: $showingClearConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive, action: clear)
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func load() {
        guard let existing = profiles.first else { return }
        allergies = existing.allergies
        medications = existing.medications
        vaccines = existing.vaccines
        history = existing.history
    }

    private func save() {
        let target: Profile
        if let existing = profiles.first {
            target = existing
        } else {
            target = Profile()
            modelContext.insert(target)
        }
        target.allergies = allergies
        target.medications = medications
        target.vaccines = vaccines
        target.history = history
        target.updatedAt = .now
        try? modelContext.save()
    }

    private func clear() {
        allergies = ""
        medications = ""
        vaccines = ""
        history = ""
        save()
    }
}
