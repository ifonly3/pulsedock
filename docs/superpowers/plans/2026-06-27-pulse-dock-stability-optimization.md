# Pulse Dock Stability And Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the verified sampler crash risks, fix user-visible metric semantics, and add release gates so Pulse Dock stays robust for App Store submission.

**Architecture:** Keep hardening in the owning layer: conversion and sampling safety in `SharedMetrics`, pause/resume behavior in `PulseDockApp`, widget rendering cleanup in `PulseDockWidget`, and release verification in scripts/tests. Use the current Swift Testing pattern plus focused source-level gates where private IOKit paths cannot be unit-tested directly. Do not add permissions, network services, analytics, or new product features.

**Tech Stack:** Swift 6, SwiftUI, AppKit, WidgetKit, IOKit, Network, SystemConfiguration, Swift Testing, SwiftPM, Xcode project generation scripts, shell validation scripts.

---

## Verified Findings Covered

| ID | Priority | Plan Task | Status From Review |
| --- | --- | --- | --- |
| 1 | P0 | Task 1 | `Int(Double.nan)` / `Int(Double.infinity)` traps are reproducible. |
| 2 | P0 | Task 1 | `Int(UInt64.max)` traps are reproducible. |
| 3 | P1 | Task 2 | CPU baseline reset is missing; current hidden warm-up hides the visible spike but explicit reset is cleaner. |
| 4 | P1 | Task 3 | Battery power at high charge is incorrectly warning-colored. |
| 5 | P2 | Task 4 | Byte formatting stops at TB. |
| 6 | P2 | Task 4 | Durations below 60 seconds render as `0m`. |
| 7 | P2 | Task 5 | Shared snapshot encoding errors are silently swallowed. |
| 8 | P2 | Task 2 | Battery sampling is uncached and calls IOKit every refresh tick. |
| 9 | P2 | Task 6 | Network interface `kind` mixes localized display text with sort keys. |
| 10 | OPT | Task 8 | Popover close suppression interval is a magic number. |
| 11 | P2 | Task 6 | Network rate progress uses undocumented fixed linear baselines. |
| 12 | P2 | Task 7 | `WidgetSamplerCache` stores dead priming state. |
| 13 | P2 | Task 7 | Unknown widget families default to the large widget layout. |
| 14 | OPT | Task 8 | `MetricSnapshot` initializer defaults call `ProcessInfo`. |
| 15 | OPT | Task 8 | `NetworkPathObserver` starts during `SystemSampler` initialization and is hard to inject. |
| 16 | P2 | Task 7 | `swift test` does not compile `Sources/PulseDockWidget`. |

## Execution Dependencies

- Execute Task 2 before Task 8. Both tasks modify `SystemSampler.init`; Task 2 first adds `batteryCacheInterval`, and Task 8 later wraps that initializer in a public convenience initializer with an injectable `NetworkPathObserving` initializer.
- Execute Task 7 after the `#if !SWIFT_PACKAGE` guard is added around the widget bundle `@main`. Adding `Sources/PulseDockWidget` as a SwiftPM library target before guarding `@main` will make `swift test` fail with `'@main' is only available in executable targets`.

## File Structure

- Modify `Sources/SharedMetrics/SystemSampler.swift`
  - Add finite and exact numeric conversion helpers.
  - Add CPU baseline reset and battery sampling cache.
  - Separate network interface sort keys from localized display kinds.
  - Make network path observation injectable for tests.

- Modify `Sources/PulseDockApp/MetricsStore.swift`
  - Reset CPU and network baselines on resume.
  - Keep the existing warm-up sample behavior.

- Modify `Sources/SharedMetrics/MetricSnapshot.swift`
  - Adjust power status tone thresholds.
  - Replace `ProcessInfo` defaults with placeholder-safe values.

- Modify `Sources/SharedMetrics/MetricFormatting.swift`
  - Add PB/EB units.
  - Render sub-minute durations as `<1m`.

- Modify `Sources/SharedMetrics/SharedSnapshotStore.swift`
  - Return a success flag from shared snapshot writes.
  - Log encoding failures in debug builds.

- Create `Sources/SharedMetrics/MetricScales.swift`
  - Centralize network throughput progress scaling.
  - Replace unexplained 40 MB/s and 20 MB/s inline baselines.

- Modify `Sources/PulseDockApp/DashboardView.swift`
  - Use `MetricScales.networkRateProgress(bytesPerSecond:)`.
  - Use the same progress helper for history trend values.

- Modify `Sources/PulseDockApp/WidgetPanelView.swift`
  - Use `MetricScales.networkRateProgress(bytesPerSecond:)`.

- Modify `Sources/PulseDockWidget/SystemDashboardWidget.swift`
  - Remove dead cache state.
  - Render unknown widget families with a compact fallback.

- Modify `Package.swift`
  - Add a SwiftPM `PulseDockWidget` target so `swift test` compiles widget source.
  - Add `PulseDockWidget` as a dependency of `SharedMetricsTests`.

- Modify `scripts/generate-xcodeproj.rb`
  - Keep WidgetKit extension generation aligned with any new shared source files.

- Modify `scripts/validate-public-pages.sh` only if Pages validation needs to include new release checks. The current script should remain unchanged for this plan unless a test fails.

- Modify `Tests/SharedMetricsTests/MetricFormattingTests.swift`
  - Add behavioral tests for formatters, shared snapshot store, power tone, and source-level gates for private sampler paths.
  - Update existing assertions that encode old behavior.

- Modify `Tests/SharedMetricsTests/LocalizationGateTests.swift` only if adding the SwiftPM widget target changes resource assertions.

- Modify `docs/data-capability-audit.md`
  - Document conversion hardening, battery cache interval, shared snapshot failure behavior, and widget compile gate.

- Modify `docs/app-store-release-checklist.md`
  - Add the final Xcode build gate for widget compilation.

---

### Task 1: Harden Numeric Conversion In SystemSampler

**Files:**
- Modify: `Sources/SharedMetrics/SystemSampler.swift:510-537`
- Modify: `Sources/SharedMetrics/SystemSampler.swift:1205-1218`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write failing source-level tests for non-trapping conversions**

Add this test near the existing sampler safety tests in `Tests/SharedMetricsTests/MetricFormattingTests.swift`:

```swift
@Test func systemSamplerRejectsNonFiniteAndOverflowingBatteryNumbersBeforeIntConversion() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(sampler.contains("private func finiteInt(_ value: Double?) -> Int?"))
    #expect(sampler.contains("guard let value, value.isFinite else { return nil }"))
    #expect(sampler.contains("return Int(exactly: value)"))
    #expect(sampler.contains("currentCapacity: finiteInt(current)"))
    #expect(sampler.contains("maxCapacity: finiteInt(maximum)"))
    #expect(sampler.contains("if let value = value as? Int64 { return Int(exactly: value) }"))
    #expect(sampler.contains("if let value = value as? UInt64 { return Int(exactly: value) }"))
    #expect(!sampler.contains("current.map(Int.init)"))
    #expect(!sampler.contains("maximum.map(Int.init)"))
    #expect(!sampler.contains("if let value = value as? UInt64 { return Int(value) }"))
}
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run:

```bash
swift test --filter systemSamplerRejectsNonFiniteAndOverflowingBatteryNumbersBeforeIntConversion
```

Expected: FAIL because `finiteInt(_:)` is not present and `current.map(Int.init)` still exists.

- [ ] **Step 3: Replace direct Double-to-Int battery conversion**

In `Sources/SharedMetrics/SystemSampler.swift`, change the `BatterySample` construction from:

```swift
currentCapacity: current.map(Int.init),
maxCapacity: maximum.map(Int.init),
```

to:

```swift
currentCapacity: finiteInt(current),
maxCapacity: finiteInt(maximum),
```

- [ ] **Step 4: Add finite/exact conversion helpers**

Replace `intValue(_:)` and `doubleValue(_:)` in `Sources/SharedMetrics/SystemSampler.swift` with:

```swift
private func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? Int64 { return Int(exactly: value) }
    if let value = value as? UInt64 { return Int(exactly: value) }
    if let value = value as? NSNumber { return finiteInt(value.doubleValue) }
    if let value = value as? String { return Int(value) }
    return nil
}

private func doubleValue(_ value: Any?) -> Double? {
    let converted: Double?
    if let value = value as? Double {
        converted = value
    } else if let value = value as? NSNumber {
        converted = value.doubleValue
    } else if let value = value as? String {
        converted = Double(value)
    } else {
        converted = nil
    }

    guard let converted, converted.isFinite else { return nil }
    return converted
}

private func finiteInt(_ value: Double?) -> Int? {
    guard let value, value.isFinite else { return nil }
    return Int(exactly: value)
}
```

- [ ] **Step 5: Run targeted and numeric trap sanity checks**

Run:

```bash
swift test --filter systemSamplerRejectsNonFiniteAndOverflowingBatteryNumbersBeforeIntConversion
swift -e 'import Foundation; print(Int(exactly: Double.nan) as Any); print(Int(exactly: UInt64.max) as Any)'
```

Expected:

```text
nil
nil
```

and the Swift test passes.

- [ ] **Step 6: Commit**

```bash
git add Sources/SharedMetrics/SystemSampler.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: harden sampler numeric conversions"
```

---

### Task 2: Reset CPU Baselines And Cache Battery Samples

**Files:**
- Modify: `Sources/SharedMetrics/SystemSampler.swift:201-240`
- Modify: `Sources/SharedMetrics/SystemSampler.swift:480-538`
- Modify: `Sources/PulseDockApp/MetricsStore.swift:116-128`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Write failing tests for resume baseline reset and battery cache**

Add this test near `appRefreshAndWidgetTimelineAvoidUnnecessaryWakeups()`:

```swift
@Test func resumeResetsCPUAndNetworkBaselinesAndBatterySamplingIsCached() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(sampler.contains("private var batteryCache: TimedSample<BatterySample>?"))
    #expect(sampler.contains("private let batteryCacheInterval: TimeInterval"))
    #expect(sampler.contains("public func resetCPUBaselines()"))
    #expect(sampler.contains("previousCPUInfo = []"))
    #expect(sampler.contains("private func cachedBattery(now: Date) -> BatterySample"))
    #expect(sampler.contains("let age = now.timeIntervalSince(sample.timestamp)"))
    #expect(sampler.contains("return cacheInterval > 0 && age >= 0 && age < cacheInterval"))
    #expect(sampler.contains("isCacheFresh(batteryCache, now: now, interval: batteryCacheInterval)"))
    #expect(sampler.contains("let battery = cachedBattery(now: now)"))
    #expect(sampler.contains("public init(inventoryCacheInterval: TimeInterval = 15, batteryCacheInterval: TimeInterval = 5)"))
    #expect(!sampler.contains("public init(inventoryCacheInterval: TimeInterval = 15)"))
    #expect(metricsStore.contains("sampler.resetNetworkBaselines()"))
    #expect(metricsStore.contains("sampler.resetCPUBaselines()"))
    #expect(audit.contains("Battery sampling is cached briefly to avoid IOKit IPC on every dashboard tick."))
}
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run:

```bash
swift test --filter resumeResetsCPUAndNetworkBaselinesAndBatterySamplingIsCached
```

Expected: FAIL because `resetCPUBaselines()` and `batteryCache` do not exist.

- [ ] **Step 3: Add CPU baseline reset and battery cache state**

In `Sources/SharedMetrics/SystemSampler.swift`, add state beside the existing caches:

```swift
private var batteryCache: TimedSample<BatterySample>?
private let batteryCacheInterval: TimeInterval
```

Replace the initializer with:

```swift
public init(inventoryCacheInterval: TimeInterval = 15, batteryCacheInterval: TimeInterval = 5) {
    self.inventoryCacheInterval = max(0, inventoryCacheInterval)
    self.batteryCacheInterval = max(0, batteryCacheInterval)
    self.systemInfo = Self.sampleSystemInfo()
}
```

Add this method below `resetNetworkBaselines()`:

```swift
public func resetCPUBaselines() {
    sampleLock.lock()
    defer { sampleLock.unlock() }

    previousCPUInfo = []
}
```

- [ ] **Step 4: Use cached battery sampling**

Change the sampling line in `sample(now:)` from:

```swift
let battery = sampleBattery()
```

to:

```swift
let battery = cachedBattery(now: now)
```

Add this helper near the other cached sample helpers:

```swift
private func cachedBattery(now: Date) -> BatterySample {
    if let batteryCache,
       isCacheFresh(batteryCache, now: now, interval: batteryCacheInterval) {
        return batteryCache.value
    }

    let sample = sampleBattery()
    batteryCache = TimedSample(timestamp: now, value: sample)
    return sample
}
```

If `isCacheFresh` only accepts the inventory interval today, replace it with this overload:

```swift
private func isCacheFresh<Value>(_ sample: TimedSample<Value>, now: Date, interval: TimeInterval? = nil) -> Bool {
    let cacheInterval = interval ?? inventoryCacheInterval
    let age = now.timeIntervalSince(sample.timestamp)
    return cacheInterval > 0 && age >= 0 && age < cacheInterval
}
```

- [ ] **Step 5: Update the existing static inventory cache assertion**

In `Tests/SharedMetricsTests/MetricFormattingTests.swift`, update the existing `systemSamplerCachesStaticInventoryBetweenLiveRefreshes()` assertion from:

```swift
#expect(sampler.contains("public init(inventoryCacheInterval: TimeInterval = 15)"))
```

to:

```swift
#expect(sampler.contains("public init(inventoryCacheInterval: TimeInterval = 15, batteryCacheInterval: TimeInterval = 5)"))
```

Also update its battery assertion from:

```swift
#expect(sampler.contains("let battery = sampleBattery()"))
```

to:

```swift
#expect(sampler.contains("let battery = cachedBattery(now: now)"))
```

- [ ] **Step 6: Reset CPU baseline on resume**

In `Sources/PulseDockApp/MetricsStore.swift`, change the resume block to:

```swift
} else {
    sampler.resetNetworkBaselines()
    sampler.resetCPUBaselines()
    scheduleTimer()
    startInitialRefresh()
}
```

- [ ] **Step 7: Update the audit document**

Add this bullet to `docs/data-capability-audit.md` near the sampler performance notes:

```markdown
- Battery sampling is cached briefly to avoid IOKit IPC on every dashboard tick while keeping power status responsive.
```

- [ ] **Step 8: Run targeted and full tests**

Run:

```bash
swift test --filter resumeResetsCPUAndNetworkBaselinesAndBatterySamplingIsCached
swift test
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add Sources/SharedMetrics/SystemSampler.swift Sources/PulseDockApp/MetricsStore.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: reset CPU baseline and cache battery samples"
```

---

### Task 3: Fix Power Status Tone Semantics

**Files:**
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift:1283-1315`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift:8859-8900`

- [ ] **Step 1: Update the behavioral power tone test**

Replace `powerToneDistinguishesChargingBatteryAndLowPowerStates()` with:

```swift
@Test func powerToneDistinguishesChargingBatteryAndPowerLevels() {
    let chargingHigh = MetricSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.82,
        batteryIsCharging: true,
        batteryPowerSource: "AC Power",
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let batteryHigh = MetricSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.82,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let batteryMedium = MetricSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.34,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let batteryLow = MetricSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.12,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 1)
    )

    #expect(chargingHigh.powerStatusTone == .normal)
    #expect(batteryHigh.powerStatusTone == .normal)
    #expect(batteryMedium.powerStatusTone == .warning)
    #expect(batteryLow.powerStatusTone == .critical)
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
swift test --filter powerToneDistinguishesChargingBatteryAndPowerLevels
```

Expected: FAIL because high battery power currently returns `.warning`.

- [ ] **Step 3: Implement battery-level tone thresholds**

Replace `powerStatusTone` in `Sources/SharedMetrics/MetricSnapshot.swift` with:

```swift
public var powerStatusTone: MetricStatusTone {
    if let batteryPercent {
        if batteryPercent < 0.2 {
            return .critical
        }

        if batteryPercent < 0.5 {
            return .warning
        }

        if batteryIsCharging {
            return .normal
        }

        switch batteryPowerSource?.lowercased() {
        case "ac power", "battery power":
            return .normal
        case "ups power":
            return .warning
        case .some(let value) where !value.isEmpty:
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
    case .some(let value) where !value.isEmpty:
        return .neutral
    default:
        return .neutral
    }
}
```

- [ ] **Step 4: Run targeted and full tests**

Run:

```bash
swift test --filter powerToneDistinguishesChargingBatteryAndPowerLevels
swift test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SharedMetrics/MetricSnapshot.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: tune battery power status tones"
```

---

### Task 4: Extend Formatter Boundaries

**Files:**
- Modify: `Sources/SharedMetrics/MetricFormatting.swift:10-92`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift:14-18`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift:643-647`

- [ ] **Step 1: Extend byte and duration tests**

Update `bytesFormatterUsesBinaryUnits()` to include PB and EB:

```swift
@Test func bytesFormatterUsesBinaryUnits() {
    #expect(MetricFormatting.bytes(512) == "512 B")
    #expect(MetricFormatting.bytes(2_097_152) == "2.0 MB")
    #expect(MetricFormatting.bytes(13_314_867_200) == "12.4 GB")
    #expect(MetricFormatting.bytes(1_125_899_906_842_624) == "1.0 PB")
    #expect(MetricFormatting.compactBytes(1_152_921_504_606_846_976) == "1 EB")
}
```

Update `minutesFormatterUsesCompactDurations()` to include zero minutes:

```swift
@Test func minutesFormatterUsesCompactDurations() {
    #expect(MetricFormatting.minutes(0) == "<1m")
    #expect(MetricFormatting.duration(42) == "<1m")
    #expect(MetricFormatting.minutes(28) == "28m")
    #expect(MetricFormatting.minutes(318) == "5h 18m")
    #expect(MetricFormatting.minutes(1_540) == "1d 1h")
}
```

- [ ] **Step 2: Run the formatter tests and verify they fail**

Run:

```bash
swift test --filter bytesFormatterUsesBinaryUnits
swift test --filter minutesFormatterUsesCompactDurations
```

Expected: FAIL because PB/EB are not supported and zero minutes returns `0m`.

- [ ] **Step 3: Extend byte units**

In `Sources/SharedMetrics/MetricFormatting.swift`, change both unit arrays to:

```swift
let units = ["B", "KB", "MB", "GB", "TB", "PB", "EB"]
```

- [ ] **Step 4: Return `<1m` for sub-minute durations**

Change the final branch of `minutes(_:)` to:

```swift
if minuteRemainder == 0 {
    return "<1m"
}

return "\(minuteRemainder)m"
```

- [ ] **Step 5: Run targeted and full tests**

Run:

```bash
swift test --filter bytesFormatterUsesBinaryUnits
swift test --filter minutesFormatterUsesCompactDurations
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/SharedMetrics/MetricFormatting.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: extend metric formatter boundaries"
```

---

### Task 5: Make Shared Snapshot Writes Observable

**Files:**
- Modify: `Sources/SharedMetrics/SharedSnapshotStore.swift:37-42`
- Modify: `Sources/PulseDockApp/MetricsStore.swift:348-358`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift:8439-8505`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Add tests for save success and encoding failure**

Add this test near the existing `SharedSnapshotStore` tests:

```swift
@Test func sharedSnapshotStoreReportsWriteFailuresInsteadOfSilentlyDroppingThem() throws {
    let suiteName = "PulseDockSharedSnapshotFailure-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = SharedSnapshotStore(defaults: defaults)
    let validSnapshot = MetricSnapshot(
        cpuUsage: 0.2,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 10)
    )
    let invalidSnapshot = MetricSnapshot(
        cpuUsage: .nan,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 11)
    )

    #expect(store.saveLatestSnapshot(validSnapshot) == true)
    #expect(defaults.data(forKey: "shared.latestMetricSnapshot") != nil)
    #expect(store.saveLatestSnapshot(invalidSnapshot) == false)
}
```

Add this source-level assertion to `sharedSnapshotUsesSingleWidgetCompactHelper()`:

```swift
#expect(sharedStore.contains("@discardableResult"))
#expect(sharedStore.contains("do {"))
#expect(sharedStore.contains("catch {"))
#expect(sharedStore.contains("Pulse Dock failed to encode shared snapshot"))
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run:

```bash
swift test --filter sharedSnapshotStoreReportsWriteFailuresInsteadOfSilentlyDroppingThem
```

Expected: FAIL because `saveLatestSnapshot` returns `Void`.

- [ ] **Step 3: Return a Bool from shared snapshot writes**

Replace `saveLatestSnapshot(_:)` in `Sources/SharedMetrics/SharedSnapshotStore.swift` with:

```swift
@discardableResult
public func saveLatestSnapshot(_ snapshot: MetricSnapshot) -> Bool {
    guard let defaults else { return false }
    let compact = snapshot.widgetCompactSnapshot()

    do {
        let data = try JSONEncoder().encode(compact)
        defaults.set(data, forKey: Keys.latestSnapshot)
        return true
    } catch {
#if DEBUG
        print("Pulse Dock failed to encode shared snapshot: \(error)")
#endif
        return false
    }
}
```

- [ ] **Step 4: Keep caller behavior unchanged but explicit**

In `Sources/PulseDockApp/MetricsStore.swift`, change:

```swift
sharedSnapshotStore.saveLatestSnapshot(snapshot)
```

to:

```swift
_ = sharedSnapshotStore.saveLatestSnapshot(snapshot)
```

- [ ] **Step 5: Document the behavior**

Add this bullet to `docs/data-capability-audit.md` near the App Group snapshot notes:

```markdown
- Shared snapshot writes return a success flag and print debug-only encoding errors, so malformed nonconforming values do not fail silently during development.
```

- [ ] **Step 6: Run targeted and full tests**

Run:

```bash
swift test --filter sharedSnapshotStoreReportsWriteFailuresInsteadOfSilentlyDroppingThem
swift test
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/SharedMetrics/SharedSnapshotStore.swift Sources/PulseDockApp/MetricsStore.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: report shared snapshot write failures"
```

---

### Task 6: Stabilize Network Interface Sorting And Rate Progress

**Files:**
- Create: `Sources/SharedMetrics/MetricScales.swift`
- Modify: `Sources/SharedMetrics/SystemSampler.swift:62-102`
- Modify: `Sources/SharedMetrics/SystemSampler.swift:626-639`
- Modify: `Sources/SharedMetrics/SystemSampler.swift:1110-1185`
- Modify: `Sources/PulseDockApp/DashboardView.swift:364`
- Modify: `Sources/PulseDockApp/DashboardView.swift:593-595`
- Modify: `Sources/PulseDockApp/DashboardView.swift:1877-1922`
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift:132-134`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Add tests for internal network sort keys and shared scaling**

Add this test near the network interface tests:

```swift
@Test func networkInterfaceSortingUsesStableInternalKindKeys() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(sampler.contains("var sortKind: String"))
    #expect(sampler.contains("sortKind: sortKind"))
    #expect(sampler.contains("if lhs.sortKind != rhs.sortKind"))
    #expect(sampler.contains("return lhs.sortKind.localizedStandardCompare(rhs.sortKind) == .orderedAscending"))
    #expect(sampler.contains("private func interfaceSortKind(systemType: String?, fallbackName name: String) -> String"))
    #expect(sampler.contains("private func interfaceKindDisplayName(sortKind: String) -> String"))
    #expect(!sampler.contains("if name.hasPrefix(\"en\") { return SharedMetricStrings.networkInterface }"))
}
```

Add this test near the formatter tests:

```swift
@Test func networkRateProgressUsesSharedLogarithmicScale() {
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 0) == 0)
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 40_000_000) > 0.5)
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 1_250_000_000) == 1)
}
```

Add this source-level test near existing dashboard/panel network tests:

```swift
@Test func networkRateProgressDoesNotUseInlineMagicBaselines() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let widgetPanel = try fixture("Sources/PulseDockApp/WidgetPanelView.swift")

    #expect(dashboard.contains("MetricScales.networkRateProgress(bytesPerSecond:"))
    #expect(widgetPanel.contains("MetricScales.networkRateProgress(bytesPerSecond:"))
    #expect(!dashboard.contains("baseline: 40_000_000"))
    #expect(!dashboard.contains("baseline: 20_000_000"))
    #expect(!widgetPanel.contains("/ 40_000_000"))
}
```

- [ ] **Step 2: Run targeted tests and verify they fail**

Run:

```bash
swift test --filter networkInterfaceSortingUsesStableInternalKindKeys
swift test --filter networkRateProgressUsesSharedLogarithmicScale
swift test --filter networkRateProgressDoesNotUseInlineMagicBaselines
```

Expected: FAIL because sort keys and `MetricScales` do not exist.

- [ ] **Step 3: Create shared metric scaling helper**

Create `Sources/SharedMetrics/MetricScales.swift`:

```swift
import Foundation

public enum MetricScales {
    private static let tenGigabitBytesPerSecond = 1_250_000_000.0

    public static func networkRateProgress(bytesPerSecond: UInt64) -> Double {
        guard bytesPerSecond > 0 else { return 0 }
        let value = min(Double(bytesPerSecond), tenGigabitBytesPerSecond)
        return min(log10(value + 1) / log10(tenGigabitBytesPerSecond + 1), 1)
    }
}
```

- [ ] **Step 4: Add network interface sort key fields**

In `Sources/SharedMetrics/SystemSampler.swift`, change `NetworkInterfaceAccumulator` and `NetworkInterfaceDescriptor`:

```swift
private struct NetworkInterfaceAccumulator {
    var name: String
    var displayName: String
    var kind: String
    var sortKind: String
    var isUp = false
    var isLoopback = false
    var bytesReceived: UInt64 = 0
    var bytesSent: UInt64 = 0
    var hasByteCounters = false
    var packetsReceived: UInt64?
    var packetsSent: UInt64?
    var receiveErrors: UInt64?
    var sendErrors: UInt64?
    var linkSpeedBitsPerSecond: UInt64?
    var mtu: Int?
}

private struct NetworkInterfaceDescriptor {
    var displayName: String
    var kind: String
    var sortKind: String
}
```

When constructing metrics, keep `kind` as the display value:

```swift
NetworkInterfaceMetric(
    index: index,
    displayName: displayName,
    kind: kind,
    isUp: isUp,
    isLoopback: isLoopback,
    hasInterfaceStateReport: true,
    bytesReceived: bytesReceived,
    bytesSent: bytesSent,
    hasByteCounters: hasByteCounters,
    packetsReceived: packetsReceived,
    packetsSent: packetsSent,
    receiveErrors: receiveErrors,
    sendErrors: sendErrors,
    linkSpeedBitsPerSecond: linkSpeedBitsPerSecond,
    mtu: mtu
)
```

- [ ] **Step 5: Sort using internal keys**

Change the sort block to:

```swift
if lhs.sortKind != rhs.sortKind {
    return lhs.sortKind.localizedStandardCompare(rhs.sortKind) == .orderedAscending
}
return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
```

- [ ] **Step 6: Split sort kind from display kind**

Replace `interfaceKind(systemType:fallbackName:)` with:

```swift
private func interfaceSortKind(systemType: String?, fallbackName name: String) -> String {
#if canImport(SystemConfiguration)
    switch systemType {
    case String(kSCNetworkInterfaceTypeIEEE80211):
        return "Wi-Fi"
    case String(kSCNetworkInterfaceTypeEthernet),
         String(kSCNetworkInterfaceTypeBond),
         String(kSCNetworkInterfaceTypeVLAN):
        return "Ethernet"
    case String(kSCNetworkInterfaceTypePPP),
         String(kSCNetworkInterfaceTypeIPSec),
         String(kSCNetworkInterfaceTypeL2TP):
        return "VPN"
    case String(kSCNetworkInterfaceTypeBluetooth):
        return "Bluetooth"
    case String(kSCNetworkInterfaceTypeWWAN):
        return "Cellular"
    default:
        return interfaceSortKind(name)
    }
#else
    return interfaceSortKind(name)
#endif
}

private func interfaceSortKind(_ name: String) -> String {
    if name == "lo0" { return "Loopback" }
    if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") { return "VPN" }
    if name.hasPrefix("bridge") { return "Bridge" }
    if name.hasPrefix("awdl") || name.hasPrefix("llw") { return "AWDL" }
    if name.hasPrefix("en") { return "Network" }
    if name.hasPrefix("thunderbolt") { return "Thunderbolt" }
    return "Other"
}

private func interfaceKindDisplayName(sortKind: String) -> String {
    switch sortKind {
    case "Wi-Fi": return "Wi-Fi"
    case "Ethernet": return "Ethernet"
    case "VPN": return "VPN"
    case "Loopback": return "Loopback"
    case "Bridge": return "Bridge"
    case "Thunderbolt": return "Thunderbolt"
    case "AWDL": return "Apple Wireless Direct"
    case "Other": return SharedMetricStrings.other
    default: return SharedMetricStrings.networkInterface
    }
}
```

Where descriptors are built, compute:

```swift
let sortKind = interfaceSortKind(systemType: systemType, fallbackName: name)
let kind = interfaceKindDisplayName(sortKind: sortKind)
let displayName = interfaceDisplayName(systemName: systemName, kind: sortKind)
```

Then store `sortKind` in the descriptor and accumulator.

- [ ] **Step 7: Replace inline network progress baselines**

In `Sources/PulseDockApp/WidgetPanelView.swift`, change `normalizedRate(_:)` to:

```swift
private func normalizedRate(_ bytesPerSecond: UInt64) -> Double {
    MetricScales.networkRateProgress(bytesPerSecond: bytesPerSecond)
}
```

In `Sources/PulseDockApp/DashboardView.swift`, change `normalizedRate` to:

```swift
private func normalizedRate(_ bytesPerSecond: UInt64) -> Double {
    MetricScales.networkRateProgress(bytesPerSecond: bytesPerSecond)
}
```

Change all call sites that currently pass a `baseline:` argument to call `normalizedRate(value)` instead. Then change `networkTrendValues` to:

```swift
private func networkTrendValues(from history: [MetricSnapshot], keyPath: KeyPath<MetricSnapshot, UInt64>) -> [Double] {
    history.filter(\.hasNetworkByteCounters).map { normalizedRate($0[keyPath: keyPath]) }
}
```

- [ ] **Step 8: Run targeted and full tests**

Run:

```bash
swift test --filter networkInterfaceSortingUsesStableInternalKindKeys
swift test --filter networkRateProgressUsesSharedLogarithmicScale
swift test --filter networkRateProgressDoesNotUseInlineMagicBaselines
swift test
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add Sources/SharedMetrics/MetricScales.swift Sources/SharedMetrics/SystemSampler.swift Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/WidgetPanelView.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: stabilize network ordering and rate scaling"
```

---

### Task 7: Clean Widget Runtime Paths And Compile Widget In SwiftPM

**Files:**
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift:13-34`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift:66-75`
- Modify: `Package.swift:15-46`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/app-store-release-checklist.md`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Add source-level tests for widget cache and fallback**

Add this test near the widget tests:

```swift
@Test func widgetSamplerCacheHasNoDeadPrimingStateAndUnknownFamiliesUseCompactFallback() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(widget.contains("private final class WidgetSamplerCache"))
    #expect(widget.contains("func sample() -> MetricSnapshot"))
    #expect(!widget.contains("private var isPrimed"))
    #expect(!widget.contains("private var primedSnapshot"))
    #expect(!widget.contains("if !isPrimed"))
    #expect(widget.contains("#if !SWIFT_PACKAGE"))
    #expect(widget.contains("@main"))
    #expect(widget.contains("struct SystemDashboardWidgetBundle: WidgetBundle"))
    #expect(widget.contains("case .systemLarge:"))
    #expect(widget.contains("default:"))
    #expect(widget.contains("SmallWidget(snapshot: snapshot)"))
    #expect(!widget.contains("default:\n                LargeWidget(snapshot: snapshot)"))
}
```

Add this test near package metadata tests:

```swift
@Test func swiftPMCompilesWidgetSourceAsReleaseGate() throws {
    let package = try fixture("Package.swift")
    let releaseChecklist = try fixture("docs/app-store-release-checklist.md")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(package.contains("name: \"PulseDockWidget\""))
    #expect(package.contains("path: \"Sources/PulseDockWidget\""))
    #expect(package.contains(".linkedFramework(\"WidgetKit\")"))
    #expect(package.contains(".linkedFramework(\"SwiftUI\")"))
    #expect(package.contains("dependencies: [\"SharedMetrics\", \"PulseDockWidget\"]"))
    #expect(releaseChecklist.contains("swift test"))
    #expect(releaseChecklist.contains("xcodebuild -project PulseDock.xcodeproj -scheme PulseDock"))
    #expect(audit.contains("SwiftPM compiles the widget source target during `swift test`; Xcode remains responsible for packaging the WidgetKit extension."))
}
```

- [ ] **Step 2: Run targeted tests and verify they fail**

Run:

```bash
swift test --filter widgetSamplerCacheHasNoDeadPrimingStateAndUnknownFamiliesUseCompactFallback
swift test --filter swiftPMCompilesWidgetSourceAsReleaseGate
```

Expected: FAIL because widget dead state exists, the widget bundle `@main` is not guarded for SwiftPM, and Package.swift has no widget target.

- [ ] **Step 3: Simplify widget sampler cache**

Replace `WidgetSamplerCache` in `Sources/PulseDockWidget/SystemDashboardWidget.swift` with:

```swift
private final class WidgetSamplerCache: @unchecked Sendable {
    private let systemSampler = SystemSampler()
    private let lock = NSLock()

    func sample() -> MetricSnapshot {
        lock.lock()
        defer { lock.unlock() }

        return systemSampler.sample()
    }
}
```

- [ ] **Step 4: Use explicit widget family fallback**

Replace the widget family switch with:

```swift
switch family {
case .systemSmall:
    SmallWidget(snapshot: snapshot)
case .systemMedium:
    MediumWidget(snapshot: snapshot)
case .systemLarge:
    LargeWidget(snapshot: snapshot)
default:
    SmallWidget(snapshot: snapshot)
}
```

- [ ] **Step 5: Guard the widget bundle entry point for SwiftPM**

In `Sources/PulseDockWidget/SystemDashboardWidget.swift`, wrap the widget bundle entry point:

```swift
#if !SWIFT_PACKAGE
@main
struct SystemDashboardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SystemDashboardWidget()
    }
}
#endif
```

Xcode project builds do not define `SWIFT_PACKAGE`, so the WidgetKit extension still has its `@main` entry point. SwiftPM builds do define `SWIFT_PACKAGE`, so the new library target compiles without an executable entry point.

- [ ] **Step 6: Add the SwiftPM widget compile target**

In `Package.swift`, add this target before the test target:

```swift
.target(
    name: "PulseDockWidget",
    dependencies: ["SharedMetrics"],
    path: "Sources/PulseDockWidget",
    resources: [
        .process("Resources")
    ],
    linkerSettings: [
        .linkedFramework("SwiftUI"),
        .linkedFramework("WidgetKit")
    ]
),
```

Change the test target dependencies from:

```swift
dependencies: ["SharedMetrics"]
```

to:

```swift
dependencies: ["SharedMetrics", "PulseDockWidget"]
```

- [ ] **Step 7: Update release docs**

Add this bullet to `docs/data-capability-audit.md`:

```markdown
- SwiftPM compiles the widget source target during `swift test`; Xcode remains responsible for packaging the WidgetKit extension.
```

Add this command to the local verification section in `docs/app-store-release-checklist.md`:

```bash
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -destination 'generic/platform=macOS' -derivedDataPath .build/xcode-derived-data CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 8: Run targeted, SwiftPM, and Xcode checks**

Run:

```bash
swift test --filter widgetSamplerCacheHasNoDeadPrimingStateAndUnknownFamiliesUseCompactFallback
swift test --filter swiftPMCompilesWidgetSourceAsReleaseGate
swift build --target PulseDockWidget
swift test
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -destination 'generic/platform=macOS' -derivedDataPath .build/xcode-derived-data CODE_SIGNING_ALLOWED=NO build
```

Expected: all commands pass.

- [ ] **Step 9: Commit**

```bash
git add Package.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/app-store-release-checklist.md docs/data-capability-audit.md
git commit -m "fix: compile widget source in SwiftPM"
```

---

### Task 8: Low-Risk Testability And Constant Cleanup

**Files:**
- Modify: `Sources/PulseDockApp/AppDelegate.swift:42`
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift:812-875`
- Modify: `Sources/SharedMetrics/SystemSampler.swift:115-218`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

**Dependency:** Run this only after Task 2 has landed. This task preserves Task 2's `batteryCacheInterval` initializer parameter while adding injectable network path observation.

- [ ] **Step 1: Add source-level tests for cleanup boundaries**

Add this test near related metadata tests:

```swift
@Test func lowRiskOptimizationBoundariesAreExplicit() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let snapshot = try fixture("Sources/SharedMetrics/MetricSnapshot.swift")
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(appDelegate.contains("private enum StatusPopoverTiming"))
    #expect(appDelegate.contains("static let closeToggleSuppressionInterval: TimeInterval = 0.25"))
    #expect(!appDelegate.contains("private let statusPopoverToggleSuppressionInterval: TimeInterval = 0.25"))

    #expect(snapshot.contains("logicalCoreCount: Int = 0"))
    #expect(snapshot.contains("activeProcessorCount: Int = 0"))
    #expect(snapshot.contains("osVersion: String = \"\""))
    #expect(!snapshot.contains("logicalCoreCount: Int = ProcessInfo.processInfo.activeProcessorCount"))
    #expect(!snapshot.contains("osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString"))

    #expect(sampler.contains("protocol NetworkPathObserving"))
    #expect(sampler.contains("private let networkPathObserver: any NetworkPathObserving"))
    #expect(sampler.contains("public convenience init(inventoryCacheInterval: TimeInterval = 15, batteryCacheInterval: TimeInterval = 5)"))
    #expect(sampler.contains("init(inventoryCacheInterval: TimeInterval = 15, batteryCacheInterval: TimeInterval = 5, networkPathObserver: any NetworkPathObserving)"))
}
```

- [ ] **Step 2: Run the targeted test and verify it fails**

Run:

```bash
swift test --filter lowRiskOptimizationBoundariesAreExplicit
```

Expected: FAIL because these cleanup boundaries are not yet explicit.

- [ ] **Step 3: Name popover suppression timing**

In `Sources/PulseDockApp/AppDelegate.swift`, add this enum near `MenuBarStatusItemLayout`:

```swift
private enum StatusPopoverTiming {
    // NSPopover close animation duration is not exposed publicly; this short guard avoids reopening against a closing status-window anchor.
    static let closeToggleSuppressionInterval: TimeInterval = 0.25
}
```

Remove:

```swift
private let statusPopoverToggleSuppressionInterval: TimeInterval = 0.25
```

Replace both uses of `statusPopoverToggleSuppressionInterval` with:

```swift
StatusPopoverTiming.closeToggleSuppressionInterval
```

- [ ] **Step 4: Remove ProcessInfo defaults from MetricSnapshot initializer**

In `Sources/SharedMetrics/MetricSnapshot.swift`, change initializer defaults to:

```swift
logicalCoreCount: Int = 0,
activeProcessorCount: Int = 0,
osVersion: String = "",
```

Keep `MetricSnapshot.placeholder` explicitly passing:

```swift
logicalCoreCount: 0,
activeProcessorCount: 0,
osVersion: "macOS",
```

- [ ] **Step 5: Make network path observation injectable for tests**

In `Sources/SharedMetrics/SystemSampler.swift`, change `NetworkPathSample` from private to internal:

```swift
struct NetworkPathSample: Sendable {
    var status = "unknown"
    var isExpensive = false
    var isConstrained = false
    var hasCostReport = false
    var supportsDNS = false
    var supportsIPv4 = false
    var supportsIPv6 = false
    var hasSupportReport = false
    var interfaceKinds: [String] = []
}
```

Add this protocol above `NetworkPathObserver`:

```swift
protocol NetworkPathObserving: Sendable {
    var current: NetworkPathSample { get }
}
```

Change the Network-enabled `NetworkPathObserver` declaration line to:

```swift
private final class NetworkPathObserver: NetworkPathObserving, @unchecked Sendable {
```

Change the fallback `NetworkPathObserver` declaration to:

```swift
private final class NetworkPathObserver: NetworkPathObserving {
    var current: NetworkPathSample { NetworkPathSample() }
}
```

Change the stored property:

```swift
private let networkPathObserver: any NetworkPathObserving
```

Replace the public initializer with:

```swift
public convenience init(inventoryCacheInterval: TimeInterval = 15, batteryCacheInterval: TimeInterval = 5) {
    self.init(
        inventoryCacheInterval: inventoryCacheInterval,
        batteryCacheInterval: batteryCacheInterval,
        networkPathObserver: NetworkPathObserver()
    )
}

init(
    inventoryCacheInterval: TimeInterval = 15,
    batteryCacheInterval: TimeInterval = 5,
    networkPathObserver: any NetworkPathObserving
) {
    self.inventoryCacheInterval = max(0, inventoryCacheInterval)
    self.batteryCacheInterval = max(0, batteryCacheInterval)
    self.networkPathObserver = networkPathObserver
    self.systemInfo = Self.sampleSystemInfo()
}
```

- [ ] **Step 6: Run targeted and full tests**

Run:

```bash
swift test --filter lowRiskOptimizationBoundariesAreExplicit
swift test
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/PulseDockApp/AppDelegate.swift Sources/SharedMetrics/MetricSnapshot.swift Sources/SharedMetrics/SystemSampler.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "chore: clarify metric and sampler boundaries"
```

---

## Final Verification

After all tasks are complete, run the full release verification set:

```bash
swift test
```

Expected: all Swift Testing tests pass.

```bash
scripts/audit-localization.sh
```

Expected: no Swift Han-character findings.

```bash
scripts/validate-public-pages.sh
CHECK_PUBLIC_URLS=1 scripts/validate-public-pages.sh
```

Expected: local page validation passes and both live public URLs return HTTP 200.

```bash
SCREENSHOT_LOCALE=zh-Hans scripts/validate-app-store-screenshots.sh
```

Expected: five Simplified Chinese screenshots validate.

```bash
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -destination 'generic/platform=macOS' -derivedDataPath .build/xcode-derived-data CODE_SIGNING_ALLOWED=NO build
```

Expected: Release build succeeds for the app and WidgetKit extension.

```bash
git diff --check
```

Expected: no whitespace errors.

## Commit And Push Strategy

Use one commit per task. After final verification:

```bash
git status -sb
git push origin main
git push origin codex/app-store-polish
```

If working from a feature branch, push that branch first and merge to `main` only after all verification commands pass.

## Self-Review Checklist

- [ ] P0 conversion traps are eliminated without relying on caller-side filtering.
- [ ] Pause/resume resets CPU and network delta baselines.
- [ ] Battery sampling is cached for short refresh intervals.
- [ ] High battery power no longer renders as warning.
- [ ] PB/EB and `<1m` formatting are covered by tests.
- [ ] Shared snapshot write failures are observable during development.
- [ ] Network interface sorting uses stable internal keys.
- [ ] Network progress no longer relies on unexplained inline magic baselines.
- [ ] Widget cache dead state is removed.
- [ ] Unknown widget families use compact fallback.
- [ ] `swift test` compiles widget source.
- [ ] Xcode Release build remains part of the release gate.
