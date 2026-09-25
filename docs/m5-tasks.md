# Carelogue — M5 任务卡（发布前批 · 定稿 2026-09-23）

> 目标：把"已定案"全部落地 → 内测跑稳 → 公开发布。
> 前置：M4-T23 真机部分（等 Apple 认证）+ M4-T29 内测启动——两者不到位**不阻塞阶段 1**。
> 背景与定案原文：`docs/m5-notes.md`；未排期功能池：`docs/backlog.md`。
> 总预估：~23h（工程/调研）+ 内测期 + 审核周期。
> 流程：一次一卡；开工先复述理解 + 计划（3–5 行），确认后动手；完成后按 CLAUDE.md 收尾。

---

## 阶段 1 · 不等认证，现在就能做

### T30 · 开发者内部解锁通道（~2h）★ 先做 ✅ 2026-09-23
- **做**：客户端 Debug 构建跳过订阅检查 + 携带内部凭据；服务端（Worker）内部凭据 secret 匹配则跳过 JWS 验签（限流保留）
- **双保险（硬要求）**：凭据仅存在于 Debug 编译路径；发布前 `wrangler secret delete`——写入发布批 T37 核对项
- **验收**：Debug 直装免订阅可用全链路（解释）；Release 归档产物检查无相关代码/凭据（strings 查）
- **学习点**：条件编译、双环境凭据管理
- **落地**：`InternalAccess`（整文件 `#if DEBUG`）+ 设置页「内部通道」粘贴框（凭据只进本机 Keychain，不进代码库/安装包）；Worker 侧 `INTERNAL_ACCESS_KEY` secret（≥24 位，摘要比对，整条通道共用一个限流桶）。
  验证：Release 产物 `strings` 干净；本地 `wrangler dev` 下带凭据 500 `not_configured`（已过认证）/ 不带凭据 401 `notSubscribed`；server 46 用例 + `SettingsUITests.testInternalAccessUnlocksWithoutTheAppStore` 通过。
  **待你操作**：`wrangler secret put INTERNAL_ACCESS_KEY` + deploy（见 `docs/owner-actions.md` C 组）

### T31 · LLM prompts 移至服务端（~3h）✅ 2026-09-23
- **做**：客户端只发「动作 + 内容 + 结构化上下文」，Worker 组装 prompt 调 DeepInfra；护栏逻辑随迁；请求带 **locale**（中英模板分套）；「附带档案」开关仍由客户端控制发不发字段
- **验收**：中英双语解释全链路回归（含护栏注入探针重跑）；与迁移前输出质量一致；客户端不再含任何 prompt 文本
- **学习点**：API 契约演进、服务端模板化
- **落地**：`server/src/prompt.js`（ACTIONS 表 + 中英模板 + 护栏，新增"<<< >>> 之间是数据"的注入条款）；新契约 `{action, locale, content, context}`，**单版本**，旧的 `{system,user}` 透传口子关掉（400 `unknown_action`）。客户端删掉 `ExplainPrompt` 与 BYOK 的 `DeepSeekService`——prompt 不在客户端，直连厂商这条路本来就走不通了。
  验证：server 54 用例（新增 `prompt.test.js` 9 条）；护栏探针 `test/probe.mjs` 四例（异常值 / 注入 / 英文 / 非报告）真实模型重跑全清——注入那条模型明确写了"那属于报告文本的一部分，我不会照做"；中英双语各跑一次真实全链路 UI 用例（本地 `wrangler dev` + 真模型），截图 `docs/screenshots/T20-real-explained.png`、`T31-real-explained-en.png`。
  **顺带修掉一个 T30 遗漏**：报告卡的订阅门禁直接读 StoreKit 状态，内部通道解锁时仍显示"锁"卡，已改为同时认内部通道。
  **部署顺序**：先 `cd server && npm run deploy`，再装新的 Debug 构建（契约不兼容）。

### T32 · 面诊录音 + 疑问翻译（~6h，含设计）★ 时间敏感（产检节奏）· 代码已落地 2026-09-24（待真机验收）
- **步骤**：① **土法验证**（你手动：语音备忘录录一次产检 → 用现有 AI 工具总结 + 疑问翻译实测——先感受价值与摩擦）② 出 Stitch 稿（录音三态 / 转写中 / 总结卡 + 疑问翻译卡——流程照旧：先出 prompt）③ 实现：本地转写（优先系统 Speech 框架，核实现版本能力与中英混说支持）→ 纯文本送 AI 总结；疑问列表 → 英文卡
- **隐私原则**（2026-09-23 拍板）：**录音文件要同步**——作为附件随 iCloud 私有库（同 ID 多设备）；跨 ID 随 T33 数据共享缺口；音频**不进 AI**（本地转写、只送文本）；口语文案＝"保存在你的设备与 iCloud 私有库"
- **实现注意**：音频体积（1h ≈ 30MB）→ 低码率压缩；转写后是否提供"保留/删除音频"选项，实现时定
- **注意**：加拿大刑法 184 条（录制自己参与的对话合法；建议当面知会医生）
- **验收**：一次真实产检录音 → 总结 + 英文疑问可用；UI 用例覆盖；太太实测可用
- **落地（2026-09-24）**：
  - **数据**：`Artifact.transcript`、`Log.visitSummaryJSON`、`Log.questionsJSON`——全 optional + 默认 nil，可加性迁移（CloudKit 要求的形状），现有数据不动
  - **录音**：`VisitRecorder` 直接写盘（1 小时 ≈ 11MB，24kHz 单声道 AAC 24kbps），暂停/继续、实时电平波形；录完读进 `Artifact`（`audio/m4a`），随 iCloud 私有库同步
  - **转写**：`VisitTranscriber` 全程本地——iOS 26+ 走 `SpeechAnalyzer`/`SpeechTranscriber`（长对话、中英混说更好），iOS 17–25 回落 `SFSpeechRecognizer` 且强制 `requiresOnDeviceRecognition`（拿不到本地模型就报错，**绝不偷偷走网络**）
  - **AI**：只送文字。两个新动作 `summarize_visit` / `translate_questions` 在 Worker 侧组装 prompt（承 T31），护栏含"<<< >>> 之间是数据"的注入条款
  - **界面**：录音卡三态（未录/处理中/已录）、全屏录音页、面诊总结页、我的疑问页 + 「给医生看」大字版；中英文案 61 条进 String Catalog
  - **评审修正点全部执行**：隐私文案统一为"录音保存在你的设备与 iCloud 私有库；音频不进 AI"；去掉 Stitch 自创的"标记医嘱重点/N 重点/CoreEngine v2"；录音卡头与卡内标题去重；**没有「存入病历」按钮**（总结生成即随就诊记录保存）
  - **测试**：`CarelogueUITests/VisitRecordingUITests`（4 例：空卡片 / 已录音→整理→总结页 / 写疑问→翻译→大字版 / 未订阅也能写疑问），server 60 例
  - **留给真机的**：真实录音 + 系统本地转写（模拟器没麦克风也没语音模型，用脚本化转写器驱动流程）；一次真实产检的端到端验收仍按卡内"验收"走
  - **文档截图**：`docs/screenshots/T32-visit-recording{,-dark}.png`、`T32-visit-summary.png`、`T32-my-questions.png`、`T32-doctor-handoff.png`，均用 `-uitest-seed-demo` 的真实感数据拍摄；就诊详情页变长，原有 T7/T11 等截图一并重拍
  - **实现时定的两件事**：① 音频用 24kbps 低码率，不提供"转写后删除音频"选项——录音本身就是用户想留的东西，要删走附件删除即可 ② 「存入病历」按钮去掉（见上）
- **设计参照（2026-09-23 评审通过）**：五稿在 `docs/design/stitch/`（visit_detail_with_recording_cards / active_visit_recording_sheet / processing_state_transcribing / visit_summary_what_doctor_said / my_questions_doctor_presentation_mode）。修正点：**隐私文案统一**（"录音保存在你的设备与 iCloud 私有库；音频不进 AI"——替换稿中"仅暂存本机沙盒""不上传第三方"等旧措辞）；忽略 Stitch 自创元素（"标记医嘱重点"打点、"CoreEngine v2"、"N 重点"计数）；录音卡头/卡内标题去重；"存入病历"按钮语义实现时定

### T33 · 跨 Apple ID 共享调研（~3h，调研卡）✅ 2026-09-24
- **产出**：`docs/ck-share-study.md`——① 路线定案 ② 实施计划 + 工程量 + 迁移风险 ③ 排期建议（v1.1 或更近）+ 非技术版老板摘要
- **方法**：读社区参考实现（framara/CloudKitSharing）、核实 SwiftData/CKShare 最新支持状态（每代 iOS 复核）；demo 可选不强制
- **验收**：结论明确到"下一步怎么走"，不悬空
- **产出**：`docs/ck-share-study.md`。结论：iOS 27 SDK 里 SwiftData 仍只有 `.private`/`.automatic`/`.none`，**没有 `.shared`**（本机读接口文件核实）。定案 = **v1.0 先做半天的「最小只读导出」，v1.1 再做路线 B（SwiftData 主库 + 专门的 CKShare 通道，5–6 天，需两台真机两个 Apple ID）**；不走路线 A（换回 Core Data），那是为一个功能换地基。

### T38 · 最小只读导出（路线 C）· 新增 2026-09-24（~0.5 天，不等认证）

- **背景**：T33 定案——v1.0 不做真共享，用"只读快照"兜住"看一眼"；跨 Apple ID 的现实下，这是两人互看与发医生/家人的唯一通道（AirDrop / 微信 / 存文件，走系统分享面板）
- **做**：把一段 Journey 渲染成只读快照（PDF 或长图，CC 选型）——标题 + 时间线（各 Log 的日期/类型/标题/关键字段）+ 可选附件缩略图；用现有设计语言；导出入口位置由 CC 提方案；系统 ShareLink 分享
- **不做**：导入 / 合并 / 增量同步（v1.1 真共享范围）；音频文件不进快照（只读文字+图）
- **验收**：导出孕期 Journey → AirDrop 到另一台设备打开、排版可读；分享面板各渠道正常；文案进 String Catalog
- **学习点**：ImageRenderer / PDF 渲染、ShareLink、分享面板家族

## 阶段 2 · Apple 认证通过后

### T34 · 订阅上线配置（ASC，你手动 + CC 协助，~1h）
- $3.99/月 产品 + **首周免费试用**（Introductory Offer）+ **Family Sharing 开关**（太太共享订阅的必经路径）
- 协议/银行/税表/隐私问卷（照 `docs/owner-actions.md`）；沙盒全流程走通
- **验收**：沙盒购买 → 解释全链路；恢复购买；家庭共享在太太设备实测通过

## 阶段 3 · 内测与发布

### T35 · 内测反馈批（非卡，贯穿 M5）
- 沿用 M4-T29：每周小结；问题进 `m5-bugs.md`；backlog 按痛点挑 1–2 项进 M5.5
- **重点观察（T33 结论）**：太太的使用形态——"看一眼"（导出快照就够）vs"一起记"（需要 v1.1 真共享）——这直接决定 v1.1 的排期

### T36 · 中国区评估（~2h，调研卡）✅ 2026-09-24
- 备案 / 主体资质 / 成本 → 评估报告；决定"做 / 不做 / 何时"
- **产出**：`docs/china-assessment.md`。结论 **不做**——卡点不是钱：苹果对大陆区已开启 ICP 备案强校验（境外主体+境外服务器有例外，但不稳），更硬的是**生成式 AI 服务备案**要求境内独立法人 + 3 名专职算法安全工程师 + 3–6 个月，且模型必须是境内已备案服务。定案：只上加拿大/美国等区，国内家人用海外 Apple ID 下载；重新评估的触发条件是"真有境内用户被挡住"或"备案门槛对个人放宽"，不设时间表。

### T37 · 发布批（~6h + 审核周期）
- 素材（截图 / 描述 / 关键词）、隐私标签、审核备注、**`ALLOW_SANDBOX` 审核期保持 `"1"`**（审核员用沙盒购买——关掉 = 订阅不解锁 = 审核必挂）、**内部通道移除双保险核对**（`wrangler secret delete INTERNAL_ACCESS_KEY` + Release 产物 strings 复查）、提审 → 通过 → 上架（内测收尾后再评估 `ALLOW_SANDBOX` 改 0）→ 自己从 App Store 装正式版走真订阅
- **验收**：上架；正式环境全链路（订阅 → 解释）用真实用户路径走通

---

## 待办（你手动，详见 owner-actions.md）
1. （等认证）Xcode 登录 + 真机验证（同 Apple ID 两台设备）
2. （认证后）ASC 配置批（T34）
3. （现在就能做）`wrangler secret put INTERNAL_ACCESS_KEY` + `npm run deploy`——T30/T31 都等这一步才能在真机上跑通
4. （下次产检）真机验一次面诊录音：本地转写质量 + 中英混说 + 总结可用性（T32 验收）

## 阶段 1 收口（2026-09-24）
T30 ✅ · T31 ✅ · T32 代码完成（待真机验收）· T33 ✅ · T36 ✅。
剩下的都卡在 Apple 认证或内测本身：T34（ASC 配置）、T35（内测反馈）、T37（发布批）。

## 开工提示（每次一卡）
> 沿用既有流程：开工先复述理解 + 计划；完成后按 CLAUDE.md 收尾（构建 + 自测 + Smoke + 截图 + 改动清单 + 5 行 Swift 概念）；一次一卡，不越范围。
