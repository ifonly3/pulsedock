# L5 — 文档与代码声明一致性报告

> 审查日期：2026-06-28
> 审查范围：docs/data-capability-audit.md (551行) + README.md (68行) + docs/app-store-*-checklist.md + PrivacyInfo.xcprivacy + entitlements + Info.plist vs Sources/SharedMetrics/SystemSampler.swift (1411行) + MetricSnapshot.swift (1763行) + PulseDockAppGroup.swift + SharedSnapshotStore.swift + AppDelegate.swift + SystemDashboardWidget.swift + MetricsStore.swift
> 审查方法：逐句核对文档声明与代码实际行为，标注"声明 vs 行为"一致性，特别关注否定声明、"first...then fallback"顺序、"centralized on"位置、Surfaces 列覆盖
> 锚点 C2（data-capability-audit.md:183）已验证：前次 review P0-1 已修复，文档描述与当前代码一致

---

## 一、data-capability-audit.md 逐句核对

### 1.1 Implemented 表格（行 16-33）— Surfaces 列覆盖核对

| 行号 | 声明摘要 | 代码位置 | 行为 | 一致性 | 差异描述 |
|------|---------|---------|------|--------|---------|
| 18 | CPU Surfaces: Overview, CPU page, menu bar, widgets | SystemDashboardWidget.swift:179,204,255 | SmallWidget/MediumWidget/LargeWidget 均显示 `cpuText` | 一致 | — |
| 19 | Memory Surfaces: Overview, Memory page, widgets | SystemDashboardWidget.swift:180,220,256 | 三种 widget 均显示 `memoryUsageText` | 一致 | — |
| 20 | Load Surfaces: ..., large widgets, menu bar popover | SystemDashboardWidget.swift:258 | 仅 LargeWidget 显示 `loadText`；声明说"large widgets" | 一致 | — |
| 21 | Network Surfaces: Overview, Network page, menu bar | SystemDashboardWidget.swift:186,221,270-272 | widget 显示 `networkPathText`（path，非 throughput/counters）；Network 行覆盖 throughput/counters，不含 path | 一致 | Network path 由行 22 单独声明，widget 在行 22 的 Surfaces 中列出 |
| 22 | Network path Surfaces: ..., widgets | SystemDashboardWidget.swift:186,221,271 | 三种 widget 均显示 path 文本 | 一致 | — |
| 23 | Storage Surfaces: Overview, Storage page, Status page, Settings page | SystemDashboardWidget.swift:222,257 | MediumWidget + LargeWidget 显示 `diskUsageText`（primary disk usage percentage），但 Surfaces 列未列出 widgets | **不一致** | **D2**：Storage 行数据首项为"Primary disk free/total"，widget 显示 primary disk usage，但 Surfaces 列遗漏 widgets。对比 CPU/Memory 行均列出 widgets（即使 widget 仅显示部分数据），Storage 行应同样列出 |
| 24 | Battery and power Surfaces: ..., widgets | SystemDashboardWidget.swift:188,238,262 | 三种 widget 均显示 power 状态 | 一致 | — |
| 25 | Thermal Surfaces: ..., widgets | SystemDashboardWidget.swift:184,237,263 | 三种 widget 均显示 `thermalText` | 一致 | — |
| 26 | System uptime and version Surfaces: ..., widgets, menu bar popover | SystemDashboardWidget.swift:291-295 | LargeWidget 显示 uptime/osVersion/kernel | 一致 | — |
| 27 | GPU and display Surfaces: GPU/Display page, Status page, Settings page, **widgets** | SystemDashboardWidget.swift（全文） | widget 代码**未引用** `gpuDevices`/`displays`/`gpuSummary`/`displaySummary`/`hasGPUReport`/`hasDisplayReport` 任何字段；`sampleWidgetCompact()` 返回 `gpuDevices: []`/`displays: []`，`widgetCompactSnapshot()` 同样裁空 | **不一致** | **D1**：GPU and display 行的 Surfaces 列包含 "widgets"，但 widget UI 从不显示任何 GPU 或 display 数据。三种 widget 布局均无 GPU/display tile/row/ring。应从 Surfaces 列移除 "widgets" |
| 28 | Running apps Surfaces: Overview, Memory page, App page | MetricsStore.swift:445-481；SystemDashboardWidget.swift（无 runningApps 引用） | widget 不显示 running apps（`sampleWidgetCompact` 返回 `runningApps: []`） | 一致 | — |
| 29 | Widget data: compact snapshot via App Group + self-sampling fallback | SystemDashboardWidget.swift:63-66；SharedSnapshotStore.swift:54-73；SystemSampler.swift:362-443 | `sampledSnapshotForTimeline` 先读 shared store（maxAge 600s），fallback 到 `sampleWidgetCompact()`（跳过 GPU/display/storage volumes/running apps） | 一致 | — |

### 1.2 否定声明（"does not store"/"does not collect"/"does not perform"）

| 行号 | 声明摘要 | 代码位置 | 行为 | 一致性 | 差异描述 |
|------|---------|---------|------|--------|---------|
| 21 | Network: "without storing local IP addresses or raw interface names" | SystemSampler.swift:701-777；MetricSnapshot.swift:578-745 | `getifaddrs` 仅读 `ifa_name`/`ifa_flags`/`ifa_data(AF_LINK)`；`ifa_addr` 仅检查 `sa_family==AF_LINK`，不读 AF_INET/AF_INET6；`NetworkInterfaceMetric` 无 IP/raw name 字段（仅 `displayName`+`kind`） | 一致 | — |
| 23 | Storage: "without storing mount paths or user-defined volume names" | SystemSampler.swift:974-1028；MetricSnapshot.swift:427-576 | `StorageVolumeCandidate.mountPath` 仅用于内部 `isPrimary` 判定，不存入 `StorageVolumeMetric`；`keys` 不含 `.volumeNameKey`；模型无 mountPath/volumeName 字段 | 一致 | — |
| 50 | "Avoid ... raw display/GPU registry identifiers, local computer names, and raw hardware model identifiers" | MetricSnapshot.swift（全文）；SystemSampler.swift:1030-1099 | `DisplayMetric` 无 displayID 字段（CGDirectDisplayID 仅作内部 dict key）；`GPUDeviceMetric` 无 registryID；无 computerName/hardwareModel 字段。UI 中 "This Mac"/"本机" 是本地化标签（PulseDockAppStrings.swift:105），非存储的机器名 | 一致 | — |
| 51 | "Avoid storing path-like local identifiers" | 同行 23 | 同上 | 一致 | — |
| 52 | "Avoid storing volume labels" | 同行 23 | 同上 | 一致 | — |
| 53 | "Avoid storing IP addresses" | 同行 21 | 同上 | 一致 | — |
| 54 | "Avoid storing or displaying interface identifiers such as system device names" | SystemSampler.swift:719-724；MetricSnapshot.swift:679-687 | `NetworkInterfaceAccumulator.name` 仅作 dict key；`metric(index:)` 输出 `displayName`（sanitized）+`kind`，无 raw name；`reportedInterfaceDisplayName` 将空/"Interface" 映射为 notReported | 一致 | — |
| 58 | "MetricSnapshot.placeholder ... must not contain realistic CPU, memory, network, process, GPU, display, or storage sample values" | MetricSnapshot.swift:967-1018 | placeholder 全为零/空/nil，osVersion="macOS"（占位），timestamp=1970 | 一致 | — |
| 75 | "Darwin kernel release is sampled from uname.release only. The sampler does not read nodename or machine from utsname" | SystemSampler.swift:592-596 | `sampleKernelRelease()` 仅读 `systemInfo.release`，不读 `nodename`/`machine` | 一致 | — |
| 185 | "Display backing scale factor ... does not store raw display identifiers in snapshots" | SystemSampler.swift:1130-1136；MetricSnapshot.swift:246-425 | `CGDirectDisplayID` 作 `scalesByDisplayID` dict key，不存入 `DisplayMetric` | 一致 | — |
| 186 | "Display color information ... does not store color profile names" | SystemSampler.swift:1137-1142；MetricSnapshot.swift:256 | `DisplayMetric` 仅存 `colorSpaceModel`(String?) + `colorComponentCount`(Int)，无 colorProfileName 字段 | 一致 | — |
| 208 | "Network path capability uses NWPath DNS/IPv4/IPv6 support flags only. It does not perform DNS lookups, pings, latency checks, or outbound probes" | SystemSampler.swift:178-189 | `NetworkPathObserver.sample(from:)` 仅读 `path.supportsDNS`/`supportsIPv4`/`supportsIPv6`；`NWPathMonitor` 不发起外部连接/DNS/ping | 一致 | NWPathMonitor 仅监听系统网络状态评估，不发送流量 |
| 247 | "Network interface MTU ... without storing raw interface names" | 同行 21 | 同上 | 一致 | — |
| 249 | "Network interface packet counters ... without storing raw interface names" | 同行 21 | 同上 | 一致 | — |
| 252 | "Running-app architecture ... without storing bundle identifiers, executable paths, process identifiers, or resource counters" | MetricsStore.swift:469-480；MetricSnapshot.swift:10-104 | `ProcessMetric` 仅有 `name`/`activationPolicy`/`isActive`/`isHidden`/`launchDate`/`architecture`，无 bundleID/execPath/pid/resourceCounters | 一致 | — |
| 265 | "Trend history persistence stores sanitized snapshots only ... strips process list, network interfaces, storage volume list, GPU list, and display list" | MetricsStore.swift:223-288 | `sanitizedHistorySnapshot` 设 `runningApps:[]`/`networkInterfaces:[]`/`storageVolumes:[]`/`gpuDevices:[]`/`displays:[]` | 一致 | — |
| 274 | "Status thresholds are dashboard-only for v1. The app does not request notification permissions or badge privileges" | Sources/ 全文 grep | 无 `UNUserNotificationCenter`/`requestAuthorization`/badge 请求代码 | 一致 | — |

### 1.3 "first ... then fallback" 顺序声明

| 行号 | 声明摘要 | 代码位置 | 行为 | 一致性 | 差异描述 |
|------|---------|---------|------|--------|---------|
| 147 | "Battery sampling ... prefers the internal battery before falling back to other capacity-bearing power sources" | SystemSampler.swift:684-699 | `preferredBatteryDescription`: 先查 `kIOPSInternalBatteryType`，再查 capacity-bearing，再 `descriptions.first` | 一致 | — |
| 148 | "Battery sampling also reads the current providing power source type" | SystemSampler.swift:623,674-676 | `providingPowerSourceText(info)` 调用 `IOPSGetProvidingPowerSourceType(info)` | 一致 | — |
| 161 | "Battery sampling uses the public system time remaining estimate only as a discharge-time fallback when the selected power source description does not report time to empty" | SystemSampler.swift:648-651 | `timeRemaining = isCharging ? timeToFull : (timeToEmpty ?? estimatedDischargeMinutes)`；`IOPSGetTimeRemainingEstimate` 仅在 `timeToEmpty` 为 nil 且非充电时使用 | 一致 | — |
| 170 | "Storage page ... displays important usage available capacity with regular available capacity as fallback" | SystemSampler.swift:998-1010；MetricSnapshot.swift:525-529 | `StorageVolumeMetric.reportedAvailableBytes`: `importantAvailableBytes ?? self.availableBytes` | 一致 | — |
| 176 | "Storage sampling uses volumeIsReadOnly ... without storing mount paths or user-defined volume names" | SystemSampler.swift:982,1007 | `keys` 含 `.volumeIsReadOnlyKey`，不含 `.volumeNameKey`；模型无 mountPath/name 字段 | 一致 | — |
| 182 | "Display sampling uses CoreGraphics first and falls back to NSScreen.screens when the sandboxed app cannot resolve an active display list. The fallback exposes ordinal display information only" | SystemSampler.swift:1057-1098 | `CGGetActiveDisplayList` 先调用；若返回 0 → `screenSnapshot.fallbackDisplays`（来自 `NSScreen.screens`）；fallback `DisplayMetric` 设 `hasTopologyReport:false`/`hasRotationReport:false`/`isBuiltin:false`/`isMirrored:false`（仅 ordinal+dimensions+refresh+scale+color） | 一致 | — |
| 183 | "Display metadata that depends on NSScreen is collected through a main-thread snapshot before CoreGraphics display rows are assembled. This preserves Retina scale, color-space model, and refresh fallback when app sampling runs from detached tasks" | SystemSampler.swift:1101-1113,1057-1058 | `screenDisplaySnapshot()`: 若 `Thread.isMainThread` 直接调用；否则 `DispatchQueue.main.sync { screenDisplaySnapshotOnMainThread() }`。`sampleDisplays()` 第一行调用 `screenDisplaySnapshot()` 后再组装 CG display rows。MetricsStore.swift:339 通过 `Task.detached` 调用 `sample()`，`DispatchQueue.main.sync` 确保主线程执行 NSScreen 读取 | **一致（已修复）** | **C2 锚点确认**：前次 review P0-1 指出 detached 采样下 NSScreen 元数据丢失。当前代码通过 `DispatchQueue.main.sync` 桥接主线程，文档描述与实际行为一致。注意：`DispatchQueue.main.sync` 从 detached task 调用安全，因为 `Task { @MainActor }` 在 `await` 时释放 main actor，不持有线程 |
| 184 | "Display refresh rate uses CoreGraphics display mode first, then NSScreen.maximumFramesPerSecond when macOS omits refresh rate from the active display mode" | SystemSampler.swift:1070-1072,1179-1182 | `modeRefreshRate > 0 ? modeRefreshRate : screenSnapshot.refreshRatesByDisplayID[displayID, default: 0]`；`screenRefreshRate` 读 `screen.maximumFramesPerSecond` | 一致 | — |
| 219 | "Network interface kind falls back to a generic interface label when SystemConfiguration cannot identify en* devices" | SystemSampler.swift:1306-1314 | `interfaceSortKind(name)`: `en*` → "Network"（generic）；SystemConfiguration 不可用时走此路径 | 一致 | — |
| 220 | "Network byte counters prefer sysctl interface statistics and do not mark legacy getifaddrs fallback counters as authoritative" | SystemSampler.swift:733-754 | `interfaceStats[interfaceIndex]` 可用 → `hasByteCounters=true`；fallback 到 `getifaddrs if_data` → `hasByteCounters=false` | 一致 | — |
| 241 | "Network interface byte counters prefer public NET_RT_IFLIST2 64-bit interface counters ... legacy getifaddrs data is used only for non-byte metadata" | SystemSampler.swift:814-857,733-754 | `networkInterfaceStatsByIndex()` 用 `NET_RT_IFLIST2`；fallback `getifaddrs` 仅读 packets/errors/linkSpeed/mtu，不设 byte counters | 一致 | — |

### 1.4 "centralized on" 声明

| 行号 | 声明摘要 | 代码位置 | 一致性 |
|------|---------|---------|--------|
| 77 | "OS and kernel reported state is centralized on the shared snapshot model" | MetricSnapshot.swift:1490-1508 (`hasOSVersionReport`/`hasKernelReleaseReport`/`osVersionText`/`kernelText`) | 一致 |
| 124 | "GPU/display combined summary text is centralized on the shared snapshot model" | MetricSnapshot.swift:1578-1588 (`gpuDisplaySummaryText`) | 一致 |
| 135 | "Thermal display text is centralized on the shared snapshot model" | MetricSnapshot.swift:1231-1256 (`thermalText`/`thermalLimitText`/`hasThermalStateReport`) | 一致 |
| 136 | "Thermal reported state is centralized on the shared snapshot model" | 同上 | 一致 |
| 137 | "Thermal limit display text is centralized on the shared snapshot model" | 同上 | 一致 |
| 142 | "Running-app display text is centralized on the shared process model" | MetricSnapshot.swift:72-99 (`ProcessMetric.stateText`/`architectureText`/`launchText`) | 一致 |
| 150 | "Power reported state is centralized on the shared snapshot model" | MetricSnapshot.swift:1282-1327 (`hasPowerStatusReport`/`powerStatusText`/`powerStatusTone`) | 一致 |
| 160 | "Battery detail display text is centralized on the shared snapshot model" | MetricSnapshot.swift:1509-1560 | 一致 |
| 174 | "Storage volume reported state is centralized on the shared snapshot model" | MetricSnapshot.swift:1461-1478 | 一致 |
| 177 | "Storage volume kind and access display text is centralized on the shared volume model" | MetricSnapshot.swift:551-561 (`StorageVolumeMetric.kindText`/`accessText`) | 一致 |
| 190 | "Display reported state is centralized on the shared snapshot model" | MetricSnapshot.swift:1572-1593 | 一致 |
| 192 | "Display topology state text is centralized on the shared display model" | MetricSnapshot.swift:401-408 (`DisplayMetric.stateText`) | 一致 |
| 199 | "GPU device capability display text is centralized on the shared GPU model" | MetricSnapshot.swift:199-231 (`GPUDeviceMetric.kindText` 等) | 一致 |
| 215 | "Network path capability row display text is centralized on the shared snapshot model" | MetricSnapshot.swift:1383-1432 | 一致 |
| 218 | "Network path reported state is centralized on the shared snapshot model" | MetricSnapshot.swift:1332-1339 | 一致 |
| 226 | "Network local-rule display text is centralized on the shared snapshot model" | MetricSnapshot.swift:1398-1403 | 一致 |
| 230 | "Network interface state display text is centralized on the shared interface model" | MetricSnapshot.swift:714-718 (`NetworkInterfaceMetric.stateText`) | 一致 |
| 235 | "Network interface reported state is centralized on the shared snapshot model" | MetricSnapshot.swift:1600-1602 | 一致 |
| 255 | "Running-app summary display text is centralized on the shared snapshot model" | MetricSnapshot.swift:1170-1203 | 一致 |
| 276 | "Settings data-source display text is centralized on the shared snapshot model" | MetricSnapshot.swift:1138-1230 (各 `sourceStatusText`) | 一致 |

### 1.5 "legacy ... remain not-reported" 声明（Codable decodeIfPresent ?? derived 行为）

| 行号 | 声明摘要 | 代码位置 | 行为 | 一致性 |
|------|---------|---------|------|--------|
| 73 | "Legacy snapshots missing operating system version remain not-reported instead of borrowing the current machine OS version during decode" | MetricSnapshot.swift:1759 | `osVersion = ... ?? Self.placeholder.osVersion`("macOS")；`hasOSVersionReport` 排除 "macOS"；不调用 ProcessInfo | 一致 |
| 88 | "Legacy snapshots missing physical or logical CPU counts remain not-reported instead of borrowing the current machine counts during decode" | MetricSnapshot.swift:1678-1679 | `?? Self.placeholder.physicalCoreCount`(0)/`logicalCoreCount`(0)；`reportedCountText(0)` → notReported；不调用 sysctl | 一致 |
| 144 | "Legacy running-app snapshots missing state fields remain not-reported" | MetricSnapshot.swift:62-63 | `hasStateReport = ... ?? (hasActivationPolicyKey \|\| hasActiveKey \|\| hasHiddenKey)`；无 state key → false → notReported | 一致 |
| 145 | "Legacy running-app list records with no reported app fields remain not-reported" | MetricSnapshot.swift:91-99,101-103 | `hasInventoryReport` 检查 name/state/launchDate/policy/architecture | 一致 |
| 146 | "Legacy running-app snapshots with a list but missing count fields keep total, active, and hidden counts as not-reported" | MetricSnapshot.swift:1753 | `hasRunningAppCountReport = ... ?? (processCount>0 \|\| ...)`；空 list+缺失 count → false → notReported | 一致 |
| 175 | "Legacy storage volume records with no reported fields remain not-reported" | MetricSnapshot.swift:569-575 | `hasInventoryReport` 检查 fileSystem/capacity/kind/access/isPrimary | 一致 |
| 178 | "Legacy storage volume snapshots missing kind or access flags remain not-reported" | MetricSnapshot.swift:500-502 | `hasKindReport = ... ?? (hasInternalKey \|\| ...)`；`hasAccessReport = ... ?? hasReadOnlyKey` | 一致 |
| 191 | "Legacy display inventory records with no reported display fields remain not-reported" | MetricSnapshot.swift:410-424 | `hasInventoryReport` 检查各字段 | 一致 |
| 194 | "Legacy display snapshots missing topology or rotation fields remain not-reported" | MetricSnapshot.swift:350-352 | `hasTopologyReport = ... ?? (hasBuiltinKey && hasMainKey && hasMirroredKey)`；`hasRotationReport = ... ?? hasRotationKey` | 一致 |
| 201 | "Legacy GPU device snapshots missing capability flags remain not-reported" | MetricSnapshot.swift:189-192 | `hasDeviceKindReport = ... ?? ((hasLowPowerKey && isLowPower) \|\| ...)` | 一致 |
| 204 | "Legacy GPU inventory records with no reported device fields remain not-reported" | MetricSnapshot.swift:233-243 | `hasInventoryReport` 检查各字段 | 一致 |
| 212 | "Legacy network path snapshots missing DNS, IPv4, or IPv6 support flags remain not-reported" | MetricSnapshot.swift:1728-1729 | `hasNetworkPathSupportReport = ... ?? (hasDNSKey && hasIPv4Key && hasIPv6Key)` | 一致 |
| 214 | "Legacy network path snapshots missing low-data-mode or metered-network flags remain not-reported" | MetricSnapshot.swift:1720-1721 | `hasNetworkPathCostReport = ... ?? (hasExpensiveKey && hasConstrainedKey)` | 一致 |
| 232 | "Legacy network interface snapshots missing state flags remain not-reported" | MetricSnapshot.swift:663-664 | `hasInterfaceStateReport = ... ?? (hasUpKey \|\| hasLoopbackKey)` | 一致 |
| 258 | "Legacy memory snapshots missing composition fields keep free, wired, compressed, and cached memory as not-reported" | MetricSnapshot.swift:1691-1695 | `hasMemoryCompositionReport = ... ?? (contains(free) && contains(wired) && contains(compressed) && contains(cached))` | 一致 |

### 1.6 关键行为声明核对（抽样）

| 行号 | 声明摘要 | 代码位置 | 一致性 | 备注 |
|------|---------|---------|--------|------|
| 62 | "Main app and widget snapshots warm the sampler before publishing delta-based CPU/network readings" | MetricsStore.swift:300-313 | 一致 | `startInitialRefresh()` detached 调用 `sampler.sample()` 预热，sleep 150ms，再 `refresh()` |
| 63 | "Refresh ticks that arrive while sampling is in flight queue one follow-up refresh" | MetricsStore.swift:330-333,347,360-362 | 一致 | `pendingRefreshAfterCurrent = true` → 完成后 `if shouldRunPendingRefresh { refresh() }` |
| 64 | "Sample timestamp display text reports the system-not-reported state for placeholder or missing timestamp snapshots" | MetricSnapshot.swift:1479-1485 | 一致 | `hasSampleTimeReport = timestamp.timeIntervalSince1970 > 0`；placeholder timestamp=1970 |
| 68 | "Static inventory sampling is cached ... 15-second TTL while CPU, memory, network, thermal, uptime, and load remain sampled on each visible refresh" | SystemSampler.swift:237,926-965 | 一致 | `inventoryCacheInterval=15`；storage/gpu/display/descriptor 缓存；CPU/mem/net/thermal/uptime/load 每次采 |
| 69 | "Battery and power sampling uses a short cache ... 5-second" | SystemSampler.swift:237,936-945 | 一致 | `batteryCacheInterval=5` |
| 70 | "Static system information is sampled once per sampler instance" | SystemSampler.swift:229,253,582-590 | 一致 | `systemInfo` 在 init 中设置，不更新；`activeProcessorCount` 每次 live |
| 71 | "System uptime ... requires the System Boot Time required-reason entry because the shared sampler is used by both the app and Widget extension" | SystemSampler.swift:298,376；PrivacyInfo.xcprivacy（两份） | 一致 | 两份 PrivacyInfo 均声明 `35F9.1` |
| 85 | "CPU active processor count uses ProcessInfo.activeProcessorCount ... separate from the hardware logical-core count" | SystemSampler.swift:306,384,585 | 一致 | `activeProcessorCount` = `ProcessInfo.processInfo.activeProcessorCount`(live)；`logicalCoreCount` = sysctl `hw.logicalcpu`(once) |
| 89 | "CPU usage text reports the system-not-reported state when Mach CPU counters have not produced a delta sample" | SystemSampler.swift:471-474,506-507；MetricSnapshot.swift:1077-1080 | 一致 | priming 时 `isReported:false`；`cpuText` 检查 `hasCPUUsageReport` |
| 90 | "MetricSnapshot initializer defaults CPU usage to not-reported unless a sampler explicitly reports a Mach CPU delta sample" | MetricSnapshot.swift:818 | 一致 | `hasCPUUsageReport: Bool = false` 默认 |
| 118 | "The CPU sampler returns no per-core usage list while it is only priming Mach CPU tick baselines" | SystemSampler.swift:471-474 | 一致 | priming 返回 `(0, [], isReported:false)` — 空 list 非合成零值 |
| 131 | "The main app writes a compact latest snapshot to App Group UserDefaults on a 60-second throttled cadence and asks WidgetKit to reload its timeline kind after shared writes" | MetricsStore.swift:67,69,366-376,432-443 | **部分一致** | **D3**：write 和 reload 均为 60s 独立节流，非"write 后触发 reload"。`saveSharedSnapshotIfNeeded` 和 `reloadWidgetsIfNeeded` 顺序调用但各自维护 `lastSharedSnapshotWriteDate`/`lastWidgetReloadDate`。reload 可在 write 被节流时仍触发，也可在 write 失败（`_ =` 丢弃返回值）时仍触发。文档措辞"after shared writes"暗示因果触发，实际是独立节流。实践中因两者均为 60s 且 1/2/5s 均整除 60，通常同步触发 |
| 132 | "Shared widget snapshot writes return a success flag and log DEBUG-only encoding failures" | SharedSnapshotStore.swift:37-52 | 一致 | `saveLatestSnapshot` 返回 `Bool`，`#if DEBUG print(...)`。但调用方 MetricsStore.swift:375 `_ =` 丢弃返回值（属代码缺陷 P2-8，非文档漂移） |
| 133 | "Shared widget snapshots tolerate small system clock skew while still rejecting stale or far-future data" | SharedSnapshotStore.swift:11,62-65 | 一致 | `acceptedFutureSkew: TimeInterval = 300`；`age <= maxAge, age >= -acceptedFutureSkew` |
| 162 | "Battery charging state is only displayed when the public power-source description reports kIOPSIsChargingKey; AC power alone is not treated as charging" | SystemSampler.swift:646-647 | 一致 | `reportedIsCharging = description[kIOPSIsChargingKey] as? Bool`；`isCharging = reportedIsCharging ?? false` |
| 266 | "Sanitized trend history resets OS version and Darwin kernel release to shared not-reported placeholders" | MetricsStore.swift:284-285 | 一致 | `osVersion: MetricSnapshot.placeholder.osVersion`("macOS")；`kernelRelease: MetricSnapshot.placeholder.kernelRelease`("") |
| 267 | "Persisted trend history preserves CPU reported-state flags" | MetricsStore.swift:226-227 | 一致 | `hasCPUUsageReport: snapshot.hasCPUUsageReport` |
| 268 | "Persisted trend history preserves sampled active processor count" | MetricsStore.swift:230 | 一致 | `activeProcessorCount: snapshot.activeProcessorCount` |
| 269 | "Legacy persisted history without sampled active processor count is excluded from load-average trend normalization" | MetricSnapshot.swift:1121-1124,1680 | 一致 | decoder `?? Self.placeholder.activeProcessorCount`(0)；`reportedLoadProgress` 要求 `activeProcessorCount > 0` |
| 274 | "The app does not request notification permissions or badge privileges" | Sources/ 全文 | 一致 | 无 UNUserNotificationCenter 代码 |

### 1.7 Privacy Manifest Scope 声明（行 518-524）

| 行号 | 声明摘要 | 代码位置 | 一致性 |
|------|---------|---------|--------|
| 520 | "Main app: Disk Space 85F4.1, UserDefaults CA92.1, and System Boot Time 35F9.1" | Resources/App/PrivacyInfo.xcprivacy:5-31 | 一致 |
| 521 | "Widget extension: Disk Space 85F4.1, UserDefaults CA92.1, and System Boot Time 35F9.1" | Resources/Widget/PrivacyInfo.xcprivacy:5-31 | 一致 |
| 522 | "Both targets declare no collected data and no tracking" | 两份 PrivacyInfo.xcprivacy:32-37 | 一致 | `NSPrivacyCollectedDataTypes=[]`/`NSPrivacyTracking=false`/`NSPrivacyTrackingDomains=[]` |
| 523 | "app Info.plist carries stable public privacy and support URLs" | Resources/AppInfo.plist:41-44；PulseDockLinks.swift:5-14 | 一致 | `PulseDockPrivacyPolicyURL`/`PulseDockSupportURL` key 读取 |
| 524 | "ITSAppUsesNonExemptEncryption is set to false" | AppInfo.plist:31-32；WidgetInfo.plist:29-30 | 一致 |

### 1.8 Refresh Policy 声明（行 509-516）

| 行号 | 声明摘要 | 代码位置 | 一致性 |
|------|---------|---------|--------|
| 511 | "Main app refresh: user-selectable 1/2/5 seconds with timer tolerance" | MetricsStore.swift:12-20,290-298 | 一致 | `RefreshIntervalOption: quick=1/balanced=2/relaxed=5`；`tolerance = min(seconds*0.18, 0.5)` |
| 512 | "Widget timeline: 5 minutes" | SystemDashboardWidget.swift:58 | 一致 | `byAdding: .minute, value: 5` |
| 513 | "Shared widget snapshot write and Widget reload request from app: throttled to 60 seconds" | MetricsStore.swift:67,69 | 一致 | `widgetReloadInterval=60`/`sharedSnapshotWriteInterval=60` |
| 514 | "Shared widget snapshot storage checks the production bundle identifier and App Group container availability before creating suite UserDefaults" | SharedSnapshotStore.swift:24-34；PulseDockAppGroup.swift:8-10 | 一致 | `supportsAppGroup` 严格匹配 bundleID + `containerURL` 检查 |
| 515 | "Trend history persistence: throttled to 15 seconds, with forced writes when sampling stops or history depth changes" | MetricsStore.swift:68,106-112,119,158,394-420 | 一致 | `historyPersistenceInterval=15`；`stopForTermination`/`togglePause`(pause)/`updateHistoryDepth` 调 `force:true` |

---

## 二、README vs 代码

| README 声明 | 代码位置 | 行为 | 一致性 | 差异描述 |
|------------|---------|------|--------|---------|
| :3 "shows local CPU, memory, storage, network, battery, thermal, display, GPU, uptime, and running app status using public macOS APIs" | SystemSampler.swift 全文 | 全部通过 Mach/IOKit/Metal/CG/NSScreen/NWPath/SystemConfiguration 公共 API 采样 | 一致 | — |
| :9-10 "Native macOS app target: PulseDock / Widget extension target: PulseDockWidgetExtension" | PulseDock.xcodeproj/project.pbxproj:587,627 | bundle ID 分别为 `com.ifonly3.pulsedock`/`com.ifonly3.pulsedock.widget` | 一致 | — |
| :11 "SwiftPM package: PulseDock" | Package.swift:6 | `name: "PulseDock"` | 一致 | — |
| :12 "Minimum macOS version: 14.0" | Package.swift:9；PulseDock.xcodeproj/project.pbxproj:585,606,625,644；AppInfo.plist:33-34 | `.macOS(.v14)`/`MACOSX_DEPLOYMENT_TARGET=14.0`/`LSMinimumSystemVersion=14.0` | 一致 | 三处统一 |
| :14-15 "App: com.ifonly3.pulsedock / Widget: com.ifonly3.pulsedock.widget" | PulseDockAppGroup.swift:5-6；PulseDock.xcodeproj/project.pbxproj:587,627 | 完全匹配 | 一致 | — |
| :61 "does not create accounts" | Sources/ 全文 grep `account\|signIn\|login` | 仅 PulseDockAppStrings.swift:947 用户可见文案 "no account"；无账户/认证逻辑 | 一致 | — |
| :61 "does not ... collect personal data" | SystemSampler.swift 全文；MetricSnapshot.swift 全文 | 采样系统指标（CPU/mem/disk/net/battery/thermal/display/GPU/uptime/apps），不涉及用户个人数据；`NSPrivacyCollectedDataTypes=[]` | 一致 | — |
| :61 "does not ... track users" | 两份 PrivacyInfo.xcprivacy:34-37 | `NSPrivacyTracking=false`/`NSPrivacyTrackingDomains=[]`；无 IDFA/advertisingIdentifier/tracking 代码 | 一致 | — |
| :61 "does not ... run analytics" | Sources/ 全文 grep `analytics\|telemetry\|crashReport` | 无 analytics/telemetry/crashReport 代码 | 一致 | — |
| :61 "does not ... send remote probes" | SystemSampler.swift:148-219 | `NWPathMonitor` 监听系统网络状态，不发送 DNS/ping/latency/outbound 流量；data-capability-audit.md:208 明确声明 | 一致 | NWPathMonitor 不发起外部连接，措辞精确 |
| :63 "Privacy policy URL: https://ifonly3.github.io/pulsedock/privacy-policy/" | AppInfo.plist:42；PulseDockLinks.swift:5,8-10 | Info.plist `PulseDockPrivacyPolicyURL` key 存储该 URL；PulseDockLinks 读取并校验 https scheme | 一致 | — |
| :64 "Support URL: https://ifonly3.github.io/pulsedock/support/" | AppInfo.plist:44；PulseDockLinks.swift:6,12-14 | 同上 | 一致 | — |

---

## 三、PrivacyInfo.xcprivacy vs 实际行为

| 检查项 | App PrivacyInfo | Widget PrivacyInfo | 实际行为 | 一致性 |
|--------|----------------|-------------------|---------|--------|
| NSPrivacyCollectedDataTypes | `[]`（空） | `[]`（空） | 无数据采集/上传 | 一致 — 与 README:61 "does not collect personal data" 一致 |
| NSPrivacyTracking | `false` | `false` | 无追踪代码 | 一致 — 与 README:61 "does not track users" 一致 |
| NSPrivacyTrackingDomains | `[]`（空） | `[]`（空） | 无远程连接 | 一致 |
| NSPrivacyAccessedAPICategoryDiskSpace `85F4.1` | 已声明 | 已声明 | `FileManager.attributesOfFileSystem(forPath:)`(SystemSampler.swift:901-910)；`FileManager.mountedVolumeURLs`(SystemSampler.swift:985-988) | 一致 — app 和 widget 均使用 disk space API |
| NSPrivacyAccessedAPICategoryUserDefaults `CA92.1` | 已声明 | 已声明 | `UserDefaults.standard`(MetricsStore.swift)；`UserDefaults(suiteName:)`(SharedSnapshotStore.swift:34) | 一致 — app 和 widget 均使用 UserDefaults |
| NSPrivacyAccessedAPICategorySystemBootTime `35F9.1` | 已声明 | 已声明 | `ProcessInfo.processInfo.systemUptime`(SystemSampler.swift:298,376) | 一致 — app 和 widget 均使用 system uptime |
| 是否遗漏 required-reason API | — | — | IOKit/Metal/Network/CoreGraphics/SystemConfiguration/Mach/sysctl/getifaddrs/uname 均不在 Apple 当前 required-reason 列表 | 一致 — 无遗漏 |
| ITSAppUsesNonExemptEncryption | AppInfo.plist:31-32 `false` | WidgetInfo.plist:29-30 `false` | 无自定义加密 | 一致 — 与 data-capability-audit.md:524 一致 |

---

## 四、entitlements 最小权限检查

| entitlements 项 | App (PulseDock.entitlements) | Widget (PulseDockWidgetExtension.entitlements) | 必要性 | 一致性 |
|----------------|----------------------------|-----------------------------------------------|--------|--------|
| `com.apple.security.app-sandbox` | `true` | `true` | App Store 必需 | 一致 — 最小权限 |
| `com.apple.security.application-groups` | `["group.com.ifonly3.pulsedock"]` | `["group.com.ifonly3.pulsedock"]` | widget 共享 snapshot 必需 | 一致 — 与 PulseDockAppGroup.swift:4 匹配 |
| network client/server | **未声明** | **未声明** | 不需要（无远程连接） | 一致 — 与 README "no remote probes" 一致 |
| camera/microphone/photos/contacts/location | **未声明** | **未声明** | 不需要 | 一致 |
| file access (read-write user-selected) | **未声明** | **未声明** | 不需要 | 一致 |
| temporary-exception entitlements | **未声明** | **未声明** | 不需要 | 一致 — 与 release-checklist:25 "No temporary sandbox exception entitlements" 一致 |
| 比对 bundle ID | `group.com.ifonly3.pulsedock` 与 app bundle ID `com.ifonly3.pulsedock` 前缀一致 | 同上 | App Group 命名规范 | 一致 |

**结论**：entitlements 为最小权限集，仅 sandbox + app-group，无多余权限。

---

## 五、checklist 完整性

### 5.1 readiness-checklist vs 代码可验证行为

| checklist 项 | 代码验证点 | 一致性 |
|-------------|-----------|--------|
| [x] Widget reads shared latest app snapshot through App Group with self-sampling fallback | SystemDashboardWidget.swift:63-66 | 一致 |
| [x] App Group provisioning prerequisite documented for production signing | PulseDockAppGroup.swift:8-10 严格匹配 + SharedSnapshotStore.swift:24-34 container 检查 | 一致 |
| [x] Threshold copy says "阈值判断"/"状态判断" for v1 and does not imply system notifications | Sources/ 无 UNUserNotificationCenter 代码 | 一致 |
| [x] Local notifications are deferred to a future opt-in feature | 同上 | 一致 |
| [x] Disk fallback no longer uses NSHomeDirectory string path | SystemSampler.swift:902 `FileManager.default.homeDirectoryForCurrentUser.path` | 一致 |
| [x] Source folders renamed to Sources/PulseDockApp and Sources/PulseDockWidget | glob 确认目录存在 | 一致 |
| [x] Repository-local GitHub Pages sources for support and privacy URLs | docs/privacy-policy/index.html + docs/support/index.html 存在且 URL 匹配 | 一致 |

### 5.2 release-checklist vs 代码可验证行为

| checklist 项 | 代码验证点 | 一致性 |
|-------------|-----------|--------|
| App Sandbox enabled for both targets | 两份 entitlements: `app-sandbox=true` | 一致 |
| App Group entitlement declared with suite `group.com.ifonly3.pulsedock` | 两份 entitlements + PulseDockAppGroup.swift:4 | 一致 |
| No temporary sandbox exception entitlements | entitlements 无 temporary-exception | 一致 |
| Privacy manifests included in both targets | 两份 PrivacyInfo.xcprivacy + pbxproj:377,390 引用 | 一致 |
| Both targets declare no collected data and no tracking | 两份 PrivacyInfo.xcprivacy `NSPrivacyCollectedDataTypes=[]`/`NSPrivacyTracking=false` | 一致 |
| App: Disk Space 85F4.1, UserDefaults CA92.1, System Boot Time 35F9.1 | App PrivacyInfo.xcprivacy | 一致 |
| Widget: 同上 | Widget PrivacyInfo.xcprivacy | 一致 |
| Default generated bundle IDs: com.ifonly3.pulsedock / .widget | pbxproj:587,627 | 一致 |
| Minimum macOS version: 14.0 | pbxproj MACOSX_DEPLOYMENT_TARGET=14.0 | 一致 |
| ITSAppUsesNonExemptEncryption declared as false | AppInfo.plist:31-32 | 一致 |
| Privacy policy URL: https://ifonly3.github.io/pulsedock/privacy-policy/ | AppInfo.plist:42 | 一致 |
| Support URL: https://ifonly3.github.io/pulsedock/support/ | AppInfo.plist:44 | 一致 |
| Source folders: Sources/PulseDockApp and Sources/PulseDockWidget | glob 确认 | 一致 |
| Local adhoc signing verifies entitlement shape only; functional App Group sharing must be verified with Xcode automatic signing, TestFlight, or an App Store-signed archive | SharedSnapshotStore.swift:29-32 `containerURL` 检查在本地无 provisioning 时返回 nil → `defaults=nil` 静默降级 | 一致 — 外部验证项无法在代码层验证，但降级行为与 checklist 描述一致 |

### 5.3 readiness-checklist "Still Open" 项 vs 代码

| checklist 项 | 代码现状 | 一致性 |
|-------------|---------|--------|
| [ ] Future: design opt-in local threshold notifications | 未实现（无通知代码） | 一致 — 正确标记为未实现 |
| [ ] If shipping v1 globally, complete a separate full localization sprint | AppInfo.plist:8-12 声明 en+zh-Hans | 一致 — 基础设施已声明，内容审计待完成 |
| [ ] External: publish GitHub Pages privacy/support URLs | docs/privacy-policy/index.html + docs/support/index.html 仓库内源存在 | 一致 — 仓库内源已就绪，发布为外部步骤 |
| [ ] External: verify App Group sharing with production provisioning | PulseDockAppGroup.swift:8-10 严格匹配逻辑存在 | 一致 — 代码侧就绪，外部验证为 provisioning 步骤 |

---

## 六、与 REVIEW-PLAN.md 重叠项

| REVIEW-PLAN.md 条目 | L5 验证结果 | 重叠说明 |
|---------------------|-----------|---------|
| **P0-1**（SystemSampler.swift NSScreen 主线程守卫，detached 采样下 display 元数据丢失） | **已修复** — SystemSampler.swift:1101-1113 通过 `DispatchQueue.main.sync` 桥接主线程；data-capability-audit.md:183 文档描述与当前代码一致 | **C2 锚点确认**：前次 review 标记的文档-代码漂移已消除 |
| **P1-3**（PulseDockAppGroup.swift:8-10 严格匹配 + SharedSnapshotStore 静默失败） | data-capability-audit.md:514 准确描述 bundle identifier + container availability 检查；README:14-15 bundle ID 与 PulseDockAppGroup.swift:5-6 一致 | 文档准确描述了严格匹配行为；P1-3 的"静默失败"风险是代码缺陷而非文档漂移 |
| **P2-8**（MetricsStore.swift:375 `_ =` 丢弃 saveLatestSnapshot 返回值） | data-capability-audit.md:132 准确描述 API 返回 success flag + DEBUG 日志；调用方丢弃返回值是代码缺陷 | 文档描述 API 行为准确，调用方行为缺陷不影响文档一致性 |
| **P2-11**（SharedSnapshotStore release 下 save/load 失败静默，无 schema 版本字段） | MetricSnapshot.swift:748 有 `schemaVersion` 字段（=1）；decoder:1673 `decodeIfPresent ?? currentSchemaVersion` | data-capability-audit.md 未声明 schema 版本策略，但代码有 schemaVersion 字段。P2-11 关于"无 schema 版本字段"的描述与代码不完全一致（字段存在但未用于版本迁移） |
| **P1-2**（无 NSWorkspaceDidWakeNotification/屏幕变更观察） | **已修复** — AppDelegate.swift:90-103 `registerSystemEventObservers` 注册 `didWakeNotification`+`didChangeScreenParametersNotification`；MetricsStore.swift:130-140 `handleSystemWake`/`handleScreenConfigurationChange` | 文档未显式声明系统事件观察，但代码已实现，无漂移 |
| **P0-2**（Widget 同步 fallback sampler 跑完整 SystemSampler 路径） | data-capability-audit.md:59 准确描述 widget fallback 使用 compact in-extension sampling 跳过 GPU/display/volumes/running apps；SystemSampler.swift:362-443 `sampleWidgetCompact` 确实跳过这些 | 文档准确；P0-2 关于"同步阻塞 watchdog 风险"是代码缺陷（SystemDashboardWidget.swift:53 `DispatchQueue.global().async` 内同步采样），非文档漂移 |
| **D1**（GPU/display Surfaces 列含 widgets） | 本报告新发现 | REVIEW-PLAN.md 未提及此文档漂移 |
| **D2**（Storage Surfaces 列缺 widgets） | 本报告新发现 | REVIEW-PLAN.md 未提及此文档漂移 |
| **D3**（line 131 "after shared writes" 措辞） | 本报告新发现 | REVIEW-PLAN.md 未提及此文档措辞漂移 |

---

## 七、发现汇总

### 7.1 文档-代码漂移（3 条）

| ID | 行号 | 严重度 | 声明 | 实际行为 | 建议 |
|----|------|--------|------|---------|------|
| **D1** | data-capability-audit.md:27 | 低 | GPU and display Surfaces 列包含 "widgets" | SystemDashboardWidget.swift 全文无 GPU/display 字段引用；`sampleWidgetCompact`/`widgetCompactSnapshot` 均裁空 `gpuDevices`/`displays` | 从 Surfaces 列移除 "widgets" |
| **D2** | data-capability-audit.md:23 | 低 | Storage Surfaces 列: "Overview, Storage page, Status page, Settings page"（无 widgets） | SystemDashboardWidget.swift:222,257 MediumWidget+LargeWidget 显示 `diskUsageText`（primary disk usage）；Storage 行数据首项为 "Primary disk free/total" | 在 Surfaces 列添加 "widgets"（仅 primary disk 部分），与 CPU/Memory 行列出 widgets 的标准一致 |
| **D3** | data-capability-audit.md:131 | 极低 | "asks WidgetKit to reload its timeline kind after shared writes" 暗示 reload 由 write 触发 | MetricsStore.swift:366-376,432-443 write 和 reload 各自独立 60s 节流，非因果触发；reload 可在 write 被节流/失败时仍触发 | 改为 "on a 60-second throttled cadence, independently of shared writes" 或 "throttled to 60 seconds alongside shared writes" |

### 7.2 已验证一致的声明（0 条漂移）

- **C2 锚点（行 183）**：display 元数据主线程快照声明 — **已修复，与代码一致**（`DispatchQueue.main.sync` 桥接 detached 采样）
- 所有 "does not store/collect/perform" 否定声明（15+ 条）— **全部一致**
- 所有 "first ... then fallback" 顺序声明（11 条）— **全部一致**
- 所有 "centralized on" 位置声明（20 条）— **全部一致**
- 所有 "legacy ... remain not-reported" 声明（15 条）— **全部一致**
- README 隐私声明（no accounts/personal data/tracking/analytics/remote probes）— **全部一致**
- PrivacyInfo.xcprivacy（3 个 required-reason API + 无采集 + 无追踪）— **全部一致**
- entitlements 最小权限（sandbox + app-group only）— **一致**
- checklist 完整性（readiness + release）— **全部一致**
- bundle ID 三处一致（README / PulseDockAppGroup.swift / pbxproj / entitlements）
- 最低 macOS 版本三处一致（README / Package.swift / pbxproj / Info.plist）
- 隐私/支持 URL 三处一致（README / AppInfo.plist / PulseDockLinks.swift）
- Refresh Policy 5 条声明 — **全部一致**

### 7.3 统计

- 核对声明总数：~120 条
- 一致：~117 条
- 漂移：3 条（D1/D2/D3，均为低/极低严重度的 Surfaces 列/措辞问题）
- 否定声明全部一致：无任何"文档说不做但代码实际做了"的漂移
- 隐私声明全部一致：README/PrivacyInfo/privacy-policy/code 四层一致

---

## 八、结论

data-capability-audit.md 整体与代码行为高度一致。前次 review P0-1 标记的 display 元数据文档-代码漂移（C2 锚点）已通过 `DispatchQueue.main.sync` 桥接修复，文档描述现在准确反映代码行为。

3 条新发现的漂移均为低严重度的表格 Surfaces 列覆盖问题（D1/D2）和措辞精度问题（D3），不涉及隐私声明、安全声明或功能声明的实质性漂移。所有否定声明（不存储/不采集/不执行）与代码完全一致，隐私合规层面无文档-代码漂移风险。
