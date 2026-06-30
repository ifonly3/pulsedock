# Frontend Responsive Design Review

Date: 2026-06-30
Scope: Pulse Dock main window, settings, menu bar status item, popover, and widgets.

## Review Matrix

| Surface | Size | Language | Appearance | Result | Screenshot | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Dashboard Overview | 960x640 | en | Light | Source Fixed | docs/review/screenshots/responsive/en-light-960x640-overview.png | `DashboardTopBar` now owns the full-width header band; screenshot follow-up can confirm pixels. |
| Dashboard Overview | 1100x700 | en | Light | Pass | docs/review/screenshots/responsive/en-light-1100x700-current.png | Captured after fix; the header band spans the full main content width. |
| Dashboard Overview | 1200x760 | en | Light | Pending | docs/review/screenshots/responsive/en-light-1200x760-overview.png | Intermediate width check after top-bar repair. |
| Dashboard Overview | 1320x860 | en | Light | Pending | docs/review/screenshots/responsive/en-light-1320x860-overview.png | Confirm regular density and alignment. |
| Dashboard CPU | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-cpu.png | Check chart, load rows, and bottom details. |
| Dashboard GPU / Displays | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-gpu.png | Check long table values and display-mode columns. |
| Dashboard Memory | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-memory.png | Check ring, composition bar, and key-value grid. |
| Dashboard Storage | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-storage.png | Check capacity hero and volume table. |
| Dashboard Network | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-network.png | Check metric cards and interface table. |
| Dashboard Power | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-power.png | Check battery ring and key-value grid. |
| Dashboard Apps | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-apps.png | Check running-app table. |
| Dashboard Status | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-status.png | Check status cards and thresholds. |
| Dashboard History | 960x640 | en | Light | Pending | docs/review/screenshots/responsive/en-light-960x640-history.png | Check trend rows. |
| Dashboard Settings | 960x640 | en | Light | Source Fixed | docs/review/screenshots/responsive/en-light-960x640-settings.png | Setting rows now use `ViewThatFits` plus capped control widths. |
| Dashboard Settings | 960x640 | zh-Hans | Light | Pending | docs/review/screenshots/responsive/zh-light-960x640-settings.png | Check localized control row wrapping. |
| Menu Bar Status | Native | en | Light | Pending | docs/review/screenshots/responsive/en-light-menu-bar-status.png | Check each selected metric width. |
| Menu Bar Popover | Native | en | Light | Pending | docs/review/screenshots/responsive/en-light-popover.png | Check fixed popover frame and labels. |
| Small Widget | Small | en | Light | Pending | docs/review/screenshots/responsive/en-light-widget-small.png | Check English label wrapping. |
| Medium Widget | Medium | en | Light | Pending | docs/review/screenshots/responsive/en-light-widget-medium.png | Check metric rows and status labels. |

## Finding Log

| ID | Priority | Surface | Finding | Root Cause | Fix | Status |
| --- | --- | --- | --- | --- | --- | --- |
| RF-1 | P0 | DashboardTopBar | Header chrome can render as a centered narrow island. | `ViewThatFits` keeps intrinsic width because the top bar lacks a full-width frame. | Full-width frames added to `DashboardTopBar`, `regularContent`, and `compactContent`. | Source Fixed |
| RF-2 | P0 | Settings rows | Long controls can press beyond the right panel edge. | Setting rows use one horizontal `HStack` with no vertical fallback. | `ViewThatFits` fallback and capped control widths added. | Source Fixed |

## Fixed-Width Inventory

These remaining fixed widths are allowed only when they are paired with an existing compact fallback, local horizontal scrolling, or source-level review coverage.

| Source Pattern | Surface | Decision |
| --- | --- | --- |
| `.frame(width: 360)` | Overview widget preview / responsive aside | Covered by `ResponsivePanelPair` or a page-specific compact branch. |
| `.frame(width: 340)` | Power responsive aside | Covered by `ResponsivePanelPair`. |
| `.frame(width: 320)` | CPU responsive aside | Covered by `ResponsivePanelPair`. |

## Final Result

P0 source-level responsive failures are fixed and guarded:

- `DashboardTopBar` now claims the full main-column width before and after padding, so its background and divider cannot collapse into an intrinsic-width island.
- `SettingControlRow` and `SettingReadOnlyRow` now use horizontal and vertical `ViewThatFits` fallbacks, with capped control widths for picker-heavy rows.
- Remaining fixed-width dashboard panels are covered by existing compact branches, `ResponsivePanelPair`, or local table scrolling.

Manual screenshot follow-up remains useful for pixel-level confirmation across every matrix row, especially widgets and menu-bar chrome.
