# Carelogue · 待办（只有你能做的）

> 其余全部已由 CC 完成（M4：T23–T28 已合入）。这份只列真正需要你动手的，按"什么时候能做"分组。
> 更新：2026-09-23（M4 完成评审后）

## ⏳ 唯一阻塞项

- [ ] **Apple Developer 认证**——还在审。过审后解锁 B 组全部事项。

## B. 认证过审后（按序）

1. [ ] Xcode → Settings → Accounts 登录开发者账号
2. [ ] 两台 iPhone 各 Run 一次 Carelogue（Xcode 直装）
3. [ ] 和 CC 一起验证 CloudKit 双机同步（一台建记录 → 另一台可见、含附件；细则见 docs/m4-tasks.md T23）
4. [ ] App Store Connect：
   - [ ] 建 app 记录 + 订阅产品（id 已定：`…Carelogue.plus.monthly`，$4.99/月，中英本地化）
   - [ ] 签 Paid Apps 协议；填银行账户 + 税表
   - [ ] 隐私问卷（照 `docs/legal/privacy-policy.md` 填）
5. [ ] 真机沙盒订阅 → 完整跑一次解释（与 CC 配合）
6. [ ] **内测启动**（T29）：太太手机安装 → 建真实孕期 Journey → 开始用（发现问题丢微信即可）

## C. 现在就能做（不等认证）

- [x] **部署 server 到 Cloudflare**（在 Mac 上；可整体交给 CC 执行）——**含法律页**：`/privacy`、`/terms` 复用同一个 Worker（加两条路由 + 页面直出即可，不需要单独建项目）
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
  - 域名：确认 carelogue.ca 的 zone 已在 Cloudflare → 取消 `wrangler.toml` 里 `[[routes]]` 注释 → 重新 deploy（得到 `api.carelogue.ca`）→ `curl https://api.carelogue.ca/v1/health` 应返回 `{"ok":true}`
- [x] **法律文本填空**（正文 CC 已写好；3 个占位符 × 2 份文档）
  - 生效日期 / 法律主体（如：你的姓名 · 加拿大安省）/ 联系邮箱（建议 `support@carelogue.ca`）
  - 文件：`docs/legal/privacy-policy.md`、`docs/legal/terms-of-service.md`
- [ ] **拍一个小项**：解释可"附带档案信息"（过敏/长期用药，默认开启；隐私政策已披露、设置可关）——① 同意弹窗要不要也补一句透明说明？（建议：补）② 默认值"开"还是"关"？（建议：开）回一句即可

## D. 发布前（M5，内测之后）

- [ ] 其余见 `docs/appstore-checklist.md` 的 ⏳ 项（截图素材、描述、审核备注、`ALLOW_SANDBOX` 改回 0 等）
