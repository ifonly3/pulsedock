# macOS System Monitor UI Concepts

Generated with the built-in image generation flow as a first visual direction for a macOS system monitor app and WidgetKit widgets.

## Screens

1. `01-overview.png` - Main runtime overview dashboard
2. `02-cpu.png` - CPU detail page
3. `03-memory.png` - Memory pressure and usage page
4. `04-storage.png` - Storage volumes and disk I/O page
5. `05-network.png` - Network interfaces and throughput page
6. `06-power-battery.png` - Power and battery page
7. `07-gpu-display.png` - GPU and display capability page
8. `08-processes.png` - Process table and inspector page
9. `09-sensors-thermal.png` - Sensors, thermal state, and helper-only telemetry page
10. `10-history-alerts.png` - Historical metrics and alert rules page
11. `11-settings-permissions.png` - Settings, permissions, and data-source status page
12. `12-desktop-widgets.png` - Desktop WidgetKit widget variants
13. `13-menu-bar-popover.png` - Menu bar quick monitor popover

## Implementation Notes

Public macOS data sources suitable for the first build:

- CPU/load/processes: `host_processor_info`, `sysctl`, `libproc`, `proc_pidinfo`
- Memory: `vm_statistics64`, `host_statistics64`, `sysctl hw.memsize`
- Storage capacity: `FileManager` volume resource values, `statfs`, `DiskArbitration`
- Disk I/O: IOKit storage counters where available
- Network: `NWPathMonitor`, `getifaddrs`, `SystemConfiguration`, `CoreWLAN` with permission caveats
- Power/battery: `IOPowerSources`, `IORegistry`, `IOPMAssertion`
- Thermal state: `ProcessInfo.thermalState`
- GPU/display: `Metal`, `CoreGraphics`, `NSScreen`, IOKit display properties
- Widgets: `WidgetKit` timelines backed by an App Group cache written by the main sampler

Advanced or machine-dependent telemetry should be shown as optional/helper-only:

- Per-core CPU temperature
- GPU temperature
- Fan RPM
- Exact GPU utilization
- Some battery/adapter details
- Some Wi-Fi SSID and display brightness details, depending on TCC permissions and macOS version
