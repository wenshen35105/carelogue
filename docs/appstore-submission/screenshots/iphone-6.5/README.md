# iPhone 6.5" 提审截图（1284 × 2778）

两套，各 7 张，按文件名顺序上传（第一张是商店列表的首图）：

- `en-CA/` → ASC **English (Canada)**（主语言）listing
- `zh-Hans/` → ASC **简体中文** listing

全部由 `CarelogueUITests/ASCScreenshotUITests.swift` 在 iPhone 13 Pro Max 模拟器
（iOS 17.0，浅色）上用 `-uitest-seed-demo` 示例数据生成——不含任何真实数据。示例数据
跟随界面语言：英文版的旅程、记录、AI 解释、面诊总结都是英文内容；只有「我的疑问」
一页刻意保留中文原问题 + 英文翻译，因为「用母语写、给医生看英文」正是这页要展示的功能。

| 文件 | 画面 |
|---|---|
| `01-journeys.png` | 旅程列表：进行中的孕期旅程（下次体检倒计时、共享图标）+ 已完成的拔智齿旅程 |
| `02-timeline.png` | 时间线：共享标记、即将到来的体检、随手记、测量组、带 AI 摘要的验血记录 |
| `03-report-explain.png` | 报告 + AI 白话解释：总结、术语速查、「可以问问医生」问题清单 |
| `04-visit-recording.png` | 面诊录音卡：32:14 录音、波形、总结摘要行、「音频不进 AI」隐私说明 |
| `05-visit-summary.png` | 面诊总结：医生说了什么 / 关键要点 / 可以再问 |
| `06-questions.png` | 我的疑问：中文问题 + 英文翻译，「给医生看」大字版入口 |
| `07-paywall.png` | 订阅页：Carelogue Plus，$3.99/月（StoreKit 返回的价格） |

重拍（13 Pro Max 的 udid 用 `xcrun simctl list devices` 查）：

```
SIM_ID=<udid> APPEARANCE=light SCREENSHOT_DIR=$PWD/build/asc-zh \
  scripts/ui-test.sh -only-testing:CarelogueUITests/ASCScreenshotUITests
cp build/asc-zh/*.png docs/appstore-submission/screenshots/iphone-6.5/zh-Hans/

SIM_ID=<udid> APPEARANCE=light SCREENSHOT_DIR=$PWD/build/asc-en \
  scripts/ui-test.sh -only-testing:CarelogueUITests/ASCScreenshotEnglishUITests
cp build/asc-en/*.png docs/appstore-submission/screenshots/iphone-6.5/en-CA/
```
