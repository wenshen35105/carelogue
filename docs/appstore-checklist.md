# Carelogue · App Store 审核要素自检（T28）

> 对着 App Review Guidelines 里与本应用有关的条目逐项过。✅ = 代码/文档里已经落地；
> ⏳ = 等你手动完成（账号、域名、素材）。M5 上架前再整体复核一次。

## 订阅（Guideline 3.1.1 / 3.1.2）

| 项 | 状态 | 落点 |
|---|---|---|
| 应用内购买走 StoreKit，不绕过 | ✅ | `SubscriptionService`（StoreKit 2），无任何外部支付入口 |
| 订阅页写明：名称、时长、价格 | ✅ | `PaywallView`：Carelogue Plus · 按月 · 价格取自 App Store（`displayPrice`，不硬编码）|
| 写明自动续订与扣款方式 | ✅ | 订阅按钮下方："由 Apple ID 账户扣款，确认购买后立即生效；到期前可随时在 App Store 账户里取消。" |
| 订阅页可直达隐私政策与使用条款 | ✅ | `PaywallView` 页脚两个链接 → `LegalLinks` |
| 提供「恢复购买」 | ✅ | 订阅页页脚、设置页订阅卡、未订阅解释卡各一处 |
| 提供「管理订阅」入口 | ✅ | 设置页订阅卡 → `apps.apple.com/account/subscriptions` |
| 订阅只锁增值功能，核心功能免费 | ✅ | 锁只作用于生成新解释：记录 / 附件 / 预览 / 导出 / 已生成的解释都不受影响（`ExplanationCard` 的 locked 分支 + `SubscriptionUITests`）|
| App Store Connect 建好订阅产品与本地化 | ⏳ | 产品 id `com.jiajinlinpersonalteam.Carelogue.plus.monthly`（与 `wrangler.toml` 的 `PRODUCT_IDS` 一致）|
| Paid Apps 协议、银行与税表 | ⏳ | App Store Connect |

## 隐私（Guideline 5.1）

| 项 | 状态 | 落点 |
|---|---|---|
| 隐私政策链接在 App 内可达 | ✅ | 设置页页脚、同意弹窗、订阅页 |
| 隐私政策托管在可访问的 URL | ⏳ | `docs/legal/privacy-policy.md` → carelogue.ca/privacy |
| 使用条款（EULA）可达 | ✅ / ⏳ | 文本见 `docs/legal/terms-of-service.md`；托管待办 |
| 首次使用前的数据流向说明与同意 | ✅ | `ConsentSheet`（每台设备一次，可撤回）|
| 相机权限用途说明（双语）| ✅ | `InfoPlist.xcstrings` 的 `NSCameraUsageDescription` |
| 不收集与功能无关的数据 | ✅ | 无账号、无分析 SDK、无广告标识符 |
| App Store Connect 隐私问卷 | ⏳ | 按隐私政策填：不收集可识别个人的数据；健康数据仅存本机/用户 iCloud |

## AI 相关披露

| 项 | 状态 | 落点 |
|---|---|---|
| 说明 AI 生成、可能出错、不替代医生 | ✅ | 解释卡免责行、同意弹窗、使用条款第 2 条 |
| 说明发送了什么、发给谁 | ✅ | `AIDisclosure`（责任版）：只发提取文本，原件不离开设备 |
| 不替服务商做无法担保的承诺 | ✅ | 改为"我们的遴选与更换纪律"（m3-bugs #1 的处置）|
| 服务商变更会通知用户 | ✅ | 写进隐私政策 |

## 医疗类应用注意

| 项 | 状态 | 说明 |
|---|---|---|
| 不做诊断 / 不给用药剂量建议 | ✅ | prompt 硬规则 + M3 护栏探针（含注入攻击样例）已验证 |
| 紧急情况提示 | ✅ | 使用条款第 2 条；应用内免责文案 |
| 不声称经过医疗认证 | ✅ | 全文无此类表述 |

## 提交前还要准备（M5）

- ⏳ 截图（6.7" / 6.5" 各一组，中英）
- ⏳ App 描述、关键词、What's New（中英）
- ⏳ 支持网址、营销网址、联系邮箱（与隐私政策一致）
- ⏳ 审核备注：说明 AI 解释需要订阅，并提供沙盒账号或说明如何用沙盒购买
- ⏳ `server/wrangler.toml` 的 `ALLOW_SANDBOX` 在正式发布后改回 `"0"`
