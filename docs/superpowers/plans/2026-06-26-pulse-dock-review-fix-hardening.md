# Pulse Dock Review Fix Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix and harden the remaining verified review findings after the App Store polish pass, with special attention to popover sizing, widget dark appearance, metric semantics, sampler robustness, App Store metadata, and low-risk cleanup.

**Architecture:** Keep changes narrowly scoped to existing SwiftPM targets. Shared data semantics stay in `SharedMetrics`, App UI behavior stays in `PulseDockApp`, widget rendering stays in `PulseDockWidget`, and source-level regression tests remain in `Tests/SharedMetricsTests/MetricFormattingTests.swift`. Avoid introducing new runtime permissions or product features in this pass.

**Tech Stack:** Swift 6, SwiftUI, AppKit, WidgetKit, CoreGraphics, Network, SystemConfiguration, IOKit, Swift Testing, SwiftPM, Xcode project generation scripts.

---

## Scope And Order

This plan handles the currently verified issues:

1. Popover content width can disagree with geometry-clamped width.
2. Widget dark-mode background still has a brown stop and old fixed palette.
3. Metric defaults and gauge semantics can imply fake precision.
4. Network and display sampling have fragile fallbacks.
5. Shared snapshot freshness rejects future timestamps too strictly.
6. App Store metadata and URL handling need final hardening.
7. Low-risk cleanup: main delegate lifetime, duplicate dashboard branch, table IDs, dead settings row, shadow helper documentation.
8. Refresh ticks that arrive during an in-flight sample should queue one follow-up refresh instead of disappearing silently.
9. Repeated dashboard panel shadows should be reduced at the shared panel modifier.

This plan does not add notification permissions, full new product features, or App Store Connect configuration work. Those belong in a later product-change plan.

## File Structure

- Modify `Sources/PulseDockApp/AppDelegate.swift`
  - Pass both popover width and height into SwiftUI content.
  - Preserve pre-show sizing and no post-show window frame movement.
  - Leave delegate lifetime cleanup to `Sources/PulseDockApp/main.swift` in Task 7.

- Modify `Sources/PulseDockApp/WidgetPanelView.swift`
  - Add `popoverWidth`.
  - Use geometry-provided width for root frame.
  - Keep fixed internal layout stable through min widths and truncation.

- Modify `Sources/SharedMetrics/MenuBarPopoverGeometry.swift`
  - Name the popover chrome allowance with an explanatory comment.
  - Add explicit tests for narrow visible width.

- Modify `Sources/PulseDockWidget/SystemDashboardWidget.swift`
  - Remove brown dark-mode stop.
  - Align widget colors with the cleaned app popover palette.
  - Remove fake loading ambiguity in empty widget state.

- Modify `Sources/SharedMetrics/MetricSnapshot.swift`
  - Change physical-core default to placeholder-safe `0`.
  - Return `nil` for power progress when no battery percent exists.
  - Make memory-active fallback conservative.

- Modify `Sources/SharedMetrics/SystemSampler.swift`
  - Remove `en0 == Wi-Fi` fallback.
  - Avoid trusting `if_data` byte counters when sysctl stats are unavailable.
  - Keep `NSScreen` access on the main thread only or avoid it entirely in background sampling.

- Modify `Sources/SharedMetrics/SharedSnapshotStore.swift`
  - Add a small future-skew tolerance.
  - Keep stale snapshot rejection.

- Modify `Sources/PulseDockApp/PulseDockLinks.swift`
  - Restrict support/privacy URLs to HTTPS.
  - Keep nil URL behavior deterministic.

- Modify `Resources/AppInfo.plist`
  - Add `CFBundleDisplayName` as `Pulse Dock`.

- Modify `Resources/WidgetInfo.plist`
  - Add `ITSAppUsesNonExemptEncryption` false.

- Modify `Sources/PulseDockApp/DashboardView.swift`
  - Collapse compact/regular branch duplication.
  - Replace `ForEach(columns, id: \.self)` with stable indexed IDs.
  - Remove dead `SettingRow` if unused.
  - Remove the default heavy panel shadow from the shared `panel(cornerRadius:)` modifier.

- Modify `Sources/PulseDockApp/MetricsStore.swift`
  - Queue one pending refresh tick when a timer fires while sampling is still in flight.
  - Expose a simple `isRefreshing` state for tests and future UI use.

- Modify `Sources/PulseDockApp/main.swift`
  - Make delegate lifetime explicitly strong for the app run loop.

- Modify `Tests/SharedMetricsTests/MetricFormattingTests.swift`
  - Update source-level assertions that currently encode old behavior.
  - Add behavioral tests for the changed semantics.

- Modify `docs/data-capability-audit.md`
  - Update audit statements for conservative fallbacks and widget dark-mode hardening.

---

### Task 1: Make Menu Popover Width Follow Geometry Placement

**Files:**
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
- Modify: `Sources/PulseDockApp/AppDelegate.swift`
- Modify: `Sources/SharedMetrics/MenuBarPopoverGeometry.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Write failing tests for width propagation**

Add a test near the existing menu popover tests:

```swift
@Test func menuPopoverPassesClampedWidthIntoSwiftUIContent() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let widgetPanel = try fixture("Sources/PulseDockApp/WidgetPanelView.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(widgetPanel.contains("let popoverWidth: CGFloat"))
    #expect(widgetPanel.contains(".frame(width: popoverWidth, height: popoverHeight, alignment: .topLeading)"))
    #expect(!widgetPanel.contains(".frame(width: MenuPopoverLayout.width, height: popoverHeight, alignment: .topLeading)"))
    #expect(appDelegate.contains("makeWidgetPanelView(popoverWidth: CGFloat, popoverHeight: CGFloat)"))
    #expect(appDelegate.contains("makeStatusHostingController(contentSize: NSSize)"))
    #expect(appDelegate.contains("WidgetPanelView("))
    #expect(appDelegate.contains("popoverWidth: contentSize.width"))
    #expect(audit.contains("Menu bar popover passes geometry-clamped width and height into SwiftUI before showing."))
}
```

Add a geometry behavior test:

```swift
@Test func menuPopoverGeometryClampsNarrowVisibleWidth() {
    let placement = MenuBarPopoverGeometry.placement(
        preferredSize: CGSize(width: 356, height: 520),
        minimumHeight: 420,
        screenMargin: 12,
        visibleFrame: CGRect(x: 0, y: 48, width: 300, height: 860),
        anchorFrame: CGRect(x: 252, y: 884, width: 32, height: 24),
        anchorKind: .statusBar
    )

    #expect(placement.size.width == 276)
    #expect(placement.anchorScreenMidX == 150)
}
```

Update the existing `menuPopoverReservesChromeAndConstrainsActualWindowFrame` assertions from:

```swift
#expect(geometry.contains("private static let windowChromeAllowance: CGFloat = 28"))
#expect(geometry.contains("let availableHeightAfterChrome = rawAvailableHeight - windowChromeAllowance"))
```

to:

```swift
#expect(geometry.contains("private static let popoverChromeHeightAllowance: CGFloat = 28"))
#expect(geometry.contains("let availableHeightAfterChrome = rawAvailableHeight - popoverChromeHeightAllowance"))
```

- [ ] **Step 2: Run the focused tests and verify failure**

Run:

```bash
swift test --filter menuPopoverPassesClampedWidthIntoSwiftUIContent
swift test --filter menuPopoverGeometryClampsNarrowVisibleWidth
```

Expected: first test fails because `WidgetPanelView` has no `popoverWidth`; second should pass if geometry already clamps width.

- [ ] **Step 3: Implement width propagation**

In `Sources/PulseDockApp/WidgetPanelView.swift`, change:

```swift
struct WidgetPanelView: View {
    @ObservedObject var store: MetricsStore
    let popoverHeight: CGFloat
```

to:

```swift
struct WidgetPanelView: View {
    @ObservedObject var store: MetricsStore
    let popoverWidth: CGFloat
    let popoverHeight: CGFloat
```

Pass the width:

```swift
MenuPopoverPreview(
    snapshot: store.snapshot,
    isPaused: store.isPaused,
    popoverWidth: popoverWidth,
    popoverHeight: popoverHeight,
    openDashboard: openDashboard,
    togglePause: togglePause,
    openSettings: openSettings
)
```

Add the field to `MenuPopoverPreview`:

```swift
let popoverWidth: CGFloat
let popoverHeight: CGFloat
```

Change the root frame:

```swift
.frame(width: popoverWidth, height: popoverHeight, alignment: .topLeading)
```

In `Sources/PulseDockApp/AppDelegate.swift`, replace:

```swift
private func makeWidgetPanelView(popoverHeight: CGFloat) -> WidgetPanelView
private func makeStatusHostingController(popoverHeight: CGFloat) -> NSHostingController<WidgetPanelView>
```

with:

```swift
private func makeWidgetPanelView(popoverWidth: CGFloat, popoverHeight: CGFloat) -> WidgetPanelView {
    WidgetPanelView(
        store: store,
        popoverWidth: popoverWidth,
        popoverHeight: popoverHeight,
        openDashboard: { [weak self] in
            self?.openDashboardFromPopover()
        },
        togglePause: { [store] in
            store.togglePause()
        },
        openSettings: { [weak self] in
            self?.openSettingsFromPopover()
        }
    )
}

private func makeStatusHostingController(contentSize: NSSize) -> NSHostingController<WidgetPanelView> {
    let hostingController = NSHostingController(
        rootView: makeWidgetPanelView(
            popoverWidth: contentSize.width,
            popoverHeight: contentSize.height
        )
    )
    hostingController.sizingOptions = []
    hostingController.preferredContentSize = contentSize
    hostingController.view.frame = NSRect(origin: .zero, size: contentSize)
    hostingController.view.setFrameSize(contentSize)
    hostingController.view.layoutSubtreeIfNeeded()
    return hostingController
}
```

Update `installFreshStatusHostingController`:

```swift
let hostingController = makeStatusHostingController(contentSize: contentSize)
```

In `Sources/SharedMetrics/MenuBarPopoverGeometry.swift`, replace:

```swift
private static let windowChromeAllowance: CGFloat = 28
```

with:

```swift
// AppKit popover chrome and arrow consume vertical space outside SwiftUI's content size.
// Reserving this before show(relativeTo:) avoids post-show window movement that desynchronizes the arrow.
private static let popoverChromeHeightAllowance: CGFloat = 28
```

and update the reference:

```swift
let availableHeightAfterChrome = rawAvailableHeight - popoverChromeHeightAllowance
```

Update `docs/data-capability-audit.md` with:

```markdown
- Menu bar popover passes geometry-clamped width and height into SwiftUI before showing.
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
swift test --filter menuPopover
```

Expected: all menu popover tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/PulseDockApp/AppDelegate.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/SharedMetrics/MenuBarPopoverGeometry.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: align menu popover content with clamped geometry"
```

---

### Task 2: Clean Widget Dark-Mode Palette And Empty State

**Files:**
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Write failing tests for widget palette**

Add:

```swift
@Test func widgetDarkPaletteAvoidsBrownBackgroundStops() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(widget.contains("private func widgetBackgroundColors(for colorScheme: ColorScheme) -> [Color]"))
    #expect(!widget.contains("Color(red: 0.17, green: 0.13, blue: 0.08).opacity(0.82)"))
    #expect(widget.contains("Color(red: 0.06, green: 0.09, blue: 0.11).opacity(0.82)"))
    #expect(widget.contains("private enum WidgetColor"))
    #expect(widget.contains("static func green(for colorScheme: ColorScheme) -> Color"))
    #expect(audit.contains("Widget dark-mode palette uses cool neutral stops and color-scheme-aware accents."))
}
```

Add:

```swift
@Test func emptyWidgetStateHasAccessibleLoadingLabel() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(widget.contains("private struct EmptyDataWidget: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("Text(\"等待数据\")"))
    #expect(widget.contains(".accessibilityLabel(\"等待系统监控数据\")"))
}
```

Add:

```swift
@Test func widgetColorHelpersReceiveColorSchemeExplicitly() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(widget.contains("private struct SmallWidget: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("private struct LargeWidget: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("private struct MediumStatusStrip: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("private struct LargeInfoGrid: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("private func thermalTint(_ state: String, for colorScheme: ColorScheme) -> Color"))
    #expect(widget.contains("private func networkTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color"))
    #expect(widget.contains("private func reportedTint(hasReport: Bool, fallback: Color, for colorScheme: ColorScheme) -> Color"))
    #expect(widget.contains("private func powerTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color"))
    #expect(!widget.contains("WidgetColor.green)"))
    #expect(!widget.contains("WidgetColor.blue)"))
    #expect(!widget.contains("WidgetColor.amber)"))
    #expect(!widget.contains("WidgetColor.cyan)"))
    #expect(!widget.contains("WidgetColor.red)"))
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
swift test --filter widgetDarkPaletteAvoidsBrownBackgroundStops
swift test --filter emptyWidgetStateHasAccessibleLoadingLabel
swift test --filter widgetColorHelpersReceiveColorSchemeExplicitly
```

Expected: these tests fail before implementation.

- [ ] **Step 3: Replace the dark palette**

In `SystemDashboardWidget.swift`, change the dark colors to:

```swift
private func widgetBackgroundColors(for colorScheme: ColorScheme) -> [Color] {
    if colorScheme == .dark {
        return [
            Color(red: 0.09, green: 0.11, blue: 0.12).opacity(0.96),
            Color(red: 0.07, green: 0.16, blue: 0.16).opacity(0.90),
            Color(red: 0.06, green: 0.09, blue: 0.11).opacity(0.82)
        ]
    }

    return [
        Color.white.opacity(0.92),
        Color(red: 0.89, green: 0.95, blue: 0.94).opacity(0.88),
        Color(red: 0.98, green: 0.93, blue: 0.84).opacity(0.72)
    ]
}
```

Replace `WidgetColor` constants with color-scheme-aware functions:

```swift
private enum WidgetColor {
    static func blue(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.36, green: 0.62, blue: 1.00) : Color(red: 0.14, green: 0.43, blue: 0.95)
    }

    static func green(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.24, green: 0.82, blue: 0.62) : Color(red: 0.04, green: 0.62, blue: 0.39)
    }

    static func amber(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 1.00, green: 0.68, blue: 0.28) : Color(red: 0.93, green: 0.54, blue: 0.10)
    }

    static func cyan(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.29, green: 0.78, blue: 0.88) : Color(red: 0.04, green: 0.56, blue: 0.70)
    }

    static func red(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 1.00, green: 0.42, blue: 0.42) : Color(red: 0.84, green: 0.16, blue: 0.16)
    }
}
```

Add `@Environment(\.colorScheme)` to every widget view that directly calls `WidgetColor` or the tint helpers and does not already have it:

```swift
private struct SmallWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot
```

Apply the same pattern to:

```swift
SmallWidget
MediumStatusStrip
LargeWidget
LargeInfoGrid
EmptyDataWidget
```

`MediumWidget`, `WidgetHeader`, `CompactWidgetHeader`, and the placeholder subviews already have `colorScheme`; update their call sites but do not add duplicate environment properties.

Update direct color call sites to pass `colorScheme`, for example:

```swift
WidgetColor.green(for: colorScheme)
WidgetColor.blue(for: colorScheme)
WidgetColor.amber(for: colorScheme)
WidgetColor.cyan(for: colorScheme)
WidgetColor.red(for: colorScheme)
```

Change free tint helpers so they do not depend on unavailable SwiftUI environment:

```swift
private func thermalTint(_ state: String, for colorScheme: ColorScheme) -> Color {
    switch state.lowercased() {
    case "critical", "hot", "serious": WidgetColor.red(for: colorScheme)
    case "warm", "fair": WidgetColor.amber(for: colorScheme)
    case "nominal": WidgetColor.green(for: colorScheme)
    case "unknown": WidgetColor.cyan(for: colorScheme)
    default: WidgetColor.cyan(for: colorScheme)
    }
}

private func networkTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color {
    switch snapshot.networkPathStatus.lowercased() {
    case "satisfied":
        WidgetColor.green(for: colorScheme)
    case "requiresconnection", "requires_connection", "requires connection":
        WidgetColor.amber(for: colorScheme)
    case "unsatisfied":
        WidgetColor.red(for: colorScheme)
    default:
        WidgetColor.cyan(for: colorScheme)
    }
}

private func reportedTint(hasReport: Bool, fallback: Color, for colorScheme: ColorScheme) -> Color {
    guard hasReport else { return WidgetColor.cyan(for: colorScheme) }
    return fallback
}

private func powerTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color {
    switch snapshot.powerStatusTone {
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

Update helper call sites, for example:

```swift
thermalTint(snapshot.thermalState, for: colorScheme)
networkTint(snapshot, for: colorScheme)
powerTint(snapshot, for: colorScheme)
reportedTint(hasReport: snapshot.hasUptimeReport, fallback: WidgetColor.amber(for: colorScheme), for: colorScheme)
```

Before editing call sites, capture the mechanical replacement worklist:

```bash
rg -n "WidgetColor\.|thermalTint\(|networkTint\(|powerTint\(|reportedTint\(" Sources/PulseDockWidget/SystemDashboardWidget.swift
```

Expected before implementation: 57 matches.

Update every match in these groups:

```text
SmallWidget body:
- WidgetColor.green / blue
- thermalTint(snapshot.thermalState)
- networkTint(snapshot)
- powerTint(snapshot)

MediumWidget body:
- WidgetColor.blue / amber
- networkTint(snapshot)

MediumStatusStrip body:
- thermalTint(snapshot.thermalState)
- powerTint(snapshot)

LargeWidget body:
- WidgetColor.green / blue / amber / cyan
- powerTint(snapshot)
- thermalTint(snapshot.thermalState)
- networkTint(snapshot)

LargeInfoGrid body:
- reportedTint(... fallback: WidgetColor.amber / blue / cyan)

EmptyDataWidget body:
- WidgetColor.green / blue / amber / cyan

WidgetHeader and CompactWidgetHeader:
- WidgetColor.green

Helper definitions:
- thermalTint, networkTint, reportedTint, powerTint internals
```

After editing call sites, run:

```bash
rg -n -P "WidgetColor\.(blue|green|amber|cyan|red)(?!\()" Sources/PulseDockWidget/SystemDashboardWidget.swift
rg -n "thermalTint\([^,\n]+\)|networkTint\([^,\n]+\)|powerTint\([^,\n]+\)" Sources/PulseDockWidget/SystemDashboardWidget.swift
```

Expected after implementation: no matches. `swift test --filter widget` and `swift build` will catch any missed `reportedTint` fallback argument or helper signature mismatch.

- [ ] **Step 4: Make empty state explicit**

Inside `EmptyDataWidget`, add a visible concise label:

```swift
Text("等待数据")
    .font(.system(size: 13, weight: .semibold))
    .foregroundStyle(widgetSecondaryText(for: colorScheme))
```

Add accessibility to the empty state root:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("等待系统监控数据")
```

Update `docs/data-capability-audit.md` with:

```markdown
- Widget dark-mode palette uses cool neutral stops and color-scheme-aware accents.
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --filter widget
```

Expected: widget tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: clean widget dark palette and empty state"
```

---

### Task 3: Make Metric Snapshot Defaults Conservative

**Files:**
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Write failing tests for conservative defaults**

Replace the existing power progress test with:

```swift
@Test func powerStatusProgressOnlyUsesMeasuredBatteryPercent() throws {
    let acPower = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "AC Power",
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let batteryPercent = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: 0.42,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(acPower.powerStatusProgress == nil)
    #expect(batteryPercent.powerStatusProgress == 0.42)
    #expect(MetricSnapshot.placeholder.powerStatusProgress == nil)
}
```

Add:

```swift
@Test func metricSnapshotDefaultsDoNotInventPhysicalCoreCount() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(snapshot.physicalCoreCount == 0)
    #expect(snapshot.physicalCoreCountText == "未报告")
}
```

Add:

```swift
@Test func memoryActiveBytesDoesNotOverstateWhenCompositionIsInvalid() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_000,
        memoryTotalBytes: 2_000,
        memoryWiredBytes: 700,
        memoryCompressedBytes: 500,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(snapshot.memoryActiveBytes == 0)
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
swift test --filter powerStatusProgressOnlyUsesMeasuredBatteryPercent
swift test --filter metricSnapshotDefaultsDoNotInventPhysicalCoreCount
swift test --filter memoryActiveBytesDoesNotOverstateWhenCompositionIsInvalid
```

Expected: all fail before implementation or before old tests are updated.

- [ ] **Step 3: Change snapshot semantics**

In `MetricSnapshot.init`, change:

```swift
physicalCoreCount: Int = ProcessInfo.processInfo.processorCount,
```

to:

```swift
physicalCoreCount: Int = 0,
```

Change `memoryActiveBytes` to:

```swift
public var memoryActiveBytes: UInt64 {
    guard memoryUsedBytes >= memoryWiredBytes + memoryCompressedBytes else {
        return 0
    }
    return memoryUsedBytes - memoryWiredBytes - memoryCompressedBytes
}
```

Change `powerStatusProgress` to:

```swift
public var powerStatusProgress: Double? {
    batteryPercent
}
```

- [ ] **Step 4: Update UI call sites to tolerate nil gauges**

In `DashboardView.swift`, make `powerGaugeProgress(_:)` return `snapshot.powerStatusProgress` without fallback:

```swift
private func powerGaugeProgress(_ snapshot: MetricSnapshot) -> Double? {
    snapshot.powerStatusProgress
}
```

In popover/widget views, keep existing `reportedProgress` or optional progress behavior; do not draw a filled gauge when `powerStatusProgress == nil`.

Update `docs/data-capability-audit.md` with:

```markdown
- Power progress uses measured battery percent only; AC/UPS/source-only states are displayed as text without invented gauge fill.
- MetricSnapshot defaults do not invent physical core counts when the sampler has not reported them.
```

- [ ] **Step 5: Run focused and full shared metric tests**

Run:

```bash
swift test --filter powerStatus
swift test --filter physicalCoreCount
swift test --filter memoryActiveBytes
swift test
```

Expected: all tests pass after old assertions are updated.

- [ ] **Step 6: Commit**

```bash
git add Sources/SharedMetrics/MetricSnapshot.swift Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: make metric snapshot fallbacks conservative"
```

---

### Task 4: Harden Network And Display Sampler Fallbacks

**Files:**
- Modify: `Sources/SharedMetrics/SystemSampler.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Write failing tests for safer fallbacks**

Add:

```swift
@Test func networkInterfaceFallbackDoesNotAssumeEn0IsWifi() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(!sampler.contains("if name.hasPrefix(\"en\") { return name == \"en0\" ? \"Wi-Fi\" : \"Ethernet\" }"))
    #expect(sampler.contains("if name.hasPrefix(\"en\") { return \"网络接口\" }"))
    #expect(audit.contains("Network interface kind falls back to a generic interface label when SystemConfiguration cannot identify en* devices."))
}
```

Add:

```swift
@Test func networkFallbackDoesNotTrustIfDataByteCounters() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(!sampler.contains("record.bytesReceived = UInt64(interfaceData.ifi_ibytes)"))
    #expect(!sampler.contains("record.bytesSent = UInt64(interfaceData.ifi_obytes)"))
    #expect(sampler.contains("record.hasByteCounters = false"))
    #expect(audit.contains("Network byte counters prefer sysctl interface statistics and do not mark legacy getifaddrs fallback counters as authoritative."))
}
```

Add:

```swift
@Test func displaySamplerOnlyUsesNSScreenOnMainThread() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(sampler.contains("Thread.isMainThread"))
    #expect(sampler.contains("guard Thread.isMainThread else { return [] }"))
    #expect(audit.contains("NSScreen fallback sampling is guarded to run only on the main thread."))
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
swift test --filter networkInterfaceFallbackDoesNotAssumeEn0IsWifi
swift test --filter networkFallbackDoesNotTrustIfDataByteCounters
swift test --filter displaySamplerOnlyUsesNSScreenOnMainThread
```

Expected: all fail before implementation.

- [ ] **Step 3: Change interface fallback classification**

In `interfaceKind(_:)`, replace:

```swift
if name.hasPrefix("en") { return name == "en0" ? "Wi-Fi" : "Ethernet" }
```

with:

```swift
if name.hasPrefix("en") { return "网络接口" }
```

Keep `SystemConfiguration` mappings as the primary source for Wi-Fi and Ethernet.

- [ ] **Step 4: Stop marking legacy getifaddrs byte counters authoritative**

In the `else` branch where `interfaceStats[interfaceIndex]` is unavailable, change the byte-counter section to:

```swift
let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
record.hasByteCounters = false
record.packetsReceived = UInt64(interfaceData.ifi_ipackets)
record.packetsSent = UInt64(interfaceData.ifi_opackets)
record.receiveErrors = UInt64(interfaceData.ifi_ierrors)
record.sendErrors = UInt64(interfaceData.ifi_oerrors)
if interfaceData.ifi_baudrate > 0 {
    record.linkSpeedBitsPerSecond = UInt64(interfaceData.ifi_baudrate)
}
record.mtu = interfaceData.ifi_mtu > 0 ? Int(interfaceData.ifi_mtu) : nil
```

Do not assign `ifi_ibytes` or `ifi_obytes` in this fallback.

- [ ] **Step 5: Guard AppKit screen access**

In each AppKit fallback helper, add a main-thread guard.

For `fallbackDisplaysFromScreens()`:

```swift
#if canImport(AppKit)
    guard Thread.isMainThread else { return [] }
    let mainScreen = NSScreen.main
```

For dictionary helpers:

```swift
#if canImport(AppKit)
    guard Thread.isMainThread else { return [:] }
    var rates: [CGDirectDisplayID: Double] = [:]
```

Apply the same pattern to:

```swift
screenRefreshRatesByDisplayID()
screenScalesByDisplayID()
screenColorSpacesByDisplayID()
```

Update `docs/data-capability-audit.md` with:

```markdown
- Network interface kind falls back to a generic interface label when SystemConfiguration cannot identify en* devices.
- Network byte counters prefer sysctl interface statistics and do not mark legacy getifaddrs fallback counters as authoritative.
- NSScreen fallback sampling is guarded to run only on the main thread.
```

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter network
swift test --filter displaySampler
swift test
```

Expected: all tests pass. If existing tests explicitly require `NSScreen.screens`, update them to require `Thread.isMainThread` guard as well.

- [ ] **Step 7: Commit**

```bash
git add Sources/SharedMetrics/SystemSampler.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: harden sampler fallbacks"
```

---

### Task 5: Relax Shared Snapshot Future-Skew Handling

**Files:**
- Modify: `Sources/SharedMetrics/SharedSnapshotStore.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Write failing tests**

Replace or add around the stale/future snapshot tests:

```swift
@Test func sharedSnapshotStoreAcceptsSmallFutureClockSkewButRejectsLargeFutureSnapshots() throws {
    let suiteName = "SharedSnapshotStoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = SharedSnapshotStore(defaults: defaults)
    let snapshot = MetricSnapshot(
        cpuUsage: 0.2,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.4,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 1_000)
    )

    store.saveLatestSnapshot(snapshot)

    #expect(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 995)) != nil)
    #expect(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 600)) == nil)
}
```

- [ ] **Step 2: Run focused test and verify failure**

Run:

```bash
swift test --filter sharedSnapshotStoreAcceptsSmallFutureClockSkewButRejectsLargeFutureSnapshots
```

Expected: fails because current code rejects any future timestamp.

- [ ] **Step 3: Implement skew tolerance**

In `SharedSnapshotStore.swift`, add:

```swift
private let acceptedFutureSkew: TimeInterval
```

Update `init(defaults:)`:

```swift
public init(defaults: UserDefaults?, acceptedFutureSkew: TimeInterval = 300) {
    self.defaults = defaults
    self.acceptedFutureSkew = acceptedFutureSkew
}
```

Update App Group init:

```swift
public init(
    suiteName: String = PulseDockAppGroup.suiteName,
    fileManager: FileManager = .default,
    bundleIdentifier: String? = Bundle.main.bundleIdentifier,
    acceptedFutureSkew: TimeInterval = 300
) {
    self.acceptedFutureSkew = acceptedFutureSkew
    ...
}
```

Replace the load guard with explicit age handling:

```swift
public func loadLatestSnapshot(maxAge: TimeInterval, now: Date = Date()) -> MetricSnapshot? {
    guard let defaults,
          let data = defaults.data(forKey: Keys.latestSnapshot),
          let snapshot = try? JSONDecoder().decode(MetricSnapshot.self, from: data) else {
        return nil
    }

    let age = now.timeIntervalSince(snapshot.timestamp)
    guard age <= maxAge, age >= -acceptedFutureSkew else {
        return nil
    }
    return snapshot
}
```

Update `docs/data-capability-audit.md` with:

```markdown
- Shared widget snapshots tolerate small system clock skew while still rejecting stale or far-future data.
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter sharedSnapshotStore
swift test
```

Expected: all shared snapshot tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SharedMetrics/SharedSnapshotStore.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: tolerate small shared snapshot clock skew"
```

---

### Task 6: Harden App Store Metadata And Support Links

**Files:**
- Modify: `Resources/AppInfo.plist`
- Modify: `Resources/WidgetInfo.plist`
- Modify: `Sources/PulseDockApp/PulseDockLinks.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Write failing tests**

Add:

```swift
@Test func appAndWidgetInfoPlistsContainStoreMetadata() throws {
    let appInfo = try fixture("Resources/AppInfo.plist")
    let widgetInfo = try fixture("Resources/WidgetInfo.plist")

    #expect(appInfo.contains("<key>CFBundleDisplayName</key>"))
    #expect(appInfo.contains("<string>Pulse Dock</string>"))
    #expect(appInfo.contains("<key>ITSAppUsesNonExemptEncryption</key>"))
    #expect(widgetInfo.contains("<key>ITSAppUsesNonExemptEncryption</key>"))
    #expect(widgetInfo.contains("<false/>"))
}
```

Add:

```swift
@Test func pulseDockLinksOnlyAllowHTTPSURLs() throws {
    let links = try fixture("Sources/PulseDockApp/PulseDockLinks.swift")

    #expect(links.contains("components.scheme?.lowercased() == \"https\""))
    #expect(!links.contains("scheme == \"https\" || scheme == \"http\""))
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
swift test --filter appAndWidgetInfoPlistsContainStoreMetadata
swift test --filter pulseDockLinksOnlyAllowHTTPSURLs
```

Expected: both fail before implementation.

- [ ] **Step 3: Update Info.plists**

In `Resources/AppInfo.plist`, after `CFBundleName`, add:

```xml
  <key>CFBundleDisplayName</key>
  <string>Pulse Dock</string>
```

In `Resources/WidgetInfo.plist`, before `NSExtension`, add:

```xml
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
```

- [ ] **Step 4: Restrict support/privacy links to HTTPS**

In `PulseDockLinks.swift`, replace scheme validation with:

```swift
guard components.scheme?.lowercased() == "https",
      components.host?.isEmpty == false else {
    return nil
}
```

Keep `open(_:)` behavior deterministic; do not introduce in-app alerts in this pass.

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter InfoPlists
swift test --filter pulseDockLinks
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Resources/AppInfo.plist Resources/WidgetInfo.plist Sources/PulseDockApp/PulseDockLinks.swift Tests/SharedMetricsTests/MetricFormattingTests.swift
git commit -m "fix: harden app store metadata and links"
```

---

### Task 7: Low-Risk App Cleanup

**Files:**
- Modify: `Sources/PulseDockApp/main.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Write failing tests for cleanup targets**

Add:

```swift
@Test func mainKeepsAppDelegateStrongForRunLoopLifetime() throws {
    let main = try fixture("Sources/PulseDockApp/main.swift")

    #expect(main.contains("final class PulseDockApplication"))
    #expect(main.contains("private let delegate = AppDelegate()"))
    #expect(main.contains("PulseDockApplication().run()"))
}
```

Add:

```swift
@Test func dashboardUsesStableTableColumnIDsAndNoDeadSettingRow() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    #expect(!dashboard.contains("ForEach(columns, id: \\.self)"))
    #expect(dashboard.contains("Array(columns.enumerated())"))
    #expect(!dashboard.contains("private struct SettingRow: View"))
}
```

Add:

```swift
@Test func dashboardAvoidsDuplicatedCompactRegularPageBranch() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    #expect(dashboard.contains("let isCompact = proxy.size.width < 1080"))
    #expect(dashboard.contains("metricColumns: adaptiveMetricColumns(for: proxy.size.width)"))
    #expect(dashboard.contains("summaryColumns: adaptiveSummaryColumns(for: proxy.size.width)"))
    #expect(!dashboard.contains("if proxy.size.width < 1080 {\n                            pageContent("))
}
```

Add:

```swift
@Test func dashboardPanelModifierDoesNotApplyRepeatedHeavyShadows() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let panelStart = try #require(dashboard.range(of: "func panel(cornerRadius: CGFloat) -> some View")?.lowerBound)
    let panelEnd = dashboard.range(of: "private func normalizedRate", range: panelStart..<dashboard.endIndex)?.lowerBound ?? dashboard.endIndex
    let panelBody = String(dashboard[panelStart..<panelEnd])

    #expect(!panelBody.contains(".shadow(color: .black.opacity(0.035), radius: 16, x: 0, y: 8)"))
    #expect(!panelBody.contains(".shadow(color: .black.opacity"))
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
swift test --filter mainKeepsAppDelegateStrongForRunLoopLifetime
swift test --filter dashboardUsesStableTableColumnIDsAndNoDeadSettingRow
swift test --filter dashboardAvoidsDuplicatedCompactRegularPageBranch
swift test --filter dashboardPanelModifierDoesNotApplyRepeatedHeavyShadows
```

Expected: fail before cleanup.

- [ ] **Step 3: Make delegate lifetime explicit**

Replace `main.swift` with:

```swift
import AppKit

final class PulseDockApplication {
    private let app = NSApplication.shared
    private let delegate = AppDelegate()

    func run() {
        app.delegate = delegate
        app.run()
    }
}

PulseDockApplication().run()
```

- [ ] **Step 4: Collapse dashboard compact branch**

In `DashboardView.body`, replace the duplicated `if/else` block with:

```swift
GeometryReader { proxy in
    let isCompact = proxy.size.width < 1080
    pageContent(
        metricColumns: adaptiveMetricColumns(for: proxy.size.width),
        summaryColumns: adaptiveSummaryColumns(for: proxy.size.width),
        isCompact: isCompact
    )
    .padding(.horizontal, 24)
    .padding(.top, 18)
    .padding(.bottom, 28)
}
```

Preserve the existing `ScrollView` and `.background(DashboardColor.canvas)` around this block. The padding values must match the current dashboard padding.

- [ ] **Step 5: Stabilize table header IDs**

In `TableHeader`, replace:

```swift
ForEach(columns, id: \.self) { column in
    Text(column)
}
```

with:

```swift
ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
    Text(column)
}
```

- [ ] **Step 6: Remove dead `SettingRow` and repeated panel shadow**

Delete:

```swift
private struct SettingRow: View {
    ...
}
```

Only delete it after confirming:

```bash
rg -n "SettingRow" Sources/PulseDockApp Tests
```

Expected after deletion: no source usage remains except removed/updated tests.

In the shared `panel(cornerRadius:)` modifier, remove the default panel shadow:

```swift
private extension View {
    func panel(cornerRadius: CGFloat) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DashboardColor.panel)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DashboardColor.border, lineWidth: 1)
            }
    }
}
```

Keep small semantic glows such as `StatusDot` unchanged; only remove the default repeated shadow from large panels.

Update `docs/data-capability-audit.md` with:

```markdown
- Main app delegate lifetime is held strongly for the run loop.
- Dashboard table headers use stable index IDs and unused settings-row code was removed.
- Dashboard panels avoid repeated default shadows from the shared panel modifier.
```

- [ ] **Step 7: Run tests**

Run:

```bash
swift test --filter dashboard
swift test --filter mainKeepsAppDelegateStrongForRunLoopLifetime
swift test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/PulseDockApp/main.swift Sources/PulseDockApp/DashboardView.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "chore: clean up app lifetime and dashboard structure"
```

---

### Task 8: Metric Formatting And Compact Widget Snapshot Audit

**Files:**
- Modify: `Sources/SharedMetrics/MetricFormatting.swift`
- Modify: `Sources/SharedMetrics/MetricSnapshot.swift`
- Modify: `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Add focused regression tests for units**

Add:

```swift
@Test func networkRateFormattingLabelsBytesAndBitsExplicitly() {
    #expect(MetricFormatting.byteRate(bytesPerSecond: 1_024) == "1 KB/s")
    #expect(MetricFormatting.bitRate(bitsPerSecond: 1_000) == "1 Kbps")
    #expect(MetricFormatting.bitRate(bitsPerSecond: 1_000_000) == "1 Mbps")
    #expect(MetricFormatting.networkRate(bytesPerSecond: 125_000) == "1 Mbps")
}
```

Use the existing public APIs. Do not add overlapping `bytesPerSecond(_:)` or `bitsPerSecond(_:)` helpers.

- [ ] **Step 2: Add compact snapshot intent test**

Add:

```swift
@Test func widgetCompactSnapshotPreservesSummarySignalsAndDropsPrivateLists() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.42,
        hasCPUUsageReport: true,
        memoryUsedBytes: 4_096,
        memoryTotalBytes: 8_192,
        loadAverage: 1.2,
        hasLoadAverageReport: true,
        thermalState: "Nominal",
        batteryPercent: 0.8,
        batteryIsCharging: true,
        networkBytesPerSecond: 12_345,
        hasNetworkByteCounters: true,
        networkPathStatus: "satisfied",
        networkPathInterfaceKinds: ["Wi-Fi"],
        networkInBytesPerSecond: 6_000,
        networkOutBytesPerSecond: 6_345,
        diskFreeBytes: 2_048,
        diskTotalBytes: 4_096,
        processCount: 42,
        runningApps: [
            ProcessMetric(index: 0, name: "Private App", hasStateReport: true)
        ],
        timestamp: Date(timeIntervalSince1970: 1_000)
    )

    let compact = snapshot.widgetCompactSnapshot()

    #expect(compact.cpuUsage == snapshot.cpuUsage)
    #expect(compact.networkPathStatus == "satisfied")
    #expect(compact.networkPathInterfaceKinds == ["Wi-Fi"])
    #expect(compact.networkBytesPerSecond == snapshot.networkBytesPerSecond)
    #expect(compact.networkInterfaces.isEmpty)
    #expect(compact.runningApps.isEmpty)
}
```

- [ ] **Step 3: Run focused tests and verify failure where applicable**

Run:

```bash
swift test --filter networkRateFormattingLabelsBytesAndBitsExplicitly
swift test --filter widgetCompactSnapshotPreservesSummarySignalsAndDropsPrivateLists
```

Expected: formatting test documents current byte-rate and bit-rate API names. Compact snapshot test should document intended behavior and expose accidental zeroing.

- [ ] **Step 4: Audit existing formatting helpers and call sites**

Keep these existing helpers in `MetricFormatting.swift`:

```swift
public static func networkRate(bytesPerSecond: UInt64) -> String {
    let bitsPerSecond = Double(bytesPerSecond) * 8
    return bitRate(bitsPerSecond: bitsPerSecond)
}

public static func bitRate(bitsPerSecond: Double) -> String {
    ...
}

public static func byteRate(bytesPerSecond: UInt64) -> String {
    "\(compactBytes(bytesPerSecond))/s"
}
```

In `MetricSnapshot.swift`, keep directional throughput on `byteRate(bytesPerSecond:)`:

```swift
public var networkInText: String {
    guard hasNetworkDirectionByteCounters else { return "未报告" }
    return MetricFormatting.byteRate(bytesPerSecond: networkInBytesPerSecond)
}

public var networkOutText: String {
    guard hasNetworkDirectionByteCounters else { return "未报告" }
    return MetricFormatting.byteRate(bytesPerSecond: networkOutBytesPerSecond)
}
```

Keep aggregate network speed on `networkRate(bytesPerSecond:)` and link speed on `bitRate(bitsPerSecond:)`.

- [ ] **Step 5: Adjust compact snapshot only if test exposes loss of displayed summary**

In `MetricSnapshot+WidgetCompact.swift`, preserve fields the widget visibly uses:

```swift
networkBytesPerSecond: networkBytesPerSecond,
hasNetworkByteCounters: hasNetworkByteCounters,
hasNetworkDirectionByteCounters: hasNetworkDirectionByteCounters,
networkPathStatus: networkPathStatus,
networkPathIsExpensive: networkPathIsExpensive,
networkPathIsConstrained: networkPathIsConstrained,
hasNetworkPathCostReport: hasNetworkPathCostReport,
networkPathSupportsDNS: networkPathSupportsDNS,
networkPathSupportsIPv4: networkPathSupportsIPv4,
networkPathSupportsIPv6: networkPathSupportsIPv6,
hasNetworkPathSupportReport: hasNetworkPathSupportReport,
networkPathInterfaceKinds: networkPathInterfaceKinds,
networkInBytesPerSecond: networkInBytesPerSecond,
networkOutBytesPerSecond: networkOutBytesPerSecond,
networkInterfaces: [],
runningApps: [],
gpuDevices: [],
displays: []
```

Do not preserve app names, interface details, GPU device names, or display names in the widget compact snapshot.

Update `docs/data-capability-audit.md` with:

```markdown
- Network formatting distinguishes byte-per-second throughput from bit-per-second link rates.
- Widget compact snapshots preserve visible summary signals while dropping detailed private lists.
```

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter MetricFormatting
swift test --filter widgetCompactSnapshot
swift test
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/SharedMetrics/MetricFormatting.swift Sources/SharedMetrics/MetricSnapshot.swift Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: clarify network units and compact widget summaries"
```

---

### Task 9: Widget Sampling Fallback Guard

**Files:**
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Write failing test**

Add:

```swift
@Test func widgetSamplerCacheAvoidsImmediateSecondSampleAfterPrime() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(widget.contains("private var primedSnapshot: MetricSnapshot?"))
    #expect(!widget.contains("_ = systemSampler.sample()\n            isPrimed = true\n            return systemSampler.sample()"))
    #expect(audit.contains("Widget sampler fallback returns the priming sample instead of taking an immediate second sample with near-zero deltas."))
}
```

- [ ] **Step 2: Run focused test and verify failure**

Run:

```bash
swift test --filter widgetSamplerCacheAvoidsImmediateSecondSampleAfterPrime
```

Expected: fails with current immediate second sample.

- [ ] **Step 3: Store and return the priming sample**

In `WidgetSamplerCache`, add:

```swift
private var primedSnapshot: MetricSnapshot?
```

Change `sample()` to:

```swift
func sample() -> MetricSnapshot {
    lock.lock()
    defer { lock.unlock() }

    if !isPrimed {
        let snapshot = systemSampler.sample()
        primedSnapshot = snapshot
        isPrimed = true
        return snapshot
    }

    let snapshot = systemSampler.sample()
    primedSnapshot = snapshot
    return snapshot
}
```

Update `docs/data-capability-audit.md` with:

```markdown
- Widget sampler fallback returns the priming sample instead of taking an immediate second sample with near-zero deltas.
```

- [ ] **Step 4: Run widget tests**

Run:

```bash
swift test --filter WidgetSamplerCache
swift test --filter widget
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: avoid immediate widget fallback resampling"
```

---

### Task 10: Queue One Pending Refresh Tick

**Files:**
- Modify: `Sources/PulseDockApp/MetricsStore.swift`
- Test: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Docs: `docs/data-capability-audit.md`

- [ ] **Step 1: Write failing test**

Add near the existing refresh task tests:

```swift
@Test func metricsStoreQueuesOnePendingRefreshWhenSamplingIsInFlight() throws {
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(metricsStore.contains("@Published private(set) var isRefreshing = false"))
    #expect(metricsStore.contains("private var pendingRefreshAfterCurrent = false"))
    #expect(metricsStore.contains("guard refreshTask == nil else"))
    #expect(metricsStore.contains("pendingRefreshAfterCurrent = true"))
    #expect(metricsStore.contains("let shouldRunPendingRefresh = pendingRefreshAfterCurrent && !isPaused && !Task.isCancelled"))
    #expect(metricsStore.contains("if shouldRunPendingRefresh"))
    #expect(metricsStore.contains("refresh()"))
    #expect(audit.contains("Refresh ticks that arrive while sampling is in flight queue one follow-up refresh instead of disappearing silently."))
}
```

- [ ] **Step 2: Run focused test and verify failure**

Run:

```bash
swift test --filter metricsStoreQueuesOnePendingRefreshWhenSamplingIsInFlight
```

Expected: fails because current `refresh()` returns silently when `refreshTask != nil`.

- [ ] **Step 3: Add refresh state fields**

In `MetricsStore.swift`, near the existing refresh task state, add:

```swift
@Published private(set) var isRefreshing = false
private var pendingRefreshAfterCurrent = false
```

Keep both `@MainActor` isolated with the rest of `MetricsStore`.

- [ ] **Step 4: Clear pending state on cancellation**

Update `cancelRefreshTask()`:

```swift
private func cancelRefreshTask() {
    refreshGeneration += 1
    refreshTask?.cancel()
    refreshTask = nil
    pendingRefreshAfterCurrent = false
    isRefreshing = false
}
```

- [ ] **Step 5: Queue a pending refresh instead of dropping ticks**

Replace the start of `refresh()` with:

```swift
private func refresh() {
    guard !isPaused else { return }
    guard refreshTask == nil else {
        pendingRefreshAfterCurrent = true
        return
    }

    isRefreshing = true
    let sampler = self.sampler
    let generation = refreshGeneration
    refreshTask = Task { @MainActor [weak self] in
        let sampledSnapshot = await Task.detached(priority: .userInitiated) {
            sampler.sample()
        }.value
```

In the task body, after `refreshTask = nil`, compute whether to run one queued refresh:

```swift
guard let self else { return }
guard generation == refreshGeneration else { return }
refreshTask = nil
isRefreshing = false
let shouldRunPendingRefresh = pendingRefreshAfterCurrent && !isPaused && !Task.isCancelled
pendingRefreshAfterCurrent = false
guard !Task.isCancelled, !isPaused else { return }
```

After widget reload/history persistence, run the queued refresh:

```swift
if shouldRunPendingRefresh {
    refresh()
}
```

This keeps at most one pending refresh. Do not start overlapping sampler tasks.

Update `docs/data-capability-audit.md` with:

```markdown
- Refresh ticks that arrive while sampling is in flight queue one follow-up refresh instead of disappearing silently.
```

- [ ] **Step 6: Run tests**

Update the two existing source-level refresh assertions that currently require the old single-line guard. In `Tests/SharedMetricsTests/MetricFormattingTests.swift`, update these tests:

```text
mainAppWarmsDeltaBasedSamplerBeforePublishingInitialSnapshot
menuPopoverUsesPlainButtonsForActionsAndPauseToggle
```

Replace the old assertion:

```swift
#expect(metricsStore.contains("guard !isPaused, refreshTask == nil else { return }"))
```

with assertions for the split guard and pending refresh behavior:

```swift
#expect(metricsStore.contains("guard !isPaused else { return }"))
#expect(metricsStore.contains("guard refreshTask == nil else"))
#expect(metricsStore.contains("pendingRefreshAfterCurrent = true"))
```

Run:

```bash
swift test --filter refresh
swift test
```

Expected: the two old guard assertions are updated, refresh-focused tests pass, and the full suite passes.

- [ ] **Step 7: Commit**

```bash
git add Sources/PulseDockApp/MetricsStore.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: queue refresh ticks during sampling"
```

---

### Task 11: Final Verification And Manual Smoke Test

**Files:**
- No source edits expected.
- May update docs only if verification uncovers inaccurate audit text.

- [ ] **Step 1: Check working tree**

Run:

```bash
git status --short
```

Expected: only intentional changes are present.

- [ ] **Step 2: Run SwiftPM build and tests**

Run:

```bash
swift build
swift test
```

Expected: build succeeds and all tests pass.

- [ ] **Step 3: Regenerate Xcode project**

Run:

```bash
scripts/generate-xcodeproj.rb
```

Expected: project generation succeeds.

- [ ] **Step 4: Package app and widget**

Run:

```bash
scripts/package-app.sh
```

Expected: `dist/Pulse Dock.app` is rebuilt successfully as a universal app.

- [ ] **Step 5: Validate bundled metadata**

Run:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "dist/Pulse Dock.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "dist/Pulse Dock.app/Contents/Info.plist"
find "dist/Pulse Dock.app" -name Info.plist -path '*PlugIns*' -print
```

Expected:

```text
Pulse Dock
false
```

The widget extension Info.plist exists and contains `ITSAppUsesNonExemptEncryption = false`.

- [ ] **Step 6: Verify signatures**

Run:

```bash
codesign --verify --deep --strict --verbose=2 "dist/Pulse Dock.app"
```

Expected: no codesign errors.

- [ ] **Step 7: Manual popover smoke test**

Run the packaged app:

```bash
open "dist/Pulse Dock.app"
```

Manual checks:

1. First menu-bar click opens a centered, non-drifting popover.
2. Second click closes it.
3. Reopen after close keeps the arrow aligned with the status item.
4. Dark mode popover and widget backgrounds are cool neutral, not brown.
5. Narrow-screen or side-display placement remains inside the visible frame.

- [ ] **Step 8: Screenshot validation**

Run:

```bash
scripts/validate-app-store-screenshots.sh
```

Expected: the five existing screenshots pass dimension and count checks.

- [ ] **Step 9: Final diff checks**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; only intentional files changed.

- [ ] **Step 10: Commit verification docs if needed**

If verification updates docs:

```bash
git add docs/data-capability-audit.md
git commit -m "docs: update review hardening verification notes"
```

Otherwise, no commit is required.

---

## Execution Notes

- Use one commit per task. The tests in this repository include many source-text assertions; when behavior changes intentionally, update the old assertion in the same task as the implementation.
- Do not reintroduce post-show popover window movement. `NSPopover.show(relativeTo:of:preferredEdge:)` must remain the single positioning operation.
- Do not add notification permissions in this pass. That would change the product and App Store privacy posture.
- Do not enable App Group for local ad-hoc bundle identifiers unless a separate signing/test plan is prepared.
- Keep widget compact snapshots privacy-preserving: preserve summary fields, not detailed app/interface/device names.

## Self-Review

- Spec coverage: all verified remaining findings are mapped to Tasks 1-10, with final packaging and manual verification in Task 11.
- Placeholder scan: no open-ended placeholders or unassigned work remains. Each code-changing task includes exact target files, intended snippets, test commands, and expected outcomes.
- Type consistency: new names are consistent across tasks: `popoverWidth`, `makeWidgetPanelView(popoverWidth:popoverHeight:)`, `makeStatusHostingController(contentSize:)`, `acceptedFutureSkew`, `pendingRefreshAfterCurrent`, `byteRate(bytesPerSecond:)`, and `bitRate(bitsPerSecond:)`.
