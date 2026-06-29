# Pulse Dock 前端冗余显示全面审查计划

> 制定日期：2026-06-29
> 审查目标：系统扫描整个前端 UI，发现所有"同一数据在多处展示无新增价值"的设计冗余
> 审查基准：当前 working tree（HEAD `876bcc2`，含前三轮审查修复）
> 触发缘由：侧栏 `SidebarHealthCard`（"Live Sampling"卡片）仍在渲染 CPU/Memory/Disk 三行，与 Overview MetricCard 重复。用户要求全面排查是否还有类似冗余。
> 关联资产：
> - `docs/review/REDUNDANCY-REVIEW-PLAN.md`（冗余与重复专项 —— 已执行，R1 信息冗余 9 条）
> - `docs/review/top/redundancy-final.md`（冗余最终清单 —— R-高 7 条已修复，R-中/R-低 部分未修）
> - `docs/superpowers/plans/2026-06-29-frontend-redundancy-cleanup.md`（上一版清理计划 —— 仅覆盖 6 处已知冗余，非全面审查）

---

## 一、为什么需要本次审查

前次 `REDUNDANCY-REVIEW-PLAN.md` 的 R1 子任务已发现 9 条信息冗余，但：
1. R-高 2 条（R1-3 规则表跨页、R1-6 Sensors 同页 8 项重叠）已修复，**R-中 4 条和 R-低 3 条多数未修**
2. 前次审查以"数据点 × 展示位置矩阵"方法扫描，但**未深入页面内部结构**——如同一页面内 KeyValueGrid 与 ResponsiveTable 列出完全相同的 9 行数据、MetricCard 与紧邻的 TrendRow 展示相同值+趋势
3. 侧栏 `SidebarHealthCard` 在前次审查中被判定为"有意冗余"（切页时常驻可见），但用户认为没必要——说明**前次"有意冗余"判定标准过宽松**，需重新审视

本次审查**换一个角度**：不按数据点追踪，而是**按页面结构**逐页扫描，找出每页内部"同页重复"和跨页"纯冗余子集"。

---

## 二、审查范围

| 页面 | 路径 | 行号区间 | 重点 |
|------|------|---------|------|
| 侧栏 | `DashboardView.swift` SidebarHealthCard | :226-348 | 常驻元素与各页重复 |
| 顶栏 | `DashboardView.swift` DashboardTopBar | :350-413 | 常驻 chip 与页面内重复 |
| Overview | `DashboardView.swift` OverviewPage | :414-493 | 趋势面板 ⊂ History / WidgetPreview = Settings / StatusPanel 与各页 |
| CPU | `DashboardView.swift` CPUPage | :495-564 | Recent Sample 行 / processorPanel 与 Overview |
| Memory | `DashboardView.swift` MemoryPage | :566-634 | KeyValueGrid 与 compositionPanel StatLine 重复 / ProcessListPanel 与 Processes 页 |
| Storage | `DashboardView.swift` StoragePage | :636-689 | TrendRow 与 Overview / SourceCapabilityCard 与 Sensors |
| Network | `DashboardView.swift` NetworkPage | :691-758 | MetricCard 与连通性表首行 / TrendRow 与 MetricCard / MetricCard 与 Overview |
| Power | `DashboardView.swift` PowerPage | :760-843 | KeyValueGrid 与 Battery Information 表 9 行重复 / thermalPanel 与 Sensors thermalPanel / thermalPanel uptime/sampleTime 错位 |
| GPU/Display | `DashboardView.swift` GPUDisplayPage | :845-911 | SourceCapabilityCard 与 Sensors 信号卡 |
| Processes | `DashboardView.swift` ProcessesPage | :913-942 | SummaryCard 与 ProcessListPanel / 4 卡语义重叠 |
| Sensors | `DashboardView.swift` SensorsPage | :944-1008 | realtimeSignalsPanel 11 卡与各 dedicated 页 / thermalPanel 与 Power thermalPanel / 规则表（已修） |
| History | `DashboardView.swift` HistoryAlertsPage | :1010-1049 | 趋势面板 8 行 / ThresholdControlRow 与 Sensors 规则表 |
| Settings | `DashboardView.swift` SettingsPage | :1051-1201 | WidgetPreviewPanel 与 Overview / KeyValueGrid 与 refreshDisplayPanel |
| Popover | `WidgetPanelView.swift` | :1-339 | 与 dashboard 同一数据（跨入口有意冗余，但需确认无内部冗余） |

---

## 三、探索阶段已确认的锚点发现（12 处）

> 以下为本次探索逐页扫描已确认的冗余，作为审查种子。标注 `[ANCHOR]` = 已直接定位到行号。

### [ANCHOR-F1] 侧栏 SidebarHealthCard 与 Overview MetricCard 重复
- `DashboardView.swift:325-348` — CPU/Memory/Disk 三行 CompactMetricLine
- `DashboardView.swift:430-433` — Overview MetricCard 展示相同 CPU/Memory/Disk（更详细，含 sparkline + badgeText + detail）
- **判定**：真冗余。前次判定"有意冗余"过宽松，用户确认没必要

### [ANCHOR-F2] CPU 页/Power 页 "Recent Sample" 行与顶栏 chip 重复
- `DashboardView.swift:559` — CPU 页 loadPanel `(cpuRecentSampleLabel, sampleTimeText)`
- `DashboardView.swift:839` — Power 页 thermalPanel `StatusSummaryRow(cpuRecentSampleLabel, sampleTimeText)`
- `DashboardView.swift:408` — 顶栏 `DataChip(icon: "clock", dashboardSampleChip(sampleTimeText))` 常驻
- **判定**：真冗余。顶栏每页可见

### [ANCHOR-F3] Overview 趋势面板 5 行是 History 趋势面板 8 行的纯子集
- `DashboardView.swift:464-474` — overviewTrendPanel 5 行 TrendRow（CPU/Load/Memory/Network/Disk）
- `DashboardView.swift:1026-1038` — History 趋势面板 8 行 TrendRow（含 Overview 的 5 行 + Thermal/Uptime/Power）
- **判定**：真冗余。Overview MetricCard 已含 sparkline 提供趋势预览

### [ANCHOR-F4] Power 页 KeyValueGrid 与 Battery Information 表 9 行完全重复
- `DashboardView.swift:819-829` — powerDetails KeyValueGrid 9 行：(powerSource, powerSourceText) / (batteryRemainingTime, ...) / (currentCapacity, ...) / (maxCapacity, ...) / (cycleCount, ...) / (health, ...) / (designCapacity, ...) / (voltage, ...) / (amperage, ...)
- `DashboardView.swift:778-787` — Battery Information ResponsiveTable 8 行：完全相同的 8 个字段（仅少了 powerSource 行，多了 source 列）
- **判定**：真冗余。同一页面内 KeyValueGrid 与 ResponsiveTable 展示几乎完全相同的 8-9 个字段，仅列结构不同（2 列 vs 3 列）。用户在同页看到两份相同数据

### [ANCHOR-F5] Power 页 thermalPanel 与 Sensors 页 thermalPanel 重复
- `DashboardView.swift:833-841` — Power 页 thermalPanel：StatusSummaryRow(thermalText) + StatusSummaryRow(thermalLimitText) + StatusSummaryRow(uptime) + StatusSummaryRow(sampleTime)
- `DashboardView.swift:981-988` — Sensors 页 thermalPanel：RingGauge(thermalText) + StatusSummaryRow(thermalLimitText)
- **判定**：thermalText + thermalLimitText 两行在两页重复（Power 页用 StatusSummaryRow，Sensors 页用 RingGauge+StatusSummaryRow，但值相同）。Power 页的 uptime/sampleTime 是错位放置（与 F2 重叠）

### [ANCHOR-F6] Network 页 MetricCard 与 TrendRow 同值同趋势重复
- `DashboardView.swift:704-708` — 5 张 MetricCard（Download/Upload/Total/Connection/Interface），每张含 value + progress + sparkline(values)
- `DashboardView.swift:729-732` — Network 趋势面板 4 行 TrendRow（Total/Connection/Download/Upload），每行含 value + sparkline(values)
- **判定**：Total/Connection/Download/Upload 四个指标在 MetricCard（含进度条+sparkline）和 TrendRow（含 sparkline）中重复展示。MetricCard 更丰富，TrendRow 无新增价值

### [ANCHOR-F7] Network 页连接状态 MetricCard 与连通性表首行重复
- `DashboardView.swift:707` — MetricCard(networkConnectionStatusTitle, networkPathText, networkPathDetailText)
- `DashboardView.swift:715` — 连通性表首行 [networkPathLabel, networkPathText, networkPathDetailText]
- **判定**：真冗余。MetricCard 更丰富（含进度条+sparkline），表首行无新增价值

### [ANCHOR-F8] Overview WidgetPreviewPanel 与 Settings WidgetPreviewPanel 完全相同
- `DashboardView.swift:451-461` — Overview 页 WidgetPreviewPanel(snapshot)
- `DashboardView.swift:1185-1199` — Settings 页 widgetPreviewPanel(snapshot)
- **判定**：真冗余。两处用相同入参渲染完全相同的 WidgetMiniPreview。Settings 是配置上下文的自然位置

### [ANCHOR-F9] Memory 页 KeyValueGrid 与 compositionPanel StatLine 部分重复
- `DashboardView.swift:611-619` — memoryDetails KeyValueGrid 7 行：(total, memoryDetailText) / (free, memoryFreeText) / (cached, memoryCachedText) / (compressed, memoryCompressedText) / (swap, memorySwapText) / (swapAvailable, ...) / (swapTotal, ...)
- `DashboardView.swift:626-631` — compositionPanel 5 行 StatLine：(appActive, memoryActiveText) / (wired, memoryWiredText) / (compressed, memoryCompressedText) / (cachedFiles, memoryCachedText) / (swap, memorySwapText)
- **判定**：compressed/cached/swap 三项在 KeyValueGrid 和 compositionPanel 中重复（前者无进度条，后者有进度条）。需评估是否合并

### [ANCHOR-F10] Sensors 页 realtimeSignalsPanel 11 卡与各 dedicated 页重复
- `DashboardView.swift:991-1007` — 11 张 SourceCapabilityCard：CPU/Memory/Disk/Power/Network/Displays/GPU/StorageVolumes/Load/SystemVersion/Uptime
- 重复对象：CPU 页（cpuText）/ Memory 页（memoryUsageText）/ Storage 页（diskUsageText）/ Power 页（powerStatusText）/ Network 页（networkPathText）/ GPU 页（gpuSummaryText, displaySummaryText）/ History 趋势（loadText, uptimeText）/ Overview StatusPanel（osVersionText, thermalText）
- **判定**：前次 R1-6 已修复"SystemSignals 表与 realtimeSignalsPanel 8 项重叠"（合并了表），但 **realtimeSignalsPanel 自身的 11 卡与各 dedicated 页的重复未处理**。Sensors 页作为"信号汇总"与各 dedicated 页是"摘要 vs 详情"关系，有一定有意冗余成分，但 11 卡全量重复可能过度

### [ANCHOR-F11] Memory 页/Power 页 ProcessListPanel 与 Processes 页重复
- `DashboardView.swift:521` — CPU 页 `ProcessListPanel(processes: snapshot.runningApps, ...)`
- `DashboardView.swift:581` — Memory 页 `ProcessListPanel(processes: snapshot.runningApps, ...)`
- `DashboardView.swift:926-939` — Processes 页 `ResponsiveTable(processesTableColumns, ...)` 展示相同 runningApps
- **判定**：CPU 页和 Memory 页都嵌入 ProcessListPanel，与 Processes 页展示相同 runningApps 列表。CPU/Memory 页的 ProcessListPanel 是"进程列表作为 CPU/Memory 上下文"，Processes 页是"完整进程列表"。需评估是否冗余

### [ANCHOR-F12] Overview StatusPanel 10 行与各 dedicated 页重复
- `DashboardView.swift:477-491` — 10 行 StatusSummaryRow：thermal/uptime/kernel/cpu/mem/load/runningApps/network/gpuDisplay/diskAvailable
- 重复对象：Sensors thermalPanel（thermal）/ Power thermalPanel（thermal）/ CPU 页（cpuText）/ Memory 页（memoryUsageText）/ Network 页（networkPathText）/ GPU 页（gpuSummaryText, displaySummaryText）/ Storage 页（diskUsageText）
- **判定**：前次审查判定 Overview StatusPanel 是"一屏概览摘要模式"=有意冗余。但 10 行全量重复各 dedicated 页，且 Overview 已有 4 张 MetricCard 摘要，StatusPanel 是否过度值得重新审视

---

## 四、审查方法

### 方法：逐页结构扫描

不同于前次 R1 的"数据点 × 展示位置矩阵"（自底向上），本次采用**自顶向下逐页扫描**：

1. **逐页绘制结构图**：对每个页面，列出其包含的所有面板/卡片/表格/行，标注每个元素展示的数据点
2. **同页内重复检测**：同一页面内是否有两个元素展示相同数据点（如 Power 页 KeyValueGrid vs Battery Information 表）
3. **跨页子集检测**：某页的元素是否是另一页元素的纯子集（如 Overview 趋势 ⊂ History 趋势）
4. **跨页错位检测**：某页是否展示了与该页主题无关的数据（如 Power 页 thermalPanel 展示 uptime/sampleTime）
5. **常驻元素重复检测**：侧栏/顶栏常驻元素与各页内元素是否重复（如 SidebarHealthCard vs Overview MetricCard）

### 冗余判定标准（收紧版）

前次审查对"有意冗余"判定过宽松，本次收紧：

| 判定 | 标准 | 示例 |
|------|------|------|
| **真冗余（移除）** | 同页内两元素展示相同数据且后者无新增价值；或跨页前者是后者纯子集 | Power 页 KeyValueGrid vs Battery 表 9 行；Overview 趋势 ⊂ History |
| **错位（移除/重新归位）** | 某页展示了与该页主题无关的数据，且已在更合适的页面展示 | Power 页 thermalPanel 的 uptime/sampleTime |
| **有意冗余（保留）** | 跨进程/跨入口/常驻 chrome，用户在不同上下文需要看到同一数据 | 顶栏 sampleTimeText 常驻；Popover 与 dashboard；Widget 与 app |
| **摘要 vs 详情（保留）** | 摘要面板展示聚合值，详情页展示分项，两者粒度不同 | Overview MetricCard（聚合百分比+sparkline）vs CPU 页（per-core + load average） |
| **需权衡（讨论）** | 摘要面板展示与详情页相同粒度值，但提供"一屏概览"体验 | Overview StatusPanel 10 行 vs 各 dedicated 页；Sensors realtimeSignalsPanel 11 卡 |

---

## 五、子任务划分

```
顶层复核（本计划产出最终冗余清单 + 移除建议）
  ├─ 逐条对照源码验证子 agent 发现
  ├─ 区分"真冗余"与"有意冗余"与"需权衡"
  └─ 生成 页面结构图 + 冗余清单 + 移除方案
        ↑
中层整合（middle/frontend-redundancy-integrated.md）
  ├─ 收集 3 份子 agent 报告
  ├─ 逐页绘制结构图 + 标注冗余
  └─ 跨页系统性冗余模式识别
        ↑
子层逐页扫描（subagents/frontend-*, 并行）
  ├─ F1-page-internal.md   → 同页内重复（KeyValueGrid vs Table / MetricCard vs TrendRow）
  ├─ F2-cross-page.md      → 跨页子集与错位（Overview ⊂ History / Power thermalPanel 与 Sensors）
  └─ F3-chrome-redundancy.md → 常驻元素重复（侧栏/顶栏与页面内）+ 摘要面板合理性
```

---

## 六、子任务详细清单

### 子任务 F1 — 同页内重复专项

**目标**：逐页扫描每个页面内部是否有两个元素展示相同数据点。

**必查页**：
- Power 页：KeyValueGrid（:819-829）vs Battery Information 表（:778-787）— 9 行重复
- Network 页：MetricCard 5 张（:704-708）vs TrendRow 4 行（:729-732）— 4 指标重复
- Network 页：MetricCard Connection（:707）vs 连通性表首行（:715）
- Memory 页：KeyValueGrid（:611-619）vs compositionPanel StatLine（:626-631）— compressed/cached/swap 重复
- CPU 页：processorPanel 大数 cpuText（:529）vs loadPanel StatLine loadText（:549）— 不同指标但同页两处大数展示
- Settings 页：refreshDisplayPanel（:1131-1170）vs widgetPreviewPanel KeyValueGrid（:1159-1168）— Refresh/MainWindow 重复
- History 页：趋势面板 TrendRow 8 行（:1030-1037）vs ThresholdControlRow 3 行（:1043-1045）— 趋势与阈值是不同维度，但阈值行 cpuText/mem/disk 在趋势面板也有

**输出**：每页结构图 + 同页重复清单

### 子任务 F2 — 跨页子集与错位专项

**目标**：找出某页元素是另一页元素的纯子集，或某页展示了与主题无关的数据。

**必查项**：
- Overview 趋势面板 5 行 ⊂ History 趋势面板 8 行
- Overview WidgetPreviewPanel = Settings WidgetPreviewPanel
- Overview StatusPanel 10 行 vs 各 dedicated 页
- Power 页 thermalPanel（thermalText + thermalLimitText）vs Sensors 页 thermalPanel（RingGauge thermalText + thermalLimitText）
- Power 页 thermalPanel uptime/sampleTime 错位
- CPU 页 ProcessListPanel vs Processes 页 ResponsiveTable
- Memory 页 ProcessListPanel vs Processes 页 ResponsiveTable
- Memory 页 ProcessListPanel subtitle（processesCurrentSessionSubtitle）vs CPU 页 ProcessListPanel subtitle（processesDefaultSubtitle）— 同数据不同 subtitle
- Storage 页 SourceCapabilityCard 3 张 vs Sensors realtimeSignalsPanel 卡片
- GPU 页 SourceCapabilityCard 3 张 vs Sensors realtimeSignalsPanel 卡片
- Sensors 页 realtimeSignalsPanel 11 卡 vs 各 dedicated 页
- History 页 ThresholdControlRow 3 行 vs Sensors 页规则表 4 行 — 阈值编辑 vs 阈值判定结果

**输出**：跨页子集矩阵 + 错位清单

### 子任务 F3 — 常驻元素与摘要面板合理性专项

**目标**：评估侧栏/顶栏常驻元素与页面内元素的重复，以及摘要面板（Overview StatusPanel / Sensors realtimeSignalsPanel）的全量重复是否过度。

**必查项**：
- 侧栏 SidebarHealthCard CPU/Mem/Disk vs Overview MetricCard — 重新审视（用户认为没必要）
- 顶栏 DataChip(sampleTimeText) vs CPU 页/Power 页 Recent Sample 行
- 顶栏 DataChip(refreshInterval.label) vs Settings refreshDisplayPanel Picker
- Overview StatusPanel 10 行 — 是否过度摘要（已有 4 张 MetricCard）
- Sensors realtimeSignalsPanel 11 卡 — 是否过度摘要（各 dedicated 页已覆盖）
- Processes 页 4 张 SummaryCard — "Displayed Apps" 是否是 UI 元数据而非系统指标（前次 L4-9 已提）
- History 页趋势面板 8 行 — 与 Overview MetricCard sparkline 重复度

**输出**：常驻元素重复评估 + 摘要面板合理性评估

---

## 七、优先级定义

| 级别 | 标准 | 示例 |
|------|------|------|
| F-高 | 同页内两元素展示完全相同数据（用户直接注意到重复），或跨页纯子集 | Power 页 KeyValueGrid vs Battery 表 9 行；Overview 趋势 ⊂ History |
| F-中 | 跨页错位/摘要面板全量重复/常驻元素与页面重复 | Power 页 thermalPanel uptime 错位；侧栏 vs Overview |
| F-低 | 摘要 vs 详情的合理重复但可优化 | Overview StatusPanel 部分行 |

---

## 八、执行步骤

### 阶段 1：并发派发 3 个子 agent（单消息）
每 agent 逐页扫描，输出结构化报告。

### 阶段 2：中层整合
- 收集 3 份报告 → `docs/review/middle/frontend-redundancy-integrated.md`
- 逐页绘制结构图
- 跨页系统性冗余模式识别

### 阶段 3：顶层复核
- 区分"真冗余"与"有意冗余"与"需权衡"
- 标注已被前次修复项（R1-3 规则表、R1-6 Sensors 表合并）
- 生成 `docs/review/top/frontend-redundancy-final.md`：冗余清单 + 移除方案 + 保留理由

### 阶段 4：验证
对每条 F-高问题，给出：
- 冗余的两处位置
- 后一处是否有新增价值
- 移除后副作用
- 修复方案（移除/合并/重新归位）

---

## 九、约束与边界

- **只审查，不修改源码**
- 区分"真冗余"与"有意冗余"：跨进程/跨入口/常驻 chrome 属有意冗余
- 收紧"有意冗余"判定标准：前次对侧栏 SidebarHealthCard 判定"有意冗余"已被用户否定，本次以"用户是否在该位置需要看到该数据"为准
- "摘要 vs 详情"重复需区分：摘要展示聚合值（如 MetricCard 百分比+sparkline）vs 详情展示分项（per-core/load average）= 有意冗余；摘要展示与详情相同粒度值 = 真冗余
- 与前次 REDUNDANCY-REVIEW-PLAN 重叠项标注引用关系

---

## 执行 Checklist

- [ ] 阶段 1：并发派发 3 个子 agent（F1/F2/F3）
- [ ] 阶段 2：中层整合，逐页绘制结构图
- [ ] 阶段 3：顶层复核，区分真冗余与有意冗余
- [ ] 阶段 4：为每条 F-高给出移除方案
- [ ] 输出 `docs/review/top/frontend-redundancy-final.md`
