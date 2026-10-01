# docs 索引（2026-09-30）

> 状态：**1.0 提审收尾（M6）+ 1.0.1 定义中（M7）**。入口：根目录 `CLAUDE.md`。
> 结构：里程碑卡按发布版本归档在 `releases/<版本>/`；跨版本的文档（spec、backlog、owner-actions、调研）留在 `docs/` 根。

## 里程碑（按版本）
| 版本 | 里程碑 | 状态 |
|---|---|---|
| **1.0.1** | `releases/1.0.1/m7-tasks.md` | **草案**：2026-09-30 自用反馈 6 条（T42–T47），不改 schema |
| **1.0** | `releases/1.0/m6-tasks.md` | **进行中**：T39 CKShare（代码完成，余 schema 部署/双机联调）· T40 产检真机验收 · T41 提审材料包（余 ASC 侧动作）· 发布流程指向 owner-actions |
| 1.0 | `releases/1.0/m5-tasks.md` | 已完成（T30–T38；T38 撤销，见文内更新行） |
| 1.0 | `releases/1.0/m1-tasks.md` … `m4-tasks.md` | 历史卡（均完成） |
| 1.0 | `releases/1.0/m5-notes.md` | M5 备忘（历史输入；7 条均已落实） |
| 1.0 | `releases/1.0/m2-bugs.md` / `m3-bugs.md` | 走查与技术债（P3 遗留待 v1.1） |

> 新版本：建 `releases/<版本>/`，里程碑编号与卡号全局递增（M8、T48…），不按版本重置。

## 行动与清单
| 文件 | 用途 |
|---|---|
| `owner-actions.md` | **只有老板能做的**待办（现行；§顶部=当前阻塞，§D=提审前 ASC 动作） |
| `appstore-checklist.md` | 审核要素自检（代码侧全 ✅；提交动作见下方两处） |
| `appstore-submission/` | **1.0 提审材料包**：`metadata-fields.md` 逐字段手册（§D=提交 checklist）/ `review-notes.md` / `posters/`（ASC 上传定稿）/ `screenshots/`（底图源）/ `reference/`（ASC 版本页 PDF） |
| `backlog.md` | 未排期功能总表 |

## 调研与决策
| 文件 | 用途 |
|---|---|
| `ck-share-study.md` | 跨 Apple ID 共享（T39 依据：路线 B、实施计划、自建 server 为何不做） |
| `china-assessment.md` | 中国区评估（结论：不做） |
| `design-review.md` | Stitch 稿评审记录 |
| `product-brief.md` / `mvp-spec.md` | 产品定位 / 功能蓝图（数据模型、AI 契约） |
| `legal/` | 隐私政策、条款（线上源） |
| `web/` | 支持页源（线上 `carelogue.ca/support`，经 Worker 渲染） |
| `design/stitch/` | 设计稿、prompt、DESIGN.md |
| `screenshots/` | 开发留档截图 |
