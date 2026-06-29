# Pulse Dock 前端冗余显示 — 最终审查清单

> 基于 F1（同页内重复，9 条）+ F2（跨页子集与错位，13 条）+ F3（常驻元素与摘要面板，10 条）三层扫描，去重后共 **25 条独特发现**，其中 24 条属于当前主窗口，FR-25 属于跨入口 popover 检查且无需处理。

---

## 去重对照（12 条跨级重复）

| 合并后 | F1 编号 | F2 编号 | F3 编号 | 采用优先级 |
|--------|---------|---------|---------|-----------|
| **FR-1** Overview 趋势 ⊂ History 趋势 | — | F2-1 | F3-9 | F-高 |
| **FR-2** Power KeyValueGrid vs Battery 表 | F1-1 | — | — | F-高 |
| **FR-3** Network MetricCard vs TrendRow | F1-2 | — | — | F-高 |
| **FR-4** Network MetricCard Connection vs 连通性表首行 | F1-3 | — | — | F-高 |
| **FR-5** Overview MetricCard vs TrendRow | F1-5 | — | — | F-高 |
| **FR-6** ProcessListPanel subtitle 不一致 | — | F2-10 | — | F-高 |
| **FR-7** CPU/Power Recent Sample 行 vs 顶栏 chip | F1-9 | F2-11 | F3-2 | F-中 |
| **FR-8** Power thermalPanel vs Sensors thermalPanel | — | F2-2 | (F3-5 子集) | F-中 |
| **FR-9** Power thermalPanel uptime/sampleTime 错位 | — | F2-3 | — | F-中 |
| **FR-10** 侧栏 SidebarHealthCard vs Overview MetricCard | — | — | F3-1 | F-中 |
| **FR-11** Mem KeyValueGrid vs compositionPanel StatLine | F1-4 | — | — | F-中 |
| **FR-12** Overview CPU/Memory 三次展示 | F1-6 | — | — | F-中 |
| **FR-13** Sensors realtimeSignalsPanel vs Rule table | F1-8 | — | — | F-中 |
| **FR-14** Sensors realtimeSignalsPanel 11 卡 vs 各页 | — | F2-5 | F3-5 | F-中 |
| **FR-15** Overview StatusPanel 10 行过度摘要 | — | F2-6 | F3-4 | F-中 |
| **FR-16** CPU ProcessListPanel vs Processes 页 | — | F2-12 | — | F-中 |
| **FR-17** Memory ProcessListPanel vs Processes 页 | — | F2-13 | — | F-中 |
| **FR-18** History 趋势 8 行 vs Overview MetricCard sparkline | — | — | F3-7 | F-中 |
| **FR-19** Overview WidgetPreviewPanel = Settings widgetPreviewPanel | — | F2-4 | F3-8 | F-低 |
| **FR-20** Power RingGauge vs TrendRow powerStatusText | F1-7 | — | — | F-低 |
| **FR-21** History ThresholdControlRow vs Sensors 规则表 | — | F2-7 | — | F-低 |
| **FR-22** Storage/Sensors SourceCapabilityCard 单字段重复 | — | F2-8/9 | — | F-低 |
| **FR-23** 顶栏 refreshInterval.label vs Settings Picker | — | — | F3-3 | F-低 |
| **FR-24** Processes SummaryCard 4 张 | — | — | F3-6 | F-低 |
| **FR-25** Popover WidgetPanelView 内部冗余 | — | — | F3-10 | 无（跨入口有意） |

### 不纳入计数的重叠项
- F1-9 → 合并入 FR-7（Settings sampleTime vs 顶栏 = 等同 CPU/Power）
- F2-8/9 → 合并入 FR-22（Sensors vs Storage/GPU 单/双字段）
- F2-4/F3-8 → FR-19
- F2-6/F3-4 → FR-15
- F2-5/F3-5 → FR-14

---

## 最终统计数据

| 指标 | 合计 |
|------|------|
| 独特发现 | **25 条**（含 FR-25 无需处理） |
| F-高 | **6 条**（FR-1 ~ FR-6） |
| F-中 | **12 条**（FR-7 ~ FR-18） |
| F-低 | **6 条**（FR-19 ~ FR-24） |
| 无需处理 | **1 条**（FR-25） |
| 前次 R-高 待修引用 | 0 条（前次 R-高 7 条[^prior] 与前端冗余正交） |

[^prior]: R1-3 (规则表跨页)、R1-6 (Sensors 表重叠)、D2 (Sensors 规则表移动)、前两轮修复已覆盖

---

## 按页面分布

| 页面 | F-高 | F-中 | F-低 | 主要冗余 |
|------|------|------|------|----------|
| **Sidebar** | — | 1 | — | FR-10 SidebarHealthCard 3 行常驻 |
| **TopBar** | — | 1 | 1 | FR-7 sampleTime 重复；FR-23 refreshInterval |
| **Overview** | 2 | 3 | 1 | FR-1 趋势⊂History；FR-5 MetricCard vs TrendRow；FR-12 三次展示；FR-15 StatusPanel；FR-19 WidgetPreview |
| **CPU** | — | 2 | — | FR-7 Recent Sample 行；FR-16 ProcessListPanel |
| **Memory** | — | 2 | — | FR-11 KeyValueGrid vs compositionPanel；FR-17 ProcessListPanel |
| **Network** | 2 | — | — | FR-3 MetricCard vs TrendRow；FR-4 Connection vs 连通性表首行 |
| **Power** | 1 | 2 | 1 | FR-2 KeyValueGrid vs Battery 表；FR-8/9 thermalPanel 重复+错位；FR-20 RingGauge vs TrendRow |
| **Sensors** | — | 3 | — | FR-8 thermalPanel；FR-13 vs Rule table；FR-14 realtimeSignalsPanel 11 卡 |
| **GPU/Display** | — | — | 1 | FR-22 单字段跨页 |
| **Storage** | — | — | 1 | FR-22 单字段跨页 |
| **Processes** | — | — | 1 | FR-24 SummaryCard |
| **History** | 1 | 1 | 1 | FR-1 趋势⊃Overview；FR-18 趋势 vs MetricCard sparkline；FR-21 Threshold vs Sensors |
| **Settings** | — | — | 1 | FR-19 WidgetPreview = Overview |

---

## F-高 详细清单与移除方案

### FR-1 Overview 趋势面板 5 行是 History 趋势面板 8 行的纯子集

| 属性 | 值 |
|------|------|
| 源报告 | F2-1 / F3-9 |
| 位置 A | `DashboardView.swift:464-474` — Overview `overviewTrendPanel` 5 行 TrendRow |
| 位置 B | `DashboardView.swift:1026-1038` — History 趋势面板 8 行 TrendRow |
| 冗余数据 | `cpuText`, `loadText`, `memoryUsageText`, `networkText`, `diskUsageText` |
| 新增价值 | 无。Overview 同页 MetricCard (:430-433) 已含 sparkline 提供趋势预览 |
| **移除方案** | 移除整个 `overviewTrendPanel`（:464-474）。Overview 4 张 MetricCard 的 sparkline + History 8 行 TrendPanel 完全覆盖用户趋势查看需求 |

### FR-2 Power 页 KeyValueGrid 与 Battery Information 表 8 行重复

| 属性 | 值 |
|------|------|
| 源报告 | F1-1 |
| 位置 A | `DashboardView.swift:819-829` — batteryPanel `powerDetails` KeyValueGrid 9 行 |
| 位置 B | `DashboardView.swift:778-787` — Battery Information ResponsiveTable 8 行 |
| 冗余数据 | `batteryTimeRemainingText`, `batteryCurrentCapacityText`, `batteryMaxCapacityText`, `batteryDesignCapacityText`, `batteryCycleText`, `batteryHealthText`, `batteryVoltageText`, `batteryAmperageText` |
| 新增价值 | KeyValueGrid 多 1 行 (powerSourceText)；Battery 表多 1 列 (source)。但 8 个核心字段完全重复 |
| **移除方案** | 保留 Battery Information 表（:774-790）作为含 source/provenance 的详情源；缩减 KeyValueGrid（:819-829），仅保留 `powerSourceText`，避免 8 个电池字段重复 |

### FR-3 Network 页 MetricCard 与 TrendRow 4 指标重复

| 属性 | 值 |
|------|------|
| 源报告 | F1-2 |
| 位置 A | `DashboardView.swift:704-708` — 5 张 MetricCard (Download/Upload/Total/Connection/Interface) |
| 位置 B | `DashboardView.swift:729-732` — Network 趋势面板 4 行 TrendRow (Total/Connection/Download/Upload) |
| 冗余数据 | Total `networkText`+sparkline, Connection `networkPathText`+sparkline, Download `networkInText`+sparkline, Upload `networkOutText`+sparkline |
| 新增价值 | TrendRow 相对 MetricCard 无新增价值。MetricCard 更丰富（含 progress bar + 大数） |
| **移除方案** | 移除 Network 趋势面板 TrendRow 4 行（:729-732）。MetricCard 含 sparkline 已提供趋势预览；History 页也覆盖 Network 趋势 |

### FR-4 Network 页 MetricCard Connection 与连通性表首行重复

| 属性 | 值 |
|------|------|
| 源报告 | F1-3 |
| 位置 A | `DashboardView.swift:707` — MetricCard Connection |
| 位置 B | `DashboardView.swift:715` — 连通性表首行 |
| 冗余数据 | `networkPathText`, `networkPathDetailText` |
| 新增价值 | MetricCard 更丰富（含进度条+sparkline），表首行无新增价值 |
| **移除方案** | 从连通性表（:713-725）移除首行 networkPath 行。保留 2-7 行（ip/dns/reachability/interface/port/firewall） |

### FR-5 Overview 页 MetricCard (CPU/Memory/Network) 与 TrendRow (CPU/Memory/Network) 重复

| 属性 | 值 |
|------|------|
| 源报告 | F1-5 |
| 位置 A | `DashboardView.swift:430-433` — 4 张 MetricCard CPU/Memory/Network/Power |
| 位置 B | `DashboardView.swift:467-471` — 5 行 TrendRow CPU/Load/Memory/Network/Disk |
| 冗余数据 | CPU `cpuText`+sparkline, Memory `memoryUsageText`+sparkline, Network `networkText`+sparkline |
| 新增价值 | TrendRow 是 MetricCard 的子集。MetricCard 含 progress bar + 大数 + sparkline + detail + badgeText |
| **移除方案** | 此冗余与 FR-1 直接关联——移除 `overviewTrendPanel`（FR-1 方案）即可同时解决 FR-5。两项同属一幅面板 |

### FR-6 CPU/Memory 页 ProcessListPanel subtitle 不一致

| 属性 | 值 |
|------|------|
| 源报告 | F2-10 |
| 位置 A | `DashboardView.swift:521` — CPU 页 ProcessListPanel，subtitle `processesDefaultSubtitle` |
| 位置 B | `DashboardView.swift:581` — Memory 页 ProcessListPanel，subtitle `processesCurrentSessionSubtitle` |
| 冗余数据 | `snapshot.runningApps`（完全相同的数据源） |
| 新增价值 | 两页展示完全相同的进程列表（`snapshot.runningApps`），但使用不同 subtitle 字符串 —— 这不仅是冗余，还是 bug-like 的语义不一致 |
| **修复方案** | (1) 统一 subtitle：删除 CPU 页的 `processListPanel`（:521）或 Memory 页的 `processListPanel`（:581），只保留一处；(2) 或保留两处但统一 subtitle 字符串；(3) 注意两处 `ProcessListPanel` 还各自与 Processes 页 `ResponsiveTable` 重复（FR-16/17），建议合并方案 |

---

## F-中 精简方案

| 编号 | 描述 | 方案 |
|------|------|------|
| FR-7 | CPU/Power Recent Sample 行 → 顶栏已常驻 | 移除 CPU 页 `:559` 和 Power 页 `:839` 的 `(cpuRecentSampleLabel, sampleTimeText)` 行 |
| FR-8 | Power thermalPanel vs Sensors thermalPanel | 移除 Power 页 thermalPanel `:836-837`（thermalText + thermalLimitText），Power 页 thermal 信息由 Sensors 页 thermalPanel 涵盖 |
| FR-9 | Power thermalPanel uptime/sampleTime 错位 | 移除 `:838-839`，将 uptime 移至 Overview StatusPanel 或 History 面板 |
| FR-10 | 侧栏 SidebarHealthCard 3 行 | 移除整个 `SidebarHealthCard`（:325-348）及引用。侧栏保留纯导航。用户已确认 |
| FR-11 | Memory KeyValueGrid vs compositionPanel 3 字段重叠 | 从 KeyValueGrid（:611-619）移除 compressed/cached/swap 三行，保留 compositionPanel（:626-631）含进度条版本 |
| FR-12 | Overview CPU/Memory 同一页出现三次 | 移除 Overview `StatusSummaryRow(:482-483)` cpu/memory 两行，StatusPanel 中保留其他 8 行 |
| FR-13 | Sensors realtimeSignalsPanel vs Rule table 4 字段 | 从 Rule table（:970-973）移除第 3 列当前值，仅保留阈值列 + 状态列 |
| FR-14 | Sensors realtimeSignalsPanel 11 卡 | 精简为 5-6 张（CPU/Memory/Disk/Power/Network），其余改为状态指示 |
| FR-15 | Overview StatusPanel 10 行 | 精简为 6-7 行（thermal/uptime/kernel/load/runningApps/gpuDisplay/disk），移除与 MetricCard 重复的 cpu/memory/network |
| FR-16 | CPU ProcessListPanel vs Processes 页 | 移除 CPU 页 ProcessListPanel（:521），用户可在 Processes 页查看完整进程列表 |
| FR-17 | Memory ProcessListPanel vs Processes 页 | 移除 Memory 页 ProcessListPanel（:581） |
| FR-18 | History 趋势 vs MetricCard sparkline | 有意冗余，保留（粒度不同） |

---

## F-低 处理建议

| 编号 | 描述 | 建议 |
|------|------|------|
| FR-19 | Overview = Settings WidgetPreviewPanel | 保留两处。Overview 是 widget 能力展示，Settings 是配置预览，语境不同 |
| FR-20 | Power RingGauge vs TrendRow | 保留，TrendRow 有 sparkline 新增价值 |
| FR-21 | History Threshold vs Sensors 规则表 | 保留，编辑 vs 展示不同上下文 |
| FR-22 | Storage/GPU 卡 vs Sensors | 保留，Sensors 精简后自然减少 |
| FR-23 | 顶栏 refreshInterval vs Settings Picker | 保留，display vs control 不同职责 |
| FR-24 | Processes SummaryCard 4 张 | 保留 3 张，移除 `runningAppListCountText`（纯 UI 元数据） |

---

## 明确保留项

| 编号 | 处理 | 理由 |
|------|------|------|
| FR-18 | 保留 | History 是趋势详情页，MetricCard sparkline 是摘要预览。 |
| FR-19 | 保留 | Overview 展示 widget 能力，Settings 展示配置预览，语境不同。 |
| FR-20 | 保留 | Power RingGauge 是当前状态，TrendRow 提供历史趋势。 |
| FR-21 | 保留 | History 是阈值编辑入口，Sensors 是规则判断展示。 |
| FR-22 | 通过 FR-14 间接减少 | 精简 Sensors 卡片后，Storage/GPU 跨页重复自然下降。 |
| FR-23 | 保留 | 顶栏是状态展示，Settings Picker 是控制入口。 |
| FR-25 | 保留 | Popover 是独立入口，内部没有重复字段。 |

---

## 修复影响范围

| 优先级 | 需移除/合并 | 行号 | 代码量 |
|--------|------------|------|--------|
| FR-1 (F-高) | 移除 `overviewTrendPanel` | :464-474 | ~11 行 |
| FR-2 (F-高) | 缩减 `powerDetails` 中重复电池字段，保留 Battery Information 表 | :819-829 | ~8 行 |
| FR-3 (F-高) | 移除 Network TrendRow 4 行 | :729-732 | ~4 行 |
| FR-4 (F-高) | 移除连通性表首行 | :715 | ~1 行 |
| FR-5 (F-高) | 与 FR-1 同面板 | 同上 | — |
| FR-6 (F-高) | 移除 CPU/Memory 页重复 ProcessListPanel，保留 Processes 页完整列表 | :521/:581 | ~2 行 |
| FR-7 (F-中) | 移除 2 行 sampleTime | :559, :839 | ~2 行 |
| FR-8 (F-中) | 保留 Power 页热状态与性能限制；不直接处理 | :836-837 | — |
| FR-9 (F-中) | 移除 2 行错位 | :838-839 | ~2 行 |
| FR-10 (F-中) | 移除 `SidebarHealthCard` | :325-348 | ~24 行 |
| FR-11 (F-中) | 移除 3 行 from KeyValueGrid | :611-619 | ~3 行 |
| FR-13 (F-中) | 移除 4 个列值 from Rule table | :970-973 | ~4 行 |
| FR-14 (F-中) | 精简 11 卡 → 5 卡 | :993-1005 | ~50 行 |
| FR-16 (F-中) | 移除 CPU ProcessListPanel | :521 | ~1 行 |
| FR-17 (F-中) | 移除 Memory ProcessListPanel | :581 | ~1 行 |
| **合计** | **15 处修改** | 多行 | **~125 行移除，~50 行精简** |

---

## 与前次 REDUNDANCY-REVIEW-PLAN 的关系

本次审查覆盖了前次 R1（信息冗余）的 9 条发现中的未修部分：
- R1-5 (Overview 趋势面板) → 本次 FR-1/F-高 ✓ 已深化
- R1-7 (Processes SummaryCard runningAppListCountText) → 本次 FR-24/F-低 ✓
- R1-8 (SidebarHealthCard) → 本次 FR-10/F-中 ✓ 用户确认
- FR-2 是本轮前端审查新增发现（Power 页 Battery/KVGrid）；前次 R1-4 实际对应 Overview/History 趋势面板，不是 Power 页电池详情重复。
- R1 已修项：R1-3 (规则表跨页)、R1-6 (Sensors 表合并) — 不再涉及

---

## 执行建议

1. **先修 F-高 6 条（~35 行）** — 影响面小、视觉改善大
2. **再修 F-中 12 条（~60 行）** — FR-10 (侧栏) 和 FR-14 (Sensors) 需设计确认
3. **后修 F-低 6 条（~0 行强制，均为保留/可选）**
4. 所有 F-高/F-中有明确的"移除/删除"操作，无复杂逻辑变更
5. 修改后验证：`swift build && swift test`
