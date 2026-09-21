# CLAUDE.md — Carelogue 项目规则（给 Claude Code 的常驻说明）

## 项目是什么

Carelogue：iOS 患者就医旅程记录 app（SwiftUI + SwiftData + CloudKit）。
当前阶段：M1（项目骨架 + 数据层 + Journey/Log CRUD）。首期用户：单人自用（孕期 Journey）。

## 先读这些（按序）

1. `docs/mvp-spec.md` — 功能蓝图、页面、数据模型、AI 契约（上级文档）
2. `docs/m1-tasks.md` — 当前里程碑任务卡（**一次只做一张**）
3. `docs/product-brief.md` — 定位与原则（背景）
4. `docs/design-review.md` + `docs/design/stitch/` 三屏 PNG — UI 参照

## 技术约束（硬规则，不准违背）

- iOS 17+，SwiftUI + SwiftData；目标 = iOS 原生观感
- SwiftData 模型：所有非 optional 属性必须有默认值；**不要用 unique 约束**（UUID 手动去重）——CloudKit 兼容要求
- 附件用 `@Attribute(.externalStorage)`；不要把二进制塞进其它字段
- 颜色：accent `#D9784F` · 背景 `#F7F5F2` · 卡片 `#FFFFFF` · 主墨 `#1C1B1A` · 次墨 `#8A8680` · 边框 `#EAE6DF`
- 字体：系统字体（SF Pro + 苹方），不引入第三方字体
- 圆角：卡片 18–20pt · 按钮 12–14pt · 标签 pill 全圆
- 文案：简体中文为主，关键标题中英并排
- 不做（v1.1+ 才考虑）：账号 / 订阅 / 服务端 / Tab bar / 全局视图 / 通知

## 工作流（每张任务卡）

1. **开工前**：复述你对该卡的理解 + 计划（3–5 行）——得到确认后再动手
2. **只做卡内范围**；发现卡外问题 → 记下来报告，不要顺手做
3. **完成后自检**：
   a. 模拟器构建通过
   b. 对照卡内"验收"逐条自测
   c. 跑一遍 Smoke 清单（见下）
   d. 输出：改动文件清单（每文件一句话）+ 5 行"本卡涉及的 Swift/SwiftUI 概念"（给非 Swift 背景的 reviewer 学习用）
   e. **界面有变化时**：把模拟器跑起来，`xcrun simctl io booted screenshot docs/screenshots/<卡号>-<页面名>.png` 存 1–2 张关键界面截图（供 review 与验收留档）
4. **不要**主动重构、升级依赖、或改动数据模型（schema 已冻结；确需变更 → 停下来说明原因）

## Smoke 清单（每次提交前）

1. 启动不崩溃
2. 建一条 Journey
3. 三种 Log（就诊/随手记/测量）各建一条
4. 编辑一条 + 删除一条
5. 杀 app 重开，数据都在

## 语言

- 代码、注释、commit message：英文
- 与用户对话、交付说明：中文
