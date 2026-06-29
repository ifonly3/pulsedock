# R1 — 信息冗余专项报告

审查范围：`DashboardView.swift`（侧栏 / 顶栏 / Overview / CPU / GPU / Memory / Storage / Network / Power / Processes / Sensors / History / Settings）、`WidgetPanelView.swift`（menu bar popover）、`AppDelegate.swift`（menu bar 状态项）、`SystemDashboardWidget.swift`（Small / Medium / Large widget）、`MetricSnapshot.swift`（派生属性）。

审查方法：从 `MetricSnapshot` 派生属性建立数据点清单 → 用 grep 追踪每个数据点在全部视图中的展示位置 → 评估后一处相对前一处是否有新增价值（更细粒度 / 不同视角 / 不同时间窗 / 不同上下文 = 有新增价值；无 = 冗余）。

> 锚点修正：R1-2 原称 `SystemDashboardWidget.swift:186,216,264` 展示 `sampleTimeText`，实测这三处展示的是 `sampleClockText`（时分，无秒），不是 `sampleTimeText`（时分秒）。Widget 用 `sampleClockText`，App 用 `sampleTimeText`。下文已据此修正。

---

## 一、数据点 × 展示位置矩阵

图例：`DV`=DashboardView.swift，`WPV`=WidgetPanelView.swift，`AD`=AppDelegate.swift，`SDW`=SystemDashboardWidget.swift。
"冗余评估"列只给结论性概述，逐条论证见第二节。

| 数据点 | 位置1 | 位置2 | 位置3 | 位置4 | 位置5 | 位置6 | 位置7 | 冗余评估 |
|--------|-------|-------|-------|-------|-------|-------|-------|---------|
| `cpuText` | DV 侧栏 :338 | DV Overview MetricCard :431 | DV Overview TrendRow :468 | DV Overview StatusPanel :483 | DV CPU 页 :530 | DV Sensors 规则表 :971 | DV Sensors 信号卡 :1014 | 侧栏=常驻可见(有意)；Overview 三处=卡片/趋势/状态不同视角；CPU 页=大数+sparkline 更细；Sensors 两处见 R1-3/R1-6；其余有新增价值 |
| `cpuText`续 | DV History TrendRow :1050 | DV History 规则表 :1073 | DV WidgetMiniPreview :1385 | WPV popover :54 | AD menubar :338 | SDW Small :191 | SDW Medium :217 | History TrendRow=Overview 趋势超集(见 R1-4)；menubar/widget/popover=跨入口(有意)；WidgetMiniPreview 见 R1-7 |
| `cpuText`续 | SDW Large :269 | — | — | — | — | — | — | widget 跨进程(有意) |
| `memoryUsageText` | DV 侧栏 :339 | DV Overview MetricCard :432 | DV Overview TrendRow :470 | DV Overview StatusPanel :484 | DV Memory 页 RingGauge :605 | DV Sensors 规则表 :972 | DV Sensors 信号卡 :1015 | 同 cpuText 模式；Memory 页 RingGauge+segmentBar+composition 更细 |
| `memoryUsageText`续 | DV History TrendRow :1052 | DV History 规则表 :1074 | DV WidgetMiniPreview :1386 | WPV popover :55 | SDW Small :192 | SDW Medium :233 | SDW Large :270 | 同上 |
| `diskUsageText` | DV 侧栏 :340 | DV Overview TrendRow :472 | DV Storage 页 TrendRow :659 | DV Sensors 规则表 :973 | DV Sensors 信号卡 :1016 | DV History TrendRow :1054 | DV History 规则表 :1075 | Overview 无 disk MetricCard，TrendRow 是 Overview 唯一磁盘表示=有新增价值；Storage 页大数为 diskUsedText，TrendRow 是该页唯一百分比=有新增价值 |
| `diskUsageText`续 | WPV popover :57 | SDW Medium :235 | SDW Large :271 | — | — | — | — | popover/widget 跨入口(有意) |
| `networkText` | DV Overview MetricCard :433 | DV Overview TrendRow :471 | DV Network 页 MetricCard :707 | DV Network 页 TrendRow :730 | DV History TrendRow :1053 | WPV popover :56 | — | Network 页 MetricCard :707 与 TrendRow :730 同值同趋势(见 R1-8 边界) |
| `networkPathText` | DV Overview MetricCard detail :433 | DV Overview StatusPanel :487 | DV Network 页 MetricCard :708 | DV Network 页连通性表 :716 | DV Network 页 TrendRow :731 | DV Sensors 规则表 :974 | DV Sensors 信号表 :990 | Network 页 MetricCard :708 与连通性表首行 :716 同值同 detail(见 R1-8) |
| `networkPathText`续 | DV Sensors 信号卡 :1018 | DV History 规则表 :1076 | WPV popover :56(detail)+:67 | SDW Small :198 | SDW Medium :234 | SDW Large :284 | — | popover/widget 跨入口(有意) |
| `thermalText` | DV Overview StatusPanel :480 | DV Power 页 thermalPanel :837 | DV Sensors 信号表 :984 | DV Sensors thermalPanel RingGauge :1004 | DV History TrendRow :1055 | WPV popover :62 | SDW Small :196 | Power 页 :837 与 Overview :480 同值同 StatusSummaryRow(见 R1-9)；Sensors 两处=表格+仪表不同视角 |
| `thermalText`续 | SDW Medium :250 | SDW Large :277 | — | — | — | — | — | widget(有意) |
| `powerStatusText` | DV Overview MetricCard :434 | DV Power 页 RingGauge :814 | DV Power 页 TrendRow :819 | DV Sensors 信号表 :989 | DV Sensors 信号卡 :1017 | DV History TrendRow :1057 | WPV popover :61 | Power 页 RingGauge+TrendRow 是同页两处(仪表+趋势不同视角)；Sensors 表 vs 卡见 R1-6 |
| `powerStatusText`续 | SDW Medium :251 | SDW Large :276 | — | — | — | — | — | widget(有意)；Small 用 compactPowerStatusText 不同 |
| `osVersionText` | DV Overview StatusPanel subtitle :478 | DV Sensors 信号表 :985 | DV Sensors 信号卡 :1023 | SDW Large :306 | — | — | — | Sensors 表 vs 卡同页同值(见 R1-6)；Overview 作为副标题=不同上下文 |
| `uptimeText` | DV Overview StatusPanel :481 | DV Power 页 thermalPanel :839 | DV Sensors 信号表 :986 | DV Sensors 信号卡 :1024 | DV History TrendRow :1056 | WPV popover :73 | SDW Large :305 | Power 页 :839 与 Overview :481 同值(见 R1-9)；Sensors 表 vs 卡见 R1-6 |
| `kernelText` | DV Overview StatusPanel :482 | DV Sensors 信号表 :987 | WPV popover :74 | SDW Large :309 | — | — | — | 各处不同上下文；Sensors 表是唯一重复源但无卡片对应 |
| `loadText` | DV Overview TrendRow :469 | DV CPU 页 loadPanel StatLine :550 | DV History TrendRow :1051 | WPV popover :63 | SDW Large :272 | — | — | CPU 页 loadPanel 有 1/5/15 三行更细=有新增价值；Overview TrendRow 是 History 超集子集(见 R1-4) |
| `loadDetailText` | DV Overview StatusPanel :485 | DV Sensors 信号表 :988 | DV Sensors 信号卡 :1022 | — | — | — | — | Sensors 表 vs 卡同页同值(见 R1-6) |
| `gpuSummaryText` | DV GPU 页 SourceCapabilityCard :853 | DV Sensors 信号表 :992 | DV Sensors 信号卡 :1020 | — | — | — | — | Sensors 表 vs 卡同页同值(见 R1-6)；GPU 页有设备表更细 |
| `displaySummaryText` | DV GPU 页 SourceCapabilityCard :854 | DV Sensors 信号表 :991 | DV Sensors 信号卡 :1019 | WPV popover :68 | — | — | — | Sensors 表 vs 卡同页同值(见 R1-6) |
| `gpuDisplaySummaryText` | DV Overview StatusPanel :488（唯一） | — | — | — | — | — | — | 唯一位置，无冗余 |
| `storageVolumeSummaryText` | DV Storage 页 SourceCapabilityCard :664 | DV Sensors 信号表 :993 | DV Sensors 信号卡 :1021 | WPV popover :69 | — | — | — | Sensors 表 vs 卡同页同值(见 R1-6) |
| `runningAppSummaryText` | DV Overview StatusPanel :486（唯一） | — | — | — | — | — | — | 唯一位置，无冗余 |
| `diskText`（可用量摘要） | DV Overview StatusPanel :489 | WPV popover :57(detail) | — | — | — | — | — | 不同上下文，无冗余 |
| `sampleTimeText`（时分秒） | DV 侧栏 :333 | DV 顶栏 chip :409 | DV CPU 页 loadPanel :560 | DV Power 页 thermalPanel :840 | DV Sensors 信号卡 source :1019 | DV Settings widget 预览 :1196 | WPV popover header :112 | 侧栏 vs 顶栏=同窗口同可见(见 R1-1)；CPU/Power 页=与顶栏重复(见 R1-2) |
| `sampleClockText`（时分） | DV WidgetMiniPreview :1379 | SDW Small :186 | SDW Medium :216 | SDW Large :264 | — | — | — | WidgetMiniPreview 见 R1-7；widget 跨进程(有意) |

---

## 二、信息冗余发现

### 冗余 R1-1：侧栏 sampleTimeText 与顶栏 chip 同窗口双重常驻
- **位置1**: `DashboardView.swift:333` — `SidebarHealthCard` 顶部 `Text(snapshot.sampleTimeText)`，侧栏常驻
- **位置2**: `DashboardView.swift:409` — `DashboardTopBar.chips` 中 `DataChip(icon: "clock", text: dashboardSampleChip(sampleTimeText))`，顶栏常驻
- **冗余描述**: 侧栏与顶栏在同一个 `DashboardView` 窗口内同时可见，且都是常驻 chrome（不随切页消失）。两处展示完全相同的 `sampleTimeText`（时分秒），用户在任一页面都会看到两次采样时间，顶栏 chip 相对侧栏无新增信息价值。
- **是否有意冗余**: 部分有意。侧栏的 CPU/Mem/Disk 压缩行是"切页时常驻可见"的有意设计（在 Network 页也能看 CPU），但 `sampleTimeText` 本身不随指标变化提供新视角，仅是一个时间戳；顶栏 chip 与侧栏时间戳功能完全重叠。
- **移除后副作用**: 移除顶栏 clock chip 后，采样时间仅在侧栏可见；若用户折叠/忽略侧栏则失去时间锚点。移除侧栏时间戳则顶栏保留。
- **建议**: 移除顶栏 `clock` chip（:409），保留侧栏时间戳（侧栏已含"Live Sampling"语义上下文，更贴切）。或反之移除侧栏时间戳保留顶栏。二者保留其一即可。
- **优先级**: R-中

### 冗余 R1-2：sampleTimeText 在 CPU 页 / Power 页以"Recent Sample"重复展示，与常驻顶栏重叠
- **位置1**: `DashboardView.swift:409` — 顶栏 chip（常驻，每页可见）
- **位置2**: `DashboardView.swift:560` — CPU 页 `loadPanel` KeyValueGrid `(cpuRecentSampleLabel, snapshot.sampleTimeText)`
- **位置3**: `DashboardView.swift:840` — Power 页 `thermalPanel` `StatusSummaryRow(title: cpuRecentSampleLabel, value: sampleTimeText)`
- **冗余描述**: CPU 页与 Power 页都将 `sampleTimeText` 作为"Recent Sample"行展示，但顶栏 chip 在这两个页面顶部已常驻显示同一个 `sampleTimeText`。用户在 CPU 页看到顶栏 chip 一次 + loadPanel 一次；在 Power 页看到顶栏 chip 一次 + thermalPanel 一次。页面内"Recent Sample"行相对顶栏 chip 无新增价值（同一时间戳，无新粒度/新视角）。
- **是否有意冗余**: 否。这是历史遗留：页面内"Recent Sample"行早于顶栏 chip 存在，顶栏 chip 引入后未清理页面内重复行。
- **移除后副作用**: CPU 页 loadPanel KeyValueGrid 从 6 行减为 5 行；Power 页 thermalPanel 从 4 行减为 3 行。采样时间仍由顶栏常驻提供。无信息损失。
- **建议**: 移除 CPU 页 `:560` 的 `(cpuRecentSampleLabel, sampleTimeText)` 行与 Power 页 `:840` 的 `StatusSummaryRow`。
- **优先级**: R-中

### 冗余 R1-3：本地规则表在 Sensors 页与 History 页逐行重复渲染
- **位置1**: `DashboardView.swift:967-978` — Sensors 页 `DashboardPanel(localRuleTableTitle)` 内 `ResponsiveTable`，4 行：CPU/Memory/Disk 阈值判定 + Network 在线判定
- **位置2**: `DashboardView.swift:1069-1080` — History 页 `DashboardPanel(localRuleTableTitle)` 内 `ResponsiveTable`，4 行：同上
- **冗余描述**: 两个面板标题、副标题、图标、表头列（`statusRuleTableColumns`）完全相同。4 行数据的后三列（阈值百分比、当前值 `cpuText`/`memoryUsageText`/`diskUsageText`/`networkPathText`、状态文本 `thresholdStatusText`/`networkRuleStatusText`）逐行完全相同。唯一差异是前三行第一列标签：Sensors 用 `metricCPU`/`metricMemory`/`metricDisk`，History 用 `historyRuleCPUOver`/`historyRuleMemoryHigh`/`historyRuleDiskHigh`（第 4 行标签 `metricNetworkConnection` 两处一致）。后一处（History）相对前一处（Sensors）无新增信息价值——History 页紧邻的阈值控制面板（:1061-1067）已提供阈值编辑能力，规则表本身只是只读判定结果，与 Sensors 页只读判定结果完全重叠。
- **是否有意冗余**: 否。两页各自独立添加了"规则状态"面板，但未抽象为共享视图，导致同一段逻辑被复制粘贴。
- **移除后副作用**: 移除 History 页规则表后，History 页保留趋势面板 + 阈值控制面板（阈值控制面板才是 History 页的独有价值——可编辑阈值）。规则判定只读结果仍可在 Sensors 页查看。或反之移除 Sensors 页规则表。无信息损失。
- **建议**: 移除 History 页 `:1069-1080` 的规则表面板（History 页的独有功能是阈值滑块编辑，已由 :1061-1067 覆盖）。或将规则表抽为共享子视图，仅在 Sensors 页保留。
- **优先级**: R-高（4 行 × 3 列完全重复，且跨页复制粘贴易产生未来漂移）

### 冗余 R1-4：Overview 趋势面板 5 行 TrendRow 是 History 趋势面板 8 行的纯子集
- **位置1**: `DashboardView.swift:468-472` — Overview `overviewTrendPanel`，5 行 TrendRow：CPU / Load / Memory / Network / Disk
- **位置2**: `DashboardView.swift:1050-1057` — History `historyTrendsTitle` 面板，8 行 TrendRow：CPU / Load / Memory / Network / Disk / Thermal / Uptime / Power
- **冗余描述**: Overview 趋势面板的前 5 行与 History 趋势面板的前 5 行完全一致——相同的 `title`、相同的 `value`（`cpuText`/`loadText`/`memoryUsageText`/`networkText`/`diskUsageText`）、相同的 `tint`、相同的 `values`（`cpuTrend`/`loadTrendValues`/`memoryTrend`/`networkTrend`/`diskTrendValues`，且二者都从同一 `history` 数组派生）。History 额外增加 Thermal / Uptime / Power 三行 + 顶部一个独立 Sparkline。Overview 的 5 行无任何 History 没有的信息。
- **是否有意冗余**: 部分有意。Overview 设计意图是"首屏即见趋势摘要"，但既然 History 页提供完整 8 行趋势且 Overview 5 行是其子集，Overview 趋势面板相对 History 趋势面板无新增价值。Overview 的 MetricCards（:431-434）已含各自 sparkline，趋势信息在卡片级已可见。
- **移除后副作用**: Overview 页移除 `overviewTrendPanel` 后，趋势信息仍由 MetricCards 内嵌 sparkline（:431-434 values 字段）+ History 页完整趋势面板提供。Overview 页布局变为 MetricCards + StatusPanel + ProcessList + WidgetPreview，更紧凑。无信息损失。
- **建议**: 移除 Overview `overviewTrendPanel`（:465-475），或将其替换为 History 趋势面板的深链接入口（"查看完整趋势 →"）。保留 MetricCards 内嵌 sparkline 即可在 Overview 提供趋势预览。
- **优先级**: R-中（5 行纯子集，但 Overview 作为首屏有"一眼概览"的体验价值，移除需权衡）

### 冗余 R1-5：Settings 页 Widget 预览面板 Refresh / MainWindow 行与左面板控件重复
- **位置1**: `DashboardView.swift:1166-1170` — `refreshDisplayPanel` 内 `SettingReadOnlyRow(settingsWidgetRefreshTitle, settingsWidgetRefreshDetail, settingsWidgetRefreshValue)`（Widget 刷新间隔只读行）
- **位置2**: `DashboardView.swift:1141-1147` — `refreshDisplayPanel` 内主窗口刷新 `Picker`（selection = `store.refreshInterval`，选项 `option.label`）
- **位置3**: `DashboardView.swift:1195` — `widgetPreviewPanel` KeyValueGrid `(settingsWidgetRefreshLabel, settingsWidgetRefreshValue)`
- **位置4**: `DashboardView.swift:1198` — `widgetPreviewPanel` KeyValueGrid `(settingsWidgetMainWindowLabel, store.refreshInterval.label)`
- **冗余描述**: 同一个 Settings 页内，`refreshDisplayPanel`（左/上面板）已展示 Widget 刷新间隔（:1166 只读行）与主窗口刷新间隔（:1141 可编辑 Picker）。`widgetPreviewPanel`（右/下面板）的 KeyValueGrid 又把这两个值作为只读键值对重复展示：`:1195` 的 `settingsWidgetRefreshValue` 与 `:1169` 的 `control` 完全相同；`:1198` 的 `store.refreshInterval.label` 与 `:1142` Picker 当前选中项的 `option.label` 完全相同。后一处相对前一处无新增价值（前一处已是同一页内可见的控件/只读行）。
- **是否有意冗余**: 否。Widget 预览面板的 KeyValueGrid 本意是汇总 widget 相关配置，但 Refresh 与 MainWindow 两项已在相邻面板展示，未做去重。
- **移除后副作用**: `widgetPreviewPanel` KeyValueGrid 从 6 项减为 4 项（保留 Widget Size / Data Source / Sample Time / History Duration——这 4 项是预览面板独有）。Refresh 与 MainWindow 配置仍由 `refreshDisplayPanel` 提供。无信息损失。
- **建议**: 移除 `widgetPreviewPanel` KeyValueGrid 中 `:1195`（Widget Refresh）与 `:1198`（MainWindow）两行。
- **优先级**: R-中

### 冗余 R1-6：Sensors 页 SystemSignals 表与 realtimeSignalsPanel 在同页展示 8 个重叠值
- **位置1**: `DashboardView.swift:980-997` — `statusSystemSignalsTitle` 面板，`ResponsiveTable` 10 行，每行 `[指标名, 值, 来源]`
- **位置2**: `DashboardView.swift:1011-1027` — `statusRealtimeSignalsTitle` 面板，`LazyVGrid` 11 张 `SourceCapabilityCard`，每卡 `[标题, 值, 状态徽章, 来源]`
- **冗余描述**: 同一个 Sensors 页内，两个面板展示 8 个完全重叠的数据点：

  | 数据点 | 信号表行 | 信号卡 | 值是否相同 |
  |--------|---------|--------|-----------|
  | `osVersionText` | :985 | :1023 | 是 |
  | `uptimeText` | :986 | :1024 | 是 |
  | `loadDetailText` | :988 | :1022 | 是 |
  | `powerStatusText` | :989 | :1017 | 是 |
  | `networkPathText` | :990 | :1018 | 是 |
  | `displaySummaryText` | :991 | :1019 | 是 |
  | `gpuSummaryText` | :992 | :1020 | 是 |
  | `storageVolumeSummaryText` | :993 | :1021 | 是 |

  信号表独有：`thermalText`(:984)、`kernelText`(:987)。信号卡独有：`cpuText`(:1014)、`memoryUsageText`(:1015)、`diskUsageText`(:1016)。重叠的 8 项值完全相同，差异仅在第三列：信号表显示"来源"文本（如 `sourceOSVersion`），信号卡显示状态徽章 + 来源文本。但状态徽章对这 8 项大多是 `.normal`/`.neutral`（仅 power/network 有实际状态分级），信息增量极低。
- **是否有意冗余**: 否。两个面板各自独立设计：信号表偏"数据源清单"视角，信号卡偏"实时状态徽章"视角。但 8 个重叠值使二者在用户眼中几乎是同一份清单的两种排版，未实现真正的视角区分。
- **移除后副作用**: 合并后 Sensors 页只保留一个综合面板。建议保留信号卡（含状态徽章，信息更丰富），将信号表独有的 `thermalText`/`kernelText` 并入信号卡或 thermalPanel。或保留信号表，移除信号卡中 8 个重叠项。移除后无信息损失。
- **建议**: 合并两个面板为一个：以信号卡为基（含状态徽章），补充 `kernelText` 卡片；移除信号表。或反之。二者择一，消除同页 8 项重叠。
- **优先级**: R-高（同页 8 项重叠，是本次审查单点冗余量最大的一处）

### 冗余 R1-7：WidgetMiniPreview 在 Overview 页与 Settings 页完全相同地渲染两次
- **位置1**: `DashboardView.swift:453` / `:458` — Overview 页 `WidgetPreviewPanel` 内 `WidgetMiniPreview(snapshot:)`
- **位置2**: `DashboardView.swift:1191` — Settings 页 `widgetPreviewPanel` 内 `WidgetMiniPreview(snapshot:)`
- **冗余描述**: `WidgetMiniPreview`（:1368-1405）渲染 "Pulse Dock" 标题 + `StatusDot` + `sampleClockText`（:1379）+ CPU RingGauge（`cpuText` :1385）+ MEM RingGauge（`memoryUsageText` :1386）。Overview 页与 Settings 页用完全相同的入参 `snapshot` 调用同一个 `WidgetMiniPreview`，产出像素级相同的预览。Overview 页的预览旁边还有 MetricCards（CPU/MEM 卡片含 sparkline + 百分比），WidgetMiniPreview 的 CPU/MEM 环形图与 MetricCards 的 CPU/MEM 数值在同屏重复。
- **是否有意冗余**: 部分有意。Overview 的 WidgetPreviewPanel 意图是"展示 widget 长什么样"，Settings 的意图是"配置预览"。但二者渲染完全相同，且 Overview 的 WidgetMiniPreview CPU/MEM 与同页 MetricCards 重复。Settings 页的 WidgetMiniPreview 才是配置上下文的自然位置。
- **移除后副作用**: 移除 Overview 页 `WidgetPreviewPanel`（:450-461 整个 if/else 块）后，Overview 页保留 MetricCards + StatusPanel + ProcessListPanel。Widget 预览仍可在 Settings 页查看。无信息损失。或移除 Settings 页预览保留 Overview 预览。
- **建议**: 移除 Overview 页 `WidgetPreviewPanel`（:450-461），widget 预览仅保留在 Settings 页（配置上下文更贴切）。
- **优先级**: R-低（预览有"所见即所得"体验价值，但两处完全相同确属冗余）

### 冗余 R1-8：Network 页连接状态 MetricCard 与连通性表首行重复
- **位置1**: `DashboardView.swift:708` — Network 页 `MetricCard(networkConnectionStatusTitle, value: networkPathText, detail: networkPathDetailText, ...)`（含进度条 + sparkline）
- **位置2**: `DashboardView.swift:716` — Network 页连通性表首行 `[networkPathLabel, networkPathText, networkPathDetailText]`
- **冗余描述**: 同一 Network 页内，连接状态 MetricCard 已展示 `networkPathText`（值）+ `networkPathDetailText`（详情）。紧随其后的连通性表第一行 `[networkPathLabel, networkPathText, networkPathDetailText]` 展示完全相同的值与详情。表首行相对 MetricCard 无新增价值（MetricCard 还额外有进度条与趋势 sparkline，信息更丰富）。
- **是否有意冗余**: 否。连通性表本意是逐行列出所有路径能力（Path/Capability/DNS/IPv4/IPv6/LowData/Metered），但第一行"Path"与上方的连接状态 MetricCard 重复。
- **移除后副作用**: 连通性表从 7 行减为 6 行（移除首行 Path）。连接状态值仍由 MetricCard 提供。无信息损失。
- **建议**: 移除连通性表首行 `:716`（`networkPathLabel` 行），保留 MetricCard 作为连接状态展示，表从 Capability 行开始。
- **优先级**: R-低

### 冗余 R1-9：Power 页 thermalPanel 的 thermalText / uptimeText 与 Overview StatusPanel 重复
- **位置1**: `DashboardView.swift:480` — Overview `overviewStatusPanel` `StatusSummaryRow(statusThermalTitle, thermalText)`
- **位置2**: `DashboardView.swift:837` — Power 页 `thermalPanel` `StatusSummaryRow(statusCurrentStateTitle, thermalText)`
- **位置3**: `DashboardView.swift:481` — Overview `overviewStatusPanel` `StatusSummaryRow(metricUptime, uptimeText)`
- **位置4**: `DashboardView.swift:839` — Power 页 `thermalPanel` `StatusSummaryRow(metricUptime, uptimeText)`
- **冗余描述**: Power 页 `thermalPanel`（:834-843）含 4 行 StatusSummaryRow：`thermalText`(:837) / `thermalLimitText`(:838) / `uptimeText`(:839) / `sampleTimeText`(:840)。其中 `thermalText` 与 `uptimeText` 两行与 Overview `overviewStatusPanel`（:480/:481）使用相同的 `StatusSummaryRow` 组件、相同的值、相同的 status 判定逻辑（`thermalStatus(snapshot.thermalState)` / `snapshot.hasUptimeReport`）。后一处相对前一处无新增价值（同为 StatusSummaryRow，同值同状态）。`sampleTimeText` 行已在 R1-2 覆盖。
- **是否有意冗余**: 否。Power 页 `thermalPanel` 本应聚焦"热状态 + 性能限制"，但塞入了 `uptimeText` 与 `sampleTimeText` 两行与主题无关的通用状态，这些已在 Overview StatusPanel 覆盖。
- **移除后副作用**: Power 页 `thermalPanel` 保留 `thermalText` + `thermalLimitText` 两行（热状态主题相关），移除 `uptimeText`(:839) 与 `sampleTimeText`(:840)。`uptimeText` 仍由 Overview StatusPanel / Sensors / History 趋势 / popover 提供。无信息损失。
- **建议**: 移除 Power 页 `thermalPanel` 的 `uptimeText`(:839) 与 `sampleTimeText`(:840) 行。`thermalText` 在 Power 页有上下文意义（电源/热联动），可保留，但需注意与 Overview :480 重复——若要彻底去重可仅保留 Overview，Power 页 `thermalPanel` 仅留 `thermalLimitText`。
- **优先级**: R-低（`thermalText` 在 Power 页有上下文合理性，但 `uptimeText`/`sampleTimeText` 在 Power 页 thermalPanel 中属错位放置）

---

## 三、已验证为有意冗余的项（排除项）

以下冗余经评估确认为"有意设计"，不计入需移除的冗余清单：

1. **Widget（SystemDashboardWidget）与 App 展示同一数据点** — WidgetKit 扩展是独立进程，无法复用 App 的 SwiftUI 视图树，必须独立渲染。`cpuText`/`memoryUsageText`/`diskUsageText`/`networkPathText`/`thermalText`/`powerStatusText`/`uptimeText`/`osVersionText`/`kernelText`/`loadText`/`sampleClockText` 在 Small/Medium/Large widget 中的展示均为跨进程必要冗余。保留。

2. **WidgetPanelView popover 与 Dashboard 展示同一数据点** — popover 是 menu bar 点击入口，用户可能仅打开 popover 而不打开主窗口，属不同入口点。popover 内 `cpuText`/`memoryUsageText`/`diskUsageText`/`networkText`/`networkPathText`/`thermalText`/`powerStatusText`/`loadText`/`uptimeText`/`kernelText`/`displaySummaryText`/`storageVolumeSummaryText`/`sampleTimeText` 的展示均为独立入口必要冗余。保留。

3. **AppDelegate menubar title 展示 `cpuText`** — menubar 状态项是系统级常驻微指示器（仅 72pt 宽显示一个百分比），属独立系统表面。保留。

4. **SidebarHealthCard 的 CPU/Mem/Disk 压缩行** — 侧栏目的是"切页时常驻可见核心指标"（在 Network 页也能看 CPU/Mem/Disk）。相对 Overview MetricCards，侧栏在非 Overview 页提供新增价值（常驻可见）。仅 `sampleTimeText`（R1-1）在侧栏与顶栏间无此正当性。侧栏指标行保留，侧栏 `sampleTimeText` 见 R1-1。

5. **Overview StatusPanel 作为单屏状态摘要** — `overviewStatusPanel`（:477-492）的 10 行 StatusSummaryRow 聚合 thermal/uptime/kernel/cpu/mem/load/runningApps/network/gpuDisplay/diskAvailable，意图是"一屏概览全部状态"。相对各 dedicated 页面（CPU/Memory/Network/Power...），Overview StatusPanel 是"摘要 vs 详情"关系，属不同粒度。其中 `runningAppSummaryText`(:486) 与 `gpuDisplaySummaryText`(:488) 是全应用唯一位置，无冗余。其余项与 dedicated 页的重复属摘要模式的可接受冗余。整体保留（个别项如 thermal/uptime 在 Power 页的错位重复见 R1-9）。

6. **MetricCard 内 `badgeText` 重复 `value`** — Overview `MetricCard`（:431 `badgeText: snapshot.cpuText`，:432 `badgeText: snapshot.memoryUsageText`）将值同时作为大字号 `value` 与右上角 `badgeText` 展示。这是视觉层级设计（大数为主、徽章为辅），非信息冗余。保留。

7. **`sampleTimeText`（时分秒）vs `sampleClockText`（时分）** — 二者是不同格式的时间文本：App 内用 `sampleTimeText`（含秒），Widget/WidgetMiniPreview 用 `sampleClockText`（不含秒，适配 widget 紧凑布局）。格式差异属不同表面的有意适配，非同一字符串的重复。保留。

---

## 汇总

共发现 **9 条** 信息冗余（R1-1 ~ R1-9），其中：
- **R-高**（2 条）：R1-3 规则表跨页逐行重复、R1-6 Sensors 同页 8 项重叠
- **R-中**（4 条）：R1-1 侧栏/顶栏时间戳双常驻、R1-2 CPU/Power 页 Recent Sample 与顶栏重叠、R1-4 Overview 趋势 5 行 ⊂ History 8 行、R1-5 Settings widget 预览 Refresh/MainWindow 行重复
- **R-低**（3 条）：R1-7 WidgetMiniPreview 双页同渲染、R1-8 Network 页连接卡与表首行重复、R1-9 Power 页 thermalPanel 错位放置 uptime/sampleTime

排除项 7 类（跨进程 widget / 跨入口 popover / menubar / 侧栏常驻指标 / Overview 摘要模式 / MetricCard 徽章 / 时间格式差异），均为有意冗余。
