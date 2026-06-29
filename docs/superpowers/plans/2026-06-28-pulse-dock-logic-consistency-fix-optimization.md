# Pulse Dock Logic Consistency Fix And Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix verified copy, data-contract, widget freshness, power-state, and documentation consistency problems found in the 2026-06-28 logic review while preserving App Store-safe public API behavior.

**Architecture:** Treat `SharedMetrics` as the source of truth for metric semantics, formatting, snapshot projection, and timeline policy. Keep app/widget UI copy localized in their own string layers, but make ambiguous status concepts explicit through small shared model helpers and source-level tests. The plan corrects the review report before code changes so execution does not chase verified false positives.

**Tech Stack:** Swift 6, SwiftUI on macOS 14+, WidgetKit, Foundation `UserDefaults`, Swift Testing source-level gates, existing SwiftPM plus generated Xcode project workflow.

---

## 0. Verified Scope And Corrections

The implementation must use the current working tree as source of truth, not the raw review report wording.

| Review Item | Verification Result | Execution Decision |
| --- | --- | --- |
| Final report count | The final report lists 14 medium rows and 37 low rows, for 51 visible rows, while the summary says 45. | Correct the report statistics and explain duplicate/merged rows. |
| LC-2 / L1-2 | Normal desktop Mac path reports `AC Power` and displays `Power Adapter`; it does not display `No Battery`. The real issue is the near-unreachable `powerSourceNoBattery` branch. | Do not implement a fake "No Battery vs Reported" bug. Replace the unreachable branch with explicit external/unknown power-source semantics. |
| D1 | Current `docs/data-capability-audit.md` line 27 does not list `widgets` for GPU/display surfaces. | Mark D1 as a false positive in the final review doc; do not change product code for D1. |
| L4-12 | Menu bar popover geometry already clamps below `minimumHeight` when needed and puts the body in `ScrollView`. | Downgrade to a regression test/documentation note, not a product fix unless a reproducible clipping case appears. |
| LC-6 / L2-3 / L2-4 | `fair`, `serious`, `requires_connection`, and `requires connection` are legacy/compatibility aliases. | Keep compatibility via canonical enums; remove duplicated string switches rather than deleting support. |

---

## 1. Acceptance Criteria

The work is complete only when all of these are true:

- `docs/review/top/logic-consistency-final.md` reflects the corrected item count and the verified false positives.
- Settings no longer shows a hardcoded `5m` label next to `System Scheduled`.
- Widget freshness constants are centralized and no threshold equality causes a normally refreshed widget to become stale exactly at the fallback boundary.
- App-triggered widget reload cadence and WidgetKit requested timeline cadence are documented as separate mechanisms or intentionally aligned through one shared policy.
- Low battery while charging does not show a red/critical power tone.
- Unknown external power-source values do not leak untranslated raw strings into app or widget UI.
- Power page text avoids duplicated `Power / Power Adapter / Power Adapter` rows.
- Small/Medium/Large widgets use one power-source vocabulary.
- Sensors and History use one local-rule vocabulary for the same threshold table.
- Processes page no longer presents truncated display rows as a system metric.
- Widget compact snapshots and widget fallback snapshots use the same projection contract for visible fields.
- `MetricSnapshot` init and decode fallback strategies are documented and tested, especially network direction byte counters.
- Network total/in/out display units are consistent.
- Shared snapshot save failures retry on the next eligible tick instead of suppressing writes for 60 seconds.
- Shared snapshot schema version is validated before widget use.
- Low-risk copy drift, string aliases, and docs drift are either fixed or explicitly documented as intentional.
- `swift test`, `swift build`, `swift build --target PulseDockWidget`, `scripts/audit-localization.sh`, `scripts/validate-public-pages.sh`, and generated Xcode project build pass.

---

## 2. File Structure

### Create

- `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`
  - Source-level gates for verified review findings and doc-correction regressions.

- `Sources/SharedMetrics/WidgetTimelinePolicy.swift`
  - Shared constants for WidgetKit requested timeline cadence, app reload throttle, shared snapshot max age, and freshness thresholds.

- `Sources/SharedMetrics/MetricStateContracts.swift`
  - Canonical thermal and network-path status parsing, keeping legacy aliases.

### Modify

- `Sources/SharedMetrics/MetricSnapshot.swift`
  - Power text/tone semantics, decoded report flags, network unit properties, schema handling, and canonical state helpers.

- `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift`
  - Widget compact projection field set.

- `Sources/SharedMetrics/MetricFormatting.swift`
  - Locale-aware numeric formatting and consistent network rate helpers.

- `Sources/SharedMetrics/MetricScales.swift`
  - Named network rate reference instead of a hidden 10GbE hard cap.

- `Sources/SharedMetrics/SharedMetricStrings.swift`
  - New localized shared strings for explicit external power and status contract output.

- `Sources/SharedMetrics/SharedSnapshotStore.swift`
  - Schema validation and clearer load/save behavior.

- `Sources/PulseDockApp/MetricsStore.swift`
  - Shared snapshot write retry, widget reload cadence policy, and history projection call-site cleanup.

- `Sources/PulseDockApp/DashboardView.swift`
  - Settings refresh copy, Sparkline sample-window reporting, Power page wording, Processes page labels, Sensors/History threshold-table copy.

- `Sources/PulseDockApp/PulseDockAppStrings.swift`
  - App copy vocabulary updates.

- `Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings`
- `Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings`
- `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`
  - Localized app string updates.

- `Sources/PulseDockWidget/SystemDashboardWidget.swift`
  - Timeline policy usage, power-source vocabulary, preview-data flag, widget supported text.

- `Sources/PulseDockWidget/WidgetVisualTokens.swift`
  - Freshness thresholds from shared policy.

- `Sources/PulseDockWidget/PulseDockWidgetStrings.swift`
- `Sources/PulseDockWidget/Resources/en.lproj/PulseDockWidget.strings`
- `Sources/PulseDockWidget/Resources/zh-Hans.lproj/PulseDockWidget.strings`
- `Sources/PulseDockWidget/Resources/PulseDockWidget.xcstrings`
  - Widget copy vocabulary updates.

- `Resources/WidgetInfo.plist`
  - Widget bundle display name decision.

- `docs/data-capability-audit.md`
  - Storage widget surfaces and shared write/reload wording.

- `docs/review/top/logic-consistency-final.md`
  - Corrected counts and verified false-positive notes.

### Do Not Modify

- Entitlements, app group IDs, privacy manifest purpose strings, screenshots, and App Store metadata unless a later task explicitly changes user-facing release copy.

---

## 3. Global Verification Commands

Run after every task that touches Swift source:

```bash
swift test --filter LogicConsistencyGateTests
swift test
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
```

Run after documentation or public-page changes:

```bash
scripts/validate-public-pages.sh
```

Run after WidgetKit target, Xcode project, plist, or target membership changes:

```bash
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected:

```text
Test run passed
Build complete
Localization audit passed
Public page validation passed
** BUILD SUCCEEDED **
```

---

## 4. Task Dependency Map

| Task | Can Run In Parallel With | Must Not Run In Parallel With |
| --- | --- | --- |
| Task 1 review-doc correction | Tasks 2, 3, 8, 9 | None |
| Task 2 widget timeline policy | Tasks 3, 6, 8 | Task 10 verification |
| Task 3 power semantics | Task 8 docs after string keys are known | Tasks 4, 5, 7 because all touch `MetricSnapshot.swift` |
| Task 4 copy semantics | Task 2 | Task 7 if both edit string files heavily |
| Task 5 snapshot projection/report flags | Task 8 docs | Tasks 3, 6, 7 because all touch `MetricSnapshot.swift` or `SharedSnapshotStore.swift` |
| Task 6 network units/scales | Task 2 | Tasks 3, 5, 7 because all touch `MetricSnapshot.swift` |
| Task 7 canonical state contracts | Task 8 docs | Tasks 3, 5, 6 because all touch state parsing |
| Task 8 low-risk copy/docs drift | Task 2 after string keys stabilize | Task 4 if both edit same localization files |
| Task 9 widget preview semantics | Task 6 | Task 2 if both edit `SystemDashboardWidget.swift` |
| Task 10 final verification | None | All implementation tasks |

---

## Task 1: Correct Review Report Baseline

**Files:**
- Create: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`
- Modify: `docs/review/top/logic-consistency-final.md`

- [ ] **Step 1: Write failing tests for corrected review scope**

Create `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`:

```swift
import Foundation
import Testing
@testable import SharedMetrics

private func fixture(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

@Test func logicReviewFinalReportUsesVerifiedCountsAndCorrections() throws {
    let report = try fixture("docs/review/top/logic-consistency-final.md")

    #expect(report.contains("| 原始发现 | 51 条 |"))
    #expect(report.contains("| 去重后有效发现 | 51 条（L-中:14 / L-低:37 / L-高:0） |"))
    #expect(report.contains("LC-2 部分误报"))
    #expect(report.contains("D1 不属实"))
    #expect(report.contains("L4-12 已由几何压缩与滚动缓解"))
}

@Test func dataCapabilityAuditDoesNotClaimGpuDisplayWidgets() throws {
    let audit = try fixture("docs/data-capability-audit.md")
    let gpuLine = audit
        .split(separator: "\n")
        .first { $0.contains("| GPU and display |") }
        .map(String.init) ?? ""

    #expect(!gpuLine.localizedCaseInsensitiveContains("widgets"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because the test file exists but the report still says 45/31 and does not contain the correction notes.

- [ ] **Step 3: Update final report summary and correction table**

In `docs/review/top/logic-consistency-final.md`, replace the overview values:

```markdown
| 原始发现 | 51 条 |
| 去重后有效发现 | 51 条（L-中:14 / L-低:37 / L-高:0） |
```

Add this subsection after `### 2.2 真矛盾 vs 有意区分裁定`:

```markdown
### 2.3 Codex 复核校正（2026-06-28）

| 发现 | 复核结论 | 处置 |
|------|----------|------|
| LC-2 "No Battery" vs "Reported" | **LC-2 部分误报**：正常桌面 Mac 路径会显示 "Power Adapter"，不是 "No Battery"。真实问题是 `powerSourceNoBattery` 分支近乎不可达。 | 保留 Power 语义修复任务，但不按 "No Battery vs Reported" 用户可见 bug 执行。 |
| D1 GPU/display widgets | **D1 不属实**：当前 `docs/data-capability-audit.md` 的 GPU/display Surfaces 未包含 widgets。 | 从文档漂移问题中删除或标记为 false positive。 |
| L4-12 menu bar popover minimumHeight | **L4-12 已由几何压缩与滚动缓解**：当前 geometry 在可用高度不足时允许低于 `minimumHeight`，内容主体在 `ScrollView` 内。 | 降级为回归测试，不作为明确产品 bug。 |
| LC-6/L2-3/L2-4 legacy aliases | 属实但属于兼容分支。 | 通过 canonical enum 收敛重复 switch，保留旧值解析能力。 |
```

Move D1 from the active low-risk table into a short `False Positives` note:

```markdown
### 已复核误报

| # | 原报告项 | 复核结论 |
|---|---------|----------|
| D1 | GPU/display Surfaces 包含 widgets | 当前文档未包含 widgets，代码也未显示 GPU/display widget 数据。 |
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Tests/SharedMetricsTests/LogicConsistencyGateTests.swift docs/review/top/logic-consistency-final.md
git commit -m "docs: correct logic review baseline"
```

---

## Task 2: Centralize Widget Timeline And Freshness Policy

**Files:**
- Create: `Sources/SharedMetrics/WidgetTimelinePolicy.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Modify: `Sources/PulseDockWidget/WidgetVisualTokens.swift`
- Modify: `Sources/PulseDockApp/MetricsStore.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: localized app string resources
- Test: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`

- [ ] **Step 1: Add failing timeline policy tests**

Append to `LogicConsistencyGateTests.swift`:

```swift
@Test func widgetRefreshCopyDoesNotExposeGuaranteedFiveMinuteLabel() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let strings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")

    #expect(!dashboard.contains("control: \"5m\""))
    #expect(dashboard.contains("control: PulseDockAppStrings.settingsWidgetRefreshValue"))
    #expect(strings.contains("app.settings.widget.refresh.value"))
    #expect(strings.contains("System Scheduled"))
}

@Test func widgetTimelinePolicyUsesNonEqualFreshnessThresholds() {
    #expect(WidgetTimelinePolicy.sharedSnapshotMaxAge < WidgetTimelinePolicy.staleThreshold)
    #expect(WidgetTimelinePolicy.requestedRefreshInterval < WidgetTimelinePolicy.agingThreshold)
    #expect(WidgetTimelinePolicy.appReloadThrottle == WidgetTimelinePolicy.requestedRefreshInterval)
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because `WidgetTimelinePolicy` does not exist and `DashboardView.swift` still contains `control: "5m"`.

- [ ] **Step 3: Add shared policy**

Create `Sources/SharedMetrics/WidgetTimelinePolicy.swift`:

```swift
import Foundation

public enum WidgetTimelinePolicy {
    public static let requestedRefreshInterval: TimeInterval = 300
    public static let appReloadThrottle: TimeInterval = requestedRefreshInterval
    public static let sharedSnapshotMaxAge: TimeInterval = 540
    public static let agingThreshold: TimeInterval = 360
    public static let staleThreshold: TimeInterval = 600
}
```

The chosen values mean:

- app and widget both request updates at a 5-minute cadence;
- a shared app snapshot is rejected before the stale red threshold;
- an on-time 5-minute refresh remains fresh instead of immediately aging.

- [ ] **Step 4: Use policy in widget provider and freshness resolver**

In `Sources/PulseDockWidget/SystemDashboardWidget.swift`, replace local constants:

```swift
private static let sharedSnapshotMaxAge: TimeInterval = WidgetTimelinePolicy.sharedSnapshotMaxAge
```

Replace `getTimeline` refresh calculation:

```swift
let nextRefresh = now.addingTimeInterval(WidgetTimelinePolicy.requestedRefreshInterval)
timelineCompletion(Timeline(entries: [entry], policy: .after(nextRefresh)))
```

In `Sources/PulseDockWidget/WidgetVisualTokens.swift`, replace hardcoded thresholds:

```swift
static func resolve(age: TimeInterval?) -> WidgetFreshnessTone {
    guard let age, age >= 0 else { return .fresh }
    if age >= WidgetTimelinePolicy.staleThreshold { return .stale }
    if age >= WidgetTimelinePolicy.agingThreshold { return .aging }
    return .fresh
}
```

- [ ] **Step 5: Use policy in app reload throttle**

In `Sources/PulseDockApp/MetricsStore.swift`, replace:

```swift
private let widgetReloadInterval: TimeInterval = 60
```

with:

```swift
private let widgetReloadInterval: TimeInterval = WidgetTimelinePolicy.appReloadThrottle
```

- [ ] **Step 6: Replace hardcoded settings copy**

In `Sources/PulseDockApp/DashboardView.swift`, replace:

```swift
SettingReadOnlyRow(title: PulseDockAppStrings.settingsWidgetRefreshTitle, detail: PulseDockAppStrings.settingsWidgetRefreshDetail, control: "5m")
```

with:

```swift
SettingReadOnlyRow(
    title: PulseDockAppStrings.settingsWidgetRefreshTitle,
    detail: PulseDockAppStrings.settingsWidgetRefreshDetail,
    control: PulseDockAppStrings.settingsWidgetRefreshValue
)
```

In `PulseDockAppStrings.swift`, keep `settingsWidgetRefreshValue` as `System Scheduled`, and update the detail default:

```swift
static var settingsWidgetRefreshDetail: String {
    localized("app.settings.widget_refresh.detail", defaultValue: "Requested about every 5 minutes by the system timeline")
}
```

Update `en.lproj`, `zh-Hans.lproj`, and `.xcstrings` with equivalent localized values.

- [ ] **Step 7: Run verification**

Run:

```bash
swift test --filter LogicConsistencyGateTests
swift test
swift build --target PulseDockWidget
scripts/audit-localization.sh
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/SharedMetrics/WidgetTimelinePolicy.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Sources/PulseDockWidget/WidgetVisualTokens.swift Sources/PulseDockApp/MetricsStore.swift Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources Tests/SharedMetricsTests/LogicConsistencyGateTests.swift
git commit -m "fix: centralize widget timeline policy"
```

---

## Task 3: Fix Power Status Semantics Across App And Widgets

**Files:**
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift`
- Modify: `Sources/SharedMetrics/SharedMetricStrings.swift`
- Modify: shared localized string resources
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: app localized string resources
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Modify: `Sources/PulseDockWidget/PulseDockWidgetStrings.swift`
- Modify: widget localized string resources
- Test: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`

- [ ] **Step 1: Add failing power semantics tests**

Append:

```swift
@Test func chargingLowBatteryDoesNotRenderCriticalPowerTone() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0,
        hasCPUUsageReport: false,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        thermalState: "Nominal",
        batteryPercent: 0.19,
        batteryIsCharging: true,
        batteryPowerSource: "AC Power"
    )

    #expect(snapshot.powerStatusTone == .normal)
}

@Test func unknownPowerSourceUsesLocalizedExternalPowerText() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0,
        hasCPUUsageReport: false,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "Wireless Power"
    )

    #expect(snapshot.powerSourceText == SharedMetricStrings.powerSourceExternal)
    #expect(snapshot.powerStatusText == SharedMetricStrings.powerSourceExternal)
    #expect(snapshot.hasPowerStatusReport)
}

@Test func powerSourceNoBatteryBranchIsRemovedFromRuntimePath() throws {
    let snapshot = try fixture("Sources/SharedMetrics/MetricSnapshot.swift")

    #expect(!snapshot.contains("powerSourceNoBattery"))
    #expect(snapshot.contains("powerSourceExternal"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because charging low battery is currently warning/critical and `powerSourceNoBattery` still exists.

- [ ] **Step 3: Replace unreachable no-battery string**

In `Sources/SharedMetrics/SharedMetricStrings.swift`, replace:

```swift
static var powerSourceNoBattery: String {
    localized("shared_metrics.power.source.no_battery", defaultValue: "No Battery")
}
```

with:

```swift
public static var powerSourceExternal: String {
    localized("shared_metrics.power.source.external", defaultValue: "External Power")
}
```

Update shared `en.lproj`, `zh-Hans.lproj`, and `.xcstrings`:

```text
"shared_metrics.power.source.external" = "External Power";
```

```text
"shared_metrics.power.source.external" = "外部电源";
```

- [ ] **Step 4: Fix `powerSourceText` and `powerStatusTone`**

In `MetricSnapshot.swift`, replace `powerSourceText` with:

```swift
public var powerSourceText: String {
    switch batteryPowerSource?.lowercased() {
    case "ac power":
        return batteryIsCharging ? SharedMetricStrings.powerSourceAdapterCharging : SharedMetricStrings.powerSourceAdapter
    case "battery power":
        return SharedMetricStrings.powerSourceBattery
    case "ups power":
        return SharedMetricStrings.powerSourceUPS
    case .some:
        return SharedMetricStrings.powerSourceExternal
    default:
        return batteryPercent == nil
            ? SharedMetricStrings.notReported
            : (batteryIsCharging ? SharedMetricStrings.powerSourceAdapterCharging : SharedMetricStrings.powerSourceStateNotReported)
    }
}
```

Replace the start of `powerStatusTone` with:

```swift
public var powerStatusTone: MetricStatusTone {
    if let batteryPercent {
        if batteryIsCharging {
            return .normal
        }

        if batteryPercent < 0.2 {
            return .critical
        }

        if batteryPercent < 0.5 {
            return .warning
        }

        switch batteryPowerSource?.lowercased() {
        case "ac power", "battery power":
            return .normal
        case "ups power":
            return .warning
        case .some:
            return .neutral
        default:
            return .normal
        }
    }

    switch batteryPowerSource?.lowercased() {
    case "ac power":
        return .normal
    case "battery power", "ups power":
        return .warning
    case .some:
        return .neutral
    default:
        return .neutral
    }
}
```

- [ ] **Step 5: Reduce repeated Power page copy**

In `DashboardView.swift`, remove the duplicate first row from the battery information table:

```swift
rows: [
    [PulseDockAppStrings.powerSourceLabel, snapshot.powerSourceText, PulseDockAppStrings.sourcePowerStatus],
    [PulseDockAppStrings.batteryRemainingTimeLabel, snapshot.batteryTimeRemainingText, PulseDockAppStrings.sourceSystemEstimate],
    [PulseDockAppStrings.batteryCurrentCapacityLabel, snapshot.batteryCurrentCapacityText, PulseDockAppStrings.sourcePowerStatus],
    [PulseDockAppStrings.batteryMaxCapacityLabel, snapshot.batteryMaxCapacityText, PulseDockAppStrings.sourcePowerStatus],
    [PulseDockAppStrings.batteryDesignCapacityLabel, snapshot.batteryDesignCapacityText, PulseDockAppStrings.sourceBatterySpecifications],
    [PulseDockAppStrings.batteryCycleCountLabel, snapshot.batteryCycleText, PulseDockAppStrings.sourceBatteryHealth],
    [PulseDockAppStrings.batteryHealthLabel, snapshot.batteryHealthText, PulseDockAppStrings.sourceBatteryHealth],
    [PulseDockAppStrings.batteryVoltageLabel, snapshot.batteryVoltageText, PulseDockAppStrings.sourcePowerStatus],
    [PulseDockAppStrings.batteryCurrentLabel, snapshot.batteryAmperageText, PulseDockAppStrings.sourcePowerStatus]
]
```

Keep `powerGauge` and `powerDetails` as the primary current state.

- [ ] **Step 6: Align widget power vocabulary**

In `SystemDashboardWidget.swift`, update `compactPowerStatusText`:

```swift
private func compactPowerStatusText(_ snapshot: MetricSnapshot) -> String {
    if let batteryPercent = snapshot.batteryPercent {
        return MetricFormatting.percentage(batteryPercent)
    }

    switch snapshot.batteryPowerSource?.lowercased() {
    case "ac power":
        return snapshot.batteryIsCharging ? PulseDockWidgetStrings.compactPowerCharging : PulseDockWidgetStrings.compactPowerAdapter
    case "battery power":
        return PulseDockWidgetStrings.compactPowerBattery
    case "ups power":
        return PulseDockWidgetStrings.powerUPS
    case .some:
        return PulseDockWidgetStrings.compactPowerExternal
    default:
        return PulseDockWidgetStrings.notReported
    }
}
```

Set `compactPowerExternal` default to `External Power` in `PulseDockWidgetStrings.swift` and widget localization resources.

- [ ] **Step 7: Run verification**

Run:

```bash
swift test --filter LogicConsistencyGateTests
swift test
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/SharedMetrics/MetricSnapshot.swift Sources/SharedMetrics/SharedMetricStrings.swift Sources/SharedMetrics/Resources Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources Sources/PulseDockWidget/SystemDashboardWidget.swift Sources/PulseDockWidget/PulseDockWidgetStrings.swift Sources/PulseDockWidget/Resources Tests/SharedMetricsTests/LogicConsistencyGateTests.swift
git commit -m "fix: clarify power status semantics"
```

---

## Task 4: Unify Status Rules, Processes Summary, And Page Copy

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: app localized resources
- Test: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`

- [ ] **Step 1: Add failing copy consistency tests**

Append:

```swift
@Test func statusRuleTablesUseOneVocabulary() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let strings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")

    #expect(dashboard.contains("PulseDockAppStrings.localRuleTableTitle"))
    #expect(dashboard.contains("PulseDockAppStrings.localRuleTableSubtitle"))
    #expect(dashboard.contains("PulseDockAppStrings.statusWarning"))
    #expect(!dashboard.contains("PulseDockAppStrings.statusTriggered"))
    #expect(strings.contains("app.dashboard.local_rules.title"))
}

@Test func processesSummaryLabelsDisplayedRowsExplicitly() throws {
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")

    #expect(!appStrings.contains("processesListItemsTitle"))
    #expect(appStrings.contains("processesDisplayedAppsTitle"))
    #expect(appStrings.contains("Displayed Apps"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because the old names and `statusTriggered` are still used.

- [ ] **Step 3: Add unified local-rule strings**

In `PulseDockAppStrings.swift`, add:

```swift
static var localRuleTableTitle: String {
    localized("app.dashboard.local_rules.title", defaultValue: "Local Rules")
}

static var localRuleTableSubtitle: String {
    localized("app.dashboard.local_rules.subtitle", defaultValue: "Current sample evaluated against local thresholds")
}

static var statusPerformanceLimitTitle: String {
    localized("app.dashboard.status.performance_limit.title", defaultValue: "Performance Limit")
}
```

Replace:

```swift
static var processesListItemsTitle: String {
    localized("app.dashboard.processes.list_items", defaultValue: "List Items")
}
```

with:

```swift
static var processesDisplayedAppsTitle: String {
    localized("app.dashboard.processes.displayed_apps", defaultValue: "Displayed Apps")
}
```

Update `en.lproj`, `zh-Hans.lproj`, and `.xcstrings`.

- [ ] **Step 4: Use unified strings in dashboard**

In `SensorsPage`, replace:

```swift
DashboardPanel(title: PulseDockAppStrings.statusRulesTitle, subtitle: PulseDockAppStrings.statusRulesSubtitle, icon: "checkmark.shield")
```

with:

```swift
DashboardPanel(title: PulseDockAppStrings.localRuleTableTitle, subtitle: PulseDockAppStrings.localRuleTableSubtitle, icon: "checkmark.shield")
```

In `HistoryPage`, replace:

```swift
DashboardPanel(title: PulseDockAppStrings.historyStatusEvaluationTitle, subtitle: PulseDockAppStrings.historyStatusEvaluationSubtitle, icon: "checkmark.shield")
```

with:

```swift
DashboardPanel(title: PulseDockAppStrings.localRuleTableTitle, subtitle: PulseDockAppStrings.localRuleTableSubtitle, icon: "checkmark.shield")
```

In History rule rows, replace `PulseDockAppStrings.statusTriggered` with `PulseDockAppStrings.statusWarning`.

In `thermalPanel`, replace `PulseDockAppStrings.statusSystemStatusTitle` for the thermal limit row with:

```swift
PulseDockAppStrings.statusPerformanceLimitTitle
```

In `ProcessesPage`, replace:

```swift
SummaryCard(title: PulseDockAppStrings.processesListItemsTitle, value: snapshot.runningAppListCountText, icon: "list.bullet.rectangle", tint: DashboardColor.green)
```

with:

```swift
SummaryCard(title: PulseDockAppStrings.processesDisplayedAppsTitle, value: snapshot.runningAppListCountText, icon: "list.bullet.rectangle", tint: DashboardColor.green)
```

- [ ] **Step 5: Run verification**

Run:

```bash
swift test --filter LogicConsistencyGateTests
swift test
scripts/audit-localization.sh
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources Tests/SharedMetricsTests/LogicConsistencyGateTests.swift
git commit -m "fix: unify dashboard status copy"
```

---

## Task 5: Align Snapshot Projection And Decoded Report Flags

**Files:**
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift`
- Modify: `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift`
- Modify: `Sources/PulseDockApp/MetricsStore.swift`
- Test: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Add failing projection and decode tests**

Append:

```swift
@Test func widgetCompactSnapshotPreservesWidgetFallbackVisibleFields() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.2,
        hasCPUUsageReport: true,
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
        thermalState: "Nominal",
        batteryPercent: 0.62,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        batteryCycleCount: 12,
        batteryHealth: "Good",
        batteryDesignCapacity: 100,
        batteryVoltageMillivolts: 12_000,
        batteryAmperageMilliamps: -300
    )

    let compact = snapshot.widgetCompactSnapshot()

    #expect(compact.hasMemoryCompositionReport)
    #expect(compact.memoryFreeBytes == 2_000)
    #expect(compact.batteryCycleCount == 12)
    #expect(compact.batteryHealth == "Good")
    #expect(compact.batteryDesignCapacity == 100)
    #expect(compact.batteryVoltageMillivolts == 12_000)
    #expect(compact.batteryAmperageMilliamps == -300)
}

@Test func decodedNetworkDirectionCountersMatchInitializerFallback() throws {
    let json = """
    {
      "cpuUsage": 0,
      "hasCPUUsageReport": false,
      "memoryUsedBytes": 0,
      "memoryTotalBytes": 0,
      "thermalState": "Unknown",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "hasNetworkByteCounters": false,
      "networkInBytesPerSecond": 0,
      "networkOutBytesPerSecond": 0,
      "networkPathStatus": "unknown",
      "diskFreeBytes": 0,
      "diskTotalBytes": 0,
      "uptimeSeconds": 0,
      "timestamp": 0
    }
    """

    let decoded = try JSONDecoder().decode(MetricSnapshot.self, from: Data(json.utf8))
    let constructed = MetricSnapshot(
        cpuUsage: 0,
        hasCPUUsageReport: false,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        thermalState: "Unknown",
        networkBytesPerSecond: 0,
        hasNetworkByteCounters: false,
        networkInBytesPerSecond: 0,
        networkOutBytesPerSecond: 0
    )

    #expect(decoded.hasNetworkDirectionByteCounters == constructed.hasNetworkDirectionByteCounters)
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because widget compact currently drops several fields and decoded direction counters can diverge.

- [ ] **Step 3: Preserve widget-visible compact fields**

In `MetricSnapshot+WidgetCompact.swift`, pass the same memory composition and battery detail fields that `sampleWidgetCompact` already preserves:

```swift
memoryFreeBytes: memoryFreeBytes,
memoryWiredBytes: memoryWiredBytes,
memoryCompressedBytes: memoryCompressedBytes,
memoryCachedBytes: memoryCachedBytes,
memorySwapUsedBytes: memorySwapUsedBytes,
memorySwapTotalBytes: memorySwapTotalBytes,
memorySwapAvailableBytes: memorySwapAvailableBytes,
hasMemoryCompositionReport: hasMemoryCompositionReport,
```

and:

```swift
batteryCycleCount: batteryCycleCount,
batteryHealth: batteryHealth,
batteryCurrentCapacity: batteryCurrentCapacity,
batteryMaxCapacity: batteryMaxCapacity,
batteryDesignCapacity: batteryDesignCapacity,
batteryVoltageMillivolts: batteryVoltageMillivolts,
batteryAmperageMilliamps: batteryAmperageMilliamps,
```

Keep `networkInterfaces`, `storageVolumes`, `runningApps`, `gpuDevices`, and `displays` empty in widget compact snapshots.

- [ ] **Step 4: Align decoded network direction fallback**

In `MetricSnapshot.init(from:)`, replace:

```swift
hasNetworkDirectionByteCounters = decodedHasNetworkDirectionByteCounters
    ?? (hasNetworkInBytesKey && hasNetworkOutBytesKey
        || networkInBytesPerSecond > 0
        || networkOutBytesPerSecond > 0
        || networkInterfaces.contains { $0.hasByteCounters })
```

with:

```swift
hasNetworkDirectionByteCounters = decodedHasNetworkDirectionByteCounters
    ?? (decodedHasNetworkByteCounters == true
        || networkInBytesPerSecond > 0
        || networkOutBytesPerSecond > 0
        || networkInterfaces.contains { $0.hasByteCounters })
```

Remove the now-unused `hasNetworkInBytesKey` and `hasNetworkOutBytesKey` local constants.

- [ ] **Step 5: Document projection split in code comments**

In `MetricSnapshot+WidgetCompact.swift`, add this comment above the initializer call:

```swift
// Keep fields that widgets can render in either shared-store or fallback sampling paths.
// Strip detailed inventory lists and running app rows because those can contain user-created names.
```

In `MetricsStore.sanitizedHistorySnapshot`, add this comment above the initializer call:

```swift
// History persistence keeps trend fields only; it intentionally strips names and inventory lists.
```

- [ ] **Step 6: Run verification**

Run:

```bash
swift test --filter LogicConsistencyGateTests
swift test
swift build --target PulseDockWidget
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/SharedMetrics/MetricSnapshot.swift Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift Sources/PulseDockApp/MetricsStore.swift Tests/SharedMetricsTests/LogicConsistencyGateTests.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: align snapshot projection contracts"
```

---

## Task 6: Make Network Units And Scale Semantics Explicit

**Files:**
- Modify: `Sources/SharedMetrics/MetricFormatting.swift`
- Modify: `Sources/SharedMetrics/MetricScales.swift`
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Test: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Add failing network consistency tests**

Append:

```swift
@Test func networkTotalAndDirectionTextsUseSameUnitFamily() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0,
        hasCPUUsageReport: false,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        thermalState: "Nominal",
        networkBytesPerSecond: 125_000,
        hasNetworkByteCounters: true,
        hasNetworkDirectionByteCounters: true,
        networkInBytesPerSecond: 62_500,
        networkOutBytesPerSecond: 62_500
    )

    #expect(snapshot.networkText == "1 Mbps")
    #expect(snapshot.networkInText == "500 Kbps")
    #expect(snapshot.networkOutText == "500 Kbps")
}

@Test func networkRateProgressDocumentsReferenceCapacity() {
    #expect(MetricScales.networkRateReferenceBytesPerSecond == 12_500_000_000)
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 1_250_000_000) < 1)
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 12_500_000_000) == 1)
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because in/out currently use bytes/s and 10GbE is full scale.

- [ ] **Step 3: Add explicit network direction formatter**

In `MetricFormatting.swift`, add:

```swift
public static func directionalNetworkRate(bytesPerSecond: UInt64) -> String {
    networkRate(bytesPerSecond: bytesPerSecond)
}
```

Keep `byteRate` for storage and byte-counter contexts.

- [ ] **Step 4: Update MetricSnapshot direction text**

In `MetricSnapshot.swift`, replace:

```swift
return MetricFormatting.byteRate(bytesPerSecond: networkInBytesPerSecond)
```

with:

```swift
return MetricFormatting.directionalNetworkRate(bytesPerSecond: networkInBytesPerSecond)
```

Replace:

```swift
return MetricFormatting.byteRate(bytesPerSecond: networkOutBytesPerSecond)
```

with:

```swift
return MetricFormatting.directionalNetworkRate(bytesPerSecond: networkOutBytesPerSecond)
```

- [ ] **Step 5: Rename and raise network scale reference**

In `MetricScales.swift`, replace the hidden 10GbE constant with:

```swift
public enum MetricScales {
    public static let networkRateReferenceBytesPerSecond = 12_500_000_000.0

    public static func networkRateProgress(bytesPerSecond: UInt64) -> Double {
        guard bytesPerSecond > 0 else { return 0 }
        let value = min(Double(bytesPerSecond), networkRateReferenceBytesPerSecond)
        return min(log10(value + 1) / log10(networkRateReferenceBytesPerSecond + 1), 1)
    }

    public static func clampedProgress(_ progress: Double) -> Double? {
        guard progress.isFinite else { return nil }
        return min(max(progress, 0), 1)
    }
}
```

- [ ] **Step 6: Remove redundant widget network rates from compact snapshots**

First confirm the widget view still does not render short-window network throughput:

```bash
rg -n "networkText|networkInText|networkOutText|networkBytesPerSecond|networkInBytesPerSecond|networkOutBytesPerSecond" Sources/PulseDockWidget/SystemDashboardWidget.swift
```

Expected before cleanup: widget view code does not read `snapshot.networkText`, `snapshot.networkInText`, or `snapshot.networkOutText`.

Remove these three fields from `widgetCompactSnapshot`:

```swift
networkBytesPerSecond: networkBytesPerSecond,
networkInBytesPerSecond: networkInBytesPerSecond,
networkOutBytesPerSecond: networkOutBytesPerSecond,
```

Keep `networkPathStatus`, `networkPathInterfaceKinds`, and support/cost flags because widgets render connection/path/interface rows.

- [ ] **Step 7: Run verification**

Run:

```bash
swift test --filter LogicConsistencyGateTests
swift test
swift build --target PulseDockWidget
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/SharedMetrics/MetricFormatting.swift Sources/SharedMetrics/MetricScales.swift Sources/SharedMetrics/MetricSnapshot.swift Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/LogicConsistencyGateTests.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: make network units explicit"
```

---

## Task 7: Harden Shared Snapshot Save, Retry, And Schema Validation

**Files:**
- Modify: `Sources/SharedMetrics/SharedSnapshotStore.swift`
- Modify: `Sources/PulseDockApp/MetricsStore.swift`
- Test: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Add failing shared snapshot tests**

Append:

```swift
@Test func sharedSnapshotStoreRejectsUnsupportedSchemaVersion() throws {
    let suiteName = "logic-consistency-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = SharedSnapshotStore(defaults: defaults)

    var snapshot = MetricSnapshot.placeholder
    snapshot.schemaVersion = MetricSnapshot.currentSchemaVersion + 1
    snapshot.timestamp = Date()

    #expect(store.saveLatestSnapshot(snapshot))
    #expect(store.loadLatestSnapshot(maxAge: 60, now: snapshot.timestamp) == nil)
}
```

Add a source gate for retry behavior:

```swift
@Test func metricsStoreUpdatesSharedSnapshotWriteDateOnlyAfterSuccessfulSave() throws {
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")

    #expect(metricsStore.contains("if sharedSnapshotStore.saveLatestSnapshot(snapshot) {"))
    #expect(metricsStore.contains("lastSharedSnapshotWriteDate = snapshot.timestamp"))
    #expect(!metricsStore.contains("_ = sharedSnapshotStore.saveLatestSnapshot(snapshot)"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because schema version is not checked and MetricsStore discards the save result.

- [ ] **Step 3: Validate schema on load**

In `SharedSnapshotStore.loadLatestSnapshot`, after decoding:

```swift
guard snapshot.schemaVersion == MetricSnapshot.currentSchemaVersion else {
    return nil
}
```

Keep the existing age and future-skew checks.

- [ ] **Step 4: Retry on failed save**

In `MetricsStore.saveSharedSnapshotIfNeeded`, replace:

```swift
lastSharedSnapshotWriteDate = snapshot.timestamp
_ = sharedSnapshotStore.saveLatestSnapshot(snapshot)
```

with:

```swift
if sharedSnapshotStore.saveLatestSnapshot(snapshot) {
    lastSharedSnapshotWriteDate = snapshot.timestamp
}
```

- [ ] **Step 5: Run verification**

Run:

```bash
swift test --filter LogicConsistencyGateTests
swift test
swift build
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/SharedMetrics/SharedSnapshotStore.swift Sources/PulseDockApp/MetricsStore.swift Tests/SharedMetricsTests/LogicConsistencyGateTests.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: retry failed shared snapshot writes"
```

---

## Task 8: Introduce Canonical Thermal And Network Path Contracts

**Files:**
- Create: `Sources/SharedMetrics/MetricStateContracts.swift`
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Test: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`

- [ ] **Step 1: Add failing canonical contract tests**

Append:

```swift
@Test func thermalStateCanonicalizesLegacyAliases() {
    #expect(ThermalState(raw: "nominal") == .nominal)
    #expect(ThermalState(raw: "fair") == .warm)
    #expect(ThermalState(raw: "serious") == .hot)
    #expect(ThermalState(raw: "unknown") == .unknown)
}

@Test func networkPathStateCanonicalizesLegacyAliases() {
    #expect(NetworkPathState(raw: "satisfied") == .satisfied)
    #expect(NetworkPathState(raw: "requiresConnection") == .requiresConnection)
    #expect(NetworkPathState(raw: "requires_connection") == .requiresConnection)
    #expect(NetworkPathState(raw: "requires connection") == .requiresConnection)
    #expect(NetworkPathState(raw: "unknown") == .unknown)
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because the canonical types do not exist.

- [ ] **Step 3: Create canonical state contracts**

Create `Sources/SharedMetrics/MetricStateContracts.swift`:

```swift
import Foundation

public enum ThermalState: Equatable {
    case nominal
    case warm
    case hot
    case critical
    case unknown

    public init(raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "nominal":
            self = .nominal
        case "warm", "fair":
            self = .warm
        case "hot", "serious":
            self = .hot
        case "critical":
            self = .critical
        default:
            self = .unknown
        }
    }

    public var isReported: Bool {
        self != .unknown
    }
}

public enum NetworkPathState: Equatable {
    case satisfied
    case unsatisfied
    case requiresConnection
    case unknown

    public init(raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "satisfied":
            self = .satisfied
        case "unsatisfied":
            self = .unsatisfied
        case "requiresconnection", "requires_connection", "requires connection":
            self = .requiresConnection
        default:
            self = .unknown
        }
    }

    public var isReported: Bool {
        self != .unknown
    }
}
```

- [ ] **Step 4: Route `MetricSnapshot` switches through canonical types**

In `MetricSnapshot.swift`, add:

```swift
public var canonicalThermalState: ThermalState {
    ThermalState(raw: thermalState)
}

public var canonicalNetworkPathState: NetworkPathState {
    NetworkPathState(raw: networkPathStatus)
}
```

Then update `thermalText`, `hasThermalStateReport`, `thermalLimitText`, `hasNetworkPathReport`, `networkPathText`, `networkPathDetailText`, and `networkPathCapabilityText` to switch on `canonicalThermalState` and `canonicalNetworkPathState` instead of raw string lists.

For example:

```swift
public var hasThermalStateReport: Bool {
    canonicalThermalState.isReported
}
```

and:

```swift
public var networkPathText: String {
    switch canonicalNetworkPathState {
    case .satisfied:
        return SharedMetricStrings.networkPathStatusOnline
    case .unsatisfied:
        return SharedMetricStrings.networkPathStatusOffline
    case .requiresConnection:
        return SharedMetricStrings.networkPathStatusRequiresConnection
    case .unknown:
        return SharedMetricStrings.notReported
    }
}
```

- [ ] **Step 5: Update app/widget tint helpers to use canonical state**

In `DashboardView.swift`, `WidgetPanelView.swift`, and `SystemDashboardWidget.swift`, replace repeated raw string aliases with canonical helpers:

```swift
switch ThermalState(raw: state) {
case .critical, .hot:
    DashboardColor.red
case .warm:
    DashboardColor.amber
case .nominal:
    DashboardColor.green
case .unknown:
    DashboardColor.cyan
}
```

Use the equivalent palette helpers in widget and popover files.

- [ ] **Step 6: Run verification**

Run:

```bash
swift test --filter LogicConsistencyGateTests
swift test
swift build
swift build --target PulseDockWidget
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/SharedMetrics/MetricStateContracts.swift Sources/SharedMetrics/MetricSnapshot.swift Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/LogicConsistencyGateTests.swift
git commit -m "refactor: centralize metric state contracts"
```

---

## Task 9: Resolve Low-Risk Copy And Documentation Drift

**Files:**
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: app localized resources
- Modify: `Sources/PulseDockWidget/PulseDockWidgetStrings.swift`
- Modify: widget localized resources
- Modify: `Resources/WidgetInfo.plist`
- Modify: `README.md`
- Modify: `docs/data-capability-audit.md`
- Test: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`
- Test: `Tests/SharedMetricsTests/LocalizationGateTests.swift`

- [ ] **Step 1: Add failing drift tests**

Append:

```swift
@Test func lowRiskCopyDriftUsesApprovedVocabulary() throws {
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let widgetStrings = try fixture("Sources/PulseDockWidget/PulseDockWidgetStrings.swift")
    let widgetInfo = try fixture("Resources/WidgetInfo.plist")
    let readme = try fixture("README.md")

    #expect(appStrings.contains("defaultValue: \"GPU / Displays\""))
    #expect(!appStrings.contains("defaultValue: \"GPU / Display\""))
    #expect(widgetStrings.contains("defaultValue: \"Thermal\""))
    #expect(!widgetStrings.contains("defaultValue: \"Heat\""))
    #expect(widgetInfo.contains("<string>Pulse Dock</string>"))
    #expect(readme.contains("Local sampling, no account, no tracking, no analytics, and no remote probes"))
}

@Test func dataCapabilityAuditMentionsStorageWidgetsAndSeparateWidgetCadences() throws {
    let audit = try fixture("docs/data-capability-audit.md")
    let storageLine = audit
        .split(separator: "\n")
        .first { $0.contains("| Storage |") }
        .map(String.init) ?? ""

    #expect(storageLine.localizedCaseInsensitiveContains("widgets"))
    #expect(audit.contains("Shared widget snapshot writes and WidgetKit reload requests use separate throttles"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because copy and docs still use older wording.

- [ ] **Step 3: Normalize app vocabulary**

In `PulseDockAppStrings.swift`, use:

```swift
static var dashboardPageGPUTitle: String {
    localized("app.dashboard.page.gpu.title", defaultValue: "GPU / Displays")
}

static var settingsPrivacyPolicyDetail: String {
    localized("app.settings.privacy_policy.detail", defaultValue: "Local sampling, no account, no tracking, no analytics, no remote probes")
}
```

Keep technical context names distinct only when they add meaning:

- page title: `GPU / Displays`;
- panel title: `GPU & Unified Memory`;
- source/data row: `GPU / Displays`.

Update app localization resources.

- [ ] **Step 4: Normalize widget vocabulary**

In `PulseDockWidgetStrings.swift`, replace:

```swift
static var miniThermal: String {
    localized("widget.mini.thermal", defaultValue: "Heat")
}
```

with:

```swift
static var miniThermal: String {
    localized("widget.mini.thermal", defaultValue: "Thermal")
}
```

Update `widgetDescription`:

```swift
static var widgetDescription: String {
    localized("widget.description", defaultValue: "Show Mac CPU, memory, disk, connection, power, load, thermal, uptime, system, and kernel status on your desktop.")
}
```

Update widget localization resources.

- [ ] **Step 5: Normalize widget display name**

In `Resources/WidgetInfo.plist`, set:

```xml
<key>CFBundleDisplayName</key>
<string>Pulse Dock</string>
...
<key>CFBundleName</key>
<string>Pulse Dock</string>
```

- [ ] **Step 6: Update public docs**

In `README.md`, replace the privacy paragraph sentence with:

```markdown
Pulse Dock samples local system metrics on device. It does not create accounts, collect personal data, track users, run analytics, or send remote probes. Local sampling, no account, no tracking, no analytics, and no remote probes are the product privacy baseline. Release privacy details live in `docs/data-capability-audit.md` and `docs/app-store-release-checklist.md`.
```

In `docs/data-capability-audit.md`, update the Storage row Surfaces:

```markdown
| Storage | Primary disk free/total, mounted volume summaries, per-volume total bytes, used bytes, and usage percentage, regular and important usage available capacity, file system name, removable/ejectable/internal flags, read-only state, and primary-volume flag, without storing mount paths or user-defined volume names | File system and volume resource values including `volumeAvailableCapacityForImportantUsage` and `volumeIsReadOnly` | Overview, Storage page, Status page, Settings page, widgets |
```

Replace the shared write/reload sentence with:

```markdown
- Shared widget snapshot writes and WidgetKit reload requests use separate throttles. The main app writes compact snapshots on the shared snapshot cadence and requests WidgetKit timeline reloads on the widget reload cadence; WidgetKit still decides the actual render schedule.
```

- [ ] **Step 7: Run verification**

Run:

```bash
swift test --filter LogicConsistencyGateTests
swift test
scripts/audit-localization.sh
scripts/validate-public-pages.sh
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources Sources/PulseDockWidget/PulseDockWidgetStrings.swift Sources/PulseDockWidget/Resources Resources/WidgetInfo.plist README.md docs/data-capability-audit.md Tests/SharedMetricsTests/LogicConsistencyGateTests.swift Tests/SharedMetricsTests/LocalizationGateTests.swift
git commit -m "chore: normalize product copy vocabulary"
```

---

## Task 10: Mark Widget Preview Data Explicitly

**Files:**
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Modify: `Sources/PulseDockWidget/PulseDockWidgetStrings.swift`
- Modify: widget localized resources
- Test: `Tests/SharedMetricsTests/LogicConsistencyGateTests.swift`

- [ ] **Step 1: Add failing preview-data tests**

Append:

```swift
@Test func widgetRepresentativeDataIsExplicitlyMarked() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let strings = try fixture("Sources/PulseDockWidget/PulseDockWidgetStrings.swift")

    #expect(widget.contains("enum SystemEntryKind"))
    #expect(widget.contains("kind: .preview"))
    #expect(widget.contains("kind: .live"))
    #expect(widget.contains("PulseDockWidgetStrings.previewData"))
    #expect(strings.contains("widget.preview_data"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter LogicConsistencyGateTests
```

Expected: FAIL because `SystemEntry` does not distinguish preview from live data.

- [ ] **Step 3: Add entry kind**

In `SystemDashboardWidget.swift`, add:

```swift
enum SystemEntryKind {
    case preview
    case live
    case empty
}
```

Change `SystemEntry`:

```swift
struct SystemEntry: TimelineEntry {
    let date: Date
    let snapshot: MetricSnapshot?
    let snapshotAge: TimeInterval?
    let kind: SystemEntryKind

    var freshnessTone: WidgetFreshnessTone {
        WidgetFreshnessTone.resolve(age: snapshotAge)
    }
}
```

Update provider entries:

```swift
SystemEntry(date: Date(), snapshot: Self.representativeSnapshot(), snapshotAge: 0, kind: .preview)
```

and timeline entries:

```swift
let entry = SystemEntry(date: now, snapshot: snapshot, snapshotAge: age, kind: snapshot == nil ? .empty : .live)
```

- [ ] **Step 4: Add preview label in widget header**

In `PulseDockWidgetStrings.swift`, add:

```swift
static var previewData: String {
    localized("widget.preview_data", defaultValue: "Preview")
}
```

Update resources with:

```text
"widget.preview_data" = "Preview";
```

```text
"widget.preview_data" = "预览";
```

Pass `entry.kind` into widget views and show a compact label next to the header time when `kind == .preview`:

```swift
if entryKind == .preview {
    Text(PulseDockWidgetStrings.previewData)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(widgetSecondaryText(for: colorScheme))
}
```

Keep the label out of live timeline entries.

- [ ] **Step 5: Run verification**

Run:

```bash
swift test --filter LogicConsistencyGateTests
swift test
swift build --target PulseDockWidget
scripts/audit-localization.sh
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/PulseDockWidget/SystemDashboardWidget.swift Sources/PulseDockWidget/PulseDockWidgetStrings.swift Sources/PulseDockWidget/Resources Tests/SharedMetricsTests/LogicConsistencyGateTests.swift
git commit -m "fix: label widget preview data"
```

---

## Task 11: Final Verification And Xcode Build

**Files:**
- No source edits expected.
- May modify generated `PulseDock.xcodeproj` only if `scripts/generate-xcodeproj.rb` produces a deterministic change needed for new files.

- [ ] **Step 1: Run full SwiftPM verification**

Run:

```bash
swift test
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
scripts/validate-public-pages.sh
```

Expected:

```text
Test run passed
Build complete
Build complete
Localization audit passed
Public page validation passed
```

- [ ] **Step 2: Regenerate Xcode project**

Run:

```bash
scripts/generate-xcodeproj.rb
```

Expected: project regeneration completes without Ruby exceptions.

- [ ] **Step 3: Build generated Xcode project**

Run:

```bash
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected:

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short
git diff --stat
git diff --check
```

Expected:

```text
git diff --check exits 0
```

Review that generated project changes include the new `WidgetTimelinePolicy.swift` and `MetricStateContracts.swift` files in the correct targets.

- [ ] **Step 5: Commit verification artifacts if needed**

If `PulseDock.xcodeproj` changed deterministically:

```bash
git add PulseDock.xcodeproj
git commit -m "chore: regenerate xcode project for consistency fixes"
```

If the Xcode project did not change:

```bash
git status --short
```

Expected: no unstaged generated-project change.

---

## 5. Manual QA Checklist

Run the built app and verify these user-visible surfaces:

- Settings page: Widget refresh shows `System Scheduled`, with detail saying the system timeline requests approximately 5 minutes.
- Overview page: network total and directional rates use the same unit family.
- Power page on battery Mac: low battery charging is not red; unplugged low battery still warns/critical.
- Power page on desktop/no-battery Mac: primary state reads as power source, not battery percentage, and does not repeat `Power Adapter` three times.
- Apps page: summary card reads `Displayed Apps`, not `List Items`.
- Status page: thermal panel uses `Performance Limit` where it means performance limiting.
- History and Status pages: local rules table vocabulary matches.
- Widget small/medium/large: power source vocabulary is consistent; preview data is marked only in gallery/preview paths.
- Widget freshness dot does not become stale exactly at the accepted shared snapshot max age.
- Chinese localization fits existing responsive layouts and contains no raw English fallback for new keys.

---

## 6. Known Non-Goals

- Do not add real-time network throughput to widgets; the current product decision is to avoid short-window throughput in WidgetKit.
- Do not remove legacy thermal/network path aliases; canonicalize them.
- Do not change privacy manifests unless a new API category is introduced, which this plan does not do.
- Do not redesign the dashboard visual system; this is semantic consistency and data-contract hardening.
- Do not claim D1 as a live product defect; it is a review-report false positive.

---

## 7. Self-Review

Spec coverage:

- LC-1, LC-3, L4-W5: Task 2.
- LC-5, L4-1, L4-7, L1-12, L4-13: Task 3.
- L1-3, L1-4, L4-9, L1-11: Task 4.
- L3-1, L3-2, L3-3, L3-4, L3-5, L3-6, L3-7, L3-8, L3-14, L3-16: Task 5.
- L3-9, L3-10, L3-15, L4-5, L4-6: Task 6.
- L3-11, L3-12: Task 7.
- LC-6, L2-3, L2-4, L2-5, L2-6, L2-7: Task 8.
- L1-5, L1-6, L1-7, L1-8, L1-9, L1-10, L1-13, D2, D3: Task 9.
- L4-10: Task 10.
- corrected LC-2, D1, L4-12, and final report counts: Task 1.

Placeholder scan:

- The plan contains concrete filenames, tests, code snippets, commands, and expected outcomes.
- No unresolved implementation placeholders are intentionally left.

Type consistency:

- `WidgetTimelinePolicy`, `ThermalState`, `NetworkPathState`, `SystemEntryKind`, and `LogicConsistencyGateTests` are introduced before later tasks reference them.
- Power-source strings use `powerSourceExternal` consistently across SharedMetrics, app, and widget layers.
