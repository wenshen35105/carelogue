import Foundation

/// Every user-facing sentence about where report text goes, in one place
/// (spec §11, "责任版" wording decided 2026-09-22).
///
/// Carelogue does not make promises on the AI provider's behalf: the copy
/// states what we can stand behind — what leaves the device, and the standard
/// we apply when choosing or replacing a provider. The provider is named only
/// where the sentence is a plain fact about this build ("the service it talks
/// to"), so T26 — which moves the call behind Carelogue's own server — has to
/// change `serviceName` and nothing else.
enum AIDisclosure {
    /// Who the device sends extracted report text to. Since T26/T27 that is
    /// Carelogue's own relay, which forwards to the AI service we selected;
    /// the explanation records the model that actually answered.
    static let serviceName = "Carelogue"

    /// What leaves the device (Settings privacy card, consent sheet).
    static var textOnlyDetail: String {
        String(localized: "报告文字在本机识别，只有文字会经加密通道发给我们选用的 AI 服务；照片和 PDF 原件不离开设备。")
    }

    /// Our own responsibility for the provider — the "责任版" core sentence.
    /// Replaces the earlier "不存储、不用于训练", which promised something we
    /// cannot promise for someone else (m3-bugs #1).
    static var responsibilityTitle: String { String(localized: "AI 服务由我们挑选") }
    static var responsibilityGloss: String { String(localized: "Our responsibility") }
    static var responsibilityDetail: String {
        String(localized: "我们只选用在条款层面承诺不把 API 数据用于模型训练、并写明保留期限的 AI 服务；服务商条款变化就更换，发布后更换会通知你。Carelogue 自己不留存你的报告文字。")
    }

    /// Consent sheet: the single-paragraph version shown before the points.
    static var consentSummary: String {
        String(localized: "解释时，Carelogue 会在这台设备上提取报告文字，仅把文字发送给我们选用的 AI 服务用于生成白话说明；照片和 PDF 原件不会离开设备。你可以随时在设置中撤回同意。")
    }

    static var transitDetail: String {
        String(localized: "只有文字经 HTTPS 加密通道发送；Carelogue 自己不留存报告文字。")
    }
}
