# Pulse Dock Frontend Redundancy Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the verified redundant dashboard surfaces while preserving useful summary-vs-detail distinctions and correcting the frontend redundancy review documents.

**Architecture:** Treat `DashboardView.swift` as the single UI surface under repair and use source-level Swift Testing gates to prevent the same redundant panels from coming back. Prefer deleting duplicated rows and panels over introducing new abstractions, except for small helper cleanup if deletion leaves dead structs or strings.

**Tech Stack:** SwiftUI, Swift Testing, SwiftPM, generated Xcode project resources, Pulse Dock app localization through `PulseDockAppStrings`.

---

## Critical Review Decisions

These decisions supersede `docs/superpowers/plans/2026-06-29-frontend-redundancy-cleanup.md`, which judged several items too aggressively.

### Adopted Fixes

| Finding | Decision | Reason |
| --- | --- | --- |
| FR-1 / FR-5 | Remove the Overview trend panel | It repeats CPU, Memory, and Network already shown by MetricCards, and repeats five rows from History. Load and disk still remain visible through Overview status and dedicated pages. |
| FR-2 | Keep the Battery Information table and reduce `powerDetails` to non-duplicated summary fields | The table carries the source/provenance column; the key-value grid does not. |
| FR-3 | Remove the Network trend panel | Network MetricCards already show value, progress, and sparkline for the same four metrics. |
| FR-4 | Remove the first connectivity table row | The connection MetricCard already shows `networkPathText` and `networkPathDetailText`. |
| FR-6 / FR-16 / FR-17 | Remove CPU and Memory page `ProcessListPanel` instances | They use the same `snapshot.runningApps` data as the Processes page and currently disagree on subtitle copy. |
| FR-7 | Remove page-level `sampleTimeText` rows | Top bar already shows sample time on every page. |
| FR-9 | Remove `uptimeText` and `sampleTimeText` from the Power thermal panel | They are off-topic for a thermal panel and already shown elsewhere. |
| FR-10 | Remove `SidebarHealthCard` | It is always-visible metric duplication and the user already questioned its value. |
| FR-11 | Remove duplicate Memory key-value rows that are richer in Composition | `compressed`, `cached`, and `swap` remain in `compositionPanel` with progress context. |
| FR-12 / FR-15 | Trim Overview status rows for CPU, Memory, and Network | These are already covered by Overview MetricCards. Keep thermal, uptime, kernel, load, running apps, GPU/display, and disk. |
| FR-13 | Remove the current-value column from the Sensors rule table | The realtime signal cards already show current values; the rule table should focus on threshold and judgment. |
| FR-14 | Reduce Sensors realtime cards to five operational signals | Keep CPU, Memory, Disk, Power, Network. GPU/display/storage/system/load/uptime are covered by their own pages or Overview. |
| FR-24 | Remove `runningAppListCountText` SummaryCard | It is UI row-count metadata and adds less value than total, foreground, and hidden app counts. |

### Explicit Non-Actions

| Finding | Decision | Reason |
| --- | --- | --- |
| FR-18 | Keep History trend panel | History is the detailed trend view; MetricCard sparklines are compact previews. |
| FR-19 | Keep both widget previews | Overview presents feature availability; Settings presents configuration context. |
| FR-20 | Keep Power RingGauge plus power TrendRow | RingGauge shows current battery/power state; TrendRow adds battery/power history. |
| FR-21 | Keep History threshold controls and Sensors rule table | Editing thresholds and displaying rule judgments are different jobs. |
| FR-22 | No direct Storage/GPU changes | Reducing Sensors cards removes the cross-page repeated summary cards there. |
| FR-23 | Keep top-bar refresh label plus Settings picker | One is global state display; one is a control. |
| FR-25 | Keep popover duplicate information | Popover is a separate entry point and has no internal duplicate field. |

---

## File Structure

### Create

- `Tests/SharedMetricsTests/FrontendRedundancyGateTests.swift`
  - Source-level tests for verified frontend redundancy removals.

### Modify

- `Sources/PulseDockApp/DashboardView.swift`
  - Remove redundant panels, rows, and dead helper views.
- `Sources/PulseDockApp/PulseDockAppStrings.swift`
  - Remove dead string accessors and adjust rule table columns from four columns to three.
- `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`
  - Remove dead localized keys and adjust rule table column localized values if represented in the string catalog.
- `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
  - Update existing tests that currently expect `SidebarHealthCard`.
- `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`
  - Update existing tests that mention previous duplication cleanup state.
- `docs/review/top/frontend-redundancy-final.md`
  - Fix the count mismatch and correct the R1-4 drift.
- `docs/review/middle/frontend-F1-page-internal.md`
  - Mark verified decisions and adjust implementation recommendations.
- `docs/review/middle/frontend-F2-cross-page.md`
  - Mark verified decisions and non-actions.
- `docs/review/middle/frontend-F3-chrome-redundancy.md`
  - Mark verified decisions and non-actions.

---

## Task 1: Add Frontend Redundancy Gates

**Files:**
- Create: `Tests/SharedMetricsTests/FrontendRedundancyGateTests.swift`
- Modify later tasks to satisfy this test file.

- [ ] **Step 1: Create failing source-level gate tests**

Create `Tests/SharedMetricsTests/FrontendRedundancyGateTests.swift` with this exact content:

```swift
import Foundation
import Testing

private func frontendRedundancyFixture(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

@Suite("FrontendRedundancyGateTests")
struct FrontendRedundancyGateTests {
    @Test func reviewedFrontendRedundancyDocsUseCorrectCountsAndDecisions() throws {
        let final = try frontendRedundancyFixture("docs/review/top/frontend-redundancy-final.md")

        #expect(!final.contains("去重后共 **21 条独特发现**"))
        #expect(final.contains("去重后共 **25 条独特发现**"))
        #expect(final.contains("FR-2 是本轮前端审查新增发现"))
        #expect(!final.contains("R1-4 (Power 页 Battery/KVGrid)"))
        #expect(final.contains("FR-18 | 保留"))
        #expect(final.contains("FR-19 | 保留"))
        #expect(final.contains("FR-23 | 保留"))
    }

    @Test func chromeAndPageLevelSampleTimeDuplicationIsRemoved() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let sidebar = componentBody(named: "DashboardSidebar", in: dashboard)
        let topBar = componentBody(named: "DashboardTopBar", in: dashboard)
        let cpuPage = componentBody(named: "CPUPage", in: dashboard)
        let powerPage = componentBody(named: "PowerPage", in: dashboard)

        #expect(!dashboard.contains("private struct SidebarHealthCard"))
        #expect(!sidebar.contains("SidebarHealthCard(snapshot:"))
        #expect(topBar.contains("dashboardSampleChip(snapshot.sampleTimeText)"))
        #expect(!cpuPage.contains("(PulseDockAppStrings.cpuRecentSampleLabel, snapshot.sampleTimeText)"))
        #expect(!powerPage.contains("StatusSummaryRow(title: PulseDockAppStrings.cpuRecentSampleLabel"))
        #expect(!powerPage.contains("StatusSummaryRow(title: PulseDockAppStrings.metricUptime"))
    }

    @Test func overviewAndNetworkDuplicateTrendPanelsAreRemoved() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let overviewPage = componentBody(named: "OverviewPage", in: dashboard)
        let networkPage = componentBody(named: "NetworkPage", in: dashboard)
        let historyPage = componentBody(named: "HistoryAlertsPage", in: dashboard)

        #expect(!overviewPage.contains("overviewTrendPanel"))
        #expect(overviewPage.contains("MetricCard(title: PulseDockAppStrings.overviewCPUUsageTitle"))
        #expect(overviewPage.contains("overviewStatusPanel"))
        #expect(!networkPage.contains("PulseDockAppStrings.networkTrendTitle"))
        #expect(!networkPage.contains("[PulseDockAppStrings.networkPathLabel, snapshot.networkPathText, snapshot.networkPathDetailText]"))
        #expect(historyPage.contains("PulseDockAppStrings.historyTrendsTitle"))
    }

    @Test func powerBatteryDetailsHaveOneDetailedSourceOfTruth() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let powerPage = componentBody(named: "PowerPage", in: dashboard)
        let powerDetails = functionBody(containing: "private func powerDetails(powerTrend: [Double])", in: powerPage)

        #expect(powerPage.contains("PulseDockAppStrings.batteryInformationTitle"))
        #expect(powerDetails.contains("snapshot.powerSourceText"))
        #expect(!powerDetails.contains("snapshot.batteryTimeRemainingText"))
        #expect(!powerDetails.contains("snapshot.batteryCurrentCapacityText"))
        #expect(!powerDetails.contains("snapshot.batteryMaxCapacityText"))
        #expect(!powerDetails.contains("snapshot.batteryCycleText"))
        #expect(!powerDetails.contains("snapshot.batteryHealthText"))
        #expect(!powerDetails.contains("snapshot.batteryDesignCapacityText"))
        #expect(!powerDetails.contains("snapshot.batteryVoltageText"))
        #expect(!powerDetails.contains("snapshot.batteryAmperageText"))
    }

    @Test func processListsAreConsolidatedToOverviewAndProcessesPages() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let overviewPage = componentBody(named: "OverviewPage", in: dashboard)
        let cpuPage = componentBody(named: "CPUPage", in: dashboard)
        let memoryPage = componentBody(named: "MemoryPage", in: dashboard)
        let processesPage = componentBody(named: "ProcessesPage", in: dashboard)

        #expect(overviewPage.contains("ProcessListPanel(processes: snapshot.runningApps)"))
        #expect(!cpuPage.contains("ProcessListPanel(processes: snapshot.runningApps"))
        #expect(!memoryPage.contains("ProcessListPanel(processes: snapshot.runningApps"))
        #expect(processesPage.contains("ResponsiveTable("))
        #expect(processesPage.contains("snapshot.runningApps.filter(\\.hasInventoryReport)"))
    }

    @Test func memoryOverviewSensorsAndProcessesAvoidAcceptedDuplicateRows() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let appStrings = try frontendRedundancyFixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
        let overviewStatusPanel = functionBody(containing: "private var overviewStatusPanel", in: dashboard)
        let memoryDetails = functionBody(containing: "private func memoryDetails(memoryTrend: [Double])", in: dashboard)
        let sensorsPage = componentBody(named: "SensorsPage", in: dashboard)
        let processesPage = componentBody(named: "ProcessesPage", in: dashboard)

        #expect(!overviewStatusPanel.contains("overviewCPUStatusTitle"))
        #expect(!overviewStatusPanel.contains("overviewMemoryStatusTitle"))
        #expect(!overviewStatusPanel.contains("metricNetworkConnection"))
        #expect(!memoryDetails.contains("snapshot.memoryCachedText"))
        #expect(!memoryDetails.contains("snapshot.memoryCompressedText"))
        #expect(!memoryDetails.contains("snapshot.memorySwapText"))
        #expect(!sensorsPage.contains("snapshot.displaySummaryText"))
        #expect(!sensorsPage.contains("snapshot.gpuSummaryText"))
        #expect(!sensorsPage.contains("snapshot.storageVolumeSummaryText"))
        #expect(!sensorsPage.contains("snapshot.loadDetailText"))
        #expect(!sensorsPage.contains("snapshot.osVersionText"))
        #expect(!sensorsPage.contains("snapshot.uptimeText"))
        #expect(!processesPage.contains("processesDisplayedAppsTitle"))
        #expect(appStrings.contains("static var statusRuleTableColumns: [String]"))
        #expect(!appStrings.contains("app.dashboard.rule_table.column.current"))
    }
}

private func componentBody(named name: String, in source: String) -> String {
    guard let start = source.range(of: "private struct \(name)")?.lowerBound else { return "" }
    let remainder = source[start...]
    if let next = remainder.dropFirst().range(of: "\nprivate struct ")?.lowerBound {
        return String(remainder[..<next])
    }
    return String(remainder)
}

private func functionBody(containing marker: String, in source: String) -> String {
    guard let start = source.range(of: marker)?.lowerBound else { return "" }
    let remainder = source[start...]
    if let nextPrivate = remainder.dropFirst().range(of: "\n    private ")?.lowerBound {
        return String(remainder[..<nextPrivate])
    }
    if let nextStruct = remainder.dropFirst().range(of: "\nprivate struct ")?.lowerBound {
        return String(remainder[..<nextStruct])
    }
    return String(remainder)
}
```

- [ ] **Step 2: Run the new test file and confirm it fails**

Run:

```bash
swift test --filter FrontendRedundancyGateTests
```

Expected: fail with assertions mentioning existing `SidebarHealthCard`, `overviewTrendPanel`, `networkTrendTitle`, duplicated `batteryCurrentCapacityText`, and the `21 条独特发现` doc count.

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/SharedMetricsTests/FrontendRedundancyGateTests.swift
git commit -m "test: add frontend redundancy gates"
```

---

## Task 2: Correct Frontend Redundancy Review Documents

**Files:**
- Modify: `docs/review/top/frontend-redundancy-final.md`
- Modify: `docs/review/middle/frontend-F1-page-internal.md`
- Modify: `docs/review/middle/frontend-F2-cross-page.md`
- Modify: `docs/review/middle/frontend-F3-chrome-redundancy.md`

- [ ] **Step 1: Update final report counts and wording**

In `docs/review/top/frontend-redundancy-final.md`, replace the opening count line with:

```markdown
> 基于 F1（同页内重复，9 条）+ F2（跨页子集与错位，13 条）+ F3（常驻元素与摘要面板，10 条）三层扫描，去重后共 **25 条独特发现**，其中 24 条属于当前主窗口，FR-25 属于跨入口 popover 检查且无需处理。
```

Replace the R-plan relationship bullet for FR-2 with:

```markdown
- FR-2 (Power 页 Battery/KVGrid) → 本轮前端审查新增发现；前次 R1-4 实际对应 Overview/History 趋势面板，不是 Power 页电池详情重复。
```

Add this table under the F-low section:

```markdown
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
```

- [ ] **Step 2: Update middle reports**

In each middle report, add a `## 复核后处理结论` section near the top.

For `frontend-F1-page-internal.md`, use:

```markdown
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
```

For `frontend-F2-cross-page.md`, use:

```markdown
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
```

For `frontend-F3-chrome-redundancy.md`, use:

```markdown
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
```

- [ ] **Step 3: Verify doc gate still fails only on code assertions**

Run:

```bash
swift test --filter FrontendRedundancyGateTests/reviewedFrontendRedundancyDocsUseCorrectCountsAndDecisions
```

Expected: pass.

- [ ] **Step 4: Commit document corrections**

```bash
git add docs/review/top/frontend-redundancy-final.md docs/review/middle/frontend-F1-page-internal.md docs/review/middle/frontend-F2-cross-page.md docs/review/middle/frontend-F3-chrome-redundancy.md
git commit -m "docs: correct frontend redundancy review decisions"
```

---

## Task 3: Remove Chrome and Sample-Time Duplication

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
- Modify: `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`

- [ ] **Step 1: Remove the sidebar health card call**

In `DashboardSidebar.body`, remove:

```swift
Spacer(minLength: 12)

SidebarHealthCard(snapshot: snapshot)
```

Leave the sidebar scroll content ending after the navigation rows:

```swift
VStack(alignment: .leading, spacing: 10) {
    appTitle

    Text(PulseDockAppStrings.dashboardSidebarSectionTitle)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(DashboardColor.muted)
        .padding(.top, 8)

    ForEach(DashboardPage.allCases) { page in
        SidebarRow(page: page, isSelected: page == selectedPage) {
            select(page)
        }
    }
}
```

- [ ] **Step 2: Delete the `SidebarHealthCard` struct**

Delete the whole `private struct SidebarHealthCard: View` block.

- [ ] **Step 3: Remove dead sidebar live-sampling string accessor**

Delete this accessor from `PulseDockAppStrings.swift` if `rg "dashboardSidebarLiveSampling"` shows no remaining references:

```swift
static var dashboardSidebarLiveSampling: String {
    localized("app.dashboard.sidebar.live_sampling", defaultValue: "Live Sampling")
}
```

Remove the `app.dashboard.sidebar.live_sampling` key from `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings` if it exists.

- [ ] **Step 4: Remove CPU page sample-time row**

In `CPUPage.loadPanel`, change the key-value items from:

```swift
KeyValueGrid(items: [
    (PulseDockAppStrings.cpuProcessorLabel, snapshot.cpuBrandText),
    (PulseDockAppStrings.cpuPhysicalCoresLabel, snapshot.physicalCoreCountText),
    (PulseDockAppStrings.cpuLogicalCoresLabel, snapshot.logicalCoreCountText),
    (PulseDockAppStrings.cpuActiveCoresLabel, snapshot.activeProcessorCountText),
    (PulseDockAppStrings.metricRunningApps, snapshot.runningAppCountText),
    (PulseDockAppStrings.cpuRecentSampleLabel, snapshot.sampleTimeText)
])
```

to:

```swift
KeyValueGrid(items: [
    (PulseDockAppStrings.cpuProcessorLabel, snapshot.cpuBrandText),
    (PulseDockAppStrings.cpuPhysicalCoresLabel, snapshot.physicalCoreCountText),
    (PulseDockAppStrings.cpuLogicalCoresLabel, snapshot.logicalCoreCountText),
    (PulseDockAppStrings.cpuActiveCoresLabel, snapshot.activeProcessorCountText),
    (PulseDockAppStrings.metricRunningApps, snapshot.runningAppCountText)
])
```

- [ ] **Step 5: Remove off-topic Power thermal rows**

In `PowerPage.thermalPanel`, change:

```swift
VStack(spacing: 12) {
    StatusSummaryRow(title: PulseDockAppStrings.statusCurrentStateTitle, value: snapshot.thermalText, status: thermalStatus(snapshot.thermalState))
    StatusSummaryRow(title: PulseDockAppStrings.statusPerformanceLimitTitle, value: snapshot.thermalLimitText, status: thermalStatus(snapshot.thermalState))
    StatusSummaryRow(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, status: snapshot.hasUptimeReport ? .normal : .neutral)
    StatusSummaryRow(title: PulseDockAppStrings.cpuRecentSampleLabel, value: snapshot.sampleTimeText, status: snapshot.hasSampleTimeReport ? .normal : .neutral)
}
```

to:

```swift
VStack(spacing: 12) {
    StatusSummaryRow(title: PulseDockAppStrings.statusCurrentStateTitle, value: snapshot.thermalText, status: thermalStatus(snapshot.thermalState))
    StatusSummaryRow(title: PulseDockAppStrings.statusPerformanceLimitTitle, value: snapshot.thermalLimitText, status: thermalStatus(snapshot.thermalState))
}
```

- [ ] **Step 6: Update tests that expected SidebarHealthCard**

In `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`, update `dashboardSidebarAndTopBarAreCompactSafe` from:

```swift
#expect(sidebar.contains("SidebarHealthCard"))
```

to:

```swift
#expect(!sidebar.contains("SidebarHealthCard"))
```

In `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`, update `duplicateUiPanelsAreRemovedFromDashboardSource` from:

```swift
let sidebar = componentBody(named: "SidebarHealthCard", in: dashboard)
...
#expect(!sidebar.contains("snapshot.sampleTimeText"))
```

to:

```swift
#expect(!dashboard.contains("private struct SidebarHealthCard"))
```

- [ ] **Step 7: Run focused tests**

Run:

```bash
swift test --filter FrontendRedundancyGateTests/chromeAndPageLevelSampleTimeDuplicationIsRemoved
swift test --filter VisualFrontendGateTests/dashboardSidebarAndTopBarAreCompactSafe
swift test --filter RedundancyOptimizationGateTests/duplicateUiPanelsAreRemovedFromDashboardSource
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources/PulseDockApp.xcstrings Tests/SharedMetricsTests/VisualFrontendGateTests.swift Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift
git commit -m "fix: remove dashboard chrome metric duplication"
```

---

## Task 4: Consolidate Overview and Network Trend Duplication

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`

- [ ] **Step 1: Remove `overviewTrendPanel` calls**

In `OverviewPage.body`, replace this block:

```swift
if isCompact {
    VStack(alignment: .leading, spacing: 12) {
        overviewTrendPanel(cpuTrend: cpuTrend, memoryTrend: memoryTrend, networkTrend: networkTrend)
        overviewStatusPanel
    }
} else {
    HStack(alignment: .top, spacing: 12) {
        overviewTrendPanel(cpuTrend: cpuTrend, memoryTrend: memoryTrend, networkTrend: networkTrend)
        overviewStatusPanel
            .frame(width: 330)
    }
}
```

with:

```swift
overviewStatusPanel
```

- [ ] **Step 2: Delete `overviewTrendPanel`**

Delete the full method:

```swift
private func overviewTrendPanel(cpuTrend: [Double], memoryTrend: [Double], networkTrend: [Double]) -> some View {
    DashboardPanel(title: PulseDockAppStrings.overviewRuntimeTrendsTitle, subtitle: reportedHistorySampleCountText(from: history), icon: "chart.xyaxis.line") {
        VStack(spacing: 14) {
            TrendRow(title: PulseDockAppStrings.metricCPU, value: snapshot.cpuText, tint: DashboardColor.green, values: cpuTrend)
            TrendRow(title: PulseDockAppStrings.metricLoad, value: snapshot.loadText, tint: DashboardColor.purple, values: loadTrendValues(from: history))
            TrendRow(title: PulseDockAppStrings.metricMemory, value: snapshot.memoryUsageText, tint: DashboardColor.blue, values: memoryTrend)
            TrendRow(title: PulseDockAppStrings.metricNetwork, value: snapshot.networkText, tint: DashboardColor.cyan, values: networkTrend)
            TrendRow(title: PulseDockAppStrings.metricDisk, value: snapshot.diskUsageText, tint: DashboardColor.amber, values: diskTrendValues(from: history))
        }
    }
}
```

- [ ] **Step 3: Remove dead overview trend string accessor**

Delete this accessor from `PulseDockAppStrings.swift` if `rg "overviewRuntimeTrendsTitle"` only finds the accessor and string catalog:

```swift
static var overviewRuntimeTrendsTitle: String {
    localized("app.dashboard.overview.runtime_trends.title", defaultValue: "Runtime Trends")
}
```

Remove `app.dashboard.overview.runtime_trends.title` from `PulseDockApp.xcstrings` if present.

- [ ] **Step 4: Remove Network trend panel**

In `NetworkPage.body`, delete the whole panel:

```swift
DashboardPanel(title: PulseDockAppStrings.networkTrendTitle, subtitle: PulseDockAppStrings.networkRecentLiveSamplesSubtitle, icon: "chart.line.uptrend.xyaxis") {
    VStack(spacing: 14) {
        TrendRow(title: PulseDockAppStrings.networkTotalLabel, value: snapshot.networkText, tint: DashboardColor.cyan, values: networkTrend)
        TrendRow(title: PulseDockAppStrings.networkConnectionLabel, value: snapshot.networkPathText, tint: networkStatusColor(snapshot), values: networkPathTrend)
        TrendRow(title: PulseDockAppStrings.networkDownloadTitle, value: snapshot.networkInText, tint: DashboardColor.blue, values: networkDownloadTrend)
        TrendRow(title: PulseDockAppStrings.networkUploadTitle, value: snapshot.networkOutText, tint: DashboardColor.green, values: networkUploadTrend)
    }
}
```

- [ ] **Step 5: Remove Network connectivity duplicate row**

In the connectivity table rows, remove:

```swift
[PulseDockAppStrings.networkPathLabel, snapshot.networkPathText, snapshot.networkPathDetailText],
```

The rows should begin with:

```swift
[
    [PulseDockAppStrings.networkCapabilityLabel, snapshot.networkPathCapabilityText, PulseDockAppStrings.networkSystemPathSubtitle],
    ["DNS", snapshot.networkDNSCapabilityText, PulseDockAppStrings.networkNameResolutionSource],
    ["IPv4", snapshot.networkIPv4CapabilityText, PulseDockAppStrings.networkSystemPathSubtitle],
    ["IPv6", snapshot.networkIPv6CapabilityText, PulseDockAppStrings.networkSystemPathSubtitle],
    [PulseDockAppStrings.networkLowDataModeLabel, snapshot.networkLowDataModeText, PulseDockAppStrings.networkSystemPathSubtitle],
    [PulseDockAppStrings.networkMeteredLabel, snapshot.networkMeteredText, PulseDockAppStrings.networkSystemPathSubtitle]
]
```

- [ ] **Step 6: Remove dead network trend title accessor**

Delete this accessor from `PulseDockAppStrings.swift` if `rg "networkTrendTitle"` only finds the accessor and string catalog:

```swift
static var networkTrendTitle: String {
    localized("app.dashboard.network.trend.title", defaultValue: "Network Trend")
}
```

Remove `app.dashboard.network.trend.title` from `PulseDockApp.xcstrings` if present. Keep `networkRecentLiveSamplesSubtitle` if other panels still use it.

- [ ] **Step 7: Run focused test**

Run:

```bash
swift test --filter FrontendRedundancyGateTests/overviewAndNetworkDuplicateTrendPanelsAreRemoved
```

Expected: pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources/PulseDockApp.xcstrings
git commit -m "fix: remove duplicate overview and network trend panels"
```

---

## Task 5: Consolidate Power Battery Details

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`

- [ ] **Step 1: Reduce `powerDetails` to summary-only values**

Change `powerDetails(powerTrend:)` from:

```swift
private func powerDetails(powerTrend: [Double]) -> some View {
    VStack(spacing: 14) {
        TrendRow(title: powerTrendTitle(snapshot), value: snapshot.powerStatusText, tint: powerTint(snapshot), values: powerTrend)
        KeyValueGrid(items: [
            (PulseDockAppStrings.powerSourceLabel, snapshot.powerSourceText),
            (PulseDockAppStrings.batteryRemainingTimeLabel, snapshot.batteryTimeRemainingText),
            (PulseDockAppStrings.batteryCurrentCapacityLabel, snapshot.batteryCurrentCapacityText),
            (PulseDockAppStrings.batteryMaxCapacityLabel, snapshot.batteryMaxCapacityText),
            (PulseDockAppStrings.batteryCycleCountLabel, snapshot.batteryCycleText),
            (PulseDockAppStrings.batteryHealthLabel, snapshot.batteryHealthText),
            (PulseDockAppStrings.batteryDesignCapacityLabel, snapshot.batteryDesignCapacityText),
            (PulseDockAppStrings.batteryVoltageLabel, snapshot.batteryVoltageText),
            (PulseDockAppStrings.batteryCurrentLabel, snapshot.batteryAmperageText)
        ])
    }
}
```

to:

```swift
private func powerDetails(powerTrend: [Double]) -> some View {
    VStack(spacing: 14) {
        TrendRow(title: powerTrendTitle(snapshot), value: snapshot.powerStatusText, tint: powerTint(snapshot), values: powerTrend)
        KeyValueGrid(items: [
            (PulseDockAppStrings.powerSourceLabel, snapshot.powerSourceText)
        ])
    }
}
```

Keep the Battery Information table unchanged, because it provides the source column for remaining time, current capacity, max capacity, design capacity, cycle count, health, voltage, and amperage.

- [ ] **Step 2: Run focused test**

Run:

```bash
swift test --filter FrontendRedundancyGateTests/powerBatteryDetailsHaveOneDetailedSourceOfTruth
```

Expected: pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/PulseDockApp/DashboardView.swift
git commit -m "fix: consolidate power battery details"
```

---

## Task 6: Consolidate Process Lists and Memory Detail Duplication

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`

- [ ] **Step 1: Remove CPU page process list**

In `CPUPage.body`, delete:

```swift
ProcessListPanel(processes: snapshot.runningApps, title: PulseDockAppStrings.processesRunningAppsTitle, subtitle: PulseDockAppStrings.processesDefaultSubtitle)
```

- [ ] **Step 2: Remove Memory page process list**

In `MemoryPage.body`, delete:

```swift
ProcessListPanel(processes: snapshot.runningApps, title: PulseDockAppStrings.processesRunningAppsTitle, subtitle: PulseDockAppStrings.processesCurrentSessionSubtitle)
```

- [ ] **Step 3: Remove dead memory process subtitle accessor**

Delete this accessor from `PulseDockAppStrings.swift` if `rg "processesCurrentSessionSubtitle"` only finds this accessor and string catalog:

```swift
static var processesCurrentSessionSubtitle: String {
    localized("app.dashboard.processes.current_session_subtitle", defaultValue: "Applications in the current session")
}
```

Remove `app.dashboard.processes.current_session_subtitle` from `PulseDockApp.xcstrings` if present.

- [ ] **Step 4: Remove duplicate Memory key-value rows**

In `memoryDetails(memoryTrend:)`, change:

```swift
KeyValueGrid(items: [
    (PulseDockAppStrings.memoryTotalLabel, snapshot.memoryDetailText),
    (PulseDockAppStrings.memoryFreeLabel, snapshot.memoryFreeText),
    (PulseDockAppStrings.memoryCachedLabel, snapshot.memoryCachedText),
    (PulseDockAppStrings.memoryCompressedLabel, snapshot.memoryCompressedText),
    (PulseDockAppStrings.memorySwapLabel, snapshot.memorySwapText),
    (PulseDockAppStrings.memorySwapAvailableLabel, snapshot.memorySwapAvailableText),
    (PulseDockAppStrings.memorySwapTotalLabel, snapshot.memorySwapTotalText)
])
```

to:

```swift
KeyValueGrid(items: [
    (PulseDockAppStrings.memoryTotalLabel, snapshot.memoryDetailText),
    (PulseDockAppStrings.memoryFreeLabel, snapshot.memoryFreeText),
    (PulseDockAppStrings.memorySwapAvailableLabel, snapshot.memorySwapAvailableText),
    (PulseDockAppStrings.memorySwapTotalLabel, snapshot.memorySwapTotalText)
])
```

Keep `compositionPanel` unchanged, because it displays `memoryCompressedText`, `memoryCachedText`, and `memorySwapText` with progress bars.

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --filter FrontendRedundancyGateTests/processListsAreConsolidatedToOverviewAndProcessesPages
swift test --filter FrontendRedundancyGateTests/memoryOverviewSensorsAndProcessesAvoidAcceptedDuplicateRows
```

Expected: the process-list test passes; the second test still fails on Overview/Sensors/Processes assertions until Task 7.

- [ ] **Step 6: Commit**

```bash
git add Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources/PulseDockApp.xcstrings
git commit -m "fix: consolidate process and memory duplicate rows"
```

---

## Task 7: Trim Overview Status, Sensors Rules, Sensors Cards, and Processes Summary

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`

- [ ] **Step 1: Trim duplicate Overview status rows**

In `overviewStatusPanel`, remove these rows:

```swift
StatusSummaryRow(title: PulseDockAppStrings.overviewCPUStatusTitle, value: "\(snapshot.cpuText) / \(MetricFormatting.percentage(store.cpuAlertThreshold))", status: usageStatusLevel(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold))
StatusSummaryRow(title: PulseDockAppStrings.overviewMemoryStatusTitle, value: "\(snapshot.memoryUsageText) / \(MetricFormatting.percentage(store.memoryAlertThreshold))", status: usageStatusLevel(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold))
StatusSummaryRow(title: PulseDockAppStrings.metricNetworkConnection, value: snapshot.networkPathText, status: networkStatusLevel(snapshot))
```

The retained rows should be:

```swift
StatusSummaryRow(title: PulseDockAppStrings.statusThermalTitle, value: snapshot.thermalText, status: thermalStatus(snapshot.thermalState))
StatusSummaryRow(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, status: snapshot.hasUptimeReport ? .normal : .neutral)
StatusSummaryRow(title: PulseDockAppStrings.metricKernelVersion, value: snapshot.kernelText, status: snapshot.hasKernelReleaseReport ? .normal : .neutral)
StatusSummaryRow(title: "\(PulseDockAppStrings.metricLoad) 1/5/15", value: snapshot.loadDetailText, status: snapshot.hasLoadAverageReport ? .normal : .neutral)
StatusSummaryRow(title: PulseDockAppStrings.metricRunningApps, value: snapshot.runningAppSummaryText, status: snapshot.hasRunningAppReport ? .normal : .neutral)
StatusSummaryRow(title: PulseDockAppStrings.metricGPUDisplays, value: snapshot.gpuDisplaySummaryText, status: snapshot.hasGPUDisplayReport ? .normal : .neutral)
StatusSummaryRow(title: PulseDockAppStrings.overviewDiskAvailableTitle, value: snapshot.diskText, status: usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold))
```

- [ ] **Step 2: Change Sensors rule table columns**

In `PulseDockAppStrings.swift`, change `statusRuleTableColumns` to:

```swift
static var statusRuleTableColumns: [String] {
    [
        localized("app.dashboard.rule_table.column.metric", defaultValue: "Metric"),
        localized("app.dashboard.rule_table.column.threshold", defaultValue: "Threshold"),
        localized("app.dashboard.rule_table.column.status", defaultValue: "Status")
    ]
}
```

Remove `app.dashboard.rule_table.column.current` from `PulseDockApp.xcstrings` if present.

- [ ] **Step 3: Remove current values from Sensors rule table rows**

Change the rule table rows from:

```swift
rows: [
    [PulseDockAppStrings.metricCPU, MetricFormatting.percentage(store.cpuAlertThreshold), snapshot.cpuText, thresholdStatusText(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold, warningText: PulseDockAppStrings.statusWarning)],
    [PulseDockAppStrings.metricMemory, MetricFormatting.percentage(store.memoryAlertThreshold), snapshot.memoryUsageText, thresholdStatusText(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold, warningText: PulseDockAppStrings.statusWarning)],
    [PulseDockAppStrings.metricDisk, MetricFormatting.percentage(store.diskAlertThreshold), snapshot.diskUsageText, thresholdStatusText(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold, warningText: PulseDockAppStrings.statusWarning)],
    [PulseDockAppStrings.metricNetworkConnection, PulseDockAppStrings.statusOnline, snapshot.networkPathText, snapshot.networkRuleStatusText]
],
```

to:

```swift
rows: [
    [PulseDockAppStrings.metricCPU, MetricFormatting.percentage(store.cpuAlertThreshold), thresholdStatusText(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold, warningText: PulseDockAppStrings.statusWarning)],
    [PulseDockAppStrings.metricMemory, MetricFormatting.percentage(store.memoryAlertThreshold), thresholdStatusText(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold, warningText: PulseDockAppStrings.statusWarning)],
    [PulseDockAppStrings.metricDisk, MetricFormatting.percentage(store.diskAlertThreshold), thresholdStatusText(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold, warningText: PulseDockAppStrings.statusWarning)],
    [PulseDockAppStrings.metricNetworkConnection, PulseDockAppStrings.statusOnline, snapshot.networkRuleStatusText]
],
```

- [ ] **Step 4: Reduce Sensors realtime cards to five core signals**

In `realtimeSignalsPanel`, keep only:

```swift
LazyVGrid(columns: capabilityColumns, spacing: 12) {
    SourceCapabilityCard(title: PulseDockAppStrings.metricCPU, value: snapshot.cpuText, icon: "cpu", status: usageStatusLevel(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold), source: PulseDockAppStrings.sourceThreshold(MetricFormatting.percentage(store.cpuAlertThreshold)))
    SourceCapabilityCard(title: PulseDockAppStrings.metricMemory, value: snapshot.memoryUsageText, icon: "memorychip", status: usageStatusLevel(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold), source: PulseDockAppStrings.sourceThreshold(MetricFormatting.percentage(store.memoryAlertThreshold)))
    SourceCapabilityCard(title: PulseDockAppStrings.metricDisk, value: snapshot.diskUsageText, icon: "internaldrive", status: usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold), source: PulseDockAppStrings.sourceThreshold(MetricFormatting.percentage(store.diskAlertThreshold)))
    SourceCapabilityCard(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, icon: "battery.75percent", status: powerStatusLevel(snapshot), source: snapshot.powerSourceText)
    SourceCapabilityCard(title: PulseDockAppStrings.metricNetworkConnection, value: snapshot.networkPathText, icon: "network", status: networkStatusLevel(snapshot), source: snapshot.networkPathDetailText)
}
```

- [ ] **Step 5: Remove displayed-list-count SummaryCard**

In `ProcessesPage.body`, change:

```swift
LazyVGrid(columns: summaryColumns, spacing: 12) {
    SummaryCard(title: PulseDockAppStrings.processesRunningAppsTitle, value: snapshot.runningAppCountText, icon: "app.badge", tint: DashboardColor.blue)
    SummaryCard(title: PulseDockAppStrings.processesDisplayedAppsTitle, value: snapshot.runningAppListCountText, icon: "list.bullet.rectangle", tint: DashboardColor.green)
    SummaryCard(title: PulseDockAppStrings.processesForegroundAppsTitle, value: snapshot.activeApplicationCountText, icon: "cursorarrow.click", tint: DashboardColor.amber)
    SummaryCard(title: PulseDockAppStrings.processesHiddenAppsTitle, value: snapshot.hiddenApplicationCountText, icon: "eye.slash", tint: DashboardColor.purple)
}
```

to:

```swift
LazyVGrid(columns: summaryColumns, spacing: 12) {
    SummaryCard(title: PulseDockAppStrings.processesRunningAppsTitle, value: snapshot.runningAppCountText, icon: "app.badge", tint: DashboardColor.blue)
    SummaryCard(title: PulseDockAppStrings.processesForegroundAppsTitle, value: snapshot.activeApplicationCountText, icon: "cursorarrow.click", tint: DashboardColor.amber)
    SummaryCard(title: PulseDockAppStrings.processesHiddenAppsTitle, value: snapshot.hiddenApplicationCountText, icon: "eye.slash", tint: DashboardColor.purple)
}
```

If `rg "processesDisplayedAppsTitle"` only finds the accessor and string catalog after this change, delete the accessor:

```swift
static var processesDisplayedAppsTitle: String {
    localized("app.dashboard.processes.displayed_apps", defaultValue: "List Items")
}
```

Remove `app.dashboard.processes.displayed_apps` from `PulseDockApp.xcstrings` if present.

- [ ] **Step 6: Run focused tests**

Run:

```bash
swift test --filter FrontendRedundancyGateTests/memoryOverviewSensorsAndProcessesAvoidAcceptedDuplicateRows
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources/PulseDockApp.xcstrings
git commit -m "fix: trim dashboard summary redundancy"
```

---

## Task 8: Full Verification and Local App Refresh

**Files:**
- No source edits unless verification finds a failure.

- [ ] **Step 1: Run full Swift tests**

```bash
swift test
```

Expected: all tests pass. The current baseline is 376 tests before adding `FrontendRedundancyGateTests`; the final count should be at least 382 tests.

- [ ] **Step 2: Run localization audit**

```bash
scripts/audit-localization.sh
```

Expected:

```text
Localization audit passed: no Chinese text remains in Swift sources.
```

- [ ] **Step 3: Build the widget target**

```bash
swift build --target PulseDockWidget
```

Expected:

```text
Build of target: 'PulseDockWidget' complete!
```

- [ ] **Step 4: Build/package local app**

```bash
scripts/package-app.sh
```

Expected: `** BUILD SUCCEEDED **` and the final printed path:

```text
/Users/qiaoni/Code/Projects/xiaozujian/dist/Pulse Dock.app
```

- [ ] **Step 5: Install local app**

```bash
scripts/install-system-widget.sh
```

Expected:

```text
/Users/qiaoni/Applications/Pulse Dock.app
```

- [ ] **Step 6: Launch installed app**

```bash
open "$HOME/Applications/Pulse Dock.app"
sleep 2
pgrep -fl "Pulse Dock"
```

Expected: a process line whose path starts with:

```text
/Users/qiaoni/Applications/Pulse Dock.app/Contents/MacOS/Pulse Dock
```

- [ ] **Step 7: Final commit**

If verification required small fixes, commit them:

```bash
git add -A
git commit -m "fix: complete frontend redundancy cleanup"
```

If `git status --short` is clean, do not create an empty commit.

---

## Manual Visual QA Checklist

Use the installed app at `/Users/qiaoni/Applications/Pulse Dock.app`.

- [ ] Sidebar shows only app title, section label, and navigation rows; no live sampling card.
- [ ] Top bar still shows local machine, sample time, and refresh interval chips.
- [ ] Overview shows MetricCards, StatusPanel, ProcessListPanel, and WidgetPreviewPanel; it does not show the old five-row Runtime Trends panel.
- [ ] Overview StatusPanel has no CPU, Memory, or Network connection rows.
- [ ] CPU page has processor, load, and per-core panels; it does not show a running apps table or Recent Sample row.
- [ ] Memory page has usage and composition panels; it does not show a running apps table.
- [ ] Network page has five MetricCards, connectivity table without the path/status first row, and interface table; it does not show the old trend panel.
- [ ] Power page has battery panel, thermal panel, and Battery Information table; duplicated battery detail rows are not repeated beside the gauge.
- [ ] Sensors page realtime cards show CPU, Memory, Disk, Power, and Network only.
- [ ] Sensors rule table has Metric, Threshold, and Status columns only.
- [ ] Processes page shows three SummaryCards: Running Apps, Foreground Apps, Hidden Apps.
- [ ] Settings widget preview remains visible.
- [ ] History trends remain visible.

---

## Self-Review

### Spec Coverage

- F-high fixes FR-1 through FR-6 are covered by Tasks 4, 5, and 6.
- Accepted F-medium fixes FR-7, FR-9, FR-10, FR-11, FR-12, FR-13, FR-14, FR-15, FR-16, and FR-17 are covered by Tasks 3, 6, and 7.
- Accepted F-low fix FR-24 is covered by Task 7.
- Explicit non-actions FR-18 through FR-23 and FR-25 are documented in the decision table and Task 2 docs update.

### Placeholder Scan

This plan contains no implementation placeholders. Every code-editing step names exact files, exact symbols, and replacement snippets.

### Type and Symbol Consistency

- `FrontendRedundancyGateTests` uses local helper names that do not collide with existing `fixture` helpers in other test files.
- `componentBody(named:in:)` matches the helper pattern already used in `VisualFrontendGateTests.swift`.
- All Swift identifiers referenced in tests exist in current source: `SidebarHealthCard`, `DashboardTopBar`, `OverviewPage`, `NetworkPage`, `PowerPage`, `CPUPage`, `MemoryPage`, `ProcessesPage`, `SensorsPage`, `statusRuleTableColumns`, and `ProcessListPanel`.

