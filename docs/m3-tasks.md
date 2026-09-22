# Carelogue — M3 任务卡（explain 动作打通）

> 用法同前：一张一张来；每张卡交给 Claude Code，对照"验收"手工过一遍再开下一张。
> Spec 依据：mvp-spec.md §5（AI 动作契约）、§7（隐私与合规）。
> **前置（你来做）**：① DeepSeek API key——platform.deepseek.com 申请（按量计费，很便宜）；② 准备 1 份真实报告素材（照片 + PDF 各一，如产检报告）——**仅本地使用，不要 commit 进 repo**。
> M2 遗留参照 docs/m2-bugs.md：P3 项不排卡（顺手再修）；#3（附件大小上限）建议放 M4 打磨；#7（随手记挂附件）留待 M4 真实试用后拍板。
> 总预估：~22h。

---

## T16 · 本地化基础设施（中英，~4h）
- **做**：启用 iOS per-app 语言（系统设置 → Carelogue → 首选语言；**不做 app 内语言设置**）：
  - 工程声明 zh-Hans / en 本地化；建 String Catalog（`Localizable.xcstrings`）
  - 现有全部 UI 文案从硬编码迁入 catalog；**中文文案保留"中英并排"格式（如"设置 Settings"），英文文案为纯英文**
  - 日期/数字格式跟随 app 语言（收掉 `Theme.locale` 的硬编码）
  - 此后所有新文案必须走 catalog（CLAUDE.md 已同步规则）
- **验收**：系统设置出现"首选语言"（中文 / English）；切英文后 UI 文案无中文残留（用户数据除外）；切回中文恢复并排风格；日期格式随语言；UITest 冒烟通过
- **学习点**：String Catalog、Bundle 本地化、per-app language

## T17 · 本地文本提取（~3h）
- **做**：TextExtractor 服务：图片 → Vision OCR（VNRecognizeTextRequest，中英、accurate）；PDF → PDFKit 逐页文本提取；输出纯文本（保留页/段分隔）；失败给出明确错误
- **验收**：中英混排报告照片提取可读；两页 PDF 提取完整；空图/无文字扫描件不崩且有提示
- **学习点**：Vision、PDFKit、async 封装

## T18 · AI 服务层 + Keychain + 设置页启用（~4h）
- **做**：AIService 协议（provider 可换）＋ DeepSeek 实现（URLSession → chat/completions，要求 JSON 输出；超时/错误映射）；设置页启用最小集：**AI 总开关** + **API Key 输入**（SecureField → Keychain）+ **隐私说明**三行
- **验收**：key 填入后重开仍在（Keychain）；总开关可关；最小测试调用能拿到回复
- **学习点**：Keychain、URLSession async、协议抽象

## T19 · explain 端到端 + 缓存 + 节流（~4h）
- **做**：`explainArtifact(artifact)`：提取文本 + 最小上下文（Journey 名 + Profile 过敏/用药，设置可关、默认开）→ 调 AI（护栏 system prompt：**不做诊断、不给治疗建议、不改药量**）→ 解析校验 `{summary_plain, terms[], questions[]}` → 存 `Artifact.aiExplainJSON`；失败：超时/拒答 → "无法解释，请重试"，**不缓存空结果**；节流：同附件 5 分钟内不重复请求
- **验收**：真实报告全链路跑通、结果落库；断网/无 key 有友好错误；5 分钟内重复点不发起第二次请求
- **学习点**：结构化输出解析、错误状态、本地节流

## T20 · 解释卡 UI（~3h）
- **做**：报告详情页解释卡（照 Stitch report_explanation，浅+深色）：白话总结 / 术语 chips / "可以问问医生"列表 / 免责声明 / 底部按钮（重新解释 · 复制 · 收起）；三态：未解释（按钮）/ 生成中（加载）/ 失败（重试）
- **验收**：三态齐全；深浅色都正常；复制可用；长文本不破版
- **学习点**：视图状态、剪贴板、卡内互斥展开

## T21 · 首次使用弹窗 + 同意收回（~2h）
- **做**：首次点击"解释"弹窗（每设备一次）："提取的文本将发送至模型服务用于解释；不存储、不用于训练" → 同意 / 拒绝；设置里可收回同意（收回后 AI 入口禁用）
- **验收**：每设备仅弹一次；拒绝后本地功能不受影响；设置里可收回
- **学习点**：AppStorage、同意状态流

## T22 · M3 验收走查（~2h）
- **做**：走查 spec A2（上传真实报告 → 解释 → 白话总结 + 术语卡 + 问题清单）；核对护栏输出（无诊断/用药建议）；UITest 增补（注入假 provider 测 UI 三态，真实调用留手测）；bug 清单
- **验收**：A2 全通；**把解释结果给太太读一遍，她能看懂**
- **产出**：M3 bug 清单

---

## 开工提示（每次一卡）
> 沿用既有流程：开工先复述理解 + 计划；完成后按 CLAUDE.md 收尾（构建 + 自测验收 + Smoke + 改动清单 + 截图存档 + 5 行 Swift 概念）；一次一卡，不越范围。
