import SwiftUI
import SwiftData

/// Two-step onboarding wizard: name -> template. Picking a template
/// immediately creates the Journey and dismisses (keeps the "launch to
/// created" tap count at 3: +, 下一步, template chip).
struct JourneyCreationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case name
        case template
    }

    @State private var step: Step = .name
    @State private var name: String = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .name: nameStep
                case .template: templateStep
                }
            }
            .padding(20)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(step == .name ? String(localized: "命名 · Name") : String(localized: "选择模板 · Template"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("给这段旅程起个名字")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            TextField("如：孕期", text: $name)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .focused($nameFieldFocused)
                .submitLabel(.next)
                .onSubmit(goToTemplateStep)

            Spacer()

            Button("下一步", action: goToTemplateStep)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .frame(maxWidth: .infinity)
                .disabled(trimmedName.isEmpty)
        }
        .onAppear { nameFieldFocused = true }
    }

    private var templateStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选一个模板，马上开始")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)

            ForEach(JourneyTemplate.allCases, id: \.self) { template in
                Button {
                    create(template: template)
                } label: {
                    HStack {
                        Text(template.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.inkPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .padding(16)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func goToTemplateStep() {
        guard !trimmedName.isEmpty else { return }
        step = .template
    }

    private func create(template: JourneyTemplate) {
        let journey = Journey(name: trimmedName, template: template)
        modelContext.insert(journey)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    JourneyCreationSheet()
        .modelContainer(for: [Journey.self, Log.self, Artifact.self, Profile.self], inMemory: true)
}
