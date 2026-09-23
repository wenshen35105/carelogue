import SwiftUI
import SwiftData

/// 设置 Settings (Stitch "settings" / "settings_subscribed"): calm card page
/// pushed from 档案与设置. Only settings backed by a shipped feature appear
/// here (design-review): the AI switch, the API key, the privacy notes and
/// 数据管理.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AISettings.enabledKey) private var aiEnabled = true
    @AppStorage(AISettings.includeProfileKey) private var includeProfile = true
    @AppStorage(AISettings.consentKey) private var consentRaw = ""
    @State private var showingRevokeConfirm = false
    @State private var showingEraseConfirm = false
    @State private var eraseResult: ModelContext.EraseSummary?

    @State private var apiKey: String? = AISettings.apiKey
    @State private var showingKeyEditor = false
    @State private var testState: TestState = .idle

    private enum TestState: Equatable {
        case idle, running, ok
        case failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                aiSection
                privacySection
                dataSection
                footer
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingKeyEditor) {
            APIKeyEditor(hasKey: apiKey != nil) { newKey in
                AISettings.setAPIKey(newKey)
                apiKey = AISettings.apiKey
                testState = .idle
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CARELOGUE PREFERENCES")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Theme.accent)
            Text("设置 Settings")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.inkPrimary)
            Text("AI 解释服务与隐私 · AI Services & Privacy")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    // MARK: - AI

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "sparkles", title: String(localized: "AI · 解释功能"),
                                  gloss: AppLanguage.gloss(String(localized: "AI Explanation Service")))

            VStack(spacing: 0) {
                Toggle(isOn: $aiEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("白话解释 (AI Explained)")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.inkPrimary)
                        Text("把检验报告里的医学术语，解释成家人都能看懂的话")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .tint(Theme.accent)
                .padding(.vertical, 14)
                .accessibilityIdentifier("settings.aiToggle")

                SettingsDivider()

                Toggle(isOn: $includeProfile) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("附带档案信息")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.inkPrimary)
                        Text("解释时一并发送档案里的「过敏」「长期用药」，让解释更贴合你")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .tint(Theme.accent)
                .padding(.vertical, 14)
                .disabled(!aiEnabled)
                .accessibilityIdentifier("settings.profileToggle")
                SettingsDivider()

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("解释服务 · \(AIDisclosure.serviceName)")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.inkPrimary)
                        Text(verbatim: "deepseek-chat")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer(minLength: 8)
                    ConfiguredPill(configured: apiKey != nil)
                }
                .padding(.vertical, 14)

                SettingsDivider()

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("授权密钥 API Key")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                        Text(apiKey.map { AISettings.masked($0) } ?? String(localized: "未填写"))
                            .font(.body.monospaced())
                            .foregroundStyle(apiKey == nil ? Theme.inkSecondary : Theme.inkPrimary)
                            .accessibilityIdentifier("settings.maskedKey")
                    }
                    Spacer(minLength: 8)
                    Button {
                        showingKeyEditor = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(apiKey == nil ? String(localized: "填写 Add") : String(localized: "更换 Change"))
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.accentTint))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.changeKey")
                }
                .padding(.vertical, 14)

                if apiKey != nil {
                    SettingsDivider()
                    connectionTestRow
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, Theme.Spacing.cardPadding)
            .cardSurface(padding: 0)

            Label("Key 只保存在本机钥匙串（iOS Keychain），不上传", systemImage: "lock")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
                .padding(.horizontal, 4)
        }
    }

    /// Minimal round trip to prove the key works (T18 acceptance).
    private var connectionTestRow: some View {
        HStack(spacing: 8) {
            Button {
                Task { await runConnectionTest() }
            } label: {
                Label("测试连接", systemImage: "bolt.horizontal")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(testState == .running)
            .accessibilityIdentifier("settings.testConnection")

            Spacer(minLength: 8)

            Group {
                switch testState {
                case .idle:
                    EmptyView()
                case .running:
                    ProgressView().controlSize(.small)
                case .ok:
                    Label("连接正常", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                case .failed(let message):
                    Text(message)
                        .foregroundStyle(Theme.warning)
                        .multilineTextAlignment(.trailing)
                }
            }
            .font(.footnote)
            .accessibilityIdentifier("settings.testResult")
        }
    }

    private func runConnectionTest() async {
        testState = .running
        do {
            let service = try AISettings.makeService()
            _ = try await service.complete(system: "Reply with the single word: ok", user: "ping", json: false)
            testState = .ok
        } catch {
            testState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "lock.shield", title: String(localized: "隐私与数据流向"),
                                  gloss: AppLanguage.gloss(String(localized: "Privacy & Data Flow")))

            VStack(spacing: 0) {
                PrivacyRow(icon: "lock.iphone",
                           title: String(localized: "数据只存本机"),
                           gloss: AppLanguage.gloss(String(localized: "On-device only")),
                           detail: String(localized: "旅程、记录、附件和档案都只保存在这台设备上。"))
                SettingsDivider()
                PrivacyRow(icon: "text.viewfinder",
                           title: String(localized: "仅发送提取文本"),
                           gloss: AppLanguage.gloss(String(localized: "Extracted text only")),
                           detail: AIDisclosure.textOnlyDetail)
                SettingsDivider()
                PrivacyRow(icon: "checkmark.seal",
                           title: AIDisclosure.responsibilityTitle,
                           gloss: AppLanguage.gloss(AIDisclosure.responsibilityGloss),
                           detail: AIDisclosure.responsibilityDetail)
                consentFooter
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, Theme.Spacing.cardPadding)
            .cardSurface(padding: 0)
            .confirmationDialog("撤回 AI 解释同意？", isPresented: $showingRevokeConfirm, titleVisibility: .visible) {
                Button("撤回同意", role: .destructive) {
                    consentRaw = AISettings.Consent.revoked.rawValue
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("撤回后不会再发送任何报告文字，报告页的 AI 解释入口会停用；已有的解释结果仍保留在本机。")
            }
        }
    }

    /// 撤回 AI 同意 (T21). Only shown when there is something to withdraw.
    @ViewBuilder
    private var consentFooter: some View {
        switch AISettings.Consent(rawValue: consentRaw) ?? .undecided {
        case .granted:
            Button {
                showingRevokeConfirm = true
            } label: {
                Label("撤回 AI 同意 · Revoke Consent", systemImage: "arrow.uturn.backward")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.insetFill))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.revokeConsent")
        case .revoked:
            Label("已撤回同意，AI 解释入口已停用。在报告页可重新同意。", systemImage: "hand.raised")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("settings.consentRevoked")
        case .undecided:
            EmptyView()
        }
    }

    // MARK: - 数据管理

    /// Stitch settings_subscribed "数据管理 · DATA MANAGEMENT": one destructive
    /// row on its own card, kept away from the switches above it.
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "externaldrive", title: String(localized: "数据管理"),
                                  gloss: AppLanguage.gloss(String(localized: "Data Management")))

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showingEraseConfirm = true
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.warning)
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.warning.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 4) {
                            // Not BilingualTitle: this row's title is
                            // destructive-red, and that helper pins its own
                            // ink colour.
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("清空所有数据")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.warning)
                                if let gloss = AppLanguage.gloss(String(localized: "Erase all data")) {
                                    Text(gloss)
                                        .font(.caption)
                                        .foregroundStyle(Theme.warning.opacity(0.7))
                                }
                            }
                            .lineLimit(1)
                            Text("删除这台设备上的全部旅程、记录、附件与档案。此操作不可撤销。")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                            .padding(.top, 12)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.eraseAll")

                if let eraseResult {
                    Label(eraseSummaryText(eraseResult), systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.success)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.eraseResult")
                }
            }
            .cardSurface()
            .confirmationDialog("清空所有数据？", isPresented: $showingEraseConfirm, titleVisibility: .visible) {
                Button("清空所有数据", role: .destructive) {
                    let summary = modelContext.eraseAllData()
                    eraseResult = summary
                    Task {
                        try? await Task.sleep(for: .seconds(6))
                        eraseResult = nil
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(erasePreviewText)
            }
        }
    }

    /// Counted just before the dialog opens, so the warning names real numbers.
    private var erasePreviewText: String {
        let journeys = (try? modelContext.fetchCount(FetchDescriptor<Journey>())) ?? 0
        let logs = (try? modelContext.fetchCount(FetchDescriptor<Log>())) ?? 0
        let artifacts = (try? modelContext.fetchCount(FetchDescriptor<Artifact>())) ?? 0
        return String(localized: "将删除 \(journeys) 段旅程、\(logs) 条记录、\(artifacts) 份附件，以及档案内容。删除后无法恢复，也不会留下备份。")
    }

    private func eraseSummaryText(_ summary: ModelContext.EraseSummary) -> String {
        summary.isEmpty
            ? String(localized: "本机已经没有可清空的数据")
            : String(localized: "已清空 \(summary.journeys) 段旅程、\(summary.logs) 条记录、\(summary.artifacts) 份附件")
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Label("Carelogue iOS v\(Bundle.main.shortVersion)", systemImage: "leaf")
                .font(.caption)
            Text("温和记录，陪你走好每一步")
                .font(.caption)
        }
        .foregroundStyle(Theme.inkSecondary)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pieces

private struct SettingsSectionHeader: View {
    let icon: String
    let title: String
    let gloss: String?

    var body: some View {
        HStack(spacing: 10) {
            IconBadge(systemName: icon, size: 30)
            BilingualTitle(primary: title, secondary: gloss, font: .title3.weight(.bold))
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(Theme.border).frame(height: 1)
    }
}

/// "● 已配置 Connected" / "● 未配置 Not set".
private struct ConfiguredPill: View {
    let configured: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(configured ? Theme.success : Theme.inkSecondary)
                .frame(width: 6, height: 6)
            Text(configured ? String(localized: "已配置 Connected") : String(localized: "未配置 Not set"))
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(configured ? Theme.success : Theme.inkSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(configured ? Theme.success.opacity(0.12) : Theme.insetFill))
    }
}

private struct PrivacyRow: View {
    let icon: String
    let title: String
    let gloss: String?
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accentTint))
            VStack(alignment: .leading, spacing: 4) {
                BilingualTitle(primary: title, secondary: gloss, font: .body.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }
}

/// SecureField sheet for entering / replacing / removing the key.
private struct APIKeyEditor: View {
    @Environment(\.dismiss) private var dismiss

    let hasKey: Bool
    let onSave: (String?) -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        SecureField(String(localized: "粘贴 DeepSeek API Key（sk-…）"), text: $draft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .accessibilityIdentifier("settings.keyField")
                    } footer: {
                        Text("在 platform.deepseek.com 申请。Key 只保存在本机钥匙串。")
                    }
                    if hasKey {
                        Section {
                            Button("移除 API Key", role: .destructive) {
                                onSave(nil)
                                dismiss()
                            }
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .warmFormChrome()
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
