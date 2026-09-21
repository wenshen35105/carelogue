# Carelogue

iOS 患者就医旅程记录 app（SwiftUI + SwiftData + CloudKit）。
本仓库 = 产品文档 + Xcode 工程（工程在 Mac 上创建后放入根目录）。

## 结构

- `CLAUDE.md` — Claude Code 常驻规则（每个会话开工先读）
- `docs/` — 产品文档：brief / spec / M1 任务卡 / 设计评审
- `docs/design/` — 设计稿：方向稿 + Stitch 三屏 + DESIGN.md（UI 实现参照）

## 开工流程（Mac）

1. Xcode 新建 iOS App：名 `Carelogue`，Interface: SwiftUI，Storage: SwiftData，最低 iOS 17
2. 工程存到本仓库根目录（.xcodeproj + 源码目录）
3. 启动 Claude Code，粘贴开工 prompt（见下）
4. 一次一张卡：T1 → T2 → …（每张卡按验收后 commit）

## 当前进度

- ✅ 命名（Carelogue）/ 术语表 v1 / 数据与同步架构 / 设计方向（Stitch 三屏）定稿
- ⬜ M1：项目骨架 + 数据层 + CRUD（9 张卡，见 `docs/m1-tasks.md`）
