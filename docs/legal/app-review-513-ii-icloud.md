# 5.1.3(ii) 与 iCloud 健康数据 — 核实笔记（2026-10-11）

> 起因：CC 提出「审核条款 5.1.3(ii) 写明不可把个人健康信息存 iCloud」——核实结果如下。

## 条款原文（官方，2026-10-11 核实）

> **5.1.3(ii)** Apps must not write false or inaccurate data into HealthKit or any other medical research or health management apps, **and may not store personal health information in iCloud.**

**存在属实。** 它挂在 5.1.3「Health and Health Research」下；句中主语是 "HealthKit or any other medical research or health management apps"（宽于 HealthKit、窄于全部 app），且只写了 "iCloud"，未点名任何 API、未区分「用户自己的 iCloud」与「开发者可访问的云」。

## 关键结论：适用范围未定（Apple 从未公开澄清）

该条是否覆盖「第三方 app 自己的 CloudKit 私有库」——Apple 没有任何公开表态：
- 两份 Apple 自家材料指向相反：隐私标签词汇表把 Health 定义为 "any other user provided health or medical data"（偏宽）；CloudKit 文档将 Health 列为可用加密字段的 app 之一（偏窄）。
- 开发者论坛原样提问（thread 653141）——零回复；App Review 不上论坛。
- 第三方博客的「CloudKit 即 iCloud 即禁止」断言均无一手依据。

## 实践先例（在架、可更新）

- **Bloom Private**（经期追踪）、**BabyRo**（婴儿记录，形态与我们几乎一致）等：明确宣传「通过用户自己的 iCloud 同步」、隐私标签 Data Not Collected——正常在架。
- **Catalogue 自己**：1.0（含 CloudKit 同步 + CKShare，review notes 中已写明）**已过审上架**——最直接的实践证据。

## 对我们的结论

- 架构（数据在**用户自己的** iCloud 私有库、开发者零接触、无服务器）**处于先例中的安全形态——不改**。
- **T54（HealthKit）开工时**需单独评估：从 HealthKit **读入**的数据是该条款最直接的语境，同步策略要过一遍（见 m8 T54 卡内注意项）。
- 如未来审核据此发难：引用本 app 已上架先例 + review notes 表述申诉；必要时再走 App Review 书面咨询（**不提前主动问**——已上架、无实际问题，主动问反而可能引来注意）。

来源：developer.apple.com/app-store/review/guidelines/（5.1.3）；github.com/jirigrill/eczema-helper/issues/675（2026-08 一手研究，含在架先例清单）。
