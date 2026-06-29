# Pulse Dock Redundancy Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove verified redundant presentation, duplicated metric logic, and stale compact-widget payload fields while preserving the intentional multi-surface summaries that make Pulse Dock usable from the dashboard, menu bar popover, and desktop widget.

**Architecture:** Treat `SharedMetrics` as the source of truth for metric semantics, progress math, and pure color-component data. Keep SwiftUI `Color` construction inside the app, popover, and widget targets, but make each target consume the same shared semantic tone and RGB component contracts. Reduce visible duplicate panels only where the same window shows the same value twice without adding context.

**Tech Stack:** Swift 6, SwiftUI on macOS 14+, WidgetKit, SharedMetrics SwiftPM library, Swift Testing source-level gates, existing generated Xcode project workflow.

---

## 0. Verified Scope And Corrections

This plan is based on verification against current `HEAD 876bcc2`, not only the raw redundancy review text.

| Review Item | Current Verification | Execution Decision |
| --- | --- | --- |
| `normalizedRate` count | Only 2 wrappers exist: `DashboardView.swift` and `WidgetPanelView.swift`. `SystemDashboardWidget.swift` already calls shared scale APIs directly. | Remove the 2 wrappers; do not search for a third local function. |
| `No Battery` branch | `powerSourceNoBattery` is already removed from current runtime code and string helpers. | Keep it as an already-fixed note in review docs; do not create product code changes. |
| `widgetCompact 25 dead fields` | Current `MetricSnapshot+WidgetCompact.swift` no longer passes the 5 network-rate fields listed by the report. The still-retained dead fields are 20: CPU cores/physical cores, memory composition, 5/15 min load, and battery electrical/health details. | Correct review docs and trim the remaining 20 fields. |
| R1-3 local rules wording | Sensors and History repeat the same rule values, but the first-column labels are not byte-identical (`CPU` vs `CPU Over`, etc.). | Treat as true information redundancy, not literal byte-for-byte row duplication. |
| Sidebar health card | `sampleTimeText` duplicates the top-bar chip. CPU/Mem/Disk rows are useful cross-page context. | Remove only the sidebar timestamp; keep the compact metric rows. |
| Overview trends vs History trends | Overview is a subset of History, but it has first-screen overview value. | Keep Overview trends in this pass. |
| Undo/Redo menu | The menu items are usually disabled, but the Edit menu is conventional for macOS apps and supports responder-chain text fields if added later. | Keep Undo/Redo; document as intentional low-risk sample menu. |
| `design/` vs `designs/` | Both directories are tracked and hold overlapping concept assets. | Consolidate assets after code changes, keeping one canonical design directory. |

---

## 1. Acceptance Criteria

The work is complete only when all of these are true:

- Redundancy review docs reflect the corrected current state: `normalizedRate` is 2 wrappers, `No Battery` is fixed, and widget compact dead fields are 20 rather than 25.
- Thermal, network, and power semantic tones are defined by shared model contracts, not by three separate UI switches.
- Thermal `hot` renders as the same severity across dashboard, popover, and widget.
- Network `unknown` renders as the same neutral/cyan tone across dashboard, popover, and widget.
- `reportedProgress`, `progressFillWidth`, and network-path progress have a single shared implementation.
- Light and dark RGB values for green, blue, amber, red, and cyan come from one shared component table.
- Dashboard colors adapt to dark mode for the shared accent colors.
- Sensors page no longer shows a separate System Signals table and Live Signals card grid with the same values; one combined signal panel remains.
- History page no longer repeats the current local-rule table after the threshold controls.
- Sidebar keeps live CPU/Mem/Disk context but removes the duplicate timestamp already shown in the top bar.
- Settings widget preview keeps widget-specific rows and removes refresh/main-window rows that duplicate the settings controls.
- Widget compact snapshots do not retain fields the widget never reads, and `SystemSampler.sampleWidgetCompact()` returns the same projection contract used by `SharedSnapshotStore`.
- `designs/` is either deleted or documented as archived, with `design/` retained as the canonical design asset directory.
- `swift test`, `swift build`, `swift build --target PulseDockWidget`, `scripts/audit-localization.sh`, and generated Xcode project build pass.

Manual QA must cover:

- Dashboard, Sensors, History, Settings, menu bar popover, and Small/Medium/Large widgets.
- Light and dark appearances.
- English and Simplified Chinese localizations.
- Network states: satisfied, requires connection, unsatisfied, unknown.
- Thermal states: nominal, warm, hot, critical, unknown.

---

## 2. File Structure

### Create

- `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`
  - Source-level gates for corrected review claims, shared semantic contracts, compact widget payload trimming, and removed duplicate panels.

- `Sources/SharedMetrics/MetricAccentComponents.swift`
  - Pure Swift RGB component table for shared accent colors. This file must not import SwiftUI.

### Modify

- `docs/review/top/redundancy-final.md`
  - Correct the stale current-state claims and execution counts.

- `docs/review/middle/redundancy-integrated.md`
  - Correct the widget compact dead-field count and R1-3 wording.

- `docs/review/subagents/R3-dead-state.md`
  - Replace the 25-field compact-widget dead-field table with the current 20-field table.

- `Sources/SharedMetrics/MetricStateContracts.swift`
  - Add `MetricStatusTone` and progress properties for `ThermalState` and `NetworkPathState`.

- `Sources/SharedMetrics/MetricScales.swift`
  - Add shared `reportedProgress` and `fillWidth` helpers.

- `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift`
  - Remove the remaining dead compact payload fields.

- `Sources/SharedMetrics/SystemSampler.swift`
  - Make `sampleWidgetCompact()` return `.widgetCompactSnapshot()` so fallback widget sampling and App Group snapshots share the same contract.

- `Sources/PulseDockApp/DashboardVisualTokens.swift`
  - Convert shared accent colors to adaptive colors backed by `MetricAccentComponents`.

- `Sources/PulseDockApp/DashboardView.swift`
  - Use shared semantic tone/progress helpers and remove verified duplicate UI surfaces.

- `Sources/PulseDockApp/WidgetPanelView.swift`
  - Use shared semantic tone/progress helpers and shared accent components.

- `Sources/PulseDockWidget/WidgetVisualTokens.swift`
  - Use shared accent components for widget colors.

- `Sources/PulseDockWidget/SystemDashboardWidget.swift`
  - Use shared semantic tone/progress helpers.

- `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`
  - Update compact snapshot expectations that currently require fields which will be intentionally trimmed.

- `Tests/SharedMetricsTests/MetricFormattingTests.swift`
  - Update source-level string gates for removed wrappers and duplicate UI panels.

- `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
  - Update visual-token expectations for shared color components.

### Delete

- `designs/macos-monitor-ui/*`
  - Remove the duplicate tracked design asset set after retaining the canonical `design/gptimage2-system-monitor/` set.

---

## 3. Shared Contracts

### Severity Decisions

These mappings are intentional and must be consistent across surfaces:

| Domain | State | Tone |
| --- | --- | --- |
| Thermal | `critical` | `.critical` |
| Thermal | `hot` | `.critical` |
| Thermal | `warm` | `.warning` |
| Thermal | `nominal` | `.normal` |
| Thermal | `unknown` | `.neutral` |
| Network | `satisfied` | `.normal` |
| Network | `requiresConnection` | `.warning` |
| Network | `unsatisfied` | `.critical` |
| Network | `unknown` | `.neutral` |
| Power | existing `MetricSnapshot.powerStatusTone` | unchanged |

### Shared Accent Decisions

Use these canonical component values:

| Accent | Light RGB | Dark RGB |
| --- | --- | --- |
| green | `0.04, 0.62, 0.39` | `0.24, 0.82, 0.62` |
| blue | `0.14, 0.43, 0.95` | `0.36, 0.62, 1.00` |
| amber | `0.93, 0.54, 0.10` | `1.00, 0.68, 0.28` |
| cyan | `0.04, 0.56, 0.70` | `0.29, 0.78, 0.88` |
| red | `0.84, 0.16, 0.16` | `1.00, 0.42, 0.42` |

These dark values intentionally use the current widget token values, because widgets are the most constrained dark-mode surface and already tuned for contrast.

---

## 4. Implementation Tasks

### Task 1: Correct Review Docs And Add Redundancy Gates

**Files:**
- Modify: `docs/review/top/redundancy-final.md`
- Modify: `docs/review/middle/redundancy-integrated.md`
- Modify: `docs/review/subagents/R3-dead-state.md`
- Create: `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`

- [ ] **Step 1: Add failing source-level gates**

Create `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`:

```swift
import Foundation
import Testing
@testable import SharedMetrics

private func redundancyFixture(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

@Suite("RedundancyOptimizationGateTests")
struct RedundancyOptimizationGateTests {
    @Test func redundancyReviewDocsUseCurrentVerifiedCorrections() throws {
        let final = try redundancyFixture("docs/review/top/redundancy-final.md")
        let middle = try redundancyFixture("docs/review/middle/redundancy-integrated.md")
        let r3 = try redundancyFixture("docs/review/subagents/R3-dead-state.md")

        #expect(final.contains("HEAD `876bcc2`"))
        #expect(final.contains("normalizedRate 仅 2 处"))
        #expect(final.contains("widgetCompact 20 个死字段"))
        #expect(final.contains("R1-3 是规则语义重复，不是逐字符重复"))
        #expect(middle.contains("widgetCompact 20 个死字段"))
        #expect(r3.contains("20 个死字段"))
        #expect(!final.contains("widgetCompact 25 个死字段"))
        #expect(!middle.contains("widgetCompact 25 个死字段"))
    }

    @Test func sharedMetricContractsExposeToneAndProgress() {
        #expect(ThermalState.nominal.metricStatusTone == .normal)
        #expect(ThermalState.warm.metricStatusTone == .warning)
        #expect(ThermalState.hot.metricStatusTone == .critical)
        #expect(ThermalState.critical.metricStatusTone == .critical)
        #expect(ThermalState.unknown.metricStatusTone == .neutral)
        #expect(ThermalState.hot.progress == 0.78)

        #expect(NetworkPathState.satisfied.metricStatusTone == .normal)
        #expect(NetworkPathState.requiresConnection.metricStatusTone == .warning)
        #expect(NetworkPathState.unsatisfied.metricStatusTone == .critical)
        #expect(NetworkPathState.unknown.metricStatusTone == .neutral)
        #expect(NetworkPathState.requiresConnection.progress == 0.45)
    }

    @Test func metricScalesOwnPresentationProgressHelpers() {
        #expect(MetricScales.reportedProgress(hasReport: false, progress: 0.7) == nil)
        #expect(MetricScales.reportedProgress(hasReport: true, progress: 0.7) == 0.7)
        #expect(MetricScales.fillWidth(0, in: 100, minimumVisibleWidth: 8) == 0)
        #expect(MetricScales.fillWidth(0.01, in: 100, minimumVisibleWidth: 8) == 8)
        #expect(MetricScales.fillWidth(0.5, in: 100, minimumVisibleWidth: 8) == 50)
    }

    @Test func widgetCompactSnapshotTrimsCurrentDeadFields() {
        let source = MetricSnapshot(
            cpuUsage: 0.42,
            cpuCoreUsages: [0.1, 0.2],
            hasCPUUsageReport: true,
            physicalCoreCount: 8,
            logicalCoreCount: 10,
            activeProcessorCount: 10,
            memoryUsedBytes: 8_000,
            memoryTotalBytes: 16_000,
            memoryFreeBytes: 2_000,
            memoryWiredBytes: 1_000,
            memoryCompressedBytes: 500,
            memoryCachedBytes: 3_000,
            memorySwapUsedBytes: 128,
            memorySwapTotalBytes: 256,
            memorySwapAvailableBytes: 128,
            hasMemoryCompositionReport: true,
            loadAverage: 1.1,
            loadAverage5: 1.2,
            loadAverage15: 1.3,
            hasLoadAverageReport: true,
            thermalState: "Nominal",
            batteryPercent: 0.62,
            batteryIsCharging: false,
            batteryPowerSource: "Battery Power",
            batteryTimeRemainingMinutes: 42,
            batteryCycleCount: 12,
            batteryHealth: "Good",
            batteryCurrentCapacity: 82,
            batteryMaxCapacity: 90,
            batteryDesignCapacity: 100,
            batteryVoltageMillivolts: 12_000,
            batteryAmperageMilliamps: -300,
            networkPathStatus: "satisfied",
            diskFreeBytes: 4_000,
            diskTotalBytes: 10_000,
            uptimeSeconds: 120,
            hasUptimeReport: true,
            osVersion: "macOS",
            kernelRelease: "Darwin",
            timestamp: Date(timeIntervalSince1970: 1_000)
        )

        let compact = source.widgetCompactSnapshot()

        #expect(compact.cpuCoreUsages.isEmpty)
        #expect(compact.physicalCoreCount == 0)
        #expect(compact.memoryFreeBytes == 0)
        #expect(compact.memoryWiredBytes == 0)
        #expect(compact.memoryCompressedBytes == 0)
        #expect(compact.memoryCachedBytes == 0)
        #expect(compact.memorySwapUsedBytes == 0)
        #expect(compact.memorySwapTotalBytes == 0)
        #expect(compact.memorySwapAvailableBytes == 0)
        #expect(!compact.hasMemoryCompositionReport)
        #expect(compact.loadAverage5 == 0)
        #expect(compact.loadAverage15 == 0)
        #expect(compact.batteryTimeRemainingMinutes == nil)
        #expect(compact.batteryCycleCount == nil)
        #expect(compact.batteryHealth == nil)
        #expect(compact.batteryCurrentCapacity == nil)
        #expect(compact.batteryMaxCapacity == nil)
        #expect(compact.batteryDesignCapacity == nil)
        #expect(compact.batteryVoltageMillivolts == nil)
        #expect(compact.batteryAmperageMilliamps == nil)

        #expect(compact.cpuUsage == source.cpuUsage)
        #expect(compact.logicalCoreCount == source.logicalCoreCount)
        #expect(compact.activeProcessorCount == source.activeProcessorCount)
        #expect(compact.memoryUsedBytes == source.memoryUsedBytes)
        #expect(compact.memoryTotalBytes == source.memoryTotalBytes)
        #expect(compact.loadAverage == source.loadAverage)
        #expect(compact.batteryPercent == source.batteryPercent)
        #expect(compact.batteryPowerSource == source.batteryPowerSource)
        #expect(compact.canonicalNetworkPathState == .satisfied)
        #expect(compact.diskFreeBytes == source.diskFreeBytes)
        #expect(compact.diskTotalBytes == source.diskTotalBytes)
    }

    @Test func duplicateUiPanelsAreRemovedFromDashboardSource() throws {
        let dashboard = try redundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let sidebar = componentBody(named: "SidebarHealthCard", in: dashboard)
        let sensors = componentBody(named: "SensorsPage", in: dashboard)
        let history = componentBody(named: "HistoryAlertsPage", in: dashboard)
        let settings = componentBody(named: "SettingsPage", in: dashboard)

        #expect(!sidebar.contains("snapshot.sampleTimeText"))
        #expect(sensors.contains("statusRealtimeSignalsTitle"))
        #expect(!sensors.contains("statusSystemSignalsTitle"))
        #expect(!history.contains("localRuleTableTitle"))
        #expect(!settings.contains("settingsWidgetRefreshLabel"))
        #expect(!settings.contains("settingsWidgetMainWindowLabel"))
    }
}

private func componentBody(named name: String, in source: String) -> String {
    guard let range = source.range(of: "private struct \(name)") else { return "" }
    let tail = source[range.lowerBound...]
    if let next = tail.dropFirst().range(of: "\nprivate struct ") {
        return String(tail[..<next.lowerBound])
    }
    if let next = tail.dropFirst().range(of: "\nprivate func ") {
        return String(tail[..<next.lowerBound])
    }
    return String(tail)
}
```

- [ ] **Step 2: Run the new tests and verify they fail**

Run:

```bash
swift test --filter RedundancyOptimizationGateTests
```

Expected: FAIL because the docs still contain the stale `25 个死字段` wording, shared tone/progress helpers do not exist yet, and duplicate UI panels still exist.

- [ ] **Step 3: Correct the review docs**

Update the three review docs with these exact current-state statements:

```markdown
> Current implementation baseline for this optimization plan: HEAD `876bcc2`.

Corrections from top-level verification:
- `normalizedRate` is present in 2 local wrappers only: `DashboardView.swift` and `WidgetPanelView.swift`.
- The previous `No Battery` branch is already removed; no runtime or string helper named `powerSourceNoBattery` remains.
- `widgetCompactSnapshot()` currently retains 20 widget-dead fields, not 25. The 5 network-rate fields listed by the first report are already absent from `MetricSnapshot+WidgetCompact.swift`.
- R1-3 is a true local-rule information redundancy, but it is not byte-for-byte row duplication because History uses rule labels such as `CPU Over`.
```

In `R3-dead-state.md`, replace the stale 25-field compact list with:

```markdown
Current widget-dead compact fields:
- CPU: `cpuCoreUsages`, `physicalCoreCount`
- Memory: `memoryFreeBytes`, `memoryWiredBytes`, `memoryCompressedBytes`, `memoryCachedBytes`, `memorySwapUsedBytes`, `memorySwapTotalBytes`, `memorySwapAvailableBytes`, `hasMemoryCompositionReport`
- Load: `loadAverage5`, `loadAverage15`
- Battery: `batteryTimeRemainingMinutes`, `batteryCycleCount`, `batteryHealth`, `batteryCurrentCapacity`, `batteryMaxCapacity`, `batteryDesignCapacity`, `batteryVoltageMillivolts`, `batteryAmperageMilliamps`
```

- [ ] **Step 4: Run the doc portion of the tests**

Run:

```bash
swift test --filter RedundancyOptimizationGateTests/redundancyReviewDocsUseCurrentVerifiedCorrections
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add docs/review/top/redundancy-final.md docs/review/middle/redundancy-integrated.md docs/review/subagents/R3-dead-state.md Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift
git commit -m "docs: correct redundancy review baseline"
```

---

### Task 2: Add Shared Semantic Tone And Progress Contracts

**Files:**
- Modify: `Sources/SharedMetrics/MetricStateContracts.swift`
- Modify: `Sources/SharedMetrics/MetricScales.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Test: `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Confirm the shared contract tests fail**

Run:

```bash
swift test --filter RedundancyOptimizationGateTests/sharedMetricContractsExposeToneAndProgress
swift test --filter RedundancyOptimizationGateTests/metricScalesOwnPresentationProgressHelpers
```

Expected: FAIL because `metricStatusTone`, `progress`, `reportedProgress`, and `fillWidth` are not defined.

- [ ] **Step 2: Add semantic properties to `MetricStateContracts.swift`**

Append these properties inside the existing enums:

```swift
public var metricStatusTone: MetricStatusTone {
    switch self {
    case .critical, .hot:
        return .critical
    case .warm:
        return .warning
    case .nominal:
        return .normal
    case .unknown:
        return .neutral
    }
}

public var progress: Double? {
    switch self {
    case .critical:
        return 1
    case .hot:
        return 0.78
    case .warm:
        return 0.52
    case .nominal:
        return 0.24
    case .unknown:
        return nil
    }
}
```

for `ThermalState`, and:

```swift
public var metricStatusTone: MetricStatusTone {
    switch self {
    case .satisfied:
        return .normal
    case .requiresConnection:
        return .warning
    case .unsatisfied:
        return .critical
    case .unknown:
        return .neutral
    }
}

public var progress: Double {
    switch self {
    case .satisfied:
        return 1
    case .requiresConnection:
        return 0.45
    case .unsatisfied, .unknown:
        return 0
    }
}
```

for `NetworkPathState`.

- [ ] **Step 3: Add progress helpers to `MetricScales.swift`**

Change the file header and body to include `CoreGraphics`:

```swift
import CoreGraphics
import Foundation

public enum MetricScales {
    public static let networkRateReferenceBytesPerSecond = 12_500_000_000.0

    public static func networkRateProgress(bytesPerSecond: UInt64) -> Double {
        guard bytesPerSecond > 0 else { return 0 }
        let value = min(Double(bytesPerSecond), networkRateReferenceBytesPerSecond)
        return min(log10(value + 1) / log10(networkRateReferenceBytesPerSecond + 1), 1)
    }

    public static func reportedProgress(hasReport: Bool, progress: Double) -> Double? {
        guard hasReport else { return nil }
        return progress
    }

    public static func fillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat {
        guard let normalizedProgress = clampedProgress(progress), normalizedProgress > 0 else {
            return 0
        }
        return max(minimumVisibleWidth, totalWidth * normalizedProgress)
    }

    public static func clampedProgress(_ progress: Double) -> Double? {
        guard progress.isFinite else { return nil }
        return min(max(progress, 0), 1)
    }
}
```

- [ ] **Step 4: Replace local progress wrappers**

In `DashboardView.swift`, remove local `normalizedRate`, `reportedProgress`, `progressFillWidth`, `networkPathProgress`, and `thermalProgress` bodies. Replace their call sites with:

```swift
MetricScales.networkRateProgress(bytesPerSecond: value)
MetricScales.reportedProgress(hasReport: hasReport, progress: progress)
MetricScales.fillWidth(progress, in: totalWidth, minimumVisibleWidth: minimumVisibleWidth)
snapshot.canonicalNetworkPathState.progress
ThermalState(raw: snapshot.thermalState).progress
```

Keep small local helper names only when they add app-specific context. For `thermalStatus(_:)` and `networkStatusLevel(_:)`, rewrite them to use shared tones:

```swift
private func statusLevel(for tone: MetricStatusTone) -> StatusLevel {
    switch tone {
    case .normal:
        return .normal
    case .warning:
        return .warning
    case .critical:
        return .critical
    case .neutral:
        return .neutral
    }
}

private func networkStatusLevel(_ snapshot: MetricSnapshot) -> StatusLevel {
    statusLevel(for: snapshot.canonicalNetworkPathState.metricStatusTone)
}

private func thermalStatus(_ state: String) -> StatusLevel {
    statusLevel(for: ThermalState(raw: state).metricStatusTone)
}
```

- [ ] **Step 5: Replace popover and widget progress/tone wrappers**

In `WidgetPanelView.swift` and `SystemDashboardWidget.swift`, remove duplicated `normalizedRate`, `reportedProgress`, `progressFillWidth`, and `networkPathProgress` functions. Replace calls with the shared forms:

```swift
MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkBytesPerSecond)
MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress)
MetricScales.fillWidth(progress, in: width, minimumVisibleWidth: 6)
```

In the popover and widget tone functions, switch on shared tone:

```swift
private func thermalTint(_ state: String) -> Color {
    tint(for: ThermalState(raw: state).metricStatusTone)
}

private func networkTint(_ snapshot: MetricSnapshot) -> Color {
    tint(for: snapshot.canonicalNetworkPathState.metricStatusTone)
}
```

Use the existing `powerStatusTone` without changing its semantics.

- [ ] **Step 6: Update source-level tests that expected local wrappers**

In `MetricFormattingTests.swift`, replace assertions such as:

```swift
#expect(dashboardView.contains("private func reportedProgress(hasReport: Bool, progress: Double) -> Double?"))
```

with:

```swift
#expect(metricScales.contains("public static func reportedProgress(hasReport: Bool, progress: Double) -> Double?"))
#expect(metricScales.contains("public static func fillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat"))
#expect(!dashboardView.contains("private func reportedProgress(hasReport: Bool, progress: Double) -> Double?"))
#expect(!widgetPanel.contains("private func normalizedRate(_ bytesPerSecond: UInt64) -> Double"))
#expect(!widget.contains("private func networkPathProgress(_ snapshot: MetricSnapshot) -> Double"))
```

- [ ] **Step 7: Run tests**

Run:

```bash
swift test --filter RedundancyOptimizationGateTests/sharedMetricContractsExposeToneAndProgress
swift test --filter RedundancyOptimizationGateTests/metricScalesOwnPresentationProgressHelpers
swift test --filter MetricFormattingTests
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/SharedMetrics/MetricStateContracts.swift Sources/SharedMetrics/MetricScales.swift Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/MetricFormattingTests.swift Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift
git commit -m "refactor: centralize metric presentation contracts"
```

---

### Task 3: Centralize Accent Color Components

**Files:**
- Create: `Sources/SharedMetrics/MetricAccentComponents.swift`
- Modify: `Sources/PulseDockApp/DashboardVisualTokens.swift`
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
- Modify: `Sources/PulseDockWidget/WidgetVisualTokens.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Test: `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`
- Test: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Add failing color-component gate**

Append to `RedundancyOptimizationGateTests`:

```swift
@Test func sharedAccentComponentsMatchCanonicalValues() {
    #expect(MetricAccentComponents.color(.green, scheme: .light) == MetricRGBComponents(red: 0.04, green: 0.62, blue: 0.39))
    #expect(MetricAccentComponents.color(.green, scheme: .dark) == MetricRGBComponents(red: 0.24, green: 0.82, blue: 0.62))
    #expect(MetricAccentComponents.color(.blue, scheme: .light) == MetricRGBComponents(red: 0.14, green: 0.43, blue: 0.95))
    #expect(MetricAccentComponents.color(.blue, scheme: .dark) == MetricRGBComponents(red: 0.36, green: 0.62, blue: 1.00))
    #expect(MetricAccentComponents.color(.amber, scheme: .light) == MetricRGBComponents(red: 0.93, green: 0.54, blue: 0.10))
    #expect(MetricAccentComponents.color(.amber, scheme: .dark) == MetricRGBComponents(red: 1.00, green: 0.68, blue: 0.28))
    #expect(MetricAccentComponents.color(.cyan, scheme: .light) == MetricRGBComponents(red: 0.04, green: 0.56, blue: 0.70))
    #expect(MetricAccentComponents.color(.cyan, scheme: .dark) == MetricRGBComponents(red: 0.29, green: 0.78, blue: 0.88))
    #expect(MetricAccentComponents.color(.red, scheme: .light) == MetricRGBComponents(red: 0.84, green: 0.16, blue: 0.16))
    #expect(MetricAccentComponents.color(.red, scheme: .dark) == MetricRGBComponents(red: 1.00, green: 0.42, blue: 0.42))
}
```

Run:

```bash
swift test --filter RedundancyOptimizationGateTests/sharedAccentComponentsMatchCanonicalValues
```

Expected: FAIL because `MetricAccentComponents` does not exist yet.

- [ ] **Step 2: Create `MetricAccentComponents.swift`**

Add:

```swift
import Foundation

public enum MetricAccent: String, CaseIterable, Sendable {
    case green
    case blue
    case amber
    case cyan
    case red
}

public enum MetricAccentScheme: Sendable {
    case light
    case dark
}

public struct MetricRGBComponents: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum MetricAccentComponents {
    public static func color(_ accent: MetricAccent, scheme: MetricAccentScheme) -> MetricRGBComponents {
        switch (accent, scheme) {
        case (.green, .light):
            return MetricRGBComponents(red: 0.04, green: 0.62, blue: 0.39)
        case (.green, .dark):
            return MetricRGBComponents(red: 0.24, green: 0.82, blue: 0.62)
        case (.blue, .light):
            return MetricRGBComponents(red: 0.14, green: 0.43, blue: 0.95)
        case (.blue, .dark):
            return MetricRGBComponents(red: 0.36, green: 0.62, blue: 1.00)
        case (.amber, .light):
            return MetricRGBComponents(red: 0.93, green: 0.54, blue: 0.10)
        case (.amber, .dark):
            return MetricRGBComponents(red: 1.00, green: 0.68, blue: 0.28)
        case (.cyan, .light):
            return MetricRGBComponents(red: 0.04, green: 0.56, blue: 0.70)
        case (.cyan, .dark):
            return MetricRGBComponents(red: 0.29, green: 0.78, blue: 0.88)
        case (.red, .light):
            return MetricRGBComponents(red: 0.84, green: 0.16, blue: 0.16)
        case (.red, .dark):
            return MetricRGBComponents(red: 1.00, green: 0.42, blue: 0.42)
        }
    }
}
```

- [ ] **Step 3: Convert components to SwiftUI colors in app tokens**

In `DashboardVisualTokens.swift`, import SharedMetrics and add adaptive color helpers:

```swift
import AppKit
import SharedMetrics
import SwiftUI

private func dashboardColor(_ accent: MetricAccent) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
        let scheme: MetricAccentScheme = bestMatch == .darkAqua ? .dark : .light
        let components = MetricAccentComponents.color(accent, scheme: scheme)
        return NSColor(
            calibratedRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: 1
        )
    })
}
```

Then replace shared accent constants:

```swift
static let blue = dashboardColor(.blue)
static let green = dashboardColor(.green)
static let amber = dashboardColor(.amber)
static let red = dashboardColor(.red)
static let cyan = dashboardColor(.cyan)
```

Keep `purple` app-local for now because no widget/popover purple token exists today.

- [ ] **Step 4: Convert popover Palette to shared components**

In `WidgetPanelView.swift`, import `SharedMetrics` already exists. Add:

```swift
private func popoverColor(_ accent: MetricAccent, for colorScheme: ColorScheme) -> Color {
    let components = MetricAccentComponents.color(accent, scheme: colorScheme == .dark ? .dark : .light)
    return Color(red: components.red, green: components.green, blue: components.blue)
}
```

Replace `Palette` color funcs:

```swift
static func blue(for colorScheme: ColorScheme) -> Color { popoverColor(.blue, for: colorScheme) }
static func green(for colorScheme: ColorScheme) -> Color { popoverColor(.green, for: colorScheme) }
static func amber(for colorScheme: ColorScheme) -> Color { popoverColor(.amber, for: colorScheme) }
static func cyan(for colorScheme: ColorScheme) -> Color { popoverColor(.cyan, for: colorScheme) }
static func red(for colorScheme: ColorScheme) -> Color { popoverColor(.red, for: colorScheme) }
```

- [ ] **Step 5: Convert widget colors to shared components**

In `WidgetVisualTokens.swift`, add:

```swift
private func widgetColor(_ accent: MetricAccent, for colorScheme: ColorScheme) -> Color {
    let components = MetricAccentComponents.color(accent, scheme: colorScheme == .dark ? .dark : .light)
    return Color(red: components.red, green: components.green, blue: components.blue)
}
```

Replace each `WidgetColor` accent function with:

```swift
static func blue(for colorScheme: ColorScheme) -> Color { widgetColor(.blue, for: colorScheme) }
static func green(for colorScheme: ColorScheme) -> Color { widgetColor(.green, for: colorScheme) }
static func amber(for colorScheme: ColorScheme) -> Color { widgetColor(.amber, for: colorScheme) }
static func cyan(for colorScheme: ColorScheme) -> Color { widgetColor(.cyan, for: colorScheme) }
static func red(for colorScheme: ColorScheme) -> Color { widgetColor(.red, for: colorScheme) }
```

- [ ] **Step 6: Add tone-to-color adapters**

In `DashboardVisualTokens.swift`:

```swift
extension DashboardColor {
    static func color(for tone: MetricStatusTone) -> Color {
        switch tone {
        case .normal:
            return green
        case .warning:
            return amber
        case .critical:
            return red
        case .neutral:
            return cyan
        }
    }
}
```

In `WidgetPanelView.swift`:

```swift
private func popoverColor(for tone: MetricStatusTone, colorScheme: ColorScheme) -> Color {
    switch tone {
    case .normal:
        return Palette.green(for: colorScheme)
    case .warning:
        return Palette.amber(for: colorScheme)
    case .critical:
        return Palette.red(for: colorScheme)
    case .neutral:
        return Palette.cyan(for: colorScheme)
    }
}
```

In `WidgetVisualTokens.swift`:

```swift
func widgetColor(for tone: MetricStatusTone, colorScheme: ColorScheme) -> Color {
    switch tone {
    case .normal:
        return WidgetColor.green(for: colorScheme)
    case .warning:
        return WidgetColor.amber(for: colorScheme)
    case .critical:
        return WidgetColor.red(for: colorScheme)
    case .neutral:
        return WidgetColor.cyan(for: colorScheme)
    }
}
```

- [ ] **Step 7: Run tests**

Run:

```bash
swift test --filter RedundancyOptimizationGateTests/sharedAccentComponentsMatchCanonicalValues
swift test --filter VisualFrontendGateTests/visualTokensCentralizeDashboardTypographySpacingAndColors
swift build --target PulseDockWidget
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/SharedMetrics/MetricAccentComponents.swift Sources/PulseDockApp/DashboardVisualTokens.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/PulseDockWidget/WidgetVisualTokens.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift Tests/SharedMetricsTests/VisualFrontendGateTests.swift
git commit -m "refactor: share metric accent colors"
```

---

### Task 4: Remove Verified Dashboard Information Redundancy

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`
- Modify: `Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings`
- Modify: `Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings`
- Test: `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`
- Test: `Tests/SharedMetricsTests/LocalizationGateTests.swift`

- [ ] **Step 1: Confirm UI redundancy gate fails**

Run:

```bash
swift test --filter RedundancyOptimizationGateTests/duplicateUiPanelsAreRemovedFromDashboardSource
```

Expected: FAIL because the sidebar timestamp, Sensors system table, History local rule table, and duplicate Settings widget rows are still present.

- [ ] **Step 2: Remove only the duplicate sidebar timestamp**

In `SidebarHealthCard`, replace the first `HStack`:

```swift
HStack {
    StatusDot(color: thermalColor)
    Text(PulseDockAppStrings.dashboardSidebarLiveSampling)
        .font(.system(size: 13, weight: .semibold))
    Spacer()
}
```

Keep the CPU, memory, and disk compact rows unchanged.

- [ ] **Step 3: Merge Sensors system signals into the live signal grid**

Remove this entire panel from `SensorsPage.body`:

```swift
DashboardPanel(title: PulseDockAppStrings.statusSystemSignalsTitle, subtitle: PulseDockAppStrings.statusSystemSignalsSubtitle, icon: "list.clipboard") {
    ResponsiveTable(...)
}
```

Add the missing kernel card to `realtimeSignalsPanel` so the removed table does not drop kernel visibility:

```swift
SourceCapabilityCard(
    title: PulseDockAppStrings.metricKernelVersion,
    value: snapshot.kernelText,
    icon: "terminal",
    status: snapshot.hasKernelReleaseReport ? .normal : .neutral,
    source: PulseDockAppStrings.sourceSystemVersion
)
```

Place it after the OS version card so OS/kernel/uptime remain grouped.

- [ ] **Step 4: Remove History local-rule table**

Delete the `DashboardPanel(title: PulseDockAppStrings.localRuleTableTitle` block from `HistoryAlertsPage`. Keep:

```swift
DashboardPanel(title: PulseDockAppStrings.historyThresholdSettingsTitle, subtitle: PulseDockAppStrings.historyThresholdSettingsSubtitle, icon: "slider.horizontal.3")
```

The single current local-rule evaluation table remains on Sensors.

- [ ] **Step 5: Remove duplicate Settings widget rows**

In `settings.widgetPreviewPanel`, keep these rows:

```swift
KeyValueGrid(items: [
    (PulseDockAppStrings.settingsWidgetSizeLabel, PulseDockAppStrings.settingsWidgetSizesValue),
    (PulseDockAppStrings.settingsWidgetDataSourceLabel, PulseDockAppStrings.settingsWidgetDataSourceValue),
    (PulseDockAppStrings.settingsWidgetSampleLabel, snapshot.sampleTimeText),
    (PulseDockAppStrings.settingsWidgetHistoryLabel, store.historyDurationText)
])
```

Remove:

```swift
(PulseDockAppStrings.settingsWidgetRefreshLabel, PulseDockAppStrings.settingsWidgetRefreshValue)
(PulseDockAppStrings.settingsWidgetMainWindowLabel, store.refreshInterval.label)
```

- [ ] **Step 6: Keep localization symbols until audit confirms they are unused**

Do not delete `statusSystemSignalsTitle`, `statusSystemSignalsSubtitle`, `settingsWidgetRefreshLabel`, or `settingsWidgetMainWindowLabel` in the same step. First run the source gates. If no source code references remain after tests are updated, delete those string helpers and resource keys in a separate commit.

- [ ] **Step 7: Update localization tests**

In `LocalizationGateTests.swift`, remove assertions that require the deleted UI references in `DashboardView.swift`. Keep catalog-entry checks until the resource cleanup step removes keys.

Example replacement:

```swift
#expect(!dashboard.contains("PulseDockAppStrings.statusSystemSignalsTitle"))
#expect(dashboard.contains("PulseDockAppStrings.statusRealtimeSignalsTitle"))
#expect(dashboard.contains("PulseDockAppStrings.metricKernelVersion"))
```

- [ ] **Step 8: Run tests and localization audit**

Run:

```bash
swift test --filter RedundancyOptimizationGateTests/duplicateUiPanelsAreRemovedFromDashboardSource
swift test --filter LocalizationGateTests
scripts/audit-localization.sh
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources/PulseDockApp.xcstrings Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift Tests/SharedMetricsTests/LocalizationGateTests.swift
git commit -m "refactor: reduce dashboard information redundancy"
```

---

### Task 5: Trim Widget Compact Payload

**Files:**
- Modify: `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift`
- Modify: `Sources/SharedMetrics/SystemSampler.swift`
- Modify: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`
- Test: `Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`

- [ ] **Step 1: Confirm compact snapshot gate fails**

Run:

```bash
swift test --filter RedundancyOptimizationGateTests/widgetCompactSnapshotTrimsCurrentDeadFields
```

Expected: FAIL because the current projection retains the 20 dead fields.

- [ ] **Step 2: Remove dead field arguments from `widgetCompactSnapshot()`**

In `MetricSnapshot+WidgetCompact.swift`, delete these arguments from the `MetricSnapshot(` initializer so defaults apply:

```swift
cpuCoreUsages: cpuCoreUsages,
physicalCoreCount: physicalCoreCount,
memoryFreeBytes: memoryFreeBytes,
memoryWiredBytes: memoryWiredBytes,
memoryCompressedBytes: memoryCompressedBytes,
memoryCachedBytes: memoryCachedBytes,
memorySwapUsedBytes: memorySwapUsedBytes,
memorySwapTotalBytes: memorySwapTotalBytes,
memorySwapAvailableBytes: memorySwapAvailableBytes,
hasMemoryCompositionReport: hasMemoryCompositionReport,
loadAverage5: loadAverage5,
loadAverage15: loadAverage15,
batteryTimeRemainingMinutes: batteryTimeRemainingMinutes,
batteryCycleCount: batteryCycleCount,
batteryHealth: batteryHealth,
batteryCurrentCapacity: batteryCurrentCapacity,
batteryMaxCapacity: batteryMaxCapacity,
batteryDesignCapacity: batteryDesignCapacity,
batteryVoltageMillivolts: batteryVoltageMillivolts,
batteryAmperageMilliamps: batteryAmperageMilliamps,
```

Keep these widget-visible fields:

```swift
cpuUsage: cpuUsage,
hasCPUUsageReport: hasCPUUsageReport,
logicalCoreCount: logicalCoreCount,
activeProcessorCount: activeProcessorCount,
memoryUsedBytes: memoryUsedBytes,
memoryTotalBytes: memoryTotalBytes,
loadAverage: loadAverage,
hasLoadAverageReport: hasLoadAverageReport,
thermalState: thermalState,
batteryPercent: batteryPercent,
batteryIsCharging: batteryIsCharging,
batteryPowerSource: batteryPowerSource,
networkPathStatus: networkPathStatus,
networkPathIsExpensive: networkPathIsExpensive,
networkPathIsConstrained: networkPathIsConstrained,
hasNetworkPathCostReport: hasNetworkPathCostReport,
networkPathSupportsDNS: networkPathSupportsDNS,
networkPathSupportsIPv4: networkPathSupportsIPv4,
networkPathSupportsIPv6: networkPathSupportsIPv6,
hasNetworkPathSupportReport: hasNetworkPathSupportReport,
networkPathInterfaceKinds: networkPathInterfaceKinds,
diskFreeBytes: diskFreeBytes,
diskTotalBytes: diskTotalBytes,
uptimeSeconds: uptimeSeconds,
hasUptimeReport: hasUptimeReport,
osVersion: osVersion,
kernelRelease: kernelRelease,
timestamp: timestamp,
schemaVersion: schemaVersion
```

- [ ] **Step 3: Align fallback sampling with shared snapshot projection**

In `SystemSampler.sampleWidgetCompact(now:)`, wrap the returned snapshot:

```swift
return MetricSnapshot(
    ...
    timestamp: now
).widgetCompactSnapshot()
```

Do not call the full `sample()` method here; `sampleWidgetCompact` should keep its lower-cost sampling path.

- [ ] **Step 4: Update existing compact tests**

In `LogicConsistencyGateTests.swift`, change expectations that currently require preserved dead fields. Replace:

```swift
#expect(compact.memoryFreeBytes == 2_000)
#expect(compact.batteryCycleCount == 12)
#expect(compact.batteryHealth == "Good")
#expect(compact.batteryVoltageMillivolts == 12_000)
#expect(compact.batteryAmperageMilliamps == -300)
```

with:

```swift
#expect(compact.memoryFreeBytes == 0)
#expect(compact.batteryCycleCount == nil)
#expect(compact.batteryHealth == nil)
#expect(compact.batteryVoltageMillivolts == nil)
#expect(compact.batteryAmperageMilliamps == nil)
```

Keep assertions for widget-visible fields such as `batteryPercent`, `batteryPowerSource`, `logicalCoreCount`, `activeProcessorCount`, `loadAverage`, `networkPathStatus`, `diskFreeBytes`, `uptimeSeconds`, `osVersion`, and `kernelRelease`.

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter RedundancyOptimizationGateTests/widgetCompactSnapshotTrimsCurrentDeadFields
swift test --filter LogicConsistencyGateTests
swift build --target PulseDockWidget
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift Sources/SharedMetrics/SystemSampler.swift Tests/SharedMetricsTests/LogicConsistencyGateTests.swift Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift
git commit -m "perf: trim compact widget snapshot payload"
```

---

### Task 6: Clean Up Remaining Low-Risk Duplication

**Files:**
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: `Sources/PulseDockWidget/PulseDockWidgetStrings.swift`
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Test: `Tests/SharedMetricsTests/LocalizationGateTests.swift`

- [ ] **Step 1: Centralize `notReported` string aliases without changing localization keys**

Change app and widget helpers to delegate to shared text:

```swift
static var notReported: String {
    SharedMetricStrings.notReported
}
```

Keep existing `app.not_reported` and `widget.not_reported` resource keys during this step to avoid mixing localization cleanup with behavior cleanup. Delete unused keys only after `scripts/audit-localization.sh` reports no live references.

- [ ] **Step 2: Extract status dot rendering inside each target**

In `WidgetPanelView.swift`, add:

```swift
private struct PopoverStatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }
}
```

Replace popover inline `Circle().fill(...)` calls with `PopoverStatusDot(color: ...)`.

In `SystemDashboardWidget.swift`, add:

```swift
private struct WidgetStatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .accessibilityHidden(true)
    }
}
```

Replace widget inline status circles with `WidgetStatusDot(color: ...)`.

- [ ] **Step 3: Keep row/card components separate**

Do not merge `PopoverMetricRow`, `WidgetRow`, `PopoverSmallStat`, `MiniStatus`, and `StatTile` in this pass. Their layouts differ enough that a shared SwiftUI view would add parameters without reducing meaningful complexity. The progress math and dot rendering are already centralized by earlier steps.

- [ ] **Step 4: Normalize trend calls**

In `HistoryAlertsPage`, replace:

```swift
let networkTrend = networkTrendValues(from: history, keyPath: \.networkBytesPerSecond)
```

with:

```swift
let networkTrend = networkTrendValues(from: history)
```

Keep explicit key paths only for download and upload trends.

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter MetricFormattingTests
swift test --filter LocalizationGateTests
scripts/audit-localization.sh
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockWidget/PulseDockWidgetStrings.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Sources/PulseDockApp/DashboardView.swift Tests/SharedMetricsTests/MetricFormattingTests.swift Tests/SharedMetricsTests/LocalizationGateTests.swift
git commit -m "refactor: clean low-risk presentation duplication"
```

---

### Task 7: Consolidate Duplicate Design Assets

**Files:**
- Modify: `README.md`
- Modify: `design/gptimage2-system-monitor/README.md`
- Delete: `designs/macos-monitor-ui/`

- [ ] **Step 1: Verify both design directories are tracked**

Run:

```bash
git ls-files design/ designs/
```

Expected: output includes files from both `design/gptimage2-system-monitor/` and `designs/macos-monitor-ui/`.

- [ ] **Step 2: Mark the canonical design directory**

In `design/gptimage2-system-monitor/README.md`, add this paragraph near the top:

```markdown
This directory is the canonical tracked design reference for Pulse Dock. Earlier overlapping concept assets from `designs/macos-monitor-ui/` were removed after the redundancy review to avoid maintaining two visual source directories for the same product.
```

- [ ] **Step 3: Add root README reference**

In `README.md`, add a short design-assets reference in the project documentation section:

```markdown
Design reference assets live in `design/gptimage2-system-monitor/`.
```

- [ ] **Step 4: Delete the duplicate directory**

Run:

```bash
git rm -r designs/macos-monitor-ui
```

Expected: Git stages deletion of the duplicate design asset set.

- [ ] **Step 5: Commit**

```bash
git add README.md design/gptimage2-system-monitor/README.md
git commit -m "chore: consolidate design reference assets"
```

---

### Task 8: Full Verification And Final Review

**Files:**
- No source changes unless verification exposes a regression.

- [ ] **Step 1: Run SwiftPM tests**

```bash
swift test
```

Expected: PASS.

- [ ] **Step 2: Run SwiftPM builds**

```bash
swift build
swift build --target PulseDockWidget
```

Expected: PASS.

- [ ] **Step 3: Run localization and public-page gates**

```bash
scripts/audit-localization.sh
scripts/validate-public-pages.sh
```

Expected: PASS.

- [ ] **Step 4: Regenerate and build Xcode project**

Run the existing project generation flow:

```bash
ruby scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug build
```

Expected: PASS. If the scheme name differs, run `xcodebuild -list -project PulseDock.xcodeproj` and use the app scheme printed by Xcode.

- [ ] **Step 5: Manual UI QA**

Launch the app and inspect:

```bash
swift run PulseDockApp
```

Verify:

- Dashboard top bar still shows sample time.
- Sidebar no longer repeats sample time.
- Sensors has one live/system signal panel and still shows kernel version.
- History has trends and threshold controls but no duplicated local-rule table.
- Settings widget preview no longer repeats refresh/main-window values already shown in the refresh panel.
- Thermal `hot` and network `unknown` colors match dashboard, popover, and widget.
- Widget Small/Medium/Large still render with live or fallback snapshots.

- [ ] **Step 6: Commit verification-only fixes**

If verification required code or test fixes:

```bash
git add <changed-files>
git commit -m "fix: resolve redundancy optimization regressions"
```

If verification required no changes, do not create an empty commit.

---

## 5. Execution Order

Run tasks in this exact order:

1. Task 1: docs and gates
2. Task 2: shared semantic/progress contracts
3. Task 3: shared accent colors
4. Task 4: visible dashboard redundancy
5. Task 5: compact widget payload
6. Task 6: low-risk duplication cleanup
7. Task 7: design asset consolidation
8. Task 8: full verification

Do not parallelize Tasks 2 and 3 because both touch app/widget color and tone call sites. Task 7 can run in parallel only after Task 1 lands, because it is isolated to docs/assets.

---

## 6. Risk Register

| Risk | Mitigation |
| --- | --- |
| Changing thermal `hot` from dashboard warning to critical may feel visually stronger. | This is intentional for cross-surface consistency. Manual QA must verify red is acceptable for `hot`. |
| Moving color components into SharedMetrics could accidentally introduce SwiftUI into the shared library. | `MetricAccentComponents.swift` imports only Foundation and exposes numeric values. SwiftUI conversion stays in app/widget files. |
| Removing Sensors System Signals table could drop kernel visibility. | Add a kernel card to the remaining signal grid before deleting the table. |
| Trimming compact fields could break widget derived text. | The gate test preserves all fields currently read by `SystemDashboardWidget.swift`; run widget build after trimming. |
| Source-level tests may be brittle after UI refactors. | Keep assertions focused on contracts and removed duplicates, not exact line numbers. |
| Design asset deletion is irreversible in working tree. | Use `git rm` after confirming files are tracked; history still preserves removed assets. |

---

## 7. Out Of Scope

- Removing Overview trends. They intentionally support first-screen scanning.
- Removing sidebar CPU/Mem/Disk rows. They intentionally provide cross-page status.
- Removing Undo/Redo menu items. They are conventional macOS menu entries.
- Merging popover/widget row components into one parameter-heavy shared SwiftUI view.
- Adding new animation or live sampling UX changes. The user explicitly deferred the real-time sampling question.

---

## 8. Final Commands

Run before claiming completion:

```bash
swift test
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
scripts/validate-public-pages.sh
ruby scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug build
```

Expected final state:

```bash
git status -sb
```

shows only intentional committed branch state and no unstaged implementation changes.
