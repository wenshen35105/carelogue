# M6 · 1.0 提交准备（prepare for submission）

> 定位：把 Carelogue 补到「可以提交 1.0」的状态，然后走完提交与上线。
> 结构：① 功能补完（工程卡，本文档）② 真机验收 ③ 提交与上线（执行以 `docs/owner-actions.md` 为准，不在此重复列卡）。
> 原则：测试与提审并行；发布方式手动（过审 ≠ 立即上架）。

## ① 功能补完（发布门槛）

### T39 · CKShare 真共享（直接开工 · 2026-09-25 定）

- 路线 B（SwiftData 主库 + 独立 CKShare 通道）：她装 app、接受共享后即有数据，双方改动双向自动同步；数据全在 Apple 生态，不经我们 server
- 实施计划：`docs/ck-share-study.md` 第四节（7 步，5–6 天）；参考实现 framara/CloudKitSharing——**当骨架与坑清单，不当依赖**
- 测试：双真机 × 两个 Apple ID（你的 + 太太的）；模拟器代替不了
- 已含尾巴：她的本地副本并进共享（2–3 天）
- 原 T38（只读快照 → 完整导出/导入）两版均撤销：改走 CKShare 直连，不走导出路线



## ② 真机验收

### T40 · 产检验收（下次产检）

- T32 面诊录音 + 转写真场景（中英混说，如「胎心 152，NT ultrasound」）
- 记录问题清单 → 提审前修复或进 v1.0.1
- 不因等产检而推迟提审（发布手动 = 保险闸）

## ③ 提交与上线（以 owner-actions 为准）

- 订阅产品 → Ready to Submit（Review Screenshot 上传）→ TF 内测（自己 + 太太）
- 隐私标签 / 发布素材 / Support 页（`carelogue.ca/support`）/ 提审（首次订阅随版本提交）/ 审核往复
- 上线核对：CloudKit schema Deploy、ALLOW_SANDBOX 保持开、自购真订阅、太太 ID 验家庭共享
- 首周盯盘：TF 崩溃报告 + 审核评价
