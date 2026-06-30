# Pulse Dock Responsive Frontend Review And Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Review and harden every Pulse Dock frontend surface so scaled displays, compact windows, English text, and dense data never produce broken containers, clipped labels, or compressed unreadable controls.

**Architecture:** Treat this as a second responsive hardening pass over the current SwiftUI dashboard, not a redesign. First capture an evidence matrix, then add source-level layout gates, then repair shared layout primitives before touching individual pages. Main-window dashboard, menu-bar status item, popover, and widgets are reviewed together because fixed-width assumptions in one surface have already leaked into others.

**Tech Stack:** Swift 6, SwiftUI on macOS 14+, AppKit `NSWindow`, Swift Testing source gates, shell screenshot helpers, existing SwiftPM and generated Xcode project workflow.

---

## 0. Current Verified Trigger

The user-provided screenshot shows the English Overview page at a scaled display/window proportion where `DashboardTopBar` renders as a centered narrow island while the content below uses the wider dashboard column. The visible defect is not only text compression: the header background and bottom divider no longer align with the main content band. In the current source, `DashboardTopBar` applies padding and `.frame(minHeight: 82)` to `ViewThatFits`, but it does not claim the full available width with a `maxWidth: .infinity` frame. `ViewThatFits` can therefore choose an intrinsic-width child and leave the header chrome visually detached.

This plan also covers recurring frontend risks already seen in recent screenshots:

| Priority | Surface | Risk | Evidence To Collect |
| --- | --- | --- | --- |
| P0 | Main dashboard top bar | Header chrome can shrink independently of the main content width. | Screenshot at English `960x640`, `1100x700`, `1320x860`, and scaled display mode. |
| P0 | Settings rows | Controls can exceed card width when labels or menu values are long. | Refresh & Display panel in English and Simplified Chinese. |
| P1 | Dense tables | Long values can truncate in equal-width columns even when the card itself fits. | GPU/Displays, Storage, Network, Apps. |
| P1 | Two-panel pages | Fixed aside widths can make the primary panel look cramped at intermediate widths. | CPU, Memory, Power, Status. |
| P1 | Top/chrome redundancy | Chips can crowd titles or create narrow intrinsic width. | All pages in English. |
| P2 | Menu bar status item | Selected metric text can make the menu extra visually too wide. | CPU, Network, Memory, Disk selections. |
| P2 | Widget compact layouts | English metric labels can wrap or crowd values. | Small and medium widgets, light and dark appearances. |

## 1. Acceptance Criteria

The review and repair pass is complete only when all criteria are met:

- `DashboardTopBar` always fills the main content column width; its background and bottom divider align with the content area at every supported window size.
- Every dashboard page is manually reviewed at `960x640`, `1100x700`, `1200x760`, and `1320x860`.
- English and Simplified Chinese are both reviewed for all dashboard pages.
- No card, settings row, picker, segmented control, or table visually crosses its rounded panel border.
- Long table values remain readable through per-table horizontal scrolling, wider column minimums, or deliberate one-line scaling.
- The menu-bar status item remains compact for every selectable metric.
- Small and medium widgets do not wrap short labels such as `Thermal`, `Battery`, `Connection`, `Memory`, or `Disk`.
- `swift test`, `swift build`, widget target build, generated Xcode build, and localization audit all pass.

## 2. Files And Responsibilities

### Create

- `docs/review/frontend-responsive-design-review.md`
  - Permanent evidence log for each reviewed surface, size, language, finding, decision, and screenshot path.

- `scripts/capture-dashboard-responsive-screenshot.sh`
  - Captures repeatable full-screen screenshots after resizing the Pulse Dock window to a requested size.

### Modify

- `Sources/PulseDockApp/DashboardVisualTokens.swift`
  - Add shared constants for top-bar height, settings control width, readable panel width, and screenshot-review breakpoints.

- `Sources/PulseDockApp/DashboardView.swift`
  - Fix `DashboardTopBar` full-width ownership.
  - Make settings rows use horizontal and vertical fallbacks.
  - Apply page-specific fixes found by the review matrix.

- `Sources/PulseDockApp/AppDelegate.swift`
  - Keep status item title width compact for all selectable metrics.
  - Confirm dashboard minimum and initial frame still match the layout matrix.

- `Sources/PulseDockWidget/SystemDashboardWidget.swift`
  - Fix widget label wrapping or spacing if the review matrix finds compact widget regressions.

- `Sources/PulseDockWidget/WidgetVisualTokens.swift`
  - Add widget spacing/label width constants if widget fixes require shared values.

- `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
  - Add source-level gates for full-width top bar, settings row fallback, review coverage, and fixed-width inventory.

- `Tests/SharedMetricsTests/MetricFormattingTests.swift`
  - Update existing source assertions that reference old layout snippets.

### Do Not Touch

- `Sources/SharedMetrics/SystemSampler.swift`
- `Sources/SharedMetrics/MetricSnapshot.swift`
- App Store metadata and screenshots
- Entitlements

## 3. Global Commands

Run after every Swift source task:

```bash
swift test --filter VisualFrontendGateTests
swift test
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
```

Expected:

```text
Test run passed
Build complete
Localization audit passed
```

Run after AppKit window, widget, or generated project assumptions change:

```bash
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected:

```text
** BUILD SUCCEEDED **
```

---

## Task 1: Create The Review Evidence Log

**Files:**
- Create: `docs/review/frontend-responsive-design-review.md`

- [ ] **Step 1: Create the evidence log**

Create the file with this exact structure:

```markdown
# Frontend Responsive Design Review

Date: 2026-06-30
Scope: Pulse Dock main window, settings, menu bar status item, popover, and widgets.

## Review Matrix

| Surface | Size | Language | Appearance | Result | Screenshot | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Dashboard Overview | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-overview.png | Check top bar full-width ownership and metric cards. |
| Dashboard Overview | 1100x700 | en | Light | Pending | docs/review/screenshots/responsive/en-light-1100x700-overview.png | Reproduce user screenshot proportion. |
| Dashboard Overview | 1320x860 | en | Light | Pending | docs/review/screenshots/responsive/en-light-1320x860-overview.png | Confirm regular density. |
| Dashboard CPU | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-cpu.png | Check chart, load rows, and bottom details. |
| Dashboard GPU / Displays | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-gpu.png | Check long table values. |
| Dashboard Memory | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-memory.png | Check ring, composition bar, and key-value grid. |
| Dashboard Storage | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-storage.png | Check capacity hero and volume table. |
| Dashboard Network | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-network.png | Check metric cards and interface table. |
| Dashboard Power | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-power.png | Check battery ring and key-value grid. |
| Dashboard Apps | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-apps.png | Check running-app table. |
| Dashboard Status | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-status.png | Check status cards and thresholds. |
| Dashboard History | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-history.png | Check trend rows. |
| Dashboard Settings | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-settings.png | Check settings controls stay inside panels. |
| Dashboard Settings | 960x640 | zh-Hans | Light | Pending | docs/review/screenshots/responsive/zh-light-960x640-settings.png | Check localized control row wrapping. |
| Menu Bar Status | Native | en | Light | Pending | docs/review/screenshots/responsive/en-light-menu-bar-status.png | Check each selected metric width. |
| Menu Bar Popover | Native | en | Light | Pending | docs/review/screenshots/responsive/en-light-popover.png | Check fixed popover frame and labels. |
| Small Widget | Small | en | Light | Pending | docs/review/screenshots/responsive/en-light-widget-small.png | Check English label wrapping. |
| Medium Widget | Medium | en | Light | Pending | docs/review/screenshots/responsive/en-light-widget-medium.png | Check metric rows and status labels. |

## Finding Log

| ID | Priority | Surface | Finding | Root Cause | Fix | Status |
| --- | --- | --- | --- | --- | --- | --- |
| RF-1 | P0 | DashboardTopBar | Header chrome can render as a centered narrow island. | `ViewThatFits` keeps intrinsic width because the top bar lacks a full-width frame. | Add full-width frames to `DashboardTopBar`, `regularContent`, and `compactContent`. | Open |
```

- [ ] **Step 2: Run a source gate for the new review file**

Run:

```bash
test -f docs/review/frontend-responsive-design-review.md && rg -n "RF-1|Dashboard Overview|Small Widget" docs/review/frontend-responsive-design-review.md
```

Expected:

```text
docs/review/frontend-responsive-design-review.md:...
```

- [ ] **Step 3: Commit the evidence-log scaffold**

```bash
git add docs/review/frontend-responsive-design-review.md
git commit -m "docs: add responsive frontend review matrix"
```

Expected:

```text
[codex/review-v2-fixes ...] docs: add responsive frontend review matrix
```

## Task 2: Add A Repeatable Screenshot Capture Helper

**Files:**
- Create: `scripts/capture-dashboard-responsive-screenshot.sh`

- [ ] **Step 1: Create the capture script**

Create `scripts/capture-dashboard-responsive-screenshot.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-Pulse Dock}"
SIZE="${SIZE:-960x640}"
PAGE="${PAGE:-current}"
LANGUAGE_TAG="${LANGUAGE_TAG:-en}"
APPEARANCE_TAG="${APPEARANCE_TAG:-light}"
OUT_DIR="${OUT_DIR:-docs/review/screenshots/responsive}"

WIDTH="${SIZE%x*}"
HEIGHT="${SIZE#*x}"
OUT_PATH="${OUT_DIR}/${LANGUAGE_TAG}-${APPEARANCE_TAG}-${SIZE}-${PAGE}.png"

mkdir -p "$OUT_DIR"

if [[ "${SKIP_RESIZE:-0}" != "1" ]]; then
  osascript <<APPLESCRIPT
tell application "$APP_NAME" to activate
delay 0.6
tell application "System Events"
  tell process "$APP_NAME"
    if not (exists window 1) then error "Pulse Dock window is not open"
    set position of window 1 to {96, 96}
    set size of window 1 to {$WIDTH, $HEIGHT}
  end tell
end tell
APPLESCRIPT
  sleep 0.4
fi

/usr/sbin/screencapture -x "$OUT_PATH"
echo "Captured $OUT_PATH"
```

- [ ] **Step 2: Make it executable**

Run:

```bash
chmod +x scripts/capture-dashboard-responsive-screenshot.sh
```

Expected: no terminal output.

- [ ] **Step 3: Smoke-test the helper**

Run with the app already open on the current page:

```bash
PAGE=overview SIZE=960x640 scripts/capture-dashboard-responsive-screenshot.sh
```

Expected:

```text
Captured docs/review/screenshots/responsive/en-light-960x640-overview.png
```

- [ ] **Step 4: Commit the helper**

```bash
git add scripts/capture-dashboard-responsive-screenshot.sh
git commit -m "test: add dashboard responsive screenshot helper"
```

Expected:

```text
[codex/review-v2-fixes ...] test: add dashboard responsive screenshot helper
```

## Task 3: Add Source Gates For This Specific Regression Class

**Files:**
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Add review coverage test**

Add this test inside `VisualFrontendGateTests`:

```swift
@Test func responsiveFrontendReviewCoversDashboardChromeAndWidgets() throws {
    let review = try fixture("docs/review/frontend-responsive-design-review.md")

    for required in [
        "Dashboard Overview",
        "Dashboard CPU",
        "Dashboard GPU / Displays",
        "Dashboard Memory",
        "Dashboard Storage",
        "Dashboard Network",
        "Dashboard Power",
        "Dashboard Apps",
        "Dashboard Status",
        "Dashboard History",
        "Dashboard Settings",
        "Menu Bar Status",
        "Menu Bar Popover",
        "Small Widget",
        "Medium Widget",
        "RF-1"
    ] {
        #expect(review.contains(required))
    }
}
```

- [ ] **Step 2: Add top-bar full-width test**

Add this test inside `VisualFrontendGateTests`:

```swift
@Test func dashboardTopBarOwnsFullWidthHeaderBand() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")
    let topBar = componentBody(named: "DashboardTopBar", in: dashboard)

    #expect(tokens.contains("static let topBarMinHeight: CGFloat = 82"))
    #expect(topBar.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
    #expect(topBar.contains(".frame(maxWidth: .infinity, minHeight: DashboardLayout.topBarMinHeight, alignment: .leading)"))
    #expect(topBar.contains("regularContent"))
    #expect(topBar.contains("compactContent"))
    #expect(!topBar.contains(".frame(minHeight: 82)"))
}
```

- [ ] **Step 3: Add settings-row fallback test**

Add this test inside `VisualFrontendGateTests`:

```swift
@Test func settingsRowsUseResponsiveControlFallbacks() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")
    let controlRow = componentBody(named: "SettingControlRow", in: dashboard)
    let readOnlyRow = componentBody(named: "SettingReadOnlyRow", in: dashboard)

    #expect(tokens.contains("static let settingsControlMaxWidth: CGFloat = 180"))
    #expect(controlRow.contains("ViewThatFits(in: .horizontal)"))
    #expect(controlRow.contains("layoutPriority(1)"))
    #expect(readOnlyRow.contains("ViewThatFits(in: .horizontal)"))
    #expect(readOnlyRow.contains("controlChip"))
}
```

- [ ] **Step 4: Run targeted tests and confirm RED**

Run:

```bash
swift test --filter VisualFrontendGateTests
```

Expected: failure mentioning `dashboardTopBarOwnsFullWidthHeaderBand` and `settingsRowsUseResponsiveControlFallbacks`.

- [ ] **Step 5: Commit the failing gates**

```bash
git add Tests/SharedMetricsTests/VisualFrontendGateTests.swift
git commit -m "test: gate responsive dashboard chrome"
```

Expected:

```text
[codex/review-v2-fixes ...] test: gate responsive dashboard chrome
```

## Task 4: Fix DashboardTopBar Full-Width Ownership

**Files:**
- Modify: `Sources/PulseDockApp/DashboardVisualTokens.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Add top-bar layout constants**

In `DashboardLayout`, add:

```swift
static let topBarMinHeight: CGFloat = 82
static let topBarVerticalPadding: CGFloat = 12
```

- [ ] **Step 2: Replace `DashboardTopBar.body`**

Replace the current `DashboardTopBar.body` with:

```swift
var body: some View {
    ViewThatFits(in: .horizontal) {
        regularContent
        compactContent
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, DashboardLayout.contentHorizontalPadding)
    .padding(.vertical, DashboardLayout.topBarVerticalPadding)
    .frame(maxWidth: .infinity, minHeight: DashboardLayout.topBarMinHeight, alignment: .leading)
    .background {
        ZStack {
            VisualEffectView(material: .headerView)
            Color(nsColor: .windowBackgroundColor).opacity(0.72)
        }
    }
    .overlay(alignment: .bottom) {
        Divider().overlay(DashboardColor.border)
    }
}
```

- [ ] **Step 3: Make both top-bar variants fill width**

Update `regularContent`:

```swift
private var regularContent: some View {
    HStack(spacing: 18) {
        titleBlock
            .layoutPriority(1)

        Spacer(minLength: DashboardSpacing.lg)

        chips
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
```

Update `compactContent`:

```swift
private var compactContent: some View {
    VStack(alignment: .leading, spacing: DashboardSpacing.sm) {
        titleBlock
        chips
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
```

- [ ] **Step 4: Make chip row resilient**

Replace `chips` with:

```swift
private var chips: some View {
    ViewThatFits(in: .horizontal) {
        fullChipRow
        essentialChipRow
    }
}

private var fullChipRow: some View {
    HStack(spacing: 8) {
        DataChip(icon: "desktopcomputer", text: PulseDockAppStrings.dashboardTopBarLocalMachine)
        DataChip(icon: "clock", text: PulseDockAppStrings.dashboardSampleChip(snapshot.sampleTimeText))
        DataChip(icon: "arrow.clockwise", text: refreshInterval.label)
    }
}

private var essentialChipRow: some View {
    HStack(spacing: 8) {
        DataChip(icon: "clock", text: snapshot.sampleTimeText)
        DataChip(icon: "arrow.clockwise", text: refreshInterval.label)
    }
}
```

- [ ] **Step 5: Update tests that assert the old min-height string**

Run:

```bash
rg -n "frame\\(minHeight: 82\\)|topBarMinHeight|DashboardTopBar" Tests/SharedMetricsTests
```

For any assertion that requires `.frame(minHeight: 82)`, replace it with:

```swift
#expect(topBar.contains(".frame(maxWidth: .infinity, minHeight: DashboardLayout.topBarMinHeight, alignment: .leading)"))
```

- [ ] **Step 6: Verify top-bar gate passes**

Run:

```bash
swift test --filter VisualFrontendGateTests/dashboardTopBarOwnsFullWidthHeaderBand
```

Expected:

```text
Test run passed
```

- [ ] **Step 7: Commit the top-bar fix**

```bash
git add Sources/PulseDockApp/DashboardVisualTokens.swift Sources/PulseDockApp/DashboardView.swift Tests/SharedMetricsTests
git commit -m "fix: keep dashboard top bar full width"
```

Expected:

```text
[codex/review-v2-fixes ...] fix: keep dashboard top bar full width
```

## Task 5: Harden Settings Rows And Control Containers

**Files:**
- Modify: `Sources/PulseDockApp/DashboardVisualTokens.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Add settings layout constants**

In `DashboardLayout`, add:

```swift
static let settingsControlMaxWidth: CGFloat = 180
static let settingsControlCompactMaxWidth: CGFloat = 220
```

- [ ] **Step 2: Replace `SettingControlRow`**

Replace the body and add a `textBlock` helper:

```swift
private var bodyContent: some View {
    ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
            textBlock
            Spacer(minLength: DashboardSpacing.lg)
            control
                .layoutPriority(1)
                .frame(maxWidth: DashboardLayout.settingsControlMaxWidth)
        }

        VStack(alignment: .leading, spacing: DashboardSpacing.sm) {
            textBlock
            HStack {
                Spacer(minLength: 0)
                control
                    .layoutPriority(1)
                    .frame(maxWidth: DashboardLayout.settingsControlCompactMaxWidth)
            }
        }
    }
}

private var textBlock: some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        Text(detail)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DashboardColor.muted)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

var body: some View {
    bodyContent
        .padding(12)
        .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
}
```

- [ ] **Step 3: Replace `SettingReadOnlyRow`**

Add helpers and update the body:

```swift
private var textBlock: some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        Text(detail)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DashboardColor.muted)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

private var controlChip: some View {
    Text(control)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DashboardColor.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.40), in: Capsule())
}

var body: some View {
    ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
            textBlock
            Spacer(minLength: DashboardSpacing.lg)
            controlChip
                .layoutPriority(1)
        }

        VStack(alignment: .leading, spacing: DashboardSpacing.sm) {
            textBlock
            HStack {
                Spacer(minLength: 0)
                controlChip
                    .layoutPriority(1)
            }
        }
    }
    .padding(12)
    .background(DashboardColor.panelAlt.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .opacity(0.78)
}
```

- [ ] **Step 4: Verify settings gates pass**

Run:

```bash
swift test --filter VisualFrontendGateTests/settingsRowsUseResponsiveControlFallbacks
swift test --filter VisualFrontendGateTests
```

Expected:

```text
Test run passed
```

- [ ] **Step 5: Commit settings row hardening**

```bash
git add Sources/PulseDockApp/DashboardVisualTokens.swift Sources/PulseDockApp/DashboardView.swift Tests/SharedMetricsTests
git commit -m "fix: harden settings row layout"
```

Expected:

```text
[codex/review-v2-fixes ...] fix: harden settings row layout
```

## Task 6: Review And Fix Every Dashboard Page

**Files:**
- Modify: `docs/review/frontend-responsive-design-review.md`
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Run the page matrix**

For each page, open Pulse Dock, switch to the page manually, then run:

```bash
PAGE=overview SIZE=960x640 scripts/capture-dashboard-responsive-screenshot.sh
PAGE=overview SIZE=1100x700 scripts/capture-dashboard-responsive-screenshot.sh
PAGE=overview SIZE=1320x860 scripts/capture-dashboard-responsive-screenshot.sh
```

Repeat with `PAGE=cpu`, `gpu`, `memory`, `storage`, `network`, `power`, `apps`, `status`, `history`, and `settings`.

Expected after each command:

```text
Captured docs/review/screenshots/responsive/en-light-...
```

- [ ] **Step 2: Update the review log with decisions**

For every row reviewed, change `Pending` to one of:

```markdown
Pass
Needs Fix
Accepted Scroll
```

Use `Accepted Scroll` only when horizontal scrolling is inside a table region and the card boundary remains intact.

- [ ] **Step 3: Apply allowed fix pattern A for full-width container bugs**

Use this pattern when a section background, divider, or panel chrome is narrower than its parent:

```swift
.frame(maxWidth: .infinity, alignment: .leading)
```

For top-level bands, use:

```swift
.frame(maxWidth: .infinity, minHeight: DashboardLayout.topBarMinHeight, alignment: .leading)
```

- [ ] **Step 4: Apply allowed fix pattern B for horizontal compression**

Use this pattern when a row is readable at regular width but cramped at intermediate width:

```swift
ViewThatFits(in: .horizontal) {
    HStack(alignment: .top, spacing: DashboardLayout.compactPanelSpacing) {
        primary()
            .frame(maxWidth: .infinity, alignment: .leading)
        secondary()
            .frame(width: secondaryWidth)
    }

    VStack(alignment: .leading, spacing: DashboardLayout.compactPanelSpacing) {
        primary()
        secondary()
    }
}
```

- [ ] **Step 5: Apply allowed fix pattern C for dense data**

For tables with long values, increase `preferredColumnWidth` at the call site:

```swift
ResponsiveTable(
    columns: PulseDockAppStrings.displayTableColumns,
    rows: snapshot.displayTableRows,
    emptyText: PulseDockAppStrings.notReported,
    preferredColumnWidth: DashboardLayout.wideTableColumnWidth
)
```

If the table still truncates a verified long field, add a wider token:

```swift
static let extraWideTableColumnWidth: CGFloat = 132
```

Then use:

```swift
preferredColumnWidth: DashboardLayout.extraWideTableColumnWidth
```

- [ ] **Step 6: Add source gate for fixed-width inventory**

Add this test inside `VisualFrontendGateTests`:

```swift
@Test func responsiveReviewTracksRemainingFixedWidths() throws {
    let review = try fixture("docs/review/frontend-responsive-design-review.md")
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    for fixedWidth in [
        ".frame(width: 360)",
        ".frame(width: 340)",
        ".frame(width: 320)",
        ".frame(width: 214)"
    ] {
        if dashboard.contains(fixedWidth) {
            #expect(review.contains(fixedWidth))
        }
    }
}
```

- [ ] **Step 7: Run page-review gates**

Run:

```bash
swift test --filter VisualFrontendGateTests/responsiveFrontendReviewCoversDashboardChromeAndWidgets
swift test --filter VisualFrontendGateTests/responsiveReviewTracksRemainingFixedWidths
```

Expected:

```text
Test run passed
```

- [ ] **Step 8: Commit page-level fixes and evidence**

```bash
git add Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/DashboardVisualTokens.swift Tests/SharedMetricsTests/VisualFrontendGateTests.swift docs/review/frontend-responsive-design-review.md docs/review/screenshots/responsive
git commit -m "fix: harden responsive dashboard pages"
```

Expected:

```text
[codex/review-v2-fixes ...] fix: harden responsive dashboard pages
```

## Task 7: Review Menu Bar, Popover, And Widgets

**Files:**
- Modify: `docs/review/frontend-responsive-design-review.md`
- Modify: `Sources/PulseDockApp/AppDelegate.swift`
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
- Modify: `Sources/PulseDockWidget/WidgetVisualTokens.swift`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Review menu-bar status width**

Set the status metric in Settings to each option and capture:

```bash
PAGE=menu-bar-status SIZE=1320x860 SKIP_RESIZE=1 scripts/capture-dashboard-responsive-screenshot.sh
```

Record the result in `docs/review/frontend-responsive-design-review.md`.

- [ ] **Step 2: Add menu-bar source gate if width is still too wide**

If the review finds the visible menu extra too wide, add this test:

```swift
@Test func menuBarStatusItemKeepsSelectableMetricsCompact() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

    #expect(appDelegate.contains("static let metricTitleLength"))
    #expect(!appDelegate.contains("static let metricTitleLength: CGFloat = 118"))
    #expect(appDelegate.contains("static let compactLength = NSStatusItem.squareLength"))
}
```

- [ ] **Step 3: Review popover and widgets**

Capture current popover and widget states:

```bash
PAGE=popover SIZE=1320x860 SKIP_RESIZE=1 scripts/capture-dashboard-responsive-screenshot.sh
PAGE=widget-small SIZE=1320x860 SKIP_RESIZE=1 scripts/capture-dashboard-responsive-screenshot.sh
PAGE=widget-medium SIZE=1320x860 SKIP_RESIZE=1 scripts/capture-dashboard-responsive-screenshot.sh
```

Record `Pass` or `Needs Fix` in the review matrix.

- [ ] **Step 4: Use exact compact-label fix for widget wrapping**

If the small widget wraps short English labels, update the affected widget labels to use a smaller label style:

```swift
.lineLimit(1)
.minimumScaleFactor(0.55)
.allowsTightening(true)
```

For two short labels at the bottom of the small widget, use fixed leading label width only when the resulting value still fits:

```swift
.frame(width: 54, alignment: .leading)
```

- [ ] **Step 5: Verify chrome and widget tests**

Run:

```bash
swift test --filter VisualFrontendGateTests
swift test --filter MetricFormattingTests/menuBarStatusItemKeepsSelectableMetricsCompact
swift build --target PulseDockWidget
```

Expected:

```text
Test run passed
Build complete
```

- [ ] **Step 6: Commit chrome/widget fixes**

```bash
git add Sources/PulseDockApp/AppDelegate.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Sources/PulseDockWidget/WidgetVisualTokens.swift Tests/SharedMetricsTests docs/review/frontend-responsive-design-review.md docs/review/screenshots/responsive
git commit -m "fix: harden compact chrome and widgets"
```

Expected:

```text
[codex/review-v2-fixes ...] fix: harden compact chrome and widgets
```

## Task 8: Final Verification And Local Install

**Files:**
- Modify: `docs/review/frontend-responsive-design-review.md`

- [ ] **Step 1: Run complete tests**

```bash
swift test
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
```

Expected:

```text
Test run passed
Build complete
Localization audit passed
```

- [ ] **Step 2: Run generated Xcode build**

```bash
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected:

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 3: Reinstall local app for visual review**

```bash
scripts/package-app.sh
scripts/install-system-widget.sh
open -n "$HOME/Applications/Pulse Dock.app"
```

Expected:

```text
Installed Pulse Dock.app
```

- [ ] **Step 4: Mark final review status**

At the bottom of `docs/review/frontend-responsive-design-review.md`, add:

```markdown
## Final Result

All P0 responsive layout failures are fixed. All dashboard pages were reviewed at compact, intermediate, and regular sizes in English. Simplified Chinese Settings was reviewed for control-row width. Menu-bar, popover, and widget compact surfaces were reviewed after the dashboard fixes. Remaining accepted horizontal scrolling is isolated to table regions.
```

- [ ] **Step 5: Commit final verification**

```bash
git add docs/review/frontend-responsive-design-review.md docs/review/screenshots/responsive
git commit -m "docs: record responsive frontend verification"
```

Expected:

```text
[codex/review-v2-fixes ...] docs: record responsive frontend verification
```

## Execution Order

1. Task 1: evidence log.
2. Task 2: screenshot helper.
3. Task 3: failing source gates.
4. Task 4: `DashboardTopBar` full-width fix.
5. Task 5: settings row fallback.
6. Task 6: page-by-page review and fixes.
7. Task 7: menu-bar, popover, and widget compact review.
8. Task 8: final verification and local install.

## Risk Notes

- `DashboardTopBar` is the first repair because it explains the screenshot directly and has the smallest code blast radius.
- Settings rows are second because recent screenshots already showed a control crossing a panel border.
- Page-specific fixes must be made through shared patterns before local one-off frames are introduced.
- Widget fixes must preserve WidgetKit family sizing; do not make widget views depend on the main dashboard layout constants.
- The screenshot helper captures full-screen images because SwiftUI sidebar buttons do not expose stable names for reliable page switching in UI scripting.

## Self-Review

Spec coverage: the plan covers the specific scaled Overview defect, all dashboard pages, settings controls, menu-bar status width, popover, widgets, source gates, screenshot evidence, and final local install.

Placeholder scan command:

```bash
rg -n -e 'T[B]D' -e 'T[O]DO' -e 'implement[ ]later' -e 'fill[ ]in details' -e 'appropriate[ ]error' -e 'Similar[ ]to Task' docs/superpowers/plans/2026-06-30-pulse-dock-responsive-frontend-review.md
```

Expected: no output.

Type consistency: new code snippets use existing `DashboardTopBar`, `SettingControlRow`, `SettingReadOnlyRow`, `DashboardLayout`, `DashboardSpacing`, and `VisualFrontendGateTests` names already present in the repository.
