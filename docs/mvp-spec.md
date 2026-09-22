# Carelogue — MVP Spec v0.1

> 基于 product-brief v0.2 的术语与原则。
> 状态：**v0.1 定稿**（2026-09-16）。技术栈已定：iOS 原生（SwiftUI + SwiftData + CloudKit）；AI：DeepSeek + 本地 OCR。

## 1. MVP 定义（一句话）

一个人、一台设备、一条真实 Journey 全流程跑通：**创建 → 记录 → 上传 → 解释**。

## 2. 验收标准（拿它验收，不写"完成度"这种虚词）

- A1：创建"孕期"Journey → 三种 Log（就诊 / 随手记 / 测量）各至少记录 2 条
- A2：上传 1 份真实报告（照片或 PDF）→ 点"解释" → 得到：白话总结 + 术语卡 + 该问医生的问题
- A3：产检当天，从预约到拿到报告，全流程不离开 app
- A4：不需要任何教程；从启动页到任意核心功能 ≤ 3 次点击

## 3. 页面与流程（3 + 1 个页面）

**P1 · Journey 列表（启动页）**
- 空状态 = Onboarding：wizard 两步（命名 → 选模板[孕期 / 拔牙 / 自定义]）
- 列表项：名称 · 状态（进行中/已完成）· 最近活动 · Log 数
- ＋ 新建 Journey

**P2 · Journey 时间线（核心页）**
- 按时间倒序的 Log 卡片流；图标区分 kind，卡片占一行：
  - 就诊：类型 + 日期 + 地点（"面诊 · 10/3 · 圣迈克医院"）
  - 随手记：首行文本（"晚上又开始腰酸"）
  - 测量：**默认折叠进"测量"分组卡**（"测量 ×12 · 最近 68.5 kg"），点开是列表/简单曲线——不刷屏
- 右上 ＋ → 三选一（就诊 / 随手记 / 测量）
- 顶部菜单：编辑 Journey · Profile 入口

**P3 · Log 编辑器（新建/编辑共用）**
- 就诊：类型 chips（面诊/体检/验血/影像/其他）· 日期 · 地点/医生（可选）· 备注 · 附件区（照片/PDF；每份附件一个 [解释] 按钮）
- 随手记：类型（症状/情绪/备注）· 时间 · 文本框——**打开即聚焦键盘，3 秒记完**
- 测量：类型（体重/血压/体温/自定义）· 数值 + 单位 · 时间
- 所有字段可选；**保存即记录**（无"暂存/草稿"态）

**P4 · Profile（全局档案）**
- 4 个自由文本域：过敏与不良反应 / 长期用药 / 疫苗记录 / 既往病史与手术史
- 说明行："只存本机；用于让 AI 解释更准确；可随时清空。"

## 4. 数据模型（本地，一张主表打天下）

```
Journey
  id · name · template(孕期/拔牙/自定义) · status(active/done) · created_at · updated_at

Log                                  ← 三种 kind 共用一张表
  id · journey_id · kind(encounter|quick|measurement)
  type(面诊/体检/验血/影像/症状/体重/血压/…) · occurred_at · note(null)
  meta JSON(null; 如 {location, doctor} / {intensity} / 其他)
  value REAL(null) · unit TEXT(null)      ← measurement 用
  created_at · updated_at

Artifact
  id · log_id · file(外部存储引用) · mime · created_at
  ai_explain JSON(null)   ← {summary_plain, terms[], questions[], model, created_at}

Profile（单行）
  allergies · medications · vaccines · history · updated_at
```

- 附件文件存 app 沙盒 + `@Attribute(.externalStorage)`（随 CloudKit 自动同步）
- **没有任何服务端**；AI 解释结果缓存在 Artifact.ai_explain（重解释可覆盖）

## 5. AI 动作契约（MVP 只做一个动作）

**`explainArtifact(artifact)`**

- 输入（客户端组装，无状态）：
  a) 附件 → **本地提取文本**：照片走 iOS Vision OCR（中英）；PDF 走 PDFKit 提取。**图像本身不离开设备**，只有提取出的文本随请求发出（备选：DeepSeek 侧已有 OCR 能力——订阅阶段再评估是否由 provider 端处理图像；MVP 先本地，隐私与成本双赢）
  b) 最小上下文：Journey 名称（如"孕期"）+ Profile 的「过敏」「用药」两栏（设置可关，默认开）
- 输出（结构化 JSON，便于校验与渲染）：
  ```json
  { "summary_plain": "…", "terms": [{"original": "…", "plain": "…"}], "questions": ["…"] }
  ```
- 护栏：system prompt 明确"不做诊断、不给治疗建议、不改药量"；展示前固定附免责声明；不做多轮对话（MVP）
- 模型调用封装在服务层接口后（将来换/加视觉模型只改一处）
- 失败处理：超时/拒答 → "无法解释，请重试"；不缓存空结果
- 重试成本控制：同一附件 5 分钟内不重复计费（本地节流）

## 6. 文案与双语

- **语言机制**：iOS per-app language（系统设置 → Carelogue → 首选语言），**不在 app 内做语言设置**；支持 zh-Hans / en
- 所有 UI 字符串进 String Catalog（`Localizable.xcstrings`），禁止硬编码；**中文文案保留"中英并排"格式**（如"设置 Settings"），**英文文案为纯英文**
- 日期/数字格式跟随 app 语言（不再硬编码 zh_Hans）
- 术语词典（开发用）：Journey 旅程 / Log 记录 / Encounter 就诊 / Quick Log 随手记 / Measurement 测量 / Artifact 文档 / Profile 档案 / Summary Card 摘要卡

## 7. 隐私与合规（MVP 版）

- 全部本地；**自用阶段无账号、无服务器、无订阅**——客户端直连 DeepSeek API，key 存 Keychain
- 首次使用 AI 时弹窗说明："提取的文本将发送至模型服务用于解释；不存储、不用于训练"（每设备一次，可在设置收回）
- 免责声明固定显示在解释结果下方

## 8. 非目标（MVP 明确不做）

账号 / 订阅 / 服务端 / 云端同步（iCloud 同步 = SwiftData+CloudKit 天然自带）/ 共享与导出 / 提醒 / 跨记录问答 / 面诊录音 / 找医生 / Android / Web / 自动导入医院数据

## 9. 技术栈（已定）

- **平台**：iOS 原生（iOS 17+）· SwiftUI + SwiftData
- **同步**：SwiftData + CloudKit 私有库——夫妻同 Apple ID 零成本自动同步；跨账号（父母）留给 v1.1 的 CKShare / 导出
- **附件**：SwiftData `@Attribute(.externalStorage)`——附件文件自动进 iCloud 同步，不写同步代码
- **OCR**：iOS Vision（VNRecognizeTextRequest，中英）；PDF：PDFKit 文本提取
- **AI**：DeepSeek API（客户端直连）；key 存 Keychain；服务层接口封装（可换 OpenAI / Claude）

**写代码前先记住的坑：**
- SwiftData + CloudKit：所有非 optional 属性必须有默认值；不支持 unique 约束（用 UUID 手动去重）
- 附件依赖 externalStorage 自动外置，别把文件塞进 JSON 字段
- 图像处理：MVP 一律本地 OCR（Vision）成文本再发送；DeepSeek 侧已有 OCR/视觉能力，订阅阶段再评估 provider 端方案

**分发与自用（MVP 阶段，无需发布）：**
- 完全支持"不发布、先自用"：**付费账号（$99/年）+ Xcode 直连两台 iPhone 安装**（签名 1 年有效）即可；想频繁更新再上 TestFlight（build 90 天轮换；夫妻同 Apple ID，两台机都可装）
- **$99 购买时点 = 开 CloudKit capability 时**（免费签名不支持 iCloud/CloudKit）——即同步上线前，而不是"上架前"
- 不上架 = 不需要审核 / 隐私标签 / 隐私政策；将来若想"给亲友用但不公开"，备选 Unlisted App（隐形上架）

## 10. 里程碑（按每周 5–10 小时估）

| 里程碑 | 内容 | 预估 |
|---|---|---|
| M1 | 项目骨架 + 数据层 + Journey/Log 的 CRUD | ~20–30h |
| M2 | 附件上传/展示 + 测量分组与简单图表 | ~15h |
| M3 | explain 动作打通（含护栏、缓存、节流） | ~15–20h |
| M4 | 双语文案 + 打磨 + 真实数据试用（太太孕期旅程） | ~15h |
| 合计 | | **~65–80h ≈ 10–16 周** |

## 11. 阶段与架构演进（AI 服务）

| | 阶段 1 · 自用（当前，M1–M4） | 阶段 2 · 公开 / 订阅（M5+ 规划） |
|---|---|---|
| 用户 | 你与太太（自己人） | 公众用户 |
| AI 接入 | **BYOK**：设置页填自有 DeepSeek key（Keychain 保管） | **我们的无状态转发 server**：用户不接触 key |
| 账号 / 计费 | 无账号、无计费 | App Store **IAP 订阅**（Guideline 3.1.1） |
| 发布方式 | 不发布（Xcode 直装 / TestFlight 内部） | App Store 上架 |
| 合规件 | 机内同意弹窗（已设计） | + 隐私政策、服务条款、数据流披露 |

- 两阶段**共用同一客户端代码**：AI 服务层为协议抽象（provider 可换）；阶段 2 只替换 provider 实现（直连 → 走自家 server），设置页"AI 区"由"API Key 管理"演进为"订阅状态管理"，UI 骨架不动
- 直连第三方 API **不存在审核障碍**（iOS 允许，HTTPS 即可）；"请求必须经自家 server"**不是**苹果规则——阶段 2 走 server 是设计选择（计费入口、key 托管、输出管控、隐私中间层）
- 小注：Keychain 不跨设备同步——太太的 iPhone 首次也需各填一次 key（如共用同一把）
- **商业模型（已定案 2026-09-22）**：阶段 2 = 免费下载（本地记录永远可用）+ 订阅解锁全部 AI 功能（一个订阅全包；不做买断/分层——买断与 AI 持续成本不匹配）。定价量级 ~$4.99/月。用户试用期长度 M5 再定
- **路线修订（2026-09-22）**：内部自用验证调整到 Subscription 骨架之后、以订阅形态进行（不单独做 BYOK 试用阶段）；BYOK 在订阅版上线时自用户界面移除（服务层抽象保留，供内部调试）
- **AI 服务商遴选与变更纪律**（落实"数据由我们负责"）：
  - 遴选标准 = API 默认不用于模型训练（条款级）+ 明确保留政策（30 天内删除级）+ 覆盖全部 AI 功能
  - **承诺绑定在"遴选纪律"而非某家条款上**：服务商条款变更 → 评估并替换（自用 BYOK 阶段需重填 key；订阅版 server 中继下替换对用户无感）；发布后变更需通知用户
  - 阶段 2 前必须满足标准；自用阶段可先行切换。备注：现用 DeepSeek API 不满足标准（无文档化 opt-out、条款未豁免开发者输入）

## 决策记录（2026-09-16）

- 设备：夫妻均为 iPhone → iOS 原生成立
- 技术栈：SwiftUI + SwiftData + CloudKit
- AI：DeepSeek；MVP 图像不进模型（本地 OCR 后发文本），订阅阶段再评估 provider 端 OCR
- 开发分工：代码由 dev bot（Claude Code 在 Mac 上）实现；老板做 review、逐步 pick up Swift
