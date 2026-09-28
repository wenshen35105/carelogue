# App Review 回复材料 — Guideline 2.1（2026-09-26）

> 用途：① Resolution Center 回复（附录屏）② App Review Information → Notes 字段（模板明确要求两份都放）。
> 英文全文直接复制粘贴；粘贴前先完成文末【核对三项】确认文本与实际配置一致。

## English (paste this)

**Guideline 2.1 — Information Needed: Reply**

Thank you for reviewing Carelogue. Below is the requested information.

**1. Screen recording (attached).** Captured on a physical iPhone running the latest iOS, starting with app launch and showing the typical user flow: creating a journey, adding a visit with on-device transcription, adding a report photo, using the AI explanation, and completing the subscription flow (the paywall displays the subscription title, length, price, and links to Terms of Use and Privacy Policy). The app has no account system — there is no registration, login, or account deletion flow to demonstrate.

**2. Purpose and target audience.** Carelogue is a personal health-journey organizer for patients and families managing ongoing care (for example, a pregnancy). It addresses two problems: medical information scatters across visits, reports and notes; and medical language is hard to understand — especially for families navigating care in a second language. Value: everything is kept in one timeline, reports are explained in plain language, and users bring better questions to their doctor. Target audience: adults managing their own or a family member's care.

**3. Setup and access.** No account, login, or credentials are required. The app works fully offline; data is stored on the device, with optional iCloud sync via the user's own Apple ID. Record-keeping features are free; AI features require the "Carelogue Plus" subscription. Typical flow: open the app → create a journey → add a visit, note, or report photo → tap "Explain" on a report. No sample files or credentials are needed.

**4. External services.**
- Cloudflare Workers — stateless API forwarding for AI requests; no health data stored server-side.
- DeepInfra — third-party AI inference (DeepSeek model); only the text the user explicitly submits is processed, and nothing is retained.
- Apple iCloud / CloudKit — optional sync and private sharing, hosted by Apple.
- Apple StoreKit — subscription purchases.
Used on-device only: Apple Vision (OCR) and Apple Speech (transcription).

**5. Regional differences.** None — the app functions consistently in all regions where it is available. The interface is bilingual (English / Simplified Chinese). No region-specific features or content.

**6. Regulated industry / protected material.** Not applicable. Carelogue is a personal record-keeping and comprehension tool; it provides no diagnosis, treatment advice, or clinical decision support, and is not a regulated medical device. No protected third-party material is included.

**7. In-App Purchase overview.** One subscription: "Carelogue Plus" — auto-renewable, monthly, $3.99/month with a 1-week free trial — unlocking AI features (plain-language report explanations, medical-term cards, and visit summaries). All record-keeping features are free. Navigation: tapping any AI feature (for example, "Explain" on a report) presents the paywall; it is also reachable from Settings. The paywall displays the title, length, price, and links to Terms of Use and Privacy Policy.

**Additional notes.**
- No account system exists: no registration, login, or account deletion is applicable. Settings → "Erase all data" deletes everything on the device; uninstalling the app also removes all data.
- No public user-generated content. Records are private to the device or the user's own iCloud. Journey sharing (inviting a family member via Apple's CloudKit sharing, new in 1.0) is private and user-initiated; fully testing it end-to-end requires a second Apple ID — the rest of the app works without sharing.
- The subscription supports Family Sharing.
- Health-related content is never stored on our servers: AI requests are user-initiated and processed without retention.

## 中文操作清单

### Step 1 · 录屏（你用真机录，2–4 分钟，一镜到底）

准备：iPhone（最新 iOS）、开勿扰模式、连 Wi-Fi（AI 要联网）、先把 app 删掉重装保持干净状态。

录屏方法：控制中心 → 长按录屏按钮 → 开始录 → 回主屏点开 app（从启动第一个画面开始）。

分镜：
1. 启动 → Journeys 列表
2. 新建 journey（如 "Pregnancy"）→ 创建
3. 加一次就诊：录音（麦克风弹窗选允许）→ 说几句 → 停止 → 本地转写出现
4. 加一份报告照片（可选）→ 本地 OCR
5. 报告上点 "Explain" → 订阅页出现（**停留 3–5 秒**，让 $3.99/month、Terms、Privacy 清晰可见）→ 继续 → 沙盒购买完成
6. AI 解释、术语卡出现
7. 结束

注意：只用编造数据（"Our First Baby" 那种），不要出现真实医疗信息。

### Step 2 · 上传 + 回复（ASC）

1. ASC → Resolution Center → 回复框：粘贴上方英文全文 + 附件上传录屏（超过大小限制就传 YouTube 私享链接，把链接贴进回复）
2. 同一英文全文贴到：版本页 → App Review Information → **Notes**（模板明确要求）
3. 提交

### Step 3 · 核对三项（粘贴前必须与文本一致）

a. **订阅配置**：ASC → 订阅 → Carelogue Plus → 确认「1 周免费试用」（Introductory Offer）与 Family Sharing 是否已配。英文文本第 7 条与附加第 3 条写了这两个——**没配就把对应句子删掉再贴**。
b. **IAP 随版本提交**：版本页 → "In-App Purchases and Subscriptions" 区 → 确认此订阅与该 1.0 版本一起提交（模板预防点 3.1.1）。
c. **CloudKit schema 部署 Production**：CloudKit Console → container `iCloud.ca.carelogue.app` → Deploy Schema to Production。sharing 功能在审核 build 与上架后走 Production 环境——不部署的话审核员测共享会失败。让 CC 做或你来做（只增 schema，操作前确认 development 环境已含全部 share 记录类型）。

## 内部备注

- 这是新账号首审的标准 2.1 信息请求，不是拒审；回复完整后继续审，一般不需要出新 build。
- 审核中的 build（含 T39 sharing，ask for 第二 Apple ID 的说明见英文附加段）。
- 提交前最后检查：Resolution Center 回复与 Notes 用同一份英文文本。
