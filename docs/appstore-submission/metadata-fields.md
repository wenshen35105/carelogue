# 1.0 提审 · 字段填写手册（对照 ASC 版本页）

> 用途：1.0 提审时对照 ASC 逐字段填写。状态：**✅ 已定** / **📝 草案**（可微调）/ **⏳ 待办**（有前置动作）。
> 参考：`reference/`（ASC 版本页 PDF 与 4 张转图）。

## A. 版本页字段（iOS App 1.0 · Distribution）

| # | 字段 | 限制 | 填什么 | 状态 |
|---|---|---|---|---|
| 1 | Screenshots · **iPhone 6.5"** | ≤10 张；1242×2688 / 2688×1242 / 1284×2778 / 2778×1284 | 7 张 × 2 语言（`screenshots/iphone-6.5/en-CA/` → English (Canada)；`zh-Hans/` → 简体中文）：旅程列表 / 时间线 / 报告+AI 解释 / 面诊录音 / 面诊总结 / 疑问翻译 / 订阅页。每张说明见该目录 README | ✅ 已出图 |
| 2 | Screenshots · **iPad 13"** | ≤10 张 | **决策**：走 iPhone-only（iPad 适配留 v1.1）→ 该档免交。✅ 2026/09/25 核实：工程已是 iPhone-only（`TARGETED_DEVICE_FAMILY = 1`），**Xcode 无需改动**；ASC 现在显示 iPad 13" 档只是因为还没传构建——iPhone-only 构建上传后该档自动消失 | ✅ 核实 |
| 3 | App Previews | ≤3 视频 | 不做（选填） | ✅ |
| 4 | **Promotional Text** | 170 | EN：`Log visits, translate reports, record appointments — your health journey in plain words, kept private on your device.` ｜ 中文：`记录就诊、看懂报告、录下面诊——用大白话管好健康，数据留在你的设备上。` | 📝 |
| 5 | **Description** | 4,000 | 见下方 §C 全文草案（EN + 中文） | 📝 |
| 6 | **Keywords** | 100 | EN：`care log,health journal,medical records,doctor visit,symptom,reports,ai,plain words,family`（90 字符；规则：逗号分隔、**逗号后不加空格**） | 📝 |
| 7 | **Support URL** | — | `https://carelogue.ca/support` | ✅ 已上线（2026-09-26，`docs/web/support.md` 经 Worker 渲染） |
| 8 | Marketing URL | — | 先留空（或 `https://carelogue.ca`） | 📝 |
| 9 | Version | — | `1.0` | ✅ |
| 10 | **Copyright** | 200 | `© 2026 Jiajin Lin` | 📝 |
| 11 | Routing App Coverage File | — | 不适用（仅地图类）→ 留空 | ✅ |
| 12 | App Clip / iMessage App | — | 不适用 → 跳过 | ✅ |
| 13 | **Build** | — | 上传构建（Xcode → Archive → Distribute App；bundle id `ca.carelogue.app`）→ 版本页 Add Build 选择 | ⏳ 老板 Mac |
| 14 | Game Center | — | 不勾 | ✅ |
| 15 | **Sign-In Information** | — | ⚠️ **取消勾选 "Sign-in required"**（无账号系统）；username / password 留空（当前截图里是勾着的，提审前改掉） | ⏳ 改 |
| 16 | Contact Information | — | 老板本人（姓名 / 电话 / 邮箱——**在 ASC 直接填，不写入本仓库**） | ⏳ |
| 17 | **Notes**（审核备注） | 4,000 | 见 `review-notes.md`（直接复制） | ✅ |
| 18 | Attachment | — | 选填 → 不传 | ✅ |
| 19 | **App Store Version Release** | — | ⚠️ 改选 **"Manually release this version"**（当前截图为 Automatically——我们定手动：真机验收过再点发布） | ⏳ 改 |

## B. App 级字段（不在版本页，1.0 必须齐）

| 字段 | 填什么 | 状态 |
|---|---|---|
| App 名称 | `Carelogue`（与 ASC 现有 app 记录、bundle id `ca.carelogue.app` 一致；2026/09/25 定：全部文案统一用 Carelogue） | ✅ 已建 |
| 副标题 Subtitle | `Health records, made clear`（24/30） | 📝 |
| 主 / 副类别 | 主：Health & Fitness；副：Medical | 📝 建议 |
| 年龄分级 | 按问卷照实——**逐题答案见下方「年龄分级问卷」** | ⏳ 填问卷 |
| App Privacy（隐私标签） | **Data Not Collected**——逐项复核：无追踪、无第三方 SDK、AI 转发=实时处理不留存；1.0 共享功能不改变结论（走用户自己的 iCloud，不经我们）；与 `docs/legal/` 隐私政策一致（2026/09/25 已补「共享功能」章节） | ⏳ 填问卷 |
| 价格与地区 | ✅ **已设（2026-09-25）：仅 United States + Canada**——白名单方式（比全选减中国更稳：避开欧盟 DSA、韩国分级、巴西评级等合规填报；扩展随时可改、无需重审）。Price Schedule 保持 Free，收费走订阅 | ✅ 已办 |
| 订阅产品 | `ca.carelogue.app.plus.monthly`（$3.99/月、首周免费、Family Sharing 开、multiseat No）——**首次须随版本提交**（版本页勾选）。⚠️ 仓库里的 `Carelogue.storekit` 只是 UI 测试夹具（无试用期、无家庭共享）；「首周免费 + 家庭共享」要在 **ASC 订阅配置里真的开**，否则改文案（见 review-notes 警示） | ✅ 已办 |

## B2. 年龄分级问卷答案（ASC · App Information → Age Ratings）

2025-07 新版问卷（新增 In-App Controls / Capabilities 区块）+ **2026-09 起强制的社交媒体声明**。

| 问题 | 答案 | 理由（对照 Apple 定义） |
|---|---|---|
| In-App Controls · **Parental Controls** | **No** | 无家长控制工具 |
| In-App Controls · **Age Assurance** | **No** | 无年龄验证机制（未用 Declared Age Range API） |
| Capabilities · **Unrestricted Web Access** | **No** | app 内无浏览器；法律/订阅链接用系统 Safari 打开 |
| Capabilities · **User-Generated Content** | **No** | 用户内容不广泛分发（私人库 + 定向共享给受邀个人） |
| Capabilities · **Social Media** | **No** | 无 feed / 发现 / 转发扩散机制（2026-09 起此题为必答） |
| Capabilities · **Social Media Disabled for Users Under 13** | **No** | 无社交媒体，未调用 Declared Age Range API——不声明豁免（答完上题若无此问则忽略） |
| Capabilities · **Messaging and Chat** | **No** | 无用户间通信功能 |
| Capabilities · **Advertising** | **No** | 无任何广告 |

- **内容描述符逐项**（None / Infrequent / Frequent）：
  - **Mature Themes**：Profanity or Crude Humor = **None**；Horror/Fear Themes = **None**；Alcohol, Tobacco, or Drug Use or References = **None**
  - **Medical or Wellness**：
    - Medical or Treatment Information（三档频率题 None/Infrequent/Frequent）：**Infrequent**——展示医疗记录 + 教育性解释；不提供诊断/治疗指导（Apple 新规：**Frequent 医疗内容 → 16+**）
    - Health or Wellness Topics（**No/Yes 布尔题**）：**No**——不提供自我护理/生活方式建议；用户记录数据 ≠ 建议
  - **Sexuality or Nudity**：Mature or Suggestive Themes / Sexual Content or Nudity / Graphic Sexual Content and Nudity = **None**（全）
  - **Violence**：Cartoon or Fantasy Violence / Realistic Violence / Prolonged Graphic or Sadistic Realistic Violence / Guns or Other Weapons = **None**（全）
  - **Chance-Based Activities**：Gambling / Simulated Gambling / Contests / Loot Boxes = **None**（全）
- **分级档位（2025 新制）**：4+ / 9+ / 13+ / 16+ / 18+（旧 12+ / 17+ 已移除）。
- **最终取值（2026-09-25 已办）**：问卷答完后**手动提高到 16+**——官方支持（"set a higher age rating"）；医疗内容 + 成人工具，保守无副作用（分级只影响家长控制，不挡成人用户）。
- **Regulated Medical Device 声明**（触发条件：在 US/EU/UK 在售且类目为 Health & Fitness/Medical——我们满足；路径：App Information → App Store Regulations & Permits → **Declare Regulated Medical Device**）：**选 No**（非受监管医疗器械）——官方判定清单六条（FDA 批准/注册、CE、UKCA、自认证）全否；器械定义（诊断/预防/监测/治疗）不沾。**选 No 无需附加材料，Save 即完成**。

## C. Description 全文草案

### English (Canada)（主语言）

```
Carelogue is a calm, private home for your health records.

Log doctor visits, test results, measurements and everyday notes in one timeline you actually understand. Point your camera at a paper report and Carelogue extracts the text on your device — then explains it in plain language: what the numbers mean, the terms translated, and questions worth asking your doctor next time.

• Visit logs, quick notes and measurements — one timeline per journey
• Scan reports and lab results with your camera; text is extracted on your device
• AI explanations in plain language — a summary, a term card and a question list for your doctor
• Record appointments and get a written summary, with your questions translated for the conversation
• Share a journey with family — the invite goes through your own iCloud, and both of you can view and edit
• Bilingual: English and Simplified Chinese, side by side

Privacy is the point:
• Your records, attachments and recordings live on your device and in your own private iCloud. We can't read them.
• Sharing a journey goes through Apple's iCloud too — never any other server.
• Images never leave your device — only extracted text can be sent for an explanation, processed in real time and never stored.
• Audio never goes to AI — transcription happens on your device.
• No account, no tracking, no ads.

Carelogue Plus (optional subscription, $3.99/month with a 1-week free trial) unlocks AI features. All record-keeping is free, forever.

Carelogue is a record-keeping tool. It doesn't provide diagnoses or medical advice — always talk to your doctor.
```

### 中文（zh-Hans 本地化时用）

```
Carelogue 是你健康记录的安心去处。

把就诊、检查、测量和随手记放进一条真正看得懂的时间线。对着纸质报告拍一张，Carelogue 会在你的设备上提取文字，再用大白话讲给你听：指标是什么意思、术语怎么翻译、下次见医生该问什么。

• 就诊记录、随手记、测量——一段旅程，一条时间线
• 拍照扫描报告与化验单；文字在本机提取
• AI 大白话解释——总结、术语卡，以及问医生的问题清单
• 面诊录音与书面总结；你的疑问提前翻译好，给医生看
• 把一段旅程分享给家人——邀请走你自己的 iCloud，双方都能查看和编辑
• 中英双语并排显示

隐私是底线：
• 记录、附件与录音保存在你的设备和你自己的 iCloud 私有库——我们读不到
• 共享旅程同样只经过 Apple 的 iCloud，不经任何其他服务器
• 图像不离开设备——只有提取出的文字会被送去生成解释，实时处理、不留存
• 音频不进 AI——转写在这台设备上完成
• 无账号、无追踪、无广告

Carelogue Plus（可选订阅，$3.99/月，首周免费）解锁 AI 功能；所有记录功能免费。

Carelogue 是记录工具，不提供诊断或医疗建议——请始终咨询你的医生。
```

## D. 提交前 checklist

- [x] 截图 6.5" 就位（1284×2778，iPhone 13 Pro Max 模拟器出图；`ASCScreenshotUITests` / `ASCScreenshotEnglishUITests` 生成，中英各 7 张）
- [x] ASC 里分别上传：English (Canada) 传 `en-CA/`，简体中文 传 `zh-Hans/`
- [x] iPad 决策落地：已核实工程为 iPhone-only，Xcode 无需改动；构建上传后 ASC 的 iPad 13" 档自动消失
- [x] Sign-in required 取消勾选
- [x] Release 方式改为 Manually release
- [x] Support URL 页上线（carelogue.ca/support，2026-09-26）
- [x] 构建上传 + Add Build
- [x] 订阅产品 Ready to Submit + 版本页勾选
- [x] 隐私标签 + 年龄分级完成
- [x] Notes 粘贴（review-notes.md）
- [x] Contact Information 填好
