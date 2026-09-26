# App Store Posters

从 `docs/appstore-submission/screenshots/iphone-6.5/` 的真实截图生成 App Store 提审海报（1284×2778，6.5" 档），可用作 Screenshots 直接上传。

## 用法

```bash
python3 tools/appstore-posters/make-posters.py          # 出两套（en-CA + zh-Hans）
python3 tools/appstore-posters/make-posters.py en-CA    # 只出英文套
```

输出到 `docs/appstore-submission/posters/<lang>/NN-name.png`。

## 改文案 / 换底图

- **文案**：改 `make-posters.py` 里的 `THEMES` 表（标题、`<em>` 橙色强调词、双语副标）。
- **底图**：替换 `screenshots/iphone-6.5/<lang>/` 下同名 PNG 后重跑即可；名称规则 `NN-name.png`（01-journeys … 07-paywall）。
- 底图必须是 **1284×2778**（与 ASC 提审截图同规）。

## 为什么是"大视口渲染 + 裁剪"

Chrome 在视口高度恰为 2778 时，输出 PNG 最底部约 85px 的合成不完整（白带）。
所以脚本用 4000px 高的视口渲染整页，再用 ffmpeg 裁回 1284×2778——白带即消失。

依赖：`google-chrome`（或 chromium）+ `ffmpeg`（Hermes 自带在 `~/.hermes/tools/`）。
