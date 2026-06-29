# Pulse Dock Responsive Layout Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Pulse Dock dashboard page readable and non-overlapping at the supported 13-inch-friendly window size, under macOS display scaling, and in both English and Simplified Chinese.

**Architecture:** Keep the existing desktop dashboard density at regular widths, but introduce one shared responsive layout model for compact widths. The app should stack high-risk two-column pages, prevent fixed-width panels from squeezing primary content, let dense tables scroll horizontally, and make the sidebar/top bar resilient to short content heights. This is a layout hardening pass, not a visual redesign.

**Tech Stack:** Swift 6, SwiftUI on macOS 14+, AppKit `NSWindow`, Swift Testing source-level gates, existing SwiftPM plus generated Xcode project workflow.

---

## 0. Verified Findings

These findings were verified against the current source and the user-provided screenshots.

| Priority | Finding | Evidence | Decision |
| --- | --- | --- | --- |
| P0 | Dashboard content can be clipped by the title bar or effective content height. | `DashboardView` requires `.frame(minHeight: 640)` while `AppDelegate` sets `window.minSize = NSSize(width: 960, height: 640)`. `NSWindow.minSize` is frame size, not content size. | Align window frame min size with desired content min size, or reduce the SwiftUI content min height. |
| P0 | Sidebar can crop the brand/header and bottom live-sampling card. | `DashboardSidebar` is a fixed-width `VStack` with no vertical scroll and fixed top/bottom padding. | Make the sidebar vertically scrollable/resilient and titlebar-aware. |
| P0 | Memory page over-compresses at compact width. | `MemoryPage` always uses `HStack`; right panel is fixed `360`, left panel contains a fixed `148` gauge and `HStack(spacing: 24)`. | Add compact stacked layout and compact internals for gauge/details. |
| P1 | CPU, Power, and Status pages have the same two-column fixed-width risk. | CPU fixed aside `320`; Power fixed aside `340`; Sensors fixed left `360`. | Add compact stacked layouts for each page. |
| P1 | Storage, GPU, Network, Processes, Settings, Status, and History dense tables can crush columns. | `TableHeader` and `TableRow` divide all columns into equal flexible widths with no horizontal scroll. Some tables have 7 to 9 columns. | Replace raw table blocks with a responsive table wrapper that supplies minimum table widths and horizontal scrolling. |
| P1 | Top bar chips can crowd page titles at compact width or longer localizations. | `DashboardTopBar` has fixed height `82` and one horizontal row containing title/subtitle plus three chips. | Add compact chip behavior via `ViewThatFits`, wrapping, or reduced chip set. |
| P2 | Fixed grids remain too optimistic at compact width. | CPU core grid is always 5 columns; storage/GPU capability grids are always 3 columns. | Convert to adaptive columns or shared responsive column helpers. |

Existing `swift test` passes, but current tests do not cover these failure modes. Add layout source gates before implementation.

---

## 1. Acceptance Criteria

The implementation is complete only when all of these are true:

- At `960 x 640` frame size, every dashboard page is usable with no incoherent overlap, no clipped sidebar brand, and no clipped sidebar live-sampling card. Vertical scrolling is acceptable.
- At compact effective content width, CPU, Memory, Power, and Status pages stack primary and secondary panels vertically.
- The Memory page no longer shows split/truncated key-value labels like `24.0...` caused by an over-compressed right column.
- Dense tables keep readable column widths. Horizontal scrolling is acceptable only inside table regions, not for the whole dashboard page.
- Overview and Settings keep their current regular layout quality and compact behavior.
- At regular width around `1320 x 860`, the dashboard still uses the intended dense two-column/multi-column layouts.
- English and Simplified Chinese localizations both fit without title/chip overlap.
- `swift test`, `swift build`, widget target build, generated Xcode project build, and localization audit pass.

Manual visual QA must cover these pages:

- Overview
- CPU
- GPU / Display
- Memory
- Storage
- Network
- Power
- Apps
- Status
- History
- Settings

Manual visual QA must cover these window sizes:

- `960 x 640`
- `1024 x 640`
- `1200 x 720`
- `1320 x 860`

---

## 2. File Structure

### Files To Modify

- `Sources/PulseDockApp/AppDelegate.swift`
  - Align `NSWindow` min sizing with SwiftUI content sizing.
  - Explicitly avoid titlebar/content underlap unless intentionally enabled.

- `Sources/PulseDockApp/DashboardVisualTokens.swift`
  - Add shared layout constants and responsive thresholds.

- `Sources/PulseDockApp/DashboardView.swift`
  - Pass compact layout state to all high-risk pages.
  - Stack two-column pages at compact widths.
  - Add responsive grids and table wrappers.
  - Make sidebar and top bar compact-safe.

- `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
  - Add source gates for responsive coverage and table/sidebar safety.

- `Tests/SharedMetricsTests/MetricFormattingTests.swift`
  - Update any existing source-level assertions that expect old fixed layout patterns.

### Files To Modify Only If Needed

- `Sources/PulseDockApp/PulseDockAppStrings.swift`
  - Only add strings if compact top-bar chips need shorter localized labels.

- `Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings`
- `Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings`
- `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`
  - Only update if new compact labels are introduced.

### Files Not To Touch In This Plan

- `Sources/SharedMetrics/SystemSampler.swift`
- `Sources/SharedMetrics/MetricSnapshot.swift`
- `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Entitlements and App Store metadata
- Screenshot PNG assets

---

## 3. Global Verification Commands

Run after every task that touches Swift source:

```bash
swift test --filter VisualFrontendGateTests
swift test
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
```

When `AppDelegate.swift`, target membership, or generated project assumptions change, also run:

```bash
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected:

```text
Test run passed
Build complete
Localization audit passed
** BUILD SUCCEEDED **
```

---

## Task 1: Add Responsive Layout Source Gates

**Files:**
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Add compact coverage tests**

Add a test that proves compact state is propagated beyond Overview and Settings:

```swift
@Test func dashboardCompactLayoutCoversHighRiskPages() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    #expect(dashboard.contains("CPUPage(snapshot: snapshot, history: history, isCompact: isCompact)"))
    #expect(dashboard.contains("MemoryPage(snapshot: snapshot, history: history, isCompact: isCompact)"))
    #expect(dashboard.contains("StoragePage(store: store, history: history, isCompact: isCompact)"))
    #expect(dashboard.contains("GPUDisplayPage(snapshot: snapshot, isCompact: isCompact)"))
    #expect(dashboard.contains("PowerPage(snapshot: snapshot, history: history, isCompact: isCompact)"))
    #expect(dashboard.contains("SensorsPage(store: store, isCompact: isCompact)"))
}
```

- [ ] **Step 2: Add sidebar and titlebar resilience tests**

Add a test that prevents the sidebar from returning to a non-scrollable fixed-height stack:

```swift
@Test func dashboardSidebarIsVerticallyResilientAtMinimumHeight() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let sidebar = componentBody(named: "DashboardSidebar", in: dashboard)

    #expect(sidebar.contains("ScrollView"))
    #expect(sidebar.contains("SidebarHealthCard"))
    #expect(sidebar.contains("DashboardLayout.sidebarWidth"))
}
```

Add a test that proves `NSWindow` sizing is content-aware:

```swift
@Test func dashboardWindowMinimumSizeMatchesContentArea() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

    #expect(appDelegate.contains("DashboardLayout.minimumContentSize"))
    #expect(appDelegate.contains("frameRect(forContentRect:"))
    #expect(!appDelegate.contains("window.minSize = NSSize(width: 960, height: 640)"))
}
```

- [ ] **Step 3: Add dense-table safety tests**

Add a source gate that requires a responsive table wrapper:

```swift
@Test func dashboardDenseTablesUseResponsiveTableWrapper() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    #expect(dashboard.contains("private struct ResponsiveTable"))
    #expect(dashboard.contains("ScrollView(.horizontal"))
    #expect(dashboard.contains("minimumTableWidth"))
    #expect(!dashboard.contains("TableHeader(columns: PulseDockAppStrings.storageVolumeTableColumns)"))
    #expect(!dashboard.contains("TableHeader(columns: PulseDockAppStrings.networkInterfaceTableColumns)"))
    #expect(!dashboard.contains("TableHeader(columns: PulseDockAppStrings.displayTableColumns)"))
}
```

- [ ] **Step 4: Run targeted tests and confirm RED**

```bash
swift test --filter VisualFrontendGateTests
```

Expected: the new tests fail before implementation.

---

## Task 2: Centralize Dashboard Layout Constants

**Files:**
- Modify: `Sources/PulseDockApp/DashboardVisualTokens.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Add `DashboardLayout` tokens**

Add layout constants near the existing spacing/typography/color tokens:

```swift
enum DashboardLayout {
    static let minimumContentSize = CGSize(width: 960, height: 640)
    static let idealContentSize = CGSize(width: 1320, height: 860)
    static let sidebarWidth: CGFloat = 224
    static let compactBreakpoint: CGFloat = 1080
    static let narrowContentBreakpoint: CGFloat = 760
    static let contentHorizontalPadding: CGFloat = 24
    static let contentTopPadding: CGFloat = 18
    static let regularAsideWidth: CGFloat = 360
    static let compactPanelSpacing: CGFloat = 12
    static let minimumTableColumnWidth: CGFloat = 96
}
```

Use explicit constants instead of repeating `960`, `640`, `1080`, `224`, `360`, and `24` across the dashboard.

- [ ] **Step 2: Replace hard-coded dashboard min/ideal frame**

Replace:

```swift
.frame(minWidth: 960, idealWidth: 1320, minHeight: 640, idealHeight: 860)
```

with the shared layout constants.

- [ ] **Step 3: Replace hard-coded sidebar width**

Replace:

```swift
.frame(width: 224)
```

with:

```swift
.frame(width: DashboardLayout.sidebarWidth)
```

- [ ] **Step 4: Keep adaptive-column helpers on shared thresholds**

Replace direct `1080` checks with `DashboardLayout.compactBreakpoint`.

- [ ] **Step 5: Run tests**

```bash
swift test --filter VisualFrontendGateTests
```

---

## Task 3: Fix Window Content Minimum Size And Titlebar Underlap

**Files:**
- Modify: `Sources/PulseDockApp/AppDelegate.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Make the window minimum size content-aware**

Use a content rect to derive the frame minimum:

```swift
let minimumContentSize = DashboardLayout.minimumContentSize
let minimumContentRect = NSRect(origin: .zero, size: minimumContentSize)
window.minSize = window.frameRect(forContentRect: minimumContentRect).size
```

This keeps a `640pt` dashboard content area from being squeezed into a `640pt` outer window frame after the title bar consumes vertical space.

- [ ] **Step 2: Explicitly avoid titlebar underlap**

Add defensive window configuration:

```swift
window.titlebarAppearsTransparent = false
window.styleMask.remove(.fullSizeContentView)
```

Only keep titlebar underlap if the implementation intentionally reserves a top safe area in SwiftUI. The preferred fix is to keep the standard titled content layout.

- [ ] **Step 3: Update initial frame calculations**

Use `DashboardLayout.idealContentSize` and `DashboardLayout.minimumContentSize` in `initialDashboardWindowFrame()`. Ensure the final `contentRect` still fits the visible screen.

- [ ] **Step 4: Update existing tests**

Update tests that currently assert:

```swift
window.minSize = NSSize(width: 960, height: 640)
```

They should now assert the content-size-based frame conversion.

- [ ] **Step 5: Run verification**

```bash
swift test --filter dashboardWindowMinimumSizeMatchesContentArea
swift test --filter mainWindow
swift build
```

---

## Task 4: Make Sidebar Vertically Resilient

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Wrap sidebar content in a vertical scroll container**

The sidebar should not rely on all content fitting into the visible height. Use a vertical `ScrollView` with the brand, nav rows, and `SidebarHealthCard` inside it.

Preserve regular-height visual balance by using a `GeometryReader` or `frame(minHeight:alignment:)` so the health card still sits near the bottom when there is enough space.

- [ ] **Step 2: Protect sidebar brand/title text**

Add one-line protection to the brand row:

```swift
Text("Pulse Dock")
    .lineLimit(1)
    .minimumScaleFactor(0.75)
```

- [ ] **Step 3: Keep nav rows fixed but scrollable**

Do not shrink the nav row height below `34`. Scrolling is better than unreadable controls.

- [ ] **Step 4: Run targeted tests**

```bash
swift test --filter dashboardSidebarIsVerticallyResilientAtMinimumHeight
```

Manual check:

- Open the app at `960 x 640`.
- Confirm the sidebar brand is fully visible.
- Confirm the live-sampling card is reachable and not clipped.

---

## Task 5: Make Dashboard Top Bar Compact-Safe

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Pass compact state to the top bar**

Change:

```swift
DashboardTopBar(page: router.selectedPage, snapshot: store.snapshot, refreshInterval: store.refreshInterval)
```

to include `isCompact` or derive it from the available width around the top bar.

- [ ] **Step 2: Use `ViewThatFits` for title plus chips**

The regular layout can stay horizontal. The compact layout should either:

- stack the title/subtitle above the chips, or
- show only the sample and interval chips while hiding the local-machine chip.

Use one of these patterns:

```swift
ViewThatFits(in: .horizontal) {
    regularTopBarContent
    compactTopBarContent
}
```

or:

```swift
if isCompact {
    VStack(alignment: .leading, spacing: 8) { ... }
} else {
    HStack(spacing: 18) { ... }
}
```

- [ ] **Step 3: Replace fixed height with minimum height**

Change:

```swift
.frame(height: 82)
```

to:

```swift
.frame(minHeight: 82)
```

if compact content can wrap. The scroll content below should naturally shift down instead of overlapping.

- [ ] **Step 4: Add a source gate**

Assert that `DashboardTopBar` accepts compact state or uses `ViewThatFits`.

- [ ] **Step 5: Manual check**

At `960 x 640` and `1024 x 640`, confirm the page title, subtitle, sample chip, and refresh chip do not collide or clip in English or Simplified Chinese.

---

## Task 6: Propagate Compact Layout To High-Risk Pages

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Extend page initializers**

Add `let isCompact: Bool` to:

- `CPUPage`
- `MemoryPage`
- `StoragePage`
- `NetworkPage` if needed for table/card density
- `PowerPage`
- `GPUDisplayPage`
- `SensorsPage`

Update `pageContent(...)` to pass `isCompact`.

- [ ] **Step 2: Add a local panel pair helper**

Create a small helper in `DashboardView.swift`:

```swift
@ViewBuilder
private func ResponsivePanelPair<Primary: View, Secondary: View>(
    isCompact: Bool,
    secondaryWidth: CGFloat = DashboardLayout.regularAsideWidth,
    @ViewBuilder primary: () -> Primary,
    @ViewBuilder secondary: () -> Secondary
) -> some View {
    if isCompact {
        VStack(alignment: .leading, spacing: DashboardLayout.compactPanelSpacing) {
            primary()
            secondary()
        }
    } else {
        HStack(alignment: .top, spacing: DashboardLayout.compactPanelSpacing) {
            primary()
            secondary()
                .frame(width: secondaryWidth)
        }
    }
}
```

If generic function syntax becomes awkward in SwiftUI, use repeated `if isCompact` blocks instead. Prefer clarity over cleverness.

- [ ] **Step 3: Migrate CPU page**

Stack the processor trend panel above the load/details panel when compact.

Also change the per-core grid from fixed 5 columns to adaptive columns:

```swift
GridItem(.adaptive(minimum: 118), spacing: 10)
```

- [ ] **Step 4: Migrate Memory page**

Stack the memory usage panel above the composition panel when compact.

Inside the usage panel, avoid a permanent `HStack(spacing: 24)` at compact width. Use a compact vertical layout:

```swift
if isCompact {
    VStack(spacing: 14) { gauge; details }
} else {
    HStack(spacing: 24) { gauge; details }
}
```

Keep the gauge readable but do not let it starve the details area.

- [ ] **Step 5: Migrate Power page**

Stack the battery panel above the thermal panel when compact. Use the same compact gauge/details split as Memory.

- [ ] **Step 6: Migrate Status page**

Stack the thermal gauge panel above realtime signals when compact. Convert realtime signal cards to adaptive columns.

- [ ] **Step 7: Run targeted tests**

```bash
swift test --filter dashboardCompactLayoutCoversHighRiskPages
swift test --filter VisualFrontendGateTests
```

Manual check:

- CPU at `960 x 640`
- Memory at `960 x 640`
- Power at `960 x 640`
- Status at `960 x 640`

No panel should appear visibly crushed.

---

## Task 7: Convert Fixed Grids To Responsive Columns

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Add shared column helpers**

Add helpers near existing adaptive columns:

```swift
private func adaptiveCapabilityColumns(for width: CGFloat) -> [GridItem] {
    [GridItem(.adaptive(minimum: width < DashboardLayout.compactBreakpoint ? 170 : 190), spacing: 12)]
}

private func adaptiveCoreColumns() -> [GridItem] {
    [GridItem(.adaptive(minimum: 118), spacing: 10)]
}
```

Tune minimums after visual QA.

- [ ] **Step 2: Replace fixed 3-column capability grids**

Update:

- Storage capability cards
- GPU/display capability cards
- Status realtime signal cards

They should no longer use:

```swift
Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
```

- [ ] **Step 3: Replace fixed CPU core grid**

Update CPU per-core tiles from fixed 5 columns to adaptive columns.

- [ ] **Step 4: Review SummaryCard grid behavior**

The process summary grid is already driven by `summaryColumns`; confirm it produces two columns in compact mode and remains readable.

- [ ] **Step 5: Add source gates**

Add tests that reject fixed 5-column CPU core grids and fixed 3-column capability grids for compact-sensitive pages.

- [ ] **Step 6: Run tests**

```bash
swift test --filter VisualFrontendGateTests
```

---

## Task 8: Add Responsive Table Wrapper

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Create `ResponsiveTable`**

Add a table wrapper near `TableHeader` and `TableRow`:

```swift
private struct ResponsiveTable: View {
    let columns: [String]
    let rows: [[String]]
    let minimumTableWidth: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                TableHeader(columns: columns)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    TableRow(values: row)
                }
            }
            .frame(minWidth: minimumTableWidth)
        }
    }
}
```

Use `showsIndicators: true` if QA shows users need stronger horizontal-scroll affordance.

- [ ] **Step 2: Add table width helper**

Add:

```swift
private func minimumTableWidth(columnCount: Int, preferredColumnWidth: CGFloat = DashboardLayout.minimumTableColumnWidth) -> CGFloat {
    max(CGFloat(columnCount) * preferredColumnWidth, 360)
}
```

For especially wide tables, pass a larger preferred column width:

- 7 columns: `104`
- 8 columns: `110`
- 9 columns: `112`

- [ ] **Step 3: Migrate table call sites**

Migrate all raw `TableHeader` plus `ForEach` or `TableRow` groups:

- Storage volume list
- Network connectivity
- Network interface list
- GPU device list
- Display list
- Processes table
- Power battery information
- Status rules
- Status system signals
- History status evaluation
- Settings data sources

- [ ] **Step 4: Preserve empty rows**

Either add optional empty state support to `ResponsiveTable`, or keep empty state inside the horizontally scrollable content:

```swift
if rows.isEmpty {
    TableEmptyRow(text: PulseDockAppStrings.systemDidNotReport)
}
```

- [ ] **Step 5: Run targeted tests**

```bash
swift test --filter dashboardDenseTablesUseResponsiveTableWrapper
swift test
```

Manual check:

- Storage table at `960 x 640`
- Network interface table at `960 x 640`
- GPU display table at `960 x 640`

Cells should remain readable; table-local horizontal scrolling is acceptable.

---

## Task 9: Harden Memory, Trend, Legend, And Key-Value Components

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Make `KeyValueGrid` responsive**

Current `KeyValueGrid` always uses two flexible columns. Add a `minimumColumnWidth` or `isCompact` parameter:

```swift
private struct KeyValueGrid: View {
    let items: [(String, String)]
    var minimumColumnWidth: CGFloat = 132

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumColumnWidth), spacing: 10)], spacing: 10) {
            ...
        }
    }
}
```

This prevents the Memory panel from squeezing values into unusable fragments.

- [ ] **Step 2: Make `TrendRow` robust at narrow widths**

Replace the fixed leading width:

```swift
.frame(width: 96, alignment: .leading)
```

with either:

- a compact `VStack` layout when used in narrow panels, or
- `ViewThatFits` that falls back to vertical title/value above the sparkline.

- [ ] **Step 3: Protect legend labels**

Add `lineLimit(1)` and `minimumScaleFactor` to `LegendDot` labels, or let legends wrap to multiple lines in compact layouts.

- [ ] **Step 4: Keep gauges from starving adjacent text**

Where gauges sit next to details, use compact vertical layout rather than shrinking text into unreadable columns.

- [ ] **Step 5: Add source gates**

Add tests that reject:

```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10)
```

inside `KeyValueGrid`, and reject fixed `TrendRow` width without a compact fallback.

---

## Task 10: Manual Full-Page Visual QA

**Files:**
- Modify: `docs/superpowers/plans/2026-06-28-pulse-dock-responsive-layout-hardening.md`

- [ ] **Step 1: Build and run app**

```bash
swift build
.build/debug/PulseDockApp
```

If local launch needs the generated Xcode app bundle instead, run:

```bash
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
open .build/xcode-derived/Build/Products/Debug/Pulse\\ Dock.app
```

- [ ] **Step 2: Verify all pages at compact size**

At `960 x 640`, check:

- Overview
- CPU
- GPU / Display
- Memory
- Storage
- Network
- Power
- Apps
- Status
- History
- Settings

Record failures as follow-up tasks before merging.

- [ ] **Step 3: Verify regular density is preserved**

At `1320 x 860`, confirm:

- Overview still uses four metric cards at regular width.
- CPU, Memory, Power, and Status use their intended two-column layouts.
- Capability cards are not unnecessarily single-column.
- Tables still look like tables.

- [ ] **Step 4: Verify localization**

Run the app once in English and once in Simplified Chinese. Confirm:

- Top bar title/subtitle/chips do not collide.
- Sidebar labels remain visible.
- Memory key-value rows do not collapse.
- Table headers remain readable with horizontal table scrolling.

- [ ] **Step 5: Update this plan with QA results**

Add a short `QA Results` section at the bottom before final merge, including:

- Date
- Build command
- Tested language(s)
- Tested window sizes
- Remaining known issues, if any

---

## 4. Implementation Order

Use this order to avoid merge conflicts:

1. Task 1: tests first.
2. Task 2: shared layout constants.
3. Task 3: window content minimum size.
4. Task 4: sidebar resilience.
5. Task 5: top bar compact behavior.
6. Task 6: high-risk page compact propagation.
7. Task 7: adaptive grids.
8. Task 8: responsive tables.
9. Task 9: component-level hardening.
10. Task 10: full-page visual QA.

Tasks 4, 5, 7, and 8 can be parallelized after Task 2 lands. Task 6 should be done by one worker or carefully split by page because it touches the same `pageContent` switch and page initializers.

---

## 5. Risks And Guardrails

- Do not raise the minimum window size as the primary fix. The app intentionally targets a 13-inch-friendly minimum.
- Do not solve table compression by shrinking text below readable sizes. Use table-local horizontal scrolling.
- Do not introduce app-wide horizontal scrolling for the whole dashboard.
- Do not add continuous animation or sampling changes in this pass.
- Do not change metric semantics, privacy behavior, App Group behavior, or widget timeline logic.
- Do not remove existing accessibility labels while restructuring views.
- Keep App Store screenshot layouts stable at regular size.

---

## 6. Definition Of Done

- New responsive layout gates are present and passing.
- Existing `swift test` suite passes.
- `swift build` and widget target build pass.
- Generated Xcode project build passes.
- Localization audit passes.
- Manual QA confirms all dashboard pages are usable at `960 x 640`.
- Memory page no longer reproduces the screenshot compression issue.
- Sidebar no longer clips the brand or live-sampling card at minimum size.
- Dense tables remain readable through table-local horizontal scroll.
- Final implementation summary lists any intentionally deferred visual refinements.

---

## 7. QA Results

**Date:** 2026-06-28

**Build commands:**

- `swift test`
- `swift build`
- `swift build --target PulseDockWidget`
- `scripts/audit-localization.sh`
- `scripts/generate-xcodeproj.rb`
- `xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`
- `./script/build_and_run.sh --verify`

**Tested language:** Simplified Chinese runtime UI.

**Tested window size:** Minimum content target `960 x 640`; observed AppKit frame `960 x 672-684` depending on titlebar/chrome state.

**Manual visual smoke checked pages:**

- Overview
- CPU
- GPU / Display
- Memory
- Network
- Power

**Result:** The sampled compact pages no longer reproduce titlebar underlap, sidebar brand clipping, Memory key-value compression, or fixed two-column panel crushing. Dense GPU/Display tables stay inside local table regions and can scroll horizontally rather than widening the whole dashboard. The remaining pages are covered by source-level gates for compact propagation, adaptive grids, responsive tables, top bar resilience, and sidebar resilience.

**Remaining known issue:** A complete manual click-through of every page at all four planned sizes was not finished in this automated run because macOS UI scripting did not expose stable SwiftUI sidebar button names. The implementation and source gates cover all dashboard pages, but final pre-release visual QA should still click through Status, History, Settings, Storage, Apps, and the regular `1320 x 860` size manually.
