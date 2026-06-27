# Pulse Dock App Store Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Pulse Dock to a stronger App Store v1 readiness state by finishing screenshots, responsive window behavior, accessibility, app/widget data consistency, threshold-copy clarity, and confirmed P2 polish items without expanding v1 into unreviewed product scope.

**Architecture:** Keep the current SwiftPM + generated Xcode project layout. Add small shared helpers in `SharedMetrics` for snapshot sharing and widget compaction, keep app UI changes in `SystemDashboardApp`, keep widget reading logic in `SystemDashboardWidget`, and regenerate the Xcode project through `scripts/generate-xcodeproj.rb` after target metadata changes. English support is treated as a hard release decision: either complete full-chain localization in a separate localization sprint before global release, or keep v1 `zh-Hans` only and limit App Store storefronts.

**Tech Stack:** Swift 6, SwiftUI, AppKit, WidgetKit, UserDefaults/App Group, Xcode project generation via Ruby `xcodeproj`, shell validation scripts.

---

## File Structure

- Modify `Resources/PulseDock.entitlements`: add the App Group entitlement for app/widget shared snapshot data.
- Modify `Resources/PulseDockWidgetExtension.entitlements`: add the same App Group entitlement.
- Modify `scripts/generate-xcodeproj.rb`: propagate App Group-capable entitlements, generated localization resources when localization is executed, screenshot metadata resources, and updated bundle identifiers.
- Modify `Package.swift`: no change is needed for new `.swift` files inside existing target directories because SwiftPM discovers them automatically; update only if Task 8 renames source folders.
- Create `Sources/SharedMetrics/SharedSnapshotStore.swift`: encode/decode the latest compact `MetricSnapshot` through `UserDefaults(suiteName:)`.
- Create `Sources/SharedMetrics/PulseDockAppGroup.swift`: centralize App Group suite name and fallback behavior.
- Create `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift`: provide the single shared compact snapshot used by app sharing and widget fallback.
- Modify `Sources/SystemDashboardApp/MetricsStore.swift`: write latest snapshots to the shared store with throttling, reload widgets after writes, and rename `topProcesses` local UI usage to running apps where app-owned.
- Modify `Sources/SystemDashboardWidget/SystemDashboardWidget.swift`: read the shared snapshot first and use self-sampling plus the shared compact helper only as fallback.
- Modify `Sources/SystemDashboardApp/DashboardView.swift`: lower minimum layout assumptions, add accessibility labels, replace misleading alert copy, and adjust process naming.
- Modify `Sources/SystemDashboardApp/WidgetPanelView.swift`: add accessibility labels.
- Modify `Sources/SystemDashboardApp/AppDelegate.swift`: reduce minimum window size and preserve autosave behavior.
- Do not create notification code in this v1 polish plan. `UserNotifications` remains a v1.1 feature-plan candidate so v1 does not add a new permission prompt or App Review surface.
- Create `scripts/audit-localization.sh` as the global-release gate; the audit is expected to fail until every user-facing Chinese string has a localized English path.
- Modify `Resources/AppInfo.plist` and `Resources/WidgetInfo.plist`: keep only `zh-Hans` for China-only v1, or add `en` only after Task 6 full-chain localization passes.
- Modify `docs/app-store/privacy-policy.md`: keep claims aligned with v1 behavior; do not mention notifications unless a future notification task is actually implemented.
- Modify `docs/app-store/support.md`: add stable support copy and link stability notes.
- Modify `docs/app-store-release-checklist.md` and `docs/app-store-readiness-checklist.md`: mark completed optimizations and record App Group provisioning, notification deferral, and localization/storefront decisions.
- Modify `scripts/validate-app-store-screenshots.sh`: keep existing dimension checks, add friendlier output listing missing screenshot categories.
- Add screenshots under `docs/app-store/screenshots/`: 5 production images named `01-overview.png`, `02-cpu-memory.png`, `03-network-storage.png`, `04-widget-popover.png`, `05-settings-history.png`.
- Modify `Tests/SharedMetricsTests/MetricFormattingTests.swift`: add source-level and behavioral tests for App Group sharing, widget fallback, threshold copy, accessibility semantics, localization decision gates, screenshot assets, disk path fix, naming cleanup, and responsive window minimum.

---

## Task 1: App Group Shared Snapshot Foundation

**Files:**
- Create: `Sources/SharedMetrics/PulseDockAppGroup.swift`
- Create: `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift`
- Create: `Sources/SharedMetrics/SharedSnapshotStore.swift`
- Modify: `Sources/SystemDashboardApp/MetricsStore.swift`
- Modify: `Sources/SystemDashboardWidget/SystemDashboardWidget.swift`
- Modify: `Resources/PulseDock.entitlements`
- Modify: `Resources/PulseDockWidgetExtension.entitlements`
- Modify: `docs/app-store-release-checklist.md`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write failing tests for App Group configuration, shared compaction, throttled writes, and widget fallback**

Add tests:

```swift
@Test func appGroupEntitlementsAreDeclaredForAppAndWidget() throws {
    let appEntitlements = try fixture("Resources/PulseDock.entitlements")
    let widgetEntitlements = try fixture("Resources/PulseDockWidgetExtension.entitlements")

    #expect(appEntitlements.contains("<key>com.apple.security.application-groups</key>"))
    #expect(widgetEntitlements.contains("<key>com.apple.security.application-groups</key>"))
    #expect(appEntitlements.contains("<string>group.com.ifonly3.pulsedock</string>"))
    #expect(widgetEntitlements.contains("<string>group.com.ifonly3.pulsedock</string>"))
}

@Test func sharedSnapshotUsesSingleWidgetCompactHelper() throws {
    let compact = try fixture("Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift")
    let sharedStore = try fixture("Sources/SharedMetrics/SharedSnapshotStore.swift")
    let widget = try fixture("Sources/SystemDashboardWidget/SystemDashboardWidget.swift")

    #expect(compact.contains("public func widgetCompactSnapshot() -> MetricSnapshot"))
    #expect(sharedStore.contains("snapshot.widgetCompactSnapshot()"))
    #expect(widget.contains("Self.samplerCache.sample().widgetCompactSnapshot()"))
    #expect(!widget.contains("private func compactWidgetSnapshot"))
}

@Test func appWritesSharedSnapshotsWithThrottleAndWidgetReadsSharedDataFirst() throws {
    let appGroup = try fixture("Sources/SharedMetrics/PulseDockAppGroup.swift")
    let sharedStore = try fixture("Sources/SharedMetrics/SharedSnapshotStore.swift")
    let metricsStore = try fixture("Sources/SystemDashboardApp/MetricsStore.swift")
    let widget = try fixture("Sources/SystemDashboardWidget/SystemDashboardWidget.swift")

    #expect(appGroup.contains("static let suiteName = \"group.com.ifonly3.pulsedock\""))
    #expect(sharedStore.contains("UserDefaults(suiteName: PulseDockAppGroup.suiteName)"))
    #expect(sharedStore.contains("func saveLatestSnapshot(_ snapshot: MetricSnapshot)"))
    #expect(sharedStore.contains("func loadLatestSnapshot(maxAge: TimeInterval"))
    #expect(metricsStore.contains("private let sharedSnapshotWriteInterval: TimeInterval = 60"))
    #expect(metricsStore.contains("private var lastSharedSnapshotWriteDate: Date?"))
    #expect(metricsStore.contains("saveSharedSnapshotIfNeeded(nextSnapshot)"))
    #expect(widget.contains("sharedSnapshotStore.loadLatestSnapshot(maxAge:"))
    #expect(widget.contains("?? Self.samplerCache.sample().widgetCompactSnapshot()"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter appGroupEntitlementsAreDeclaredForAppAndWidget
swift test --filter sharedSnapshotUsesSingleWidgetCompactHelper
swift test --filter appWritesSharedSnapshotsWithThrottleAndWidgetReadsSharedDataFirst
```

Expected: all fail because the shared files, entitlements, throttling, and widget fallback changes do not exist.

- [ ] **Step 3: Record provisioning prerequisite**

Before relying on runtime App Group sharing for distribution, register this App Group in Apple Developer Portal and enable it on both production Bundle IDs:

```text
App Group: group.com.ifonly3.pulsedock
App Bundle ID: com.ifonly3.pulsedock
Widget Bundle ID: com.ifonly3.pulsedock.widget
```

Update `docs/app-store-release-checklist.md` with:

```markdown
- [ ] Apple Developer Portal: `group.com.ifonly3.pulsedock` App Group is registered and enabled for both app and widget Bundle IDs.
- [ ] App Store provisioning profiles were regenerated after enabling the App Group.
- [ ] Local adhoc signing verifies entitlement shape only; functional App Group sharing must be verified with Xcode automatic signing, TestFlight, or an App Store-signed archive.
```

- [ ] **Step 4: Add shared App Group constants**

Create `Sources/SharedMetrics/PulseDockAppGroup.swift`:

```swift
import Foundation

public enum PulseDockAppGroup {
    public static let suiteName = "group.com.ifonly3.pulsedock"
}
```

- [ ] **Step 5: Move widget compacting into SharedMetrics**

Create `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift` by moving the existing field choices from `SystemDashboardWidget.swift` into a shared extension:

```swift
import Foundation

public extension MetricSnapshot {
    func widgetCompactSnapshot() -> MetricSnapshot {
        MetricSnapshot(
            cpuUsage: cpuUsage,
            cpuCoreUsages: cpuCoreUsages,
            hasCPUUsageReport: hasCPUUsageReport,
            physicalCoreCount: physicalCoreCount,
            logicalCoreCount: logicalCoreCount,
            activeProcessorCount: activeProcessorCount,
            cpuBrandName: nil,
            memoryUsedBytes: memoryUsedBytes,
            memoryTotalBytes: memoryTotalBytes,
            memorySwapUsedBytes: memorySwapUsedBytes,
            memorySwapTotalBytes: memorySwapTotalBytes,
            memorySwapAvailableBytes: memorySwapAvailableBytes,
            loadAverage: loadAverage,
            loadAverage5: loadAverage5,
            loadAverage15: loadAverage15,
            hasLoadAverageReport: hasLoadAverageReport,
            thermalState: thermalState,
            batteryPercent: batteryPercent,
            batteryIsCharging: batteryIsCharging,
            batteryPowerSource: batteryPowerSource,
            batteryTimeRemainingMinutes: batteryTimeRemainingMinutes,
            batteryCurrentCapacity: batteryCurrentCapacity,
            batteryMaxCapacity: batteryMaxCapacity,
            hasNetworkByteCounters: false,
            hasNetworkDirectionByteCounters: false,
            networkPathStatus: networkPathStatus,
            networkPathIsExpensive: networkPathIsExpensive,
            networkPathIsConstrained: networkPathIsConstrained,
            hasNetworkPathCostReport: hasNetworkPathCostReport,
            networkPathSupportsDNS: networkPathSupportsDNS,
            networkPathSupportsIPv4: networkPathSupportsIPv4,
            networkPathSupportsIPv6: networkPathSupportsIPv6,
            hasNetworkPathSupportReport: hasNetworkPathSupportReport,
            networkPathInterfaceKinds: networkPathInterfaceKinds,
            networkInBytesPerSecond: 0,
            networkOutBytesPerSecond: 0,
            networkInterfaces: compactWidgetInterfaces(),
            diskFreeBytes: diskFreeBytes,
            diskTotalBytes: diskTotalBytes,
            storageVolumes: [],
            processCount: 0,
            activeApplicationCount: 0,
            hiddenApplicationCount: 0,
            hasRunningAppCountReport: false,
            topProcesses: [],
            gpuDevices: [],
            displays: [],
            uptimeSeconds: uptimeSeconds,
            hasUptimeReport: hasUptimeReport,
            osVersion: osVersion,
            kernelRelease: kernelRelease,
            timestamp: timestamp
        )
    }

    private func compactWidgetInterfaces() -> [NetworkInterfaceMetric] {
        networkInterfaces
            .filter(\.hasInterfaceStateReport)
            .enumerated()
            .map { index, interface in
                NetworkInterfaceMetric(
                    index: index,
                    displayName: "未报告",
                    kind: "未报告",
                    isUp: interface.isUp,
                    isLoopback: interface.isLoopback,
                    hasInterfaceStateReport: true,
                    bytesReceived: 0,
                    bytesSent: 0,
                    hasByteCounters: false
                )
            }
    }
}
```

- [ ] **Step 6: Add shared snapshot persistence helper**

Create `Sources/SharedMetrics/SharedSnapshotStore.swift`:

```swift
import Foundation

public struct SharedSnapshotStore: Sendable {
    private enum Keys {
        static let latestSnapshot = "shared.latestMetricSnapshot"
    }

    private let defaults: UserDefaults?

    public init(defaults: UserDefaults? = UserDefaults(suiteName: PulseDockAppGroup.suiteName)) {
        self.defaults = defaults
    }

    public func saveLatestSnapshot(_ snapshot: MetricSnapshot) {
        guard let defaults else { return }
        let compact = snapshot.widgetCompactSnapshot()
        guard let data = try? JSONEncoder().encode(compact) else { return }
        defaults.set(data, forKey: Keys.latestSnapshot)
    }

    public func loadLatestSnapshot(maxAge: TimeInterval, now: Date = Date()) -> MetricSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: Keys.latestSnapshot),
              let snapshot = try? JSONDecoder().decode(MetricSnapshot.self, from: data),
              now.timeIntervalSince(snapshot.timestamp) >= 0,
              now.timeIntervalSince(snapshot.timestamp) <= maxAge else {
            return nil
        }
        return snapshot
    }
}
```

- [ ] **Step 7: Add App Group entitlement to both targets**

Update both entitlement files:

```xml
<key>com.apple.security.application-groups</key>
<array>
  <string>group.com.ifonly3.pulsedock</string>
</array>
```

Keep the existing sandbox key. `package-app.sh` adhoc builds should still pass codesign verification, but successful runtime sharing is not proven until the provisioning prerequisite in Step 3 is complete.

- [ ] **Step 8: Wire throttled shared snapshot writes in app**

In `MetricsStore`, add:

```swift
private let sharedSnapshotStore: SharedSnapshotStore
private var lastSharedSnapshotWriteDate: Date?
private let sharedSnapshotWriteInterval: TimeInterval = 60
```

Update initializer:

```swift
init(
    sampler: SystemSampler = SystemSampler(),
    defaults: UserDefaults = UserDefaults.standard,
    sharedSnapshotStore: SharedSnapshotStore = SharedSnapshotStore()
) {
    self.sampler = sampler
    self.defaults = defaults
    self.sharedSnapshotStore = sharedSnapshotStore
    ...
}
```

Add helper:

```swift
private func saveSharedSnapshotIfNeeded(_ snapshot: MetricSnapshot) {
    if let lastSharedSnapshotWriteDate,
       snapshot.timestamp.timeIntervalSince(lastSharedSnapshotWriteDate) < sharedSnapshotWriteInterval {
        return
    }

    lastSharedSnapshotWriteDate = snapshot.timestamp
    sharedSnapshotStore.saveLatestSnapshot(snapshot)
}
```

After `snapshot = nextSnapshot` in `refresh()`, add:

```swift
saveSharedSnapshotIfNeeded(nextSnapshot)
```

- [ ] **Step 9: Read shared snapshot first in widget**

In `SystemProvider`, add:

```swift
private static let sharedSnapshotStore = SharedSnapshotStore()
private let sharedSnapshotMaxAge: TimeInterval = 600
```

Replace `sampledSnapshot()` with:

```swift
private func sampledSnapshot() -> MetricSnapshot {
    Self.sharedSnapshotStore.loadLatestSnapshot(maxAge: sharedSnapshotMaxAge)
        ?? Self.samplerCache.sample().widgetCompactSnapshot()
}
```

Delete the old private `compactWidgetSnapshot(from:)` and `compactWidgetInterfaces(from:)` functions from `SystemDashboardWidget.swift`.

- [ ] **Step 10: Run tests**

Run:

```bash
swift test --filter appGroupEntitlementsAreDeclaredForAppAndWidget
swift test --filter sharedSnapshotUsesSingleWidgetCompactHelper
swift test --filter appWritesSharedSnapshotsWithThrottleAndWidgetReadsSharedDataFirst
swift test
```

Expected: all tests pass.

- [ ] **Step 11: Commit**

```bash
git add Sources/SharedMetrics/PulseDockAppGroup.swift Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift Sources/SharedMetrics/SharedSnapshotStore.swift Sources/SystemDashboardApp/MetricsStore.swift Sources/SystemDashboardWidget/SystemDashboardWidget.swift Resources/PulseDock.entitlements Resources/PulseDockWidgetExtension.entitlements docs/app-store-release-checklist.md Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "feat: share latest metrics with widget"
```

---

## Task 2: Disk Sampling Path and Running App Naming Cleanup

**Files:**
- Modify: `Sources/SharedMetrics/SystemSampler.swift`
- Modify: `Sources/SystemDashboardApp/MetricsStore.swift`
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift`
- Modify: `Sources/SystemDashboardApp/DashboardView.swift`
- Modify: `Sources/SystemDashboardWidget/SystemDashboardWidget.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write failing tests for disk fallback and naming cleanup**

Add:

```swift
@Test func diskFallbackUsesCurrentUserHomeUrlInsteadOfNSHomeDirectoryString() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(sampler.contains("FileManager.default.homeDirectoryForCurrentUser.path"))
    #expect(!sampler.contains("attributesOfFileSystem(forPath: NSHomeDirectory())"))
}

@Test func runningAppInventoryUsesRunningAppsNamingAtAppBoundaries() throws {
    let metricsStore = try fixture("Sources/SystemDashboardApp/MetricsStore.swift")
    let snapshot = try fixture("Sources/SharedMetrics/MetricSnapshot.swift")
    let dashboard = try fixture("Sources/SystemDashboardApp/DashboardView.swift")

    #expect(metricsStore.contains("snapshot.runningApps = visibleApplications.prefix(8)"))
    #expect(snapshot.contains("public var runningApps: [ProcessMetric]"))
    #expect(snapshot.contains("case runningApps = \"topProcesses\""))
    #expect(!snapshot.contains("@available(*, deprecated, renamed: \"runningApps\")"))
    #expect(!snapshot.contains("public var topProcesses: [ProcessMetric]"))
    #expect(dashboard.contains("snapshot.runningApps.filter"))
    #expect(!dashboard.contains("snapshot.topProcesses.filter"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter diskFallbackUsesCurrentUserHomeUrlInsteadOfNSHomeDirectoryString
swift test --filter runningAppInventoryUsesRunningAppsNamingAtAppBoundaries
```

Expected: fail because current code still uses `NSHomeDirectory()` for the disk fallback and exposes `topProcesses` in UI paths.

- [ ] **Step 3: Replace disk fallback path**

In `SystemSampler.sampleDiskSpace()`, change to:

```swift
private func sampleDiskSpace() -> (free: UInt64, total: UInt64) {
    let homePath = FileManager.default.homeDirectoryForCurrentUser.path
    guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: homePath),
          let freeSize = attributes[.systemFreeSize] as? NSNumber,
          let totalSize = attributes[.systemSize] as? NSNumber else {
        return (0, 0)
    }

    return (freeSize.uint64Value, totalSize.uint64Value)
}
```

In `sampleStorage()`, change:

```swift
let homePath = FileManager.default.homeDirectoryForCurrentUser.path
```

- [ ] **Step 4: Rename the stored property while preserving Codable compatibility**

In `MetricSnapshot`, rename the stored property:

```swift
public var runningApps: [ProcessMetric]
```

Do not keep a deprecated `topProcesses` property. It would cause internal deprecation warnings from any compatibility alias. Instead, keep the persisted JSON key stable by changing `CodingKeys` to map the new Swift property to the old key:

```swift
case runningApps = "topProcesses"
```

Update decoding:

```swift
runningApps = try values.decodeIfPresent([ProcessMetric].self, forKey: .runningApps) ?? []
```

Update encoding:

```swift
try values.encode(runningApps, forKey: .runningApps)
```

Update the `MetricSnapshot` initializer signature from:

```swift
topProcesses: [ProcessMetric] = []
```

to:

```swift
runningApps: [ProcessMetric] = []
```

and assign:

```swift
self.runningApps = runningApps
```

- [ ] **Step 5: Rename app-side references**

Replace app/widget UI references:

```swift
snapshot.runningApps
```

Use it in `DashboardView`, `MetricsStore.applyVisibleApplicationSummary`, widget compacting, shared snapshot compacting, and tests:

```swift
snapshot.runningApps
```

Update all `MetricSnapshot(...)` call sites to pass:

```swift
runningApps: []
```

or omit the argument when the default empty array is correct.

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter diskFallbackUsesCurrentUserHomeUrlInsteadOfNSHomeDirectoryString
swift test --filter runningAppInventoryUsesRunningAppsNamingAtAppBoundaries
swift test
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/SharedMetrics/SystemSampler.swift Sources/SharedMetrics/MetricSnapshot.swift Sources/SystemDashboardApp/MetricsStore.swift Sources/SystemDashboardApp/DashboardView.swift Sources/SystemDashboardWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "refactor: clarify disk and running app sampling"
```

---

## Task 3: Window Responsive Layout and Minimum Size Optimization

**Files:**
- Modify: `Sources/SystemDashboardApp/AppDelegate.swift`
- Modify: `Sources/SystemDashboardApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write failing tests for smaller minimum size and adaptive dashboard layout**

Add:

```swift
@Test func mainWindowSupportsThirteenInchFriendlyMinimumSize() throws {
    let appDelegate = try fixture("Sources/SystemDashboardApp/AppDelegate.swift")

    #expect(appDelegate.contains("window.minSize = NSSize(width: 960, height: 640)"))
    #expect(!appDelegate.contains("window.minSize = NSSize(width: 1180, height: 760)"))
}

@Test func dashboardUsesAdaptiveColumnsForCompactWindows() throws {
    let dashboard = try fixture("Sources/SystemDashboardApp/DashboardView.swift")

    #expect(dashboard.contains("private func adaptiveMetricColumns(for width: CGFloat) -> [GridItem]"))
    #expect(dashboard.contains("GeometryReader { proxy in"))
    #expect(dashboard.contains("adaptiveMetricColumns(for: proxy.size.width)"))
    #expect(dashboard.contains("if proxy.size.width < 1080"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter mainWindowSupportsThirteenInchFriendlyMinimumSize
swift test --filter dashboardUsesAdaptiveColumnsForCompactWindows
```

Expected: fail because current window min size is `1180x760` and dashboard uses fixed wide assumptions.

- [ ] **Step 3: Lower AppKit minimum size**

In `AppDelegate.createDashboardWindow()`, change:

```swift
window.minSize = NSSize(width: 960, height: 640)
```

Keep the initial content rect at `1320x860` so first launch still feels polished on larger displays.

- [ ] **Step 4: Add adaptive grid helpers**

In `DashboardView.swift`, add:

```swift
private func adaptiveMetricColumns(for width: CGFloat) -> [GridItem] {
    let count = width < 1080 ? 2 : 4
    return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
}

private func adaptiveSummaryColumns(for width: CGFloat) -> [GridItem] {
    let count = width < 1080 ? 2 : 4
    return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
}
```

- [ ] **Step 5: Wrap wide pages in GeometryReader**

For overview/process/status pages with four-column grids, replace fixed column arrays:

```swift
GeometryReader { proxy in
    ScrollView {
        LazyVGrid(columns: adaptiveMetricColumns(for: proxy.size.width), spacing: 12) {
            ...
        }
    }
}
```

For sections that currently use `HStack` with fixed `360` widths, add compact branching:

```swift
if proxy.size.width < 1080 {
    VStack(alignment: .leading, spacing: 12) {
        primaryPanel
        secondaryPanel
    }
} else {
    HStack(alignment: .top, spacing: 12) {
        primaryPanel.frame(width: 360)
        secondaryPanel
    }
}
```

- [ ] **Step 6: Run layout source tests**

Run:

```bash
swift test --filter mainWindowSupportsThirteenInchFriendlyMinimumSize
swift test --filter dashboardUsesAdaptiveColumnsForCompactWindows
swift test
```

Expected: all pass.

- [ ] **Step 7: Manual visual verification**

Run:

```bash
scripts/package-app.sh
open -n "dist/Pulse Dock.app"
```

Verify:
- window can be resized to `960x640`
- sidebar remains visible
- content scrolls instead of clipping
- card text does not overlap in Overview, CPU, Storage, Network, Status, History, Settings

- [ ] **Step 8: Commit**

```bash
git add Sources/SystemDashboardApp/AppDelegate.swift Sources/SystemDashboardApp/DashboardView.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: improve compact dashboard window layout"
```

---

## Task 4: Accessibility Semantics Completion

**Files:**
- Modify: `Sources/SystemDashboardApp/DashboardView.swift`
- Modify: `Sources/SystemDashboardApp/WidgetPanelView.swift`
- Modify: `Sources/SystemDashboardWidget/SystemDashboardWidget.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write failing tests for missing semantic groups**

Add:

```swift
@Test func dashboardRowsAndCardsExposeAccessibilitySemantics() throws {
    let dashboard = try fixture("Sources/SystemDashboardApp/DashboardView.swift")

    #expect(componentBody(named: "SummaryCard", in: dashboard).contains(".accessibilityElement(children: .combine)"))
    #expect(componentBody(named: "SummaryCard", in: dashboard).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "StatusSummaryRow", in: dashboard).contains(".accessibilityLabel(\"\\(title), \\(value), \\(status.text)\")"))
    #expect(componentBody(named: "SourceCapabilityCard", in: dashboard).contains(".accessibilityLabel(\"\\(title), \\(value), \\(source)\")"))
    #expect(componentBody(named: "TableRow", in: dashboard).contains(".accessibilityLabel(values.joined(separator: \", \"))"))
    #expect(componentBody(named: "StatLine", in: dashboard).contains(".accessibilityValue(progress.map(MetricFormatting.percentage) ?? \"未报告\")"))
    #expect(componentBody(named: "CoreUsageTile", in: dashboard).contains(".accessibilityLabel(\"Core \\(index), \\(MetricFormatting.percentage(value))\")"))
}

@Test func popoverAndWidgetMetricsExposeAccessibilitySemantics() throws {
    let popover = try fixture("Sources/SystemDashboardApp/WidgetPanelView.swift")
    let widget = try fixture("Sources/SystemDashboardWidget/SystemDashboardWidget.swift")

    #expect(componentBody(named: "PopoverMetricRow", in: popover).contains(".accessibilityLabel(\"\\(title), \\(value), \\(detail)\")"))
    #expect(componentBody(named: "PopoverSmallStat", in: popover).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "RingMetric", in: widget).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "WidgetRow", in: widget).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "MiniStatus", in: widget).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "StatTile", in: widget).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
}
```

Add helper in tests if missing:

```swift
private func componentBody(named name: String, in source: String) -> String {
    guard let start = source.range(of: "private struct \(name)")?.lowerBound else { return "" }
    let remainder = source[start...]
    if let next = remainder.dropFirst().range(of: "\nprivate struct ")?.lowerBound {
        return String(remainder[..<next])
    }
    return String(remainder)
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter dashboardRowsAndCardsExposeAccessibilitySemantics
swift test --filter popoverAndWidgetMetricsExposeAccessibilitySemantics
```

Expected: fail because several components still lack labels.

- [ ] **Step 3: Add dashboard accessibility modifiers**

Apply these patterns:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title), \(value)")
```

For status rows:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title), \(value), \(status.text)")
```

For table rows:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(values.joined(separator: ", "))
```

For progress rows:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(label), \(value)")
.accessibilityValue(progress.map(MetricFormatting.percentage) ?? "未报告")
```

For decorative symbols and dots:

```swift
.accessibilityHidden(true)
```

- [ ] **Step 4: Add popover and widget accessibility modifiers**

For `PopoverMetricRow`:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title), \(value), \(detail)")
.accessibilityValue(progress.map(MetricFormatting.percentage) ?? "未报告")
```

For `RingMetric` and `WidgetRow`:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title), \(value)")
.accessibilityValue(progress.map(MetricFormatting.percentage) ?? "未报告")
```

For `MiniStatus` and `StatTile`:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title), \(value)")
```

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter dashboardRowsAndCardsExposeAccessibilitySemantics
swift test --filter popoverAndWidgetMetricsExposeAccessibilitySemantics
swift test
```

Expected: all pass.

- [ ] **Step 6: Manual VoiceOver smoke test**

Run:

```bash
scripts/package-app.sh
open -n "dist/Pulse Dock.app"
```

Verify with VoiceOver:
- sidebar buttons announce page names
- metric cards announce title, value, and progress
- tables announce row values as one understandable row
- popover buttons and stat rows have meaningful labels
- widget labels do not read decorative dots as separate elements

- [ ] **Step 7: Commit**

```bash
git add Sources/SystemDashboardApp/DashboardView.swift Sources/SystemDashboardApp/WidgetPanelView.swift Sources/SystemDashboardWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: complete accessibility labels"
```

---

## Task 5: Threshold Copy Cleanup and Notification Deferral

**Files:**
- Modify: `Sources/SystemDashboardApp/DashboardView.swift`
- Modify: `docs/data-capability-audit.md`
- Modify: `docs/app-store-readiness-checklist.md`
- Modify: `docs/app-store-release-checklist.md`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write failing tests for v1 threshold copy and notification deferral**

Add:

```swift
@Test func thresholdFeatureUsesJudgmentCopyAndDoesNotAddNotificationPermissionInV1() throws {
    let dashboard = try fixture("Sources/SystemDashboardApp/DashboardView.swift")
    let appDelegate = try fixture("Sources/SystemDashboardApp/AppDelegate.swift")
    let metricsStore = try fixture("Sources/SystemDashboardApp/MetricsStore.swift")
    let appPrivacy = try fixture("Resources/App/PrivacyInfo.xcprivacy")
    let audit = try fixture("docs/data-capability-audit.md")
    let releaseChecklist = try fixture("docs/app-store-release-checklist.md")

    #expect(dashboard.contains("本地采样历史与阈值判断"))
    #expect(dashboard.contains("DashboardPanel(title: \"状态判断\", subtitle: \"当前采样的本地结果\""))
    #expect(!dashboard.contains("本地采样历史与告警"))
    #expect(!dashboard.contains("Toggle(\"系统通知\""))
    #expect(!appDelegate.contains("UNUserNotificationCenter"))
    #expect(!metricsStore.contains("AlertNotificationController"))
    #expect(!appPrivacy.contains("UserNotifications"))
    #expect(audit.contains("Status thresholds are dashboard-only for v1."))
    #expect(releaseChecklist.contains("Local notifications are deferred to a future opt-in feature."))
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
swift test --filter thresholdFeatureUsesJudgmentCopyAndDoesNotAddNotificationPermissionInV1
```

Expected: fail because current copy still uses at least one "告警" framing and the docs do not record the v1 deferral decision.

- [ ] **Step 3: Rename user-facing threshold copy**

Change page subtitle from:

```swift
case .history: "本地采样历史与告警"
```

to:

```swift
case .history: "本地采样历史与阈值判断"
```

Keep the existing `状态判断` panel title because it accurately describes the current dashboard-only behavior.

- [ ] **Step 4: Do not add notification code in v1**

Do not create any of these in this polish plan:

```text
Sources/SystemDashboardApp/AlertNotificationController.swift
UNUserNotificationCenter
UNMutableNotificationContent
notification permission toggles
```

Privacy-manifest judgment: `UserNotifications` is not a Required Reason API category, but since v1 does not add notifications, no privacy manifest change and no notification permission prompt are introduced.

- [ ] **Step 5: Document notification deferral**

Add to `docs/data-capability-audit.md`:

```markdown
- Status thresholds are dashboard-only for v1. The app does not request notification permissions or badge privileges.
```

Add to `docs/app-store-release-checklist.md`:

```markdown
- Local notifications are deferred to a future opt-in feature. If implemented later, update user-facing copy, permission-flow testing, support/privacy docs, and App Store Connect metadata before submission.
```

Add to `docs/app-store-readiness-checklist.md`:

```markdown
- [x] Threshold copy says "阈值判断" / "状态判断" for v1 and does not imply system notifications.
- [ ] Future: design opt-in local threshold notifications in a separate v1.1 feature plan.
```

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter thresholdFeatureUsesJudgmentCopyAndDoesNotAddNotificationPermissionInV1
swift test
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/SystemDashboardApp/DashboardView.swift docs/data-capability-audit.md docs/app-store-readiness-checklist.md docs/app-store-release-checklist.md Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "docs: clarify threshold status behavior"
```

---

## Task 6: Localization Release Gate

**Files:**
- Create: `scripts/audit-localization.sh`
- Modify: `Resources/AppInfo.plist`
- Modify: `Resources/WidgetInfo.plist`
- Modify: `docs/app-store-readiness-checklist.md`
- Modify: `docs/app-store-release-checklist.md`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

This task intentionally does not add partial English localization. The current codebase has hundreds of Chinese user-facing strings across `DashboardView.swift`, `WidgetPanelView.swift`, `SystemDashboardWidget.swift`, and `MetricSnapshot.swift`. Translating only menus and page names would produce a mixed-language product. Choose exactly one release path:

- China-only v1: keep `CFBundleLocalizations = [zh-Hans]`, keep storefront availability limited to China, and do not claim English support.
- Global v1: stop this polish plan and execute a separate full localization sprint that extracts every user-facing string before App Store submission.

- [ ] **Step 1: Write failing tests for no-partial-English release gate**

Add:

```swift
@Test func localizationGatePreventsPartialEnglishSupport() throws {
    let appInfo = try fixture("Resources/AppInfo.plist")
    let widgetInfo = try fixture("Resources/WidgetInfo.plist")
    let readiness = try fixture("docs/app-store-readiness-checklist.md")
    let release = try fixture("docs/app-store-release-checklist.md")

    #expect(appInfo.contains("<string>zh-Hans</string>"))
    #expect(widgetInfo.contains("<string>zh-Hans</string>"))
    #expect(!appInfo.contains("<string>en</string>"))
    #expect(!widgetInfo.contains("<string>en</string>"))
    #expect(readiness.contains("v1 localization decision: zh-Hans only unless full localization audit passes."))
    #expect(release.contains("Do not submit as a global English-localized app until scripts/audit-localization.sh reports zero Swift Chinese string findings."))
}

@Test func localizationAuditScriptExistsForFutureGlobalRelease() throws {
    let script = try fixture("scripts/audit-localization.sh")

    #expect(script.contains("rg --pcre2"))
    #expect(script.contains("\\\\p{Script=Han}"))
    #expect(script.contains("Sources/SystemDashboardApp"))
    #expect(script.contains("Sources/SystemDashboardWidget"))
    #expect(script.contains("Sources/SharedMetrics"))
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter localizationGatePreventsPartialEnglishSupport
swift test --filter localizationAuditScriptExistsForFutureGlobalRelease
```

Expected: fail because the audit script and release-gate checklist text do not exist.

- [ ] **Step 3: Add localization audit script for future global release**

Create `scripts/audit-localization.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

matches="$(
  rg --pcre2 -n '\p{Script=Han}' \
    Sources/SystemDashboardApp \
    Sources/SystemDashboardWidget \
    Sources/SharedMetrics \
    --glob '*.swift' \
    || true
)"

if [[ -n "$matches" ]]; then
  echo "Found Chinese text in Swift sources. Full English release is blocked until each user-facing string is localized:" >&2
  echo "$matches" >&2
  exit 1
fi

echo "Localization audit passed: no Chinese text remains in Swift sources."
```

Make it executable:

```bash
chmod +x scripts/audit-localization.sh
```

- [ ] **Step 4: Keep v1 metadata zh-Hans only unless full localization is executed**

Confirm `Resources/AppInfo.plist` and `Resources/WidgetInfo.plist` contain only:

```xml
<key>CFBundleLocalizations</key>
<array>
  <string>zh-Hans</string>
</array>
```

Do not add:

```xml
<string>en</string>
```

until `scripts/audit-localization.sh` passes and English `Localizable.strings` resources cover app, widget, shared metric formatting, support docs, privacy docs, screenshots, and App Store metadata.

- [ ] **Step 5: Record the storefront decision**

Add to `docs/app-store-readiness-checklist.md`:

```markdown
- [x] v1 localization decision: zh-Hans only unless full localization audit passes.
- [ ] If shipping v1 globally, complete a separate full localization sprint before App Store submission.
- [ ] If shipping v1 without full localization, limit App Store Connect availability to Chinese-language storefronts.
```

Add to `docs/app-store-release-checklist.md`:

```markdown
- Do not submit as a global English-localized app until scripts/audit-localization.sh reports zero Swift Chinese string findings and App Store metadata/screenshots are available in English.
```

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter localizationGatePreventsPartialEnglishSupport
swift test --filter localizationAuditScriptExistsForFutureGlobalRelease
swift test
```

Expected: all tests pass. `scripts/audit-localization.sh` is expected to fail on the current Chinese-first codebase; that failure is the intentional gate for global English release.

- [ ] **Step 7: Commit**

```bash
git add scripts/audit-localization.sh Resources/AppInfo.plist Resources/WidgetInfo.plist docs/app-store-readiness-checklist.md docs/app-store-release-checklist.md Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "docs: gate partial English localization"
```

---

## Task 7: Screenshot Assets and Validation

**Files:**
- Add: `docs/app-store/screenshots/01-overview.png`
- Add: `docs/app-store/screenshots/02-cpu-memory.png`
- Add: `docs/app-store/screenshots/03-network-storage.png`
- Add: `docs/app-store/screenshots/04-widget-popover.png`
- Add: `docs/app-store/screenshots/05-settings-history.png`
- Modify: `scripts/validate-app-store-screenshots.sh`
- Modify: `docs/app-store-release-checklist.md`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write failing screenshot asset test**

Add:

```swift
@Test func appStoreScreenshotsExistWithRequiredNamesAndValidationGate() throws {
    let script = try fixture("scripts/validate-app-store-screenshots.sh")

    #expect(fileExists("docs/app-store/screenshots/01-overview.png"))
    #expect(fileExists("docs/app-store/screenshots/02-cpu-memory.png"))
    #expect(fileExists("docs/app-store/screenshots/03-network-storage.png"))
    #expect(fileExists("docs/app-store/screenshots/04-widget-popover.png"))
    #expect(fileExists("docs/app-store/screenshots/05-settings-history.png"))
    #expect(script.contains("Use one of: 2880x1800, 2560x1600, 1440x900, 1280x800."))
}
```

If `fileExists` helper does not exist, add:

```swift
private func fileExists(_ relativePath: String) -> Bool {
    FileManager.default.fileExists(atPath: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
        .path)
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
swift test --filter appStoreScreenshotsExistWithRequiredNamesAndValidationGate
```

Expected: fail because screenshots are absent.

- [ ] **Step 3: Capture screenshots**

Package and launch:

```bash
scripts/package-app.sh
open -n "dist/Pulse Dock.app"
```

Capture five screenshots at `2880x1800` or `1280x800`:
- `01-overview.png`: overview dashboard with sidebar visible
- `02-cpu-memory.png`: CPU page or memory page with detailed metrics
- `03-network-storage.png`: network/storage page showing tables and cards
- `04-widget-popover.png`: menu bar popover and widget preview
- `05-settings-history.png`: settings/history threshold controls

Place files in:

```bash
docs/app-store/screenshots/
```

- [ ] **Step 4: Improve validation output**

In `scripts/validate-app-store-screenshots.sh`, after the count failure message, add:

```bash
echo "Expected files: 01-overview.png, 02-cpu-memory.png, 03-network-storage.png, 04-widget-popover.png, 05-settings-history.png." >&2
```

- [ ] **Step 5: Validate screenshots**

Run:

```bash
scripts/validate-app-store-screenshots.sh
```

Expected:

```text
Validated 5 Mac App Store screenshot(s) in /Users/qiaoni/Code/Projects/xiaozujian/docs/app-store/screenshots.
```

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter appStoreScreenshotsExistWithRequiredNamesAndValidationGate
swift test
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add docs/app-store/screenshots/01-overview.png docs/app-store/screenshots/02-cpu-memory.png docs/app-store/screenshots/03-network-storage.png docs/app-store/screenshots/04-widget-popover.png docs/app-store/screenshots/05-settings-history.png scripts/validate-app-store-screenshots.sh docs/app-store-release-checklist.md Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "docs: add app store screenshots"
```

---

## Task 8: Deferred Legacy Naming Residue Cleanup

**Files:**
- Move: `Sources/SystemDashboardApp` to `Sources/PulseDockApp`
- Move: `Sources/SystemDashboardWidget` to `Sources/PulseDockWidget`
- Modify: `Package.swift`
- Modify: `scripts/generate-xcodeproj.rb`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Modify: `docs/app-store-readiness-checklist.md`
- Modify: `docs/app-store-release-checklist.md`

This is a high-churn mechanical cleanup, not an App Review blocker. Execute it only after Tasks 1-7 and Task 9 are green, or defer it until after v1 ships. Do not add new tests against `Sources/SystemDashboardApp` or `Sources/SystemDashboardWidget` after this task starts; this task changes path assumptions across the test suite and docs in one pass.

- [ ] **Step 1: Write failing tests for Pulse Dock source paths**

Add:

```swift
@Test func sourceLayoutUsesPulseDockNamesInsteadOfSystemDashboardResidue() throws {
    let package = try fixture("Package.swift")
    let generator = try fixture("scripts/generate-xcodeproj.rb")

    #expect(directoryExists("Sources/PulseDockApp"))
    #expect(directoryExists("Sources/PulseDockWidget"))
    #expect(!directoryExists("Sources/SystemDashboardApp"))
    #expect(!directoryExists("Sources/SystemDashboardWidget"))
    #expect(package.contains("path: \"Sources/PulseDockApp\""))
    #expect(generator.contains("\"Sources/PulseDockApp/*.swift\""))
    #expect(generator.contains("\"Sources/PulseDockWidget/*.swift\""))
}
```

If `directoryExists` helper does not exist, add:

```swift
private func directoryExists(_ relativePath: String) -> Bool {
    var isDirectory: ObjCBool = false
    let path = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
        .path
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
swift test --filter sourceLayoutUsesPulseDockNamesInsteadOfSystemDashboardResidue
```

Expected: fail because directories still use `SystemDashboard*`.

- [ ] **Step 3: Move source directories**

Run:

```bash
git mv Sources/SystemDashboardApp Sources/PulseDockApp
git mv Sources/SystemDashboardWidget Sources/PulseDockWidget
```

- [ ] **Step 4: Update package and generator paths**

In `Package.swift`:

```swift
path: "Sources/PulseDockApp"
```

In `scripts/generate-xcodeproj.rb`:

```ruby
app_group = project.new_group("PulseDockApp", "Sources/PulseDockApp")
widget_group = project.new_group("PulseDockWidget", "Sources/PulseDockWidget")
app_files = Dir.glob(File.join(root, "Sources/PulseDockApp/*.swift")).sort.map { |path| app_group.new_file(path) }
widget_files = Dir.glob(File.join(root, "Sources/PulseDockWidget/*.swift")).sort.map { |path| widget_group.new_file(path) }
```

- [ ] **Step 5: Update tests and docs paths**

Replace old paths in tests and docs:

```text
Sources/SystemDashboardApp
Sources/SystemDashboardWidget
```

with:

```text
Sources/PulseDockApp
Sources/PulseDockWidget
```

- [ ] **Step 6: Regenerate project**

Run:

```bash
scripts/generate-xcodeproj.rb
```

Expected:

```text
/Users/qiaoni/Code/Projects/xiaozujian/PulseDock.xcodeproj
```

- [ ] **Step 7: Run tests**

Run:

```bash
swift build
swift test --filter sourceLayoutUsesPulseDockNamesInsteadOfSystemDashboardResidue
swift test
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add Package.swift scripts/generate-xcodeproj.rb Sources/PulseDockApp Sources/PulseDockWidget Tests/SharedMetricsTests/MetricFormattingTests.swift docs/app-store-readiness-checklist.md docs/app-store-release-checklist.md
git add -u Sources/SystemDashboardApp Sources/SystemDashboardWidget
git commit -m "refactor: rename source folders for Pulse Dock"
```

---

## Task 9: App Store URL and Documentation Hardening

**Files:**
- Modify: `Resources/AppInfo.plist`
- Modify: `README.md`
- Modify: `docs/app-store/privacy-policy.md`
- Modify: `docs/app-store/support.md`
- Modify: `docs/app-store-release-checklist.md`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write failing tests for stable public URLs**

Add:

```swift
@Test func privacyAndSupportUrlsUseStablePublicPages() throws {
    let appInfo = try fixture("Resources/AppInfo.plist")
    let readme = try fixture("README.md")

    #expect(appInfo.contains("https://ifonly3.github.io/pulsedock/privacy-policy/"))
    #expect(appInfo.contains("https://ifonly3.github.io/pulsedock/support/"))
    #expect(readme.contains("https://ifonly3.github.io/pulsedock/privacy-policy/"))
    #expect(readme.contains("https://ifonly3.github.io/pulsedock/support/"))
    #expect(!appInfo.contains("github.com/ifonly3/pulsedock/blob/main/docs/app-store"))
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
swift test --filter privacyAndSupportUrlsUseStablePublicPages
```

Expected: fail because current URLs point to GitHub blob pages.

- [ ] **Step 3: Update URLs**

Change `Resources/AppInfo.plist`:

```xml
<key>PulseDockPrivacyPolicyURL</key>
<string>https://ifonly3.github.io/pulsedock/privacy-policy/</string>
<key>PulseDockSupportURL</key>
<string>https://ifonly3.github.io/pulsedock/support/</string>
```

Change `README.md` to the same URLs.

- [ ] **Step 4: Publish docs**

Publish the content of:

```text
docs/app-store/privacy-policy.md
docs/app-store/support.md
```

to:

```text
https://ifonly3.github.io/pulsedock/privacy-policy/
https://ifonly3.github.io/pulsedock/support/
```

- [ ] **Step 5: Verify URLs**

Run:

```bash
curl --max-time 15 -L -I https://ifonly3.github.io/pulsedock/privacy-policy/
curl --max-time 15 -L -I https://ifonly3.github.io/pulsedock/support/
```

Expected: both return HTTP 200.

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter privacyAndSupportUrlsUseStablePublicPages
swift test
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Resources/AppInfo.plist README.md docs/app-store/privacy-policy.md docs/app-store/support.md docs/app-store-release-checklist.md Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "docs: use stable app store support urls"
```

---

## Task 10: Final Build, Archive Dry Run, and Release Checklist

**Files:**
- Modify: `docs/app-store-readiness-checklist.md`
- Modify: `docs/app-store-release-checklist.md`

- [ ] **Step 1: Run full SwiftPM verification**

Run:

```bash
swift build
swift test
```

Expected:
- `swift build` exits 0
- `swift test` reports 236 or more tests passing with 0 failures

- [ ] **Step 2: Regenerate Xcode project**

Run:

```bash
scripts/generate-xcodeproj.rb
```

Expected:

```text
/Users/qiaoni/Code/Projects/xiaozujian/PulseDock.xcodeproj
```

- [ ] **Step 3: Build local signed test bundle**

Run:

```bash
scripts/package-app.sh
```

Expected:

```text
/Users/qiaoni/Code/Projects/xiaozujian/dist/Pulse Dock.app
```

- [ ] **Step 4: Verify binary architecture and signatures**

Run:

```bash
lipo -archs "dist/Pulse Dock.app/Contents/MacOS/Pulse Dock"
lipo -archs "dist/Pulse Dock.app/Contents/PlugIns/PulseDockWidgetExtension.appex/Contents/MacOS/PulseDockWidgetExtension"
codesign --verify --deep --strict --verbose=2 "dist/Pulse Dock.app"
find "dist/Pulse Dock.app" -name 'PrivacyInfo.xcprivacy' -print
```

Expected:
- both binaries print `x86_64 arm64`
- codesign exits 0
- app and widget each contain one `PrivacyInfo.xcprivacy`

- [ ] **Step 5: Validate screenshots**

Run:

```bash
scripts/validate-app-store-screenshots.sh
```

Expected: validates 5 screenshots.

- [ ] **Step 6: Launch smoke test**

Run:

```bash
open -n "dist/Pulse Dock.app"
sleep 5
pgrep -x "Pulse Dock"
osascript -e 'tell application "Pulse Dock" to quit'
```

Expected:
- `pgrep` prints a process id before quit
- app exits after AppleScript quit

- [ ] **Step 7: Update release checklists**

In `docs/app-store-readiness-checklist.md`, mark:

```markdown
- [x] App Store screenshots prepared and validated
- [x] Core custom UI accessibility labels completed
- [x] Widget reads shared latest app snapshot through App Group with self-sampling fallback
- [x] App Group provisioning prerequisite documented for production signing
- [x] v1 localization decision recorded: zh-Hans only unless a full localization audit passes
- [x] Window minimum size lowered and compact layouts verified
- [x] Disk fallback no longer uses NSHomeDirectory string path
- [x] Threshold copy says "阈值判断" / "状态判断" and local notifications are deferred
- [x] Running app naming replaces top-process wording at user-facing boundaries
- [x] Pulse Dock source folder names replace System Dashboard residue, if deferred cleanup task is executed
```

- [ ] **Step 8: Final status**

Run:

```bash
git status --short
```

Expected: only intended changes are present.

- [ ] **Step 9: Commit checklist update**

```bash
git add docs/app-store-readiness-checklist.md docs/app-store-release-checklist.md
git commit -m "docs: update app store readiness checklist"
```

---

## Self-Review Checklist

- Spec coverage:
  - Screenshots: Task 7.
  - Window ratio and minimum size: Task 3.
  - Accessibility gaps: Task 4.
  - Widget/app data consistency: Task 1.
  - English/global release support: Task 6 gates partial English and requires a separate full localization sprint before global submission.
  - `NSHomeDirectory()` cleanup: Task 2.
  - Threshold behavior: Task 5 clarifies v1 dashboard-only threshold judgment and defers notification permissions.
  - `topProcesses` naming: Task 2.
  - Legacy System Dashboard naming residue: Task 8, deferred final mechanical cleanup.
  - URL hardening: Task 9.
  - Final verification: Task 10.
- Placeholder scan: no step relies on undefined “fill in” work; each task names concrete files, commands, expected results, and code patterns.
- Type consistency:
  - `SharedSnapshotStore` is shared and used by app/widget.
  - `PulseDockAppGroup.suiteName` is the single source for the suite name.
  - `runningApps` becomes the Swift stored property while `CodingKeys.runningApps = "topProcesses"` preserves persisted JSON compatibility.
  - No notification controller is introduced in v1; no `UserNotifications` dependency enters the app/widget/shared targets.
