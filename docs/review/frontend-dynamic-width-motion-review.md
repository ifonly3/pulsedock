# Frontend Dynamic Width And Motion Review

## Scope

| Surface | Risk | Required handling |
| --- | --- | --- |
| macOS menu bar status item | Selected metric can reserve too much space, truncate network values, or jump while text changes | Measured representative clamped status length, no literal leading space, monospaced digit font |
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
| DW-1 | Confirmed | AppDelegate used a fixed 92pt metric slot | Replace with measured 46-104pt clamped width based on selected metric family |
| DW-2 | Confirmed | AppDelegate prepended a literal space before the metric title | Remove the leading space and let AppKit image/title spacing handle separation |
| DW-3 | Confirmed | Dashboard sample chip used proportional time text with no min-width | Add min-width and monospaced digits to sample chips |
| DW-4 | Confirmed | Metric values had monospaced digits but no stable frame or numeric transition | Add StableMetricText for values and badges |
| DW-5 | Watch | Settings segmented controls can crowd cards at large text or scaled windows | Keep ViewThatFits fallback and width caps under source gates |
| DW-6 | Watch | Widget English labels can wrap in compact families | Keep abbreviations and one-line value guards under source gates |
| DW-7 | Confirmed | Measured per-sample status item width can move the popover anchor while open | Hold status item length by selected metric family and skip length changes while the popover is visible |

## Acceptance

- The menu bar selected metric for CPU, memory, battery, and short network values fits tightly beside the icon.
- Switching between icon-only and selected metrics does not leave broad empty padding on either side of the status item.
- Top bar sample time changes do not resize the chip every second.
- Dashboard value changes use monospaced digits and do not move neighboring controls.
- Numeric transitions are disabled when Reduce Motion is enabled.
- Widget and popover labels stay one line in English at supported sizes.
