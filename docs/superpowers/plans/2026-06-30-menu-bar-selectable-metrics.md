# Menu Bar Selectable Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users choose which live metric appears beside the Pulse Dock menu bar icon: icon only, CPU, network throughput, memory, or battery.

**Architecture:** Replace the current boolean `showsMenuBarCPU` preference with a small persisted `MenuBarMetricOption` enum owned by `MetricsStore`, while preserving the old boolean key as a one-time compatibility fallback. `AppDelegate` renders the selected metric from the current `MetricSnapshot`; `SettingsPage` exposes the choice with a menu picker to avoid crowded English labels.

**Tech Stack:** macOS SwiftUI, AppKit `NSStatusItem`, Combine, Swift Testing source-level gates, localized `.strings` / `.xcstrings` resources.

---

## Scope

This plan only adds selectable status bar metrics. It does not add disk I/O sampling, does not change widget content, and does not change the menu bar popover layout.

Supported first version options:

| Option | Menu bar output | Data source | Fallback |
| --- | --- | --- | --- |
| Icon Only | no text | none | always available |
| CPU | `25%` | `MetricSnapshot.cpuText` | icon only if CPU is not reported |
| Network | `4 Kbps` / `1.2 MB/s` | `MetricSnapshot.networkText` | icon only if network counters are not reported |
| Memory | `54%` | `MetricSnapshot.memoryUsageText` | icon only if memory capacity is not reported |
| Battery | `98%` or power status text | `MetricSnapshot.powerStatusText` | icon only if power status is not reported |

Network intentionally uses total throughput only. Directional text (`networkInText` / `networkOutText`) is useful in the popover but too wide for a status item.

## File Structure

- Modify: `Sources/PulseDockApp/MetricsStore.swift`
  - Add `MenuBarMetricOption`.
  - Add persisted `menuBarMetric`.
  - Keep `DefaultsKeys.showsMenuBarCPU` only as a migration fallback.
- Modify: `Sources/PulseDockApp/AppDelegate.swift`
  - Subscribe to `store.$menuBarMetric`.
  - Render status item text from the selected option.
  - Replace fixed CPU width with bounded dynamic width.
- Modify: `Sources/PulseDockApp/DashboardView.swift`
  - Replace the menu bar CPU toggle with a menu-style picker.
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
  - Add picker labels and update the menu bar setting detail.
- Modify: `Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings`
  - Add English strings.
- Modify: `Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings`
  - Add Simplified Chinese strings.
- Modify: `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`
  - Mirror the same localization keys for Xcode resource generation.
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
  - Replace the old CPU-toggle source gate with selectable metric source gates.
- Modify: `Tests/SharedMetricsTests/LocalizationGateTests.swift`
  - Add localization expectations for the new setting labels.

## Task 1: Add Source-Level Gates For The New Contract

**Files:**
- Modify: `Tests/SharedMetricsTests/MetricFormattingTests.swift`
- Modify: `Tests/SharedMetricsTests/LocalizationGateTests.swift`

- [ ] **Step 1: Replace the old status bar CPU toggle test**

In `Tests/SharedMetricsTests/MetricFormattingTests.swift`, replace `menuBarCPUDisplayCanBeToggledAndPersisted()` with:

```swift
@Test func menuBarMetricSelectionCanBeConfiguredAndPersisted() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("enum MenuBarMetricOption: String, CaseIterable, Identifiable"))
    #expect(metricsStore.contains("static let menuBarMetric = \"dashboard.menuBar.metric\""))
    #expect(metricsStore.contains("static let showsMenuBarCPU = \"dashboard.menuBar.showsCPU\""))
    #expect(metricsStore.contains("@Published private(set) var menuBarMetric: MenuBarMetricOption"))
    #expect(metricsStore.contains("private static func savedMenuBarMetric(_ defaults: UserDefaults) -> MenuBarMetricOption"))
    #expect(metricsStore.contains("func updateMenuBarMetric(_ option: MenuBarMetricOption)"))
    #expect(metricsStore.contains("defaults.set(option.rawValue, forKey: DefaultsKeys.menuBarMetric)"))
    #expect(metricsStore.contains("defaults.set(option != .iconOnly, forKey: DefaultsKeys.showsMenuBarCPU)"))

    #expect(dashboardView.contains("@State private var draftMenuBarMetric: MenuBarMetricOption?"))
    #expect(dashboardView.contains("Picker(PulseDockAppStrings.settingsMenuBarStatusTitle, selection: Binding("))
    #expect(dashboardView.contains("draftMenuBarMetric ?? store.menuBarMetric"))
    #expect(dashboardView.contains("store.updateMenuBarMetric(value)"))
    #expect(dashboardView.contains("ForEach(MenuBarMetricOption.allCases)"))
    #expect(dashboardView.contains(".pickerStyle(.menu)"))
    #expect(!dashboardView.contains("Toggle(PulseDockAppStrings.settingsMenuBarCPULabel"))

    #expect(appDelegate.contains("store.$snapshot.combineLatest(store.$menuBarMetric)"))
    #expect(appDelegate.contains("private func statusButtonMetricText(for option: MenuBarMetricOption) -> String?"))
    #expect(appDelegate.contains("case .network:"))
    #expect(appDelegate.contains("store.snapshot.networkText"))
    #expect(appDelegate.contains("case .memory:"))
    #expect(appDelegate.contains("store.snapshot.memoryUsageText"))
    #expect(appDelegate.contains("case .battery:"))
    #expect(appDelegate.contains("store.snapshot.powerStatusText"))
    #expect(appDelegate.contains("MenuBarStatusItemLayout.titleLength(for: metricText)"))
}
```

- [ ] **Step 2: Update localization gate expectations**

In `Tests/SharedMetricsTests/LocalizationGateTests.swift`, replace the old `settingsMenuBarCPULabel` entry with the new labels:

```swift
(symbol: "settingsMenuBarStatusTitle", key: "app.settings.menu_bar_status.title", english: "Menu Bar Status", chinese: "菜单栏状态"),
(symbol: "settingsMenuBarStatusDetail", key: "app.settings.menu_bar_status.detail", english: "Choose the metric shown beside the menu bar icon", chinese: "选择菜单栏图标旁显示的指标"),
(symbol: "settingsMenuBarMetricIconOnlyLabel", key: "app.settings.menu_bar_metric.icon_only", english: "Icon Only", chinese: "仅图标"),
(symbol: "settingsMenuBarMetricCPULabel", key: "app.settings.menu_bar_metric.cpu", english: "CPU", chinese: "CPU"),
(symbol: "settingsMenuBarMetricNetworkLabel", key: "app.settings.menu_bar_metric.network", english: "Network", chinese: "网络"),
(symbol: "settingsMenuBarMetricMemoryLabel", key: "app.settings.menu_bar_metric.memory", english: "Memory", chinese: "内存"),
(symbol: "settingsMenuBarMetricBatteryLabel", key: "app.settings.menu_bar_metric.battery", english: "Battery", chinese: "电池"),
```

- [ ] **Step 3: Run the focused failing tests**

Run:

```bash
swift test --filter menuBarMetricSelectionCanBeConfiguredAndPersisted
swift test --filter dashboardSettingsStringsUsePulseDockAppLocalizationResources
```

Expected:
- `menuBarMetricSelectionCanBeConfiguredAndPersisted` fails because the enum, picker, and AppDelegate switch do not exist yet.
- The localization gate fails until the new string symbols and resources are added.

- [ ] **Step 4: Commit the red tests**

```bash
git add Tests/SharedMetricsTests/MetricFormattingTests.swift Tests/SharedMetricsTests/LocalizationGateTests.swift
git commit -m "test: cover selectable menu bar metrics"
```

## Task 2: Add MenuBarMetricOption And Preference Migration

**Files:**
- Modify: `Sources/PulseDockApp/MetricsStore.swift`

- [ ] **Step 1: Add the enum near `RefreshIntervalOption`**

Insert after `HistoryDepthOption`:

```swift
enum MenuBarMetricOption: String, CaseIterable, Identifiable {
    case iconOnly
    case cpu
    case network
    case memory
    case battery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iconOnly: return PulseDockAppStrings.settingsMenuBarMetricIconOnlyLabel
        case .cpu: return PulseDockAppStrings.settingsMenuBarMetricCPULabel
        case .network: return PulseDockAppStrings.settingsMenuBarMetricNetworkLabel
        case .memory: return PulseDockAppStrings.settingsMenuBarMetricMemoryLabel
        case .battery: return PulseDockAppStrings.settingsMenuBarMetricBatteryLabel
        }
    }
}
```

- [ ] **Step 2: Add the new defaults key and keep the legacy key**

Update `DefaultsKeys`:

```swift
private enum DefaultsKeys {
    static let refreshInterval = "dashboard.refreshInterval"
    static let historyDepth = "dashboard.historyDepth"
    static let cpuAlertThreshold = "dashboard.alertThreshold.cpu"
    static let memoryAlertThreshold = "dashboard.alertThreshold.memory"
    static let diskAlertThreshold = "dashboard.alertThreshold.disk"
    static let menuBarMetric = "dashboard.menuBar.metric"
    static let showsMenuBarCPU = "dashboard.menuBar.showsCPU"
    static let historySnapshots = "dashboard.historySnapshots"
}
```

- [ ] **Step 3: Replace the published boolean with the enum**

Replace:

```swift
@Published private(set) var showsMenuBarCPU: Bool
```

with:

```swift
@Published private(set) var menuBarMetric: MenuBarMetricOption
```

- [ ] **Step 4: Load the saved option in `init`**

Replace the existing `showsMenuBarCPU` initialization:

```swift
self.showsMenuBarCPU = defaults.object(forKey: DefaultsKeys.showsMenuBarCPU) == nil
    ? true
    : defaults.bool(forKey: DefaultsKeys.showsMenuBarCPU)
```

with:

```swift
self.menuBarMetric = Self.savedMenuBarMetric(defaults)
```

- [ ] **Step 5: Add the migration helper**

Insert near `savedThreshold`:

```swift
private static func savedMenuBarMetric(_ defaults: UserDefaults) -> MenuBarMetricOption {
    if let rawValue = defaults.string(forKey: DefaultsKeys.menuBarMetric),
       let option = MenuBarMetricOption(rawValue: rawValue) {
        return option
    }

    guard defaults.object(forKey: DefaultsKeys.showsMenuBarCPU) != nil else {
        return .cpu
    }

    return defaults.bool(forKey: DefaultsKeys.showsMenuBarCPU) ? .cpu : .iconOnly
}
```

- [ ] **Step 6: Replace the update method**

Replace `updateShowsMenuBarCPU(_:)` with:

```swift
func updateMenuBarMetric(_ option: MenuBarMetricOption) {
    guard menuBarMetric != option else { return }

    menuBarMetric = option
    defaults.set(option.rawValue, forKey: DefaultsKeys.menuBarMetric)
    defaults.set(option != .iconOnly, forKey: DefaultsKeys.showsMenuBarCPU)
}
```

The legacy boolean write keeps downgrade behavior predictable during local testing.

- [ ] **Step 7: Run focused test**

Run:

```bash
swift test --filter menuBarMetricSelectionCanBeConfiguredAndPersisted
```

Expected: still fails because AppDelegate and SettingsPage are not updated yet.

- [ ] **Step 8: Commit store changes**

```bash
git add Sources/PulseDockApp/MetricsStore.swift
git commit -m "feat: add menu bar metric preference"
```

## Task 3: Render The Selected Metric In AppDelegate

**Files:**
- Modify: `Sources/PulseDockApp/AppDelegate.swift`

- [ ] **Step 1: Replace fixed CPU width with bounded dynamic width**

Replace `MenuBarStatusItemLayout` with:

```swift
private enum MenuBarStatusItemLayout {
    static let compactLength = NSStatusItem.squareLength

    static func titleLength(for text: String) -> CGFloat {
        let characterWidth: CGFloat = 8.5
        let horizontalPadding: CGFloat = 34
        let measured = CGFloat(max(text.count, 3)) * characterWidth + horizontalPadding
        return min(max(measured, 68), 118)
    }
}
```

- [ ] **Step 2: Subscribe to the selected metric**

Replace:

```swift
store.$snapshot.combineLatest(store.$showsMenuBarCPU)
```

with:

```swift
store.$snapshot.combineLatest(store.$menuBarMetric)
```

- [ ] **Step 3: Replace CPU-only text helpers**

Replace `statusButtonCPUText` and `updateStatusButtonTitle()` with:

```swift
private func statusButtonText(_ text: String, isReported: Bool) -> String? {
    guard isReported else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != PulseDockAppStrings.notReported else { return nil }
    return trimmed
}

private func statusButtonMetricText(for option: MenuBarMetricOption) -> String? {
    switch option {
    case .iconOnly:
        return nil
    case .cpu:
        return statusButtonText(store.snapshot.cpuText, isReported: store.snapshot.hasCPUUsageReport)
    case .network:
        return statusButtonText(store.snapshot.networkText, isReported: store.snapshot.hasNetworkByteCounters)
    case .memory:
        return statusButtonText(store.snapshot.memoryUsageText, isReported: store.snapshot.hasMemoryUsageReport)
    case .battery:
        return statusButtonText(store.snapshot.powerStatusText, isReported: store.snapshot.hasPowerStatusReport)
    }
}

private func updateStatusButtonTitle() {
    guard let metricText = statusButtonMetricText(for: store.menuBarMetric) else {
        statusItem?.length = MenuBarStatusItemLayout.compactLength
        statusItem?.button?.title = ""
        return
    }

    statusItem?.length = MenuBarStatusItemLayout.titleLength(for: metricText)
    statusItem?.button?.title = " \(metricText)"
}
```

- [ ] **Step 4: Run focused test**

Run:

```bash
swift test --filter menuBarMetricSelectionCanBeConfiguredAndPersisted
```

Expected: still fails until SettingsPage uses `menuBarMetric`.

- [ ] **Step 5: Commit AppDelegate changes**

```bash
git add Sources/PulseDockApp/AppDelegate.swift
git commit -m "feat: render selected menu bar metric"
```

## Task 4: Add Settings UI And Localized Labels

**Files:**
- Modify: `Sources/PulseDockApp/DashboardView.swift`
- Modify: `Sources/PulseDockApp/PulseDockAppStrings.swift`
- Modify: `Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings`
- Modify: `Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings`
- Modify: `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings`

- [ ] **Step 1: Add draft state to `SettingsPage`**

Change:

```swift
@State private var draftRefreshInterval: RefreshIntervalOption?
```

to:

```swift
@State private var draftRefreshInterval: RefreshIntervalOption?
@State private var draftMenuBarMetric: MenuBarMetricOption?
```

- [ ] **Step 2: Replace the toggle with a menu picker**

Replace the `SettingControlRow` body for `settingsMenuBarStatusTitle` with:

```swift
SettingControlRow(title: PulseDockAppStrings.settingsMenuBarStatusTitle, detail: PulseDockAppStrings.settingsMenuBarStatusDetail) {
    Picker(PulseDockAppStrings.settingsMenuBarStatusTitle, selection: Binding(
        get: { draftMenuBarMetric ?? store.menuBarMetric },
        set: { draftMenuBarMetric = $0 }
    )) {
        ForEach(MenuBarMetricOption.allCases) { option in
            Text(option.label).tag(option)
        }
    }
    .onChange(of: draftMenuBarMetric) { _, value in
        guard let value else { return }
        store.updateMenuBarMetric(value)
        draftMenuBarMetric = nil
    }
    .labelsHidden()
    .pickerStyle(.menu)
    .frame(width: 156)
}
```

- [ ] **Step 3: Add string accessors**

In `PulseDockAppStrings.swift`, update `settingsMenuBarStatusDetail` and replace `settingsMenuBarCPULabel` with:

```swift
static var settingsMenuBarStatusDetail: String {
    localized("app.settings.menu_bar_status.detail", defaultValue: "Choose the metric shown beside the menu bar icon")
}

static var settingsMenuBarMetricIconOnlyLabel: String {
    localized("app.settings.menu_bar_metric.icon_only", defaultValue: "Icon Only")
}

static var settingsMenuBarMetricCPULabel: String {
    localized("app.settings.menu_bar_metric.cpu", defaultValue: "CPU")
}

static var settingsMenuBarMetricNetworkLabel: String {
    localized("app.settings.menu_bar_metric.network", defaultValue: "Network")
}

static var settingsMenuBarMetricMemoryLabel: String {
    localized("app.settings.menu_bar_metric.memory", defaultValue: "Memory")
}

static var settingsMenuBarMetricBatteryLabel: String {
    localized("app.settings.menu_bar_metric.battery", defaultValue: "Battery")
}
```

- [ ] **Step 4: Update `.strings` resources**

In `Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings`, replace the old menu bar CPU setting lines with:

```text
"app.settings.menu_bar_metric.battery" = "Battery";
"app.settings.menu_bar_metric.cpu" = "CPU";
"app.settings.menu_bar_metric.icon_only" = "Icon Only";
"app.settings.menu_bar_metric.memory" = "Memory";
"app.settings.menu_bar_metric.network" = "Network";
"app.settings.menu_bar_status.detail" = "Choose the metric shown beside the menu bar icon";
"app.settings.menu_bar_status.title" = "Menu Bar Status";
```

In `Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings`, use:

```text
"app.settings.menu_bar_metric.battery" = "电池";
"app.settings.menu_bar_metric.cpu" = "CPU";
"app.settings.menu_bar_metric.icon_only" = "仅图标";
"app.settings.menu_bar_metric.memory" = "内存";
"app.settings.menu_bar_metric.network" = "网络";
"app.settings.menu_bar_status.detail" = "选择菜单栏图标旁显示的指标";
"app.settings.menu_bar_status.title" = "菜单栏状态";
```

- [ ] **Step 5: Mirror the keys in `PulseDockApp.xcstrings`**

Add matching entries to `Sources/PulseDockApp/Resources/PulseDockApp.xcstrings` using the existing JSON shape. For each new key, include both `en` and `zh-Hans` localizations. Remove `app.settings.menu_bar_cpu.label` if no source file references it after the Swift update.

- [ ] **Step 6: Run localization audit and focused tests**

Run:

```bash
scripts/audit-localization.sh
swift test --filter menuBarMetricSelectionCanBeConfiguredAndPersisted
swift test --filter dashboardSettingsStringsUsePulseDockAppLocalizationResources
```

Expected: all three commands pass.

- [ ] **Step 7: Commit UI and localization changes**

```bash
git add Sources/PulseDockApp/DashboardView.swift Sources/PulseDockApp/PulseDockAppStrings.swift Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings Sources/PulseDockApp/Resources/PulseDockApp.xcstrings
git commit -m "feat: expose menu bar metric setting"
```

## Task 5: Full Verification And Manual Smoke Test

**Files:**
- No planned code edits.

- [ ] **Step 1: Run the full automated suite**

```bash
swift build
swift test
scripts/audit-localization.sh
```

Expected:
- `swift build` succeeds.
- `swift test` succeeds.
- Localization audit reports no Chinese text in Swift sources.

- [ ] **Step 2: Regenerate Xcode project if resources changed**

Run:

```bash
ruby scripts/generate-xcodeproj.rb
```

Expected: `PulseDock.xcodeproj` is regenerated without errors and includes the updated localization resources.

- [ ] **Step 3: Build and run the app locally**

Use the existing macOS workflow:

```bash
swift run PulseDockApp
```

If this project is currently being run through the generated Xcode project instead, build and run the app target from `PulseDock.xcodeproj`.

- [ ] **Step 4: Manual checks**

1. Open Settings.
2. Confirm the menu bar setting shows a picker with: Icon Only, CPU, Network, Memory, Battery.
3. Select CPU and confirm the status item shows a percentage.
4. Select Network and confirm the status item shows total throughput without wrapping or excessive menu bar width.
5. Select Memory and confirm the status item shows a percentage.
6. Select Battery and confirm the status item shows battery percentage or power status.
7. Select Icon Only and confirm text disappears but the Pulse Dock icon remains clickable.
8. Quit and relaunch the app; confirm the selected option persists.

- [ ] **Step 5: Commit generated project changes if any**

```bash
git status --short
git add PulseDock.xcodeproj
git commit -m "chore: regenerate project for menu bar metric strings"
```

Only run the commit if `git status --short` shows project changes from the generator.

## Acceptance Criteria

- Users can choose menu bar output from Settings without editing defaults manually.
- Existing users with no saved preference continue to see CPU text by default.
- Existing users who previously disabled menu bar CPU migrate to Icon Only.
- The status item never displays `Not Reported`; it falls back to icon-only when the selected data source is unavailable.
- Network status item text uses total throughput, not directional detail.
- English and Simplified Chinese settings labels are complete.
- `swift build`, `swift test`, and `scripts/audit-localization.sh` pass.

## Rollback Plan

If the feature causes status bar layout regressions:

1. Keep `MenuBarMetricOption` and persistence in place.
2. Temporarily force `statusButtonMetricText(for:)` to return CPU for all non-`.iconOnly` cases.
3. Ship a follow-up patch that tunes `MenuBarStatusItemLayout.titleLength(for:)`.

This preserves user settings and avoids another preference migration.

## Future Follow-Ups

- Add disk I/O as a sixth option only after disk read/write sampling has a verified App Store-safe implementation.
- Consider an optional compact network formatter if users prefer directional text, for example `↓1.2M ↑80K`.
- Add a menu bar tooltip such as `Pulse Dock: Network 4 Kbps` if users need a label for terse status item values.
