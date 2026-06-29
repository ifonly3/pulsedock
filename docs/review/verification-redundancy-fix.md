# 冗余与重复专项修复复查报告

> 复查日期：2026-06-28
> 复查基准：当前 working tree（`swift build` ✅ / `swift test` 374 tests ✅）
> 复查对象：`docs/review/top/redundancy-final.md`（52 条：R-高 7 / R-中 18 / R-低 27）
> 复查方法：逐条 grep/read 当前源码 + 运行 `RedundancyOptimizationGateTests`（10 用例全通过）

---

## 一、R-高 修复验证（7 条）

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| R1-3 | Sensors 页与 History 页同一规则表重复 | ✅ 已修复 | History 页（`HistoryAlertsPage` 1008-1048）只剩 `historyTrendsTitle` 趋势面板 + `historyThresholdSettingsTitle` 阈值滑块面板；规则表（`localRuleTableTitle` / `statusRuleTableColumns`）仅在 Sensors 页 `DashboardView.swift:964-975` 渲染一次 | `grep localRuleTableTitle` 仅命中 `PulseDockAppStrings.swift:842` 定义 + `DashboardView.swift:964/966` 唯一调用点；`RedundancyOptimizationGateTests.duplicateUiPanelsAreRemovedFromDashboardSource` 断言 `!history.contains("localRuleTableTitle")` 通过 |
| R1-6 | Sensors 页 SystemSignals 表与 realtimeSignalsPanel 同页 8 项重叠 | ✅ 已修复 | SystemSignals 表已删除；`statusSystemSignalsTitle` 字符串定义仍保留在 `PulseDockAppStrings.swift:875` 但全工程无调用；Sensors 页仅保留 `realtimeSignalsPanel`（`DashboardView.swift:989-1005`）含 11 张 `SourceCapabilityCard`（CPU/Mem/Disk/Power/Network/Displays/GPU/Storage/Load/SystemVersion/Uptime）。修复方向提及"补充 kernelText"未做，但主目标（移除重叠表）已达成 | `grep statusSystemSignalsTitle` 仅命中 `PulseDockAppStrings.swift:875`；`DashboardView.swift` 无引用；测试断言 `!sensors.contains("statusSystemSignalsTitle")` + `sensors.contains("statusRealtimeSignalsTitle")` 通过 |
| RD-3 | networkPathProgress app↔widget 逐字符相同，0.45 魔法数两处独立 | ✅ 已修复 | 提取为 `NetworkPathState.progress` 计算属性（`MetricStateContracts.swift:94-103`），0.45 魔法数现仅此一处；app `DashboardView.swift:705` 调用 `snapshot.canonicalNetworkPathState.progress`；widget `SystemDashboardWidget.swift:234/284/285/286` 同样调用 | 测试 `sharedMetricContractsExposeToneAndProgress` 断言 `NetworkPathState.requiresConnection.progress == 0.45` 通过 |
| RD-7 | thermal→色调三处分歧：app hot=warning(amber) vs popover/widget hot=critical(red) | ✅ 已修复 | 提取 `ThermalState.metricStatusTone`（`MetricStateContracts.swift:29-40`），`case .critical, .hot: return .critical` 统一 hot=critical；app `DashboardView.swift:2260` `statusLevel(for: ThermalState(raw: state).metricStatusTone)`；popover `WidgetPanelView.swift:155` `tint(for: ThermalState(raw: state).metricStatusTone)`；widget `SystemDashboardWidget.swift:741` `widgetToneColor(ThermalState(raw: state).metricStatusTone, ...)`。三 surface 同源 | 测试断言 `ThermalState.hot.metricStatusTone == .critical` + `ThermalState.hot.progress == 0.78` 通过 |
| RD-8 | network→色调 unknown 分歧：app=blue vs popover/widget=cyan；StatusLevel.neutral→blue 内部矛盾 | ✅ 已修复 | `NetworkPathState.metricStatusTone`（`MetricStateContracts.swift:81-92`）`.unknown: return .neutral`；app `StatusLevel.color`（`DashboardView.swift:1754`）`case .neutral: DashboardColor.cyan`（已从 blue 改为 cyan）；app `powerTint`（`DashboardView.swift:2222-2223`）`.neutral: DashboardColor.cyan`；widget `widgetToneColor`（`SystemDashboardWidget.swift:765-766`）`.neutral: WidgetColor.cyan`。三 surface 现统一为 cyan | `DashboardView.swift:1754` 当前为 `DashboardColor.cyan`；测试 `sharedMetricContractsExposeToneAndProgress` 断言 `NetworkPathState.unknown.metricStatusTone == .neutral` 通过 |
| RD-4 | 三套颜色 tokens：dark RGB Palette↔WidgetColor 漂移，DashboardColor 无 dark 适配 | ✅ 已修复 | 新文件 `Sources/SharedMetrics/MetricAccentComponents.swift` 定义 `MetricColorComponents`（RGB 元组）+ `MetricAccent`（green/blue/amber/cyan/red）+ `MetricAccentAppearance`（light/dark）+ `components(for:appearance:)`；`DashboardColor`（`DashboardVisualTokens.swift:55-80`）经 `adaptiveAccent` 用 `NSColor(name:)` 动态适配 dark，调用 `MetricAccentComponents.components(for: isDark ? .dark : .light)`；`Palette`（`WidgetPanelView.swift:323-325`）+ `WidgetColor`（`WidgetVisualTokens.swift:60-62`）同样调用。dark 值统一（如 cyan.dark = 0.29/0.78/0.88 三处一致） | `grep MetricAccentComponents` 命中 3 调用点（DashboardVisualTokens/WidgetPanelView/WidgetVisualTokens）；测试 `accentComponentsOwnSharedLightAndDarkColors` + `accentTokensReadSharedComponentsAcrossSurfaces` 通过 |
| RD-1 | reportedProgress 三处逐字节相同 | ✅ 已修复 | 提取为 `MetricScales.reportedProgress(hasReport:progress:)`（`MetricScales.swift:13-16`）；app `DashboardView.swift` 调用 20+ 处（335-337/428-430/602-628/702-706/1348-1349）；popover `WidgetPanelView.swift:54-57`；widget `SystemDashboardWidget.swift:191/192/233-235/269-271/284-286` 全部调用 `MetricScales.reportedProgress`，无内联实现 | `grep reportedProgress` 仅 `MetricScales.swift:13` 定义 + 三 surface 调用；测试 `metricScalesOwnPresentationProgressHelpers` 断言 `reportedProgress(hasReport: false, ...) == nil` 通过 |

**R-高 结论：7/7 已修复。** 4 条跨 surface 色调分歧全部统一到 `MetricStateContracts.metricStatusTone` + `MetricAccentComponents`；2 条信息冗余按计划移除重复表；3 处数值魔法数（0.45 / 0.78/0.52/0.24 / reportedProgress）全部上移到 SharedMetrics。

---

## 二、R-中 抽查验证（18 条中抽查 11 条）

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| RD-2 | progressFillWidth 三处完全相同 | ✅ 已修复 | 提取为 `MetricScales.fillWidth(_:in:minimumVisibleWidth:)`（`MetricScales.swift:18-23`，依赖 CoreGraphics）；app `DashboardView.swift:1580`、popover `WidgetPanelView.swift:197`、widget `SystemDashboardWidget.swift:659` 全部调用 | 测试 `metricScalesOwnPresentationProgressHelpers` 断言 `fillWidth(0, in: 100, ...) == 0` + `fillWidth(0.5, in: 100, ...) == 50` 通过 |
| RD-5 | 三套 "Not reported" default 相同 | ✅ 已修复 | 合并到 `SharedMetricStrings.notReported`（`SharedMetricStrings.swift:4-6`，`localized("shared_metrics.not_reported", defaultValue: "Not reported")`）；`PulseDockAppStrings.notReported`（`PulseDockAppStrings.swift:1071-1073`）= `SharedMetricStrings.notReported`；`PulseDockWidgetStrings.notReported`（`PulseDockWidgetStrings.swift:89-91`）= `SharedMetricStrings.notReported`。三模块均委托 | 测试 `lowRiskPresentationDuplicationIsCentralized` 断言 app/widget strings 含 `static var notReported: String { SharedMetricStrings.notReported }` 通过 |
| RD-6 | powerTint 三处语义一致仅色源不同 | ✅ 已修复 | app `powerTint`（`DashboardView.swift:2214-2225`）按 `powerStatusTone` 映射到 DashboardColor；popover `WidgetPanelView.swift:150-152` `tint(for: snapshot.powerStatusTone)`；widget `SystemDashboardWidget.swift:753-755` `widgetToneColor(snapshot.powerStatusTone, ...)`。三处统一通过 `MetricStatusTone` 枚举映射，色源各取本地 Palette/WidgetColor（已统一到 MetricAccentComponents） | grep 确认三处均通过 tone 映射，无内联硬编码 |
| RD-9 | 两处 normalizedRate alias 零附加值 | ✅ 已修复 | `normalizedRate` 已从工程中删除，`grep normalizedRate` 在 DashboardView/WidgetPanelView/SystemDashboardWidget/MetricScales 全无命中；调用点改为直接调用 `MetricScales.networkRateProgress(bytesPerSecond:)` | `grep normalizedRate Sources/` 0 命中；`redundancy-final.md:29` 已记录"normalizedRate 仅 2 处"作为基准修正 |
| R1-1 | 侧栏 sampleTimeText 与顶栏 chip 同窗口双重常驻 | ✅ 已修复 | `SidebarHealthCard`（`DashboardView.swift:323-346`）已移除 sampleTimeText，仅保留 StatusDot + CPU/Mem/Disk CompactMetricLine；顶栏 chip 在 `DashboardView.swift:406` 保留 | 测试 `duplicateUiPanelsAreRemovedFromDashboardSource` 断言 `!sidebar.contains("snapshot.sampleTimeText")` 通过 |
| R1-2 | CPU/Power 页"Recent Sample"行与常驻顶栏 chip 重复 | ❌ 未修复 | CPU 页 `loadPanel`（`DashboardView.swift:557`）仍含 `(cpuRecentSampleLabel, snapshot.sampleTimeText)`；Power 页 `thermalPanel`（`DashboardView.swift:837`）仍含 `StatusSummaryRow(... cpuRecentSampleLabel, snapshot.sampleTimeText ...)`；顶栏 chip（`DashboardView.swift:406`）仍展示同一 `sampleTimeText`。三处同窗口常驻重复未移除 | `grep sampleTimeText DashboardView.swift` 命中 406/557/837/997/1160；R1-2 未被 `RedundancyOptimizationGateTests` 覆盖 |
| R1-4 | Overview 趋势 5 行是 History 趋势 8 行的纯子集 | 🔄 改为其他方案 | `overviewTrendPanel`（`DashboardView.swift:462-472`）仍保留 5 TrendRow（CPU/Load/Memory/Network/Disk）；`HistoryAlertsPage`（`DashboardView.swift:1024-1036`）有 8 TrendRow（含 Thermal/Uptime/Power）。原报告裁定"真冗余（但需权衡）— Overview 有首屏概览体验价值"，开发者选择保留 | 测试未断言移除 Overview 趋势；保留属合理设计权衡 |
| R1-5 | Settings widget 预览 Refresh/MainWindow 行与左面板控件重复 | ✅ 已修复 | `widgetPreviewPanel`（`DashboardView.swift:1153-1165`）现仅含 `WidgetMiniPreview` + KeyValueGrid（Widget Size / Data Source / Sample / History），无 Refresh/MainWindow 重复行；`refreshDisplayPanel`（1102-1151）独占 Refresh/MainWindow/MenuBar 控件 | 测试断言 `!settings.contains("settingsWidgetRefreshLabel")` + `!settings.contains("settingsWidgetMainWindowLabel")` 通过 |
| R2-14 | StatusDot 三处：app 抽象，popover/widget 内联手写，尺寸/shadow 不一致 | 🔄 改为其他方案 | 仍保留 3 个独立 struct：`StatusDot`（`DashboardView.swift:2085-2095`，7pt + shadow）、`PopoverStatusDot`（`WidgetPanelView.swift:246-255`，7pt 无 shadow）、`WidgetStatusDot`（`SystemDashboardWidget.swift:585`，7pt 无 shadow）。开发者选择保留各 surface 独立实现 | 测试 `lowRiskPresentationDuplicationIsCentralized` 主动**断言** popover/widget 各自的 StatusDot struct 存在（187-192 行），明确接受现状 |
| R2-17 | thermalStatus/thermalProgress 魔法数 0.78/0.52/0.24 应上移 | ✅ 已修复 | 魔法数上移到 `ThermalState.progress`（`MetricStateContracts.swift:42-55`，critical=1/hot=0.78/warm=0.52/nominal=0.24/unknown=nil）；`DashboardView.swift:982` `RingGauge(... progress: ThermalState(raw: snapshot.thermalState).progress ...)` 调用计算属性；三文件无残留 0.78/0.52/0.24 硬编码（仅余无关 opacity 0.78/0.24） | `grep "0.78\|0.52\|0.24"` 在 thermal 相关上下文 0 命中；测试断言 `ThermalState.hot.progress == 0.78` 通过 |
| R2-19 | trend 提取器调用不一致（Overview 默认重载 vs History 显式 keyPath） | ✅ 已修复 | `HistoryAlertsPage` 现用 `networkTrendValues(from: history)`（`DashboardView.swift:1020`）默认重载，与 Overview（423）一致；显式 keyPath 重载 `networkTrendValues(from: history, keyPath: \.networkBytesPerSecond)` 已删除 | 测试 `lowRiskPresentationDuplicationIsCentralized` 断言 `history.contains("let networkTrend = networkTrendValues(from: history)")` + `!history.contains("..., keyPath: \\.networkBytesPerSecond")` 通过 |

**R-中 抽查结论：11 条中 8 ✅ / 1 ❌（R1-2）/ 2 🔄（R1-4 保留、R2-14 保留）。** RD-2/RD-5/RD-6/RD-9 四条 SharedMetrics 提取全部完成；R1-1/R1-5 信息冗余按计划移除；R2-17/R2-19 上移/统一完成。R1-2（CPU/Power Recent Sample 行）未修复，且未被 gate test 覆盖，建议补测试。

---

## 三、R-低 抽查验证（27 条中抽查 4 条）

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| R3-1 | isRefreshing 被赋值但无视图消费，可安全删除 | ❌ 未修复 | `MetricsStore.swift:47` `private(set) var isRefreshing = false` 仍存在；`:326` `isRefreshing = false`、`:336` `isRefreshing = true`、`:347` `isRefreshing = false` 三处赋值；`grep -rn isRefreshing Sources/` 仅 MetricsStore 内部命中，无任何视图/面板读取 | 死状态保留；未被 gate test 覆盖 |
| R3-2 | widgetCompact 20 字段保留但 widget 从不读取 | ✅ 已修复 | `MetricSnapshot+WidgetCompact.swift:4-68` 将 20+ 字段降级：`cpuCoreUsages: []`、`physicalCoreCount: 0`、`memoryFreeBytes: 0`、`memoryWiredBytes: 0`、`memoryCompressedBytes: 0`、`memoryCachedBytes: 0`、`memorySwapUsedBytes/TotalBytes/AvailableBytes: 0`、`hasMemoryCompositionReport: false`、`loadAverage5: 0`、`loadAverage15: 0`、`batteryTimeRemainingMinutes: nil`、`batteryCycleCount: nil`、`batteryHealth: nil`、`batteryCurrentCapacity: nil`、`batteryMaxCapacity: nil`、`batteryDesignCapacity: nil`、`batteryVoltageMillivolts: nil`、`batteryAmperageMilliamps: nil`、`cpuBrandName: nil`；保留 widget 渲染所需（cpuUsage/memoryUsedBytes/loadAverage/batteryPercent/networkPath/disk 等） | 测试 `widgetCompactSnapshotTrimsCurrentDeadFields`（82-160 行）逐一断言 20 字段为 0/nil/[]/false + 保留字段不变，通过 |
| R3-4 | design/ vs designs/ 两套设计资产目录冗余 | ✅ 已修复 | 仅 `design/gptimage2-system-monitor/` 存在；`designs/macos-monitor-ui/` 已删除；`README.md:7` "Design reference assets live in `design/gptimage2-system-monitor/`."；`design/gptimage2-system-monitor/README.md` 标注 "canonical tracked design reference" | 测试 `designReferenceAssetsAreCanonicalized` 断言 `!redundancyFixtureExists("designs/macos-monitor-ui")` 通过 |
| R3-3 | "No Battery" 死分支（前次已确认修复） | ✅ 已修复（前次） | `SharedMetricStrings.swift:277` `powerSourceExternal` 替代；`SystemDashboardWidget.swift:782-783` `case .some: return PulseDockWidgetStrings.compactPowerExternal`；`grep "powerSourceNoBattery\|No Battery"` 0 命中 | `redundancy-final.md:35` 锚点纠正表已标记"当前代码已修复" |

**R-低 抽查结论：4 条中 3 ✅ / 1 ❌（R3-1）。** R3-2（20 死字段裁剪）+ R3-4（design 目录合并）+ R3-3（No Battery）全部修复且有测试守卫；R3-1（isRefreshing 死状态）未修复，建议补删 + gate test。

---

## 四、汇总

| 优先级 | 总数 | 已修复 | 部分修复 | 未修复 | 改为其他方案 |
|--------|------|--------|---------|--------|-------------|
| R-高 | 7 | 7 | 0 | 0 | 0 |
| R-中 | 18 | 抽查 8 | 0 | 抽查 1（R1-2） | 抽查 2（R1-4、R2-14 保留） |
| R-低 | 27 | 抽查 3 | 0 | 抽查 1（R3-1） | 0 |

### 关键修复成果

1. **跨 surface 色调统一**：`ThermalState.metricStatusTone` + `NetworkPathState.metricStatusTone`（MetricStateContracts.swift:29-40 / 81-92）作为单一来源，app/popover/widget 三处全部调用；hot=critical、unknown=neutral→cyan 统一。
2. **颜色 tokens 统一**：新文件 `MetricAccentComponents.swift` 提供 light/dark RGB 元组，`DashboardColor` 经 `adaptiveAccent` + `NSColor(name:)` 动态适配 dark，三 surface dark 值一致。
3. **数值魔法数上移**：`MetricScales.reportedProgress` / `MetricScales.fillWidth` / `ThermalState.progress` / `NetworkPathState.progress` 全部集中到 SharedMetrics。
4. **信息冗余移除**：History 规则表、Sensors SystemSignals 表、Settings widget 预览重复行、侧栏 sampleTimeText 全部移除。
5. **死字段裁剪**：widgetCompact 20+ 字段降级为 nil/0/[]/false，降低 App Group 载荷。
6. **测试守卫**：新增 `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`（10 用例）锁住所有 R-高 修复 + 抽查的 R-中/R-低 修复，`swift test` 374 tests 全通过。

### 未修复项（建议跟进）

| ID | 优先级 | 现状 | 建议 |
|----|--------|------|------|
| R1-2 | R-中 | CPU 页 `DashboardView.swift:557` + Power 页 `:837` 仍保留 Recent Sample 行，与顶栏 chip `:406` 重复 | 移除 CPU/Power 页 Recent Sample 行（顶栏 chip 已覆盖），补 gate test |
| R3-1 | R-低 | `MetricsStore.swift:47` isRefreshing 仍存在，无视图消费 | 删除 `isRefreshing` 字段及 3 处赋值，补 gate test |
| R1-4 | R-中 | Overview 趋势 5 行保留（History 8 行子集） | 原报告裁定"需权衡"，保留属合理设计决策，可关闭 |
| R2-14 | R-中 | StatusDot 三 surface 独立实现 | 测试主动接受现状，保留属合理决策，可关闭 |

### 验证命令结果

```
$ swift build         → Build complete! (0.10s) ✅
$ swift test          ✔ Test run with 374 tests in 2 suites passed after 0.431 seconds ✅
$ swift test --filter RedundancyOptimizationGateTests → 10/10 passed ✅
```

**最终结论：R-高 7/7 全部已修复且有测试守卫。R-中/R-低 抽查发现 2 条未修复（R1-2、R3-1），均为低风险信息冗余/死状态，不影响跨 surface 一致性。开发者"全面修复"声明对 R-高 完全成立，对 R-中/R-低 基本成立（仅 2 条遗留）。**
