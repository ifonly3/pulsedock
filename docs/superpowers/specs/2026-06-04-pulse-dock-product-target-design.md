# Pulse Dock Product Target Design

## Goal

Build a self-use macOS system monitor called Pulse Dock. The product target is a native macOS app plus official WidgetKit widgets. The widgets are the primary visual selling point; the app provides the complete system information view, settings, and future App Store-ready structure.

## Visual Direction

Use the generated concept image as the current visual target:

- Left side of the macOS desktop: official WidgetKit widgets placed through the macOS widget system.
- Right side: a normal macOS app window, not a custom always-on-top floating panel.
- Style: premium translucent macOS glass, restrained dark materials, crisp Retina typography, cyan/green/amber accents, subtle charting, no marketing landing page.
- Layout density: beautiful but practical. The app should feel like a real utility people keep open while working.

## Core Product Rules

1. The desktop surface must use WidgetKit. Do not reintroduce a custom `NSPanel`, global floating window, or window that follows all spaces.
2. The app target remains a normal macOS application with a titled, resizable window.
3. Widget families should include small, medium, and large variants.
4. The main app should show fuller data than the widgets: CPU, memory, load, thermal state, battery, network, disk, running apps, GPU, and displays.
5. The widgets should show only the most glanceable data and should prioritize visual polish over density.
6. Self-use builds may use ad-hoc signing, but App Store direction requires a real Team ID, valid bundle IDs, privacy manifest review, and WidgetKit extension signing.

## Architecture

The current architecture remains the target:

- `SharedMetrics`: metric model, formatting, and public-API sampling.
- `SystemDashboardApp`: SwiftUI/AppKit macOS app shell and full dashboard.
- `SystemDashboardWidget`: WidgetKit extension with small, medium, and large layouts.
- Widget timelines sample the same shared metrics directly inside the extension.

## Data Flow

1. The app samples system metrics while running.
2. The app updates the dashboard, menu bar, persisted sanitized trend history, and periodically requests WidgetKit timeline reloads.
3. WidgetKit samples a compact snapshot inside the extension for snapshot and timeline entries.
4. Placeholder views remain visually polished but do not contain demo metric values.

## Implementation Priorities

1. Keep the official WidgetKit integration visible and reliable in the macOS widget gallery.
2. Rename and polish the visible product identity toward Pulse Dock.
3. Bring the main app UI closer to the generated concept: left navigation, denser metric cards, refined gauges, and widget previews.
4. Improve widget layouts so they look like the generated target: glass background, compact ring metrics, sparklines, and clean small/medium/large information hierarchy.
5. Keep persisted settings and sanitized trend history aligned with the App Store privacy posture.

## Verification

Before calling a build complete:

- Run `swift test`.
- Run `xcodebuild` for the macOS app and widget extension.
- Package and sign the app.
- Verify `pluginkit` lists the widget extension.
- Launch the app and confirm it is a normal app window.
- Confirm no custom floating desktop window behavior exists.
