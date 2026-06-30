# Pulse Dock Dynamic Width And Motion Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the menu bar selected metric compact and visually balanced, stabilize live time/number text so containers stop shifting, and audit the dashboard/widget surfaces for related layout and motion polish issues.

**Architecture:** Replace the fixed 92pt menu bar metric slot with a measured and clamped AppKit status item width that keeps the popover anchor stable without wasting horizontal space. Add small SwiftUI primitives for monospaced, min-width, numeric-transition text and use them on chips, metric values, badges, and row values where live samples update. Record the review matrix in docs and add source-level gates so future visual changes cannot reintroduce oversized status items or unstable dynamic labels.

**Tech Stack:** macOS AppKit `NSStatusItem`, SwiftUI, Swift Testing, Pulse Dock `DashboardVisualTokens`, `DashboardView`, `WidgetPanelView`, `SystemDashboardWidget`.

---

## Files

- Modify: `Sources/PulseDockApp/AppDelegate.swift`
  - Responsibility: menu bar status item icon/text width, title font, and selected metric rendering.
- Modify: `Sources/PulseDockApp/DashboardVisualTokens.swift`
  - Responsibility: shared layout constants and motion helpers for stable dynamic text.
- Modify: `Sources/PulseDockApp/DashboardView.swift`
  - Responsibility: dashboard top bar chips, metric cards, gauges, summary cards, trend rows, stat rows, and settings value chips.
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
  - Responsibility: popover compact status labels and live values.
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`
  - Responsibility: widget English label wrapping and live value stability.
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
  - Responsibility: frontend-specific source guards for compact status item width, stable text components, and Reduce Motion-aware transitions.
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
  - Responsibility: update existing menu bar tests that currently assert the old fixed 92pt slot.
- Modify: `docs/data-capability-audit.md`
  - Responsibility: keep the AppKit behavior note accurate after moving from fixed width to measured width.
- Create: `docs/review/frontend-dynamic-width-motion-review.md`
  - Responsibility: human-readable audit of dynamic-width, clipping, wrapping, and animation surfaces.

---

### Task 1: Add Frontend Gates For Compact Menu Bar Metrics

**Files:**
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`

- [ ] **Step 1: Add the failing menu bar width gate**

Append this test inside `struct VisualFrontendGateTests` in `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`:

```swift
    @Test func menuBarSelectedMetricUsesMeasuredCompactStatusLength() throws {
        let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

        #expect(appDelegate.contains("static let metricMinLength: CGFloat = 46"))
        #expect(appDelegate.contains("static let metricMaxLength: CGFloat = 104"))
        #expect(appDelegate.contains("static let metricHorizontalPadding: CGFloat = 7"))
        #expect(appDelegate.contains("static let iconAllowance: CGFloat = 20"))
        #expect(appDelegate.contains("static func titleLength(for text: String, font: NSFont) -> CGFloat"))
        #expect(appDelegate.contains("static func titleLength(for option: MenuBarMetricOption, font: NSFont) -> CGFloat"))
        #expect(appDelegate.contains("case .network: \"999 Mbps\""))
        #expect(appDelegate.contains("let measuredTextWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)"))
        #expect(appDelegate.contains("return min(metricMaxLength, max(metricMinLength, measuredTextWidth + metricHorizontalPadding * 2 + iconAllowance))"))
        #expect(appDelegate.contains("private var statusItemLengthMode: MenuBarMetricOption?"))
        #expect(appDelegate.contains("guard statusPopover?.isShown != true else { return }"))
        #expect(appDelegate.contains("let statusFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)"))
        #expect(appDelegate.contains("button.font = statusFont"))
        #expect(appDelegate.contains("button.title = metricText"))
        #expect(appDelegate.contains("let statusLength = MenuBarStatusItemLayout.titleLength(for: selectedMetric, font: statusFont)"))
        #expect(appDelegate.contains("applyStatusItemLength(statusLength, mode: selectedMetric)"))
        #expect(!appDelegate.contains("metricTitleLength"))
        #expect(!appDelegate.contains("button?.title = \" \\(metricText)\""))
    }
```

- [ ] **Step 2: Run the new gate and confirm it fails on the current fixed-width implementation**

Run:

```bash
swift test --filter VisualFrontendGateTests/menuBarSelectedMetricUsesMeasuredCompactStatusLength
```

Expected: fail because `AppDelegate.swift` still contains `metricTitleLength: CGFloat = 92`, `titleLength(for text: String)`, and `statusItem?.button?.title = " \(metricText)"`.

- [ ] **Step 3: Update old menu bar source assertions**

In `Tests/SharedMetricsTests/MetricFormattingTests.swift`, replace the old assertions inside `menuPopoverUsesStableStatusItemLengthWhileCPUTitleRefreshes` with:

```swift
    #expect(appDelegate.contains("private enum MenuBarStatusItemLayout"))
    #expect(appDelegate.contains("static let compactLength = NSStatusItem.squareLength"))
    #expect(appDelegate.contains("static let metricMinLength: CGFloat = 46"))
    #expect(appDelegate.contains("static let metricMaxLength: CGFloat = 104"))
    #expect(appDelegate.contains("static func titleLength(for text: String, font: NSFont) -> CGFloat"))
    #expect(appDelegate.contains("static func titleLength(for option: MenuBarMetricOption, font: NSFont) -> CGFloat"))
    #expect(appDelegate.contains("case .network: \"999 Mbps\""))
    #expect(appDelegate.contains("private var statusItemLengthMode: MenuBarMetricOption?"))
    #expect(appDelegate.contains("private func statusButtonMetricText(for option: MenuBarMetricOption) -> String?"))
    #expect(appDelegate.contains("let selectedMetric = store.menuBarMetric"))
    #expect(appDelegate.contains("guard let metricText = statusButtonMetricText(for: selectedMetric) else"))
    #expect(appDelegate.contains("let statusLength = MenuBarStatusItemLayout.titleLength(for: selectedMetric, font: statusFont)"))
    #expect(appDelegate.contains("applyStatusItemLength(statusLength, mode: selectedMetric)"))
    #expect(appDelegate.contains("button.title = metricText"))
    #expect(appDelegate.contains("store.$snapshot.combineLatest(store.$menuBarMetric)"))
    #expect(appDelegate.contains("self?.updateStatusButtonTitle()"))
    #expect(audit.contains("Menu bar status item uses measured, representative, clamped lengths for selected metrics so live title refreshes keep the popover anchor stable without wasting menu bar space."))
    #expect(audit.contains("Source-level tests require the menu bar status item to measure selected metric families with monospaced digits, representative network text, and a tight clamped width."))
```

In `menuBarMetricSelectionPersistsAndDrivesStatusItem`, replace:

```swift
    #expect(appDelegate.contains("MenuBarStatusItemLayout.titleLength(for: store.menuBarMetric)"))
```

with:

```swift
    #expect(appDelegate.contains("MenuBarStatusItemLayout.titleLength(for: selectedMetric, font: statusFont)"))
```

- [ ] **Step 4: Run both affected source gates**

Run:

```bash
swift test --filter VisualFrontendGateTests/menuBarSelectedMetricUsesMeasuredCompactStatusLength
swift test --filter MetricFormattingTests/menuPopoverUsesStableStatusItemLengthWhileCPUTitleRefreshes
swift test --filter MetricFormattingTests/menuBarMetricSelectionPersistsAndDrivesStatusItem
```

Expected: all three fail until `AppDelegate.swift` and `docs/data-capability-audit.md` are updated.

---

### Task 2: Implement Measured Menu Bar Metric Width

**Files:**
- Modify: `Sources/PulseDockApp/AppDelegate.swift`
- Modify: `docs/data-capability-audit.md`

- [ ] **Step 1: Replace the fixed status item width helper**

Replace the current `MenuBarStatusItemLayout` in `Sources/PulseDockApp/AppDelegate.swift` with:

```swift
private enum MenuBarStatusItemLayout {
    static let compactLength = NSStatusItem.squareLength
    static let metricMinLength: CGFloat = 46
    static let metricMaxLength: CGFloat = 104
    static let metricHorizontalPadding: CGFloat = 7
    static let iconAllowance: CGFloat = 20

    static func titleLength(for text: String, font: NSFont) -> CGFloat {
        let measuredTextWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        return min(metricMaxLength, max(metricMinLength, measuredTextWidth + metricHorizontalPadding * 2 + iconAllowance))
    }

    static func titleLength(for option: MenuBarMetricOption, font: NSFont) -> CGFloat {
        titleLength(for: representativeText(for: option), font: font)
    }

    private static func representativeText(for option: MenuBarMetricOption) -> String {
        switch option {
        case .iconOnly: ""
        case .cpu, .memory, .battery: "100%"
        case .network: "999 Mbps"
        }
    }
}
```

- [ ] **Step 2: Keep the menu bar title font stable**

In `createStatusItem()`, after `button.imagePosition = .imageLeading`, add:

```swift
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
```

- [ ] **Step 3: Use the measured width in live title updates**

Replace `updateStatusButtonTitle()` with:

```swift
    private func updateStatusButtonTitle() {
        guard let button = statusItem?.button else { return }

        let statusFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        button.font = statusFont

        let selectedMetric = store.menuBarMetric
        guard let metricText = statusButtonMetricText(for: selectedMetric) else {
            applyStatusItemLength(MenuBarStatusItemLayout.compactLength, mode: nil)
            button.title = ""
            return
        }

        let statusLength = MenuBarStatusItemLayout.titleLength(for: selectedMetric, font: statusFont)
        applyStatusItemLength(statusLength, mode: selectedMetric)
        button.title = metricText
    }

    private func applyStatusItemLength(_ length: CGFloat, mode: MenuBarMetricOption?) {
        guard statusItemLengthMode != mode else { return }
        guard statusPopover?.isShown != true else { return }
        statusItem?.length = length
        statusItemLengthMode = mode
    }
```

This removes the literal leading space and caps selected metrics so `"13%"`, `"100%"`, and short network strings do not reserve a large empty slot.

- [ ] **Step 4: Update the audit wording**

In `docs/data-capability-audit.md`, replace the old fixed-width status item note with these two sentences:

```markdown
Menu bar status item uses measured, representative, clamped lengths for selected metrics so live title refreshes keep the popover anchor stable without wasting menu bar space.
Source-level tests require the menu bar status item to measure selected metric families with monospaced digits, representative network text, and a tight clamped width.
```

- [ ] **Step 5: Run menu bar gates**

Run:

```bash
swift test --filter VisualFrontendGateTests/menuBarSelectedMetricUsesMeasuredCompactStatusLength
swift test --filter MetricFormattingTests/menuPopoverUsesStableStatusItemLengthWhileCPUTitleRefreshes
swift test --filter MetricFormattingTests/menuBarMetricSelectionPersistsAndDrivesStatusItem
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/PulseDockApp/AppDelegate.swift Tests/SharedMetricsTests/VisualFrontendGateTests.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md
git commit -m "fix: tighten menu bar metric status width"
```

---

### Task 3: Add Gates For Stable Dashboard Dynamic Text

**Files:**
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Add source gates for chips, values, and numeric transitions**

Append this test inside `struct VisualFrontendGateTests`:

```swift
    @Test func dashboardDynamicTextUsesStableDigitComponents() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")

        #expect(tokens.contains("static let sampleChipMinWidth: CGFloat = 156"))
        #expect(tokens.contains("static let shortTimeChipMinWidth: CGFloat = 96"))
        #expect(tokens.contains("static let metricValueMinWidth: CGFloat = 96"))
        #expect(tokens.contains("static let statValueMinWidth: CGFloat = 56"))
        #expect(tokens.contains("static let badgeValueMinWidth: CGFloat = 42"))
        #expect(dashboard.contains("private struct StableMetricText: View"))
        #expect(dashboard.contains("@Environment(\\.accessibilityReduceMotion) private var reduceMotion"))
        #expect(dashboard.contains(".contentTransition(reduceMotion ? .identity : .numericText())"))
        #expect(dashboard.contains(".animation(DashboardMotion.metric(reduceMotion: reduceMotion), value: text)"))
        #expect(dashboard.contains("DataChip(icon: \"clock\", text: PulseDockAppStrings.dashboardSampleChip(snapshot.sampleTimeText), minWidth: DashboardLayout.sampleChipMinWidth, monospacedDigits: true)"))
        #expect(dashboard.contains("DataChip(icon: \"clock\", text: snapshot.sampleTimeText, minWidth: DashboardLayout.shortTimeChipMinWidth, monospacedDigits: true)"))
        #expect(dashboard.contains("StableMetricText(text: value, font: .system(size: 29, weight: .semibold, design: .default), minWidth: DashboardLayout.metricValueMinWidth, alignment: .leading, minimumScaleFactor: 0.68)"))
        #expect(dashboard.contains("StableMetricText(text: value, font: .system(size: 13, weight: .semibold), minWidth: DashboardLayout.statValueMinWidth, alignment: .trailing, minimumScaleFactor: 0.70)"))
    }
```

- [ ] **Step 2: Run the new gate**

Run:

```bash
swift test --filter VisualFrontendGateTests/dashboardDynamicTextUsesStableDigitComponents
```

Expected: fail because `StableMetricText` and the min-width layout constants do not exist yet.

---

### Task 4: Implement Stable Dashboard Text Primitives

**Files:**
- Modify: `Sources/PulseDockApp/DashboardVisualTokens.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift`

- [ ] **Step 1: Add dynamic text layout constants**

In `DashboardLayout` in `Sources/PulseDockApp/DashboardVisualTokens.swift`, add:

```swift
    static let sampleChipMinWidth: CGFloat = 156
    static let shortTimeChipMinWidth: CGFloat = 96
    static let metricValueMinWidth: CGFloat = 96
    static let statValueMinWidth: CGFloat = 56
    static let badgeValueMinWidth: CGFloat = 42
```

- [ ] **Step 2: Add the stable text view**

In `Sources/PulseDockApp/DashboardView.swift`, place this helper above `DataChip`:

```swift
private struct StableMetricText: View {
    let text: String
    let font: Font
    let minWidth: CGFloat?
    let alignment: Alignment
    let minimumScaleFactor: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(font.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(DashboardMotion.metric(reduceMotion: reduceMotion), value: text)
            .frame(minWidth: minWidth, alignment: alignment)
    }
}
```

- [ ] **Step 3: Upgrade `DataChip` to support stable numeric text**

Replace `DataChip` with:

```swift
private struct DataChip: View {
    let icon: String
    let text: String
    var minWidth: CGFloat?
    var monospacedDigits = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var textFont: Font {
        let base = Font.system(size: 12, weight: .semibold)
        return monospacedDigits ? base.monospacedDigit() : base
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .accessibilityHidden(true)
            Text(text)
                .font(textFont)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(monospacedDigits && !reduceMotion ? .numericText() : .identity)
                .animation(monospacedDigits ? DashboardMotion.metric(reduceMotion: reduceMotion) : nil, value: text)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(minWidth: minWidth)
        .background(.quaternary.opacity(0.62), in: Capsule())
    }
}
```

- [ ] **Step 4: Stabilize top bar clock chips**

In `DashboardTopBar.fullChipRow`, replace the sample chip call with:

```swift
            DataChip(icon: "clock", text: PulseDockAppStrings.dashboardSampleChip(snapshot.sampleTimeText), minWidth: DashboardLayout.sampleChipMinWidth, monospacedDigits: true)
```

In `DashboardTopBar.essentialChipRow`, replace the sample chip call with:

```swift
            DataChip(icon: "clock", text: snapshot.sampleTimeText, minWidth: DashboardLayout.shortTimeChipMinWidth, monospacedDigits: true)
```

- [ ] **Step 5: Stabilize metric card values and badges**

In `MetricCard`, replace badge and value `Text` blocks with:

```swift
                if let badgeText = badgeText {
                    StableMetricText(
                        text: badgeText,
                        font: .system(size: 11, weight: .semibold),
                        minWidth: DashboardLayout.badgeValueMinWidth,
                        alignment: .trailing,
                        minimumScaleFactor: 0.72
                    )
                    .foregroundStyle(tint)
                }
```

and:

```swift
                StableMetricText(
                    text: value,
                    font: .system(size: 29, weight: .semibold, design: .default),
                    minWidth: DashboardLayout.metricValueMinWidth,
                    alignment: .leading,
                    minimumScaleFactor: 0.68
                )
```

- [ ] **Step 6: Stabilize summary and stat values**

In `SummaryCard`, replace the value `Text` with:

```swift
                StableMetricText(
                    text: value,
                    font: .system(size: 24, weight: .semibold),
                    minWidth: DashboardLayout.metricValueMinWidth,
                    alignment: .leading,
                    minimumScaleFactor: 0.72
                )
```

In `StatLine`, replace the value `Text` with:

```swift
                StableMetricText(
                    text: value,
                    font: .system(size: 13, weight: .semibold),
                    minWidth: DashboardLayout.statValueMinWidth,
                    alignment: .trailing,
                    minimumScaleFactor: 0.70
                )
```

- [ ] **Step 7: Run the dashboard dynamic text gate**

Run:

```bash
swift test --filter VisualFrontendGateTests/dashboardDynamicTextUsesStableDigitComponents
```

Expected: pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/PulseDockApp/DashboardVisualTokens.swift Sources/PulseDockApp/DashboardView.swift Tests/SharedMetricsTests/VisualFrontendGateTests.swift
git commit -m "fix: stabilize live dashboard text width"
```

---

### Task 5: Audit Remaining Frontend Dynamic Width And Motion Surfaces

**Files:**
- Create: `docs/review/frontend-dynamic-width-motion-review.md`
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
- Modify: `Sources/PulseDockApp/WidgetPanelView.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift`

- [ ] **Step 1: Write the audit document**

Create `docs/review/frontend-dynamic-width-motion-review.md` with:

```markdown
# Frontend Dynamic Width And Motion Review

## Scope

| Surface | Risk | Required handling |
| --- | --- | --- |
| macOS menu bar status item | Selected metric can reserve too much space or jump while text changes | Measured clamped status length, no literal leading space, monospaced digit font |
| Dashboard top bar chips | Time strings change width every second/minute | Min-width clock chips, monospaced digits, Reduce Motion-aware numeric transition |
| Metric cards and badges | Values such as 9% to 100%, 999 Kbps to 1.0 MB/s can resize text blocks | StableMetricText with min-width and one-line scaling |
| Stat rows and key-value grids | Right-aligned values can move row baselines | StableMetricText for live numeric values |
| Settings controls | Segmented controls and picker chips can exceed cards at zoomed display scale | Width caps, ViewThatFits fallback, one-line scale |
| Popover widget panel | Compact metrics update while the popover is anchored | Monospaced values and one-line scaling |
| Desktop widgets | English labels and values compete for narrow widths | Label abbreviations, one-line values, adaptive stacks |
| Motion | Numeric and progress changes feel abrupt | Numeric text transitions and existing DashboardMotion guarded by Reduce Motion |

## Findings

| ID | Status | Evidence | Fix |
| --- | --- | --- | --- |
| DW-1 | Confirmed | AppDelegate used a fixed 92pt metric slot | Replace with measured 46-76pt clamped width |
| DW-2 | Confirmed | AppDelegate prepended a literal space before the metric title | Remove the leading space and let AppKit image/title spacing handle separation |
| DW-3 | Confirmed | Dashboard sample chip used proportional time text with no min-width | Add min-width and monospaced digits to sample chips |
| DW-4 | Confirmed | Metric values had monospaced digits but no stable frame or numeric transition | Add StableMetricText for values and badges |
| DW-5 | Watch | Settings segmented controls can crowd cards at large text or scaled windows | Keep ViewThatFits fallback and width caps under source gates |
| DW-6 | Watch | Widget English labels can wrap in compact families | Keep abbreviations and one-line value guards under source gates |

## Acceptance

- The menu bar selected metric for CPU, memory, battery, and short network values fits tightly beside the icon.
- Switching between icon-only and selected metrics does not leave broad empty padding on either side of the status item.
- Top bar sample time changes do not resize the chip every second.
- Dashboard value changes use monospaced digits and do not move neighboring controls.
- Numeric transitions are disabled when Reduce Motion is enabled.
- Widget and popover labels stay one line in English at supported sizes.
```

- [ ] **Step 2: Add gates for audit coverage**

Append this test inside `struct VisualFrontendGateTests`:

```swift
    @Test func dynamicWidthAndMotionReviewDocumentCoversKnownSurfaces() throws {
        let review = try fixture("docs/review/frontend-dynamic-width-motion-review.md")

        #expect(review.contains("macOS menu bar status item"))
        #expect(review.contains("Dashboard top bar chips"))
        #expect(review.contains("Metric cards and badges"))
        #expect(review.contains("Settings controls"))
        #expect(review.contains("Popover widget panel"))
        #expect(review.contains("Desktop widgets"))
        #expect(review.contains("Reduce Motion"))
        #expect(review.contains("DW-1"))
        #expect(review.contains("DW-6"))
    }
```

- [ ] **Step 3: Run the audit document gate**

Run:

```bash
swift test --filter VisualFrontendGateTests/dynamicWidthAndMotionReviewDocumentCoversKnownSurfaces
```

Expected: pass after the document is created.

- [ ] **Step 4: Inspect remaining plain dynamic `Text` call sites**

Run:

```bash
rg -n "Text\\(snapshot\\.|Text\\(value\\)|Text\\(badgeText\\)|Text\\(item\\.1\\)|Text\\(refreshInterval\\.label\\)|sampleTimeText" Sources/PulseDockApp Sources/PulseDockWidget
```

Expected: each match is either already wrapped with `StableMetricText`, uses `.monospacedDigit()` and one-line scaling, or is a non-live static label. Record any new confirmed issue in `docs/review/frontend-dynamic-width-motion-review.md` before editing.

- [ ] **Step 5: Patch popover and widget value labels found by the inspection**

For `WidgetPanelView.swift` and `SystemDashboardWidget.swift`, apply the same pattern on live values:

```swift
.font(.system(size: 11, weight: .semibold).monospacedDigit())
.lineLimit(1)
.minimumScaleFactor(0.62)
```

For English labels that still wrap in compact space, prefer the existing abbreviated labels already used in the widget, such as `Temp` and `Pwr`, and keep values aligned with fixed-width progress rows.

- [ ] **Step 6: Run focused frontend gates**

Run:

```bash
swift test --filter VisualFrontendGateTests
swift build --target PulseDockWidget
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add docs/review/frontend-dynamic-width-motion-review.md Tests/SharedMetricsTests/VisualFrontendGateTests.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/PulseDockWidget/SystemDashboardWidget.swift
git commit -m "docs: audit dynamic width and motion polish"
```

---

### Task 6: Run Visual Verification On Real Builds

**Files:**
- Read: `scripts/generate-xcodeproj.rb`
- Read: `scripts/package-app.sh`
- Read: `scripts/install-system-widget.sh`
- Read: `scripts/capture-dashboard-responsive-screenshot.sh`
- Modify only if a verification script path is broken: `scripts/capture-dashboard-responsive-screenshot.sh`

- [ ] **Step 1: Run full source and build checks**

Run:

```bash
swift test
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug -destination 'platform=macOS' build
```

Expected: every command exits 0. `xcodebuild` may print simulator discovery warnings; treat them as acceptable only if the final build result succeeds.

- [ ] **Step 2: Install the local app build**

Run:

```bash
scripts/package-app.sh
scripts/install-system-widget.sh
open -n "$HOME/Applications/Pulse Dock.app"
```

Expected: the updated app launches from `$HOME/Applications/Pulse Dock.app`.

- [ ] **Step 3: Capture dashboard screenshots at sensitive sizes**

Run:

```bash
SCREENSHOT_PATH="docs/review/screenshots/responsive/en-light-1100x700-dynamic-width.png" \
PULSE_DOCK_LOCALE="en" \
PULSE_DOCK_APPEARANCE="light" \
PULSE_DOCK_WINDOW_SIZE="1100x700" \
scripts/capture-dashboard-responsive-screenshot.sh

SCREENSHOT_PATH="docs/review/screenshots/responsive/zh-light-1100x700-dynamic-width.png" \
PULSE_DOCK_LOCALE="zh-Hans" \
PULSE_DOCK_APPEARANCE="light" \
PULSE_DOCK_WINDOW_SIZE="1100x700" \
scripts/capture-dashboard-responsive-screenshot.sh
```

Expected: both screenshots are created under `docs/review/screenshots/responsive/`.

- [ ] **Step 4: Manual visual pass**

Check these points on the installed app:

```text
1. Menu bar icon-only mode uses the normal square status item width.
2. Menu bar CPU, memory, network, and battery modes fit tightly beside the icon, with no broad empty side padding.
3. Opening the popover from a selected metric keeps the arrow anchored under the status item.
4. The dashboard sample chip does not resize when seconds change.
5. Metric card values do not move neighboring text when changing from one to two or three digits.
6. Reduce Motion disables numeric animation while preserving stable widths.
7. English widgets keep compact labels on one line.
```

- [ ] **Step 5: Commit verification evidence**

```bash
git add docs/review/screenshots/responsive/en-light-1100x700-dynamic-width.png docs/review/screenshots/responsive/zh-light-1100x700-dynamic-width.png
git commit -m "test: capture dynamic width visual evidence"
```

---

### Task 7: Final Review And Push

**Files:**
- Read: all modified files from previous tasks.

- [ ] **Step 1: Confirm no placeholder language slipped into the plan or review doc**

Run:

```bash
rg -n "TB[D]|TO[D]O|implement[[:space:]]later|fill[[:space:]]in[[:space:]]details|appropriate[[:space:]]error|Similar[[:space:]]to[[:space:]]Task" docs/superpowers/plans/2026-06-30-pulse-dock-dynamic-width-and-motion-polish.md docs/review/frontend-dynamic-width-motion-review.md
```

Expected: no matches.

- [ ] **Step 2: Review the diff**

Run:

```bash
git status --short
git diff --stat
git diff -- Sources/PulseDockApp/AppDelegate.swift Sources/PulseDockApp/DashboardVisualTokens.swift Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/WidgetPanelView.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/VisualFrontendGateTests.swift Tests/SharedMetricsTests/MetricFormattingTests.swift docs/data-capability-audit.md docs/review/frontend-dynamic-width-motion-review.md
```

Expected: only dynamic-width, menu bar density, stable text, docs, tests, and screenshot evidence changed.

- [ ] **Step 3: Run final verification**

Run:

```bash
swift test
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
```

Expected: pass.

- [ ] **Step 4: Push the branch**

Run:

```bash
git status --short
git push
```

Expected: clean working tree before push; branch updates on the remote.
