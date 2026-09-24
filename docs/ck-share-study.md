# 跨 Apple ID 共享 · 调研（T33）

> 2026-09-23 · 对应 `docs/m5-tasks.md` T33
> 问题：太太和我是**不同的 Apple ID**（同一个家庭组）。iCloud 私有库同步解决的是"同一个 ID 的多台设备"，解决不了"两个人看同一段旅程"。
> 结论先说：**走路线 B（SwiftData 主库 + 一条专门的 CKShare 通道）**，但**不进 v1.0**；v1.0 用「最小只读导出」兜住，把真正的共享放到 v1.1，等内测跑出真实痛点再动数据层。

---

## 一、先核实：Apple 今天到底给了什么

**核实方式**：直接读 iOS 27 SDK 里 SwiftData 的接口文件
（`SwiftData.framework/Modules/SwiftData.swiftmodule/arm64-apple-ios-simulator.swiftinterface`），
以及社区最新的参考实现。

SwiftData 能选的 CloudKit 数据库只有三种：

```swift
ModelConfiguration.CloudKitDatabase
  .automatic          // 私有库
  .none               // 不同步
  .private(String)    // 指定名字的私有库
```

**没有 `.shared`**。也就是说，截至 iOS 27 SDK，SwiftData 仍然**只会**读写你自己的私有库，
它不知道"共享库"这个东西存在。这一点从 iOS 17 到现在没变，社区的判断也一致。

Core Data 那边（`NSPersistentCloudKitContainer`）则一直是完整的：`share(_:to:)`、
`acceptShareInvitations`、`databaseScope = .shared`、区域级共享（`CKRecordNameZoneWideShare`）都有。
**能力差距不在 CloudKit，在 SwiftData 的封装。**

还有一条硬约束：**默认 zone 里的记录不能共享**。要共享就必须在自定义 zone 里，
而 SwiftData 自己建的 zone 是它说了算的。

---

## 二、三条路线

### 路线 A · 数据层换回 Core Data（`NSPersistentCloudKitContainer`）

把 `@Model` 全部改写成 Core Data 实体 + `.xcdatamodeld`，共享用官方 API。

- ✅ 唯一一条"官方支持、文档齐全、以后不会被 Apple 改坏"的路
- ✅ 读写权限、邀请、接受、撤销、区域级共享，全都是现成的
- ❌ 现有 4 个模型（Journey / Log / Artifact / Profile）、所有 `@Query`、
  `ModelContext` 调用、`ModelDeletion`、UITest 的 seeding 全部要重写
- ❌ 已经在设备上、已经同步进 iCloud 的数据要做一次真实迁移（见第四节风险）
- 📏 工程量估计：**5–8 天**（重写 3–4 天 + 迁移与回归 2–4 天），且期间整个 app 处于"半拆状态"

### 路线 B · SwiftData 留着，另开一条 CKShare 通道 ★ 选这条

主库仍是 SwiftData（私有库自动同步，一个字不改），**另外**用原生 CloudKit API
单独处理"被共享出去的那部分"：建 `CKShare`、发邀请、接受邀请、把共享库里的记录
读回来写进本地 SwiftData。社区参考实现 `framara/CloudKitSharing` 正是这套，可直接对照。

它的关键做法（从参考实现里核实出来的）：

1. 被共享的根记录要带 CloudKit 元信息字段：`isShared` / `ownerID` / `shareRecordID` /
   `shareZoneOwnerName` / `lastSharedUpdatedAt`——对我们就是给 `Journey` 加几个 optional 字段
2. 共享的记录必须放在**自定义 zone**，不能在默认 zone
3. 子记录要设 `record.parent` 指向根记录，否则它们在 zone 里但不属于这个 share
4. 接受邀请走 **SceneDelegate** 的 `userDidAcceptCloudKitShareWith`（不是 AppDelegate），
   再用 `CKAcceptSharesOperation`，然后在本地建一份 SwiftData 副本
5. 同步靠三件事叠加：5 秒轮询（主力）+ `CKDatabaseSubscription` 推送 + 监听
   `NSPersistentStoreRemoteChange`

- ✅ 主库不动，现有代码、测试、CloudKit 容器全部照常
- ✅ 可以只共享"一段 Journey"，符合产品直觉（共享孕期，不共享拔智齿）
- ✅ 失败了也只是"共享不可用"，不会把本地数据弄坏
- ❌ 这是**社区模式，不是 Apple 文档里的路**；SwiftData 哪天真加了 `.shared`，这套要重写
- ❌ 双写（SwiftData 本地 + CloudKit 共享区）意味着要自己处理冲突；参考实现坦承
  **没有字段级冲突解决**，也**只支持读写参与者，不支持只读**
- ❌ 5 秒轮询对电量和配额都不友好，得自己调成"前台 + 推送触发"
- 🔁 **如果苹果将来给 SwiftData 补上官方共享**：迁移 = 拆掉桥接层、换成官方通道——本地数据层、共享元信息字段、邀请/管理 UI、产品语义基本原样保留，估 **2–3 天**；不是"白做"（最坏情况 ≈ 当初 1–2 天写的桥接被重写一次）
- 📏 工程量估计：**4–6 天**（通道 2–3 天 + 邀请/接受/撤销的 UI 与状态 1 天 + 两台真机两个 ID 的联调 1–2 天）

### 路线 C · 最小只读导出（不动数据层）

不做真共享：把一段 Journey 渲染成只读快照（PDF 或长图），走系统分享面板发出去。

> **2026-09-24 补充（老板问 AirDrop）**：分享面板天然含 **AirDrop**——两台设备直传、原文件不压缩、不经任何第三方服务器，比微信截图更适合健康数据；微信/信息/存文件也都在面板里。定性：AirDrop 是**传文件**，不是同步——单向、快照、要手动。它把"看一眼"体验做到位；"一起记"仍然等 v1.1（或内测证明不需要）。

- ✅ **半天**，不碰数据层、不碰 CloudKit、不引入任何新失败模式
- ✅ 顺手把 backlog 里的「导出/分享」往前推了一步，发给医生也用得上
- ❌ 单向、静态；对方看到的是那一刻的快照，不会更新，也不能回写

---

## 三、定案与理由

**v1.0 先上路线 C，v1.1 做路线 B。**

为什么不是现在就做 B：

1. **时间点不对**。M5 的目标是"发出去 + 跑稳"。跨 ID 共享是 4–6 天的新失败面
   （冲突、配额、邀请链路），压在上架前会把审核周期一起拖长。
2. **需求强度还没被验证过**。太太还没真正用起来（T29 内测才刚要开始）。
   很可能真实痛点是"我想让他看看今天这张报告"，那 C 就够了；
   也可能是"我们俩都要记"，那 B 才值得。**让内测来回答，而不是现在猜。**
3. **B 的风险是"可能白做"**。Apple 只要给 SwiftData 补上 `.shared`，
   这套 hack 就得拆。晚半年做，反而更可能等到官方解法。
4. **C 不是浪费**。只读导出在 backlog 里本来就是要做的（发给医生、存档、给家人看），
   共享做出来之后它依然有用。

为什么最终不是 A：数据层换回 Core Data 是"为了一个功能，把整个 app 的地基换掉"。
只有当共享成为产品的**主轴**（照护者模式、家庭档案组，见 backlog A 区）时才划算。
到那一步再评估——而且到那时 SwiftData 很可能已经原生支持了。

---

## 四、路线 B 的实施计划（等 v1.1 启动时照这个走）

| 步骤 | 做什么 | 估时 |
|---|---|---|
| 1 | `Journey` 加 optional 元信息字段（`shareRecordID` / `ownerID` / `shareZoneOwnerName` / `isShared` / `lastSharedUpdatedAt`）——全 optional + 默认值，可加性迁移 | 0.5 天 |
| 2 | `ShareService`：建自定义 zone、建根 `CKRecord` + `CKShare`、把 Journey 及其 Log/Artifact 以 `record.parent` 挂成一棵树、原子保存 | 1 天 |
| 3 | 邀请链路：`UICloudSharingController` 发出邀请；SceneDelegate 接 `userDidAcceptCloudKitShareWith` + `CKAcceptSharesOperation` | 0.5 天 |
| 4 | 回流：从 `.shared` 库拉记录 → 写成本地 SwiftData 副本；`CKDatabaseSubscription` 推送 + 前台一次性拉取（**不做 5 秒轮询**） | 1 天 |
| 5 | 冲突策略：先做最粗的「按 `updatedAt` 后写赢 + 附件不合并」，并在 UI 上明说 | 0.5 天 |
| 6 | 共享管理 UI：谁能看、撤销、退出 | 0.5 天 |
| 7 | 两台真机 × 两个 Apple ID 联调（这一步没法在模拟器做） | 1–2 天 |

**合计 5–6 天**，其中第 7 步必须要两个真实 Apple ID 的设备。

### 迁移风险

- **可加性 schema 变更**（全 optional + 默认值）对 CloudKit 是安全的，
  与 T32 刚加的字段同一性质，已经验证过一次
- **真正的风险不在本地，在 zone**：共享要求自定义 zone，而 SwiftData 已经把数据放在
  它自己管理的 zone 里。路线 B 的做法是**复制一份进共享 zone**，不是搬家——
  也就是说被共享的 Journey 在 CloudKit 里会有两份。配额和一致性都要按这个前提设计
- **附件是大头**：一段孕期旅程的照片 + 录音可能几百 MB，跨 ID 复制一份要考虑
  只共享元数据和文字、附件按需拉取
- **撤销共享后对方本地的副本不会自动消失**——这是 CloudKit 的行为，产品文案要说清楚

---

## 五、非技术版摘要（给老板）

**一句话**：两个 Apple ID 看同一段旅程，苹果今天没给现成的路；能做，但要自己搭，
大约一周，而且苹果随时可能给出官方做法让这一周白做。

**所以建议**：

- **现在（v1.0）**：花半天做一个「把这段旅程导出成一份只读快照，发给家人或医生」。
  单向、静态，但立刻能用，也不会给上架添风险。
- **内测期**：注意观察——太太到底是想"看一眼"，还是想"一起记"。
  这两件事需要的东西完全不同。
- **v1.1**：如果是"一起记"，再花 5–6 天把真共享做上（含两台真机联调）。
  到那时也许苹果已经补上了，能省掉一半工作。

**要你配合的**：真共享做到最后一步时，需要**两台 iPhone、两个不同的 Apple ID**
（你的 + 太太的）联调，没法用模拟器代替。

---

## 参考

- SwiftData 的 `CloudKitDatabase` 选项：iOS 27 SDK 接口文件（本机核实，2026-09-23）
- [framara/CloudKitSharing](https://github.com/framara/CloudKitSharing) — SwiftData + CKShare 的可用参考实现
- [delawaremathguy/CoreDataCloudKitShare](https://github.com/delawaremathguy/CoreDataCloudKitShare) — 官方路线（Core Data）的完整示例
- [SwiftData, CloudKit Sharing between different users（Hacking with Swift 论坛）](https://www.hackingwithswift.com/forums/swiftui/swiftdata-cloudkit-sharing-between-different-users/27679)
- [SwiftData with shared and private containers（Apple 开发者论坛）](https://developer.apple.com/forums/thread/756721)
