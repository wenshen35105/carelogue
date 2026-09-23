import SwiftUI
import StoreKit

/// Carelogue Plus 订阅页 (T27; Stitch carelogue_plus_paywall). Calm and
/// factual: what it unlocks, what it costs, how to cancel. No countdowns, no
/// guilt copy.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptions = SubscriptionService.shared
    @State private var message: String?
    @State private var showingThanks = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    heading
                    benefits
                    priceCard
                    subscribeButton
                    legalFooter
                }
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .accessibilityLabel("关闭")
                }
            }
            .alert("订阅提示", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
            .alert("订阅已开通", isPresented: $showingThanks) {
                Button("好") { dismiss() }
            } message: {
                Text("AI 解释已经解锁，去报告页试试吧。")
            }
        }
        .task { await subscriptions.loadProduct() }
        .accessibilityIdentifier("paywall")
    }

    // MARK: - Pieces

    private var heading: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 74, height: 74)
                .background(RoundedRectangle(cornerRadius: 22).fill(Theme.accentTint))
            Text("Carelogue Plus")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.inkPrimary)
            Text("解锁全部 AI 功能 · Unlock all AI")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(spacing: Theme.Spacing.cardGap) {
            BenefitRow(icon: "sparkles",
                       title: String(localized: "白话解释"),
                       gloss: AppLanguage.gloss(String(localized: "Plain summaries")),
                       detail: String(localized: "把报告变成白话总结、术语卡和「问问医生」清单。"))
            BenefitRow(icon: "infinity",
                       title: String(localized: "全部 AI 功能"),
                       gloss: AppLanguage.gloss(String(localized: "All AI features")),
                       detail: String(localized: "以后新增的 AI 能力都包含在内，不额外加价。"))
            BenefitRow(icon: "lock.shield",
                       title: String(localized: "隐私不变"),
                       gloss: AppLanguage.gloss(String(localized: "Same privacy")),
                       detail: String(localized: "订阅只解锁 AI；记录、附件和档案依旧只属于你。"))
        }
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(subscriptions.displayPrice ?? String(localized: "价格加载中"))
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.inkPrimary)
                    .accessibilityIdentifier("paywall.price")
                Text("/ 月 · month")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Label("通过 App Store 订阅，随时可以取消", systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
        }
        .cardSurface(padding: 20)
    }

    private var subscribeButton: some View {
        VStack(spacing: 10) {
            Button {
                Task { await subscribe() }
            } label: {
                HStack(spacing: 8) {
                    if subscriptions.isWorking {
                        ProgressView().tint(Theme.onAccent)
                    }
                    Text("开始订阅 · Subscribe")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .disabled(subscriptions.isWorking)
            .accessibilityIdentifier("paywall.subscribe")

            Text("由 Apple ID 账户扣款，确认购买后立即生效；到期前可随时在 App Store 账户里取消。")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legalFooter: some View {
        HStack(spacing: 14) {
            Button("恢复购买 · Restore") {
                Task { await restore() }
            }
            .accessibilityIdentifier("paywall.restore")
            Link("使用条款 · Terms", destination: LegalLinks.terms)
            Link("隐私政策 · Privacy", destination: LegalLinks.privacy)
        }
        .font(.caption)
        .foregroundStyle(Theme.inkSecondary)
        .tint(Theme.inkSecondary)
        .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func subscribe() async {
        do {
            switch try await subscriptions.purchase() {
            case .subscribed:
                showingThanks = true
            case .cancelled:
                break
            case .pending:
                message = String(localized: "购买还在等待确认，完成后 AI 解释会自动解锁。")
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func restore() async {
        do {
            try await subscriptions.restore()
            message = subscriptions.isSubscribed
                ? String(localized: "已恢复订阅，AI 解释可以用了。")
                : String(localized: "这个 Apple ID 下没有找到可恢复的订阅。")
        } catch {
            message = error.localizedDescription
        }
    }
}

/// One row of the benefit list: tinted icon tile, bilingual title, one line.
private struct BenefitRow: View {
    let icon: String
    let title: String
    let gloss: String?
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Theme.accentTint))
            VStack(alignment: .leading, spacing: 4) {
                BilingualTitle(primary: title, secondary: gloss, font: .body.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
    }
}

/// Where the hosted policy pages live (T28 fills these pages in).
enum LegalLinks {
    static let privacy = URL(string: "https://carelogue.ca/privacy")!
    static let terms = URL(string: "https://carelogue.ca/terms")!
    /// Apple's own subscription management screen.
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}
