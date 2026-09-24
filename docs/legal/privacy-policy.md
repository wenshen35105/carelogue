# Carelogue 隐私政策 · Privacy Policy

**生效日期 Effective date**：2026/09/23
**运营方 Operator**：Jiajin Lin · Canada · Ontario
**联系方式 Contact**：support@carelogue.ca

---

## 中文

### 一句话版本

Carelogue 是一个记录就医过程的本地应用。你的记录存在你自己的设备和你自己的
iCloud 里；只有在你主动点击「白话解释」时，这份报告里**被识别出来的文字**才会经
加密通道发送一次，用于生成解释。我们不保存这些文字，也没有账号系统。

### 我们收集什么

**我们不收集**你的健康记录、附件、档案信息，也不收集姓名、邮箱、手机号或广告标
识符。Carelogue 没有账号，你不需要注册。

| 数据 | 存在哪里 | 谁能看到 |
|---|---|---|
| 旅程、记录、测量、备注 | 你的设备；开启 iCloud 后同步到你自己的 iCloud 私有数据库 | 只有你（我们没有访问权限） |
| 附件（照片、PDF） | 同上 | 只有你 |
| 档案（过敏、长期用药等） | 同上 | 只有你 |
| AI 解释结果 | 同上（缓存在本机记录里） | 只有你 |

iCloud 同步由 Apple 提供，适用 Apple 的隐私政策；数据存放在你个人的 iCloud 私有
数据库中，我们无法读取。

### 使用 AI 解释时会发生什么

1. 报告里的文字**在你的设备上**用系统自带的文字识别提取出来；
2. 只有这些文字（以及旅程名称，和你在设置里允许时的「过敏 / 长期用药」）经 HTTPS
   加密通道发送到我们的转发服务；
3. 转发服务把它交给我们选用的 AI 服务，取回解释，再原样返回给你的设备；
4. 解释结果保存在你的设备上。

**照片和 PDF 原件不会离开你的设备。** 我们的转发服务不保存请求内容、不保存返回内
容、不写日志留存报告文字。

为了防止滥用与失控的费用，转发服务会保留一个**计数器**：订阅凭证与 IP 地址经哈希
后的短值，加上一个次数，按小时自动过期。它不包含报告内容，也无法还原成你的身份。

### 关于 AI 服务商

我们对选谁负责，而不是替服务商做承诺。我们的遴选标准是：

- 条款层面承诺 API 数据**不用于模型训练**；
- 有明确、有限的数据保留期限；
- 能覆盖 Carelogue 需要的全部 AI 功能。

若服务商条款发生变化而不再满足上述标准，我们会评估并更换服务商；应用发布后发生更
换，我们会在应用内或通过更新说明告知你。

### 订阅

Carelogue Plus 通过 App Store 订阅，付款与续费由 Apple 处理。**我们拿不到你的支付
信息。** 校验订阅时使用的是 Apple 为每笔交易签名的凭证，它包含交易标识与到期时间，
不包含你的姓名或账户信息。我们不保存它。

### 你的选择

- **随时关闭 AI**：设置 › AI · 解释功能。关闭后不会发送任何内容。
- **撤回 AI 同意**：设置 › 隐私与数据流向 › 撤回 AI 同意。
- **不附带档案信息**：设置里关闭「附带档案信息」。
- **删除数据**：设置 › 数据管理 › 清空所有数据，会删除这台设备上的全部记录、附件
  与档案；删除 App 也会一并删除本机数据（iCloud 中的副本按 Apple 的规则清理）。
- **取消订阅**：App Store 账户 › 订阅。

### 儿童

Carelogue 不面向 13 岁以下儿童，也不会有意收集他们的信息。

### 变更

政策更新会修改本页的生效日期；涉及数据流向的实质变更，会在应用内说明。

### 联系

有任何隐私问题，请邮件联系 support@carelogue.ca。

---

## English

### In one sentence

Carelogue keeps your care records on your own device and in your own iCloud.
Only when you tap "Explain" does the **text recognised from that report** get
sent once, over an encrypted connection, so an explanation can be generated. We
do not keep that text, and there are no accounts.

### What we collect

**We do not collect** your health records, attachments or profile, and we do not
collect your name, email, phone number or advertising identifiers. Carelogue has
no account system; there is nothing to sign up for.

| Data | Where it lives | Who can see it |
|---|---|---|
| Journeys, records, measurements, notes | Your device; with iCloud on, your own private iCloud database | Only you — we have no access |
| Attachments (photos, PDFs) | Same | Only you |
| Profile (allergies, medications, …) | Same | Only you |
| AI explanations | Same (cached with the record) | Only you |

iCloud syncing is provided by Apple under Apple's privacy policy; the data sits
in your personal private database, which we cannot read.

### What happens when you use an AI explanation

1. The report's text is extracted **on your device** using the system's own text
   recognition;
2. only that text (plus the journey name, and your allergies / medications if you
   allow it in Settings) is sent over HTTPS to our relay;
3. the relay passes it to the AI service we use, takes the reply, and returns it
   to your device;
4. the explanation is stored on your device.

**Photos and PDFs never leave your device.** Our relay stores no request bodies,
no replies, and writes no logs containing report text.

To prevent abuse and runaway cost, the relay keeps a **counter**: a short hash of
the subscription receipt and of the IP address, plus a number, expiring
automatically each hour. It contains no report content and cannot be turned back
into your identity.

### About the AI service

We take responsibility for choosing the provider rather than making promises on
its behalf. Our standard is:

- terms that commit to **not training models on API data**;
- a clear, limited retention period;
- coverage of every AI feature Carelogue needs.

If a provider's terms change so that they no longer meet this standard, we
evaluate and switch. After public release, we will tell you in the app or in the
release notes when we do.

### Subscription

Carelogue Plus is sold through the App Store; payment and renewal are handled by
Apple. **We never receive your payment details.** Verification uses the receipt
Apple signs for each transaction, which carries a transaction identifier and an
expiry date — not your name or account. We do not store it.

### Your choices

- **Turn AI off** at any time: Settings › AI. Nothing is sent while it is off.
- **Withdraw AI consent**: Settings › Privacy & Data Flow › Revoke consent.
- **Leave your profile out**: switch off "Include profile" in Settings.
- **Erase everything**: Settings › Data Management › Erase all data. Deleting the
  app also removes its local data (the iCloud copy is cleaned up under Apple's
  rules).
- **Cancel the subscription**: App Store account › Subscriptions.

### Children

Carelogue is not directed at children under 13 and does not knowingly collect
their information.

### Changes

Updates are reflected in the effective date above; substantive changes to where
data goes are explained in the app as well.

### Contact

Questions about privacy: support@carelogue.ca.
