# Carelogue · 待办（只有你能做的）

> 其余全部已由 CC 完成（M4：T23–T28 已合入）。这份只列真正需要你动手的，按"什么时候能做"分组。
> 更新：2026-09-23（M4 完成评审后）

## ⏳ 唯一阻塞项

- [x] **Apple Developer 认证** ✅ 2026-09-24 通过——B 组解锁。
  - ⚠️ （2026-09-24）**重复付款跟进**——认证已过，付款周期完结，不用再干等：① 查邮箱 "Apple Developer" 收据 + 账单结算状态（只扣一笔 → 删除本项）② 两笔都实扣（posted）→ 开 case：`developer.apple.com/contact/` → Membership and Account → Other Memberships/Account Questions → Email：请保留 Amex、退支付宝那笔，附两笔凭证 ③ 有笔仍挂 pending → 等结算（1–2 天）再定。开 case 不影响账号正常使用

## B. 认证过审后（按序）

1. [ ] Xcode → Settings → Accounts 登录开发者账号
2. [ ] 两台 iPhone 各 Run 一次 Carelogue（Xcode 直装）
3. [ ] 和 CC 一起验证 CloudKit 同步——**需同一 Apple ID 的两台设备**（你与太太各自 ID，两台手机无法互验；用你的 iPhone + 任意可登你 ID 的第二台设备；太太设备各验各的库）；细则见 docs/m4-tasks.md T23
4. [ ] App Store Connect：
   - [ ] 建 app 记录 + 订阅产品（id 已定：`…Carelogue.plus.monthly`，$3.99/月，中英本地化；**Family Sharing 开关一并打开——你们各自 Apple ID 但太太在家庭组里：这是她共享你订阅的必经路径**）
   - [ ] 签 Paid Apps 协议；填银行账户 + 税表
   - [ ] 隐私问卷（照 `docs/legal/privacy-policy.md` 填）
   - [ ] 注册 **App Store Small Business Program**（15% 抽成；不注册默认 30%——早注册早生效）
5. [ ] 真机沙盒订阅 → 完整跑一次解释（与 CC 配合）
6. [ ] **内测启动**（T29）：太太手机安装 → 建真实孕期 Journey → 开始用（发现问题丢微信即可）

## C. 现在就能做（不等认证）

- [x] **部署 server 到 Cloudflare** ✅（2026-09-23 完成；法律页已并入同一 Worker）
- [x] **DNS 记录 · api 子域** ✅（`api.carelogue.ca` 已解析，`/v1/health` 返回 `{"ok":true}`；2026-09-23 验证）
- [x] **DNS 记录 · 根域** ✅（2026-09-23；`https://carelogue.ca/privacy`、`/terms` 均已上线 200）—— 至此 Cloudflare + 域名 + server + 法律页全链路完成 🎉
- [x] **确认密钥**：`cd server && npx wrangler secret list`（应列出 `DEEPINFRA_API_KEY`；没有就 `npx wrangler secret put DEEPINFRA_API_KEY`）
- [x] **（建议）Email Routing**：把 `support@carelogue.ca` 转发到你的邮箱（Cloudflare → Email → Email Routing，2 分钟；法律文本的联系邮箱就用它）
  - 前提（一次性）：`cd server && npx wrangler login`
  - 两个值已替备好：
    - `DEEPINFRA_MODEL` = `deepseek-ai/DeepSeek-V4-Flash`
    - `APPLE_ROOT_CA_G3_SHA256` = `63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179`
      （来源：apple.com/certificateauthority 官方 AppleRootCA-G3.cer 的 SHA-256；CC 可自行复算核对）
  - 然后：
    ```sh
    cd server
    npx wrangler kv namespace create RATE_LIMIT   # 把 id 填进 wrangler.toml 并取消注释
    npx wrangler secret put DEEPINFRA_API_KEY     # 粘贴 DeepInfra 的 key
    npx wrangler deploy
    ```
  - 域名：确认 carelogue.ca 的 zone 已在 Cloudflare → 取消 `wrangler.toml` 里**三条** `[[routes]]` 注释 → `cd server && npm run deploy` → 验收：
    - `curl https://api.carelogue.ca/v1/health` 返回 `{"ok":true}`
    - `curl -I https://carelogue.ca/privacy` 与 `/terms` 返回 200（法律页已内置在同一个 Worker 里，见 `server/README.md`）
- [x] **法律文本填空**（正文 CC 已写好；3 个占位符 × 2 份文档）
  - 生效日期 / 法律主体（如：你的姓名 · 加拿大安省）/ 联系邮箱（建议 `support@carelogue.ca`）
  - 文件：`docs/legal/privacy-policy.md`、`docs/legal/terms-of-service.md`
- [x] **重新部署 server**（T31 改了 API 契约：prompt 从 app 搬到了 Worker）：`cd server && npm run deploy`。
  **先部署，再装新的 Debug 构建**——新旧契约不兼容，装反了解释会报 400。
- [x] **开通内部通道**（T30，2 分钟）：订阅还没上线，这是你自己装 Debug 构建就能跑通 AI 解释的唯一通道。
  ```sh
  cd server
  KEY=$(openssl rand -hex 24)        # 至少 24 位；记到密码管理器里
  echo "$KEY"                        # 待会儿粘到 app 的设置页
  npx wrangler secret put INTERNAL_ACCESS_KEY   # 粘贴同一串
  npx wrangler deploy
  ```
  然后在 Debug 构建的 **设置 → 内部通道 · Internal Access** 里粘贴同一串 → 显示「已解锁」即可免订阅用 AI 解释。
  凭据只落在那台设备的 Keychain 里，不进代码库、不进安装包；**公开发布前 `npx wrangler secret delete INTERNAL_ACCESS_KEY`**（已写进 T37 核对项）。
- [ ] **真机验一次面诊录音**（T32，只有真机能验）：装上 Debug 构建 → 任一「就诊」记录 → 开始录音 → 说两分钟 → 完成 → 看本地转写出不出文字 → 整理成总结。
  重点看两件事：① 中英混着说（"胎心 152，NT ultrasound"）转写准不准 ② 一小时录音的体积（预期 ≈ 11MB）。
  **按卡内验收**：最好就是下次产检真录一次，太太一起看看总结和「我的疑问」大字版能不能用。
- [ ] **拍一个小项**：解释可"附带档案信息"（过敏/长期用药，默认开启；隐私政策已披露、设置可关）——① 同意弹窗要不要也补一句透明说明？（建议：补）② 默认值"开"还是"关"？（建议：开）回一句即可

## D. 发布前（M5，内测之后）

- [ ] 其余见 `docs/appstore-checklist.md` 的 ⏳ 项（截图素材、描述、审核备注、`ALLOW_SANDBOX` 改回 0 等）
