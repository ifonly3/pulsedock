# F2 跨页子集与错位 — 报告

## 方法
对比不同页面的面板/元素，检查是否为纯子集或错位放置。按 `FRONTEND-REDUNDANCY-REVIEW-PLAN.md` 子任务 F2 清单逐项扫描 `DashboardView.swift`，使用 Read 工具精确定位行号区间。

扫描覆盖的源文件：
- `/Users/qiaoni/Code/Projects/xiaozujian/Sources/PulseDockApp/DashboardView.swift`（2263 行）

---

## 复核后处理结论

- F2-1 / FR-1：采纳，删除 Overview 趋势面板。
- F2-2 / FR-8：不直接删除 Power thermal 状态行，保留热状态与性能限制。
- F2-3 / FR-9：采纳，Power thermalPanel 删除 uptime/sampleTime。
- F2-4 / FR-19：保留，Overview 与 Settings 的 widget 预览语境不同。
- F2-5 / FR-14：采纳，Sensors realtimeSignalsPanel 精简到 CPU/Memory/Disk/Power/Network。
- F2-6 / FR-15：部分采纳，Overview StatusPanel 删除 CPU/Memory/Network，保留其余摘要行。
- F2-7 / FR-21：保留，编辑入口和判断展示职责不同。
- F2-8 / F2-9 / FR-22：通过 FR-14 间接减少。
- F2-10 / FR-6：采纳，删除 CPU/Memory 页面重复的 ProcessListPanel。
- F2-11 / FR-7：采纳。
- F2-12 / F2-13 / FR-16 / FR-17：采纳。

---

## 跨页结构对比图

### 对比：Overview 趋势面板 vs History 趋势面板
| 特性 | Overview 趋势面板 (:464-474) | History 趋势面板 (:1026-1038) |
|------|------------------------------|-------------------------------|
| 容器 | `overviewTrendPanel` (内联函数) | `DashboardPanel(historyTrendsTitle)` |
| 行数 | 5 行 TrendRow | 8 行 TrendRow + 1 个 Sparkline |
| CPU | `TrendRow(metricCPU, cpuText)` (:467) | `TrendRow("CPU", cpuText)` (:1030) |
| Load | `TrendRow(metricLoad, loadText)` (:468) | `TrendRow(metricLoad, loadText)` (:1031) |
| Memory | `TrendRow(metricMemory, memoryUsageText)` (:469) | `TrendRow(metricMemory, memoryUsageText)` (:1032) |
| Network | `TrendRow(metricNetwork, networkText)` (:470) | `TrendRow(metricNetwork, networkText)` (:1033) |
| Disk | `TrendRow(metricDisk, diskUsageText)` (:471) | `TrendRow(metricDisk, diskUsageText)` (:1034) |
| Thermal | 无 | `TrendRow(thermalTitle, thermalText)` (:1035) |
| Uptime | 无 | `TrendRow(metricUptime, uptimeText)` (:1036) |
| Power | 无 | `TrendRow(powerTrendTitle, powerStatusText)` (:1037) |
| **交集** | CPU/Load/Memory/Network/Disk = 5/5 行完全重合 |

### 对比：Power 页 thermalPanel vs Sensors 页 thermalPanel
| 特性 | Power thermalPanel (:833-841) | Sensors thermalPanel (:981-988) |
|------|-------------------------------|---------------------------------|
| 容器 | `DashboardPanel(thermalTitle, thermalSubtitle)` | `DashboardPanel(thermalTitle, thermalSubtitle)` |
| 展示形式 | 4 × `StatusSummaryRow` | 1 × `RingGauge` + 1 × `StatusSummaryRow` |
| thermalText | `StatusSummaryRow(statusCurrentStateTitle, thermalText)` (:836) | `RingGauge(thermalTitle, thermalText, ..., thermalStatus)` (:984) |
| thermalLimitText | `StatusSummaryRow(statusPerformanceLimitTitle, thermalLimitText)` (:837) | `StatusSummaryRow(statusPerformanceLimitTitle, thermalLimitText)` (:986) |
| uptime | `StatusSummaryRow(metricUptime, uptimeText)` (:838) | 无 |
| sampleTime | `StatusSummaryRow(cpuRecentSampleLabel, sampleTimeText)` (:839) | 无 |
| **交集** | thermalText + thermalLimitText = 2 行数据重复 |

### 对比：Overview WidgetPreviewPanel vs Settings widgetPreviewPanel
| 特性 | Overview (:451-461, 实际 WidgetPreviewPanel 定义 :1312-1331) | Settings widgetPreviewPanel (:1155-1167) |
|------|---------------------------------------------------------------|------------------------------------------|
| 容器 | `DashboardPanel(settingsWidgetTitle, settingsWidgetSubtitle)` | `DashboardPanel(settingsWidgetTitle, settingsWidgetSubtitle)` |
| 核心组件 | `WidgetMiniPreview(snapshot: snapshot)` (:1318) | `WidgetMiniPreview(snapshot: snapshot)` (:1158) |
| 元数据左 | 无 | `KeyValueGrid` (size/dataSource/sample/history) (:1159-1164) |
| 元数据右 | `DataChip` × 3 (sizes/dataSource/refresh) + description (:1320-1327) | 无 |
| **交集** | WidgetMiniPreview 组件完全相同 |

### 对比：Sensors realtimeSignalsPanel 11 卡 vs 各 dedicated 页 SourceCapabilityCard
| Sensors 卡 (:994-1004) | 数据字段 | 对应 dedicated 页卡片 | 位置 |
|------------------------|----------|----------------------|------|
| CPU | cpuText | — (CPU 页大数展示) | CPUPage :529 |
| Memory | memoryUsageText | — (Memory 页 RingGauge) | MemoryPage :604 |
| Disk | diskUsageText | — (Storage 页 CapacityBar 上下文) | StoragePage :648-658 |
| Power | powerStatusText | — (Power 页 RingGauge) | PowerPage :813 |
| Network | networkPathText | — (Network 页 MetricCard) | NetworkPage :707 |
| Displays | displaySummaryText | GPUPage SourceCapabilityCard (:853) | GPUPage :853 |
| GPU | gpuSummaryText | GPUPage SourceCapabilityCard (:852) | GPUPage :852 |
| StorageVolumes | storageVolumeSummaryText | StoragePage SourceCapabilityCard (:663) | StoragePage :663 |
| Load | loadDetailText | — (CPU 页 loadPanel) | CPUPage :549 |
| SystemVersion | osVersionText | — (Overview StatusPanel) | OverviewPage :477 |
| Uptime | uptimeText | — (Overview StatusPanel) | OverviewPage :480 |

### 对比：Overview StatusPanel 10 行 vs 各 dedicated 页
| StatusPanel 行 (:479-488) | 数据字段 | 对应 dedicated 页元素 | 位置 |
|--------------------------|----------|----------------------|------|
| Thermal | thermalText | Sensors thermalPanel | :984 |
| Uptime | uptimeText | Power thermalPanel (错位) | :838 |
| Kernel | kernelText | 仅 Overview 有 | — |
| CPU | cpuText / threshold% | CPUPage processorPanel | :529 |
| Memory | memoryUsageText / threshold% | MemoryPage RingGauge | :604 |
| Load 1/5/15 | loadDetailText | CPUPage loadPanel | :549 |
| RunningApps | runningAppSummaryText | ProcessesPage SummaryCard | :920 |
| Network | networkPathText | NetworkPage MetricCard | :707 |
| GPU/Displays | gpuDisplaySummaryText | GPUPage 2 × SourceCapabilityCard | :852-853 |
| DiskAvailable | diskText | StoragePage CapacityBar | :648 |

---

## 发现清单

### F2-1 Overview 趋势面板 5 行是 History 趋势面板 8 行的纯子集
- **页面 A（子集）**：Overview `overviewTrendPanel` — `:464-474`，5 行 TrendRow
- **页面 B（超集）**：History `DashboardPanel(historyTrendsTitle)` — `:1026-1038`，8 行 TrendRow + 1 个 Sparkline
- **关系**：A ⊂ B（纯子集 — Overview 的 5 行全部在 History 中出现，仅缺 Thermal/Uptime/Power 3 行）
- **冗余数据点**：CPU (cpuText), Load (loadText), Memory (memoryUsageText), Network (networkText), Disk (diskUsageText)
- **判定**：真冗余。Overview MetricCard 已含 sparkline 提供每项趋势预览，TrendPanel 5 行无新增价值
- **优先级**：F-高

### F2-2 Power 页 thermalPanel 与 Sensors 页 thermalPanel 重复（thermalText + thermalLimitText）
- **页面 A**：Power `thermalPanel` — `:833-841`，StatusSummaryRow × 4
- **页面 B**：Sensors `thermalPanel` — `:981-988`，RingGauge + StatusSummaryRow
- **关系**：部分重复 — thermalText（值相同，展示形式不同：Power 用 StatusSummaryRow，Sensors 用 RingGauge） + thermalLimitText（值相同，展示形式相同：均用 StatusSummaryRow）
- **冗余数据点**：thermalText, thermalLimitText
- **判定**：真冗余。thermal 状态是全局系统状态，在 Sensors 页展示更自然（信号汇总页）。Power 页嵌入 thermal 信息尚可理解（电源与热管理相关），但值完全相同无新增价值
- **优先级**：F-中

### F2-3 Power 页 thermalPanel 中 uptime/sampleTime 错位
- **页面**：Power `thermalPanel` — `:838-839`
- **行**：`StatusSummaryRow(metricUptime, uptimeText)` (:838) 和 `StatusSummaryRow(cpuRecentSampleLabel, sampleTimeText)` (:839)
- **关系**：错位 — uptime 和 sampleTime 放在标题为 "Thermal State" 的 thermalPanel 内，与 thermal 主题无关
- **冗余数据点**：uptimeText, sampleTimeText
- **判定**：错位。uptime 应放在系统状态面板或 Overview StatusPanel 中；sampleTime 已由顶栏 DataChip (line 408) 常驻展示，无需在页面内重复
- **优先级**：F-中

### F2-4 Overview WidgetPreviewPanel 与 Settings widgetPreviewPanel 共享 WidgetMiniPreview
- **页面 A**：Overview 内嵌 `WidgetPreviewPanel(snapshot: snapshot)` — `:452/:457`（定义 :1312-1331）
- **页面 B**：Settings `widgetPreviewPanel` — `:1155-1167`（定义 :1155-1167）
- **关系**：核心组件 `WidgetMiniPreview(snapshot: snapshot)` 完全相同，但元数据展示不同（Overview 用 DataChip × 3 + 描述文字；Settings 用 KeyValueGrid 4 行）
- **冗余数据点**：WidgetMiniPreview 整体渲染
- **判定**：需权衡。WidgetMiniPreview 在两页展示相同 widget 快照，但上下文不同：Overview 是功能引导（"这是我们的 widget"），Settings 是配置预览（"你的 widget 长这样"）。若移除 Overview 的 WidgetPreviewPanel，则将失去一个功能展示入口
- **优先级**：F-低

### F2-5 Sensors realtimeSignalsPanel 11 卡与各 dedicated 页重复
- **页面 A**：Sensors `realtimeSignalsPanel` — `:991-1007`，11 张 SourceCapabilityCard
- **页面 B**：各 dedicated 页（CPU、Memory、Storage、Power、Network、GPU）的对应元素
- **关系**：11 张卡中，至少 9 张展示与 dedicated 页相同粒度的数据值
  - CPU、Memory、Disk、Power、Network、Displays、GPU、Load、Uptime、SystemVersion — 均在各自 dedicated 页或 Overview StatusPanel 中出现
  - StorageVolumes 卡（:1001，storageVolumeSummaryText）在 Storage 页 SourceCapabilityCard 中也出现（:663）
- **冗余数据点**：cpuText, memoryUsageText, diskUsageText, powerStatusText, networkPathText, displaySummaryText, gpuSummaryText, storageVolumeSummaryText, loadDetailText, osVersionText, uptimeText
- **判定**：需权衡。Sensors 定位为"信号汇总摘要页"，全量展示各 dedicated 页的核心值有其设计意图。但 11 卡中 9 卡与 dedicated 页完全同粒度，区别仅在于 Sensors 卡含 threshold 来源标注（source 参数）。属于"摘要 vs 详情"关系，但摘要粒度偏细
- **优先级**：F-中

### F2-6 Overview StatusPanel 10 行与各 dedicated 页重复
- **页面 A**：Overview `overviewStatusPanel` — `:477-491`，10 行 StatusSummaryRow
- **页面 B**：各 dedicated 页对应元素
- **关系**：10 行中 9 行在各自 dedicated 页有对应（kernel 行仅 Overview 有）。每行展示与详情页相同粒度的值
- **冗余数据点**：thermalText, uptimeText, cpuText, memoryUsageText, loadDetailText, runningAppSummaryText, networkPathText, gpuDisplaySummaryText, diskText
- **判定**：需权衡。Overview 本身已有 4 张 MetricCard 提供聚合摘要（含 sparkline 趋势），StatusPanel 再加 10 行全量详情粒度的状态是对"一屏概览"的补充。但在已有 MetricCard 的情况下，StatusPanel 的行级重复价值有限
- **优先级**：F-低

### F2-7 History ThresholdControlRow 3 行与 Sensors 规则表 4 行共享阈值数据
- **页面 A**：History `DashboardPanel(historyThresholdSettingsTitle)` — `:1041-1047`，3 行 ThresholdControlRow
- **页面 B**：Sensors `DashboardPanel(localRuleTableTitle)` — `:966-977`，4 行 ResponsiveTable
- **关系**：不同数据 point（ThresholdControlRow 是阈值编辑滑块；规则表是阈值判定结果展示），但共享相同的底层阈值（store.cpuAlertThreshold / store.memoryAlertThreshold / store.diskAlertThreshold）
- **冗余数据点**：CPU/Memory/Disk 三个阈值数值
- **判定**：需权衡。History 页的滑块用于编辑阈值，Sensors 表的阈值列展示当前值及判定结果。同一阈值在编辑上下文中展示（History）和在评估结果中展示（Sensors）属于不同用途。但阈值数值本身在两页以不同形式重复。Sensors 表的阈值列可以视为对当前阈值设置的引用，而非冗余
- **优先级**：F-低

### F2-8 Storage 页 SourceCapabilityCard storageVolumeSummary 与 Sensors realtimeSignalsPanel 重复
- **页面 A**：Storage 页 SourceCapabilityCard — `:663`（storageVolumeSummaryText）
- **页面 B**：Sensors realtimeSignalsPanel SourceCapabilityCard — `:1001`（storageVolumeSummaryText）
- **关系**：storageVolumeSummaryText 在 Storage 页和 Sensors 页以相同 SourceCapabilityCard 形式展示
- **注意**：Storage 页另有 diskAvailableText（:664）和 externalStorageVolumeSummaryText（:665），Sensors 页另有 diskUsageText（:996）—— 这两组不是同一字段
- **冗余数据点**：storageVolumeSummaryText
- **判定**：需权衡。Sensors 作为信号汇总，列出 storage 摘要可接受；Storage 页作为详情页，保留 storageVolumeSummary 也有上下文价值
- **优先级**：F-低

### F2-9 GPU 页 SourceCapabilityCard displays/gpu 与 Sensors realtimeSignalsPanel 重复
- **页面 A**：GPU 页 SourceCapabilityCard — `:852-853`（gpuSummaryText, displaySummaryText）
- **页面 B**：Sensors realtimeSignalsPanel SourceCapabilityCard — `:999-1000`（displaySummaryText, gpuSummaryText）
- **关系**：gpuSummaryText + displaySummaryText 在 GPU 页和 Sensors 页以相同 SourceCapabilityCard 形式重复
- **注意**：GPU 页另有 unifiedMemorySummary（:854），Sensors 页另有 storageVolumeSummaryText（:1001）—— 不在重复集合内
- **冗余数据点**：gpuSummaryText, displaySummaryText
- **判定**：需权衡。Sensors 作为信号汇总展示 GPU/Display 摘要合理，GPU 页作为详情页保留也是自然的
- **优先级**：F-低

### F2-10 Memory 页 ProcessListPanel subtitle 与 CPU 页 ProcessListPanel subtitle 不一致
- **页面 A**：CPU 页 `ProcessListPanel` — `:521`，subtitle = `processesDefaultSubtitle`
- **页面 B**：Memory 页 `ProcessListPanel` — `:581`，subtitle = `processesCurrentSessionSubtitle`
- **关系**：两页嵌入同一个 `ProcessListPanel(processes: snapshot.runningApps)`，数据源完全相同（snapshot.runningApps），但使用了不同的 subtitle 字符串
- **冗余数据点**：snapshot.runningApps（进程列表数据完全重复）
- **判定**：真冗余（subtitle 不一致是 bug-like，same data 跨页重复）。两页展示完全相同的进程列表，且 Processes 页又有完整进程列表 ResponsiveTable（:926-938）
- **优先级**：F-高

### F2-11 CPU 页 / Power 页 "Recent Sample" 行与顶栏 chip 重复（sampleTimeText）
- **页面 A（源）**：顶栏常驻 DataChip — `:408`，`dashboardSampleChip(sampleTimeText)`
- **页面 B1**：CPU 页 loadPanel KeyValueGrid — `:559`，`(cpuRecentSampleLabel, sampleTimeText)`
- **页面 B2**：Power 页 thermalPanel StatusSummaryRow — `:839`，`(cpuRecentSampleLabel, sampleTimeText)`
- **关系**：sampleTimeText 在顶栏每页常驻，同时在 CPU 页和 Power 页内重复展示
- **冗余数据点**：sampleTimeText
- **判定**：真冗余。顶栏已提供全页可见的采样时间 chip，页面内无需再列一次。Power 页的 placement 还涉及错位（F2-3）
- **优先级**：F-中

### F2-12 CPU 页 ProcessListPanel 与 Processes 页 ResponsiveTable 重复
- **页面 A**：CPU 页 `ProcessListPanel(processes: snapshot.runningApps)` — `:521`
- **页面 B**：Processes 页 `ResponsiveTable(processesTableColumns, rows: snapshot.runningApps.filter(\.hasInventoryReport))` — `:926-938`
- **关系**：两处使用同一数据源 snapshot.runningApps。CPU 页用 ProcessListPanel 展示进程列表（带开关/筛选功能），Processes 页用 ResponsiveTable 展示完整表格（含架构/启动方式等列）
- **冗余数据点**：snapshot.runningApps 全部进程
- **判定**：需权衡。CPU 页内的进程列表是为了展示"当前占用 CPU 的进程"上下文，Processes 页是完整进程管理。但 ProcessListPanel 展示的是全部 runningApps 而非仅 CPU 相关进程，实际展示内容与 Processes 页高度重叠
- **优先级**：F-中

### F2-13 Memory 页 ProcessListPanel 与 Processes 页 ResponsiveTable 重复
- **页面 A**：Memory 页 `ProcessListPanel(processes: snapshot.runningApps)` — `:581`
- **页面 B**：Processes 页 `ResponsiveTable(processesTableColumns, rows: snapshot.runningApps.filter(\.hasInventoryReport))` — `:926-938`
- **关系**：同 F2-12，Memory 页亦嵌入 ProcessListPanel 展示相同 runningApps
- **冗余数据点**：snapshot.runningApps 全部进程
- **判定**：需权衡。与 F2-12 同理，但 CPU 页的进程列表比 Memory 页的进程列表更有上下文关联（进程 vs CPU 使用率）
- **优先级**：F-中

---

## 汇总

### 总计发现：13 条

| 编号 | 涉及页面对 | 关系类型 | 判定 | 优先级 |
|------|-----------|----------|------|--------|
| F2-1 | Overview 趋势 ⊂ History 趋势 | 纯子集 | 真冗余 | F-高 |
| F2-2 | Power thermalPanel vs Sensors thermalPanel | 部分重复 | 真冗余 | F-中 |
| F2-3 | Power thermalPanel uptime/sampleTime 错位 | 错位 | 错位 | F-中 |
| F2-4 | Overview WidgetPreviewPanel vs Settings widgetPreviewPanel | 组件共享 | 需权衡 | F-低 |
| F2-5 | Sensors realtimeSignalsPanel 11 卡 vs 各 dedicated 页 | 摘要全量重复 | 需权衡 | F-中 |
| F2-6 | Overview StatusPanel 10 行 vs 各 dedicated 页 | 摘要全量重复 | 需权衡 | F-低 |
| F2-7 | History ThresholdControlRow vs Sensors 规则表 | 阈值共享 | 需权衡 | F-低 |
| F2-8 | Storage SourceCapabilityCard vs Sensors realtimeSignalsPanel | 单字段重复 | 需权衡 | F-低 |
| F2-9 | GPU SourceCapabilityCard vs Sensors realtimeSignalsPanel | 双字段重复 | 需权衡 | F-低 |
| F2-10 | CPU/Memory ProcessListPanel subtitle 不一致 | 同数据不同 subtitle | 真冗余 | F-高 |
| F2-11 | CPU/Power Recent Sample 行 vs 顶栏 chip | 常驻重复 | 真冗余 | F-中 |
| F2-12 | CPU ProcessListPanel vs Processes ResponsiveTable | 同数据列表 | 需权衡 | F-中 |
| F2-13 | Memory ProcessListPanel vs Processes ResponsiveTable | 同数据列表 | 需权衡 | F-中 |

### 按优先级统计
- **F-高**：2 条（F2-1 Overview 趋势 ⊂ History 趋势、F2-10 ProcessListPanel subtitle 不一致）
- **F-中**：6 条（F2-2, F2-3, F2-5, F2-11, F2-12, F2-13）
- **F-低**：5 条（F2-4, F2-6, F2-7, F2-8, F2-9）

### 关系类型分布
- **纯子集**：1 条
- **部分重复**：1 条
- **错位**：1 条
- **组件共享**：1 条
- **摘要全量重复**：2 条
- **阈值/字段共享**：3 条
- **常驻重复**：1 条
- **同数据不同展示**：3 条

---

## 与已发现锚点的对照

| 锚点 | 本报告编号 | 验证状态 | 差异说明 |
|------|-----------|----------|---------|
| F3 (Overview ⊂ History) | F2-1 | 已验证 | 确认 5 行趋势数据完全重合 |
| F5 (Power vs Sensors thermalPanel) | F2-2 | 已验证 | thermalText + thermalLimitText 两字段重复 |
| F5-extra (thermalPanel 错位) | F2-3 | 已验证 | uptime/sampleTime 确与 thermal 主题无关 |
| F8 (WidgetPreviewPanel 相同) | F2-4 | 已验证但重判定 | 核心 WidgetMiniPreview 相同但元数据不同，改为"需权衡" |
| F10 (Sensors 11 卡 vs 各页) | F2-5 | 已验证 | 11 卡全量重复确认 |
| F12 (StatusPanel 10 行 vs 各页) | F2-6 | 已验证 | 10 行中 9 行有对应 |
| — (ThresholdControlRow vs 规则表) | F2-7 | 新增 | 阈值数据共享，不同用途 |
| — (Storage 卡 vs Sensors) | F2-8 | 新增 | 仅 storageVolumeSummaryText 单字段重复 |
| — (GPU 卡 vs Sensors) | F2-9 | 新增 | gpuSummary + displaySummary 双字段重复 |
| — (ProcessListPanel subtitle 不一致) | F2-10 | 新增 | 同一数据不同 subtitle |
| F2 (Recent Sample 行 vs 顶栏) | F2-11 | 已验证 | sampleTimeText 三处重复 |
| — (CPU ProcessListPanel vs Processes) | F2-12 | 新增 | runningApps 列表跨页 |
| — (Memory ProcessListPanel vs Processes) | F2-13 | 新增 | runningApps 列表跨页 |
