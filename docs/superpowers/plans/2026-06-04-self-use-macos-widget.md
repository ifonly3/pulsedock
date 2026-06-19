# Self-Use macOS Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-use macOS system dashboard app with an official WidgetKit widget.

**Architecture:** Shared metric models and sampling code live in `SharedMetrics`. The macOS app shows a live SwiftUI dashboard, and the WidgetKit extension samples the same public metrics inside its own timeline provider for polished small/medium/large widgets.

**Tech Stack:** Swift 6, SwiftUI, AppKit, WidgetKit, IOKit, Mach host APIs, Xcode project targets.

---

### Task 1: Shared Metrics

**Files:**
- Move shared logic into `Sources/SharedMetrics`
- Keep widget snapshots Codable for WidgetKit timelines

- [x] Create shared model and formatting tests.
- [x] Add direct WidgetKit sampling without App Group runtime storage.
- [x] Add public macOS inventory metrics for GPU, displays, storage volumes, network interfaces, and power source details.

### Task 2: Main macOS App

**Files:**
- Create `Sources/SystemDashboardApp`

- [x] Build native SwiftUI dashboard.
- [x] Start live sampler for the dashboard and menu bar.
- [x] Notify WidgetKit from the app with throttled `WidgetCenter.reloadTimelines(ofKind:)`.
- [x] Add menu bar monitor popover.
- [x] Add sandbox-safe process fallback via `NSWorkspace`.

### Task 3: Widget Extension

**Files:**
- Create `Sources/SystemDashboardWidget`

- [x] Add WidgetKit timeline provider.
- [x] Add small, medium, and large glass-style widget layouts.
- [x] Include newly sampled interface/display summary in widget layouts.

### Task 4: Xcode Project

**Files:**
- Create `SystemDashboard.xcodeproj`
- Create entitlements and Info.plist files

- [x] Build app target.
- [x] Build widget extension target embedded in the app.
- [x] Link CoreGraphics, IOKit, and Metal in generated Xcode targets.

### Task 5: Verify

- [x] Run `swift test`.
- [x] Run `xcodebuild`.
- [x] Package and ad-hoc sign app.
- [x] Verify `pluginkit` lists widget extension.
- [x] Install the app into `~/Applications` and elect the widget extension for system use.
- [x] Launch app and check process/window.
