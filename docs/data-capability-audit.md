# Pulse Dock Data Capability Audit

Last updated: 2026-06-13

This file is an internal product and App Store readiness audit. It should not be surfaced verbatim in the app UI.

## Status Legend

- Implemented: sampled from public macOS APIs and displayed as live data.
- Partial: public data exists and is used, but deeper AIDA64-style detail is intentionally not shown.
- Not implemented: kept out of the product because it would need fragile, private, privileged, or hard-to-justify access.
- Internal fallback: used only while waiting for a real app snapshot; must not pretend to be live data.

## Implemented

| Area | Data | Source | Surfaces |
| --- | --- | --- | --- |
| CPU | Total usage, per-logical-core usage, physical/logical core counts, active processor count, CPU brand | Mach host processor counters, `ProcessInfo.activeProcessorCount`, and sysctl hardware keys | Overview, CPU page, menu bar, widgets |
| Memory | Used, total, free, wired, compressed, cached memory, and swap used/total/available | Mach VM statistics, physical memory, and `vm.swapusage` sysctl | Overview, Memory page, widgets |
| Load | 1/5/15 minute load averages | System load average | Overview, CPU page, Status page, History page, Settings page, large widgets, menu bar popover |
| Network | Interface counters, upload/download/total throughput, interface list, state, system interface kind, MTU, packet counters, interface error counters, and link speed when reported, without storing local IP addresses or raw interface names | Public route sysctl 64-bit interface counters, getifaddrs fallback, public route interface statistics, and SystemConfiguration interface metadata | Overview, Network page, menu bar |
| Network path | Online/offline/requires connection, interface kind, low data mode, metered network, DNS/IPv4/IPv6 path support | Network path monitor | Overview, Network page, Status page, widgets |
| Storage | Primary disk free/total, mounted volume summaries, per-volume total bytes, used bytes, and usage percentage, regular and important usage available capacity, file system name, removable/ejectable/internal flags, read-only state, and primary-volume flag, without storing mount paths or user-defined volume names | File system and volume resource values including `volumeAvailableCapacityForImportantUsage` and `volumeIsReadOnly` | Overview, Storage page, Status page, Settings page |
| Battery and power | Battery percentage, current providing power source, charging state, remaining time, current/max/design capacity, cycle count, health, voltage, and amperage when reported | Public IOPowerSources description keys, current providing power source type, public system time remaining estimate, preferring the internal battery description when multiple power sources exist | Overview, Power page, Status page, widgets |
| Thermal | System thermal state | Process thermal state | Overview, Power page, Status page, widgets |
| System uptime and version | Time elapsed since system boot, OS version string, and Darwin kernel release, formatted on-device | System boot time via `ProcessInfo.systemUptime`, OS version via `ProcessInfo`, and Darwin kernel release via `uname.release` | Overview, Status page, History page, Settings page, widgets, menu bar popover |
| GPU and display | GPU device inventory, low-power/removable GPU capability, unified memory capability, recommended working set, public threadgroup memory and size limits, active displays, pixel size, display mode size, backing scale factor, color space model and component count, physical screen size, refresh rate, rotation state, mirror/extension state when reported | Metal, CoreGraphics display configuration, AppKit `NSScreen` display metadata, AppKit `NSScreen` fallback, and `NSScreen.maximumFramesPerSecond` when CoreGraphics omits refresh rate | GPU/Display page, Status page, Settings page |
| Running apps | Foreground-session app count, full-list active/hidden counts, ranked display list, activation policy, executable architecture, and launch time when reported | Workspace running applications in the main app | Overview, Memory page, App page |
| Widget data | Compact local timeline snapshot shared from the main app through App Group UserDefaults, with Widget extension self-sampling fallback when shared data is unavailable or stale | Main app writes a compact snapshot with the shared sampler; Widget extension reads the shared snapshot first and otherwise uses the same public sampler | Small, medium, large WidgetKit widgets |
| Menu bar monitor | Optional live CPU title, compact popover, open dashboard, pause/resume refresh, open settings | Main app store and AppKit status item | Menu bar popover |
| Settings | Main-window refresh interval, persisted trend history depth, menu bar CPU title, and local thresholds | App-only UserDefaults with privacy reason `CA92.1` | Settings page, top bar, History page |
| Status thresholds | CPU, memory, and disk local alert thresholds | App-only UserDefaults and current live samples | History, Overview, Status, and Storage pages |
| Trend history | Sanitized CPU, memory, load, network, disk, battery, thermal, and uptime trend snapshots | App-only UserDefaults with 15-second persistence throttle | Overview, CPU, Memory, Network, Power, and History pages |

## Partial

| Area | Current behavior | Reason |
| --- | --- | --- |
| Per-process resource detail | Shows public app session state only | Cross-process CPU, memory, thread count, and CPU time are intentionally not sampled in the sandboxed product |
| GPU detail | Shows device capability and display topology | GPU utilization, temperature, fan speed, and power draw are not available through stable public macOS APIs for this app shape |
| Network probes | Shows path status and throughput | Latency, DNS health, packet loss, and remote speed tests would require outbound probes and user-facing product decisions |

## Not Implemented For App Store Path

| Area | Exclusion |
| --- | --- |
| CPU/GPU temperature sensors | Avoid SMC, powermetrics, privileged helpers, or private registry probing |
| Fan speed and power draw | Avoid private/privileged hardware sensor paths |
| Per-process resource ranking | Avoid cross-process inspection beyond the public running-app list |
| Raw serial and hardware identifiers | Avoid device fingerprinting-like fields, raw display/GPU registry identifiers, local computer names, and raw hardware model identifiers |
| Storage mount paths | Avoid storing path-like local identifiers in dashboard snapshots |
| User-defined storage volume names | Avoid storing volume labels because they can contain user-created names; use local ordinal labels and a primary-volume flag instead |
| Local network addresses | Avoid storing IP addresses in dashboard snapshots when interface state and counters are enough for the product UI |
| Raw network interface names | Avoid storing or displaying interface identifiers such as system device names; use local ordinal identifiers with display kind labels instead |

## Internal Fallbacks

- `MetricSnapshot.placeholder` is intentionally empty or unknown. It must not contain realistic CPU, memory, network, process, GPU, display, or storage sample values.
- Widget timelines use direct public-API sampling through a small in-extension sampler cache and then store compact timeline snapshots. The placeholder view is a visual skeleton with a short waiting label only; it must not contain demo values or explanatory waiting-state copy.
- Widget timeline entries store compact snapshots that strip unused process, storage, GPU, and display inventory lists.
- Main app and widget snapshots warm the sampler before publishing delta-based CPU/network readings, so the first visible sample and resume-after-pause sample are not unprimed or stale counter baselines.
- Sample timestamp display text reports the system-not-reported state for placeholder or missing timestamp snapshots.
- Widget headers use minute-level sampled time text so narrow widget families stay readable.
- Widget headers use explicit sample-time reported-state flags instead of comparing sampled time display text.
- History sample-count labels count only snapshots with reported sample timestamps, so placeholder or legacy missing-time history is not displayed as sampled history.
- Static inventory sampling is cached for the main refresh loop: mounted volumes, GPU devices, and display topology use a short 15-second TTL while CPU, memory, network, power, thermal, uptime, and load remain sampled on each visible refresh.
- Static system information is sampled once per sampler instance: physical/logical core counts, CPU brand, OS version, and Darwin kernel release are reused while active processor count, CPU usage, memory, network, power, thermal, uptime, and load remain live readings.
- System uptime is sampled and formatted on-device only. It requires the System Boot Time required-reason entry because the shared sampler is used by both the app and Widget extension.
- Operating system version display text reports the system-not-reported state when only a generic placeholder is available.
- Legacy snapshots missing operating system version remain not-reported instead of borrowing the current machine OS version during decode.
- System uptime display text reports the system-not-reported state when no boot-time sample has been published, instead of formatting missing uptime as zero minutes.
- Darwin kernel release is sampled from `uname.release` only. The sampler does not read `nodename` or `machine` from `utsname`.
- Kernel version status rows report missing kernel release as not-reported instead of normal.
- OS and kernel reported state is centralized on the shared snapshot model instead of being inferred from user-facing text.
- The Status page and Settings data-source row surface OS version alongside uptime and Darwin kernel release.
- Large widgets surface OS version, Darwin kernel release, and uptime with explicit snapshot reported-state tinting. Smaller widget families keep to glanceable live status values.
- Large widgets surface Darwin kernel release alongside OS version and uptime.
- Large widget layout uses two breathable columns with grouped rings and signal sections instead of stacking every row and tile vertically.
- Widget dark-mode palette uses cool neutral stops and color-scheme-aware accents.
- Widget metric rings and stat tiles use the shared light/dark track and secondary text helpers, so dark-mode contrast stays consistent across widget families.
- Widget placeholder skeletons use shared light/dark track and fill helpers so widget gallery previews do not retain fixed light-mode colors.
- CPU active processor count uses `ProcessInfo.activeProcessorCount` for load normalization and display; it is separate from the hardware logical-core count.
- CPU core-count surfaces use shared reported-state text, so placeholder or failed count samples do not appear as zero-core hardware.
- MetricSnapshot defaults do not invent physical core counts when the sampler has not reported them.
- Legacy snapshots missing physical or logical CPU counts remain not-reported instead of borrowing the current machine counts during decode.
- CPU usage text reports the system-not-reported state when Mach CPU counters have not produced a delta sample, instead of formatting an unprimed counter baseline as zero percent.
- MetricSnapshot initializer defaults CPU usage to not-reported unless a sampler explicitly reports a Mach CPU delta sample.
- CPU trend charts filter out samples whose CPU counters were not reported, so missing samples do not appear as 0% dips.
- Memory, disk, and network trend charts filter out samples whose capacity or byte-counter data was not reported, so missing samples do not appear as zero-value dips.
- Memory trend charts use the shared memory reported-state flag, so future capacity validation changes stay consistent across text and charts.
- The Overview running trend surfaces load-average history alongside CPU, memory, network, and disk.
- Current progress bars and gauges in the app and widgets suppress filled progress when the paired live value is not reported, so missing samples do not render as 0% readings.
- Dashboard progress bars and gauges use explicit snapshot reported-state flags instead of user-facing text comparisons.
- Widget progress rings and rows use explicit snapshot reported-state flags instead of user-facing text comparisons.
- Menu bar popover progress bars suppress filled progress when the paired live value is not reported, so missing samples do not render as 0% readings.
- Menu bar popover progress bars use explicit snapshot reported-state flags instead of user-facing text comparisons.
- Menu bar popover chooses a visible screen edge and clamps height before showing, with scrollable content for smaller visible areas.
- Menu bar popover shows without activating the main app, avoiding a second window-ordering pass after the popover is positioned.
- Menu bar status item uses stable fixed lengths so live CPU title refreshes do not move the popover anchor while it is shown.
- Menu bar popover pins a fresh SwiftUI root view to the computed content height before showing.
- Menu bar popover installs a fresh hosting controller before each show and releases it after close, avoiding stale second-open layout state without replacing content after `show`.
- Menu bar popover treats the NSStatusBar window as a fixed top anchor, always opening downward while clamping height from the actual anchor frame and visible screen.
- Menu bar popover treats status-bar-level or higher anchor windows as fixed top anchors, so menu extra window-level differences cannot trigger transient off-screen edge calculation.
- Menu bar popover placement uses a tested geometry helper that clamps status-bar popovers from the actual anchor frame before showing.
- Menu bar popover clamps the status-button positioning rect within button-local coordinates before showing, so edge-of-screen clamping cannot move the arrow onto neighboring menu extras.
- Menu bar popover reserves non-content popover chrome before sizing and does not move the AppKit popover window after showing.
- Menu bar popover computes one placement before showing and reuses it for content size, preferred edge, and bounded anchor rect.
- Menu bar popover relies on pre-show content sizing instead of post-show window fitting, keeping the AppKit arrow and status item anchor synchronized.
- Menu bar popover adapts background, panel, track, and text colors for light and dark appearances.
- Menu bar popover surfaces the sampled load average instead of duplicating the header sample timestamp.
- Menu bar popover surfaces uptime and Darwin kernel release with explicit snapshot reported-state tinting.
- CPU brand display text reports the system-not-reported state when the sysctl brand string is unavailable, instead of using a generic device label.
- Per-core CPU tiles use one color because public per-core samples do not identify physical-core topology.
- The CPU page does not synthesize per-core tiles from aggregate CPU usage; if per-core counters are unavailable, it shows that the system did not report them.
- The CPU sampler returns no per-core usage list while it is only priming Mach CPU tick baselines, instead of reporting synthetic zero-valued per-core samples.
- Load average display text reports the system-not-reported state when getloadavg does not return a sample, instead of formatting missing load as zero.
- Current load-average progress requires both reported load averages and a sampled active processor count, so widgets and CPU page bars do not invent a one-core denominator.
- The Status page surfaces load-average detail as a current system signal instead of limiting it to the CPU and History pages.
- Large widgets surface load average with reported-state progress, normalized by active processor count.
- The Status page surfaces GPU inventory summary as a current system signal, using the same public Metal device inventory as the GPU/Display page.
- GPU/display combined summary text is centralized on the shared snapshot model.
- Widget UI avoids short-window network throughput because WidgetKit timelines are not continuous monitors.
- Widgets disable system content margins and own their family-specific padding, avoiding double-inset crowding while keeping the first-version composition.
- Medium widgets keep the large CPU readout and use three supporting metric rows so the desktop layout stays breathable; power remains visible in the small and large widget families.
- Medium widget layout follows the roomier first-version composition with wider left content, larger CPU type, and relaxed supporting row spacing.
- Medium widget left column uses a first-version-style CPU block with core summary and a compact status strip instead of stacking network detail text.
- Dashboard widget preview adapts its background, stroke, shadow, and secondary text to light and dark appearances.
- The main app writes a compact latest snapshot to App Group UserDefaults on a 60-second throttled cadence and asks WidgetKit to reload its timeline kind after shared writes.
- The Widget extension reads the shared compact snapshot first, rejects stale or future-dated records, and falls back to extension-local public API self-sampling when shared data is unavailable.
- User-facing fallback text says when the system did not report a value instead of using generic unknown-state wording.
- Thermal display text is centralized on the shared snapshot model, so dashboard, menu bar, and widget surfaces use the same reported-state fallback.
- Thermal reported state is centralized on the shared snapshot model instead of being inferred from user-facing text.
- Thermal limit display text is centralized on the shared snapshot model.
- Thermal gauge progress suppresses filled arcs when thermal state is not reported, instead of drawing missing thermal data as a nominal low-pressure value.
- Missing thermal-state indicators use neutral tint instead of green across dashboard, menu bar, and widget surfaces.
- Running-app lists describe their actual public Workspace ordering: active apps first, hidden apps later, then localized app name ordering.
- Running-app display names use `NSRunningApplication.localizedName`; missing or blank running-app names as not-reported instead of a generic app label.
- Running-app display text is centralized on the shared process model.
- ProcessMetric initializer defaults running state to not-reported when only public app identity, launch time, or architecture fields are provided.
- Legacy running-app snapshots missing state fields remain not-reported instead of being displayed as running apps.
- Legacy running-app list records with no reported app fields remain not-reported instead of being counted as live app list entries.
- Legacy running-app snapshots with a list but missing count fields keep total, active, and hidden counts as not-reported instead of zero.
- Battery sampling enumerates all public IOPowerSources descriptions and prefers the internal battery before falling back to other capacity-bearing power sources.
- Battery sampling also reads the current providing power source type so desktop Macs or missing battery descriptions can still report AC/Battery/UPS state.
- Battery percentage text is separated from power status text so desktop and UPS power states are not mislabeled as battery readings.
- Power reported state is centralized on the shared snapshot model instead of being inferred from user-facing text.
- Missing power-source samples display as not-reported instead of being inferred as no battery.
- Missing power-source indicators use neutral tint instead of healthy or warning colors.
- History power trend uses the current power-status label and neutral tint when power-source data is missing.
- Power progress uses measured battery percent only; AC/UPS/source-only states are displayed as text without invented gauge fill.
- Power indicator tint uses the shared power-source tone mapping so battery or UPS power without a percent is warning-colored instead of green.
- Compact power surfaces show the current providing power source when no battery percentage exists, while battery-specific rows still say that no battery is present.
- Overview and Status power surfaces use the same current power status fallback instead of treating missing battery percentage as zero battery.
- The Power page foregrounds the current power status when no battery percentage exists, while detailed battery rows remain explicit about missing battery values.
- The Power page summary surfaces public voltage and amperage readings when macOS reports them, not only in the detailed battery table.
- Battery detail display text is centralized on the shared snapshot model.
- Battery sampling uses the public system time remaining estimate only as a discharge-time fallback when the selected power source description does not report time to empty.
- Battery charging state is only displayed when the public power-source description reports `kIOPSIsChargingKey`; AC power alone is not treated as charging.
- Storage sampling uses public mounted-volume capacity values, including important usage available capacity when macOS reports it.
- Primary disk sampling uses the same sanitized important-available capacity fallback as per-volume display, so impossible important-available values do not suppress otherwise valid disk usage.
- The Status page surfaces mounted storage volume summary as a current system signal, using the same sanitized volume inventory as the Storage page.
- Primary disk display text reports the system-not-reported state when total capacity is unavailable, instead of formatting missing capacity as zero bytes.
- Primary disk display text treats impossible free-greater-than-total capacity samples as not-reported instead of formatting them as 0% usage.
- Disk trend charts use the shared primary-disk reported-state flag, so impossible capacity samples do not appear as 0% dips.
- Disk capacity bars use the shared primary-disk reported-state flag, so impossible capacity samples do not render as fully free storage.
- The Storage page shows per-volume total bytes, used bytes, and usage percentage derived from the sampled total and available capacity values, and displays important usage available capacity with regular available capacity as fallback.
- Per-volume display text reports the system-not-reported state when capacity is unavailable, instead of formatting missing volume capacity fields as zero bytes.
- Per-volume raw used and usage values use the same capacity reported-state guard as display text.
- Storage volume count surfaces use shared storage summary text so missing storage inventory is not formatted as 0 volumes.
- Storage volume reported state is centralized on the shared snapshot model instead of being inferred from user-facing text.
- Legacy storage volume records with no reported fields remain not-reported instead of being counted as mounted volumes.
- Storage sampling uses `volumeIsReadOnly` to show the current read-only state without storing mount paths or user-defined volume names.
- Storage volume kind and access display text is centralized on the shared volume model.
- Legacy storage volume snapshots missing kind or access flags remain not-reported instead of being displayed as external writable volumes or zero external-volume counts.
- Storage volume kind text and external-volume classification ignore residual removable/ejectable flags when kind state was not reported.
- StorageVolumeMetric initializer defaults kind and access to not-reported when only volume capacity is provided.
- Storage file-system display text reports missing or legacy unknown values as not-reported.
- Display sampling uses CoreGraphics first and falls back to `NSScreen.screens` when the sandboxed app cannot resolve an active display list. The fallback exposes ordinal display information only.
- NSScreen fallback sampling is guarded to run only on the main thread.
- Display refresh rate uses CoreGraphics display mode first, then `NSScreen.maximumFramesPerSecond` when macOS omits refresh rate from the active display mode.
- Display backing scale factor uses `NSScreen.backingScaleFactor` mapped by display number. It does not store raw display identifiers in snapshots.
- Display color information uses `NSScreen.colorSpace` only for generic model and component count. It does not store color profile names.
- Display metric text reports the system-not-reported state when display dimensions or capabilities are unavailable, instead of formatting missing display fields as zero-sized or adaptive values.
- Missing or legacy generic display names are displayed as not-reported instead of a generic display label.
- Display count surfaces use the shared display summary text so missing display inventory is not formatted as 0 displays.
- Display reported state is centralized on the shared snapshot model instead of being inferred from user-facing text.
- Legacy display inventory records with no reported display fields remain not-reported instead of being counted as live displays.
- Display topology state text is centralized on the shared display model.
- DisplayMetric initializer defaults topology and rotation state to not-reported when only public display capability fields are provided.
- Legacy display snapshots missing topology or rotation fields remain not-reported instead of being displayed as external extended displays or 0-degree rotation.
- Compact inventory and uptime indicators use neutral tint when their sampled values are not reported.
- The GPU/Display page shows sampled display mode size, physical screen size, and rotation state instead of only the pixel resolution.
- The GPU/Display page shows public low-power/removable GPU capability as a readable device type.
- The GPU/Display page shows public Metal threadgroup limits as capability data and still avoids utilization, temperature, fan, and power telemetry.
- GPU device capability display text is centralized on the shared GPU model.
- GPUDeviceMetric initializer defaults kind, unified-memory, and display-role state to not-reported when only public capability limits are provided.
- Legacy GPU device snapshots missing capability flags remain not-reported instead of being displayed as high-performance, non-unified-memory display GPUs.
- GPU unified-memory summary ignores legacy devices whose unified-memory capability was not reported instead of counting them as unsupported.
- GPU inventory display text reports the system-not-reported state when Metal does not return a device list, instead of treating missing inventory as absent hardware.
- Legacy GPU inventory records with no reported device fields remain not-reported instead of being counted as live GPU devices.
- Missing or legacy generic GPU names are displayed as not-reported instead of a generic device label.
- GPU/Display detail tables filter legacy inventory rows without reported fields instead of rendering empty not-reported rows.
- Network card progress bars may use normalized baselines for glanceable charts, but the UI must not present those baselines as measured percentages.
- Network path capability uses `NWPath` DNS/IPv4/IPv6 support flags only. It does not perform DNS lookups, pings, latency checks, or outbound probes.
- Network path support rows distinguish reported unsupported DNS/IPv4/IPv6 capabilities from missing path data.
- MetricSnapshot initializer defaults do not mark network path support or cost flags as reported when only path status is provided.
- Network path support rows show unavailable when the reported path is offline instead of treating offline false flags as unsupported capabilities.
- Legacy network path snapshots missing DNS, IPv4, or IPv6 support flags remain not-reported instead of being displayed as unsupported capabilities.
- The Network page surfaces low-data-mode and metered-network path flags as explicit rows, not only inside the path detail string.
- Legacy network path snapshots missing low-data-mode or metered-network flags remain not-reported instead of being displayed as disabled flags.
- Network path capability row display text is centralized on the shared snapshot model.
- Network path flag display text is centralized on the shared snapshot model.
- Network path other-interface labels use localized product text instead of leaking internal enum wording.
- Network path reported state is centralized on the shared snapshot model instead of being inferred from user-facing text.
- Network interface kind falls back to a generic interface label when SystemConfiguration cannot identify en* devices.
- Network byte counters prefer sysctl interface statistics and do not mark legacy getifaddrs fallback counters as authoritative.
- Unknown network path state keeps detail and progress in a not-reported state instead of borrowing online details or positive progress.
- Unknown network path state keeps dashboard status neutral instead of warning, so missing path data is not treated as a network issue.
- Network path detail suppresses low-data and metered qualifiers when path status itself is not reported.
- Network path trend charts filter out unknown path samples while preserving reported offline states as zero-value status samples.
- Network local-rule rows report missing path state as not-reported instead of warning, while reported offline or requires-connection states remain warning results.
- Network local-rule display text is centralized on the shared snapshot model.
- Status summary neutral badges use not-reported wording instead of optional wording, so missing sampled values are not framed as configurable features.
- Network interface classification uses SystemConfiguration metadata when available, while raw BSD interface names remain transient sampler keys only.
- Network interface classification metadata uses the short inventory TTL, while byte counters, packet counters, errors, MTU, and link speed remain sampled from live interface data on each visible refresh.
- Network interface state display text is centralized on the shared interface model.
- NetworkInterfaceMetric initializer defaults interface state to not-reported when only counters, MTU, link speed, or sanitized labels are provided.
- Legacy network interface snapshots missing state flags remain not-reported instead of being displayed as offline or zero active interfaces.
- Missing or legacy generic network interface names and kinds are displayed as not-reported.
- Network interface summary text reports the system-not-reported state when the interface inventory is missing, instead of formatting missing inventory as 0 active interfaces.
- Network interface reported state is centralized on the shared snapshot model instead of being inferred from user-facing text.
- Network data-source status ignores legacy interface rows without reported state, while still allowing byte counters to report interface traffic.
- App and widget active-interface progress normalizes by reported interface state rows, so legacy interface records do not dilute live interface progress.
- Network interface detail table filters legacy rows without reported fields and shows an explicit not-reported row instead of an empty table.
- Widget active-interface progress normalizes by the sampled interface count instead of a fixed baseline.
- The Network page summary surfaces sampled active interface count alongside throughput and path state.
- Network interface byte counters prefer public `NET_RT_IFLIST2` 64-bit interface counters and fall back to `getifaddrs` counters when route sysctl data is unavailable.
- Network interface byte count display text reports the system-not-reported state when counters are unavailable, instead of formatting missing byte counters as zero.
- Aggregate network rate display text reports the system-not-reported state when byte counters are unavailable, instead of formatting missing aggregate throughput as zero.
- The Network page trend panel surfaces aggregate throughput alongside download and upload history.
- The Network page trend panel surfaces connection status history from the public network path monitor.
- Network interface MTU uses public route interface statistics and `getifaddrs` interface data fallback, without storing raw interface names in snapshots.
- Network interface MTU display text reports the system-not-reported state when MTU is unavailable or zero.
- Network interface packet counters and interface error counters use the same public route statistics and `getifaddrs` fallback without storing raw interface names in snapshots.
- Network interface packet and error count display text reports the system-not-reported state when counters are unavailable, instead of formatting missing counters as zero.
- Network interface link-speed display text reports the system-not-reported state when link speed is unavailable or zero.
- Running-app architecture uses `NSRunningApplication.executableArchitecture` mapped to readable labels, without storing bundle identifiers, executable paths, process identifiers, or resource counters.
- Running-app count surfaces report missing Workspace samples as not-reported instead of displaying zero counts.
- The Overview system status running-app row surfaces the full public Workspace state counts: total, active, and hidden apps.
- Running-app summary display text is centralized on the shared snapshot model.
- Memory composition keeps active/wired/compressed, inactive/purgeable cache, and free/speculative pages in separate buckets; used memory excludes inactive cache pages.
- Memory display text reports the system-not-reported state when total memory capacity is unavailable, instead of formatting missing memory fields as zero bytes.
- Legacy memory snapshots missing composition fields keep free, wired, compressed, cached, and active memory as not-reported instead of zero bytes.
- MetricSnapshot initializer defaults memory composition to not-reported when only memory capacity and usage are provided.
- CPU and memory data-source status uses the shared memory reported-state flag instead of raw capacity checks.
- Memory segment bars use the shared memory composition reported-state flag, so missing detail samples do not render as zero-byte segments.
- Memory and disk usage percentage text reports the system-not-reported state when capacity is unavailable, instead of formatting missing usage percentages as zero.
- Threshold status surfaces report missing memory or disk usage as not-reported instead of normal, so local rules do not treat missing capacity data as a healthy value.
- Threshold status surfaces use explicit snapshot reported-state flags instead of user-facing text comparisons.
- Trend history persistence stores sanitized snapshots only. Live snapshots do not model local computer names or raw hardware model identifiers, and persisted history also strips process list, network interfaces, storage volume list, GPU list, and display list before writing to UserDefaults.
- Sanitized trend history resets OS version and Darwin kernel release to shared not-reported placeholders instead of preserving system identity fields.
- Persisted trend history preserves CPU reported-state flags so missing CPU samples do not reload as 0%.
- Persisted trend history preserves sampled active processor count so load-average charts keep the original normalization denominator.
- Legacy persisted history without sampled active processor count is excluded from load-average trend normalization instead of borrowing the current machine count.
- The History page surfaces persisted disk usage trend alongside CPU, memory, network, and power history.
- The History page surfaces persisted load-average trend while filtering samples whose load averages were not reported.
- The History page surfaces persisted thermal-state trend while filtering samples whose thermal state was not reported.
- The History page surfaces persisted uptime trend while filtering samples whose uptime was not reported.
- Status thresholds are dashboard-only for v1. The app does not request notification permissions or badge privileges.
- Settings data-source rows use sampled reported-state text instead of hard-coded availability labels, so missing or partial inventories remain visible as not-reported or partial data.
- Settings data-source display text is centralized on the shared snapshot model.
- Settings data-source rows include load-average reported state, matching the implemented Load surfaces.

## Quality Gates

- Source-level tests prevent realistic values from returning to `MetricSnapshot.placeholder`.
- Source-level tests require WidgetKit snapshot and timeline entries to sample through `SystemSampler()`.
- Source-level tests require WidgetKit sampling to reuse an in-extension sampler cache instead of recreating the delta-based sampler on every timeline request.
- Source-level tests require the main app to warm the sampler before publishing its initial visible snapshot and before publishing after pause/resume.
- Source-level tests prevent app and widget surfaces from formatting placeholder snapshot timestamps as real sample times.
- Source-level tests require widget headers to use explicit sample-time reported-state flags instead of comparing sampled time display text.
- Source-level tests prevent history count labels from counting placeholder snapshots as sampled history.
- Source-level tests require the menu bar popover to use a fixed content size, matching preferred content size, enabled AppKit animation, and a bounded status-button anchor.
- Source-level tests require the menu bar popover to pin SwiftUI hosting size and layout before showing with a fresh hidden hosting controller.
- Source-level tests require the menu bar popover to choose a visible screen edge, clamp content height, and keep smaller popovers scrollable before showing.
- Source-level tests require the menu bar popover root view height to match the computed content height before showing.
- Source-level tests require the menu bar popover to rebuild its hidden hosting controller before showing and release it after close.
- Source-level tests require the menu bar popover to bypass dynamic edge inference for NSStatusBar windows.
- Source-level tests require the menu bar popover to treat status-bar-level or higher anchor windows as top anchored.
- Source-level tests execute menu bar popover geometry for top status-bar anchors and shorter visible screens.
- Source-level tests require status popover geometry to clamp any screen-derived anchor adjustment back into button-local coordinates.
- Source-level tests require the menu bar popover to reserve popover chrome before showing without clamping the shown window frame.
- Source-level tests require menu bar popover content height to be finalized before `show` instead of shrinking after AppKit creates the popover window.
- Source-level tests require the menu bar popover to avoid post-show window frame refits that desynchronize the arrow.
- Source-level tests require the menu bar popover to avoid hiding content as a workaround for post-show window movement.
- Source-level tests require menu bar popover progress bars to use reported-state progress instead of drawing missing values as zero.
- Source-level tests require the menu bar status item to keep a stable length while the live CPU title refreshes.
- Source-level tests require the menu bar popover to use dynamic light/dark appearance helpers instead of fixed light panel colors.
- Source-level tests require the menu bar popover to surface load average with reported-state tinting.
- Source-level tests require the menu bar popover to surface uptime and Darwin kernel release with explicit snapshot reported-state tinting.
- Source-level tests prevent status popover opening from calling app activation after showing the popover.
- Source-level tests prevent widget placeholders from showing waiting-state copy.
- Source-level tests require Widget timeline entries to compact sampled snapshots before storage, keeping unused inventory lists out of WidgetKit entries.
- Source-level tests require static inventory sampling to be cached in the main refresh loop without caching live CPU, memory, network, or power readings.
- Source-level tests require static system information to be sampled once per sampler instance without caching active processor count.
- Source-level tests require medium widgets to avoid duplicating the CPU row and keep three supporting rows for memory, connection, and disk.
- Source-level tests keep medium widget vertical padding, row spacing, and dark-mode text/track colors from regressing into a crowded layout.
- Source-level tests keep the medium widget from reintroducing crowded left-column network detail copy.
- Source-level tests keep large widget ring spacing, grouped sections, and dynamic panel styling from regressing into a crowded vertical stack.
- Source-level tests require persisted trend history to use sanitized snapshots instead of writing full live snapshots.
- Source-level tests require sanitized history snapshots to reset OS and kernel identity fields through shared not-reported placeholders.
- Source-level tests require sanitized history snapshots to preserve sampled active processor count for load trend normalization.
- Source-level tests prevent legacy load history without active processor count from inventing a normalization denominator.
- Source-level tests require the History page to surface persisted disk usage trend.
- Source-level tests require the History page to surface persisted load-average trend.
- Source-level tests require the History page to surface persisted thermal-state trend.
- Source-level tests require the History page to surface persisted uptime trend.
- Source-level tests require the Overview running trend to surface persisted load-average history.
- Source-level tests keep user-facing copy aligned with implemented signals, including memory usage wording and WidgetKit timeline refresh semantics.
- Source-level tests prevent raw thermal unknown states from reaching dashboard, menu bar, or widget surfaces.
- Source-level tests require thermal reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons.
- Source-level tests prevent missing thermal state from using healthy green indicators.
- Source-level tests require the thermal gauge to hide filled progress when thermal state is not reported.
- Source-level tests prevent missing CPU usage from being formatted as 0% or judged as normal.
- Source-level tests prevent value-only snapshots from reporting CPU usage without explicit sample state.
- Source-level tests require current progress bars and gauges in the app and widgets to hide filled progress when the paired live value is not reported.
- Source-level tests require Dashboard progress bars and gauges to use explicit snapshot reported-state flags instead of user-facing text comparisons.
- Source-level tests require the CPU page to surface public active processor count, normalize load against it, and avoid implying physical-core topology in per-core tiles.
- Source-level tests require CPU page and menu bar core-count labels to use shared count text instead of interpolating raw integer fields.
- Source-level tests prevent legacy decoded snapshots without CPU count fields from inventing physical or logical core counts.
- Source-level tests prevent missing CPU brand strings from being displayed as a generic Mac label.
- Source-level tests prevent per-core CPU tiles from being synthesized from aggregate CPU usage.
- Source-level tests prevent CPU baseline priming from reporting synthetic zero-valued per-core samples.
- Source-level tests prevent missing load averages from being formatted as 0.0.
- Source-level tests require load-average progress in the CPU page and large widget to use shared optional progress instead of `max(activeProcessorCount, 1)`.
- Source-level tests require the Status page to surface load-average detail with reported-state handling.
- Source-level tests require Settings data-source rows to surface load-average reported state.
- Source-level tests require large widgets to surface load average with reported-state progress.
- Source-level tests require the Status page to surface GPU inventory with reported-state handling.
- Source-level tests prevent GPU unified-memory summary counts from treating missing unified-memory flags as unsupported GPUs.
- Source-level tests require Overview GPU/display summary labels to come from the shared snapshot model.
- Source-level tests require swap used/total/available to come from `vm.swapusage` sysctl and appear on the Memory page.
- Source-level tests keep memory used, cached, and reclaimable free page buckets disjoint.
- Source-level tests prevent missing memory capacity from being formatted as 0 B.
- Source-level tests require memory trend charts to use the shared memory reported-state flag.
- Source-level tests prevent legacy memory composition snapshots from inventing zero-byte detail rows.
- Source-level tests prevent capacity-only memory snapshots from inventing zero-byte composition details.
- Source-level tests prevent missing memory or disk usage percentages from being formatted as 0%.
- Source-level tests prevent missing threshold usage values from being displayed as normal local rule results.
- Source-level tests require threshold status surfaces to use explicit snapshot reported-state flags instead of user-facing text comparisons.
- Source-level tests require battery sampling to choose the internal battery description before other power sources such as UPS devices.
- Source-level tests require battery sampling to use the current providing power source type as a fallback when detailed battery descriptions are unavailable.
- Source-level tests prevent absent power-source data from surfacing as a no-battery state.
- Source-level tests prevent missing power-source state from using fixed healthy or warning tint.
- Source-level tests prevent the shared snapshot model from exposing the old batteryText alias.
- Source-level tests require power reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons.
- Source-level tests require power trend charts and gauges to use measured battery percent only, leaving source-only AC/UPS states without invented fill.
- Source-level tests require app, widget, and menu bar power tints to use shared power-source tone mapping.
- Source-level tests require overview, menu bar, and widget power surfaces to use the current power status instead of always foregrounding battery percentage text.
- Source-level tests require Overview and Status page power rows to use the current power status when battery percentage is unavailable.
- Source-level tests require the Power page to foreground the current power status instead of always foregrounding battery percentage text.
- Source-level tests require thermal limit labels to come from the shared snapshot model.
- Source-level tests require the Power page summary to surface sampled voltage and amperage readings.
- Source-level tests require Power page battery detail labels to come from the shared snapshot model.
- Source-level tests require battery sampling to use `IOPSGetTimeRemainingEstimate()` as a discharge-time fallback while filtering unknown and unlimited sentinel values.
- Source-level tests prevent missing battery charging flags from being inferred from AC power.
- Source-level tests prevent running-app models from carrying zeroed cross-process resource placeholders.
- Source-level tests prevent unsupported sensor values such as CPU/GPU temperature, fan speed, and power draw from remaining as zeroed or nil model placeholders.
- Source-level tests require system uptime to be sampled from the public process uptime API, displayed in the main app and large widget, and declared in both privacy manifests.
- Source-level tests require OS version surfaces to use reported-state text instead of the generic macOS fallback.
- Source-level tests prevent legacy decoded snapshots without OS version fields from inventing the current system version.
- Source-level tests require large widgets to surface OS version with explicit snapshot reported-state tinting.
- Source-level tests prevent missing uptime from being formatted as 0m.
- Source-level tests require public Darwin kernel release display without reading local device names or machine identifiers from `utsname`.
- Source-level tests require kernel version status rows to stay neutral when Darwin release is missing.
- Source-level tests require OS and kernel reported-state checks to use explicit snapshot flags instead of user-facing text comparisons.
- Source-level tests prevent GPU inventory snapshots from storing raw Metal registry identifiers.
- Source-level tests require the GPU/Display page to surface low-power/removable GPU capability from public Metal device properties.
- Source-level tests require GPU inventory snapshots and the GPU/Display page to surface public Metal threadgroup capability limits.
- Source-level tests require GPU page capability labels to come from the shared model.
- Source-level tests prevent capability-only GPU snapshots from inventing high-performance, non-unified-memory display state.
- Source-level tests prevent legacy GPU capability flags from inventing high-performance display state.
- Source-level tests prevent missing GPU inventory from being displayed as undetected hardware or warning-state data.
- Source-level tests prevent legacy GPU inventory records with only an index from inventing GPU device counts.
- Source-level tests prevent missing GPU device names from surfacing as a generic GPU label.
- Source-level tests prevent display inventory snapshots from storing raw CoreGraphics display identifiers.
- Source-level tests require a public AppKit fallback for display inventory when the CoreGraphics active display list is empty.
- Source-level tests require the display sampler to use `NSScreen.maximumFramesPerSecond` when CoreGraphics does not report refresh rate.
- Source-level tests require the GPU/Display page to surface display mode size and rotation state from sampled display metrics.
- Source-level tests require the display sampler and GPU/Display page to surface public CoreGraphics physical screen size without storing raw display identifiers.
- Source-level tests require the display sampler and GPU/Display page to surface public AppKit backing scale factor without storing raw display identifiers.
- Source-level tests require the display sampler and GPU/Display page to surface public AppKit color space model and component count, and to avoid storing color profile names.
- Source-level tests require Display page topology labels to come from the shared model.
- Source-level tests prevent capability-only display snapshots from inventing external extended topology or 0-degree rotation.
- Source-level tests prevent legacy display topology and rotation fields from inventing external extended state.
- Source-level tests prevent missing display metrics from being formatted as 0x0 or adaptive text.
- Source-level tests prevent missing display names from surfacing as a generic display label.
- Source-level tests prevent missing display inventory from being formatted as 0 displays on dashboard and menu bar surfaces.
- Source-level tests prevent legacy display inventory records with only an index from inventing display counts.
- Source-level tests prevent compact inventory and uptime indicators from showing healthy or warning tint when their values are missing.
- Source-level tests require display reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons.
- Source-level tests require GPU and display detail tables to filter by reported inventory state.
- Source-level tests prevent dashboard snapshots from storing local computer names or raw hardware model identifiers.
- Source-level tests prevent the running-app UI from showing process identifiers.
- Source-level tests require running-app summary counts to come from the full `NSWorkspace.runningApplications` list, not the truncated display rows.
- Source-level tests require the Overview running-app summary to surface active and hidden Workspace counts.
- Source-level tests require running-app architecture to come from the public `NSRunningApplication.executableArchitecture` label while still avoiding bundle identifiers and executable paths.
- Source-level tests require running-app page labels to come from the shared process model.
- Source-level tests require missing or blank running-app names as not-reported instead of a generic app label.
- Source-level tests prevent capability-only running-app snapshots from inventing running state.
- Source-level tests prevent legacy running-app state fields from inventing running state.
- Source-level tests prevent legacy running-app list records with only an index from inventing app list counts.
- Source-level tests prevent legacy running-app list snapshots from inventing zero total, active, or hidden counts.
- Source-level tests prevent missing running-app samples from being displayed as zero-count summaries.
- Source-level tests require running-app summary labels to come from the shared snapshot model.
- Source-level tests prevent sparklines from inventing synthetic trend samples when history is sparse.
- Source-level tests prevent widgets from showing short-window network throughput as if it were continuous live data.
- Source-level tests keep widget headers short enough to avoid narrow-family title and time truncation.
- Source-level tests require WidgetKit content margins to be disabled so medium widgets keep controlled breathing room.
- Source-level tests require widget metric ring tracks and stat tile labels to use dynamic light/dark appearance helpers.
- Source-level tests require WidgetKit placeholder skeleton tracks and fills to use dynamic light/dark helpers.
- Source-level tests prevent the dashboard widget preview from using fixed light-only colors in dark mode.
- Menu bar popover dark appearance uses cool dynamic card colors without drawing a second root material or brown overlay stops.
- Menu bar popover tracks transient close events and suppresses same-click reopen races when the status item is clicked to close.
- Menu bar popover prepares size and bounded button-local anchor before showing and never moves the AppKit popover window after `show`, keeping the arrow aligned.
- Menu bar popover passes geometry-clamped width and height into SwiftUI before showing.
- Menu bar popover rebuilds its hidden hosting controller for each show cycle and avoids forcing layout on the system status-bar window before calculating the frame.
- The menu bar popover leaves the outer background, rounded frame, arrow, and shadow to NSPopover instead of nesting a second custom chrome inside the system popover.
- Menu bar title updates are coalesced from snapshot and CPU-title preference changes, and missing CPU samples keep the status item icon-only.
- MetricsStore invalidates timers and cancels refresh tasks during deinitialization as a final lifecycle backstop.
- Source-level tests prevent dashboard network cards from showing normalized chart baselines as measured percentages.
- Source-level tests require Network page and large widget path capability display to come from public `NWPath` DNS/IPv4/IPv6 support flags.
- Source-level tests prevent reported false network path support flags from being displayed as not-reported.
- Source-level tests prevent status-only network path snapshots from inventing unsupported capabilities or disabled path flags.
- Source-level tests prevent offline network path support rows from being displayed as unsupported.
- Source-level tests prevent legacy network path support fields from inventing unsupported DNS, IPv4, or IPv6 capabilities.
- Source-level tests require the Network page to surface low-data and metered path flags with reported-state handling.
- Source-level tests prevent legacy network path cost flags from inventing disabled low-data-mode or metered-network state.
- Source-level tests require Network page path capability labels to come from the shared snapshot model.
- Source-level tests require Network page low-data and metered labels to come from the shared snapshot model.
- Source-level tests require the Network page trend panel to surface aggregate throughput history.
- Source-level tests require the Network page trend panel to surface network path status history.
- Source-level tests require Network path other-interface labels to use localized product text.
- Source-level tests require network path reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons.
- Source-level tests prevent unknown network path state from borrowing online details or positive progress.
- Source-level tests require unknown network path status to remain neutral instead of warning.
- Source-level tests require network path detail to guard cost qualifiers behind reported path state.
- Source-level tests require network path trend charts to filter unknown samples without dropping reported offline states.
- Source-level tests require network local-rule rows to preserve missing path state instead of showing warning.
- Source-level tests require network local-rule labels to come from the shared snapshot model.
- Source-level tests require status summary neutral badges to describe missing sampled values as not-reported instead of optional.
- Source-level tests require the Storage page to surface per-volume total bytes, used bytes, and usage percentage.
- Source-level tests require the Storage page to surface public read-only state without storing user-defined volume names.
- Source-level tests require Storage page volume kind and access labels to come from the shared model.
- Source-level tests require storage sampling and UI to use public important usage available capacity with regular available capacity as fallback.
- Source-level tests require primary disk sampling to use the shared sanitized storage-volume available-capacity value.
- Source-level tests require the Status page to surface storage volume inventory with reported-state handling.
- Source-level tests prevent missing primary disk capacity from being formatted as 0 B.
- Source-level tests prevent impossible primary disk capacity samples from being displayed as 0% usage.
- Source-level tests require disk trend charts to use the shared primary-disk reported-state flag.
- Source-level tests require disk capacity bars to use the shared primary-disk reported-state flag.
- Source-level tests prevent missing per-volume storage capacity from being formatted as 0 B.
- Source-level tests prevent missing storage inventory from being formatted as 0 volumes on dashboard and menu bar surfaces.
- Source-level tests require storage volume reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons.
- Source-level tests prevent storage inventory snapshots from storing volume mount paths.
- Source-level tests prevent storage inventory snapshots from storing user-defined volume names.
- Source-level tests prevent missing storage file-system names from surfacing as unknown.
- Source-level tests prevent legacy storage volume kind and access flags from inventing external writable state.
- Source-level tests prevent legacy storage volume records with only an index from inventing mounted-volume inventory.
- Source-level tests prevent legacy storage volume kind fields from inventing zero external-volume summaries.
- Source-level tests prevent explicit missing storage kind state from surfacing residual removable/ejectable flags.
- Source-level tests prevent capacity-only storage volume snapshots from inventing external writable state.
- Source-level tests prevent network interface snapshots from storing local IP addresses.
- Source-level tests prevent network interface snapshots from storing raw interface names or using raw names as fallback display labels.
- Source-level tests prevent missing network interface names or kinds from surfacing as Interface or Other.
- Source-level tests require SystemConfiguration-backed network interface classification to be linked in both SwiftPM and generated Xcode projects.
- Source-level tests require network interface classification metadata to use the short inventory TTL while counters stay live.
- Source-level tests require Network page interface state labels to come from the shared model.
- Source-level tests prevent counter-only network interface snapshots from inventing online or offline state.
- Source-level tests prevent legacy network interface state fields from inventing offline state.
- Source-level tests require active-interface progress to filter by reported interface state before normalizing.
- Source-level tests require Network data-source status to use reported interface state instead of raw interface array presence.
- Source-level tests prevent missing network interface inventory from being formatted as 0 active interfaces.
- Source-level tests require network interface reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons.
- Source-level tests require the network interface inventory table to show a not-reported empty row when filtered reported rows are unavailable.
- Source-level tests require the Network page summary to surface sampled network interface count.
- Source-level tests require network sampling to prefer public route sysctl 64-bit interface counters for long-running byte totals.
- Source-level tests prevent missing network byte counters from being formatted as 0 B / 0 B.
- Source-level tests prevent missing aggregate network counters from being formatted as 0 Kbps.
- Source-level tests require the Network page to surface public interface MTU without raw interface names.
- Source-level tests prevent missing network MTU from being formatted as 0.
- Source-level tests require the Network page to surface public packet counters and interface error counters without raw interface names.
- Source-level tests prevent missing network packet and error counters from being formatted as 0 / 0.
- Source-level tests prevent missing network link speed from being formatted as 0 bps.
- Source-level tests prevent Settings data-source rows from hard-coding availability when snapshot fields are missing.
- Source-level tests require Settings data-source labels to come from the shared snapshot model.

## Refresh Policy

- Main app refresh: user-selectable 1/2/5 seconds with timer tolerance.
- Widget timeline: 5 minutes.
- Shared widget snapshot write and Widget reload request from app: throttled to 60 seconds.
- Shared widget snapshot storage checks the production bundle identifier and App Group container availability before creating suite UserDefaults, so local ad-hoc builds fall back without blocking on unavailable App Group preferences.
- Trend history persistence: throttled to 15 seconds, with forced writes when sampling stops or history depth changes.
- Rationale: WidgetKit is system-scheduled, so the widget should be glanceable and power-friendly rather than pretending to be a real-time monitor.

## Privacy Manifest Scope

- Main app: Disk Space `85F4.1`, UserDefaults `CA92.1`, and System Boot Time `35F9.1`.
- Widget extension: Disk Space `85F4.1`, UserDefaults `CA92.1`, and System Boot Time `35F9.1`.
- Both targets declare no collected data and no tracking.
- The app Info.plist carries stable public privacy and support URLs used by the app menu and Settings page: `https://ifonly3.github.io/pulsedock/privacy-policy/` and `https://ifonly3.github.io/pulsedock/support/`.
- `ITSAppUsesNonExemptEncryption` is set to `false` for the current build because the app does not include custom cryptography.

## Build And Signing Readiness

- Local packaging uses a Release build with ad-hoc signing only for on-device testing and WidgetKit registration checks.
- Local packaging uses a deterministic derived-data directory so built app discovery does not depend on user-specific Xcode DerivedData hashes.
- App Store signing should use the generated Xcode project with Apple-managed signing, production bundle identifiers, and an App Store Connect archive/export workflow.
- App Store archive/export uses a dedicated script that requires production bundle identifiers and DEVELOPMENT_TEAM, then runs Xcode archive and export with App Store Connect export options.
- Generated Xcode projects, targets, shared scheme, and archive path use `PulseDock`, while the installed app product name remains `Pulse Dock`.
- Mac App Store screenshots live in `docs/app-store/screenshots` and are validated by `scripts/validate-app-store-screenshots.sh` before upload.
- Generated Xcode projects and local packaging accept DEVELOPMENT_TEAM from the environment for Apple-managed signing while keeping the default unset for local unsigned builds.
- Local packaging forwards bundle identifiers, version metadata, and DEVELOPMENT_TEAM to both Xcode project generation and xcodebuild, keeping generated project files and archive build settings aligned.
- `PACKAGE_SIGNING_MODE=xcode` keeps Xcode signing intact so the package script does not replace Apple-managed signatures with local ad-hoc signatures.
- App and Widget version metadata use shared Xcode build settings so App Store archives keep matching marketing and build versions.
- Source-level tests require App Store version metadata to come from archive build settings instead of hard-coded plist literals.
- Source-level tests prevent local packaging from depending on user-specific DerivedData hash paths.
- Source-level tests require App Store signing metadata to be parameterized through DEVELOPMENT_TEAM instead of being fixed in scripts.
- Source-level tests require local packaging to pass App Store archive metadata through both project generation and xcodebuild.
- Source-level tests require App Store archive/export to stay separate from local ad-hoc packaging.
- Source-level tests require PulseDock naming across project generation, shared schemes, archive scripts, and package metadata.
- Source-level tests require in-app privacy/support links and Mac App Store screenshot validation to remain wired.
- Local install cleanup removes the legacy System Dashboard bundle only after confirming its old bundle identifier, and unregisters old System Dashboard widget extensions before installing Pulse Dock.

## Next Implementation Targets

1. Keep status thresholds dashboard-only unless the product explicitly adds opt-in local notifications later.
2. Continue page-by-page runtime review for values that are technically available through public APIs but still absent from the UI.
