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

    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false
    @State private var restoreNotice: String?

    #if DEBUG
    @State private var internalDraft = ""
    /// Mirrors the Keychain so the page redraws when the credential changes;
    /// SubscriptionService cannot observe a Keychain write.
    @State private var internalCredential = InternalAccess.credential
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                subscriptionSection
                #if DEBUG
                internalAccessSection
                #endif
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
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
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
            }
            .padding(.horizontal, Theme.Spacing.cardPadding)
            .cardSurface(padding: 0)

            Label("AI 解释需要 Carelogue Plus 订阅；关闭开关后，报告页不再显示解释入口", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - 订阅

    /// Stitch settings_subscribed "订阅 · SUBSCRIPTION": status, renewal, and
    /// the two things the user can act on — manage and restore (T28).
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "sparkles.rectangle.stack", title: String(localized: "订阅"),
                                  gloss: AppLanguage.gloss(String(localized: "Subscription")))

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(verbatim: "Carelogue Plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.inkPrimary)
                    Spacer(minLength: 8)
                    SubscriptionPill(subscribed: subscriptions.isSubscribed)
                }
                .padding(.vertical, 14)
                .accessibilityIdentifier("settings.subscriptionStatus")

                if let renewal = subscriptions.renewalDate {
                    SettingsDivider()
                    HStack {
                        Label("下次续费 · Next renewal", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                        Spacer(minLength: 8)
                        Text(renewal.numericDate)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.inkPrimary)
                    }
                    .padding(.vertical, 14)
                }

                SettingsDivider()

                if subscriptions.isSubscribed {
                    Link(destination: LegalLinks.manageSubscriptions) {
                        SettingsRowLabel(title: String(localized: "管理订阅 · Manage"),
                                         detail: String(localized: "在 App Store 账户里更改或取消"))
                    }
                    .accessibilityIdentifier("settings.manageSubscription")
                } else {
                    Button {
                        showingPaywall = true
                    } label: {
                        SettingsRowLabel(title: String(localized: "了解 Carelogue Plus"),
                                         detail: String(localized: "订阅后解锁全部 AI 功能"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.openPaywall")
                }

                SettingsDivider()

                Button {
                    Task { await restore() }
                } label: {
                    SettingsRowLabel(title: String(localized: "恢复购买 · Restore"),
                                     detail: String(localized: "在别的设备上订阅过？点这里同步"))
                }
                .buttonStyle(.plain)
                .disabled(subscriptions.isWorking)
                .accessibilityIdentifier("settings.restore")
            }
            .padding(.horizontal, Theme.Spacing.cardPadding)
            .cardSurface(padding: 0)

            if let restoreNotice {
                Label(restoreNotice, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("settings.restoreResult")
            }
        }
    }

    private func restore() async {
        do {
            try await subscriptions.restore()
            restoreNotice = subscriptions.isSubscribed
                ? String(localized: "已恢复订阅，AI 解释可以用了。")
                : String(localized: "这个 Apple ID 下没有找到可恢复的订阅。")
        } catch {
            restoreNotice = error.localizedDescription
        }
    }

    // MARK: - 内部通道 (T30, Debug only)

    #if DEBUG
    /// The internal unlock channel: paste the relay's `INTERNAL_ACCESS_KEY`
    /// once and this build behaves as subscribed, going through the real
    /// relay. Debug-only in every sense — the section, the copy and the
    /// credential are absent from a Release archive, which is also why this
    /// text is deliberately outside the String Catalog — and written in
    /// English like the code around it, not in the app's bilingual product
    /// voice: it is developer tooling, not product copy.
    private var internalAccessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconBadge(systemName: "hammer", size: 30)
                Text(verbatim: "Internal Access")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.inkPrimary)
            }

            VStack(alignment: .leading, spacing: 12) {
                if let credential = internalCredential {
                    HStack(spacing: 10) {
                        Label {
                            Text(verbatim: "Unlocked · " + InternalAccess.masked(credential))
                                .font(.subheadline.weight(.medium))
                        } icon: {
                            Image(systemName: "lock.open")
                        }
                        .foregroundStyle(Theme.success)
                        .accessibilityIdentifier("settings.internalUnlocked")
                        Spacer(minLength: 8)
                        Button {
                            InternalAccess.setCredential(nil)
                            internalCredential = nil
                            internalDraft = ""
                            Task { await subscriptions.refresh() }
                        } label: {
                            Text(verbatim: "Clear")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.warning)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.internalClear")
                    }
                } else {
                    SecureField(text: $internalDraft) {
                        Text(verbatim: "Paste INTERNAL_ACCESS_KEY")
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.insetFill))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    .accessibilityIdentifier("settings.internalField")

                    Button {
                        guard InternalAccess.setCredential(internalDraft) else { return }
                        internalCredential = InternalAccess.credential
                        internalDraft = ""
                        Task { await subscriptions.refresh() }
                    } label: {
                        Text(verbatim: "Save & unlock")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(internalDraft.trimmingCharacters(in: .whitespacesAndNewlines).count < InternalAccess.minimumLength)
                    .accessibilityIdentifier("settings.internalSave")
                }

                Text(verbatim: "Debug builds only. The credential stays in this device's Keychain — never in the repo, never in a build. Requests still go through the Carelogue relay and its rate limit; the matching server secret is deleted before launch.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .cardSurface()
        }
    }
    #endif

    // MARK: - Privacy

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "lock.shield", title: String(localized: "隐私与数据流向"),
                                  gloss: AppLanguage.gloss(String(localized: "Privacy & Data Flow")))

            VStack(spacing: 0) {
                storageRow
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

    /// Where records live. With CloudKit on (T23) they also sync through the
    /// user's own private iCloud database, so the copy has to say so.
    @ViewBuilder
    private var storageRow: some View {
        if CloudSync.isSyncing {
            PrivacyRow(icon: "icloud",
                       title: String(localized: "你的设备与 iCloud"),
                       gloss: AppLanguage.gloss(String(localized: "Your devices & iCloud")),
                       detail: String(localized: "旅程、记录、附件和档案保存在这台设备上，并通过你自己的 iCloud 私有库同步到你的其他设备。我们读不到这些内容。"))
        } else {
            PrivacyRow(icon: "lock.iphone",
                       title: String(localized: "数据只存本机"),
                       gloss: AppLanguage.gloss(String(localized: "On-device only")),
                       detail: CloudSync.mode == .cloudKit
                           ? String(localized: "旅程、记录、附件和档案都只保存在这台设备上。登录 iCloud 后，它们会在你自己的私有库里同步到其他设备。")
                           : String(localized: "旅程、记录、附件和档案都只保存在这台设备上。"))
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
        VStack(spacing: 10) {
            // App Store review expects both reachable from inside the app.
            HStack(spacing: 16) {
                Link("隐私政策 · Privacy", destination: LegalLinks.privacy)
                    .accessibilityIdentifier("settings.privacyPolicy")
                Link("使用条款 · Terms", destination: LegalLinks.terms)
                    .accessibilityIdentifier("settings.terms")
            }
            .font(.footnote.weight(.medium))
            .tint(Theme.accent)

            VStack(spacing: 6) {
                Label("Carelogue iOS v\(Bundle.main.shortVersion)", systemImage: "leaf")
                    .font(.caption)
                Text("温和记录，陪你走好每一步")
                    .font(.caption)
            }
            .foregroundStyle(Theme.inkSecondary)
        }
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

/// "● 订阅中 · Active" / "● 未订阅 · Not subscribed".
private struct SubscriptionPill: View {
    let subscribed: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(subscribed ? Theme.success : Theme.inkSecondary)
                .frame(width: 6, height: 6)
            Text(subscribed ? String(localized: "订阅中 · Active") : String(localized: "未订阅 · Not subscribed"))
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(subscribed ? Theme.success : Theme.inkSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(subscribed ? Theme.success.opacity(0.12) : Theme.insetFill))
    }
}

/// Title + one muted line + chevron, the shape of every actionable row on
/// this page.
private struct SettingsRowLabel: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.accent)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
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

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
