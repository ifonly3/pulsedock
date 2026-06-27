# Pulse Dock Visual Frontend Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add restrained, accessible visual polish to Pulse Dock without turning the monitoring dashboard or widget into a continuously animated surface.

**Architecture:** Keep motion and visual behavior in SwiftUI view code, not in `MetricsStore` or sampling code. Introduce small visual-token helpers for motion, typography, spacing, and freshness states, then migrate only the high-impact dashboard and widget components in this pass. Defer accessory widget families and full Asset Catalog color migration to separate product/design work.

**Tech Stack:** Swift 6, SwiftUI on macOS 14+, WidgetKit, Swift Testing source-level gates, existing SwiftPM + generated Xcode project workflow.

---

## 0. Review Adoption Decision

### Adopt Now

- Page/sidebar transitions and selected-state animation, scoped to view layer.
- Ring/progress value animation using `.animation(DashboardMotion.metric(reduceMotion:), value:)`.
- `accessibilityReduceMotion` handling for every new animation.
- Widget staleness/freshness indicator and Medium widget time visibility.
- High-impact accessibility labels for components still missing grouping.
- `MemorySegmentBar` width clamping to avoid visual overflow.
- Code-level visual tokens for typography, spacing, and colors.

### Adopt With Changes

- Do not wrap `MetricsStore.snapshot = nextSnapshot` in `withAnimation`; animate individual views instead.
- Do not add `TimelineView(.animation)` to the whole dashboard; continuous animation is too costly for a monitoring utility.
- Do not add repeating `.symbolEffect(.bounce/.pulse)` for alerts; use static severity plus transition feedback.
- Do not immediately migrate to Asset Catalog colors; first centralize colors in code because the project currently has no `.xcassets` and uses a custom Xcode generator.

### Defer

- `.systemExtraLarge` and accessory widget families. They need separate layouts, copy, and App Store screenshot coverage.
- Full Dynamic Type conversion across all 89 explicit font calls. This pass creates tokens and migrates critical components first.
- Full color-set Asset Catalog migration. This should follow after token usage stabilizes.

### Do Not Adopt

- Replacing sparklines with SF Symbols. Sparklines are real data visualization, not decorative icons.
- Shimmer skeleton as a primary WidgetKit experience. The provider already returns representative placeholder data.
- GeometryReader conversion for every fixed width. Fix only proven overflow points.

---

## 1. File Structure

### Files To Create

- `Sources/PulseDockApp/DashboardVisualTokens.swift`
  - Owns dashboard motion, typography, spacing, and color constants currently embedded in `DashboardView.swift`.
- `Sources/PulseDockWidget/WidgetVisualTokens.swift`
  - Owns widget color, freshness, and motion-adjacent constants currently embedded in `SystemDashboardWidget.swift`.
- `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`
  - Source-level gates for motion scoping, reduce-motion support, staleness usage, and layout clamps.

### Files To Modify

- `Sources/PulseDockApp/DashboardView.swift`
  - Remove local `DashboardColor`.
  - Add page transition, sidebar selected-state animation, ring/progress animations, accessibility labels, and memory bar clamp.
- `Sources/PulseDockApp/MetricsStore.swift`
  - No behavior changes expected. Tests must prove animation is not introduced here.
- `Sources/PulseDockWidget/SystemDashboardWidget.swift`
  - Remove local `WidgetColor` and widget color helper functions after moving them to `WidgetVisualTokens.swift`.
  - Add `SystemEntry.snapshotAge`, widget freshness tone, header freshness dot, and Medium widget time text.
- `Sources/PulseDockWidget/PulseDockWidgetStrings.swift`
  - Reuse `staleData`; add one freshness helper only if the header needs localizable visible text.

### Files Not To Touch In This Plan

- `Sources/SharedMetrics/SystemSampler.swift`
- `Sources/SharedMetrics/MetricSnapshot.swift`
- `Resources/App/*.entitlements`
- `Resources/Widget/*.entitlements`
- `scripts/generate-xcodeproj.rb`

---

## 2. Global Verification Commands

Run these after every task unless a task lists a narrower command:

```bash
swift test --filter VisualFrontendGateTests
swift build
swift build --target PulseDockWidget
scripts/audit-localization.sh
```

Expected:

```text
Build complete
Test run passed
Localization audit passed
```

When a task changes widget source, also run:

```bash
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected:

```text
** BUILD SUCCEEDED **
```

---

## Task 1: Add Visual Frontend Source Gates

**Files:**
- Create: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Write the source-level tests**

Create `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`:

```swift
import Foundation
import Testing

private func fixture(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

@Suite("VisualFrontendGateTests")
struct VisualFrontendGateTests {
    @Test func dashboardMotionIsViewScopedAndReduceMotionAware() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")
        let store = try fixture("Sources/PulseDockApp/MetricsStore.swift")

        #expect(tokens.contains("enum DashboardMotion"))
        #expect(dashboard.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(dashboard.contains(".transition("))
        #expect(dashboard.contains(".animation(DashboardMotion.page"))
        #expect(dashboard.contains(".animation(DashboardMotion.metric"))
        #expect(!store.contains("withAnimation"))
        #expect(!store.contains(".animation("))
    }

    @Test func visualTokensCentralizeDashboardTypographySpacingAndColors() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")

        #expect(tokens.contains("enum DashboardTypography"))
        #expect(tokens.contains("enum DashboardSpacing"))
        #expect(tokens.contains("enum DashboardColor"))
        #expect(tokens.contains("Font.system(.title2"))
        #expect(dashboard.contains("DashboardTypography.metricValue"))
        #expect(dashboard.contains("DashboardSpacing.md"))
        #expect(!dashboard.contains("private enum DashboardColor"))
    }

    @Test func widgetFreshnessIsVisibleAndMediumHeaderShowsTime() throws {
        let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
        let tokens = try fixture("Sources/PulseDockWidget/WidgetVisualTokens.swift")

        #expect(widget.contains("let snapshotAge: TimeInterval?"))
        #expect(widget.contains("WidgetFreshnessTone"))
        #expect(widget.contains("PulseDockWidgetStrings.staleData"))
        #expect(widget.contains("CompactWidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName"))
        #expect(widget.contains("if hasTimeReport"))
        #expect(tokens.contains("enum WidgetFreshnessTone"))
    }

    @Test func memorySegmentBarCannotForceOverflowWithTinySegments() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

        #expect(dashboard.contains("private let memorySegmentCount: CGFloat = 3"))
        #expect(dashboard.contains("let minimumVisibleWidth = min(8, totalWidth / memorySegmentCount)"))
        #expect(!dashboard.contains("return max(width, 8)"))
    }

    @Test func continuousAnimationPatternsStayOutOfThisPass() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

        #expect(!dashboard.contains("TimelineView(.animation"))
        #expect(!widget.contains("TimelineView(.animation"))
        #expect(!dashboard.contains("options: .repeating"))
        #expect(!widget.contains("options: .repeating"))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --filter VisualFrontendGateTests
```

Expected:

```text
Test dashboardMotionIsViewScopedAndReduceMotionAware() failed
Test visualTokensCentralizeDashboardTypographySpacingAndColors() failed
Test widgetFreshnessIsVisibleAndMediumHeaderShowsTime() failed
Test memorySegmentBarCannotForceOverflowWithTinySegments() failed
```

- [ ] **Step 3: Commit the failing gates**

```bash
git add Tests/SharedMetricsTests/VisualFrontendGateTests.swift
git commit -m "test: add visual frontend gates"
```

---

## Task 2: Add Dashboard Visual Tokens

**Files:**
- Create: `Sources/PulseDockApp/DashboardVisualTokens.swift`
- Modify: `Sources/PulseDockApp/DashboardView.swift:145-158`
- Test: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Create dashboard visual tokens**

Create `Sources/PulseDockApp/DashboardVisualTokens.swift`:

```swift
import SwiftUI

enum DashboardSpacing {
    static let xxs: CGFloat = 3
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum DashboardTypography {
    static let appTitle = Font.system(.title3, design: .default, weight: .semibold)
    static let pageTitle = Font.system(.title, design: .default, weight: .semibold)
    static let sectionTitle = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.system(.body, design: .default, weight: .medium)
    static let caption = Font.system(.caption, design: .default, weight: .medium)
    static let captionStrong = Font.system(.caption, design: .default, weight: .semibold)
    static let metricValue = Font.system(.title2, design: .default, weight: .semibold).monospacedDigit()
    static let compactMetricValue = Font.system(.callout, design: .default, weight: .semibold).monospacedDigit()
    static let smallMetricValue = Font.system(.caption, design: .default, weight: .semibold).monospacedDigit()
}

enum DashboardMotion {
    static func page(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    static func selection(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.16)
    }

    static func metric(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)
    }
}

enum DashboardColor {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .controlBackgroundColor).opacity(0.74)
    static let panel = Color(nsColor: .textBackgroundColor).opacity(0.78)
    static let panelAlt = Color(nsColor: .controlBackgroundColor).opacity(0.86)
    static let border = Color(nsColor: .separatorColor).opacity(0.52)
    static let muted = Color.secondary.opacity(0.74)
    static let blue = Color(red: 0.14, green: 0.43, blue: 0.95)
    static let green = Color(red: 0.04, green: 0.62, blue: 0.39)
    static let amber = Color(red: 0.93, green: 0.54, blue: 0.10)
    static let red = Color(red: 0.84, green: 0.16, blue: 0.16)
    static let purple = Color(red: 0.48, green: 0.34, blue: 0.88)
    static let cyan = Color(red: 0.04, green: 0.56, blue: 0.70)
}
```

- [ ] **Step 2: Remove the old private `DashboardColor` block**

Delete this block from `Sources/PulseDockApp/DashboardView.swift`:

```swift
private enum DashboardColor {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .controlBackgroundColor).opacity(0.74)
    static let panel = Color(nsColor: .textBackgroundColor).opacity(0.78)
    static let panelAlt = Color(nsColor: .controlBackgroundColor).opacity(0.86)
    static let border = Color(nsColor: .separatorColor).opacity(0.52)
    static let muted = Color.secondary.opacity(0.74)
    static let blue = Color(red: 0.14, green: 0.43, blue: 0.95)
    static let green = Color(red: 0.04, green: 0.62, blue: 0.39)
    static let amber = Color(red: 0.93, green: 0.54, blue: 0.10)
    static let red = Color(red: 0.84, green: 0.16, blue: 0.16)
    static let purple = Color(red: 0.48, green: 0.34, blue: 0.88)
    static let cyan = Color(red: 0.04, green: 0.56, blue: 0.70)
}
```

- [ ] **Step 3: Migrate high-impact font and spacing call sites**

In `DashboardView.swift`, update the core visible components first:

```swift
Text("Pulse Dock")
    .font(DashboardTypography.appTitle)

Text(page.title)
    .font(DashboardTypography.body.weight(isSelected ? .semibold : .medium))

Text(value)
    .font(DashboardTypography.metricValue)

VStack(spacing: DashboardSpacing.md) {
    content
}
```

Use these exact replacements in:

- `DashboardSidebar`
- `SidebarRow`
- `DashboardTopBar`
- `RingGauge`
- `TrendRow`
- `ThresholdControlRow`

- [ ] **Step 4: Run the token gate**

Run:

```bash
swift test --filter visualTokensCentralizeDashboardTypographySpacingAndColors
```

Expected:

```text
Test visualTokensCentralizeDashboardTypographySpacingAndColors() passed
```

- [ ] **Step 5: Build**

Run:

```bash
swift build
```

Expected:

```text
Build complete
```

- [ ] **Step 6: Commit**

```bash
git add Sources/PulseDockApp/DashboardVisualTokens.swift Sources/PulseDockApp/DashboardView.swift Tests/SharedMetricsTests/VisualFrontendGateTests.swift
git commit -m "style: centralize dashboard visual tokens"
```

---

## Task 3: Add Restrained Dashboard Motion

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift:15-78,249-283,1277-1307,1413-1430`
- Test: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Add reduce-motion awareness to `DashboardView`**

Modify `DashboardView`:

```swift
struct DashboardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: MetricsStore
    @ObservedObject var router: DashboardRouter

    var body: some View {
        HStack(spacing: 0) {
            DashboardSidebar(selection: $router.selectedPage, snapshot: store.snapshot)

            Divider()
                .overlay(DashboardColor.border)

            VStack(spacing: 0) {
                DashboardTopBar(page: router.selectedPage, snapshot: store.snapshot, refreshInterval: store.refreshInterval)

                GeometryReader { proxy in
                    ScrollView {
                        let isCompact = proxy.size.width < 1080
                        pageContent(
                            metricColumns: adaptiveMetricColumns(for: proxy.size.width),
                            summaryColumns: adaptiveSummaryColumns(for: proxy.size.width),
                            isCompact: isCompact
                        )
                        .id(router.selectedPage)
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .trailing)))
                        .animation(DashboardMotion.page(reduceMotion: reduceMotion), value: router.selectedPage)
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                        .padding(.bottom, 28)
                    }
                    .background(DashboardColor.canvas)
                }
            }
        }
        .frame(minWidth: 960, idealWidth: 1320, minHeight: 640, idealHeight: 860)
        .background(WindowBackdrop())
    }
}
```

- [ ] **Step 2: Add selected-state animation to `SidebarRow`**

Modify `SidebarRow`:

```swift
private struct SidebarRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let page: DashboardPage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)
                Text(page.title)
                    .font(DashboardTypography.body.weight(isSelected ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary.opacity(0.58))
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(DashboardColor.blue)
                        .frame(width: 3, height: 18)
                        .offset(x: -2)
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(DashboardMotion.selection(reduceMotion: reduceMotion), value: isSelected)
    }
}
```

- [ ] **Step 3: Animate `RingGauge` progress only**

Modify `RingGauge`:

```swift
private struct RingGauge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let value: String
    let progress: Double?
    let tint: Color

    private var clampedProgress: Double? {
        progress.flatMap(MetricScales.clampedProgress)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.14), lineWidth: 8)
            if let clampedProgress {
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(DashboardMotion.metric(reduceMotion: reduceMotion), value: clampedProgress)
            }
            VStack(spacing: 3) {
                Text(value)
                    .font(DashboardTypography.metricValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(title)
                    .font(DashboardTypography.caption)
                    .foregroundStyle(DashboardColor.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockAppStrings.notReported)
    }
}
```

- [ ] **Step 4: Animate `StatProgress` progress only**

Modify the filled capsule in `StatProgress`:

```swift
Capsule()
    .fill(tint)
    .frame(width: progressFillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 6))
    .animation(DashboardMotion.metric(reduceMotion: reduceMotion), value: progress)
```

Add the environment property at the top of `StatProgress`:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

- [ ] **Step 5: Run motion gate**

Run:

```bash
swift test --filter dashboardMotionIsViewScopedAndReduceMotionAware
```

Expected:

```text
Test dashboardMotionIsViewScopedAndReduceMotionAware() passed
```

- [ ] **Step 6: Build**

```bash
swift build
```

Expected:

```text
Build complete
```

- [ ] **Step 7: Commit**

```bash
git add Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/DashboardVisualTokens.swift Tests/SharedMetricsTests/VisualFrontendGateTests.swift
git commit -m "feat: add restrained dashboard motion"
```

---

## Task 4: Improve Dashboard Accessibility And Layout Robustness

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift:1309-1329,1489-1528,1795-1827,1830-1888`
- Test: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Add accessibility grouping to `TrendRow`**

Modify `TrendRow`:

```swift
private struct TrendRow: View {
    let title: String
    let value: String
    let tint: Color
    let values: [Double]

    var body: some View {
        HStack(spacing: DashboardSpacing.md) {
            VStack(alignment: .leading, spacing: DashboardSpacing.xxs) {
                Text(title)
                    .font(DashboardTypography.caption)
                    .foregroundStyle(DashboardColor.muted)
                Text(value)
                    .font(DashboardTypography.metricValue)
            }
            .frame(width: 96, alignment: .leading)

            Sparkline(values: values, tint: tint, fill: true)
                .frame(height: 46)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}
```

- [ ] **Step 2: Fix `MemorySegmentBar` minimum width overflow**

Modify `MemorySegmentBar`:

```swift
private struct MemorySegmentBar: View {
    private let memorySegmentCount: CGFloat = 3
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardSpacing.sm) {
            if snapshot.hasMemoryUsageReport && snapshot.hasMemoryCompositionReport {
                GeometryReader { proxy in
                    let availableWidth = max(proxy.size.width - 4, 0)
                    HStack(spacing: 2) {
                        segment(snapshot.memoryUsedBytes, color: DashboardColor.blue, in: availableWidth)
                        segment(snapshot.memoryCachedBytes, color: DashboardColor.cyan, in: availableWidth)
                        segment(snapshot.memoryFreeBytes, color: Color.secondary.opacity(0.20), in: availableWidth)
                    }
                }
                .frame(height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 16)
            }

            HStack(spacing: 10) {
                LegendDot(title: PulseDockAppStrings.memoryUsedTitle, color: DashboardColor.blue)
                LegendDot(title: PulseDockAppStrings.memoryCachedLabel, color: DashboardColor.cyan)
                LegendDot(title: PulseDockAppStrings.memoryFreeLabel, color: Color.secondary.opacity(0.38))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(PulseDockAppStrings.metricMemory), \(snapshot.memoryUsageText)")
    }

    private func segment(_ bytes: UInt64, color: Color, in totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: segmentWidth(bytes, in: totalWidth))
    }

    private func segmentWidth(_ bytes: UInt64, in totalWidth: CGFloat) -> CGFloat {
        guard totalWidth > 0 else { return 0 }
        let width = CGFloat(normalizedBytes(bytes, total: snapshot.memoryTotalBytes)) * totalWidth
        let minimumVisibleWidth = min(8, totalWidth / memorySegmentCount)
        return min(max(width, minimumVisibleWidth), totalWidth)
    }
}
```

- [ ] **Step 3: Add accessibility to `ThresholdControlRow`**

Modify `ThresholdControlRow`:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title), \(MetricFormatting.percentage(displayedValue))")
```

Place the modifiers after the background:

```swift
.padding(12)
.background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title), \(MetricFormatting.percentage(displayedValue))")
```

- [ ] **Step 4: Run layout and accessibility gates**

Run:

```bash
swift test --filter memorySegmentBarCannotForceOverflowWithTinySegments
swift test --filter visualTokensCentralizeDashboardTypographySpacingAndColors
```

Expected:

```text
Test memorySegmentBarCannotForceOverflowWithTinySegments() passed
Test visualTokensCentralizeDashboardTypographySpacingAndColors() passed
```

- [ ] **Step 5: Build**

```bash
swift build
```

Expected:

```text
Build complete
```

- [ ] **Step 6: Commit**

```bash
git add Sources/PulseDockApp/DashboardView.swift Tests/SharedMetricsTests/VisualFrontendGateTests.swift
git commit -m "fix: improve dashboard visual accessibility"
```

---

## Task 5: Add Widget Visual Tokens And Freshness State

**Files:**
- Create: `Sources/PulseDockWidget/WidgetVisualTokens.swift`
- Modify: `Sources/PulseDockWidget/SystemDashboardWidget.swift:33-59,108-124,449-506,639-715`
- Test: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Create widget visual tokens**

Create `Sources/PulseDockWidget/WidgetVisualTokens.swift`:

```swift
import SwiftUI

enum WidgetFreshnessTone {
    case fresh
    case aging
    case stale

    static func resolve(age: TimeInterval?) -> WidgetFreshnessTone {
        guard let age, age >= 0 else { return .fresh }
        if age >= 600 { return .stale }
        if age >= 300 { return .aging }
        return .fresh
    }

    func color(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .fresh:
            WidgetColor.green(for: colorScheme)
        case .aging:
            WidgetColor.amber(for: colorScheme)
        case .stale:
            WidgetColor.red(for: colorScheme)
        }
    }

    var accessibilityText: String {
        switch self {
        case .fresh:
            return PulseDockWidgetStrings.widgetDisplayName
        case .aging, .stale:
            return PulseDockWidgetStrings.staleData
        }
    }
}

enum WidgetColor {
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
        colorScheme == .dark ? Color(red: 1.00, green: 0.38, blue: 0.36) : Color(red: 0.84, green: 0.16, blue: 0.16)
    }
}

func widgetBackgroundColors(for colorScheme: ColorScheme) -> [Color] {
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

func widgetPanelFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.40)
}

func widgetPanelStroke(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.58)
}

func widgetPrimaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary
}

func widgetSecondaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.62) : Color.secondary
}

func widgetTrackFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.14) : Color.secondary.opacity(0.14)
}

func widgetPlaceholderFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.16) : Color.secondary.opacity(0.16)
}
```

- [ ] **Step 2: Add snapshot age to `SystemEntry`**

Modify `SystemEntry`:

```swift
struct SystemEntry: TimelineEntry {
    let date: Date
    let snapshot: MetricSnapshot?
    let snapshotAge: TimeInterval?

    var freshnessTone: WidgetFreshnessTone {
        WidgetFreshnessTone.resolve(age: snapshotAge)
    }
}
```

Update entry creation:

```swift
func placeholder(in context: Context) -> SystemEntry {
    let snapshot = Self.representativeSnapshot()
    return SystemEntry(date: Date(), snapshot: snapshot, snapshotAge: 0)
}

func getSnapshot(in context: Context, completion: @escaping (SystemEntry) -> Void) {
    let snapshot = Self.representativeSnapshot()
    completion(SystemEntry(date: Date(), snapshot: snapshot, snapshotAge: 0))
}

func getTimeline(in context: Context, completion: @escaping (Timeline<SystemEntry>) -> Void) {
    let timelineCompletion = TimelineCompletion(completion: completion)
    DispatchQueue.global(qos: .utility).async {
        let now = Date()
        let snapshot = Self.sampledSnapshotForTimeline(now: now)
        let age = snapshot.map { now.timeIntervalSince($0.timestamp) }
        let entry = SystemEntry(date: now, snapshot: snapshot, snapshotAge: age)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        timelineCompletion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
```

- [ ] **Step 3: Pass freshness tone into widget views**

Modify `SystemDashboardWidgetView`:

```swift
struct SystemDashboardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SystemEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall:
                SmallWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone)
            case .systemMedium:
                MediumWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone)
            case .systemLarge:
                LargeWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone)
            default:
                SmallWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone)
            }
        } else {
            EmptyDataWidget(family: family)
        }
    }
}
```

Add `let freshnessTone: WidgetFreshnessTone` to `SmallWidget`, `MediumWidget`, and `LargeWidget`.

- [ ] **Step 4: Make header freshness visible**

Modify `WidgetHeader`:

```swift
private struct WidgetHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let timeText: String
    let hasTimeReport: Bool
    let freshnessTone: WidgetFreshnessTone

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetColor.green(for: colorScheme))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
                .lineLimit(1)
            Circle()
                .fill(freshnessTone.color(for: colorScheme))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Spacer()
            if hasTimeReport {
                Text(timeText)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(widgetSecondaryText(for: colorScheme))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasTimeReport ? "\(title), \(timeText), \(freshnessTone.accessibilityText)" : "\(title), \(freshnessTone.accessibilityText)")
    }
}
```

Modify `CompactWidgetHeader` so Medium displays time:

```swift
private struct CompactWidgetHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let timeText: String
    let hasTimeReport: Bool
    let freshnessTone: WidgetFreshnessTone

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetColor.green(for: colorScheme))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
            Circle()
                .fill(freshnessTone.color(for: colorScheme))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Spacer(minLength: 4)
            if hasTimeReport {
                Text(timeText)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(widgetSecondaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasTimeReport ? "\(title), \(timeText), \(freshnessTone.accessibilityText)" : "\(title), \(freshnessTone.accessibilityText)")
    }
}
```

- [ ] **Step 5: Update header call sites**

Use localized display name in small and medium:

```swift
WidgetHeader(
    title: PulseDockWidgetStrings.widgetDisplayName,
    timeText: snapshot.sampleClockText,
    hasTimeReport: snapshot.hasSampleTimeReport,
    freshnessTone: freshnessTone
)
```

```swift
CompactWidgetHeader(
    title: PulseDockWidgetStrings.widgetDisplayName,
    timeText: snapshot.sampleClockText,
    hasTimeReport: snapshot.hasSampleTimeReport,
    freshnessTone: freshnessTone
)
```

Use existing title in large:

```swift
WidgetHeader(
    title: PulseDockWidgetStrings.headerSystemStatus,
    timeText: snapshot.sampleClockText,
    hasTimeReport: snapshot.hasSampleTimeReport,
    freshnessTone: freshnessTone
)
```

- [ ] **Step 6: Remove duplicate widget color helpers**

Delete these definitions from `SystemDashboardWidget.swift` after `WidgetVisualTokens.swift` compiles:

- `private func widgetBackgroundColors(for colorScheme: ColorScheme) -> [Color]`
- `private func widgetPanelFill(for colorScheme: ColorScheme) -> Color`
- `private func widgetPanelStroke(for colorScheme: ColorScheme) -> Color`
- `private func widgetPrimaryText(for colorScheme: ColorScheme) -> Color`
- `private func widgetSecondaryText(for colorScheme: ColorScheme) -> Color`
- `private func widgetTrackFill(for colorScheme: ColorScheme) -> Color`
- `private func widgetPlaceholderFill(for colorScheme: ColorScheme) -> Color`
- `private enum WidgetColor`

- [ ] **Step 7: Run widget freshness gate**

```bash
swift test --filter widgetFreshnessIsVisibleAndMediumHeaderShowsTime
swift build --target PulseDockWidget
```

Expected:

```text
Test widgetFreshnessIsVisibleAndMediumHeaderShowsTime() passed
Build complete
```

- [ ] **Step 8: Run Xcode compile-only build**

```bash
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected:

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 9: Commit**

```bash
git add Sources/PulseDockWidget/WidgetVisualTokens.swift Sources/PulseDockWidget/SystemDashboardWidget.swift Tests/SharedMetricsTests/VisualFrontendGateTests.swift PulseDock.xcodeproj/project.pbxproj
git commit -m "feat: show widget data freshness"
```

---

## Task 6: Prove Continuous Animation Was Not Introduced

**Files:**
- Modify: `Tests/SharedMetricsTests/VisualFrontendGateTests.swift`

- [ ] **Step 1: Run the continuous-animation guard**

```bash
swift test --filter continuousAnimationPatternsStayOutOfThisPass
```

Expected:

```text
Test continuousAnimationPatternsStayOutOfThisPass() passed
```

- [ ] **Step 2: Run full SwiftPM verification**

```bash
swift build
swift build --target PulseDockWidget
swift test
scripts/audit-localization.sh
```

Expected:

```text
Build complete
Test run passed
Localization audit passed
```

- [ ] **Step 3: Commit verification-only test adjustments if needed**

Only run this commit if Step 1 required a test edit:

```bash
git add Tests/SharedMetricsTests/VisualFrontendGateTests.swift
git commit -m "test: guard visual motion scope"
```

If Step 1 and Step 2 passed without edits, do not create a commit for this task.

---

## Task 7: Manual Visual QA

**Files:**
- No source changes expected.

- [ ] **Step 1: Build and run the app**

```bash
swift build
```

Expected:

```text
Build complete
```

Launch the app using the existing app build/run workflow for this project. If using the generated Xcode project, run:

```bash
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Debug -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
open ".build/xcode-derived/Build/Products/Debug/Pulse Dock.app"
```

- [ ] **Step 2: Verify dashboard motion**

Manual checks:

- Sidebar selection moves between pages with a subtle fade/move transition.
- Ring and progress bars animate value changes without animating the full page.
- No repeating alert bounce or pulse exists.
- Page switching still feels fast at 1s refresh interval.

- [ ] **Step 3: Verify Reduce Motion**

System Settings:

1. Open Accessibility.
2. Enable Reduce Motion.
3. Reopen Pulse Dock.
4. Switch pages and wait for metrics to refresh.

Expected:

- Page changes are immediate or nearly immediate.
- Progress values update without spring motion.
- Layout remains stable.

- [ ] **Step 4: Verify light and dark appearances**

Manual checks:

- Light mode background keeps contrast in all pages.
- Dark mode does not collapse into a one-note blue/green palette.
- Widget preview remains readable with freshness dot visible.

- [ ] **Step 5: Verify widget timeline rendering**

Run:

```bash
swift build --target PulseDockWidget
```

Expected:

```text
Build complete
```

Manual checks:

- Small widget shows Pulse Dock title and freshness dot.
- Medium widget shows title, freshness dot, and timestamp.
- Large widget shows system status title, freshness dot, and timestamp.
- Placeholder/gallery preview uses representative data.

- [ ] **Step 6: Commit any QA fixes**

If manual QA led to source changes:

```bash
git add Sources/PulseDockApp Sources/PulseDockWidget Tests/SharedMetricsTests/VisualFrontendGateTests.swift
git commit -m "fix: polish visual frontend qa issues"
```

If manual QA passed without edits, do not create a commit for this task.

---

## Final Verification

Run:

```bash
git diff --check
swift build
swift build --target PulseDockWidget
swift test
scripts/audit-localization.sh
scripts/validate-public-pages.sh
scripts/generate-xcodeproj.rb
xcodebuild -project PulseDock.xcodeproj -scheme PulseDock -configuration Release -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected:

```text
Build complete
Test run passed
Localization audit passed
Public page validation passed
** BUILD SUCCEEDED **
```

Screenshot validation is not part of this visual-code plan because English App Store screenshots are a separate release asset gate.

---

## Commit Boundaries

1. `test: add visual frontend gates`
2. `style: centralize dashboard visual tokens`
3. `feat: add restrained dashboard motion`
4. `fix: improve dashboard visual accessibility`
5. `feat: show widget data freshness`
6. `test: guard visual motion scope` only if the test file changes in Task 6
7. `fix: polish visual frontend qa issues` only if manual QA finds defects

---

## Out Of Scope For This Plan

- Accessory widget families: `.accessoryInline`, `.accessoryCircular`, `.accessoryRectangular`.
- `.systemExtraLarge` widget layout.
- Asset Catalog color-set migration.
- Full DashboardView file split.
- Replacing Canvas sparklines with SF Symbols.
- Continuous `TimelineView(.animation)` dashboard effects.
- Repeating `.symbolEffect` alert animation.
