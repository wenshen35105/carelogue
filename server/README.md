# Carelogue · 解释转发服务 + 法律页（Cloudflare Worker）

app 里的「白话解释」不再直连模型厂商：设备上提取出的报告文字发到这里，由这个
Worker 验证订阅、转发给 AI 服务、把回复原样传回去。

**同一个 Worker 还负责两张法律页**：`carelogue.ca/privacy` 与 `/terms`，内容直接从
`docs/legal/` 的两份 Markdown 渲染（打包时作为 Text 模块进包），配色跟 app 一致。
一次部署，两个域名——路由在 `wrangler.toml` 里分，代码按路径分发。

**它不保存任何东西。** 没有用户表、没有账号、不落盘请求与回复。判断"你是不是订阅
用户"靠 App Store 给每笔交易签的 JWS——app 随请求带上，这里当场验签（spec §11
的无状态校验）。限流计数器里只有一个哈希和一个数字。

## 路由

```
GET  /privacy     → 隐私政策网页（HTML，由 docs/legal/privacy-policy.md 渲染）
GET  /terms       → 使用条款网页（同上）
GET  /v1/health   → {"ok": true}

POST /v1/explain
     Authorization: Bearer <StoreKit Transaction JWS>
     {"system": "...", "user": "...", "json": true, "stream": false}
     → {"content": "...", "model": "..."}        # stream: true 时原样透传 SSE
```

出错时返回稳定的机器码，文案由 app 决定：

| HTTP | `error` | 含义 |
|---|---|---|
| 401 | `missing_subscription` / `invalid_subscription` | 没带交易，或签名/证书链不可信 |
| 402 | `expired` / `revoked` / `wrong_product` / `sandbox_not_allowed` … | 签名可信但不构成有效订阅 |
| 413 | `too_long` | 报告文字超过上限（system 8k / user 16k 字符）|
| 429 | `rate_limited` / `provider_busy` | 触到限流，或上游在限流 |
| 502 | `provider_auth` / `provider_balance` / `provider_error` / `empty_reply` | 上游的问题（原始报错不外传：里面可能有我们的账户信息）|
| 504 | `timeout` / `unreachable` | 上游超时或连不上 |

## 一次性配置（你手动）

1. **DeepInfra**：注册 → 充值 → 生成 API key → 记下要用的模型 id（deepinfra.com/models
   上模型页标题那串，例如 `deepseek-ai/...`）。key 只进 Cloudflare secret，不进 git。
2. **Cloudflare**：注册免费账号，然后在这台 Mac 上一次性授权：

   ```sh
   cd server
   npx wrangler login            # 浏览器里点一次 Allow
   ```

3. **Apple 根证书指纹**：从 https://www.apple.com/certificateauthority/ 下载
   **Apple Root CA - G3**（`AppleRootCAG3.cer`，DER 格式），算出 SHA-256：

   ```sh
   shasum -a 256 AppleRootCAG3.cer
   ```

   把这串十六进制填进 `wrangler.toml` 的 `APPLE_ROOT_CA_G3_SHA256`。验签时链上的根
   必须正好是它——这样即使有人拿自签链来冒充，也过不了。

4. 把 `wrangler.toml` 里空着的 `DEEPINFRA_MODEL` 填上；确认 `PRODUCT_IDS` 与 App
   Store Connect 里的订阅产品 id 一致。
5. 限流计数器（可选但建议）：

   ```sh
   npx wrangler kv namespace create RATE_LIMIT
   ```

   把返回的 id 填进 `wrangler.toml` 里那段被注释掉的 `[[kv_namespaces]]` 并取消注释。
   不配也能跑，只是不限流。
6. 密钥与部署：

   ```sh
   npx wrangler secret put DEEPINFRA_API_KEY    # 粘贴 DeepInfra 的 key
   npx wrangler deploy
   ```

7. **自定义域**（等 carelogue.ca 接进 Cloudflare 之后）：取消 `wrangler.toml` 里三条
   `[[routes]]` 的注释，重新 deploy。三条各司其职：

   | 路由 | 给谁 |
   |---|---|
   | `api.carelogue.ca/v1/*` | app 的解释请求 |
   | `carelogue.ca/privacy` | 隐私政策页（App Store 审核要求可达）|
   | `carelogue.ca/terms` | 使用条款页 |

   app 里的 `CarelogueServerService.baseURL` 指向 `api.carelogue.ca`，
   `LegalLinks` 指向根域那两条。

## 本地跑

```sh
cd server
npm test              # 41 个用例（解释链路 + 法律页），不需要网络
npm install           # 只装 wrangler（部署工具；Worker 运行时零依赖）
npm run dev           # 本地起服务：http://127.0.0.1:8787/privacy 能直接看页面
npm run bundle-check  # wrangler deploy --dry-run，验证两份 md 打包进去了
```

`npm test` 用的是 Node 自带的测试运行器，依赖为零。测试里那条证书链是
`test/fixtures/` 下用 openssl 现造的、只在测试里用的自签链（有效期 100 年），
和苹果的真证书没有关系：它验证的是"签名对不对、链接不接得上、根是不是我们钉的那
个、过期的认不认"这套逻辑本身。

## 改法律文本

改 `docs/legal/*.md` 就行，重新 `npm run deploy` 即可生效——网页、仓库文本、App Store
审核用的那份是同一份，不会各自漂移。渲染器只支持文档里实际用到的 Markdown 子集
（标题 / 段落 / 加粗 / 列表 / 表格 / 分隔线）；加新语法要同时补 `src/markdown.js`
与 `test/legal.test.js`。

> 排版注意：连续几行会被合并成一段（标准 Markdown 行为）。要分行就写成列表或空一行。

## 上线前检查

- [ ] `ALLOW_SANDBOX` 改回 `"0"`（内测期间才需要 `"1"`）
- [ ] `DEEPINFRA_MODEL`、`APPLE_ROOT_CA_G3_SHA256`、`PRODUCT_IDS` 都已填
- [ ] KV 绑定已配（否则没有成本护栏）
- [ ] `wrangler deploy` 后 `curl https://api.carelogue.ca/v1/health` 返回 `{"ok":true}`
- [ ] `curl -I https://carelogue.ca/privacy` 返回 200 且 `content-type: text/html`
- [ ] 真机上用沙盒订阅走通一次完整解释
