# Carelogue · M4 Stitch Prompt（订阅相关：paywall / 设置页订阅版 / 未订阅引导 / 时间线摘要）

> 用法：同一 Stitch 项目里发出，基于已有设计语言扩展。
> 生成后导出 → 丢回来评审 → 采纳值进 M4 的 T27/T28/T25 卡。

## Prompt

Extend the existing Carelogue design with the subscription (launch) screens.
Keep the exact same design language as the current Carelogue screens: warm
off-white #F7F5F2 canvas, white cards with soft radii and hairline borders,
apricot accent #D9784F, secondary text #8A8680, SF Pro / PingFang SC type,
bilingual labels (Simplified Chinese primary, small English sub-labels),
native iOS feel. Show the light theme (the dark "Nocturne" system already
exists and follows automatically).

SCREEN 1 — Subscription page ("Carelogue Plus" paywall)
A calm, focused full-screen page (may be presented as a sheet), single column.
- Top: small brand mark (heart + cross), title "Carelogue Plus", subtitle
  "解锁全部 AI 功能 · Unlock all AI"
- Benefit list (3 rows, small line icons, generous spacing):
  1. "白话解释 — 把报告变成白话总结、术语卡和「问问医生」清单"
  2. "全部 AI 功能 — 未来新增的 AI 能力都会包含，不加价"
  3. "隐私不变 — 订阅只解锁 AI；你的数据始终只存在你的设备"
- Price block: prominent "$3.99 / 月", caption "通过 App Store 订阅，随时取消"
- Primary CTA (filled apricot, full width): "开始订阅 · Subscribe"
- Footer links (small, muted, one row): "恢复购买 · Restore" ·
  "使用条款 · Terms" · "隐私政策 · Privacy"
- Tone: trustworthy and warm — NOT aggressive growth-hack style; no
  countdowns, no 限时, no guilt copy.

SCREEN 2 — Settings page, subscription version (replaces the current
"AI · 解释功能" section)
- New "订阅 · Subscription" card:
  * row "Carelogue Plus" with a small green pill "订阅中 · Active"
  * row "下次续费 · 2026年10月22日"
  * row "管理订阅 · Manage" (chevron) and row "恢复购买 · Restore"
- Privacy card stays, copy updated to:
  * "数据只存本机 · on-device only"
  * "解释时仅发送提取文本；图像不离开设备"
  * "我们的 AI 服务承诺不将你的数据用于训练"
  * ghost button "撤回 AI 同意 · Revoke consent"
- Data card stays: destructive row "清空所有数据 · Erase all data"
- Page title "设置 Settings".

SCREEN 3 — Report page, NOT-subscribed state
The explanation-card slot on a report detail page shows a guided (locked) card:
- small sparkle icon, title "白话解释 · AI Explained"
- one line: "订阅后，这份报告会变成白话总结、术语卡和「问问医生」清单"
- filled apricot button "解锁订阅 · Subscribe"
- tiny muted caption: "已有订阅？恢复购买"
- Note: the SUBSCRIBED state keeps the existing explanation card exactly as
  designed today (no change).

SCREEN 4 — Timeline card with AI summary (small addition)
A visit card inside a Journey timeline, now with one extra line at the bottom:
a tiny sparkle icon + "AI 摘要：医生说一切正常，两周后复查…" in muted text,
single line, tappable to open the record.

Show all screens side by side.
