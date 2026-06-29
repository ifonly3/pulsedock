# F1 同页内重复 — 报告

## 方法

逐页读取 `DashboardView.swift`（2263 行），对每个页面内所有面板/元素进行两两比较，识别展示相同数据点的冗余。

**判定标准**：
- **真冗余**：同页内两元素展示相同数据且后者无新增价值
- **需权衡**：核心数据字段相同，但后者有不同列结构/进度条/交互，或可优化合并
- **F-高**：同页内完全相同的数据重复，用户直接注意到
- **F-中**：核心数据重复但呈现方式略有差异，可优化
- **F-低**：标签/标题重复但数据值不同，或摘要 vs 详情的合理重复

---

## 复核后处理结论

- F1-1 / FR-2：采纳，但保留 Battery Information 表作为含 source 的详情源，缩减 `powerDetails`。
- F1-2 / FR-3：采纳，删除 Network 趋势面板。
- F1-3 / FR-4：采纳，删除连通性表首行。
- F1-4 / FR-11：采纳，Memory KeyValueGrid 删除 compressed/cached/swap 三行。
- F1-5 / FR-5：采纳，随 Overview 趋势面板删除。
- F1-6 / FR-12：采纳，Overview StatusPanel 删除 CPU/Memory/Network 三行。
- F1-7 / FR-20：保留，RingGauge 与 TrendRow 语义不同。
- F1-8 / FR-13：采纳，规则表删除当前值列。
- F1-9 / FR-7：采纳，页面内 sampleTime 行删除，顶栏保留。

---

## 逐页结构图

### Overview 页（:414-493）
- MetricCard x4（:430-433）：CPU / Memory / Network / Power → `cpuText`, `memoryUsageText`, `networkText`, `powerStatusText`
- TrendRow x5（:467-471）：CPU / Load / Memory / Network / Disk → `cpuText`, `loadText`, `memoryUsageText`, `networkText`, `diskUsageText`
- StatusSummaryRow x10（:479-488）：thermal / uptime / kernel / cpuStatus / memoryStatus / load / runningApps / network / gpuDisplays / diskAvailable
- ProcessListPanel(:451/456) + WidgetPreviewPanel(:452/457)

### CPU 页（:495-564）
- processorPanel（:525-544）：大数 `cpuText` + sparkline
- loadPanel（:546-563）：StatLine x3（`loadText`, `loadAverage5Text`, `loadAverage15Text`）+ KeyValueGrid（brand/cores/processes/sampleTime）
- Per-core panel（:509-519）：CoreUsageTile
- ProcessListPanel（:521）

### Memory 页（:566-634）
- memoryUsagePanel（:585-601）：RingGauge + MemorySegmentBar + TrendRow（`memoryText`）+ KeyValueGrid 7 行（total/free/cached/compressed/swap/swapAvailable/swapTotal）
- compositionPanel（:623-633）：StatLine x5（appActive/wired/compressed/cachedFiles/swap）
- ProcessListPanel（:581）

### Storage 页（:636-689）
- Main panel（:645-660）：大数 `diskUsedText` + CapacityBar + TrendRow（`diskUsageText`）
- SourceCapabilityCard x3（:662-666）：`storageVolumeSummaryText` / `diskAvailableText` / `externalStorageVolumeSummaryText`
- Volume table（:668-685）

### Network 页（:691-758）
- MetricCard x5（:703-708）：Download / Upload / Total / Connection / Interface
- Connectivity table 7 行（:711-725）
- TrendRow x4（:729-732）：Total / Connection / Download / Upload
- Interface table（:736-755）

### Power 页（:760-843）
- batteryPanel（:794-831）→ RingGauge（`powerStatusText`）+ TrendRow（`powerStatusText`）+ KeyValueGrid 9 行（powerSource/remainingTime/currentCapacity/maxCapacity/cycleCount/health/designCapacity/voltage/amperage）
- thermalPanel（:833-841）：StatusSummaryRow x4（thermal/thermalLimit/uptime/sampleTime）
- Battery Information table（:775-790）：8 行 ResponsiveTable

### GPU/Display 页（:845-911）
- SourceCapabilityCard x3（:852-854）：GPU（`gpuSummaryText`）/ Displays（`displaySummaryText`）/ Unified Memory（`unifiedMemorySummary`）
- GPU device table（:857-872）：individual GPU device rows
- Display table（:875-893）：individual display rows

### Processes 页（:913-942）
- SummaryCard x4（:920-923）：`runningAppCountText` / `runningAppListCountText` / `activeApplicationCountText` / `hiddenApplicationCountText`
- ProcessListPanel（:926-939）：full process table

### Sensors 页（:944-1008）
- thermalPanel（:981-989）：RingGauge（`thermalText`）+ StatusSummaryRow（`thermalLimitText`）
- realtimeSignalsPanel（:991-1007）：11 张 SourceCapabilityCard（CPU / Memory / Disk / Power / Network / Displays / GPU / StorageVolumes / Load / SystemVersion / Uptime）
- Rule table（:966-977）：4 行（CPU / Memory / Disk / Network 的阈值 + 当前值 + 状态）

### History / Alerts 页（:1010-1049）
- TrendPanel（:1026-1039）：Sparkline + TrendRow x8（CPU / Load / Memory / Network / Disk / Thermal / Uptime / Power）
- ThresholdControlRow x3（:1043-1045）：CPU / Memory / Disk 阈值滑块

### Settings 页（:1052-1168）
- refreshDisplayPanel（:1104-1153）：SettingControlRow x3（mainWindowRefresh / menuBar / historyDepth）+ SettingReadOnlyRow（widgetRefresh）
- widgetPreviewPanel（:1155-1167）：WidgetMiniPreview + KeyValueGrid（widgetSize / dataSource / sampleTime / historyDuration）
- Data sources table（:1085-1100）
- Support/Privacy panel（:1074-1083）

---

## 发现清单

### 已验证的锚点

---

#### F1-1 [ANCHOR-F4] Power 页 — KeyValueGrid 与 Battery Information 表 8 行重复

- **页面**：Power（:760-843）
- **位置 A**：`powerDetails` -> KeyValueGrid（:819-829），9 行：(powerSource, `powerSourceText`), (remainingTime, `batteryTimeRemainingText`), (currentCapacity, `batteryCurrentCapacityText`), (maxCapacity, `batteryMaxCapacityText`), (cycleCount, `batteryCycleText`), (health, `batteryHealthText`), (designCapacity, `batteryDesignCapacityText`), (voltage, `batteryVoltageText`), (amperage, `batteryAmperageText`)
- **位置 B**：Battery Information -> ResponsiveTable（:778-787），8 行：(remainingTime, `batteryTimeRemainingText`), (currentCapacity, `batteryCurrentCapacityText`), (maxCapacity, `batteryMaxCapacityText`), (designCapacity, `batteryDesignCapacityText`), (cycleCount, `batteryCycleText`), (health, `batteryHealthText`), (voltage, `batteryVoltageText`), (amperage, `batteryAmperageText`)
- **冗余数据点**：`batteryTimeRemainingText`, `batteryCurrentCapacityText`, `batteryMaxCapacityText`, `batteryDesignCapacityText`, `batteryCycleText`, `batteryHealthText`, `batteryVoltageText`, `batteryAmperageText` — 8 个字段完全重复
- **新增价值**：B (ResponsiveTable) 多一个 `source` 列（3 列 vs KeyValueGrid 的 2 列），但数据字段完全相同。KeyValueGrid 额外有 `powerSourceText` 行（第 9 行）
- **判定**：真冗余
- **优先级**：F-高

---

#### F1-2 [ANCHOR-F6] Network 页 — MetricCard 与 TrendRow 4 指标重复

- **页面**：Network（:691-758）
- **位置 A**：5 张 MetricCard（:704-708）：Download / Upload / Total / Connection / Interface，每张含 value + progress bar + sparkline
- **位置 B**：Network 趋势面板 4 行 TrendRow（:729-732）：Total / Connection / Download / Upload，每行含 value + sparkline
- **冗余数据点**：
  - Total：`snapshot.networkText` + sparkline(`networkTrend`)
  - Connection：`snapshot.networkPathText` + sparkline(`networkPathTrend`)
  - Download：`snapshot.networkInText` + sparkline(`networkDownloadTrend`)
  - Upload：`snapshot.networkOutText` + sparkline(`networkUploadTrend`)
- **新增价值**：TrendRow 相对 MetricCard 无新增价值。MetricCard 更丰富（含 progress bar + 大数显示），TrendRow 是纯子集
- **判定**：真冗余
- **优先级**：F-高

---

#### F1-3 [ANCHOR-F7] Network 页 — MetricCard Connection 与连通性表首行重复

- **页面**：Network（:691-758）
- **位置 A**：MetricCard Connection（:707）：value=`snapshot.networkPathText`, detail=`snapshot.networkPathDetailText`
- **位置 B**：连通性表首行（:715）：`[networkPathLabel, snapshot.networkPathText, snapshot.networkPathDetailText]`
- **冗余数据点**：`networkPathText`, `networkPathDetailText`
- **新增价值**：MetricCard 更丰富（含进度条 + sparkline + 大数），表首行无新增价值
- **判定**：真冗余
- **优先级**：F-高

---

#### F1-4 [ANCHOR-F9] Memory 页 — KeyValueGrid 与 compositionPanel StatLine 部分重复

- **页面**：Memory（:566-634）
- **位置 A**：`memoryDetails` -> KeyValueGrid（:611-619），7 行：total / free / **cached** / **compressed** / **swap** / swapAvailable / swapTotal
- **位置 B**：`compositionPanel` -> StatLine x5（:626-631）：appActive / wired / **compressed** / **cachedFiles** / **swap**
- **冗余数据点**：
  - compressed：`snapshot.memoryCompressedText`
  - cached：`snapshot.memoryCachedText`
  - swap：`snapshot.memorySwapText`
- **新增价值**：B (StatLine) 有 progress bar（归一化百分比），A (KeyValueGrid) 无进度条。但 cached 在 A 中为 "Cached"，B 中为 "Cached Files"（同一数据 `memoryCachedText`）；swap 在 A 中为 "Swap"，B 中为 "Swap"（同一数据 `memorySwapText`）
- **判定**：需权衡。B 有进度条新增价值，但 A 无进度条且与 B 数据重叠
- **优先级**：F-中

---

### 新增发现（非锚点）

---

#### F1-5 Overview 页 — MetricCard (CPU/Memory/Network) 与 TrendRow (CPU/Memory/Network) 重复

- **页面**：Overview（:414-493）
- **位置 A**：MetricCard CPU（:430）+ Memory（:431）+ Network（:432）
- **位置 B**：TrendRow CPU（:467）+ Memory（:469）+ Network（:470）
- **冗余数据点**：
  - CPU：`snapshot.cpuText` + sparkline(`cpuTrend`)
  - Memory：`snapshot.memoryUsageText` + sparkline(`memoryTrend`)
  - Network：`snapshot.networkText` + sparkline(`networkTrend`)
- **新增价值**：B (TrendRow) 相对 A (MetricCard) 无新增价值 — MetricCard 已包含 value + progress bar + sparkline + detail。TrendRow 仅含 value + sparkline，是 MetricCard 的子集
- **判定**：真冗余。同一页面上方 4 张 MetricCard 已展示 CPU/Memory/Network，下方趋势面板又以 TrendRow 重复展示相同值+sparkline。用户在同页看到每项指标两次
- **优先级**：F-高

---

#### F1-6 Overview 页 — StatusSummaryRow CPU/Memory 与 MetricCard/TrendRow CPU/Memory 重复

- **页面**：Overview（:414-493）
- **位置 A**：StatusSummaryRow CPU（:482）：`"snapshot.cpuText / MetricFormatting.percentage(store.cpuAlertThreshold)"`
- **位置 A'**：MetricCard CPU（:430）：`snapshot.cpuText`
- **位置 A''**：TrendRow CPU（:467）：`snapshot.cpuText`
- **位置 B**：StatusSummaryRow Memory（:483）：`"snapshot.memoryUsageText / MetricFormatting.percentage(store.memoryAlertThreshold)"`
- **位置 B'**：MetricCard Memory（:431）：`snapshot.memoryUsageText`
- **位置 B''**：TrendRow Memory（:469）：`snapshot.memoryUsageText`
- **冗余数据点**：`cpuText`, `memoryUsageText`
- **新增价值**：StatusSummaryRow 叠加了阈值信息（"value / threshold"），不仅仅是裸值。但同一页面上 CPU 值已在 MetricCard 和 TrendRow 中出现两次，StatusSummaryRow 是第三次
- **判定**：需权衡。StatusSummaryRow 有阈值附加值，但同一页面同一数据出现三次（MetricCard + TrendRow + StatusSummaryRow）明显过度
- **优先级**：F-中

---

#### F1-7 Power 页 — RingGauge powerStatusText 与 TrendRow powerStatusText 重复

- **页面**：Power（:760-843）
- **位置 A**：`powerGauge` -> RingGauge（:813）：value=`snapshot.powerStatusText`
- **位置 B**：`powerDetails` -> TrendRow（:818）：value=`snapshot.powerStatusText`
- **冗余数据点**：`powerStatusText`
- **新增价值**：两者同在 `batteryPanel` 内。RingGauge 以环图+大字展示 `powerStatusText`，TrendRow 在下方以（标题 + sparkline + value）格式展示相同 `powerStatusText`。TrendRow 有 sparkline，RingGauge 无 sparkline。但用户在同面板看到 powerStatusText 两次
- **判定**：需权衡。TrendRow 有 sparkline（趋势线）新增价值，但两元素同面板展示相同值
- **优先级**：F-低

---

#### F1-8 Sensors 页 — realtimeSignalsPanel (CPU/Memory/Disk/Network) 与 Rule table (CPU/Memory/Disk/Network) 重复

- **页面**：Sensors（:944-1008）
- **位置 A**：`realtimeSignalsPanel` 11 张 SourceCapabilityCard（:994-998）：
  - CPU 卡（:994）：value=`snapshot.cpuText`
  - Memory 卡（:995）：value=`snapshot.memoryUsageText`
  - Disk 卡（:996）：value=`snapshot.diskUsageText`
  - Network 卡（:998）：value=`snapshot.networkPathText`
- **位置 B**：Rule table（:966-977）4 行（:970-973）：
  - CPU 行（:970）：第 3 列 `snapshot.cpuText`
  - Memory 行（:971）：第 3 列 `snapshot.memoryUsageText`
  - Disk 行（:972）：第 3 列 `snapshot.diskUsageText`
  - Network 行（:973）：第 3 列 `snapshot.networkPathText`
- **冗余数据点**：
  - `cpuText` — CPU 卡 / CPU 规则行
  - `memoryUsageText` — Memory 卡 / Memory 规则行
  - `diskUsageText` — Disk 卡 / Disk 规则行
  - `networkPathText` — Network 卡 / Network 规则行
- **新增价值**：B (Rule table) 的 primary 目的是展示阈值配置和判定状态（阈值列 + 状态列），当前值列是附带字段。A (realtimeSignalsPanel) 的 primary 目的是展示实时信号值。Rule table 多出阈值百分比和状态列
- **判定**：需权衡。Rule table 的核心功能是阈值管理而非实时值，但当前值列与 realtimeSignalsPanel 重复。可考虑将 Rule table 的当前值列移除或替换为 delta/变化指示
- **优先级**：F-中

---

#### F1-9 Settings 页 — widgetPreviewPanel KeyValueGrid sampleTimeText 与顶栏 DataChip sampleTimeText 重复

- **页面**：Settings（:1052-1168）
- **位置 A**：`widgetPreviewPanel` KeyValueGrid（:1162）：`snapshot.sampleTimeText`
- **位置 B**：DashboardTopBar DataChip（:408）：`PulseDockAppStrings.dashboardSampleChip(snapshot.sampleTimeText)`
- **冗余数据点**：`sampleTimeText`
- **新增价值**：顶栏 DataChip 的 sampleTimeText 带 "Sample:" 前缀标签，widgetPreviewPanel 的 sampleTimeText 带 "Sample" 标签。两者在 Settings 页上同时可见。顶栏是所有页面的常驻元素（chrome），属于跨页重复范畴（F3 覆盖）
- **判定**：需权衡。顶栏常驻属于有意冗余，但 widgetPreviewPanel 的 sampleTimeText 在 Settings 页的确与顶栏重复
- **优先级**：F-低

---

#### F1-10 GPU/Display 页 — SourceCapabilityCard 摘要与 GPU/Display 表细节 — 无直接数据值重叠

- **页面**：GPU/Display（:845-911）
- **位置 A**：SourceCapabilityCard（:852-853）：`snapshot.gpuSummaryText`, `snapshot.displaySummaryText`
- **位置 B**：GPU device table（:857-872）：individual GPU device rows
- **位置 B'**：Display table（:875-893）：individual display rows
- **结论**：卡片展示聚合摘要文本（如 "2 GPUs, 16 GB"），表格展示逐设备明细（name/kind/memory/state）。无同一数据字段的直接值重叠，属合理的"摘要 vs 详情"模式
- **判定**：无冗余
- **优先级**：N/A

---

#### F1-11 History 页 — TrendRow (CPU/Memory/Disk) 与 ThresholdControlRow (CPU/Memory/Disk) — 数据不同

- **页面**：History（:1010-1049）
- **位置 A**：TrendRow（:1030-1032）：`snapshot.cpuText`, `snapshot.memoryUsageText`, `snapshot.diskUsageText`（实际数值）
- **位置 B**：ThresholdControlRow（:1043-1045）：`store.cpuAlertThreshold`, `store.memoryAlertThreshold`, `store.diskAlertThreshold`（阈值配置）
- **结论**：标签标题重合（"CPU"/"Memory"/"Disk"），但实际数据值完全不同（实际值 vs 阈值）。无数据冗余
- **判定**：无冗余（仅标签文字重合）
- **优先级**：N/A

---

## 汇总

### 总计发现同页内重复：6 条（含 4 条已验证锚点 + 2 条新增）

| 编号 | 页面 | 位置 A | 位置 B | 冗余数据点 | 判定 | 优先级 |
|------|------|--------|--------|-----------|------|--------|
| F1-1 | Power | KeyValueGrid（:819-829） | Battery Information 表（:778-787） | 8 fields | 真冗余 | F-高 |
| F1-2 | Network | MetricCard x5（:704-708） | TrendRow x4（:729-732） | 4 fields | 真冗余 | F-高 |
| F1-3 | Network | MetricCard Connection（:707） | 连通性表首行（:715） | 2 fields | 真冗余 | F-高 |
| F1-5 | Overview | MetricCard CPU/Memory/Network（:430-432） | TrendRow CPU/Memory/Network（:467-470） | 3 fields | 真冗余 | F-高 |
| F1-4 | Memory | KeyValueGrid（:611-619） | compositionPanel StatLine（:626-631） | 3 fields | 需权衡 | F-中 |
| F1-6 | Overview | MetricCard/TrendRow CPU/Memory | StatusSummaryRow CPU/Memory（:482-483） | 2 fields | 需权衡 | F-中 |
| F1-8 | Sensors | realtimeSignalsPanel 4 卡（:994-998） | Rule table 4 行（:970-973） | 4 fields | 需权衡 | F-中 |
| F1-7 | Power | RingGauge powerStatusText（:813） | TrendRow powerStatusText（:818） | 1 field | 需权衡 | F-低 |
| F1-9 | Settings | widgetPreviewPanel KeyValueGrid（:1162） | 顶栏 DataChip（:408） | 1 field | 需权衡（跨页） | F-低 |
| F1-10 | GPU/Display | SourceCapabilityCard（:852-853） | GPU/Display 表 | — | 无冗余 | N/A |
| F1-11 | History | TrendRow CPU/Memory/Disk | ThresholdControlRow | — | 无冗余 | N/A |

### 优先级分布

| 级别 | 数量 | 条目 |
|------|------|------|
| **F-高** | 4 条 | F1-1, F1-2, F1-3, F1-5 |
| **F-中** | 3 条 | F1-4, F1-6, F1-8 |
| **F-低** | 2 条 | F1-7, F1-9 |
| **N/A（无冗余）** | 2 条 | F1-10, F1-11 |
| **总计有效冗余** | **9 条** | |

### 说明

1. **锚点 F11（ProcessListPanel 跨页重复）** 属跨页子集范畴，不在本 F1 报告中，由 F2 子任务覆盖。
2. **F1-9（Settings widgetPreviewPanel sampleTimeText）** 本质是跨页重复（顶栏常驻元素），但因同页可见而归入本报告作为 F-低。
3. **F1-6（Overview StatusSummaryRow CPU/Memory）** 与 F1-5（MetricCard vs TrendRow）是同一问题的不同层次 — 同一页面 CPU 值出现三次（MetricCard + TrendRow + StatusSummaryRow），Memory 同理。
4. **CPU 页** 经逐行扫描未发现同页内数据值重复。processorPanel 的 `cpuText` 与 loadPanel 的 `loadText` 是不同指标，无冗余。
5. **Storage 页** 经逐行扫描未发现同页内数据值重复。`diskUsedText`（大数）vs `diskUsageText`（TrendRow 百分比）是不同的数据字段。
6. **Processes 页** 4 张 SummaryCard 展示 4 个不同计数，彼此无重叠，与 ProcessListPanel 属"摘要 vs 详情"关系，合理。
7. **GPU/Display 页** SourceCapabilityCard 是聚合摘要文本，GPU/Display 表是逐行明细，无直接值重叠。
8. **History 页** TrendRow 展示实际值，ThresholdControlRow 展示阈值配置值，数据不同，仅标签标题重合。
