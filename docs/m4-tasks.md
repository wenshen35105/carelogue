# Carelogue — M4 任务卡（真机化 + 真实试用）

> 目标：① 真机化（CloudKit + 两台 iPhone，T23–T25）；② 做出 Subscription 版 → 以订阅形态内部自用、打磨 → 公开发布。
> 前置（你手动）：① Apple Developer Program（$99/年，见 T23 第 1 步）；② 两台 iPhone + Mac。
> 讨论结论（2026-09-22）：账号已买；AI 文案走"责任版"（服务商遴选纪律见 spec §11)；"暂不使用"保持现状；商业模型=订阅（见 spec §11）。
> **Subscription 定案（2026-09-22）**：AI 服务商 = **DeepInfra**（DeepSeek-V4-Flash 开源版，$0.09/$0.18 每 M tokens，默认不落盘；备选 Fireworks）；Server = **Cloudflare Workers**（serverless，仅 CPU 计费）；**无账号系统**——订阅校验走 StoreKit Transaction JWS 无状态验签（server 零用户库）；定价 $3.99/月（2026-09-23 修订）；BYOK 在订阅版上线时自用户界面移除（服务层抽象保留，供内部调试）。
> 总预估：~24h + 内测期。

---

## T23 · CloudKit 开通 + 双机同步（~4h）★ 先做这个

**你（手动）**：
1. developer.apple.com/programs → Enroll（**个人**身份即可，$99 USD/年；开通可能需 24–48h 或身份验证）
2. 开通后：Xcode → Settings → Accounts 登录该 Apple ID
3. 在两台 iPhone 上各 Run 一次 app（Xcode 直装；签名 1 年）
**CC（工程）**：
4. 给 app 加 iCloud/CloudKit capability 与容器；`ModelConfiguration` 打开 CloudKit（private 库）
5. 复查 SwiftData 兼容三件套（默认值 / 无 unique / 关系可选——M1 已按此写，复核）
6. 双机验证：A 机建记录 → B 机同步可见；附件（照片/PDF）同步；断网补传；两机同 Apple ID
**验收**：两台真机数据互见（含附件）；杀 app 重开一致；无异常冲突提示
**注意**：开启 CloudKit 后 **schema 冻结真正生效**——改模型需迁移策略（两台设备代价可控，仍按"停下来说明"处理）
**学习点**：iCloud 容器、capability、SwiftData 同步配置

## T24 · 真机批次（~3h）
- **做**：相机直拍入口（就诊编辑器附件区加"拍照"；真机验证，模拟器不可测）；真机观感/手势走查（字体、手感；性能：多附件 + 长列表）
- **验收**：真机拍照 → 保存 → 预览全通；无明显卡顿
- **学习点**：相机权限、真机与模拟器差异

## T25 · 打磨批（~5h，纯代码、不依赖账号，等待期可先跑）
- ① **AI 服务商切换（待拍）** → 新 provider 实现 + 全用例回归；AI 披露文案改**责任版**（"我们只选用承诺不用你的数据训练的 AI 服务"——措辞随 provider 定稿）
- ② 设置页"清空所有数据"（显式逐层删除，M2 教训；二次确认）
- ③ 时间线卡片内嵌解释摘要（design-review 采纳项）；设计参照 `docs/design/stitch/journey_timeline_with_ai_summary/`——只取"AI 摘要"行元素（muted 小条+箭头），其余卡片（里程碑/每日寄语等）忽略
- ④ 英文修漏 + P3 顺手清（附件上限 #3、Form 深色 #2、chip 遮挡 #12 等，对照 m2/m3-bugs）
- **验收**：各条自测 + UI 测试全绿；文案对照复核

## T26 · 转发 server（Cloudflare Workers，~5h）
- **做**（`server/`，同 repo）：`/v1/explain`（接收文本 + 订阅 JWS → 验签 → 转发 DeepInfra 流式 → 透传；无日志、不落盘）；基础限流（匿名设备 ID + IP）；wrangler 配置 + `api.carelogue.ca` 自定义域 + secrets
- **你手动**：Cloudflare 注册 + Mac 上 `wrangler login`（一次性浏览器授权）
- **验收**：本地 `wrangler dev` 打通 → 部署后真机测；流式、延迟、错误映射；确认无数据落盘
- **学习点**：边缘函数、流式代理、secrets 管理

## T27 · iOS 订阅接入（StoreKit 2，~4h）
- **做**：订阅页（$3.99/月，产品建在 App Store Connect）；购买/恢复/管理入口；Transaction JWS 随解释请求附带；AI 功能门控（未订阅 → 引导订阅；订阅 → 全开）；StoreKit Testing 本地跑通 + 沙盒
- **设计参照**：`docs/design/stitch/carelogue_plus_paywall/`、`report_view_not_subscribed/`——注意：**锁只作用于解释卡**，附件/记录本身保持免费；权益文案用通用表述（**不点名未规划功能**——设计稿里的"双语病历梳理/随访助理"删）；"DIGNIFIED CARE" pill 可略
- **验收**：沙盒购买 → 解释全流程；退款/过期降级不崩
- **学习点**：StoreKit 2、订阅生命周期

## T28 · 合规件 + 设置页订阅区（~3h）
- **做**：设置页"AI 区"改造（BYOK 移除 → 订阅状态 / 恢复购买 / 管理订阅）；隐私政策 + 服务条款（文本 + carelogue.ca 托管页，app 内链接）；AI 披露"责任版"按定案服务商定稿；同意弹窗文案更新（订阅语境）
- **设计参照**：`docs/design/stitch/settings_subscribed/`——订阅卡三行结构照用；"Family Care Tier"、版本号等 Stitch 自创元素忽略；**全部文案以本卡"责任版"定稿为准**（设计稿中"端到端加密"、旧服务商名已过时）
- **验收**：App Store 审核要素自检（AI 披露、隐私政策 URL、恢复购买）
- **学习点**：App Store 合规要素

## T29 · 内测期（订阅形态自用，1–2 周，非卡）
- 你与太太走"订阅（沙盒/正式）"全流程；观察：解释质量（vs 原 DeepSeek）、延迟、计费流程、记录习惯
- 每周一版小结；问题进 `m4-bugs.md`
- **公开前的最后一关**：自用打磨满意 → M5 公开发布（上架素材 / 审核）

---

## 待办清单（你手动，按顺序）
1. **DeepInfra**：注册 + 充值（$5–10 起）→ 生成 API key → **存 Mac 本地**（不进 git、不发聊天）；部署时设进 Cloudflare secrets
2. **Cloudflare**：注册（免费）→（可选）顺手注册域名 carelogue.ca（~$12–15/年）；开发时在 Mac 上 `wrangler login`
3. **Apple**：App Store Connect 三查——① Paid Apps 协议 ② 银行 + 税表 ③ 建 app 记录（bundle ID）
4. （发布前）联系邮箱、法律主体信息 → 到时一起定

## 开工提示（每次一卡）
> 沿用既有流程：开工先复述理解 + 计划；完成后按 CLAUDE.md 收尾（构建 + 自测验收 + Smoke + 截图 + 改动清单 + 5 行 Swift 概念）；一次一卡，不越范围。
