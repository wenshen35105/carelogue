# Carelogue · M3 Stitch Prompt（设置页 + 解释四态 + 同意弹窗）

> 用法：在 Stitch 的同一项目里发出，基于已有设计语言扩展三个新面。
> 生成后导出 → 评审 → 采纳值进 M3 的 T17/T19/T20 卡。

## Prompt（复制这段）

````text
Extend the existing Carelogue design with THREE new screens for the "explain"
milestone. Keep the exact same design language as the current Carelogue screens
in this project: warm off-white #F7F5F2 canvas, white cards with soft 17-20px
radii and hairline borders, apricot accent #D9784F, secondary text #8A8680,
SF Pro / PingFang SC typography, bilingual labels (Simplified Chinese primary,
small English sub-labels). Avoid Material Design; keep the native iOS feel.
All colors must have counterparts in the existing warm-charcoal dark system.

SCREEN 1 — Settings 设置 (new page)
One calm, card-based scrollable page (NOT a system-gray settings list).
- Section "AI · 解释功能" card:
  * toggle row "白话解释 (AI Explained)" — ON state, apricot toggle
  * row "解释服务 · DeepSeek" with a small green-ish status dot and "已配置"
  * row "API Key" showing masked value "sk-••••••••" with a "更换" action
  * small muted caption: "Key 保存在本机钥匙串，不上传"
- Section "隐私" card: three short lines with small line icons:
  * "数据只存本机 · on-device only"
  * "解释时仅发送提取文本；图像不离开设备"
  * "不存储、不用于训练"
  * ghost/outline button "撤回 AI 同意"
- Section "数据" card: one destructive row "清空所有数据" in a muted
  terracotta tone (NOT pure red), caption "不可撤销"
- Large title "设置 Settings", back link "‹ 档案与设置"

SCREEN 2 — Explanation card, 4 states (shown stacked on the report page
context so all can be compared)
1. Not yet explained: an outline apricot card, small sparkle icon, primary
   filled button "✨ 生成白话解释 · Explain"
2. Generating: same card with soft skeleton shimmer over 2-3 text lines,
   calm label "正在解释… (Explaining)" with a small spinner
3. Failed: muted warning icon, text "无法解释，请重试 (Couldn't explain —
   try again)", outline button "重试"
4. Explained (match the existing report screen): plain-language summary
   paragraph, term chips (e.g. CBC · 全血细胞计数), "可以问问医生" question
   list, tiny disclaimer line, actions "重新解释 · 复制 · 收起"
Note: when the AI toggle is OFF, the card is replaced by a calm single line
"AI 解释已在设置中关闭" with no action button.

SCREEN 3 — First-use consent sheet
Bottom sheet over a dimmed report page; rounded-top card in the same radius
language. Small apricot sparkle icon; title "关于 AI 解释"; body text:
"解释时，app 会在这台设备上提取报告文字，仅把文字发送给 DeepSeek 用于生成
解释；不发送图像，不存储、不用于训练。你可以随时在设置中撤回同意。"
Two buttons: filled apricot "同意并继续 · Continue", ghost "暂不使用 · Not now".

Show the three screens side by side.
````
