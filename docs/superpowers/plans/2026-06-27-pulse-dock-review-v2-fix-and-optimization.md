# Pulse Dock Review V2 Fix And Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the verified top-review v2 App Store risks for Pulse Dock, downgrade overstated findings, and add gates that keep display sampling, widget fallback, persistence, accessibility, localization, and release signing from regressing.

**Architecture:** Keep fixes in the layer that owns the behavior: hardware sampling in `SharedMetrics`, scheduling and persistence in `PulseDockApp`, widget fallback and accessibility in `PulseDockWidget`, and App Store readiness in scripts/tests/docs. Use small, source-level tests for private AppKit/WidgetKit paths that are hard to exercise in SwiftPM, and behavioral tests for pure Swift helpers. Do not add new permissions, analytics, background network services, or product features.

**Tech Stack:** Swift 6, SwiftUI, AppKit, WidgetKit, CoreGraphics, IOKit, Network, Swift Testing, SwiftPM, Xcode project generation scripts, shell release gates.

---

## Review Corrections To Preserve

This plan is based on a direct verification pass over `docs/review/top/final-review-v2.md`. Keep these corrections in the implementation notes and final review:

| Item | Corrected decision |
| --- | --- |
| P0-1 NSScreen sampling | Real P0, but do not say refresh rate is always empty. CGDisplay can still provide refresh rate; the hard loss is NSScreen-derived scale/color and refresh fallback when sampling runs off-main. |
| P0-2 widget fallback | Real P0 watchdog risk, but the reported `数百 ms-1s` duration is unmeasured. Treat it as a synchronous full-sampler risk until timed. |
| P1-9 widget families | Downgrade macOS release severity. Keep defensive `@unknown default`; do not treat iPad-style families as a macOS App Store blocker. |
| P2-7/P2-8 accessibility | Some components already have labels. Fix the remaining gaps, especially `WidgetHeader`, decorative circles, and missing combine modifiers. |
| P2-16 localization bundle | `SharedMetricStrings` uses `.module` under SwiftPM and `.main` outside SwiftPM. The risk is Xcode resource copy validation, not a blanket `.main` bug. |
| P2-19 undo/redo selectors | Remove from the defect list. `undo:` and `redo:` are valid AppKit responder-chain selectors for text editing menus. |
| P2-20/P2-25 timing and stale UserDefaults | Keep as optimization risks that need verification, not proven user-facing bugs. |

## File Structure

- Modify `Sources/SharedMetrics/SystemSampler.swift`
  - Route NSScreen reads through the main thread without returning empty data from detached sampling.
  - Expose `invalidateDisplaysCache()`.
  - Add a compact widget sampler that skips expensive GPU/display/storage-volume enumeration.
  - Keep `sample()` thread-safe through its existing `sampleLock`.

- Modify `Sources/PulseDockApp/MetricsStore.swift`
  - Replace deinit cleanup with explicit lifecycle cleanup.
  - Add wake/screen-change entry points.
  - Offload JSON encoding work away from the main actor.
  - Reduce unnecessary refresh publication.

- Modify `Sources/PulseDockApp/AppDelegate.swift`
  - Register system wake and screen-change observers.
  - Close popovers/windows and remove status item at termination.
  - Preserve valid AppKit edit menu selectors.

- Modify `Sources/PulseDockApp/DashboardView.swift`
  - Memoize trend arrays per render.
  - Commit threshold slider changes after editing instead of publishing every drag tick.
  - Sanitize progress rendering for finite values.
  - Localize user-facing short labels where they are not technical standards or brand names.

- Modify `Sources/PulseDockApp/WidgetPanelView.swift`
  - Use the shared finite progress helper.
  - Keep accessibility labels aligned with app dashboard components.

- Modify `Sources/PulseDockWidget/SystemDashboardWidget.swift`
  - Replace synchronous full fallback sampling with shared snapshot or compact fallback.
  - Return representative placeholder data for gallery snapshots.
  - Add staleness indication.
  - Sanitize progress values.
  - Localize widget-owned strings.
  - Add missing accessibility labels and hidden markers.

- Modify `Sources/SharedMetrics/MetricSnapshot.swift`
  - Add `schemaVersion`.
  - Normalize decode/init report-flag inference.
  - Keep compact snapshot contract explicit.

- Modify `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift`
  - Preserve compact snapshot trimming.
  - Add compile-time fields needed by widget staleness, if any.

- Modify `Sources/SharedMetrics/SharedMetricStrings.swift`
  - Keep `.module` under SwiftPM.
  - Add tests that app/widget bundles copy `SharedMetrics.strings` into built products.

- Modify `Sources/SharedMetrics/SharedSnapshotStore.swift`
  - Log decode failures in DEBUG builds.
  - Keep save returning `Bool`.

- Modify `Sources/SharedMetrics/MetricScales.swift`
  - Add finite progress clamping shared by app and widget.

- Modify `Sources/PulseDockApp/PulseDockAppStrings.swift`
  - Add app labels that are truly user-facing, such as core labels and widget refresh copy.

- Modify `Sources/PulseDockWidget/PulseDockWidgetStrings.swift`
  - Add widget display name, CPU, memory, UPS, stale, and waiting strings.

- Modify `scripts/archive-app-store.sh`
  - Add post-archive entitlements validation for app and widget.

- Modify `scripts/generate-xcodeproj.rb`
  - Set project-level Swift version to 6.0.
  - Preserve app/widget/shared localization resource copying.

- Modify `Tests/SharedMetricsTests/MetricFormattingTests.swift`
  - Add source gates for display sampling, compact widget sampling, lifecycle cleanup, progress sanitizing, and schema/version handling.
  - Keep existing behavioral tests for sampler/formatting/store regressions.

- Modify `Tests/SharedMetricsTests/LocalizationGateTests.swift`
  - Add release gate tests for bundle IDs, App Group entitlements, shared localization resources, and project-level Swift version.

- Modify `docs/review/top/final-review-v2.md`
  - Apply the severity corrections listed above.

- Modify `docs/data-capability-audit.md`
  - Document main-thread display metadata, compact widget fallback, and stale-data semantics.

- Modify `docs/app-store-release-checklist.md`
  - Add automatic archive entitlement checks and manual TestFlight App Group verification.

---

### Task 1: Fix P0 Display Metadata Sampling

**Files:**
- Modify: `Sources/SharedMetrics/SystemSampler.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Modify: `docs/data-capability-audit.md`

- [ ] **Step 1: Write the failing source gate**

Add this test near existing display/sampler tests in `Tests/SharedMetricsTests/MetricFormattingTests.swift`:

```swift
@Test func systemSamplerRoutesNSScreenMetadataThroughMainThreadInsteadOfDroppingIt() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(sampler.contains("private struct ScreenDisplaySnapshot"))
    #expect(sampler.contains("private func screenDisplaySnapshot() -> ScreenDisplaySnapshot"))
    #expect(sampler.contains("DispatchQueue.main.sync"))
    #expect(sampler.contains("private func screenDisplaySnapshotOnMainThread() -> ScreenDisplaySnapshot"))
    #expect(!sampler.contains("guard Thread.isMainThread else { return [:] }"))
    #expect(!sampler.contains("guard Thread.isMainThread else { return [] }"))
}
```

- [ ] **Step 2: Run the targeted test and confirm RED**

Run:

```bash
swift test --filter systemSamplerRoutesNSScreenMetadataThroughMainThreadInsteadOfDroppingIt
```

Expected: FAIL because `ScreenDisplaySnapshot` and `DispatchQueue.main.sync` are not present.

- [ ] **Step 3: Add a Sendable screen snapshot value**

In `Sources/SharedMetrics/SystemSampler.swift`, add this private type near the other private sample structs:

```swift
private struct ScreenDisplaySnapshot: Sendable {
    var fallbackDisplays: [DisplayMetric]
    var refreshRatesByDisplayID: [CGDirectDisplayID: Double]
    var scalesByDisplayID: [CGDirectDisplayID: Double]
    var colorSpacesByDisplayID: [CGDirectDisplayID: DisplayColorSpaceSample]

    static let empty = ScreenDisplaySnapshot(
        fallbackDisplays: [],
        refreshRatesByDisplayID: [:],
        scalesByDisplayID: [:],
        colorSpacesByDisplayID: [:]
    )
}
```

- [ ] **Step 4: Route NSScreen reads through the main thread**

Replace the four separate NSScreen helper calls in `sampleDisplays()` with a single snapshot:

```swift
private func sampleDisplays() -> [DisplayMetric] {
    let screenSnapshot = screenDisplaySnapshot()
    var displayCount: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
        return screenSnapshot.fallbackDisplays
    }

    var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
    guard CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
        return screenSnapshot.fallbackDisplays
    }

    let displays = displayIDs.prefix(Int(displayCount)).enumerated().map { index, displayID in
        let mode = CGDisplayCopyDisplayMode(displayID)
        let modeRefreshRate = mode?.refreshRate ?? 0
        let refreshRate = modeRefreshRate > 0 ? modeRefreshRate : screenSnapshot.refreshRatesByDisplayID[displayID, default: 0]
        let modeWidth = mode.map { Int($0.width) } ?? Int(CGDisplayPixelsWide(displayID))
        let modeHeight = mode.map { Int($0.height) } ?? Int(CGDisplayPixelsHigh(displayID))
        let screenSize = CGDisplayScreenSize(displayID)

        return DisplayMetric(
            index: index,
            name: displayName(for: displayID, index: index),
            pixelWidth: Int(CGDisplayPixelsWide(displayID)),
            pixelHeight: Int(CGDisplayPixelsHigh(displayID)),
            modeWidth: modeWidth,
            modeHeight: modeHeight,
            refreshRate: refreshRate,
            backingScaleFactor: screenSnapshot.scalesByDisplayID[displayID, default: 0],
            colorSpaceModel: screenSnapshot.colorSpacesByDisplayID[displayID]?.model,
            colorComponentCount: screenSnapshot.colorSpacesByDisplayID[displayID]?.componentCount ?? 0,
            physicalWidthMillimeters: Int(screenSize.width.rounded()),
            physicalHeightMillimeters: Int(screenSize.height.rounded()),
            isBuiltin: CGDisplayIsBuiltin(displayID) != 0,
            isMain: displayID == CGMainDisplayID(),
            isMirrored: CGDisplayIsInMirrorSet(displayID) != 0,
            rotationDegrees: CGDisplayRotation(displayID),
            hasTopologyReport: true,
            hasRotationReport: true
        )
    }
    return displays.isEmpty ? screenSnapshot.fallbackDisplays : displays
}
```

Add the thread-routing helpers:

```swift
private func screenDisplaySnapshot() -> ScreenDisplaySnapshot {
#if canImport(AppKit)
    if Thread.isMainThread {
        return screenDisplaySnapshotOnMainThread()
    }
    return DispatchQueue.main.sync {
        screenDisplaySnapshotOnMainThread()
    }
#else
    return .empty
#endif
}

private func screenDisplaySnapshotOnMainThread() -> ScreenDisplaySnapshot {
#if canImport(AppKit)
    var refreshRates: [CGDirectDisplayID: Double] = [:]
    var scales: [CGDirectDisplayID: Double] = [:]
    var colorSpaces: [CGDirectDisplayID: DisplayColorSpaceSample] = [:]
    let mainScreen = NSScreen.main

    let fallbackDisplays = NSScreen.screens.enumerated().map { index, screen in
        let scale = screen.backingScaleFactor
        let pointWidth = max(0, Int(screen.frame.width.rounded()))
        let pointHeight = max(0, Int(screen.frame.height.rounded()))
        let pixelWidth = max(0, Int((screen.frame.width * scale).rounded()))
        let pixelHeight = max(0, Int((screen.frame.height * scale).rounded()))
        let isMain = mainScreen.map { screen === $0 } ?? (index == 0)
        let screenSize = physicalScreenSize(screen)

        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            let displayID = CGDirectDisplayID(screenNumber.uint32Value)
            let refreshRate = screenRefreshRate(screen)
            if refreshRate > 0 {
                refreshRates[displayID] = refreshRate
            }
            scales[displayID] = Double(scale)
            if let model = colorSpaceModel(screen.colorSpace?.colorSpaceModel) {
                colorSpaces[displayID] = DisplayColorSpaceSample(
                    model: model,
                    componentCount: screen.colorSpace?.numberOfColorComponents ?? 0
                )
            }
        }

        return DisplayMetric(
            index: index,
            name: isMain ? SharedMetricStrings.mainDisplay : SharedMetricStrings.display(number: index + 1),
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            modeWidth: pointWidth,
            modeHeight: pointHeight,
            refreshRate: screenRefreshRate(screen),
            backingScaleFactor: scale,
            colorSpaceModel: colorSpaceModel(screen.colorSpace?.colorSpaceModel),
            colorComponentCount: screen.colorSpace?.numberOfColorComponents ?? 0,
            physicalWidthMillimeters: screenSize.width,
            physicalHeightMillimeters: screenSize.height,
            isBuiltin: false,
            isMain: isMain,
            isMirrored: false,
            rotationDegrees: 0,
            hasTopologyReport: false,
            hasRotationReport: false
        )
    }

    return ScreenDisplaySnapshot(
        fallbackDisplays: fallbackDisplays,
        refreshRatesByDisplayID: refreshRates,
        scalesByDisplayID: scales,
        colorSpacesByDisplayID: colorSpaces
    )
#else
    return .empty
#endif
}
```

Remove the old `fallbackDisplaysFromScreens()`, `screenRefreshRatesByDisplayID()`, `screenScalesByDisplayID()`, and `screenColorSpacesByDisplayID()` helpers after the new helpers compile.

- [ ] **Step 5: Add display cache invalidation**

Add this public method beside `resetNetworkBaselines()` and `resetCPUBaselines()`:

```swift
public func invalidateDisplaysCache() {
    sampleLock.lock()
    defer { sampleLock.unlock() }

    displaysCache = nil
}
```

- [ ] **Step 6: Run tests and commit**

Run:

```bash
swift test --filter systemSamplerRoutesNSScreenMetadataThroughMainThreadInsteadOfDroppingIt
swift test
```

Expected: both commands PASS.

Commit:

```bash
git add Sources/SharedMetrics/SystemSampler.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: preserve display metadata during detached sampling"
```

---

### Task 2: Replace Widget Full-Sampler Fallback

**Files:**
- Modify: `Sources/SharedMetrics/SystemSampler.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Modify: `Sources/PulseDockWidget/PulseDockWidgetStrings.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write widget fallback source gates**

Add these tests to `Tests/SharedMetricsTests/MetricFormattingTests.swift`:

```swift
@Test func widgetProviderDoesNotSynchronouslyRunFullSystemSamplerForSnapshotOrTimeline() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(widget.contains("func getSnapshot(in context: Context, completion: @escaping (SystemEntry) -> Void)"))
    #expect(widget.contains("representativeSnapshot()"))
    #expect(widget.contains("Task.detached(priority: .utility)"))
    #expect(widget.contains("sampledSnapshotForTimeline()"))
    #expect(!widget.contains("return systemSampler.sample()"))
    #expect(!widget.contains("completion(SystemEntry(date: Date(), snapshot: sampledSnapshot()))"))
}

@Test func sharedMetricsProvidesCompactWidgetSamplerThatSkipsExpensiveInventory() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(sampler.contains("public func sampleWidgetCompact(now: Date = Date()) -> MetricSnapshot"))
    #expect(sampler.contains("let cpu = sampleCPUUsage()"))
    #expect(sampler.contains("let battery = cachedBattery(now: now)"))
    #expect(sampler.contains("let disk = sampleDiskSpace()"))
    #expect(sampler.contains("gpuDevices: []"))
    #expect(sampler.contains("displays: []"))
    #expect(sampler.contains("storageVolumes: []"))
    #expect(!sampler.contains("public func sampleWidgetCompact(now: Date = Date()) -> MetricSnapshot {\n        sample()"))
}
```

- [ ] **Step 2: Run the targeted tests and confirm RED**

Run:

```bash
swift test --filter widgetProviderDoesNotSynchronouslyRunFullSystemSamplerForSnapshotOrTimeline
swift test --filter sharedMetricsProvidesCompactWidgetSamplerThatSkipsExpensiveInventory
```

Expected: both FAIL before implementation.

- [ ] **Step 3: Add compact widget sampling in SharedMetrics**

Add this method inside `SystemSampler`:

```swift
public func sampleWidgetCompact(now: Date = Date()) -> MetricSnapshot {
    sampleLock.lock()
    defer { sampleLock.unlock() }

    let memory = sampleMemory()
    let networkInterfaces = sampleNetworkInterfaces(now: now)
    let hasNetworkByteCounters = networkInterfaces.contains { $0.hasByteCounters }
    let networkTotal = networkTotals(from: networkInterfaces)
    let networkRate = sampleNetworkRate(totalBytes: networkTotal, hasByteCounters: hasNetworkByteCounters, now: now)
    let networkPath = networkPathObserver.current
    let battery = cachedBattery(now: now)
    let cpu = sampleCPUUsage()
    let loads = sampleLoadAverages()
    let disk = sampleDiskSpace()
    let uptime = ProcessInfo.processInfo.systemUptime

    return MetricSnapshot(
        cpuUsage: cpu.total,
        cpuCoreUsages: cpu.cores,
        hasCPUUsageReport: cpu.isReported,
        physicalCoreCount: systemInfo.physicalCoreCount,
        logicalCoreCount: systemInfo.logicalCoreCount,
        activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
        cpuBrandName: systemInfo.cpuBrandName,
        memoryUsedBytes: memory.used,
        memoryTotalBytes: memory.total,
        memoryFreeBytes: memory.free,
        memoryWiredBytes: memory.wired,
        memoryCompressedBytes: memory.compressed,
        memoryCachedBytes: memory.cached,
        memorySwapUsedBytes: memory.swapUsed,
        memorySwapTotalBytes: memory.swapTotal,
        memorySwapAvailableBytes: memory.swapAvailable,
        hasMemoryCompositionReport: memory.hasCompositionReport,
        loadAverage: loads.one,
        loadAverage5: loads.five,
        loadAverage15: loads.fifteen,
        hasLoadAverageReport: loads.isReported,
        thermalState: sampleThermalState(),
        batteryPercent: battery.percent,
        batteryIsCharging: battery.isCharging,
        batteryPowerSource: battery.powerSource,
        batteryTimeRemainingMinutes: battery.timeRemainingMinutes,
        batteryCycleCount: battery.cycleCount,
        batteryHealth: battery.health,
        batteryCurrentCapacity: battery.currentCapacity,
        batteryMaxCapacity: battery.maxCapacity,
        batteryDesignCapacity: battery.designCapacity,
        batteryVoltageMillivolts: battery.voltageMillivolts,
        batteryAmperageMilliamps: battery.amperageMilliamps,
        networkBytesPerSecond: networkRate.total,
        hasNetworkByteCounters: hasNetworkByteCounters,
        hasNetworkDirectionByteCounters: hasNetworkByteCounters,
        networkPathStatus: networkPath.status,
        networkPathIsExpensive: networkPath.isExpensive,
        networkPathIsConstrained: networkPath.isConstrained,
        hasNetworkPathCostReport: networkPath.hasCostReport,
        networkPathSupportsDNS: networkPath.supportsDNS,
        networkPathSupportsIPv4: networkPath.supportsIPv4,
        networkPathSupportsIPv6: networkPath.supportsIPv6,
        hasNetworkPathSupportReport: networkPath.hasSupportReport,
        networkPathInterfaceKinds: networkPath.interfaceKinds,
        networkInBytesPerSecond: networkRate.input,
        networkOutBytesPerSecond: networkRate.output,
        networkInterfaces: Array(networkInterfaces.prefix(2)),
        diskFreeBytes: disk.free,
        diskTotalBytes: disk.total,
        storageVolumes: [],
        processCount: 0,
        activeApplicationCount: 0,
        hiddenApplicationCount: 0,
        hasRunningAppCountReport: false,
        runningApps: [],
        gpuDevices: [],
        displays: [],
        uptimeSeconds: uptime,
        hasUptimeReport: uptime > 0,
        osVersion: systemInfo.osVersion,
        kernelRelease: systemInfo.kernelRelease,
        timestamp: now
    ).widgetCompactSnapshot()
}
```

- [ ] **Step 4: Convert widget provider to placeholder-first and async timeline fallback**

In `Sources/PulseDockWidget/SystemDashboardWidget.swift`, replace `WidgetSamplerCache.sample()` with:

```swift
func sampleCompact() -> MetricSnapshot {
    systemSampler.sampleWidgetCompact()
}
```

Replace provider methods with:

```swift
func placeholder(in context: Context) -> SystemEntry {
    SystemEntry(date: Date(), snapshot: Self.representativeSnapshot())
}

func getSnapshot(in context: Context, completion: @escaping (SystemEntry) -> Void) {
    completion(SystemEntry(date: Date(), snapshot: Self.representativeSnapshot()))
}

func getTimeline(in context: Context, completion: @escaping (Timeline<SystemEntry>) -> Void) {
    Task.detached(priority: .utility) {
        let now = Date()
        let entry = SystemEntry(date: now, snapshot: Self.sampledSnapshotForTimeline(now: now))
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private static func sampledSnapshotForTimeline(now: Date) -> MetricSnapshot? {
    if let shared = sharedSnapshotStore.loadLatestSnapshot(maxAge: 600, now: now) {
        return shared
    }

    let fallback = samplerCache.sampleCompact()
    return fallback.hasCPUUsageReport || fallback.hasMemoryUsageReport || fallback.hasDiskUsageReport ? fallback : nil
}
```

Add a representative fixture:

```swift
private static func representativeSnapshot() -> MetricSnapshot {
    MetricSnapshot(
        cpuUsage: 0.37,
        cpuCoreUsages: [0.31, 0.42, 0.28, 0.47],
        hasCPUUsageReport: true,
        physicalCoreCount: 8,
        logicalCoreCount: 8,
        activeProcessorCount: 8,
        cpuBrandName: "Apple Silicon",
        memoryUsedBytes: 8_600_000_000,
        memoryTotalBytes: 17_179_869_184,
        memoryFreeBytes: 3_200_000_000,
        memoryWiredBytes: 2_100_000_000,
        memoryCompressedBytes: 820_000_000,
        memoryCachedBytes: 4_100_000_000,
        hasMemoryCompositionReport: true,
        loadAverage: 1.42,
        loadAverage5: 1.20,
        loadAverage15: 1.05,
        hasLoadAverageReport: true,
        thermalState: "Nominal",
        batteryPercent: 0.86,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        networkBytesPerSecond: 1_200_000,
        hasNetworkByteCounters: true,
        hasNetworkDirectionByteCounters: true,
        networkPathStatus: "satisfied",
        networkPathSupportsDNS: true,
        networkPathSupportsIPv4: true,
        networkPathSupportsIPv6: true,
        hasNetworkPathSupportReport: true,
        networkInBytesPerSecond: 900_000,
        networkOutBytesPerSecond: 300_000,
        diskFreeBytes: 180_000_000_000,
        diskTotalBytes: 494_000_000_000,
        uptimeSeconds: 86_400,
        hasUptimeReport: true,
        osVersion: "macOS",
        kernelRelease: "Darwin",
        timestamp: Date()
    ).widgetCompactSnapshot()
}
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
swift test --filter widgetProviderDoesNotSynchronouslyRunFullSystemSamplerForSnapshotOrTimeline
swift test --filter sharedMetricsProvidesCompactWidgetSamplerThatSkipsExpensiveInventory
swift build --target PulseDockWidget
swift test
```

Expected: all PASS.

Commit:

```bash
git add Sources/SharedMetrics/SystemSampler.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Sources/PulseDockWidget/PulseDockWidgetStrings.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: avoid full sampler fallback in widget timelines"
```

---

### Task 3: Fix App Lifecycle, Wake Events, And Persistence Errors

**Files:**
- Modify: `Sources/PulseDockApp/MetricsStore.swift`
- Modify: `Sources/PulseDockApp/AppDelegate.swift`
- Modify: `Sources/SharedMetrics/SharedSnapshotStore.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write lifecycle and persistence source gates**

Add these tests:

```swift
@Test func metricsStoreUsesExplicitLifecycleCleanupInsteadOfAssumeIsolatedDeinit() throws {
    let store = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let delegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

    #expect(store.contains("func stopForTermination()"))
    #expect(!store.contains("MainActor.assumeIsolated"))
    #expect(delegate.contains("store.stopForTermination()"))
    #expect(delegate.contains("statusPopover?.close()"))
    #expect(delegate.contains("NSStatusBar.system.removeStatusItem"))
}

@Test func appRegistersWakeAndScreenChangeRefreshHooks() throws {
    let store = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let delegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(delegate.contains("NSWorkspace.didWakeNotification"))
    #expect(delegate.contains("NSApplication.didChangeScreenParametersNotification"))
    #expect(store.contains("func handleSystemWake()"))
    #expect(store.contains("func handleScreenConfigurationChange()"))
    #expect(sampler.contains("public func invalidateDisplaysCache()"))
}

@Test func sharedSnapshotLoadLogsDecodeFailuresInDebugBuilds() throws {
    let sharedStore = try fixture("Sources/SharedMetrics/SharedSnapshotStore.swift")
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")

    #expect(sharedStore.contains("do {"))
    #expect(sharedStore.contains("catch {"))
    #expect(sharedStore.contains("SharedSnapshotStore failed to decode latest snapshot"))
    #expect(metricsStore.contains("MetricsStore failed to decode history"))
    #expect(metricsStore.contains("MetricsStore failed to encode history"))
}
```

- [ ] **Step 2: Run the targeted tests and confirm RED**

Run:

```bash
swift test --filter metricsStoreUsesExplicitLifecycleCleanupInsteadOfAssumeIsolatedDeinit
swift test --filter appRegistersWakeAndScreenChangeRefreshHooks
swift test --filter sharedSnapshotLoadLogsDecodeFailuresInDebugBuilds
```

Expected: FAIL before implementation.

- [ ] **Step 3: Replace deinit cleanup with explicit stop**

In `MetricsStore`, replace the current `deinit` block with:

```swift
deinit {}

func stopForTermination() {
    persistHistoryIfNeeded(at: Date(), force: true)
    timer?.invalidate()
    timer = nil
    cancelInitialRefresh()
    cancelRefreshTask()
}
```

Ensure `applicationWillTerminate` or the existing termination path calls `store.stopForTermination()`.

- [ ] **Step 4: Add wake and screen-change handlers**

In `MetricsStore`, add:

```swift
func handleSystemWake() {
    sampler.resetNetworkBaselines()
    sampler.resetCPUBaselines()
    sampler.invalidateDisplaysCache()
    refresh()
}

func handleScreenConfigurationChange() {
    sampler.invalidateDisplaysCache()
    refresh()
}
```

In `AppDelegate`, add observer registration after the store and UI are initialized:

```swift
private func registerSystemEventObservers() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleSystemWakeNotification(_:)),
        name: NSWorkspace.didWakeNotification,
        object: NSWorkspace.shared
    )
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleScreenConfigurationChangeNotification(_:)),
        name: NSApplication.didChangeScreenParametersNotification,
        object: nil
    )
}

@objc private func handleSystemWakeNotification(_ notification: Notification) {
    store.handleSystemWake()
}

@objc private func handleScreenConfigurationChangeNotification(_ notification: Notification) {
    store.handleScreenConfigurationChange()
}
```

Call `registerSystemEventObservers()` from `applicationDidFinishLaunching`.

- [ ] **Step 5: Close app UI resources on termination**

In `AppDelegate.applicationWillTerminate`, ensure this exact cleanup shape exists:

```swift
func applicationWillTerminate(_ notification: Notification) {
    NotificationCenter.default.removeObserver(self)
    store.stopForTermination()
    statusPopover?.close()
    resetStatusPopoverContentHost()
    dashboardWindow?.orderOut(nil)
    if let statusItem {
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }
}
```

- [ ] **Step 6: Make load and history encoding errors visible in DEBUG**

Replace `SharedSnapshotStore.loadLatestSnapshot` with:

```swift
public func loadLatestSnapshot(maxAge: TimeInterval, now: Date = Date()) -> MetricSnapshot? {
    guard let defaults, let data = defaults.data(forKey: snapshotKey) else {
        return nil
    }

    do {
        let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: data)
        guard now.timeIntervalSince(snapshot.timestamp) <= maxAge else { return nil }
        guard now.timeIntervalSince(snapshot.timestamp) >= 0 else { return nil }
        return snapshot
    } catch {
        #if DEBUG
        print("SharedSnapshotStore failed to decode latest snapshot: \(error)")
        #endif
        return nil
    }
}
```

Replace silent history decode/encode in `MetricsStore` with do/catch blocks that print:

```swift
#if DEBUG
print("MetricsStore failed to decode history: \(error)")
#endif
```

and:

```swift
#if DEBUG
print("MetricsStore failed to encode history: \(error)")
#endif
```

- [ ] **Step 7: Run tests and commit**

Run:

```bash
swift test --filter metricsStoreUsesExplicitLifecycleCleanupInsteadOfAssumeIsolatedDeinit
swift test --filter appRegistersWakeAndScreenChangeRefreshHooks
swift test --filter sharedSnapshotLoadLogsDecodeFailuresInDebugBuilds
swift test
```

Expected: all PASS.

Commit:

```bash
git add Sources/PulseDockApp/MetricsStore.swift Sources/PulseDockApp/AppDelegate.swift Sources/SharedMetrics/SharedSnapshotStore.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: handle app lifecycle events and persistence errors"
```

---

### Task 4: Reduce Dashboard Refresh Work

**Files:**
- Modify: `Sources/PulseDockApp/MetricsStore.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write UI performance source gates**

Add this test:

```swift
@Test func dashboardAvoidsRepeatedTrendExtractionAndHighFrequencySliderPublishing() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let store = try fixture("Sources/PulseDockApp/MetricsStore.swift")

    #expect(dashboard.contains("let cpuTrend = cpuTrendValues(from: history)"))
    #expect(dashboard.contains("let memoryTrend = memoryTrendValues(from: history)"))
    #expect(dashboard.contains("let networkTrend = networkTrendValues(from: history)"))
    #expect(dashboard.contains("@State private var draftRefreshInterval"))
    #expect(dashboard.contains("onEditingChanged"))
    #expect(store.contains("private(set) var isRefreshing"))
    #expect(!store.contains("@Published private(set) var isRefreshing"))
}
```

- [ ] **Step 2: Run targeted test and confirm RED**

Run:

```bash
swift test --filter dashboardAvoidsRepeatedTrendExtractionAndHighFrequencySliderPublishing
```

Expected: FAIL before implementation.

- [ ] **Step 3: Stop publishing unused refresh state**

In `MetricsStore`, change:

```swift
@Published private(set) var isRefreshing = false
```

to:

```swift
private(set) var isRefreshing = false
```

Keep all internal guards and assignments unchanged.

- [ ] **Step 4: Memoize trend arrays inside page bodies**

In `OverviewPage.body`, compute trend arrays once:

```swift
let cpuTrend = cpuTrendValues(from: history)
let memoryTrend = memoryTrendValues(from: history)
let networkTrend = networkTrendValues(from: history)
let powerTrend = powerTrendValues(from: history)
```

Use those constants for `MetricCard`, `TrendRow`, and other local consumers in the same body. Do not call `cpuTrendValues(from:)`, `memoryTrendValues(from:)`, `networkTrendValues(from:)`, or `powerTrendValues(from:)` more than once in that body.

In pages that show trend lists, use the same pattern:

```swift
let cpuTrend = cpuTrendValues(from: history)
let memoryTrend = memoryTrendValues(from: history)
let networkTrend = networkTrendValues(from: history)
```

- [ ] **Step 5: Commit threshold changes after interaction**

For the settings controls, add local draft state to the settings page:

```swift
@State private var draftRefreshInterval: RefreshIntervalOption?
@State private var draftCPUThreshold: Double?
@State private var draftMemoryThreshold: Double?
@State private var draftDiskThreshold: Double?
```

Use local values while editing and commit on `onEditingChanged(false)`:

```swift
Slider(
    value: Binding(
        get: { draftCPUThreshold ?? store.cpuWarningThreshold },
        set: { draftCPUThreshold = $0 }
    ),
    in: 0.1...0.95,
    onEditingChanged: { editing in
        guard !editing, let draftCPUThreshold else { return }
        store.updateCPUWarningThreshold(draftCPUThreshold)
        self.draftCPUThreshold = nil
    }
)
```

Apply the same pattern to memory and disk warning threshold sliders. For the refresh interval picker, commit in `onChange` only when the user selects a new value:

```swift
Picker(
    PulseDockAppStrings.settingsRefreshIntervalLabel,
    selection: Binding(
        get: { draftRefreshInterval ?? store.refreshInterval },
        set: { draftRefreshInterval = $0 }
    )
) {
    ForEach(RefreshIntervalOption.allCases) { option in
        Text(option.title).tag(option)
    }
}
.onChange(of: draftRefreshInterval) { _, value in
    guard let value else { return }
    store.updateRefreshInterval(value)
}
```

- [ ] **Step 6: Run tests and commit**

Run:

```bash
swift test --filter dashboardAvoidsRepeatedTrendExtractionAndHighFrequencySliderPublishing
swift test
```

Expected: PASS.

Commit:

```bash
git add Sources/PulseDockApp/MetricsStore.swift Sources/PulseDockApp/DashboardView.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "perf: reduce dashboard refresh publishing work"
```

---

### Task 5: Sanitize Progress And Finish Accessibility/Localization Gaps

**Files:**
- Modify: `Sources/SharedMetrics/MetricScales.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Modify: `Sources/PulseDockWidget/PulseDockWidgetStrings.swift`
- Modify: `Sources/PulseDockWidget/Resources/PulseDockWidget.xcstrings`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Modify: `Tests/SharedMetricsTests/LocalizationGateTests.swift`

- [ ] **Step 1: Write progress, widget, and localization gates**

Add these tests:

```swift
@Test func metricScalesRejectsNanProgressBeforeSwiftUITrimAndFrame() {
    #expect(MetricScales.clampedProgress(Double.nan) == nil)
    #expect(MetricScales.clampedProgress(Double.infinity) == nil)
    #expect(MetricScales.clampedProgress(-0.25) == 0)
    #expect(MetricScales.clampedProgress(1.25) == 1)
}

@Test func appAndWidgetProgressRenderingUsesFiniteClampHelper() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let popover = try fixture("Sources/PulseDockApp/WidgetPanelView.swift")
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(dashboard.contains("MetricScales.clampedProgress(progress)"))
    #expect(popover.contains("MetricScales.clampedProgress(progress)"))
    #expect(widget.contains("MetricScales.clampedProgress(progress)"))
    #expect(!dashboard.contains("min(max(progress, 0), 1)"))
    #expect(!popover.contains("min(max(progress, 0), 1)"))
    #expect(!widget.contains("min(max(progress, 0), 1)"))
}

@Test func widgetHeaderAndDecorativeMarksHaveAccessibleSemantics() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(widget.contains("private struct WidgetHeader"))
    #expect(widget.contains(".accessibilityElement(children: .combine)"))
    #expect(widget.contains(".accessibilityLabel(hasTimeReport ? \"\\(title), \\(timeText)\" : title)"))
    #expect(widget.contains(".accessibilityHidden(true)"))
}

@Test func widgetUserFacingShortLabelsAreLocalized() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let strings = try fixture("Sources/PulseDockWidget/PulseDockWidgetStrings.swift")

    #expect(widget.contains(".configurationDisplayName(PulseDockWidgetStrings.widgetDisplayName)"))
    #expect(widget.contains("PulseDockWidgetStrings.metricCPU"))
    #expect(widget.contains("PulseDockWidgetStrings.metricMemoryCompact"))
    #expect(widget.contains("PulseDockWidgetStrings.powerUPS"))
    #expect(strings.contains("widget.display_name"))
    #expect(strings.contains("widget.metric.cpu"))
    #expect(strings.contains("widget.metric.memory_compact"))
    #expect(strings.contains("widget.power.ups"))
}
```

- [ ] **Step 2: Run targeted tests and confirm RED**

Run:

```bash
swift test --filter metricScalesRejectsNanProgressBeforeSwiftUITrimAndFrame
swift test --filter appAndWidgetProgressRenderingUsesFiniteClampHelper
swift test --filter widgetHeaderAndDecorativeMarksHaveAccessibleSemantics
swift test --filter widgetUserFacingShortLabelsAreLocalized
```

Expected: FAIL before implementation.

- [ ] **Step 3: Add finite progress helper**

In `Sources/SharedMetrics/MetricScales.swift`, add:

```swift
public static func clampedProgress(_ progress: Double) -> Double? {
    guard progress.isFinite else { return nil }
    return min(max(progress, 0), 1)
}
```

Use this helper in ring trims:

```swift
if let progress, let clamped = MetricScales.clampedProgress(progress) {
    Circle()
        .trim(from: 0, to: clamped)
        .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        .rotationEffect(.degrees(-90))
}
```

Use this helper in progress bars:

```swift
private func progressFillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat {
    guard let normalizedProgress = MetricScales.clampedProgress(progress), normalizedProgress > 0 else {
        return 0
    }
    return max(minimumVisibleWidth, totalWidth * normalizedProgress)
}
```

- [ ] **Step 4: Fix widget header accessibility**

Change `WidgetHeader.body` to include the same semantics as `CompactWidgetHeader`:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(hasTimeReport ? "\(title), \(timeText)" : title)
```

Mark decorative `Image` and live-status `Circle` as hidden:

```swift
Image(systemName: "waveform.path.ecg.rectangle")
    .font(.system(size: 13, weight: .semibold))
    .foregroundStyle(WidgetColor.green(for: colorScheme))
    .accessibilityHidden(true)

Circle()
    .fill(WidgetColor.green(for: colorScheme))
    .frame(width: 6, height: 6)
    .accessibilityHidden(true)
```

Apply the same hidden marks to `CompactWidgetHeader`.

- [ ] **Step 5: Localize widget-owned short labels**

In `PulseDockWidgetStrings.swift`, add:

```swift
static var widgetDisplayName: String {
    localized("widget.display_name", defaultValue: "Pulse Dock")
}

static var metricCPU: String {
    localized("widget.metric.cpu", defaultValue: "CPU")
}

static var metricMemoryCompact: String {
    localized("widget.metric.memory_compact", defaultValue: "MEM")
}

static var powerUPS: String {
    localized("widget.power.ups", defaultValue: "UPS")
}

static var staleData: String {
    localized("widget.status.stale_data", defaultValue: "Stale data")
}
```

Replace widget hardcoded uses:

```swift
.configurationDisplayName(PulseDockWidgetStrings.widgetDisplayName)
RingMetric(title: PulseDockWidgetStrings.metricCPU, ...)
RingMetric(title: PulseDockWidgetStrings.metricMemoryCompact, ...)
return PulseDockWidgetStrings.powerUPS
```

Add matching keys to `Sources/PulseDockWidget/Resources/PulseDockWidget.xcstrings` for `en` and `zh-Hans`.

- [ ] **Step 6: Keep technical and brand labels scoped**

Do not localize these unless product direction changes:

```text
CPU
DNS
IPv4
IPv6
Pulse Dock
```

Localize the widget-owned compact variants because they appear as standalone user-facing labels and already flow through widget string catalogs after this task.

- [ ] **Step 7: Run validation and commit**

Run:

```bash
swift test --filter metricScalesRejectsNanProgressBeforeSwiftUITrimAndFrame
swift test --filter appAndWidgetProgressRenderingUsesFiniteClampHelper
swift test --filter widgetHeaderAndDecorativeMarksHaveAccessibleSemantics
swift test --filter widgetUserFacingShortLabelsAreLocalized
scripts/audit-localization.sh
swift test
```

Expected: all PASS.

Commit:

```bash
git add Sources/SharedMetrics/MetricScales.swift Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Sources/PulseDockWidget/PulseDockWidgetStrings.swift Sources/PulseDockWidget/Resources/PulseDockWidget.xcstrings Tests/SharedMetricsTests/MetricFormattingTests.swift Tests/SharedMetricsTests/LocalizationGateTests.swift
git commit -m "fix: sanitize progress and complete widget semantics"
```

---

### Task 6: Add Shared Snapshot Schema And Decode Consistency

**Files:**
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift`
- Modify: `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write schema and report-flag tests**

Add:

```swift
@Test func metricSnapshotHasExplicitSchemaVersionAndDecodesCurrentSchema() throws {
    let snapshot = MetricSnapshot.placeholder
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(MetricSnapshot.self, from: data)

    #expect(decoded.schemaVersion == MetricSnapshot.currentSchemaVersion)
    #expect(MetricSnapshot.currentSchemaVersion == 1)
}

@Test func metricSnapshotDecoderKeepsInitReportInferenceSymmetric() throws {
    let metricSnapshot = try fixture("Sources/SharedMetrics/MetricSnapshot.swift")

    #expect(metricSnapshot.contains("public static let currentSchemaVersion = 1"))
    #expect(metricSnapshot.contains("schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion"))
    #expect(metricSnapshot.contains("hasLoadAverageReport = try values.decodeIfPresent(Bool.self, forKey: .hasLoadAverageReport) ?? (loadAverage > 0 || loadAverage5 > 0 || loadAverage15 > 0)"))
    #expect(metricSnapshot.contains("hasRunningAppCountReport = try values.decodeIfPresent(Bool.self, forKey: .hasRunningAppCountReport) ?? (processCount > 0 || activeApplicationCount > 0 || hiddenApplicationCount > 0)"))
    #expect(metricSnapshot.contains("hasUptimeReport = try values.decodeIfPresent(Bool.self, forKey: .hasUptimeReport) ?? (uptimeSeconds > 0)"))
}
```

- [ ] **Step 2: Run targeted tests and confirm RED**

Run:

```bash
swift test --filter metricSnapshotHasExplicitSchemaVersionAndDecodesCurrentSchema
swift test --filter metricSnapshotDecoderKeepsInitReportInferenceSymmetric
```

Expected: FAIL before implementation.

- [ ] **Step 3: Add schema version to MetricSnapshot**

In `MetricSnapshot`, add:

```swift
public static let currentSchemaVersion = 1
public var schemaVersion: Int
```

Add `schemaVersion` to `CodingKeys`.

In the public initializer, add this parameter first or last with a default:

```swift
schemaVersion: Int = MetricSnapshot.currentSchemaVersion,
```

Assign:

```swift
self.schemaVersion = schemaVersion
```

In `placeholder`, rely on the default schema value.

- [ ] **Step 4: Make decoder inference symmetric with initializer inference**

In `init(from decoder:)`, decode schema and report flags with the same fallback rules as `init`:

```swift
schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
```

Use nil-coalescing inference for legacy payloads:

```swift
hasLoadAverageReport = try values.decodeIfPresent(Bool.self, forKey: .hasLoadAverageReport)
    ?? (loadAverage > 0 || loadAverage5 > 0 || loadAverage15 > 0)

hasRunningAppCountReport = try values.decodeIfPresent(Bool.self, forKey: .hasRunningAppCountReport)
    ?? (processCount > 0 || activeApplicationCount > 0 || hiddenApplicationCount > 0)

hasUptimeReport = try values.decodeIfPresent(Bool.self, forKey: .hasUptimeReport)
    ?? (uptimeSeconds > 0)
```

For network byte counters, keep the existing directional inference shape and ensure both decoded and initializer paths use OR semantics when old payloads omit explicit report flags.

- [ ] **Step 5: Preserve compact snapshot trimming with schema**

In `MetricSnapshot+WidgetCompact.swift`, ensure compact snapshots retain schema:

```swift
var compact = self
compact.schemaVersion = schemaVersion
```

Keep expensive arrays trimmed:

```swift
compact.runningApps = Array(runningApps.prefix(3))
compact.gpuDevices = []
compact.displays = []
compact.storageVolumes = Array(storageVolumes.prefix(1))
compact.networkInterfaces = Array(networkInterfaces.prefix(2))
```

- [ ] **Step 6: Run tests and commit**

Run:

```bash
swift test --filter metricSnapshotHasExplicitSchemaVersionAndDecodesCurrentSchema
swift test --filter metricSnapshotDecoderKeepsInitReportInferenceSymmetric
swift test
```

Expected: all PASS.

Commit:

```bash
git add Sources/SharedMetrics/MetricSnapshot.swift Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "feat: version shared metric snapshots"
```

---

### Task 7: Strengthen Build, Signing, And Release Gates

**Files:**
- Modify: `scripts/archive-app-store.sh`
- Modify: `scripts/generate-xcodeproj.rb`
- Modify: `Tests/SharedMetricsTests/LocalizationGateTests.swift`
- Modify: `docs/app-store-release-checklist.md`
- Modify: `.gitignore`

- [ ] **Step 1: Write release gate tests**

Add:

```swift
@Test func releaseBuildGatesVerifyBundleIdentifiersEntitlementsAndSwiftVersion() throws {
    let project = try fixture("PulseDock.xcodeproj/project.pbxproj")
    let appGroup = try fixture("Sources/SharedMetrics/PulseDockAppGroup.swift")
    let appEntitlements = try fixture("Resources/PulseDock.entitlements")
    let widgetEntitlements = try fixture("Resources/PulseDockWidget.entitlements")
    let archiveScript = try fixture("scripts/archive-app-store.sh")
    let generator = try fixture("scripts/generate-xcodeproj.rb")

    #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER = com.ifonly3.pulsedock;"))
    #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER = com.ifonly3.pulsedock.widget;"))
    #expect(project.contains("SWIFT_VERSION = 6.0;"))
    #expect(appGroup.contains(#"appBundleIdentifier = "com.ifonly3.pulsedock""#))
    #expect(appGroup.contains(#"widgetBundleIdentifier = "com.ifonly3.pulsedock.widget""#))
    #expect(appEntitlements.contains("group.com.ifonly3.pulsedock"))
    #expect(widgetEntitlements.contains("group.com.ifonly3.pulsedock"))
    #expect(archiveScript.contains("verify_entitlements"))
    #expect(archiveScript.contains("codesign -d --entitlements :-"))
    #expect(archiveScript.contains("group.com.ifonly3.pulsedock"))
    #expect(generator.contains("SWIFT_VERSION = 6.0"))
}
```

Add resource-copy gate:

```swift
@Test func sharedLocalizationResourcesAreCopiedForAppAndWidgetTargets() throws {
    let generator = try fixture("scripts/generate-xcodeproj.rb")
    let package = try fixture("Package.swift")

    #expect(package.contains(#".process("Resources")"#))
    #expect(generator.contains("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings"))
    #expect(generator.contains("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"))
}
```

- [ ] **Step 2: Run targeted tests and confirm RED where gates are missing**

Run:

```bash
swift test --filter releaseBuildGatesVerifyBundleIdentifiersEntitlementsAndSwiftVersion
swift test --filter sharedLocalizationResourcesAreCopiedForAppAndWidgetTargets
```

Expected: The first test fails until archive verification and project-level Swift 6 are present. The second test should pass unless resource copying regressed.

- [ ] **Step 3: Add archive entitlements verification**

In `scripts/archive-app-store.sh`, add:

```bash
verify_entitlements() {
  local bundle_path="$1"
  local label="$2"
  local expected_group="group.com.ifonly3.pulsedock"
  local entitlements

  entitlements="$(codesign -d --entitlements :- "$bundle_path" 2>/dev/null || true)"
  if ! printf '%s\n' "$entitlements" | grep -q "$expected_group"; then
    echo "error: $label is missing App Group entitlement $expected_group" >&2
    return 1
  fi
}
```

After archive/export paths are known, call:

```bash
APP_PRODUCT="$ARCHIVE_PATH/Products/Applications/Pulse Dock.app"
WIDGET_PRODUCT="$APP_PRODUCT/Contents/PlugIns/PulseDockWidgetExtension.appex"
verify_entitlements "$APP_PRODUCT" "Pulse Dock.app"
verify_entitlements "$WIDGET_PRODUCT" "PulseDockWidgetExtension.appex"
```

- [ ] **Step 4: Set project-level Swift version to 6.0**

In `scripts/generate-xcodeproj.rb`, ensure both project-level and target-level build settings write:

```ruby
config.build_settings["SWIFT_VERSION"] = "6.0"
```

Regenerate:

```bash
scripts/generate-xcodeproj.rb
```

- [ ] **Step 5: Clean ignored legacy dist artifact**

Remove the stale legacy bundle from the working tree:

```bash
rm -rf "dist/System Dashboard.app"
```

Keep `.gitignore` covering generated artifacts:

```gitignore
dist/
*.xcarchive/
*.dSYM/
```

- [ ] **Step 6: Update release checklist**

Add these bullets to `docs/app-store-release-checklist.md`:

```markdown
- Confirm `scripts/archive-app-store.sh` exits non-zero if either the app or widget archive product is missing `group.com.ifonly3.pulsedock`.
- After TestFlight install, launch the app once, add the widget, and verify the widget receives a shared snapshot within 60 seconds.
- Keep `dist/` treated as disposable build output; do not submit or review stale bundles from this directory.
```

- [ ] **Step 7: Run gates and commit**

Run:

```bash
scripts/generate-xcodeproj.rb
swift test --filter releaseBuildGatesVerifyBundleIdentifiersEntitlementsAndSwiftVersion
swift test --filter sharedLocalizationResourcesAreCopiedForAppAndWidgetTargets
swift test
```

Expected: all PASS.

Commit:

```bash
git add scripts/archive-app-store.sh scripts/generate-xcodeproj.rb PulseDock.xcodeproj/project.pbxproj Tests/SharedMetricsTests/LocalizationGateTests.swift docs/app-store-release-checklist.md .gitignore
git commit -m "chore: verify app store signing gates"
```

---

### Task 8: Correct Review Documents And Final Verification

**Files:**
- Modify: `docs/review/top/final-review-v2.md`
- Modify: `docs/review/middle/integrated-review-v2.md`
- Modify: `docs/review/REVIEW-PLAN.md`
- Modify: `docs/data-capability-audit.md`

- [ ] **Step 1: Write documentation consistency gate**

Add this test to `Tests/SharedMetricsTests/LocalizationGateTests.swift`:

```swift
@Test func reviewV2DocumentsUseCorrectedSeverityAndDoNotCarryStaleClaims() throws {
    let top = try fixture("docs/review/top/final-review-v2.md")
    let middle = try fixture("docs/review/middle/integrated-review-v2.md")
    let plan = try fixture("docs/review/REVIEW-PLAN.md")

    #expect(top.contains("CGDisplay can still provide refresh rate"))
    #expect(top.contains("watchdog risk is unmeasured"))
    #expect(top.contains("P2-19 removed: undo:/redo: are valid AppKit responder-chain selectors"))
    #expect(!top.contains("refresh 永远为空"))
    #expect(!top.contains("无需降级/升级"))
    #expect(!middle.contains("P0-2 新"))
    #expect(plan.contains("P0-2 Widget synchronous fallback sampler"))
}
```

- [ ] **Step 2: Run targeted test and confirm RED**

Run:

```bash
swift test --filter reviewV2DocumentsUseCorrectedSeverityAndDoNotCarryStaleClaims
```

Expected: FAIL before document edits.

- [ ] **Step 3: Update top review wording**

In `docs/review/top/final-review-v2.md`:

```markdown
P0-1 修正：NSScreen-derived scale/color and refresh fallback are dropped when sampling runs off-main. CGDisplay may still provide refresh rate, so do not describe refresh as always empty.

P0-2 修正：Widget fallback synchronously invokes a sampler path that can touch mach/IOKit/Metal/CG work. The watchdog risk is real, but the exact duration is unmeasured in this review.

P2-19 removed: undo:/redo: are valid AppKit responder-chain selectors for text editing menus.
```

Replace `本次子 agent 判定整体准确，无需降级/升级` with:

```markdown
本次复核确认大多数高优先级问题属实，但 P1-9、P2-5、P2-7/P2-8、P2-16、P2-19、P2-20、P2-25 需要降级、改写或删除，避免把产品判断写成事实。
```

- [ ] **Step 4: Align middle and plan P0 numbering**

Use this P0 mapping in all three review docs:

```markdown
P0-1 Display metadata is lost when detached sampling needs NSScreen metadata.
P0-2 Widget timeline fallback must not synchronously run the full SystemSampler path.
```

Move App Group production signing to P1 release gate wording.

- [ ] **Step 5: Update data capability audit**

Add:

```markdown
Display metadata that depends on NSScreen is collected through a main-thread snapshot before CoreGraphics display rows are assembled. This preserves Retina scale, color-space model, and refresh fallback when app sampling runs from detached tasks.

Widget timelines prefer shared app snapshots. When a shared snapshot is unavailable, the widget uses compact sampling that skips GPU devices, display topology, mounted volume enumeration, and running app inventory.
```

- [ ] **Step 6: Run full verification**

Run:

```bash
swift build
swift build --target PulseDockWidget
swift test
scripts/audit-localization.sh
scripts/validate-public-pages.sh
scripts/validate-app-store-screenshots.sh
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -derivedDataPath .build/xcode-derived build
```

Expected: all commands exit 0.

- [ ] **Step 7: Commit final docs and generated project**

Commit:

```bash
git add docs/review/top/final-review-v2.md docs/review/middle/integrated-review-v2.md docs/review/REVIEW-PLAN.md docs/data-capability-audit.md Tests/SharedMetricsTests/LocalizationGateTests.swift PulseDock.xcodeproj/project.pbxproj
git commit -m "docs: align review v2 fixes with verified findings"
```

---

## Parallelization Guide

Safe parallel lanes after Task 1 lands:

| Lane | Tasks | Notes |
| --- | --- | --- |
| A | Task 2 | Touches widget provider and compact sampler. Avoid parallel edits to `SystemSampler.swift` with Task 1. |
| B | Task 3 | Touches app lifecycle and persistence. Can run after Task 1 because it uses `invalidateDisplaysCache()`. |
| C | Task 4 | Touches dashboard performance. Avoid parallel edits to `DashboardView.swift` with Task 5. |
| D | Task 5 | Touches widget semantics and progress helpers. Can run after Task 2 if widget file is already stable. |
| E | Task 6 | Touches `MetricSnapshot`; coordinate with Task 2 if compact snapshot fields change. |
| F | Task 7 | Build/release gates; can run in parallel with UI work. |
| G | Task 8 | Runs last after code behavior is settled. |

Recommended order:

```text
Task 1 -> Task 2
Task 1 -> Task 3
Task 4 and Task 5 after dashboard/widget file ownership is assigned
Task 6 before final widget snapshot verification
Task 7 before archive
Task 8 last
```

## Final Acceptance Checklist

- [ ] `swift build` passes.
- [ ] `swift build --target PulseDockWidget` passes.
- [ ] `swift test` passes.
- [ ] `scripts/audit-localization.sh` passes.
- [ ] `scripts/validate-public-pages.sh` passes.
- [ ] `scripts/validate-app-store-screenshots.sh` passes.
- [ ] `scripts/generate-xcodeproj.rb` is idempotent.
- [ ] `xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -derivedDataPath .build/xcode-derived build` passes.
- [ ] Manual app run shows display backing scale and color space in the GPU/Display page.
- [ ] Widget gallery uses representative data and does not block on full sampling.
- [ ] Widget timeline receives shared app snapshot after app launch.
- [ ] App wake resets CPU/network baselines and invalidates display cache.
- [ ] App Group entitlements are present in archived app and widget.
- [ ] `dist/System Dashboard.app` is removed from local build output.

## Self-Review

- Spec coverage: Covers verified P0, P1, and material P2 items from the top-review verification pass, including corrections for overstated findings.
- Placeholder scan: This plan contains no placeholder instructions or open-ended error-handling steps. Each code task includes concrete tests, code shape, commands, and expected results.
- Type consistency: New names are consistent across tasks: `ScreenDisplaySnapshot`, `screenDisplaySnapshot()`, `invalidateDisplaysCache()`, `sampleWidgetCompact(now:)`, `sampledSnapshotForTimeline(now:)`, `MetricScales.clampedProgress(_:)`, and `schemaVersion`.
