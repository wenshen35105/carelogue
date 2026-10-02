# M7 · v1.0.1（自用反馈修补批 · 草案 2026-09-30）

> 来源：`docs/backlog.md`「2026-09-30 自用反馈（6 条）」。
> 定位：1.0 过审后的第一个小版本，只修真实使用中卡手的地方；**不改 schema**（6 条已核对，全部落在现有字段上）。T48 为做 T47 时发现的共享同步 bug，并入本批。
> 流程：一次一卡；开工先复述理解 + 计划，确认后动手；完成后按 CLAUDE.md 收尾。

## Schema 核对（2026-09-30）

| 反馈 | 现有字段 | 结论 |
|---|---|---|
| 就诊记具体时间 | `Log.occurredAt: Date` | 已是完整时间戳，仅就诊编辑器 `DatePicker(displayedComponents: .date)` 截掉了时分 |
| 测量备注 | `Log.note`（`save()` 测量分支已写入） | 编辑器没给测量分支放备注输入框 |
| 地点/医生联想 | `Log.location` / `Log.doctor` | 从已有记录 distinct 取值即可 |

---

## 小卡（UI 级，各 ≤ 半天）

### T42 · 就诊记录支持具体时间 ✅ 2026-10-01
- 就诊编辑器 `日期` → `时间`，`DatePicker` 放开时分（与随手记/测量一致）
- 时间线 / 详情页的就诊日期展示补上时间（跟随 app 语言格式）
- 旧数据：原来只选日期的记录，时分是创建时刻——不做迁移，照常显示
- **验收**：新建就诊选 14:30 → 时间线、详情显示 14:30；编辑可改；UI 测试覆盖
- **落地**：就诊编辑器「时间 · 就诊时间」日期+时分；时间线就诊行、「下次 · 面诊」卡、首页下次就诊均显示时分（详情页本来就有）；`LogEditorUITests.testVisitRecordsATime`（滚轮选 14:05 → 时间线与详情可见）

### T43 · 测量记录可加备注
- 测量编辑器加 `备注` 区（同就诊样式）；详情页测量分支显示备注（若已有则只核对）
- **验收**：建测量带备注 → 详情可见 → 编辑可改；UI 测试覆盖

### T44 · 白话解释不再显示模型名 ✅ 2026-09-30
- 去掉 `ExplanationCard.modelPill`；标题统一为「白话解释 / AI Explained」
- 顺查面诊总结（`VisitSummaryView`）等处有无同类露出，一并去掉
- `model` 字段照常存（排障用），只是不展示
- **验收**：解释卡、总结卡无模型名；截图过目
- **落地**：`ExplanationCard` 删 `modelPill` + 其换行布局，标题恒为「白话解释（AI 生成）· AI Explained」；`ExplainUITests` 断言无模型名；UI 全套浅/深各 53 过（2 条真连 relay 跳过）；截图 `docs/screenshots/T44-explanation{,-dark}.png`

### T45 · 地点 / 医生联想输入（type-ahead）
- 数据源：本库所有就诊 Log 的 `location` / `doctor`，去空、去重，按最近使用排序
- 交互：输入框聚焦时在下方列出候选（空输入 = 最近 N 个；有输入 = 前缀/包含匹配），点选填入；仍可自由输入新值
- 范围：**全库**（不限当前旅程，2026-09-30 定）——同一家医院/医生常跨旅程
- 共享旅程：候选含共享进来的记录（同一 SwiftData 库，自然包含）
- **验收**：第二次建就诊能点选上次的地点和医生；UI 测试覆盖

---

## 大卡

### T46 · 录音中可离开录音页 + 后台录音（~1–1.5 天）
- 现状：录音页是 `fullScreenCover`，录音时出不去；也没开 `UIBackgroundModes: audio`，锁屏/切 app 即中断
- 方案：
  1. 录音器提升为 app 级单例（不再属于某个 Log 的卡片）
  2. 录音页可收起 → 全局**迷你录音条**（计时 + 暂停/停止 + 点开回全屏），收起后可自由浏览 journey、翻「我的疑问」
  3. 开 Background Modes → Audio；处理中断（来电/Siri）：暂停并在恢复后提示继续
  4. 停止录音后回到对应就诊 Log 走原有转写流程（录音与 Log 绑定在开始时确定）
- 边界：同一时间只允许一条录音；录音进行中删除该 Log → 先拦截确认
- **验收**：录音中收起 → 打开另一旅程、翻疑问页 → 回来继续；锁屏 1 分钟录音不断；来电后可恢复；UI 测试覆盖收起/展开（后台与来电真机验）

### T47 · 面诊录音转写质量 ✅ 2026-10-01（余真机复核）
- 现状：录音 AAC 24 kHz / **24 kbps** 单声道、session mode `.spokenAudio`；转写全在设备上——iOS 26+ `SpeechAnalyzer`，以下 `SFSpeechRecognizer`（on-device）；locale 按 app 语言**单选** zh-CN / en-CA
- 已知（2026-09-30）：设备 iPhone Air / **iOS 27** → 走的是 `SpeechAnalyzer` 分支；**原录音人耳听得清**（有距离感）→ 问题主要在识别环节，不在采集
- 嫌疑（按可能性）：
  1. 中英混说用单一 locale（zh-CN）识别，英文术语全部变乱码
  2. `SpeechTranscriber` preset / 选项（`.transcription` vs 带 volatile/alternatives 的配置）、是否对远场音频做了预处理
  3. 24 kbps 对人耳够、对识别器偏低（次要，需数据证实）
  4. 喂给 AI 的转写是否完整（长录音分段/截断）
- 步骤：
  0. ✅ 2026-09-30 **先做「分享录音」**：app 装自 TestFlight，取不出容器 → 录音卡长按菜单加「分享录音 / Share Recording」（系统分享面板，可 AirDrop；同时附带当时的转写原文 .txt）。是正式功能（Release 可见），用户也可自留原音；先单独出一个 TF 构建拿到样本
     - **落地**：录音卡播放条右侧分享按钮（`recording.share`）→ 临时目录写 `<原文件名>.m4a` + 同名 `.txt` 转写 → `SharePresenter.presentFiles` 弹系统分享面板，关闭后清临时文件；`VisitRecordingUITests.testRecordingCanBeShared`；UI 全套浅/深各 54 过；截图 `docs/screenshots/T47-*.png`
  1. **拿原录音离线复现**：老板用上面的入口把那次录音 + 转写原文 AirDrop 到 Mac → `scripts/` 下写个 macOS 命令行小工具，用同一套 `SpeechAnalyzer` 跑多种配置（zh-CN / en / 双 locale 分段、不同 preset），出转写对比表——不用来回装机
     - **结果（2026-10-01，`scripts/t47-transcribe-bench.swift`，Mac 上 SpeechAnalyzer，与 app 同一引擎）**：
       | 录音 | zh-CN（app 现状） | en-US | 粤语 zh-HK |
       |---|---|---|---|
       | 9/30 真实面诊（5:29，医生说英文） | 乱码，置信度 0.49 | **逐句可读**，0.82 | 乱码，0.50 |
       | 合成中文夹英文术语（`say -v Tingting`） | 可读（术语有误），**0.89** | 空，0.02 | 0.67 |
     - **根因**：不是录音质量，是**识别语言选错**——app 按界面语言选 zh-CN，而加拿大医生说英文。码率 / session mode 无需改
     - 置信度（`transcriptionConfidence`，按字符加权平均）两个方向都能清楚区分语言 → 可自动判断
  2. ✅ **改 app**：
     - **自动判断语言**：`VisitTranscription.transcribe(fileURL:with:)`——录音开头 60 秒按 zh-CN / en-CA 各识别一遍，取置信度高者（平手取 app 语言）转写全程；≤ 90 秒的录音直接整段各跑一遍。界面语言只决定 AI 整理的输出语言
     - **质量闸**：胜出语言置信度 < 0.6 → 保留转写、不自动送 AI，卡片提示「转写把握不高…」，用户可手动「整理这次面诊」
     - **重新转写**：录音卡「⋯」菜单（分享录音 / 重新转写），确认后清掉旧转写与整理并重跑——9/30 那条记录靠它修复
     - 验证：真实 `VisitTranscriber.swift` 在 Mac 上编译跑 9/30 原录音 → 选中 en-CA、0.82、5258 字；中文样本 → zh-CN、0.89。UI 测试：`testRetranscribeDetectsTheVisitLanguage` / `testLowConfidenceTranscriptWaitsForTheUser`（假转写器按语言给置信度）
     - 无单元测试 target（加 target 要大改工程文件），语言挑选逻辑由 UI 测试经假转写器覆盖
- 隐私：原录音只在本机/你的 Mac 上处理，**不进 repo**（`build/` 或 scratchpad 下，已 gitignore）
- **验收**：同一段原录音，转写可读性明显提升（附前后对比）；低质量转写有提示
- **待真机复核（老板）**：装 1.0.1 后打开 9/30 那次面诊 →「⋯ → 重新转写」→ 转写为英文、整理正常；分享录音应为 2 个项目（m4a + txt）

### T48 · 共享同步把转写 / 解释写回空值（2026-10-01 发现，卡外 bug 并入本批）✅ 2026-10-01（余真机复核）
- **现象**：9/30 共享旅程里的面诊，AI 整理在、转写原文没了（分享录音只出 m4a，无 txt）
- **根因**（T39 `ShareChannel`）：一轮同步 = pull（存 change token）→ push；push 写上去的记录在**下一轮 pull 里作为"远端变更"回来**（回声）。录音一存就随空转写上传；转写稍后写入本地；下一轮 pull 拿到自己上传的旧版（transcript = nil），附件不比较时间戳 → 覆盖本地。白话解释（`aiExplainJSON`）同理会丢
- **修复**：记住本机保存成功的记录的 `recordChangeTag`（UserDefaults，按 zone）；pull 遇到 tag 完全一致的记录 = 自己的回声 → 跳过；tag 不同 = 别人在我们之后写过 → 照常应用。`clearToken` 一并清除
- **验证**：模拟器无 CloudKit，只做了构建 + 全套 UI 测试回归；**需双机复核**：共享旅程里新录一段 → 等转写完成 → 两台设备都能看到转写（分享出 2 个项目）；解释一张附件 → 对方可见、本机不丢

---

## 不在本批

- **T39 尾巴「受邀方本地副本并进共享」——不做（2026-09-30）**：只影响 CKShare 上线前就各自建过同一条旅程的人（实际只有太太的内测数据），新用户不会遇到；太太手动处理即可（她本地那条要么删掉、要么留着当私人旅程）。降级回 backlog，等真有用户反馈再说
- 版本号：✅ 2026-10-01 已改 `MARKETING_VERSION` 1.0.1 / build 1（首个 TF 构建用于 T47 取录音样本）

## 建议顺序

T44 → **T47 第 0 步「分享录音」**（早出 TF 构建才能拿到样本）→ T42 → T43 → T45 → T47 调研与修复 → T46
