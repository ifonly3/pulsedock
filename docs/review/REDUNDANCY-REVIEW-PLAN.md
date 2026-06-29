# Pulse Dock 深度代码审查计划 — 冗余与重复专项

> 制定日期：2026-06-28
> 审查目标：系统性发现**信息冗余**（同一数据在 UI 多处重复展示无新增价值）、**代码重复**（同一逻辑在多处独立维护）、**死状态/死代码**（声明但从不读取的状态/分支/字段）三类问题
> 审查基准：当前 working tree（HEAD `9db73ee`）
> 触发缘由：用户指出侧栏左下角"Live Sampling"卡片（`SidebarHealthCard`）信息与顶栏/Overview 页大部分重复，质疑其必要性。本计划将此思路扩展到全代码库，复查是否存在类似的冗余。
> 关联资产：
> - `docs/review/LOGIC-CONSISTENCY-REVIEW-PLAN.md`（逻辑/数据一致性专项 —— 本计划与之互补，不重复其话术矛盾/字符串契约审查）
> - `docs/review/REVIEW-PLAN.md`（Bug 与设计缺陷专项 —— 本计划不重复其崩溃/性能/并发审查）
> - `docs/review/top/final-review-v2.md`（前次 Bug 专项最终报告）

---

## 一、定位与边界

本计划**不重复**前两次审查的范围，而是聚焦三类"静态分析难以发现、需要人/agent 逐处对照才能识别"的冗余层缺陷：

| 类别 | 定义 | 典型症状 |
|------|------|----------|
| R1. 信息冗余 | 同一数据点在 UI 多处展示，且后一处相对前一处无新增信息价值（无更细粒度/无不同视角/无不同时间窗） | 侧栏 "Live Sampling" 卡片的 CPU/Memory/Disk 值+进度条与 Overview MetricCard 完全重复；sampleTimeText 在侧栏/顶栏/CPU页/Settings页/widget预览 6 处展示 |
| R2. 代码重复 | 同一逻辑/函数/常量在多处独立维护，无单一来源（single source of truth），rename 一处即与其他处静默分歧 | `normalizedRate`/`reportedProgress`/`progressFillWidth` 在 DashboardView + WidgetPanelView + SystemDashboardWidget 三处各一份；`Palette`/`DashboardColor`/`WidgetColor` 三套颜色系统 |
| R3. 死状态/死代码 | 声明但从不被任何视图消费的状态、定义但从不被调用的分支/字段、保留但从不被读取的持久化数据 | `isRefreshing` 非 @Published 但无视图消费；networkBytesPerSecond 在 widgetCompact 保留但 widget 不读取；`powerSourceNoBattery` 分支不可达 |

**与 `LOGIC-CONSISTENCY-REVIEW-PLAN.md` 的关系**：前次审查的 L3-15（networkBytesPerSecond 冗余传输）、L4-7（"No Battery" 不可达分支）、L1-12（桌面 Mac "Power=Power Adapter" 三处重复）已点到为止；本计划将其升级为**独立审查维度**，逐处扫描全部冗余模式，目标是从"已知 3 条"扩展到"全量清单"。

**与 `REVIEW-PLAN.md` 的关系**：前次 Bug 专项的 P2-4（normalizedRate/reportedProgress/progressFillWidth/Palette 三处重复）、P2-1（god file）已记录代码重复；本计划聚焦"重复带来的具体用户/维护影响"而非"应拆分"的结构性建议。

---

## 二、审查范围

| 模块 | 路径 | 冗余相关重点文件 |
|------|------|----------------|
| SharedMetrics | `Sources/SharedMetrics/` | `MetricSnapshot.swift`(1763) 派生属性是否多处重复计算 · `SharedMetricStrings.swift`(423) 话术是否多处定义 · `MetricSnapshot+WidgetCompact.swift`(62) 裁剪字段是否被保留但不被读取 |
| PulseDockApp | `Sources/PulseDockApp/` | `DashboardView.swift`(2337) UI 组件/数据展示重复 · `WidgetPanelView.swift`(339) 与 DashboardView 逻辑重复 · `MetricsStore.swift`(513) 死状态 · `DashboardVisualTokens.swift`(66) 与 WidgetPanelView `Palette` 颜色重复 |
| PulseDockWidget | `Sources/PulseDockWidget/` | `SystemDashboardWidget.swift`(757) 与 app 侧 thermalTint/networkTint/reportedProgress 重复 · `WidgetVisualTokens.swift`(96) 与 DashboardColor 重复 |
| 文档/资源 | `docs/`、`Resources/` | 话术在三套 strings 表重复定义 · `design/` vs `designs/` 目录冗余 |

---

## 三、探索阶段已确认的锚点发现（种子清单）

> 以下为本次探索已对照源码确认的具体问题，作为各子任务的起始线索。标注 `[ANCHOR]` = 已直接定位到行号。

### R1 类 — 信息冗余

- **[ANCHOR-R1-1] SidebarHealthCard 与 Overview/顶栏信息重复**：
  - `Sources/PulseDockApp/DashboardView.swift:323-349` — 侧栏底部 "Live Sampling" 卡片展示：thermal 圆点 + sampleTimeText + CPU 值/进度 + Memory 值/进度 + Disk 值/进度
  - `Sources/PulseDockApp/DashboardView.swift:409` — 顶栏 `DataChip(icon:"clock", text: dashboardSampleChip(snapshot.sampleTimeText))` 已展示采样时间
  - `Sources/PulseDockApp/DashboardView.swift:431-434` — Overview 页 MetricCard 已展示 CPU/Memory/Network/Power 值+进度条+趋势（更详细）
  - 冗余：sampleTimeText 完全重复；CPU/Memory/Disk 是 Overview MetricCard 的缩小版，无新增信息。唯一价值是切到非 Overview 页时侧栏仍可见快照——但 Overview 是默认首页，且顶栏采样时间常驻。
  - 待审延伸：是否存在其他"侧栏/顶栏常驻元素"与"页面主体"信息重复的模式。

- **[ANCHOR-R1-2] sampleTimeText 在 6 处展示**：
  - `DashboardView.swift:333`（侧栏卡片）/ `:409`（顶栏 chip）/ `:560`（CPU 页 KeyValueGrid）/ `:840`（Power 页 StatusSummaryRow）/ `:1019`（Sensors 页 SourceCapabilityCard）/ `:1196`（Settings 页 widget 预览 KeyValueGrid）
  - `WidgetPanelView.swift:112`（popover）/ `SystemDashboardWidget.swift:186,216,264`（widget header 用 sampleClockText）
  - 冗余：同一采样时间在 app 内 6 处 + widget 3 处展示。顶栏 chip 已常驻可见，页面内再展示无新增价值（除非页面关注的是"该指标的最后采样时间"而非"整体采样时间"，但当前所有位置用的是同一个 `snapshot.sampleTimeText`）。

- **[ANCHOR-R1-3] 同一规则表在 Sensors 页与 History 页重复渲染**：
  - `DashboardView.swift:967-978` — Sensors 页 `localRuleTableTitle` 面板，4 行规则（CPU/Memory/Disk/Network）
  - `DashboardView.swift:1069-1080` — History 页 `localRuleTableTitle` 面板，**完全相同的 4 行规则**
  - 冗余：两页渲染同一份阈值规则评估结果，行数据完全相同（已在 LOGIC-CONSISTENCY-REVIEW-PLAN L1-4 指出话术不一致，本计划关注**数据渲染重复**）。用户切到 History 页看到的规则表与 Sensors 页完全一样。

- **[ANCHOR-R1-4] TrendRow 在 Overview/History/Sensors/CPU/Memory/Network/Power 多页重复列同指标**：
  - `DashboardView.swift:468-472` — Overview 趋势面板：CPU/Load/Memory/Network/Disk 5 行 TrendRow
  - `DashboardView.swift:1050-1057` — History 页趋势面板：CPU/Load/Memory/Network/Disk/Thermal/Uptime/Power 8 行 TrendRow（含 Overview 的 5 行 + 3 行）
  - `DashboardView.swift:1048` — History 页还有独立 Sparkline（CPU）
  - 冗余：Overview 的 5 行 TrendRow 在 History 页完全重复（同 history 数据源、同 cpuTrendValues 等提取器）。History 页是 Overview 趋势面板的超集，Overview 趋势面板的存在价值需评估。

- **[ANCHOR-R1-5] Settings 页 Widget 预览面板与顶栏/Refresh 面板信息重复**：
  - `DashboardView.swift:1167` — Refresh & Display 面板：Widget Refresh 行 "5m" / "Scheduled by the system timeline"
  - `DashboardView.swift:1188-1199` — Widget 预览面板：WidgetMiniPreview + KeyValueGrid(Size/Data Source/Refresh/Sample/History/Main Window)
  - 冗余：Widget Refresh 事实在 Settings 页两面板重复展示（已在 LOGIC-CONSISTENCY L1-1 指出话术冲突，本计划关注**信息重复**）。WidgetMiniPreview 预览 widget 外观有一定价值，但 KeyValueGrid 的 Refresh/Sample 行与左面板重复。

### R2 类 — 代码重复

- **[ANCHOR-R2-1] normalizedRate/reportedProgress/progressFillWidth 三处独立维护**：
  - `DashboardView.swift:2148-2157` — app 侧
  - `WidgetPanelView.swift:132-136, 311` — popover 侧
  - `SystemDashboardWidget.swift:771-776` — widget 侧
  - 重复：三个文件各有一份 `normalizedRate`/`reportedProgress`/`progressFillWidth` 实现，逻辑完全相同。任一处修改不会自动传播到其他处。（前次 REVIEW-PLAN P2-4 已记录，本计划确认仍未修复并扩展影响分析）

- **[ANCHOR-R2-2] thermalTint/networkTint 三处独立维护**：
  - `WidgetPanelView.swift:159-180` — Palette 版
  - `SystemDashboardWidget.swift:736-745` — WidgetColor 版
  - `DashboardView.swift:2321-2334` — thermalStatus/thermalProgress（StatusLevel 版，语义略不同但逻辑同源）
  - 重复：同一 thermalState/networkPathStatus → 颜色/进度映射在三处独立 switch，含相同的死分支（fair/serious/requires_connection，见 LOGIC-CONSISTENCY LC-6）。

- **[ANCHOR-R2-3] Palette/DashboardColor/WidgetColor 三套颜色系统**：
  - `WidgetPanelView.swift:318` — `enum Palette`
  - `DashboardVisualTokens.swift:53` — `enum DashboardColor`
  - `WidgetVisualTokens.swift:39` — `enum WidgetColor`
  - 重复：三套颜色枚举各自定义 green/blue/amber/red/cyan/purple/muted 等语义颜色，值可能相同或略不同（如 Sidebar 的 muted 与 widget 的 muted 色值不同）。无单一来源保证跨模块颜色语义一致。（前次 REVIEW-PLAN P2-4 已记录）

- **[ANCHOR-R2-4] trend 提取器 O(n) 重复调用无 memoization**：
  - `DashboardView.swift:2180-2222` — cpuTrendValues/memoryTrendValues/diskTrendValues/networkTrendValues/powerTrendValues/loadTrendValues/thermalTrendValues/uptimeTrendValues
  - `DashboardView.swift:424-427` — OverviewPage body 顶部 `let cpuTrend = cpuTrendValues(from: history)` 计算 4 个趋势
  - `DashboardView.swift:468-472` — overviewTrendPanel 内又调用 `loadTrendValues(from: history)` / `diskTrendValues(from: history)`（未在顶部 let 缓存）
  - `DashboardView.swift:1040-1043` — HistoryPage body 顶部又计算 4 个趋势（与 OverviewPage 部分重叠）
  - 重复：同一 history 的同一趋势在多页 body 中重复计算，每次 O(n) 遍历最多 360 snapshot。（前次 REVIEW-PLAN P1-5 已记录性能维度，本计划关注**计算重复**而非性能）

- **[ANCHOR-R2-5] "Not reported" 在三套 strings 表各自定义**：
  - `PulseDockAppStrings.swift:1070-1071` — `notReported = "Not reported"`
  - `SharedMetricStrings.swift:4-5` — `notReported = "Not reported"`
  - `PulseDockWidgetStrings.swift:84-85` — `notReported = "Not reported"`
  - 重复：同一 defaultValue "Not reported" 在三套 strings 表各定义一份，三处 localization key 不同但 default 值相同。（已在 LOGIC-CONSISTENCY L1-9 指出双术语问题，本计划关注**定义重复**）

### R3 类 — 死状态/死代码

- **[ANCHOR-R3-1] isRefreshing 声明但无视图消费**：
  - `MetricsStore.swift:47` — `private(set) var isRefreshing = false`（非 @Published）
  - `MetricsStore.swift:326,336,347` — 设置 true/false
  - 死状态：`isRefreshing` 被赋值但无任何视图读取它来显示"刷新中"状态。非 @Published 意味着即使读取也不会触发更新。（前次 REVIEW-PLAN P1-6 已记录"死状态触发额外渲染"，本计划确认其**完全无消费者**）

- **[ANCHOR-R3-2] networkBytesPerSecond 在 widgetCompact 保留但 widget 不读取**：
  - `MetricSnapshot+WidgetCompact.swift:29,41,42` — 保留 networkBytesPerSecond/networkInBytesPerSecond/networkOutBytesPerSecond
  - `SystemDashboardWidget.swift` 全文 — 不读取 networkText/networkInText/networkOutText
  - 死数据：三个 UInt64 + 两个 Bool 在每次 shared store 写入时被序列化（每 60s），widget 解码后丢弃。（前次 LOGIC-CONSISTENCY L3-15 已记录）

- **[ANCHOR-R3-3] powerSourceNoBattery "No Battery" 分支不可达**：
  - `MetricSnapshot.swift:1269-1274` — `case .some(let value) where !value.isEmpty` 捕获所有非空字符串，`default` 内 `guard batteryPowerSource != nil` 必定失败
  - 死代码：`return SharedMetricStrings.powerSourceNoBattery` 永不执行，本地化字符串永不展示。（前次 LOGIC-CONSISTENCY L4-7 已记录）

- **[ANCHOR-R3-4] design/ vs designs/ 目录冗余**：
  - 项目根目录同时存在 `design/` 和 `designs/` 两个设计资产目录
  - 死资源：需确认两目录内容是否冗余，是否有 gitignore 遗漏。（前次 REVIEW-PLAN P2-28 已记录）

---

## 四、审查方法与子任务划分

沿用项目已验证的并行子 agent 结构，按"信息冗余/代码重复/死状态"三维度切分。

```
顶层复核（本计划产出最终冗余清单）
  ├─ 逐条对照源码验证子 agent 发现（重点区分"真冗余"与"有意冗余"）
  ├─ 区分"真冗余"与"有意冗余"（如顶栏常驻采样时间是有意冗余，侧栏卡片重复是无意冗余）
  └─ 生成 信息冗余表 + 代码重复矩阵 + 死状态清单
        ↑
中层整合（middle/redundancy-integrated.md）
  ├─ 收集 4 份子 agent 报告
  ├─ 跨模块重复模式识别（同一逻辑在 app/widget/shared 三处维护的模式）
  └─ 冗余优先级评估（用户影响 / 维护成本 / 修复风险）
        ↑
子层逐处审查（subagents/redundancy-*, 并行）
  ├─ R1-info-redundancy.md   → 信息冗余专项（UI 数据点重复展示）
  ├─ R2-code-duplication.md  → 代码重复专项（函数/常量/颜色系统重复）
  ├─ R3-dead-state.md        → 死状态/死代码/死资源专项
  └─ R4-cross-module.md      → 跨模块重复模式（app/widget/shared 三处维护的同一逻辑）
```

**并行执行要求**：4 个子 agent 在单消息中并发派发，每个指定 `very thorough`，返回 `file_path:line_number` 引用，prompt 末尾强制约束"**最终消息必须是完整报告，不得截断，不得以过渡语结尾**"。

---

## 五、子任务详细清单

### 子任务 R1 — 信息冗余专项

**目标文件**：`DashboardView.swift`、`WidgetPanelView.swift`、`AppDelegate.swift`、`SystemDashboardWidget.swift`

**审查方法**：
1. **建立数据点清单**：列出 `MetricSnapshot` 所有用户可见的数据点（cpuText/memoryUsageText/diskUsageText/networkText/sampleTimeText/thermalText/powerStatusText/loadText/uptimeText/osVersionText 等）。
2. **追踪每个数据点的全部展示位置**：在 app（侧栏/顶栏/各页面/Settings）+ widget（Small/Medium/Large/header）中找到所有展示该数据点的视图。
3. **评估冗余度**：对每个数据点的多个展示位置，判断后一处相对前一处是否有新增价值（更细粒度/不同视角/不同时间窗/不同上下文）。无新增价值 = 冗余。

**必查项**：
- [ANCHOR-R1-1] SidebarHealthCard 与 Overview/顶栏重复
- [ANCHOR-R1-2] sampleTimeText 6 处展示
- [ANCHOR-R1-3] Sensors/History 同一规则表重复渲染
- [ANCHOR-R1-4] TrendRow 在 Overview/History 多页重复列同指标
- [ANCHOR-R1-5] Settings 页 Widget 预览与 Refresh 面板信息重复
- cpuText 在 Overview MetricCard + Overview TrendRow + CPU 页 + History TrendRow + 侧栏 5 处展示
- memoryUsageText 在 Overview MetricCard + Overview TrendRow + Memory 页 + History TrendRow + 侧栏 5 处展示
- diskUsageText 在 Overview StatusRow + Overview TrendRow + Storage 页 + History TrendRow + 侧栏 5 处展示
- networkPathText 在 Overview StatusRow + Network 页 + Sensors 信号表 + History 规则表 + 侧栏(间接) 多处展示
- thermalText 在 Overview StatusRow + Sensors 热面板 + Sensors 信号表 + History TrendRow 多处展示
- powerStatusText 在 Overview MetricCard + Power 页 + Sensors 信号表 + History TrendRow 多处展示
- osVersionText 在 Overview StatusPanel subtitle + Sensors 信号表 多处展示
- WidgetMiniPreview 是否与实际 widget 渲染重复（同一 snapshot 在 app 内预览 + 桌面 widget 实际展示）

**输出**：数据点 × 展示位置矩阵 + 冗余评估表

### 子任务 R2 — 代码重复专项

**目标文件**：`DashboardView.swift`、`WidgetPanelView.swift`、`SystemDashboardWidget.swift`、`DashboardVisualTokens.swift`、`WidgetVisualTokens.swift`、`MetricFormatting.swift`、`MetricScales.swift`、`MetricSnapshot.swift`

**审查方法**：
1. **提取所有 private/free 函数**：列出每个文件中的 `private func` 和文件级 `func`。
2. **比对函数签名与实现**：跨文件查找签名相同或语义相同的函数（如 `reportedProgress`/`progressFillWidth`/`normalizedRate`/`thermalTint`/`networkTint`/`networkPathProgress`）。
3. **提取所有常量/枚举**：跨文件查找语义相同的常量（如颜色 green/blue/amber、布局间距、面板圆角）。
4. **评估合并可行性**：哪些重复可以提取到 SharedMetrics 或共享 tokens 模块，哪些因模块边界无法合并（app 不能依赖 widget tokens）。

**必查项**：
- [ANCHOR-R2-1] normalizedRate/reportedProgress/progressFillWidth 三处
- [ANCHOR-R2-2] thermalTint/networkTint 三处
- [ANCHOR-R2-3] Palette/DashboardColor/WidgetColor 三套颜色
- [ANCHOR-R2-4] trend 提取器重复调用
- [ANCHOR-R2-5] "Not reported" 三套 strings 表
- thermalStatus/thermalProgress 在 DashboardView 与 MetricSnapshot 的 thermalText/thermalLimitText 逻辑重复
- networkStatusLevel/networkPathProgress 在 DashboardView 与 SystemDashboardWidget 重复
- powerGaugeProgress/powerTint 在 DashboardView 内多处使用但定义是否单一
- MetricFormatting 与 SharedMetricStrings.localizedFormat 的格式化逻辑分散
- DashboardLayout/DashboardSpacing/DashboardTypography 与 widget 侧布局常量重复

**输出**：重复函数矩阵 + 重复常量矩阵 + 合并可行性评估

### 子任务 R3 — 死状态/死代码/死资源专项

**目标文件**：`MetricsStore.swift`、`MetricSnapshot.swift`、`MetricSnapshot+WidgetCompact.swift`、`SharedSnapshotStore.swift`、`AppDelegate.swift`、项目根目录

**审查方法**：
1. **死状态**：列出所有 `@Published`/`private(set) var`/`@State`/`@Binding` 声明，搜索每个状态变量是否被任何视图读取。仅被赋值不被读取 = 死状态。
2. **死分支**：列出所有 switch/if 的 default 分支和 case 分支，搜索是否可达（结合 LOGIC-CONSISTENCY L2 的死分支清单，扩展到非字符串字面量分支）。
3. **死字段**：列出 `MetricSnapshot` 所有字段，追踪哪些在 widgetCompact 裁剪后被保留但从不被 widget 读取。
4. **死资源**：检查 `design/` vs `designs/`、`dist/` 残留、未引用的 Resources 资源。

**必查项**：
- [ANCHOR-R3-1] isRefreshing 死状态
- [ANCHOR-R3-2] networkBytesPerSecond 死数据
- [ANCHOR-R3-3] powerSourceNoBattery 死分支
- [ANCHOR-R3-4] design/ vs designs/ 目录
- `recentSnapshots`（MetricsStore.swift:45）是否被任何视图消费（vs `history`）
- `showsMenuBarCPU`（MetricsStore.swift:53）是否真的驱动 menu bar CPU 显示
- AppDelegate 的 `Selector(("undo:"))`/`Selector(("redo:"))`（前次 REVIEW-PLAN P2-19 已标记为有效 responder-chain selectors，确认）
- widgetCompactSnapshot 保留的 networkPathSupportsDNS/IPv4/IPv6 等字段是否被 widget 读取
- widgetCompactSnapshot 保留的 memorySwap* 字段是否被 widget 读取
- `schemaVersion` 字段（L3-11 已记录存在但不校验）
- `batteryTimeRemainingMinutes`/`batteryCurrentCapacity`/`batteryMaxCapacity` 在 widgetCompact 保留但 widget 是否读取
- `loadAverage5`/`loadAverage15` 是否在 UI 展示（vs `loadAverage` 1min）
- `activeProcessorCount` 是否在 UI 直接展示（vs `logicalCoreCount`）
- `dist/` 目录是否纳入版本控制

**输出**：死状态清单 + 死分支清单 + 死字段清单 + 死资源清单

### 子任务 R4 — 跨模块重复模式专项

**目标文件**：全模块，重点 app/widget/shared 三处维护的同一逻辑

**审查方法**：识别"同一逻辑在 app/widget/shared 三个模块各自维护一份"的模式，评估是否可通过提取到 SharedMetrics 或共享 tokens 消除。

**必查项**：
- thermalState → 颜色映射：app `thermalStatus`/`thermalProgress` + popover `thermalTint` + widget `thermalTint`（三处 switch，含相同死分支）
- networkPathStatus → 颜色/进度映射：app `networkStatusLevel`/`networkPathProgress` + popover `networkTint` + widget `networkTint`/`networkPathProgress`（三处 switch）
- reportedProgress 模式：app + popover + widget 三处 `reportedProgress(hasReport:progress:) -> Double?`
- progressFillWidth 模式：app + popover + widget 三处 `progressFillWidth(progress:in:minimumVisibleWidth:) -> CGFloat`
- 颜色语义：app `DashboardColor` + popover `Palette` + widget `WidgetColor`（三套 green/blue/amber/red/cyan）
- "Not reported" 话术：app `PulseDockAppStrings.notReported` + shared `SharedMetricStrings.notReported` + widget `PulseDockWidgetStrings.notReported`
- 网络速率 scale：app `MetricScales.networkRateProgress` vs widget `networkPathProgress`（不同 scale 函数，已在 L3-9 指出单位混用）
- powerStatusText 展示：app `powerStatusText` vs widget `compactPowerStatusText`（已在 L4-13 指出同状态两套输出）
- 格式化 locale：`MetricFormatting` C locale vs `SharedMetricStrings.localizedFormat` Locale.current（已在 L3-13 指出）
- 验证哪些重复因模块边界（app 不能依赖 widget）无法合并，哪些可提取到 SharedMetrics

**输出**：跨模块重复模式矩阵 + 可合并性评估（可提取到 SharedMetrics / 需保持独立 / 无法合并的原因）

---

## 六、优先级定义

本计划优先级独立于前两次审查，聚焦"用户可感知的信息冗余"与"维护成本":

| 级别 | 标准 | 示例 |
|------|------|------|
| R-高 | 同屏可见的信息冗余（用户直接注意到重复），或死状态导致额外渲染 | R1-1 侧栏卡片与 Overview 重复 |
| R-中 | 跨页面信息冗余（切页后发现重复），或代码重复导致 rename 静默分歧风险 | R1-3 Sensors/History 同表重复 / R2-1 三处 reportedProgress |
| R-低 | 死字段/死资源（无用户可见影响，仅维护成本） | R3-2 networkBytesPerSecond 死数据 / R3-4 design/ 目录 |

---

## 七、执行步骤

### 阶段 1：并发派发 4 个子 agent（单消息）
每 agent 读取对应文件全集，按上述"审查方法"输出结构化报告。强制完整报告、不截断。

### 阶段 2：中层整合
- 收集 4 份报告 → `docs/review/middle/redundancy-integrated.md`
- 生成三张主表：
  1. **数据点 × 展示位置矩阵**：每个用户可见数据点在 app/widget 的全部展示位置 + 冗余度
  2. **代码重复矩阵**：每个重复函数/常量的 N 处位置 + 合并可行性
  3. **死状态/死字段清单**：每个死项的声明位置 + 确认无消费者
- 识别跨模块系统性重复模式

### 阶段 3：顶层复核
- 对照源码验证每条发现，重点区分"真冗余"与"有意冗余"：
  - **有意冗余**（保留）：顶栏常驻采样时间（用户切页时仍可见）= 有意冗余；widget header 时间（独立进程，无法读 app 顶栏）= 有意冗余
  - **真冗余**（可移除）：侧栏卡片与 Overview 重复 = 真冗余；Sensors/History 同表 = 真冗余
- 标注已被前两次审查覆盖项
- 生成 `docs/review/top/redundancy-final.md`：冗余清单 + 修复优先级 + 移除建议

### 阶段 4：验证
对每条 R-高问题，要求给出：
- 冗余的两处（或多处）位置
- 后一处相对前一处是否有新增价值
- 移除后是否有副作用（如切到非 Overview 页时侧栏不再显示快照）
- 修复建议（移除 / 合并 / 保留但标注有意冗余）

---

## 八、验证命令

```bash
swift build
swift test
scripts/audit-localization.sh
```

**关键验证点**：
1. `swift test` 通过（确认审查期间无回归）
2. `audit-localization.sh` 报告的未使用键是否覆盖本计划发现的死话术定义

---

## 九、约束与边界

- **只审查，不修改源码**（除非用户明确指示修复）
- 不引入新功能、新依赖
- 区分"真冗余"与"有意冗余"：跨进程边界（app vs widget）的重复属有意冗余（无法共享代码/状态）；同进程内重复需评估
- 与 `LOGIC-CONSISTENCY-REVIEW-PLAN.md` 重叠项（L3-15/L4-7/L1-12）标注引用关系，不重复定级
- 与 `REVIEW-PLAN.md` 重叠项（P2-4/P2-1/P1-6）标注引用关系
- 修复建议优先选择"提取到 SharedMetrics"而非"再复制一份"

---

## 执行 Checklist

- [ ] 阶段 1：并发派发 4 个子 agent（R1-R4），收集 4 份子报告
- [ ] 阶段 2：中层整合，生成数据点 × 展示位置矩阵 + 代码重复矩阵 + 死状态清单
- [ ] 阶段 3：顶层复核，区分真冗余与有意冗余，标注与前两次审查重叠项
- [ ] 阶段 4：为每条 R-高问题给出冗余位置 + 移除建议
- [ ] 输出 `docs/review/top/redundancy-final.md` 最终清单
- [ ] 运行 `swift build` + `swift test` 确认基线
- [ ] 检查 `design/` vs `designs/` 目录冗余
