# 1.0 提审 · 字段填写手册（对照 ASC 版本页）

> 用途：1.0 提审时对照 ASC 逐字段填写。状态：**✅ 已定** / **📝 草案**（可微调）/ **⏳ 待办**（有前置动作）。
> 参考：`reference/`（ASC 版本页 PDF 与 4 张转图）。

## A. 版本页字段（iOS App 1.0 · Distribution）

| # | 字段 | 限制 | 填什么 | 状态 |
|---|---|---|---|---|
| 1 | Screenshots · **iPhone 6.5"** | ≤10 张；1242×2688 / 2688×1242 / 1284×2778 / 2778×1284 | 套图 6–8 张（`screenshots/iphone-6.5/`）：旅程列表 / 时间线 / 报告+AI 解释 / 面诊录音 / 面诊总结 / 疑问翻译 / 订阅页 | ⏳ CC 出图 |
| 2 | Screenshots · **iPad 13"** | ≤10 张 | **决策**：走 iPhone-only（推荐，iPad 适配留 v1.1；target 去掉 iPad）→ 该档免交 | ⏳ 拍板 |
| 3 | App Previews | ≤3 视频 | 不做（选填） | ✅ |
| 4 | **Promotional Text** | 170 | EN：`Log visits, translate reports, record appointments — your health journey in plain words, kept private on your device.` ｜ 中文：`记录就诊、看懂报告、录下面诊——用大白话管好健康，数据留在你的设备上。` | 📝 |
| 5 | **Description** | 4,000 | 见下方 §C 全文草案（EN + 中文） | 📝 |
| 6 | **Keywords** | 100 | EN：`care log,health journal,medical records,doctor visit,symptom,reports,ai,plain words,family`（≈95；规则：逗号分隔、**逗号后不加空格**） | 📝 |
| 7 | **Support URL** | — | `https://carelogue.ca/support` | ⏳ 页面待建 |
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
| App 名称 | `Catalogue`（若被占 → 加副题 `Catalogue: Care Log`） | ✅ 已建 |
| 副标题 Subtitle | `Health records, made clear`（24/30） | 📝 |
| 主 / 副类别 | 主：Health & Fitness；副：Medical | 📝 建议 |
| 年龄分级 | 按问卷照实——**逐题答案见下方「年龄分级问卷」** | ⏳ 填问卷 |
| App Privacy（隐私标签） | **Data Not Collected**——逐项复核：无追踪、无第三方 SDK、AI 转发=实时处理不留存；与 `docs/legal/` 隐私政策一致 | ⏳ 填问卷 |
| 价格与地区 | 免费 + 订阅；地区：全球**除中国大陆**（已决：不做中国区） | 📝 建议 |
| 订阅产品 | `ca.carelogue.app.plus.monthly`（$3.99/月、首周免费、Family Sharing 开、multiseat No）——**首次须随版本提交**（版本页勾选） | 配置中 |

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
- **相关**：App Information 里另有 **Regulated Medical Device Status** 声明——选**非受监管医疗器械**（app 明确不做诊断/治疗，文案已全程声明）。

## C. Description 全文草案

### English (Canada)（主语言）

```
Catalogue is a calm, private home for your health records.

Log doctor visits, test results, measurements and everyday notes in one timeline you actually understand. Point your camera at a paper report and Carelogue extracts the text on your device — then explains it in plain language: what the numbers mean, the terms translated, and questions worth asking your doctor next time.

• Visit logs, quick notes and measurements — one timeline per journey
• Scan reports and lab results with your camera; text is extracted on your device
• AI explanations in plain language — a summary, a term card and a question list for your doctor
• Record appointments and get a written summary, with your questions translated for the conversation
• Share a journey with family or your doctor (invite from the app)  ← 仅当共享功能随 1.0 上线则保留；否则删除（不可描述未上线功能）
• Bilingual: English and Simplified Chinese, side by side

Privacy is the point:
• Your records, attachments and recordings live on your device and in your own private iCloud. We can't read them.
• Images never leave your device — only extracted text can be sent for an explanation, processed in real time and never stored.
• Audio never goes to AI — transcription happens on your device.
• No account, no tracking, no ads.

Catalogue Plus (optional subscription, $3.99/month with a 1-week free trial) unlocks AI features. All record-keeping is free, forever.

Catalogue is a record-keeping tool. It doesn't provide diagnoses or medical advice — always talk to your doctor.
```

### 中文（zh-Hans 本地化时用）

```
Catalogue 是你健康记录的安心去处。

把就诊、检查、测量和随手记放进一条真正看得懂的时间线。对着纸质报告拍一张，Catalogue 会在你的设备上提取文字，再用大白话讲给你听：指标是什么意思、术语怎么翻译、下次见医生该问什么。

• 就诊记录、随手记、测量——一段旅程，一条时间线
• 拍照扫描报告与化验单；文字在本机提取
• AI 大白话解释——总结、术语卡，以及问医生的问题清单
• 面诊录音与书面总结；你的疑问提前翻译好，给医生看
• 把一段旅程分享给家人或医生（app 内发出邀请）  ← 同上：视共享功能是否随 1.0 上线
• 中英双语并排显示

隐私是底线：
• 记录、附件与录音保存在你的设备和你自己的 iCloud 私有库——我们读不到
• 图像不离开设备——只有提取出的文字会被送去生成解释，实时处理、不留存
• 音频不进 AI——转写在这台设备上完成
• 无账号、无追踪、无广告

Catalogue Plus（可选订阅，$3.99/月，首周免费）解锁 AI 功能；所有记录功能免费。

Catalogue 是记录工具，不提供诊断或医疗建议——请始终咨询你的医生。
```

## D. 提交前 checklist

- [ ] 截图 6.5" 就位（1284×2778，iPhone 13 Pro Max 模拟器出图）
- [ ] iPad 决策落地（默认：改 iPhone-only）
- [ ] Sign-in required 取消勾选
- [ ] Release 方式改为 Manually release
- [ ] Support URL 页上线（carelogue.ca/support）
- [ ] 构建上传 + Add Build
- [ ] 订阅产品 Ready to Submit + 版本页勾选
- [ ] 隐私标签 + 年龄分级完成
- [ ] Notes 粘贴（review-notes.md）
- [ ] Contact Information 填好
