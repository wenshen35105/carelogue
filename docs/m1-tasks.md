# Carelogue — M1 任务卡（项目骨架 + 数据层 + CRUD）

> 用法：一张一张来——每张卡交给 Claude Code（Mac 上）或 dev 执行，**完成后对照"验收"项手工过一遍再开下一张**。卡不依赖顺序里的后续卡，但建议按顺序。
> 环境前提：MacBook Air 接入完成（dev profile SSH 到 Mac）、Xcode 装好。
> 总预估：~29h ≈ 按每周 5–10h 计 4–6 周。

---

## T1 · 项目初始化（~3h）
- **做**：Xcode 新建 iOS App（Interface: SwiftUI，Storage: SwiftData）；bundle id（如 `love.carelogue.app` 待定）；最低 iOS 17；建 Git 仓库 + 目录结构（`Models / Views / Services / Resources`）；CloudKit capability 先不勾（M1 纯本地跑通再说）
- **验收**：`xcodebuild -version` 无误，模拟器能起空 App
- **学习点**：Xcode 工程结构、target、模拟器

## T2 · 数据模型 v1（~3h）
- **做**：按 spec 第 4 节建 4 个 `@Model`：Journey / Log / Artifact / Profile
  - CloudKit 兼容规则：**所有非 optional 属性给默认值；不要用 unique 约束**（UUID 手动去重）
- **验收**：能插入/查询一条 Journey 和 Log（临时按钮 + print 即可）；重装 app 数据在
- **学习点**：`@Model`、属性包装、SwiftData 的 schema 思路

## T3 · Journey 列表页 P1（~4h）
- **做**：列表（名称/状态/最近活动/Log 数）+ 空状态引导（wizard 两步：命名 → 模板[孕期/拔牙/自定义]）+ 新建/重命名/归档
- **验收**：A4 原则——启动到新建完成 ≤3 次点击
- **学习点**：`@Query`、`NavigationStack`、List、sheet

## T4 · 时间线页 P2（~5h）
- **做**：按 `occurred_at` 倒序的 Log 卡片流；kind 图标；测量**折叠分组卡**（"测量 ×12 · 最近 68.5 kg"）+ 展开列表
- **验收**：三种 kind 混排不刷屏；点卡片进详情
- **学习点**：列表分组、`@ViewBuilder`、状态归一

## T5 · Log 编辑器：就诊（~4h）
- **做**：类型 chips（面诊/体检/验血/影像/其他）、日期、地点/医生（可选）、备注；附件区占位（M2 实现）
- **验收**：新建/编辑/删除就诊记录全通
- **学习点**：Form、Picker、DatePicker、绑定

## T6 · Log 编辑器：随手记 + 测量（~3h）
- **做**：随手记=打开即聚焦键盘、3 秒记完；测量=类型+数值+单位+时间
- **验收**：随手记从点＋到保存 ≤ 5 秒
- **学习点**：`@FocusState`、数字输入

## T7 · 详情/编辑/删除 + 导航打磨（~3h）
- **做**：统一详情页；滑动删除；编辑入口；全局导航自检
- **验收**：任意 Log ≤3 击可达编辑
- **学习点**：swipeActions、导航层级

## T8 · Profile 页 P4（~2h）
- **做**：4 个自由文本域 + "只存本机"说明行 + 清空按钮
- **验收**：数据可存可清
- **学习点**：单例数据（@Query 取第一条）

## T9 · M1 验收走查（~2h）
- **做**：手工过 spec 的 A1 / A3 / A4（A2 属 M3）；把卡壳点记成 issues
- **验收**：三种 Log 各 2 条、产检流程演练一遍不离开 app
- **产出**：M2 开工的 bug 清单

---

## 给 Claude Code 的开工提示（每次一卡）
> 你在此仓库实现任务卡 Tn（见 m1-tasks.md）。完成后：① 用模拟器构建通过 ② 自测卡里的"验收"项 ③ 列出改动的文件清单。不实现卡范围外的功能（YAGNI）。
