# F3 常驻元素与摘要面板合理性 — 报告

## 方法
读取侧栏/顶栏/摘要面板的代码，与各页专用面板进行数据字段对比，评估新增价值。行号基于 `DashboardView.swift`（2263行）和 `WidgetPanelView.swift`（328行）。

- 侧栏 `SidebarHealthCard`: 行 325-348
- 顶栏 `DashboardTopBar`: 行 350-412
- Overview 页: 行 414-492
- CPU 页: 行 494-564
- Memory 页: 行 566-634
- Storage 页: 行 636-689
- Network 页: 行 691-758
- Power 页: 行 760-843
- GPU/Display 页: 行 845-911
- Processes 页: 行 913-942
- Sensors 页: 行 944-1008
- History 页: 行 1010-1049
- Settings 页: 行 1051-1168
- Popover WidgetPanelView: `WidgetPanelView.swift` 行 34-161

---

## 复核后处理结论

- F3-1 / FR-10：采纳，删除 SidebarHealthCard。
- F3-2 / FR-7：采纳，删除 CPU/Power 页面内 sampleTime 行。
- F3-3 / FR-23：保留，状态展示与设置控制职责不同。
- F3-4 / FR-15：部分采纳，Overview StatusPanel 删除 CPU/Memory/Network。
- F3-5 / FR-14：采纳，Sensors realtimeSignalsPanel 精简到五张核心信号卡。
- F3-6 / FR-24：采纳，删除 displayed-list-count SummaryCard。
- F3-7 / FR-18：保留 History 趋势详情页。
- F3-8 / FR-19：保留 widget 双入口预览。
- F3-9 / FR-1：采纳。
- F3-10 / FR-25：保留，popover 内部无重复字段。

---

## 常驻元素结构图

### SidebarHealthCard（:325-348）
- 展示数据点：CPU `cpuText`+`cpuUsage`、Memory `memoryUsageText`+`memoryUsage`、Disk `diskUsageText`+`diskUsage`
- 显示形式：3 行 `CompactMetricLine`（标题+值+进度条）
- 跨页可见性：始终（侧栏常驻）

### DashboardTopBar DataChips（:405-410）
- `DataChip(icon: "desktopcomputer")` — 固定文本"Local Machine"
- `DataChip(icon: "clock")` — `snapshot.sampleTimeText`（最近采样时间）
- `DataChip(icon: "arrow.clockwise")` — `refreshInterval.label`（当前刷新间隔标签）
- 跨页可见性：始终（顶栏常驻）

### Overview MetricCard（:429-433）
- 4 张 MetricCard：CPU（cpuText+cpuUsage+sparkline+detail+badge）、Memory（memoryUsageText+memoryUsage+sparkline+detail+badge）、Network（networkText+networkBytesPerSecond+sparkline+detail）、Power（powerStatusText+powerGaugeProgress+sparkline+detail）
- 跨页可见性：仅 Overview 页

### Overview StatusPanel（:476-491）
- 10 行 StatusSummaryRow：thermal/uptime/kernel/cpu+threshold/memory+threshold/load 1/5/15/runningApps/network/gpuDisplay/disk+threshold
- 跨页可见性：仅 Overview 页

### Sensors realtimeSignalsPanel（:991-1007）
- 11 张 SourceCapabilityCard：CPU/Memory/Disk/Power/Network/Displays/GPU/StorageVolumes/Load/SystemVersion/Uptime
- 跨页可见性：仅 Sensors 页

### Processes SummaryCard 4 张（:919-924）
- 4 张 SummaryCard：runningAppCountText/runningAppListCountText/activeApplicationCountText/hiddenApplicationCountText
- 跨页可见性：仅 Processes 页

### History TrendPanel（:1026-1038）
- 1 条主导 Sparkline + 8 行 TrendRow：CPU/Load/Memory/Network/Disk/Thermal/Uptime/Power
- 跨页可见性：仅 History 页

---

## 发现清单

### F3-1 侧栏 SidebarHealthCard vs Overview MetricCard（已知锚点 F1）
- **元素 A**（常驻）: SidebarHealthCard 行 337-339 — CPU/Memory/Disk 三行 CompactMetricLine
- **元素 B**（页面专用）: Overview MetricCard 行 430-433 — CPU/Memory/Network/Power 四张 MetricCard
- **数据字段重复**：
  - `snapshot.cpuText` / `snapshot.cpuUsage`（Sidebar: line 337 => MetricCard: line 430）
  - `snapshot.memoryUsageText` / `snapshot.memoryUsage`（Sidebar: line 338 => MetricCard: line 431）
  - `snapshot.diskUsageText` / `snapshot.diskUsage`（Sidebar: line 339 => 无直接 Disk MetricCard，但有 Storage 页）
- **A 对 B 的新增价值**：无。SidebarHealthCard 仅展示值+进度条，无 sparkline、detail、badge；MetricCard 更丰富（sparkline+detail+badge+progress）。用户已明确否定保留理由。
- **判定**：真冗余
- **优先级**：F-中

### F3-2 顶栏 DataChip sampleTimeText vs CPU 页/Power 页 "Recent Sample" 行（已知锚点 F2）
- **元素 A**（常驻）: 顶栏 DataChip 行 408 — `dashboardSampleChip(snapshot.sampleTimeText)`
- **元素 B1**（页面专用）: CPU 页 loadPanel KeyValueGrid 行 559 — `(cpuRecentSampleLabel, snapshot.sampleTimeText)`
- **元素 B2**（页面专用）: Power 页 thermalPanel StatusSummaryRow 行 839 — `(cpuRecentSampleLabel, snapshot.sampleTimeText)`
- **数据字段重复**：`snapshot.sampleTimeText` 三处完全重复
- **A 对 B 的新增价值**：无。顶栏常驻可见，CPU/Power 行是同一值重述。
- **判定**：真冗余
- **优先级**：F-中

### F3-3 顶栏 DataChip refreshInterval.label vs Settings refreshDisplayPanel Picker（额外检查项 1）
- **元素 A**（常驻）: 顶栏 DataChip 行 409 — 纯文本 `refreshInterval.label`
- **元素 B**（页面专用）: Settings 页 refreshDisplayPanel 行 1107-1112 — `Picker` 选择刷新间隔
- **数据字段重复**：`refreshInterval` 的 label 文本
- **A 对 B 的新增价值**：A 是状态展示（当前间隔），B 是交互控件（修改间隔）。不同职责：display vs control。
- **判定**：有意冗余（显示 vs 控制分离），保留
- **优先级**：F-低

### F3-4 Overview StatusPanel 10 行 — 是否过度摘要（已知锚点 F3）
- **元素 A**（摘要）: Overview StatusPanel 行 477-491 — 10 行 StatusSummaryRow
- **元素 B**（摘要）: Overview MetricCard 行 430-433 — 4 张 MetricCard
- **各专用页已覆盖的数据**：
  | StatusPanel 行 | 对应专用页元素 | 重复度 |
  |---------------|---------------|--------|
  | thermalText(:479) | Sensors thermalPanel(:984) / Power thermalPanel(:836) | 全值重复 |
  | uptimeText(:480) | Power thermalPanel(:838) | 全值重复 |
  | kernelText(:481) | Settings DataSource 表(:1085) | 弱关联 |
  | cpuText+threshold(:482) | CPU 页 processorPanel(:529) | 全值重复 |
  | memoryUsageText+threshold(:483) | Memory 页 memoryGauge(:604) | 全值重复 |
  | loadDetailText(:484) | CPU 页 loadPanel(:549) | 全值重复 |
  | runningAppSummaryText(:485) | CPU 页(:558) / Processes 页(:920) | 全值重复 |
  | networkPathText(:486) | Network 页 MetricCard(:707) | 全值重复 |
  | gpuDisplaySummaryText(:487) | GPU 页(:852-853) | 全值重复 |
  | diskText+threshold(:488) | Storage 页 diskUsedText(:648) | 全值重复 |
- **A 对 MetricCard 的新增价值**：6 行（thermal/uptime/kernel/load/runningApps/gpuDisplay）在 MetricCard 不包含；cpu/memory/network 三行与 MetricCard 有重叠但更详细（含 threshold）。
- **判定**：需权衡。StatusPanel "一屏概览"有其价值，6 行补充 MetricCard 之外，4 行与 MetricCard/各页重复。建议精简为 6-7 行聚合摘要。
- **优先级**：F-中

### F3-5 Sensors realtimeSignalsPanel 11 卡 — 是否过度摘要（已知锚点 F10）
- **元素 A**（摘要）: Sensors 页 realtimeSignalsPanel 行 993-1005 — 11 张 SourceCapabilityCard
- **各专用页已覆盖的数据**：
  | 卡片 | 对应专用页 | 重复度 |
  |------|-----------|--------|
  | CPU(:994) | CPU 页 processorPanel(:529) | cpuText 全值重复 |
  | Memory(:995) | Memory 页 memoryGauge(:604) | memoryUsageText 全值重复 |
  | Disk(:996) | Storage 页(:648) | diskUsageText 全值重复 |
  | Power(:997) | Power 页 batteryPanel(:813) | powerStatusText 全值重复 |
  | Network(:998) | Network 页 MetricCard(:707) | networkPathText 全值重复 |
  | Displays(:999) | GPU 页(:853) | displaySummaryText 全值重复 |
  | GPU(:1000) | GPU 页(:852) | gpuSummaryText 全值重复 |
  | StorageVolumes(:1001) | Storage 页(:664) | storageVolumeSummaryText 全值重复 |
  | Load(:1002) | CPU 页(:549) | loadDetailText 全值重复 |
  | SystemVersion(:1003) | Overview StatusPanel(:477) | osVersionText 全值重复 |
  | Uptime(:1004) | Overview StatusPanel(:480) / Power(:838) | uptimeText 全值重复 |
- **A 对专用页的新增价值**：Sensors 作为"信号汇总"提供统一格式的状态总览，每卡带 threshold 着色。但 11 卡展示与各页**完全相同粒度值**，且 Sensors 规则表（:966-977）已做 threshold 判定重叠。
- **判定**：需权衡。建议精简为 5-6 张关键信号卡（CPU/Memory/Disk/Power/Network），其余改为状态指示。
- **优先级**：F-中

### F3-6 Processes 页 4 张 SummaryCard — UI 元数据（已知锚点 F11）
- **元素 A**（摘要）: Processes 页 SummaryCard 行 920-924
  - `runningAppCountText` (总运行应用数)
  - `runningAppListCountText` (当前列表显示数 — UI 元数据)
  - `activeApplicationCountText` (前台应用数)
  - `hiddenApplicationCountText` (隐藏应用数)
- **元素 B**（同页）: 行 926-939 ResponsiveTable（进程列表）
- **分析**：前 3 卡为表格提供"X total, Y displayed, Z foreground"的上下文计数 - 常见 UI 模式。`runningAppCountText` 虽在 CPU/Overview 重复，但在 Processes 是表格上下文。`runningAppListCountText` 是纯 UI 元数据（仅反映列表行数）。
- **判定**：有意冗余（UI 元数据）。保留总/前台/隐藏三卡，`runningAppListCountText` 可移除（纯 UI 元数据无系统意义）。
- **优先级**：F-低

### F3-7 History 趋势面板 8 行 vs Overview MetricCard sparkline（额外检查项 2）
- **元素 A**（页面专用）: History 趋势面板 行 1026-1038 — 主导 Sparkline + 8 TrendRow
- **元素 B**（摘要）: Overview MetricCard 行 430-433 — 4 张 MetricCard 各含 sparkline
- **元素 C**（摘要）: Overview 趋势面板 行 464-474 — 5 TrendRow（CPU/Load/Memory/Network/Disk）
- **分析**：
  - History 8 TrendRow vs MetricCard sparkline：不同粒度。MetricCard 是微型预览（34px），History 是趋势详情页（92px 主导 sparkline + 8 行对比）。**有意冗余**。
  - Overview 趋势面板（C）5 行是 History（A）5/8 纯子集，且 Overview 同页 MetricCard 已含 sparkline。**真冗余**。
- **判定**：History TrendPanel vs MetricCard sparkline → 有意冗余；Overview TrendPanel（5 行）⊂ History TrendPanel（8 行）→ 真冗余（见 F3-9）
- **优先级**：F-中

### F3-8 Settings widgetPreviewPanel vs Overview WidgetPreviewPanel（已知锚点 F8）
- **元素 A**（摘要）: Overview WidgetPreviewPanel 行 451-461（定义 1312-1331） — WidgetMiniPreview + DataChips + 描述文字
- **元素 B**（页面专用）: Settings widgetPreviewPanel 行 1155-1167 — WidgetMiniPreview + KeyValueGrid（配置上下文）
- **重复分析**：WidgetMiniPreview(snapshot) 本身完全重复，但周边信息不同。Overview 是实时预览，Settings 是配置预览。跨页展示同一组件。
- **判定**：有意冗余（不同上下文：预览 vs 配置），保留
- **优先级**：F-低

### F3-9 Overview TrendPanel 5 行 ⊂ History TrendPanel 8 行（已知锚点 F3）
- **元素 A**（摘要）: Overview 趋势面板 行 464-474 — 5 TrendRow（CPU/Load/Memory/Network/Disk）
- **元素 B**（页面专用）: History 趋势面板 行 1030-1037 — 8 TrendRow
- **数据字段重复**：5/8 严格子集。Overview MetricCard 已含 sparkline。
- **A 对 B 的新增价值**：无。Overview 同页 MetricCard sparkline 已提供趋势。
- **判定**：真冗余
- **优先级**：F-高

### F3-10 Popover WidgetPanelView 内部冗余检查（额外检查项 4）
- **WidgetPanelView 行 34-161 结构**：
  - Header(112): `sampleTimeText`
  - 4 PopoverMetricRow(54-57): CPU `cpuText`/ Memory `memoryUsageText`/ Network `networkText`+`networkPathText`/ Disk `diskUsageText`
  - PopoverSmallStat(61-74): power `powerStatusText`/ thermal `thermalText`/ load `loadText`/ network `networkPathText`/ displays `displaySummaryText`/ volumes `storageVolumeSummaryText`/ uptime `uptimeText`/ kernel `kernelText`
- **内部冗余检查**：无两元素展示相同字段。每个行/卡展示不同数据点。
- **与 dashboard 跨入口重复**：大量重复但属不同入口（菜单栏 popover vs 主窗口），按标准为有意冗余。
- **判定**：无内部冗余。跨入口重复 → 有意冗余（保留）
- **优先级**：无（无需处理）

---

## 汇总

### 判定分布
| 判定 | 计数 | 条目 |
|------|------|------|
| 真冗余 | 3 | F3-1（侧栏 SidebarHealthCard）、F3-2（顶栏 sampleTime vs CPU/Power Recent Sample）、F3-9（Overview 趋势面板子集） |
| 有意冗余 | 5 | F3-3（顶栏 refreshInterval vs Settings Picker）、F3-6（Processes SummaryCard）、F3-7（History vs MetricCard sparkline）、F3-8（Settings vs Overview WidgetPreview）、F3-10（Popover 跨入口） |
| 需权衡 | 2 | F3-4（Overview StatusPanel 10 行）、F3-5（Sensors realtimeSignalsPanel 11 卡） |

### 优先级分布
| 优先级 | 计数 | 条目 |
|--------|------|------|
| F-高 | 1 | F3-9 |
| F-中 | 5 | F3-1、F3-2、F3-4、F3-5、F3-7 |
| F-低 | 3 | F3-3、F3-6、F3-8 |

### 总计
- 总计发现：10 条
- 真冗余：3 条
- 有意冗余：5 条（含 F3-10 无内部冗余）
- 需权衡：2 条
- F-高：1 条
- F-中：5 条
- F-低：3 条

---

## 判定说明

### 真冗余条目移除建议

**F3-1（侧栏 SidebarHealthCard 3 行）**：移除整个 SidebarHealthCard。侧栏保留 SidebarRow 导航列表即可。CPU/Memory/Disk 的概览可在 Overview 页查看。用户已明确否定保留理由。移除后侧栏更简洁。

**F3-2（CPU/Power Recent Sample 行）**：从 CPU 页 loadPanel KeyValueGrid（:559）和 Power 页 thermalPanel（:839）移除 `(cpuRecentSampleLabel, sampleTimeText)` 行。顶栏 DataChip 已在每页显示 sampleTimeText。

**F3-9（Overview 趋势面板 5 行）**：移除 Overview 页的 overviewTrendPanel 及其 5 行 TrendRow（:464-474）。Overview 4 张 MetricCard 已通过 sparkline 提供趋势预览，History 页提供完整 8 行趋势面板。移除后 Overview 更聚焦，减少同页内 MetricCard sparkline 与 TrendRow 的视觉重复。

### 需权衡条目分析

**F3-4（Overview StatusPanel 10 行）**：建议保留但精简。保留 5-6 行（thermal/uptime/load/runningApps/gpuDisplay/disk），移除与 MetricCard 重复的 cpu/memory/network 详细行。或改为聚合状态指示（仅显示状态点 + 摘要文本）。

**F3-5（Sensors realtimeSignalsPanel 11 卡）**：建议精简为 5-6 张关键信号卡（CPU/Memory/Disk/Power/Network），移除与规则表功能重叠的 threshold 着色卡片。对于已由 dedicated 页完整覆盖的指标（GPU/Displays/StorageVolumes/Load/SystemVersion/Uptime），改为仅显示"可用/不可用"状态指示而非全值重复。
