# Carelogue · T32 Stitch Prompt（面诊录音 + 疑问翻译）

> 用法：同一 Stitch 项目里发出，基于已有设计语言扩展。
> 生成后导出 → 丢回来评审 → 采纳值进 M5 的 T32 卡。
> 已拍板（2026-09-23）：入口在**就诊记录详情页**；录音文件**随 iCloud 私有库同步**（同 ID 多设备）；音频**不进 AI**（本地转写、只送文本）。
> 深色（Nocturne）版待浅色稿通过后另出（同既有流程）。

## Prompt

Extend the existing Carelogue design with the consultation recording + question translation screens (record a doctor's visit, get a plain-language summary, and carry your questions in English).

Keep the exact same design language as the current Carelogue screens: warm off-white #F7F5F2 canvas, white cards with soft radii (18-20pt) and hairline borders, apricot accent #D9784F, secondary text #8A8680, SF Pro / PingFang SC type, bilingual labels (Simplified Chinese primary with small English sub-labels), native iOS feel. Show the light theme (the dark "Nocturne" system follows later, same as before).
Tone is critical: this feature must feel like a quiet notepad — NOT like surveillance. No big red recording dots, no flashy waveforms, no alarm-like visuals. Calm, private, discreet.

SCREEN 1 — Visit detail page with the recording card (two states)
Same structure as today's visit (就诊) detail page (title, date, notes, attachments card). ADD a new card ABOVE the attachments card: "面诊录音 · Visit Recording".
- State A (no recording): soft microphone icon, one line "录下医生的话，回家慢慢整理 · Record the visit, review at home", apricot-tinted button "开始录音 · Record", and a subtle bottom text link "我的疑问（英文）· My Questions" (questions don't require a recording).
- State B (recorded): a playback row (small play button, "32:14", a faint wave hint), a one-line summary preview "医生说一切正常，两周后复查…", and two small text buttons: "查看总结 · Summary" and "我的疑问（英文）· My Questions".
- Card microcopy (muted, tiny): "录音保存在你的设备与 iCloud 私有库 · Kept in your device & private iCloud".

SCREEN 2 — Recording screen (full-screen sheet, active)
- Very calm: large light-weight elapsed timer "12:38" centered, a subtle live level indicator (soft pulsing dot or minimal bars), one large rounded-square stop button (apricot) at the bottom, and a small "暂停 · Pause" text button beside it.
- Top: small pill "正在录音 · Recording" and one gentle line: "记得告诉医生：我在录音，方便回家整理 · Let the doctor know you're recording".
- Dimmed, quiet — no red lights.

SCREEN 3 — Processing state (in the card)
- Reuses the explanation card's "generating" pattern: gentle shimmer or soft spinner, "正在本地转写并整理… · Transcribing on device…", caption "在设备上转写；只有文字用于整理，通常十几秒 · Transcribed on device; only text is processed".
- No fake progress bars or countdowns.

SCREEN 4 — Visit summary card ("医生说了什么 · What the doctor said")
- Same visual language as the explanation card (white card, sectioned):
  * Header: "面诊总结 · Visit Summary" with a small sparkle icon + a "32:14" playback chip to re-listen.
  * Body: 2–4 short paragraphs of plain-language summary (same type rhythm as the explanation card).
  * "关键要点 · Key points" bullet list (e.g. "两周后复查血常规", "继续补铁", "下次带 NT 报告").
  * "可以再问 · Follow-ups" mini list (1–3 questions worth asking next time).
  * Footer (muted, small): "AI 整理，可能有遗漏；请以医生原话与病历为准 · AI-organized; the doctor's words prevail".
- Include a long-content variant (a 4-line paragraph + 4 bullets) to prove it doesn't break.

SCREEN 5 — Questions → English ("我的疑问 · My Questions")
- Stacked layout: a list of 2–3 editable question rows in Chinese (e.g. "血糖偏高需要控制饮食吗？") with a small "+ 添加问题" row; each question paired with its English translation right below (e.g. "Do I need to watch my diet given the higher blood sugar?").
- One prominent secondary button: "给医生看 · Show the doctor" — a clean full-screen presentation mode: large English text, high contrast, no UI chrome, readable at arm's length, small "完成 · Done" to close.
- Microcopy: "翻译只为沟通；医疗判断以医生为准 · For communication only".

Show all screens side by side.
