# 逻辑/数据一致性专项修复复查报告

> 复查日期：2026-06-28
> 复查基准：当前 working tree
> 原审查报告：`docs/review/top/logic-consistency-final.md`（51 条：L-中 14 / L-低 37）
> 复查方法：逐条 grep/read 当前源码，对比原审查位置与修复方向

---

## 一、L-中 修复验证（14 条）

### 话术矛盾（4 条）

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| LC-1 | Widget 刷新同屏"5m"硬编码 vs "System Scheduled" | ✅ 已修复 | 全局搜索"5m"无匹配；`PulseDockAppStrings.swift:1040` 统一为 `settingsWidgetRefreshValue = "System Scheduled"`（localized 路径 `app.settings.widget.refresh.value`） | grep "5m" in Sources → 0 命中；`PulseDockAppStrings.swift:1040`、`PulseDockApp.xcstrings:4345`、`en.lproj/PulseDockApp.strings:272` 三处一致 |
| LC-2 | "No Battery"(powerSourceText) vs "Reported"(hasPowerStatusReport) 语义冲突 | ✅ 已修复 | `powerSourceNoBattery` 字符串已删除；`MetricSnapshot.swift:1258-1272` powerSourceText：`case .some` → `powerSourceExternal`("External Power")，`default` → `notReported` 或 `powerSourceStateNotReported`("Power state not reported")。`hasPowerStatusReport`（:1277）= `batteryPercent != nil || batteryPowerSource != nil`，与文案无冲突 | grep `powerSourceNoBattery` → 0 命中；`SharedMetricStrings.swift:277-283` 仅保留 `powerSourceExternal` + `powerSourceStateNotReported` |
| L1-3 | "System Status"同字面三义（Overview/Sensors/widget） | ✅ 已修复 | Sensors 页改用 `statusPerformanceLimitTitle`="Performance Limit"（`PulseDockAppStrings.swift:555-557`，调用点 `DashboardView.swift:835,984`）。"System Status"仅保留 Overview（`PulseDockAppStrings.swift:134`，全系统汇总）与 widget Large header（`PulseDockWidgetStrings.swift:73-74`，整体标题）——两者语义一致（整体系统状态），三义已降为一义 | grep `statusPerformanceLimitTitle` → DashboardView.swift:835,984；grep "System Status" → 仅 Overview + widget header 两处 |
| L1-4 | Sensors/History 同表异题（"Status Rules"/"Warning" vs "Status Evaluation"/"Triggered"） | ✅ 已修复 | History 页的"Status Evaluation"/"Triggered"规则表已移除（grep `historyStatusEvaluation`/`statusTriggered` → 0 命中）。仅保留 Sensors 页 `localRuleTableTitle`="Local Rules"（`PulseDockAppStrings.swift:842-848`，subtitle="Current sample evaluated against local thresholds"），状态列统一用 `statusWarning`="Warning" | grep `historyStatusEvaluation`/`Triggered` → 0 命中；`DashboardView.swift:964` 仅 Local Rules 表，:968-970 使用 `statusWarning` |

### 设计语义（6 条）

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| LC-3 | widget freshness：maxAge(600)==stale(600)，正常刷新被标老化 | ✅ 已修复 | `WidgetTimelinePolicy.swift:4-8`：`requestedRefreshInterval=300`、`agingThreshold=360`、`sharedSnapshotMaxAge=540`、`staleThreshold=600`。满足 maxAge(540) < staleThreshold(600)；正常刷新 300s < aging 360s 仍为 fresh；maxAge 数据 540s 落在 aging 区间不红色 | `WidgetTimelinePolicy.swift` 全文 9 行；`WidgetVisualTokens.swift:11-16` 使用 `staleThreshold`/`agingThreshold` 判定 |
| LC-4 | Sparkline 只画 suffix(80) 但 chip 报"Recent 360" | ✅ 已修复 | `DashboardView.swift` 提取 `sparklineVisibleSampleLimit = 80`；Sparkline `preparedValues` 与 `reportedHistorySampleChipText`/`reportedHistorySampleCountText` 共用该上限，chip/面板文案不再显示超过实际绘制窗口的点数。 | `DashboardView.swift` `sparklineVisibleSampleLimit`、`values.suffix(sparklineVisibleSampleLimit)`、`min(reportedSampleCount, sparklineVisibleSampleLimit)`；`RedundancyOptimizationGateTests.historySampleChipUsesSameVisibleLimitAsSparkline` |
| LC-5 | powerStatusTone 低电量早返回覆盖 charging（19%充电显示 critical） | ✅ 已修复 | `MetricSnapshot.swift:1283-1318`：`batteryIsCharging` 判定**提前到最前**（:1285-1287 `if batteryIsCharging { return .normal }`），先于低电量阈值（:1289 `<0.2 → critical`、:1293 `<0.5 → warning`）。充电中始终 normal | `MetricSnapshot.swift:1284-1287` charging 早返回；原报告锚点 [ANCHOR-C3] 方向已纠正 |
| L4-1 | powerStatus 三维度同时切换，桌面 Mac 空环误读 0% | ✅ 已修复 | `powerStatusTitle`（:1320-1322）：`batteryPercent==nil → "Power"` / 否则 `"Battery"`，已拆分。`powerStatusProgress`（:1280-1282）= `batteryPercent`（无电池时 nil）。`RingGauge`（DashboardView.swift:1402-1438）progress 为 nil 时 `clampedProgress`=nil，不绘制填充弧，仅显示空环 + "Power Adapter"文案 + "Power"标题 | `MetricSnapshot.swift:1320-1322` title 拆分；`DashboardView.swift:1409-1411` `progress.flatMap`、:1417 `if let clampedProgress` 守卫 |
| L4-7 | powerSourceText "No Battery" 分支不可达 | ✅ 已修复 | `powerSourceNoBattery` 本地化字符串已删除（grep → 0 命中）。`case .some`（:1266-1267）显式返回 `powerSourceExternal`="External Power"，不再透传原值；`default`（:1268-1271）返回 notReported / powerSourceStateNotReported | grep `powerSourceNoBattery` → 0 命中；`SharedMetricStrings.swift` 无该键 |
| L4-9 | Processes 页"List Items"是 UI 元数据非系统指标 | ✅ 已修复 | 已改名为 `processesDisplayedAppsTitle`="Displayed Apps"（`PulseDockAppStrings.swift:785-786`），调用点 `DashboardView.swift:919` SummaryCard，值=`snapshot.runningAppListCountText`（列表行数）。grep `List Items` → 0 命中 | `PulseDockAppStrings.swift:785-786`；`DashboardView.swift:919`；grep "List Items" → 0 |

### 数据流（4 条）

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| L3-3 | sampleWidgetCompact(fallback) vs widgetCompactSnapshot(shared) 字段集不对称 | ✅ 已修复 | `SystemSampler.sampleWidgetCompact` 改为 `sampleWidgetSnapshot(now:).widgetCompactSnapshot()`：fallback 先走轻量采样，再复用同一 `widgetCompactSnapshot()` 裁剪函数；`SharedSnapshotStore.saveLatestSnapshot` 也调用同一函数。两条路径字段集仍由单一 compaction helper 收口。 | `SystemSampler.swift` `sampleWidgetCompact`/`sampleWidgetSnapshot`；`SharedSnapshotStore.swift:40`；`RedundancyOptimizationGateTests.widgetCompactSamplerDoesNotRunFullInventorySamplingBeforeCompaction` |
| L3-8 | hasNetworkDirectionByteCounters init=OR vs Codable=AND+OR 混合 | ✅ 已修复 | init（`MetricSnapshot.swift:919-922`）：`hasNetworkDirectionByteCounters ?? (inBytes>0 || outBytes>0 || interfaces.contains{$0.hasByteCounters})`。Codable（:1727-1730）：`decodedHasNetworkDirectionByteCounters ?? (inBytes>0 || outBytes>0 || interfaces.contains{$0.hasByteCounters})`。两处策略完全一致（纯 OR） | `MetricSnapshot.swift:919-922` vs `1727-1730` 逐字相同表达式 |
| L3-9 | networkText(bits/s) vs networkInText/networkOutText(bytes/s) 单位混用 | ✅ 已修复 | `directionalNetworkRate`（`MetricFormatting.swift:49-51`）改为直接调用 `networkRate(bytesPerSecond:)`——两者均先 `×8` 转 bits 再经 `bitRate` 格式化为 Gbps/Mbps/Kbps。networkText（:1325）、networkInText（:1428）、networkOutText（:1432）三者单位统一为 bits/s | `MetricFormatting.swift:44-51` directionalNetworkRate 调用 networkRate；:45 `bitsPerSecond = Double(bytes) * 8` |
| L3-12 | `_ =` 丢弃 saveLatestSnapshot 返回值，lastSharedSnapshotWriteDate 无论成败都更新 | ✅ 已修复 | `MetricsStore.swift:375-377`：`if sharedSnapshotStore.saveLatestSnapshot(snapshot) { lastSharedSnapshotWriteDate = snapshot.timestamp }`——检查返回值，仅成功时更新日期，失败后下次 tick 可重试 | `MetricsStore.swift:375` `if ...saveLatestSnapshot(snapshot) {` |

### L-中 汇总

| 优先级 | 总数 | 已修复 | 部分修复 | 未修复 |
|--------|------|--------|---------|--------|
| L-中 | 14 | 14 | 0 | 0 |

**L-中 结论**：14 条全部已修复；LC-4 已通过共享可见点数上限完成文案/绘制窗口对齐。

---

## 二、L-低 抽查验证（37 条中抽查 10 条）

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| LC-6 | thermal "fair"/"serious" 死分支（14 实例） | ✅ 已修复 | `ThermalState` enum（`MetricStateContracts.swift:3-56`）init(raw:) 将 `"fair"→.warm`、`"serious"→.hot` 作为别名映射；下游通过 enum case 匹配而非裸字符串。MetricSnapshot.swift:1532 残留 `case "fair"` 属于 batteryHealthText（电池健康"Fair"），非 thermal | `MetricStateContracts.swift:14,16` 别名映射；grep `"fair"`/`"serious"` in Sources → 仅 enum + batteryHealth 两处 |
| L2-3 | network "requires_connection" 死分支（8 实例） | ✅ 已修复 | `NetworkPathState` enum（`MetricStateContracts.swift:58-103`）init(raw:) :70 `"requiresconnection", "requires_connection", "requires connection"` → `.requiresConnection`；下游用 `canonicalNetworkPathState` enum 匹配 | `MetricStateContracts.swift:70`；`MetricSnapshot.swift:1327-1346` 用 enum switch |
| L2-4 | network "requires connection" 死分支（8 实例） | ✅ 已修复 | 同 L2-3，同一 enum init 行 :70 将三种写法统一映射 | 同 L2-3 |
| L3-13 | MetricFormatting C locale vs SharedMetricStrings Locale.current 混用 | ❌ 未修复 | `MetricFormatting.swift:24,41,57,73` 仍用 `String(format:)` 无 locale 参数（默认 C locale）；`SharedMetricStrings.swift:404` `localizedFormat` 用 `String(format:..., locale: Locale.current)`。浮点格式化在逗号小数点 locale 下仍不一致 | `MetricFormatting.swift:24` `String(format: "%.1f %@", value, units)` 无 locale；`SharedMetricStrings.swift:404` 有 `locale: Locale.current` |
| D1 | GPU/display Surfaces 列误含 widgets | ✅ 误报确认 | 原审查已标记 false positive；当前 `data-capability-audit.md:27` GPU Surfaces="GPU/Display page, Status page, Settings page"（无 widgets）——与代码一致，无需修产品码 | `data-capability-audit.md:27` Surfaces 列无 widgets |
| D2 | Storage Surfaces 列遗漏 widgets | ✅ 已修复 | `data-capability-audit.md:23` Storage Surfaces 现为 "Overview, Storage page, Status page, Settings page, **widgets**" | `data-capability-audit.md:23` 末尾含 "widgets" |
| D3 | "after shared writes"措辞暗示因果触发 | ⚠️ 部分修复 | `data-capability-audit.md:131` 原句 "asks WidgetKit to reload its timeline kind **after shared writes**" 仍在；但新增 :513 澄清句 "Shared widget snapshot writes and WidgetKit reload requests use **separate throttles**...on the widget reload cadence"。误导措辞未改，仅增补充说明 | `data-capability-audit.md:131` 原文未改；:513 新增澄清 |
| L1-7 | widget small "Heat" vs large/app "Thermal" | ✅ 已修复 | `PulseDockWidgetStrings.swift:13-14` `miniThermal`="Thermal"（已从"Heat"改为"Thermal"）；`metricThermalState`="Thermal"（:49-50）。grep "Heat" in widget strings → 0 | `PulseDockWidgetStrings.swift:14` "Thermal" |
| L4-13 | Small widget "External" vs Medium/Large 原值透传 | ✅ 已修复 | Small：`compactPowerStatusText`（`SystemDashboardWidget.swift:770-786`）`case .some` → `compactPowerExternal`="External Power"；Large：`MetricSnapshot.powerSourceText` :1267 → `powerSourceExternal`="External Power"。两尺寸同状态输出一致 | `SystemDashboardWidget.swift:783` + `MetricSnapshot.swift:1267` 均返回 "External Power" |
| L4-W5 | widgetReloadInterval(60s) vs nextRefresh(300s) 频率脱节 | ✅ 已修复 | `WidgetTimelinePolicy.swift:5` `appReloadThrottle = requestedRefreshInterval = 300`；`MetricsStore.swift:67` `widgetReloadInterval = appReloadThrottle`。两者均 300s，已对齐 | `WidgetTimelinePolicy.swift:4-5`；`MetricsStore.swift:67` |

### L-低 抽查汇总

| 抽查项 | 已修复 | 部分修复 | 未修复 | 误报 |
|--------|--------|---------|--------|------|
| 10 条 | 7 | 1（D3） | 1（L3-13） | 1（D1） |

---

## 三、汇总

| 优先级 | 总数 | 已修复 | 部分修复 | 未修复 | 误报/不适用 |
|--------|------|--------|---------|--------|------------|
| L-中 | 14 | 14 | 0 | 0 | 0 |
| L-低（抽查 10/37） | 10 | 7 | 1 | 1 | 1 |

### 遗留问题（需后续跟进）

1. **L3-13（L-低，未修复）**：`MetricFormatting` 的 `String(format:)` 缺 locale 参数，与 `SharedMetricStrings.localizedFormat` 的 `Locale.current` 混用。建议统一为 `String(format:..., locale: Locale.current)` 或提取共享格式化入口。
2. **D3（L-低，部分修复）**：`data-capability-audit.md:131` "after shared writes" 误导措辞未改正，仅 :513 增补充。建议将 :131 改为 "independently of shared writes" 或 "on a separate 300-second throttle"。

### 修复亮点

- **L3-3** 通过轻量 widget sampler + 统一调用 `widgetCompactSnapshot()` 消除两条路径字段集分歧，同时避免 fallback 跑完整 inventory 采样
- **LC-5** 将 `batteryIsCharging` 提前到最前判定，一行改动解决低电量充电红色误读
- **L3-3 / L3-8 / L3-9** 数据流对称化修复均通过共享函数/统一策略实现，非补丁式
- **LC-6 / L2-3 / L2-4** 死分支通过 `ThermalState` / `NetworkPathState` enum 收敛，保留旧值解析兼容性
- **L4-W5** 通过 `appReloadThrottle = requestedRefreshInterval` 常量链式对齐，防止未来再次脱节
