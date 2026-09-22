# Carelogue — M2 验收走查 & Bug 清单（T15）

> 走查日期：2026-09-21 · 模拟器 iPhone 15 Pro Max · Debug 构建
> 方法：模拟器里没有 UI 自动化工具，所以用一个**临时调试夹具**（仅 DEBUG，未提交）灌入种子数据，并把目标页面直接设为根视图，配合 `simctl` 截图、杀进程重开来验证。需要点击系统界面（相册、文件选择器）的步骤列在最后"待手测"一节。

## 一、走查结果

| 项目 | 结果 | 说明 |
|---|---|---|
| T10 附件导入：压缩 | ✅ | 4032×3024 PNG 压到 2048×1536 JPEG（~390KB → ~130KB），竖图同理 |
| T10 附件导入：落盘 | ✅ | 就诊 Log + 2 图 + 1 PDF，杀进程重开 3 份都在 |
| T11 详情页附件卡 | ✅ | 图片 3 列网格 + PDF 行（图标块 / 文件名 / 大小 / 👁），样式照 Stitch"原始报告凭单" |
| T11 全屏预览 | ✅ | 图片按原比例完整显示；PDF（PDFKit）连续滚动两页 |
| T11 删除附件 | ✅ | 删除后重开不复活；外部存储文件被清掉 |
| T11 删除 Log 级联 | ✅（修复后） | 见 Bug #1 |
| T12 类型筛选 | ✅ | 体重 / 血压 / 体温混排，"血压"只剩 3 行；只有 1 种类型时隐藏 chips |
| T13 图表 20 点 | ✅ | 日期轴按月分档（5/1…9/1），曲线可读 |
| T13 图表 1 点 / 0 点 | ✅ | 1 点：日期轴前后各留 3 天 + 提示文字；0 点：空态卡。均不崩 |
| T13 新增数据后更新 | ✅ | 新增一条 72.5kg 后图表变为 21 点 |
| T14 深色模式 | ✅ | P1 / P2 / P3、图表、预览都没有白底残留；阴影退场，改用色阶分层 |
| T14 浅色回归 | ✅ | 与改动前一致 |
| Smoke：启动不崩溃 | ✅ | 不带夹具的干净构建 |
| Smoke：杀进程重开数据仍在 | ✅ | 见 T10 / T11 |

## 二、Bug 清单（M3 开工参考）

### 已在 M2 内修复
1. **删除 Log 不会级联删除 Artifact**（P1，M1 遗留）：`@Relationship(deleteRule: .cascade)` 没有生效，删除 Log 后附件留成 `log == nil` 的孤儿行，外部文件也一直占着空间。已改为 `ModelContext.deleteLog(_:)` 显式删除附件（T11 commit）。
   → **M3 注意**：以后如果加"删除 Journey"或"清空数据"，也不能依赖 cascade，要显式逐层删除，并用同样方法复查有没有孤儿行。
10. **新建/删除记录后时间线不刷新**（P0，UI 自动化测试发现）：保存成功（数据已落库，重开后能看到），但当前时间线不显示新记录；删除测量、删除附件后界面也不更新。原因：只设置了子对象一侧（`log.journey = journey` / `artifact.log = log`），视图观察的父对象数组 `journey.logs` / `log.artifacts` 没有触发刷新。已改为直接增删父对象数组（`journey.logs.append`、删除前 `removeAll`）。
    → 在 iOS 27 模拟器上复现；是否在 M1 就存在（真机 iOS 版本不同）未单独验证。**M3 注意**：以后所有增删关系都走父对象数组。
11. **预览页删除附件的时序**（P2）：原来在全屏预览还没关完时就删除 Artifact；已改为预览完全关闭后（`onDismiss`）再删，避免关闭动画期间视图再读到已删除对象。

### 待处理
2. **编辑类 sheet 深色下不是暖色调**（P3，视觉）：LogEditor / JourneyCreation / Profile 用的是系统 `Form`，深色下显示系统灰黑，不是 Nocturne 暖炭色。不算白底残留，但和 P1–P3 的色调不统一。建议给 Form 加 `scrollContentBackground(.hidden)`，再配上 `Theme.background` 和 `listRowBackground(Theme.card)`。
3. **导入附件没有大小上限**（P2）：未保存前附件全放在内存里，PDF 按原样存。几十 MB 的扫描件会占用大量内存，也会拖大 CloudKit 同步。建议 PDF 设上限（比如 20MB）并给出提示。
4. **时间线展开到底时，页脚"温和记录"离最后一行太近**（P3，视觉，M1 就有）。
5. **PDF 没有首页缩略图**（P3）：目前 PDF 行显示的是通用文档图标，可以用 PDFKit 渲染首页作缩略图。
6. **相册导入的文件名是生成的**（`IMG_日期_序号.jpg`，P3）：PhotosPicker 拿不到原文件名；从"文件"导入时会保留原名。
7. **附件入口只在就诊 Log**（产品问题）：按卡片范围，随手记不能挂照片（比如症状照片）。M3 要不要开放，需要产品决定。
8. **血压只记单值（收缩压）**：已知限制，图表页已经提示；双值字段留到 M4 / v1.1。
9. ~~没有 UI 自动化测试~~ → 已加 `CarelogueUITests` + `scripts/ui-test.sh`（见第三节）。
12. **测量 chip 行第 4 个 chip 被"图表"按钮挡住**（P3，可用性）：体重 / 血压 / 体温都有时，"体温"只露出一个边，需要横滑才能看到。可以考虑把"图表"按钮移到 chip 行上方，或放进分组卡的标题行。

## 三、自动化覆盖（原"待手测"项）

运行 `scripts/ui-test.sh`（深色：`APPEARANCE=dark scripts/ui-test.sh`），深浅两种模式均 5/5 通过：

| 用例 | 覆盖内容 |
|---|---|
| `SmokeUITests.testSmokeChecklist` | CLAUDE.md Smoke 5 步：启动 → 建 Journey → 三种 Log 各一条 → 编辑测量值 + 删除就诊 → 杀掉重开数据仍在 |
| `AttachmentUITests.testImportFromPhotosAndFiles` | 相册多选 2 张 + "文件"里选 2 份 PDF（系统选择器全程自动）→ 保存 → 杀掉重开仍是 2 图 + 2 PDF |
| `AttachmentUITests.testPreviewAndDelete` | 图片预览（捏合 / 双击缩放）、PDF 预览、预览页 🗑 删除、长按菜单删除，重开后不复活 |
| `MeasurementUITests.testFilterChipsAndTapToEdit` | 类型 chip 计数与筛选、点行直接进编辑并删除（2 击） |
| `MeasurementUITests.testChartSheet` | 图表 sheet：20 点体重、1 点体温的提示、关闭 |

仍需人工的：真机上的实际观感（字体渲染、手势手感），以及 CloudKit 同步（接入后）。
