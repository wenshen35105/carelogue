import SwiftUI

/// First-use AI consent (spec §7; Stitch first_use_consent_sheet). Shown
/// the first time 解释 is tapped on this device; agreeing is remembered,
/// "Not now" sends nothing and asks again on the next deliberate tap.
struct ConsentSheet: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        // The buttons sit outside the ScrollView: the points grew past the
        // sheet's height, and 同意并继续 must never be below the fold.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(Theme.accentTint))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("关于 AI 白话解释")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Theme.inkPrimary)
                            if let gloss = AppLanguage.gloss(String(localized: "About AI Explanations")) {
                                Text(gloss)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                        }
                        Text(AIDisclosure.consentSummary)
                            .font(.body)
                            .foregroundStyle(Theme.inkPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        point(icon: "text.viewfinder",
                              title: String(localized: "本地提取文字"),
                              detail: String(localized: "只在你的 iPhone 上识别报告文字，照片和 PDF 原件不会上传。"))
                        point(icon: "lock",
                              title: String(localized: "加密传输 · Encrypted in transit"),
                              detail: AIDisclosure.transitDetail)
                        point(icon: "checkmark.seal",
                              title: AIDisclosure.responsibilityTitle,
                              detail: AIDisclosure.responsibilityDetail)
                        point(icon: "slider.horizontal.3",
                              title: String(localized: "随时撤回"),
                              detail: String(localized: "在「档案与设置 › 设置 › 隐私与数据流向」里可以随时关闭或撤回同意。"))
                    }

                    Label("AI 解释仅帮助理解报告，不能替代医生的诊断。", systemImage: "checkmark.shield")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))

                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 6) {
                Button(action: onAccept) {
                    Text("同意并继续 · Continue")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("consent.accept")

                Button(action: onDecline) {
                    Text("暂不使用 · Not now")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("consent.decline")
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Theme.card)
        }
        .background(Theme.card)
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .interactiveDismissDisabled(false)
    }

    private func point(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.accentTint))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.inkPrimary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
