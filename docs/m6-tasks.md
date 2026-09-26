# M6 · Beta → 发布（v1.0 上架冲刺）

> 定位：把 Carelogue 从「已装上真机的 beta」带到「App Store 上架」。
> 承接：M5（T30–T38）已完成评审；ASC 记录 / 协议 / 税务 / 小企业计划进行中。
> 原则：**测试与提审并行；发布方式用手动**（过审 ≠ 立即上架，手动点发布当保险闸）。

## T39 · TestFlight 内测批

- 订阅产品元数据收尾 → 达到 **Ready to Submit**：
  - **Review Screenshot**（即 T27-paywall 新版，$3.99 当前版）上传 ← 多半就是卡住"TF 里看不到订阅"的那一项
  - 状态核对：若为 "Missing Metadata"，逐项补齐后保存即变 Ready to Submit
- **TF 中测订阅的先决条件 = 产品达到 Ready to Submit**（不需要等审核、不需要提审）
- 内测组：自己 + 太太；清单：记录 → 报告 → AI 解释 → 面诊录音 → 总结 → 疑问翻译 → 订阅购买 / 恢复购买
- 注意：TF 购买走沙盒后端、**加速过期**（1 周试用 ≈ 几分钟）；与本地 Sandbox 不同，**TF 的购买不能清除**——用真 Apple ID，不扣钱
- **家庭共享在 TF / sandbox 一般验证不了** → 留到上架后验（T44），TF 里看不到共享入口属正常

## T40 · 真机验收（下次产检）

- T32 面诊录音 + 转写真场景：中英混说（如「胎心 152，NT ultrasound」）
- 记录问题清单 → 有则进 v1.0.1 批
- 与 T43 并行：不因等产检而推迟提审

## T41 · 发布素材收尾

- 支持页 `carelogue.ca/support`（新建，Cloudflare 静态页——ASC 必填 Support URL）
- 描述 / 副标题 / 关键词；类别建议：**主 Health & Fitness、副 Medical**（可改）
- 设备支持：建议先 **iPhone-only** 上架（iPad 适配放 v1.1）
- 截图全套（ScreenshotUITests 流程）+ 推广图（`promo-image-prompt.md` 出图）

## T42 · 隐私标签（App Privacy）

- 定位：不收集、不追踪、无账号；AI 转发为实时处理、不保留 → 按 Apple 对 "collect" 的定义逐项核对
- 与 `docs/legal/` 隐私政策逐条一致性核对（含音频本地转写、图像本地 OCR 口径）

## T43 · 提审批

- **首次订阅须随版本提交**：版本页 In-App Purchases and Subscriptions 区勾选；Review Notes 草稿已备（见 owner-actions 会话记录）
- 提审 → 处理审核往复（预留 1–2 轮）
- **发布方式：手动**（完成 T44 核对后再点发布）

## T44 · 上线核对批（含首周盯盘）

- CloudKit Console：Development schema **Deploy 到 Production**（发布前必做）
- `ALLOW_SANDBOX` 保持 `"1"`（审核员用沙盒购买）；上架后视内测收尾再评估
- 自购一次真订阅走全链路；太太 Apple ID 验证家庭共享生效
- server 健康 / DeepInfra 用量与成本 check；首周：TF 崩溃报告 + 审核评价

## 卡外储备（M7 候选）

- CKShare 桥接（跨 Apple ID 真共享）、导出 / 导入合并、iPad 适配、增长实验
- 中国区：已有结论（不做），维持
