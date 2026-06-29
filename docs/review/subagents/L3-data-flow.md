# L3 — 数据字段端到端一致性报告

> 审查日期：2026-06-28
> 审查范围：MetricSnapshot 全字段从 sampler 赋值 → init → Codable 编解码 → SharedSnapshotStore 持久化 → widgetCompactSnapshot 裁剪 → widget 读取的完整链路
> 审查方法：逐字段追踪单位/量纲/裁剪/编解码策略不一致

---

## 一、字段清单与量纲

从 `MetricSnapshot.swift:747-813` 存储属性声明 + `:815-960` init 参数 + `:1671-1762` Codable decode 提取：

| 字段 | 类型 | 单位 | 报告状态属性 | init 默认值 |
|------|------|------|-------------|------------|
| schemaVersion | Int | n/a | n/a | currentSchemaVersion(=1) |
| cpuUsage | Double | 0-1 分数 | hasCPUUsageReport | 必填(无默认) |
| cpuCoreUsages | [Double] | 0-1 分数数组 | hasCPUUsageReport | [] |
| hasCPUUsageReport | Bool | n/a | (自身) | false |
| physicalCoreCount | Int | 核数 | n/a | 0 |
| logicalCoreCount | Int | 核数 | n/a | 0 |
| activeProcessorCount | Int | 核数 | n/a | 0 |
| cpuBrandName | String? | 字符串 | n/a | nil |
| memoryUsedBytes | UInt64 | bytes | hasMemoryUsageReport(派生: memoryTotalBytes>0) | 必填 |
| memoryTotalBytes | UInt64 | bytes | hasMemoryUsageReport(派生) | 必填 |
| memoryFreeBytes | UInt64 | bytes | hasMemoryCompositionReport | 0 |
| memoryWiredBytes | UInt64 | bytes | hasMemoryCompositionReport | 0 |
| memoryCompressedBytes | UInt64 | bytes | hasMemoryCompositionReport | 0 |
| memoryCachedBytes | UInt64 | bytes | hasMemoryCompositionReport | 0 |
| memorySwapUsedBytes | UInt64 | bytes | hasMemorySwapReport(派生: swapTotal>0) | 0 |
| memorySwapTotalBytes | UInt64 | bytes | hasMemorySwapReport(派生) | 0 |
| memorySwapAvailableBytes | UInt64 | bytes | hasMemorySwapReport(派生) | 0 |
| hasMemoryCompositionReport | Bool | n/a | (自身) | false |
| loadAverage | Double | load(1min) | hasLoadAverageReport | 必填 |
| loadAverage5 | Double | load(5min) | hasLoadAverageReport | 0 |
| loadAverage15 | Double | load(15min) | hasLoadAverageReport | 0 |
| hasLoadAverageReport | Bool | n/a | (自身) | false(但 init 做 OR 派生) |
| thermalState | String | 枚举(Nominal/Warm/Hot/Critical/Unknown) | hasThermalStateReport(派生) | 必填 |
| batteryPercent | Double? | **0-1 分数** | hasPowerStatusReport(派生) | nil |
| batteryIsCharging | Bool | bool | n/a | 必填 |
| batteryPowerSource | String? | 枚举(AC Power/Battery Power/UPS Power) | hasPowerStatusReport(派生) | nil |
| batteryTimeRemainingMinutes | Int? | 分钟 | n/a | nil |
| batteryCycleCount | Int? | 次数 | n/a | nil |
| batteryHealth | String? | 枚举(Good/Fair/Poor/Check Battery/Permanent Battery Failure) | n/a | nil |
| batteryCurrentCapacity | Int? | mAh(相对) | n/a | nil |
| batteryMaxCapacity | Int? | mAh | n/a | nil |
| batteryDesignCapacity | Int? | mAh | n/a | nil |
| batteryVoltageMillivolts | Int? | mV | n/a | nil |
| batteryAmperageMilliamps | Int? | mA | n/a | nil |
| networkBytesPerSecond | UInt64 | **bytes/s** | hasNetworkByteCounters | 0 |
| hasNetworkByteCounters | Bool | n/a | (自身) | false(但 init 做 OR 派生) |
| hasNetworkDirectionByteCounters | Bool | n/a | (自身) | nil→OR 派生 |
| networkPathStatus | String | 枚举(satisfied/unsatisfied/requiresConnection/unknown) | hasNetworkPathReport(派生) | "unknown" |
| networkPathIsExpensive | Bool | bool | hasNetworkPathCostReport | false |
| networkPathIsConstrained | Bool | bool | hasNetworkPathCostReport | false |
| hasNetworkPathCostReport | Bool | n/a | (自身) | false |
| networkPathSupportsDNS | Bool | bool | hasNetworkPathSupportReport | false |
| networkPathSupportsIPv4 | Bool | bool | hasNetworkPathSupportReport | false |
| networkPathSupportsIPv6 | Bool | bool | hasNetworkPathSupportReport | false |
| hasNetworkPathSupportReport | Bool | n/a | (自身) | false |
| networkPathInterfaceKinds | [String] | 字符串列表 | n/a | [] |
| networkInBytesPerSecond | UInt64 | bytes/s | hasNetworkDirectionByteCounters | 0 |
| networkOutBytesPerSecond | UInt64 | bytes/s | hasNetworkDirectionByteCounters | 0 |
| networkInterfaces | [NetworkInterfaceMetric] | 列表 | hasNetworkInterfaceReport(派生) | [] |
| diskFreeBytes | UInt64 | bytes | hasDiskUsageReport(派生: total>0 && free<=total) | 必填 |
| diskTotalBytes | UInt64 | bytes | hasDiskUsageReport(派生) | 0 |
| storageVolumes | [StorageVolumeMetric] | 列表 | hasStorageVolumeReport(派生) | [] |
| processCount | Int | 进程数 | hasRunningAppCountReport(OR 派生) | 0 |
| activeApplicationCount | Int | app 数 | hasRunningAppCountReport(OR 派生) | 0 |
| hiddenApplicationCount | Int | app 数 | hasRunningAppCountReport(OR 派生) | 0 |
| hasRunningAppCountReport | Bool | n/a | (自身) | false(但 init 做 OR 派生) |
| runningApps | [ProcessMetric] | 列表(Codable key="topProcesses") | hasRunningAppReport(派生) | [] |
| gpuDevices | [GPUDeviceMetric] | 列表 | hasGPUReport(派生) | [] |
| displays | [DisplayMetric] | 列表 | hasDisplayReport(派生) | [] |
| uptimeSeconds | TimeInterval | **秒** | hasUptimeReport(OR 派生) | 0 |
| hasUptimeReport | Bool | n/a | (自身) | false(但 init 做 OR 派生) |
| osVersion | String | 字符串 | hasOSVersionReport(派生) | "" |
| kernelRelease | String | 字符串 | hasKernelReleaseReport(派生) | "" |
| timestamp | Date | 日期 | hasSampleTimeReport(派生) | 必填 |

---

## 二、字段端到端追踪表

> 路径：sampler 赋值(SystemSampler.swift) → init 默认(MetricSnapshot.swift:815-960) → Codable decode(:1671-1762) → store 持久化(SharedSnapshotStore.swift) → widgetCompact 裁剪(MetricSnapshot+WidgetCompact.swift:4-60) → widget 读取(SystemDashboardWidget.swift)

| 字段 | sampler 赋值点 | init 默认 | Codable decode | store 持久化 | widgetCompact 裁剪 | widget 读取 | 不一致点 |
|------|---------------|-----------|---------------|-------------|-------------------|------------|---------|
| cpuUsage | :301 `cpu.total`(0-1) | 必填 | :1674 `?? placeholder.cpuUsage(0)` | JSON 编解码 | :6 保留 | :179,255 `cpuText`/`cpuUsage` | 无 |
| cpuCoreUsages | :302 `cpu.cores` | [] | :1675 `?? []` | JSON | :7 保留 | 不直接读取 | 无 |
| hasCPUUsageReport | :303 `cpu.isReported` | 直接赋值(无派生) | :1676 `?? (cpuUsage>0 \|\| !cores.isEmpty)` OR 派生 | JSON | :8 保留 | :179,255 `hasCPUUsageReport` | **L3-4** init=direct vs Codable=OR |
| physicalCoreCount | :304 | 0 | :1678 `?? placeholder(0)` | JSON | :9 保留 | 不读取 | 无 |
| logicalCoreCount | :305 | 0 | :1679 `?? placeholder(0)` | JSON | :10 保留 | :209 `logicalCoreSummaryText` | 无 |
| activeProcessorCount | :306 | 0 | :1680 `?? placeholder(0)` | JSON | :11 保留 | 用于 loadAverageProgress 分母 | 无 |
| cpuBrandName | :307 | nil | :1681 `?? nil` | JSON | :12 **置 nil** | 不读取 | 无(当前安全) |
| memoryUsedBytes | :308 | 必填 | :1682 `?? placeholder(0)` | JSON | :13 保留 | :180,220,256 `memoryUsage` | 无 |
| memoryTotalBytes | :309 | 必填 | :1683 `?? placeholder(0)` | JSON | :14 保留 | :180,220,256 | 无 |
| memoryFreeBytes | :310 | 0 | :1684 `?? 0` | JSON | **未传递→0** | 不读取 | **L3-1** 裁剪后依赖 init 默认 |
| memoryWiredBytes | :311 | 0 | :1685 `?? 0` | JSON | **未传递→0** | 不读取 | **L3-1** |
| memoryCompressedBytes | :312 | 0 | :1686 `?? 0` | JSON | **未传递→0** | 不读取 | **L3-1** |
| memoryCachedBytes | :313 | 0 | :1687 `?? 0` | JSON | **未传递→0** | 不读取 | **L3-1** |
| memorySwapUsedBytes | :314 | 0 | :1688 `?? 0` | JSON | :15 保留 | 不读取 | 无 |
| memorySwapTotalBytes | :315 | 0 | :1689 `?? 0` | JSON | :16 保留 | 不读取 | 无 |
| memorySwapAvailableBytes | :316 | 0 | :1690 `?? 0` | JSON | :17 保留 | 不读取 | 无 |
| hasMemoryCompositionReport | :317 | 直接赋值(无派生) | :1691 `?? (contains 4 keys AND)` AND 派生 | JSON | **未传递→false** | 不读取 | **L3-5** init=direct vs Codable=AND；**L3-1** 裁剪 |
| loadAverage | :318 `loads.one`(1min) | 必填 | :1696 `?? placeholder(0)` | JSON | :18 保留 | :258 `loadText`/`loadAverageProgress` | 无 |
| loadAverage5 | :319 `loads.five`(5min) | 0 | :1697 `?? 0` | JSON | :19 保留 | 不直接读取 | 无 |
| loadAverage15 | :320 `loads.fifteen`(15min) | 0 | :1698 `?? 0` | JSON | :20 保留 | 不直接读取 | 无 |
| hasLoadAverageReport | :321 `loads.isReported` | **OR 派生**(report \|\| val>0) | :1699 `?? OR 派生` | JSON | :21 保留 | :258 `loadAverageProgress` | 无(对称) |
| thermalState | :322 Title-case | 必填 | :1700 `?? "Unknown"` | JSON | :22 保留 | :184,237,263 `thermalText` | 无(量纲一致) |
| batteryPercent | :323 `percent`(0-1) | nil | :1701 `?? nil` | JSON | :23 保留 | :741 `compactPowerStatusText` | 无(0-1 一致) |
| batteryIsCharging | :324 | 必填 | :1702 `?? false` | JSON | :24 保留 | :745-756 间接 | 无 |
| batteryPowerSource | :325 | nil | :1703 `reportedPowerSource(decode)` | JSON | :25 保留 | :745-756 | 无 |
| batteryTimeRemainingMinutes | :326 | nil | :1704 `?? nil` | JSON | :26 保留 | 不读取 | 无 |
| batteryCycleCount | :327 | nil | :1705 `?? nil` | JSON | **未传递→nil** | 不读取 | **L3-2** 裁剪 |
| batteryHealth | :328 | nil | :1706 `?? nil` | JSON | **未传递→nil** | 不读取 | **L3-2** |
| batteryCurrentCapacity | :329 | nil | :1707 `?? nil` | JSON | :27 保留 | 不读取 | 无 |
| batteryMaxCapacity | :330 | nil | :1708 `?? nil` | JSON | :28 保留 | 不读取 | 无 |
| batteryDesignCapacity | :331 | nil | :1709 `?? nil` | JSON | **未传递→nil** | 不读取 | **L3-2** |
| batteryVoltageMillivolts | :332 | nil | :1710 `?? nil` | JSON | **未传递→nil** | 不读取 | **L3-2** |
| batteryAmperageMilliamps | :333 | nil | :1711 `?? nil` | JSON | **未传递→nil** | 不读取 | **L3-2** |
| networkBytesPerSecond | :334 `networkRate.total`(bytes/s) | 0 | :1712 `?? 0` | JSON | :29 保留 | **不读取** | **L3-15** 保留但 widget 不用 |
| hasNetworkByteCounters | :335 | **OR 派生** | :1741 `?? OR 派生` | JSON | :30 保留 | :间接 networkSourceStatusText | 无(对称) |
| hasNetworkDirectionByteCounters | :336 | nil→**OR 派生** | :1736 `?? (AND key \|\| OR val)` 混合 | JSON | :31 保留 | :间接 | **L3-8** init=OR vs Codable=AND+OR |
| networkPathStatus | :337 | "unknown" | :1715 `?? "unknown"` | JSON | :32 保留 | :186,221,270 `networkPathText` | 无 |
| networkPathIsExpensive | :338 | false | :1718 `?? false` | JSON | :33 保留 | :间接 networkPathDetailText | 无 |
| networkPathIsConstrained | :339 | false | :1719 `?? false` | JSON | :34 保留 | :间接 | 无 |
| hasNetworkPathCostReport | :340 | 直接赋值 | :1720 `?? (AND 2 keys)` | JSON | :35 保留 | :间接 | **L3-6** init=direct vs Codable=AND |
| networkPathSupportsDNS | :341 | false | :1725 `?? false` | JSON | :36 保留 | :间接 networkPathCapabilityText | 无 |
| networkPathSupportsIPv4 | :342 | false | :1726 `?? false` | JSON | :37 保留 | :间接 | 无 |
| networkPathSupportsIPv6 | :343 | false | :1727 `?? false` | JSON | :38 保留 | :间接 | 无 |
| hasNetworkPathSupportReport | :344 | 直接赋值 | :1728 `?? (AND 3 keys)` | JSON | :39 保留 | :间接 | **L3-7** init=direct vs Codable=AND |
| networkPathInterfaceKinds | :345 | [] | :1730 `?? []` | JSON | :40 保留 | :272 `networkPathDetailText` | 无 |
| networkInBytesPerSecond | :346 (bytes/s) | 0 | :1733 `?? 0` | JSON | :41 保留 | **不读取** | 无(保留但 widget 不用) |
| networkOutBytesPerSecond | :347 (bytes/s) | 0 | :1734 `?? 0` | JSON | :42 保留 | **不读取** | 无 |
| networkInterfaces | :348 | [] | :1735 `?? []` | JSON | :43 **置 []** | 不直接读取 | **L3-1**(B3 验证) |
| diskFreeBytes | :349 | 必填 | :1747 `?? 0` | JSON | :44 保留 | :222,257 `diskUsage` | 无 |
| diskTotalBytes | :350 | 0 | :1748 `?? 0` | JSON | :45 保留 | :222,257 | 无 |
| storageVolumes | :351 | [] | :1749 `?? []` | JSON | :46 **置 []** | 不直接读取 | **L3-1**(B3 验证) |
| processCount | —(MetricsStore 补) | 0 | :1750 `?? 0` | JSON | :47 **置 0** | 不读取 | 无 |
| activeApplicationCount | —(MetricsStore 补) | 0 | :1751 `?? 0` | JSON | :48 **置 0** | 不读取 | 无 |
| hiddenApplicationCount | —(MetricsStore 补) | 0 | :1752 `?? 0` | JSON | :49 **置 0** | 不读取 | 无 |
| hasRunningAppCountReport | —(MetricsStore 补) | **OR 派生** | :1753 `?? OR 派生` | JSON | :50 **置 false** | 不读取 | 无(对称) |
| runningApps | —(MetricsStore 补) | [] | :1754 `?? []` | JSON | :51 **置 []** | 不读取 | **L3-16** Codable key="topProcesses" |
| gpuDevices | :352 | [] | :1755 `?? []` | JSON | :52 **置 []** | 不读取 | **L3-1** |
| displays | :353 | [] | :1756 `?? []` | JSON | :53 **置 []** | 不读取 | **L3-1** |
| uptimeSeconds | :354 `systemUptime`(秒) | 0 | :1757 `?? 0` | JSON | :54 保留 | :291 `uptimeText` | 无(秒一致) |
| hasUptimeReport | :355 `true` | **OR 派生** | :1758 `?? OR 派生` | JSON | :55 保留 | :291 | 无(对称) |
| osVersion | :356 | "" | :1759 `?? placeholder("macOS")` | JSON | :56 保留 | :292 `osVersionText` | 无 |
| kernelRelease | :357 | "" | :1760 `?? ""` | JSON | :57 保留 | :295 `kernelText` | 无 |
| timestamp | :358 `now` | 必填 | :1761 `?? Date(1970)` | JSON | :58 保留 | :56 `snapshotAge` 计算 | 无 |
| schemaVersion | — | currentSchemaVersion(1) | :1673 `?? currentSchemaVersion` | JSON | :59 保留 | **不校验** | **L3-11** 字段存在但 store 不验证 |

---

## 三、不一致发现详情

### 不一致 L3-1: widgetCompactSnapshot 裁剪 memory composition 字段——契约脆弱（B3 验证）

- **字段**: memoryFreeBytes, memoryWiredBytes, memoryCompressedBytes, memoryCachedBytes, hasMemoryCompositionReport
- **链路断点**: `MetricSnapshot+WidgetCompact.swift:13-17` — 仅传递 memoryUsedBytes/memoryTotalBytes/memorySwap*，未传递 memory composition 四字段 + 报告标志
- **不一致描述**: `widgetCompactSnapshot()` 手工列举裁剪字段，memoryFreeBytes/Wired/Compressed/Cached 依赖 init 默认值 0，hasMemoryCompositionReport 依赖 init 默认值 false。当前 widget 不读取 `memoryFreeText`/`memoryWiredText`/`memoryCompressedText`/`memoryCachedText`/`memoryActiveText`，故功能正确。但若未来 widget 新增 memory composition 展示，这些字段会静默返回 "Not reported"（hasMemoryCompositionReport=false），无编译期告警。
- **用户影响**: 当前无。未来 widget 扩展时可能展示错误的 "Not reported"。
- **建议**: 在 `MetricSnapshot` 上提供 `func widgetCompact()` 工厂方法或 `mutating func stripForWidget()`，由 shared 模块单点维护裁剪逻辑；或改用 `var copy = snapshot; copy.cpuBrandName = nil; ...` 拷贝修改模式，保留所有未显式裁剪字段。引入独立 `WidgetCompactSnapshot` 类型可获得编译期保证。
- **优先级**: L-低（当前功能正确，属维护性风险）

### 不一致 L3-2: widgetCompactSnapshot 裁剪 battery detail 字段——契约脆弱（B3 扩展）

- **字段**: batteryCycleCount, batteryHealth, batteryDesignCapacity, batteryVoltageMillivolts, batteryAmperageMilliamps
- **链路断点**: `MetricSnapshot+WidgetCompact.swift:23-28` — 仅传递 batteryPercent/batteryIsCharging/batteryPowerSource/batteryTimeRemainingMinutes/batteryCurrentCapacity/batteryMaxCapacity，5 个 battery 详情字段被裁空
- **不一致描述**: 与 L3-1 同理。当前 widget 仅读取 `compactPowerStatusText`（依赖 batteryPercent + batteryPowerSource）和 `powerStatusTone`（依赖 batteryPercent + batteryIsCharging + batteryPowerSource），均被保留。batteryCycleCount/Health/Design/Voltage/Amperage 被 init 默认为 nil，widget 不读取，功能正确但脆弱。
- **用户影响**: 当前无。
- **建议**: 同 L3-1。
- **优先级**: L-低

### 不一致 L3-3: sampleWidgetCompact(fallback) vs widgetCompactSnapshot(shared store) 字段集不对称

- **字段**: memoryFreeBytes/Wired/Compressed/Cached, hasMemoryCompositionReport, batteryCycleCount/Health/Design/Voltage/Amperage
- **链路断点**: `SystemSampler.swift:362-443`（sampleWidgetCompact）vs `MetricSnapshot+WidgetCompact.swift:4-60`（widgetCompactSnapshot）
- **不一致描述**: widget 有两条数据路径：
  1. **Shared store 路径**: App `sampler.sample()` → `widgetCompactSnapshot()` 裁剪 → SharedSnapshotStore JSON → widget 读取。此路径 **裁剪** memory composition + battery details。
  2. **Fallback 路径**: `SystemDashboardWidget.swift:65` `WidgetSamplerCache.sampleCompact()` → `sampler.sampleWidgetCompact()` → widget 读取。此路径 **保留** memory composition（:388-395）和 battery details（:405-411）。

  两条路径产出的 MetricSnapshot 字段集不同。当前 widget 不读取这些差异字段，故无可见影响。但这意味着同一 widget 在"App 运行时"（shared store）和"App 未运行时"（fallback）拿到的数据结构不同，违反数据契约一致性。
- **用户影响**: 当前无可见差异。但若 widget 未来读取 memory composition，App 运行时显示 "Not reported"、App 未运行时显示实际值——行为反转。
- **建议**: 统一两条路径的裁剪策略。要么 sampleWidgetCompact 也裁剪这些字段（与 widgetCompactSnapshot 对齐），要么 widgetCompactSnapshot 保留这些字段（与 sampleWidgetCompact 对齐）。推荐后者（保留更多数据，减少脆弱性）。
- **优先级**: L-中

### 不一致 L3-4: hasCPUUsageReport init=直接赋值 vs Codable=OR 派生（P2-14 验证）

- **字段**: hasCPUUsageReport
- **链路断点**: init `MetricSnapshot.swift:884` `self.hasCPUUsageReport = hasCPUUsageReport`（直接赋值，无派生）vs Codable `:1676-1677` `?? (cpuUsage > 0 || !cpuCoreUsages.isEmpty)`（OR 派生）
- **不一致描述**: init 信任调用方传入的 hasCPUUsageReport 值，不做派生。Codable decode 在字段缺失时用 OR 策略从值推断。两者策略不对称：若构造 `MetricSnapshot(cpuUsage: 0, cpuCoreUsages: [], hasCPUUsageReport: true)`（CPU 空闲但已报告），init 保留 true；但若该 snapshot 的 JSON 缺失 hasCPUUsageReport key，Codable decode 派生为 `false`（0 && empty → false）。实际场景中 JSONEncoder 总会编码 hasCPUUsageReport 字段（Bool 非 Optional），故此 edge case 仅影响手工/旧版 JSON。
- **用户影响**: 当前无（字段总会被编码）。但策略不对称是维护隐患。
- **建议**: 统一策略。推荐 init 也加 OR 派生：`self.hasCPUUsageReport = hasCPUUsageReport || cpuUsage > 0 || !cpuCoreUsages.isEmpty`，与 Codable 对称。
- **优先级**: L-低

### 不一致 L3-5: hasMemoryCompositionReport init=直接赋值 vs Codable=AND 派生（P2-14 验证）

- **字段**: hasMemoryCompositionReport
- **链路断点**: init `:898` `self.hasMemoryCompositionReport = hasMemoryCompositionReport`（直接）vs Codable `:1691-1695` `?? (contains(.memoryFreeBytes) && contains(.memoryWiredBytes) && contains(.memoryCompressedBytes) && contains(.memoryCachedBytes))`（AND key 存在性派生）
- **不一致描述**: Codable 用 AND 策略——四个 byte 字段的 key 全部存在于 JSON 才派生 true。init 用直接赋值。两者策略不对称。AND 比 OR 更严格：如果旧 JSON 只有 memoryFreeBytes 而无 memoryWiredBytes，Codable 派生 false，但 sampler 实际可能已报告 composition。
- **用户影响**: 当前无（sampler 总是同时传递四字段或不传）。向后兼容场景下可能误判。
- **建议**: 统一为 OR 策略（任一 byte > 0 即报告），与 init 的其他 hasXxxReport 派生一致：`?? (memoryFreeBytes > 0 || memoryWiredBytes > 0 || memoryCompressedBytes > 0 || memoryCachedBytes > 0)`。或在 init 中也做 AND 派生。推荐前者。
- **优先级**: L-低

### 不一致 L3-6: hasNetworkPathCostReport init=直接赋值 vs Codable=AND 派生（P2-14 扩展）

- **字段**: hasNetworkPathCostReport
- **链路断点**: init `:933` 直接赋值 vs Codable `:1720-1721` `?? (hasNetworkPathExpensiveKey && hasNetworkPathConstrainedKey)`（AND key 存在性）
- **不一致描述**: 同 L3-5 模式。Codable 要求 isExpensive 和 isConstrained 两个 key 都存在才派生 true。init 信任调用方。实际场景中 sampler 总是同时传递两者，故无可见影响。
- **建议**: 统一为 OR 策略：`?? (hasNetworkPathExpensiveKey || hasNetworkPathConstrainedKey)`。
- **优先级**: L-低

### 不一致 L3-7: hasNetworkPathSupportReport init=直接赋值 vs Codable=AND 派生（P2-14 扩展）

- **字段**: hasNetworkPathSupportReport
- **链路断点**: init `:937` 直接赋值 vs Codable `:1728-1729` `?? (hasNetworkPathDNSKey && hasNetworkPathIPv4Key && hasNetworkPathIPv6Key)`（AND 三 key 存在性）
- **不一致描述**: 同 L3-5/L3-6 模式。Codable 要求 DNS/IPv4/IPv6 三个 key 全部存在才派生 true。init 信任调用方。
- **建议**: 统一为 OR 策略：`?? (hasNetworkPathDNSKey || hasNetworkPathIPv4Key || hasNetworkPathIPv6Key)`。
- **优先级**: L-低

### 不一致 L3-8: hasNetworkDirectionByteCounters init=OR 派生 vs Codable=AND+OR 混合派生（P2-14 扩展）

- **字段**: hasNetworkDirectionByteCounters
- **链路断点**: init `:919-923` `hasNetworkDirectionByteCounters ?? (hasNetworkByteCounters || networkInBytesPerSecond > 0 || networkOutBytesPerSecond > 0 || networkInterfaces.contains { $0.hasByteCounters })`（纯 OR）vs Codable `:1736-1740` `?? (hasNetworkInBytesKey && hasNetworkOutBytesKey || networkInBytesPerSecond > 0 || networkOutBytesPerSecond > 0 || networkInterfaces.contains { $0.hasByteCounters })`（AND key 存在性 + OR 值）
- **不一致描述**: Codable 的派生逻辑中，`(hasNetworkInBytesKey && hasNetworkOutBytesKey)` 检查 key 存在性（AND），其余是值检查（OR）。init 无 key 存在性检查，纯 OR 值派生。

  **Edge case 可触发不一致**：若 JSON 同时包含 `networkInBytesPerSecond: 0` 和 `networkOutBytesPerSecond: 0`（两 key 存在但值均为 0），且 `hasNetworkByteCounters=false`、`networkInterfaces=[]`、缺失 `hasNetworkDirectionByteCounters` key：
  - Codable 派生：`(true && true) || false || false || false` = **true**
  - init 派生（若用相同入参 nil 构造）：`false || false || false || false` = **false**
  - **结果分歧**：同一数据经 Codable decode 和 init 构造得到不同的 hasNetworkDirectionByteCounters。

  实际场景中 JSONEncoder 总会编码 hasNetworkDirectionByteCounters（Bool 非 Optional），故此 edge case 仅影响缺失该 key 的旧版 JSON。
- **用户影响**: 当前无。旧版 JSON 兼容场景下可能误派生 true，导致 widget 侧 `networkInText`/`networkOutText` 尝试展示 0 bytes/s 而非 "Not reported"。
- **建议**: 统一策略。推荐 Codable 改为纯 OR 值派生，去掉 key 存在性 AND 检查：`?? (networkInBytesPerSecond > 0 || networkOutBytesPerSecond > 0 || networkInterfaces.contains { $0.hasByteCounters })`，与 init 对称。
- **优先级**: L-中

### 不一致 L3-9: networkText 展示 bits/s vs networkInText/networkOutText 展示 bytes/s——单位混用

- **字段**: networkBytesPerSecond, networkInBytesPerSecond, networkOutBytesPerSecond
- **链路断点**: `MetricSnapshot.swift:1328-1331` `networkText` → `MetricFormatting.networkRate(bytesPerSecond:)` → 转换为 **bits/s**（Kbps/Mbps/Gbps）；`MetricSnapshot.swift:1433-1439` `networkInText`/`networkOutText` → `MetricFormatting.byteRate(bytesPerSecond:)` → 展示为 **bytes/s**（compactBytes + "/s"）
- **不一致描述**: 同一指标族（网络速率）的总量用 bits/s 展示，方向分量用 bytes/s 展示。`MetricFormatting.networkRate`（:44-47）先将 bytes×8 转为 bits 再格式化；`MetricFormatting.byteRate`（:63-65）直接用 compactBytes 格式化 bytes。用户在同一 UI 中看到 "12 Mbps"（总量）和 "900 KB/s"（入站）、"300 KB/s"（出站），单位不一致，无法直觉换算。
- **用户影响**: 用户困惑——总速率 12 Mbps 看似不等于 900 KB/s + 300 KB/s = 1200 KB/s = 9.6 Mbps（实际 12 Mbps = 1.5 MB/s = 1500 KB/s，但 UI 显示 900+300=1200 KB/s，差值因 compactBytes 取整）。单位混用增加认知负担。
- **建议**: 统一为 bits/s 或 bytes/s。推荐全部用 `MetricFormatting.networkRate`（bits/s），因为网络带宽通常以 bits/s 度量。或全部用 `byteRate`，但需修改 `networkText`。
- **优先级**: L-中

### 不一致 L3-10: MetricScales.tenGigabitBytesPerSecond 硬上限对 25/40/100 GbE 钳制

- **字段**: networkBytesPerSecond（间接影响 progress 展示）
- **链路断点**: `MetricScales.swift:4` `tenGigabitBytesPerSecond = 1_250_000_000.0`（10 Gbps = 1.25 GB/s）；`MetricScales.swift:8` `let value = min(Double(bytesPerSecond), tenGigabitBytesPerSecond)` 钳制；`MetricScales.swift:9` `log10(value + 1) / log10(tenGigabitBytesPerSecond + 1)` 对数缩放
- **不一致描述**: `networkRateProgress` 将超过 10 Gbps 的速率钳制到 10 Gbps 后做对数缩放，progress 在 10 Gbps 处饱和为 1.0。对于 25/40/100 GbE 链路，实际吞吐超过 10 Gbps 时 progress 仍为 1.0，无法区分 10/25/40/100 Gbps。

  **影响范围确认**：widget 侧 `SystemDashboardWidget.swift` **不调用** `networkRateProgress`——widget 用 `networkPathProgress`（:697-708，基于 path status 返回 0/0.45/1）。此 scale 仅在 app 侧 `DashboardView`/`WidgetPanelView` 使用（如 network rate 进度条）。widget 不受影响。
- **用户影响**: 仅 app 侧。25/40/100 GbE 用户看到网络速率 progress 条提前满格，无法反映实际超高吞吐。
- **建议**: 将 `tenGigabitBytesPerSecond` 提高到 `12_500_000_000.0`（100 Gbps）或改为可配置参数。对数缩放本身已能处理大动态范围，提高上限不影响低端链路的可视化粒度。
- **优先级**: L-低

### 不一致 L3-11: SharedSnapshotStore 无 schema 版本校验——schemaVersion 字段存在但未使用

- **字段**: schemaVersion
- **链路断点**: `MetricSnapshot.swift:748` `currentSchemaVersion = 1`；`:1673` Codable decode `?? currentSchemaVersion`；`SharedSnapshotStore.swift:54-73` `loadLatestSnapshot` 直接 decode，**不校验 schemaVersion**
- **不一致描述**: MetricSnapshot 有 schemaVersion 字段（=1），Codable 会编解码它，但 `SharedSnapshotStore.loadLatestSnapshot` 解码后不检查 `snapshot.schemaVersion` 是否 <= `currentSchemaVersion`。如果未来 schema 升级到 v2 并改变字段语义，旧 widget 读取 v2 数据时会静默接受并可能用错误的语义解读。

  同样，`MetricsStore.savedHistory`（:205-221）解码历史时也不校验 schemaVersion。
- **用户影响**: 当前无（schema v1）。未来 schema 升级时，旧 widget/app 可能用错误语义解读新数据，导致显示异常而非明确的 "unsupported schema" 降级。
- **建议**: 在 `loadLatestSnapshot` 和 `savedHistory` 中加 schemaVersion 校验：`guard snapshot.schemaVersion <= MetricSnapshot.currentSchemaVersion else { return nil }`。或实现 schema migration（v1→v2 转换）。
- **优先级**: L-低

### 不一致 L3-12: MetricsStore 丢弃 saveLatestSnapshot 返回值——save 失败静默

- **字段**: 全字段（间接影响共享持久化链路）
- **链路断点**: `MetricsStore.swift:375` `_ = sharedSnapshotStore.saveLatestSnapshot(snapshot)` 丢弃 Bool 返回值；`SharedSnapshotStore.swift:38-52` `saveLatestSnapshot` 在编码失败时返回 false + DEBUG print
- **不一致描述**: `saveLatestSnapshot` 返回 Bool 表示成功/失败，但 `saveSharedSnapshotIfNeeded` 用 `_ =` 丢弃返回值。release 构建中 `#if DEBUG` print 不执行，save 失败完全无日志、无遥测、无重试。widget 拿不到新数据，用户无任何感知。

  对称性检查：`loadLatestSnapshot` 返回 Optional，失败返回 nil——widget 侧 `sampledSnapshotForTimeline`（:63-65）用 `?? fallback sampler` 处理 nil，有降级路径。save 端无降级/重试。
- **用户影响**: App Group 权限丢失/磁盘满/编码异常时，widget 静默停更，用户无感知。与 P1-3（App Group 校验失败静默）叠加。
- **建议**: (1) 记录 save 失败到非 DEBUG 日志或遥测；(2) 考虑重试机制；(3) 至少在 `MetricsStore` 中检查返回值并设置 `lastSharedSnapshotWriteDate` 仅在成功时更新（当前无论成败都更新 :374，导致失败后 60s 内不重试）。
- **优先级**: L-中

### 不一致 L3-13: MetricFormatting C locale vs SharedMetricStrings.localizedFormat Locale.current 混用

- **字段**: 所有数值展示字段（cpuUsage, memoryUsedBytes, networkBytesPerSecond, loadAverage, diskFreeBytes, batteryPercent 等）
- **链路断点**: `MetricFormatting.swift:24,41,53,57,60,69` 全部 `String(format:)` **无 locale 参数**（C locale，小数点为 "."）；`SharedMetricStrings.swift:399-405` `localizedFormat` 用 `String(format:..., locale: Locale.current, arguments:)`（Locale.current，德语等用逗号 ","）
- **不一致描述**: 同一 UI 中，数字部分用 C locale 格式化（如 "1.2 GB"），外层文案用 Locale.current 格式化（如 "%@ available" 中的 %@ 替换为本地化数字）。在德语/法语等使用逗号小数点的 locale 下，用户看到 "1.2 GB available"（数字用 C locale 句点）而非 "1,2 GB available"（本地化逗号），数字格式与周围文案不一致。

  具体组合点：`SharedMetricStrings.diskAvailableSummary`（:328-330）用 `localizedFormat("%@ available", availableText)`，其中 `availableText` 来自 `MetricFormatting.compactBytes`（C locale）。外层 localizedFormat 的 %@ 替入的是已格式化的 C locale 字符串，Locale.current 只影响 "available" 文案的本地化，不影响数字。

  受影响的 C locale 格式化函数：
  - `MetricFormatting.bytes`：`String(format: "%.1f %@", ...)` — "1.2 GB"
  - `MetricFormatting.compactBytes`：`String(format: "%.0f %@", ...)` — "1 GB"
  - `MetricFormatting.bitRate`：`String(format: "%.1f Gbps", ...)` — "1.2 Gbps"
  - `MetricFormatting.load`：`String(format: "%.1f", ...)` — "1.4"
  - `DisplayMetric.refreshRateText`：`String(format: "%.0f Hz", ...)` — "60 Hz"
  - `DisplayMetric.backingScaleText`：`String(format: "%.0fx", ...)` — "2x"
  - `NetworkInterfaceMetric.compactCount`：`String(format: "%.1fB", ...)` — "1.2B"

  受影响的 Locale.current 格式化函数：
  - `SharedMetricStrings.localizedFormat`（:399-405）— 用于 `display(number:)`, `diskAvailableSummary`, `storageVolumeSummary`, `gpuSummary`, `displaySummary`, `runningAppSummary`, `activeNetworkInterfaceSummary`, `logicalCoreSummary`, `runningAppListOnly` 等

  注意：`MetricFormatting.percentage`（:4-8）不用 `String(format:)`，用 `"\(Int(...))%"` 字符串插值——不涉及 locale，始终用 C locale 数字。`MetricFormatting.minutes`（:78-97）同样用字符串插值。
- **用户影响**: 非英语 locale 下数字格式不一致（句点 vs 逗号）。对英语用户无影响。对使用 monospaced digit 的 widget/数字面板，C locale 可能是刻意选择（保证数字宽度一致），但未在代码中标注此意图。
- **建议**: (1) 若 C locale 是刻意选择（monospaced digit），在 `MetricFormatting` 顶部加注释说明；(2) 若应跟随 locale，改用 `String(format:..., locale: Locale.current)`；(3) 保证 `MetricFormatting` 和 `SharedMetricStrings.localizedFormat` 策略统一。
- **优先级**: L-低

### 不一致 L3-14: 两套独立裁剪路径（widgetCompactSnapshot + sanitizedHistorySnapshot）字段集不同

- **字段**: 全字段（两条裁剪路径）
- **链路断点**: `MetricSnapshot+WidgetCompact.swift:4-60`（widget 裁剪）vs `MetricsStore.swift:223-288`（history 裁剪）
- **不一致描述**: 存在两套手工列举的裁剪逻辑：

  | 字段 | widgetCompactSnapshot | sanitizedHistorySnapshot |
  |------|----------------------|--------------------------|
  | cpuBrandName | 置 nil | 置 nil |
  | memoryFreeBytes/Wired/Compressed/Cached | **未传递→0** | **保留** |
  | hasMemoryCompositionReport | **未传递→false** | **保留** |
  | batteryCycleCount/Health | 置 nil | 置 nil |
  | batteryDesignCapacity/Voltage/Amperage | 置 nil | 置 nil |
  | batteryCurrentCapacity/MaxCapacity | **保留** | **保留** |
  | networkInterfaces | 置 [] | 置 [] |
  | storageVolumes | 置 [] | 置 [] |
  | gpuDevices | 置 [] | 置 [] |
  | displays | 置 [] | 置 [] |
  | runningApps | 置 [] | 置 [] |
  | processCount/activeApp/hiddenApp | 置 0 | 置 0 |
  | osVersion | **保留** | **置 placeholder** |
  | kernelRelease | **保留** | **置 placeholder** |
  | uptimeSeconds | 保留 | 保留 |
  | memorySwap* | 保留 | 保留 |

  两套裁剪策略不同：widgetCompact 保留 osVersion/kernelRelease，sanitizedHistory 置为 placeholder；widgetCompact 裁剪 memory composition，sanitizedHistory 保留。两者各自有理（widget 需展示 OS 版本，history 不需要；widget 不展示 memory composition，history 趋势图需要），但缺乏统一的裁剪策略管理。
- **用户影响**: 当前无（两套裁剪各自满足需求）。维护风险：新增字段时需同时更新两处，遗漏任一处会导致数据静默丢失。
- **建议**: 提取统一的裁剪策略枚举或配置（如 `SnapshotTrimmingPolicy.forWidget` / `.forHistory`），单点维护字段裁剪规则，避免两处手工列举漂移。
- **优先级**: L-低

### 不一致 L3-15: networkBytesPerSecond 在 widgetCompact 中保留但 widget 不读取——冗余数据传输

- **字段**: networkBytesPerSecond, networkInBytesPerSecond, networkOutBytesPerSecond
- **链路断点**: `MetricSnapshot+WidgetCompact.swift:29,41,42` 保留这三个字段；`SystemDashboardWidget.swift` 全文不读取 `networkText`/`networkInText`/`networkOutText`
- **不一致描述**: widgetCompactSnapshot 保留 networkBytesPerSecond/networkInBytesPerSecond/networkOutBytesPerSecond，但 widget 只读取 `networkPathText`/`networkPathDetailText`/`networkPathCapabilityText`（基于 networkPathStatus/networkPathInterfaceKinds）。三个速率字段的 JSON 数据在每次 shared store 写入时被序列化（每 60s），widget 解码后丢弃——增加 UserDefaults 存储/读取开销，无功能收益。

  `hasNetworkByteCounters`/`hasNetworkDirectionByteCounters` 同样被保留但仅间接用于 `networkSourceStatusText`（widget 不读取此属性）。
- **用户影响**: 当前无。轻微的存储/序列化开销（三个 UInt64 + 两个 Bool ≈ 28 bytes/snapshot）。
- **建议**: 评估是否在 widgetCompactSnapshot 中也裁剪 network 速率字段（若 widget 确定不展示速率）。或保留以备未来 widget 扩展。低优先级。
- **优先级**: L-低

### 不一致 L3-16: runningApps Codable key 为 "topProcesses"——property name 与 JSON key 语义不一致

- **字段**: runningApps（JSON key: "topProcesses"）
- **链路断点**: `MetricSnapshot.swift:1661` `case runningApps = "topProcesses"`
- **不一致描述**: Swift 属性名为 `runningApps`（语义：运行中的 App 列表），但 Codable 编码的 JSON key 为 `"topProcesses"`（语义：Top 进程列表）。两者语义不同——"running apps" vs "top processes"。这是历史 rename 的遗留：前次 review 称该字段为 "topProcesses"，后 rename 为 "runningApps" 但保留旧 JSON key 以向后兼容。

  `MetricsStore.applyVisibleApplicationSummary`（:445-481）填充的是 `NSWorkspace.runningApplications`（App 列表），非 "top processes"（按 CPU/内存排序的进程）。JSON key "topProcesses" 误导性更强。
- **用户影响**: 当前无功能影响。但 JSON schema 审查/debug 时 property name 与 JSON key 语义不一致增加理解成本。如果未来真正新增 "top processes" 字段（如按 CPU 排序的进程），命名冲突。
- **建议**: 在 schema v2 中将 JSON key rename 为 "runningApps"，并在 Codable decode 中兼容旧 key "topProcesses"。低优先级。
- **优先级**: L-低

---

## 四、locale/格式化一致性

### 4.1 格式化函数 locale 策略矩阵

| 函数 | 位置 | locale 策略 | 示例输出 |
|------|------|------------|---------|
| MetricFormatting.percentage | :4-8 | 无 format（字符串插值）= C locale | "86%" |
| MetricFormatting.bytes | :10-25 | `String(format:)` 无 locale = C locale | "1.2 GB" |
| MetricFormatting.compactBytes | :27-42 | `String(format:)` 无 locale = C locale | "1 GB" |
| MetricFormatting.networkRate | :44-47 | 间接调 bitRate | "12 Mbps" |
| MetricFormatting.bitRate | :49-61 | `String(format:)` 无 locale = C locale | "1.2 Gbps" |
| MetricFormatting.byteRate | :63-65 | 间接调 compactBytes | "900 KB/s" |
| MetricFormatting.load | :67-70 | `String(format:)` 无 locale = C locale | "1.4" |
| MetricFormatting.duration | :72-76 | 间接调 minutes | "1d 2h" |
| MetricFormatting.minutes | :78-97 | 字符串插值 = C locale | "2h 30m" |
| DisplayMetric.refreshRateText | :386 | `String(format:)` 无 locale | "60 Hz" |
| DisplayMetric.backingScaleText | :373-375 | `String(format:)` 无 locale | "2x" |
| DisplayMetric.rotationText | :398 | `String(format:)` 无 locale | "90°" |
| NetworkInterfaceMetric.compactCount | :733-744 | `String(format:)` 无 locale | "1.2B" |
| SharedMetricStrings.localizedFormat | :399-405 | `String(format:, locale: Locale.current)` | 本地化数字 |

### 4.2 混用场景

1. **`diskAvailableSummary`**（SharedMetricStrings:328-330）：`localizedFormat("%@ available", availableText)` — 外层用 Locale.current，`availableText` 来自 `MetricFormatting.compactBytes`（C locale）。德语下结果："1 GB available"（数字用句点）而非 "1 GB verfügbar" + "1 GB" 用逗号。

2. **`logicalCoreSummary`**（SharedMetricStrings:321-326）：`localizedFormat("%d logical cores", count)` — `%d` 整数不涉及小数点，locale 差异不可见。无问题。

3. **`runningAppSummary`**（SharedMetricStrings:211-219）：`localizedFormat("%d apps · foreground %d · hidden %d", ...)` — 同上，`%d` 无 locale 差异。无问题。

4. **`gpuDisplaySummary`**（SharedMetricStrings:357-359）：`localizedFormat("%@ / %@", gpuText, displayText)` — %@ 替入的是 `gpuSummary`/`displaySummary` 的本地化文本，无数字。无问题。

**结论**：locale 混用问题仅影响 **浮点数**（`%.1f` / `%.0f`）格式化场景，即 `bytes`/`compactBytes`/`bitRate`/`load` 的输出。这些值通过 `%@` 被嵌入 `localizedFormat` 时，数字保留 C locale 句点。整数（`%d`）和纯文本（`%@` 本地化字符串）不受影响。

### 4.3 batteryPercent 量纲一致性验证

| 消费点 | 位置 | 处理 | 一致 |
|--------|------|------|------|
| sampler 赋值 | SystemSampler.swift:654-657 `current / maxValue` | 0-1 | ✅ |
| batteryPercentText | MetricSnapshot.swift:1257-1260 `MetricFormatting.percentage(batteryPercent)` | 0-1→×100 | ✅ |
| powerStatusProgress | :1285-1287 `batteryPercent` 直接返回 | 0-1 | ✅ |
| powerStatusTone | :1289-1290 `batteryPercent < 0.2` | 0-1 比较 | ✅ |
| compactPowerStatusText | SystemDashboardWidget.swift:741-742 `MetricFormatting.percentage(batteryPercent)` | 0-1→×100 | ✅ |

**结论**：batteryPercent 全链路 0-1 一致，无 0-100 混用。

### 4.4 cpuUsage 量纲一致性验证

| 消费点 | 位置 | 处理 | 一致 |
|--------|------|------|------|
| sampler 赋值 | SystemSampler.swift:507 `1 - (idle/total)` | 0-1 | ✅ |
| cpuText | MetricSnapshot.swift:1077-1080 `MetricFormatting.percentage(cpuUsage)` | 0-1→×100 | ✅ |
| widget RingMetric progress | SystemDashboardWidget.swift:179 `snapshot.cpuUsage` | 0-1 | ✅ |

**结论**：cpuUsage 全链路 0-1 一致。

### 4.5 networkBytesPerSecond scale 函数一致性验证

| 消费点 | 位置 | scale 函数 | 一致 |
|--------|------|-----------|------|
| networkText | MetricSnapshot.swift:1330 `MetricFormatting.networkRate(bytesPerSecond:)` | networkRate→bitRate(bits/s) | bits/s |
| networkInText | :1435 `MetricFormatting.byteRate(bytesPerSecond:)` | byteRate→compactBytes | bytes/s |
| networkOutText | :1439 `MetricFormatting.byteRate(bytesPerSecond:)` | byteRate→compactBytes | bytes/s |
| widget | 不读取 networkBytesPerSecond | n/a | n/a |

**结论**：**不一致**（L3-9）——总量用 bits/s，方向分量用 bytes/s。`MetricScales.networkRateProgress` 用于 app 侧 progress 条，widget 侧不调用。

### 4.6 loadAverage 三值映射一致性验证

| 环节 | 1min | 5min | 15min | 一致 |
|------|------|------|-------|------|
| sampler getloadavg | loads[0] | loads[1] | loads[2] | ✅ |
| sampler sample() | loadAverage | loadAverage5 | loadAverage15 | ✅ |
| loadDetailText | loadAverageText | loadAverage5Text | loadAverage15Text | ✅（1/5/15 顺序） |

**结论**：loadAverage 三值全链路一一对应，顺序一致（1min/5min/15min）。

### 4.7 timestamp / snapshotAge 一致性验证

| 环节 | 位置 | 处理 | 单位 | 一致 |
|------|------|------|------|------|
| sampler 赋值 | SystemSampler.swift:358 `timestamp: now` | Date | Date | ✅ |
| Codable encode/decode | MetricSnapshot.swift:1761 | Date | Date | ✅ |
| store age 计算 | SharedSnapshotStore.swift:62 `now.timeIntervalSince(snapshot.timestamp)` | TimeInterval | 秒 | ✅ |
| widget snapshotAge | SystemDashboardWidget.swift:56 `now.timeIntervalSince($0.timestamp)` | TimeInterval | 秒 | ✅ |
| store maxAge | SharedSnapshotStore.swift:54 `maxAge: TimeInterval` | 600 | 秒 | ✅ |
| store acceptedFutureSkew | :11 `300` | 300 | 秒 | ✅ |
| widget sharedSnapshotMaxAge | SystemDashboardWidget.swift:41 `600` | 600 | 秒 | ✅ |
| widget nextRefresh | :58 `5 minutes` | 300 | 秒 | ✅ |

**结论**：timestamp/snapshotAge 全链路单位一致（秒）。但 freshness 窗口（600s）> 刷新间隔（300s），见 C1 anchor（非本审查范围，已在 L4 报告覆盖）。

### 4.8 bytes 展示函数一致性验证

| 字段 | 展示属性 | 格式化函数 | 一致 |
|------|---------|-----------|------|
| memoryUsedBytes | memoryText | MetricFormatting.bytes | ✅ |
| memoryTotalBytes | memoryDetailText | MetricFormatting.bytes | ✅ |
| memoryFreeBytes | memoryFreeText | MetricFormatting.bytes(via reportedMemoryCompositionText) | ✅ |
| memoryWiredBytes | memoryWiredText | MetricFormatting.bytes | ✅ |
| memoryCompressedBytes | memoryCompressedText | MetricFormatting.bytes | ✅ |
| memoryCachedBytes | memoryCachedText | MetricFormatting.bytes | ✅ |
| memorySwapUsedBytes | memorySwapText | MetricFormatting.bytes(via reportedSwapText) | ✅ |
| memorySwapTotalBytes | memorySwapTotalText | MetricFormatting.bytes | ✅ |
| memorySwapAvailableBytes | memorySwapAvailableText | MetricFormatting.bytes | ✅ |
| diskFreeBytes | diskAvailableText | MetricFormatting.compactBytes | ⚠️ compactBytes(无小数) |
| diskTotalBytes | diskTotalText | MetricFormatting.bytes | ✅ |
| diskUsedBytes | diskUsedText | MetricFormatting.bytes | ✅ |
| StorageVolumeMetric.totalBytes | totalText | MetricFormatting.bytes | ✅ |
| StorageVolumeMetric.availableBytes | availableText | MetricFormatting.bytes | ✅ |
| StorageVolumeMetric.usedBytes | usedText | MetricFormatting.bytes | ✅ |
| GPUDeviceMetric.recommendedMaxWorkingSetBytes | recommendedWorkingSetText | MetricFormatting.bytes | ✅ |
| GPUDeviceMetric.maxThreadgroupMemoryLength | threadgroupMemoryText | MetricFormatting.bytes | ✅ |
| NetworkInterfaceMetric.bytesReceived/Sent | byteCountText | MetricFormatting.compactBytes | ⚠️ compactBytes |

**结论**：大部分 bytes 展示用 `MetricFormatting.bytes`（带 1 位小数），但 `diskAvailableText` 和 `NetworkInterfaceMetric.byteCountText` 用 `compactBytes`（无小数）。这是刻意的空间节省（widget/detail 紧凑展示），非不一致。单位均为 bytes → binary 单位（KB/MB/GB，1024 进制），一致。

---

## 五、与 REVIEW-PLAN.md 重叠项

| 本报告 ID | REVIEW-PLAN.md 项 | 重叠描述 | 验证结果 |
|-----------|-------------------|---------|---------|
| L3-1, L3-2 | P2-11 / [ANCHOR-B3] | widgetCompactSnapshot 裁剪契约靠手工列举，无类型级强制 | **验证确认**：widget 当前不读取被裁字段，功能正确但脆弱。widgetCompactSnapshot 手工列举 ~40 字段，~11 字段依赖 init 默认值静默置零/nil |
| L3-4 ~ L3-8 | P2-14 | decoder/init 推断策略不一致（AND/OR 混用） | **验证并扩展**：发现 5 个不对称字段——hasCPUUsageReport(OR), hasMemoryCompositionReport(AND), hasNetworkPathCostReport(AND), hasNetworkPathSupportReport(AND), hasNetworkDirectionByteCounters(AND+OR)。其中 hasNetworkDirectionByteCounters 有可触发的 edge case 不一致 |
| L3-10 | P3 / MetricScales 硬上限 | `tenGigabitBytesPerSecond` 硬上限对 25/40/100 GbE 钳制 | **验证确认**：硬上限 10 Gbps 钳制 + 对数缩放饱和。但 widget 侧不调用 `networkRateProgress`，仅 app 侧受影响 |
| L3-13 | P3 / MetricFormatting C locale | `String(format:)` C locale vs `Locale.current` 混用 | **验证确认**：影响范围限定为浮点数格式化（bytes/bitRate/load），整数和文本不受影响。问题真实存在但影响范围比预期小 |
| L3-12 | P2-8 / P2-11 | `try?`/`_ =` 静默吞噬错误 | **验证确认**：`MetricsStore.swift:375` `_ =` 丢弃 saveLatestSnapshot 返回值，且 `lastSharedSnapshotWriteDate` 无论成败都更新，导致失败后 60s 内不重试 |
| L3-11 | P2-11 | release 下 save/load 失败静默，无 schema 版本字段 | **验证确认**：schemaVersion 字段存在(=1)但 SharedSnapshotStore/MetricsStore 均不校验 |
| L3-3 | P0-2 (widget fallback) | fallback 路径与 shared store 路径数据集不同 | **扩展发现**：sampleWidgetCompact 保留 memory composition + battery details，widgetCompactSnapshot 裁剪——两条路径字段集不对称 |
| L3-9 | 无（新发现） | networkText bits/s vs networkInText/networkOutText bytes/s | **新发现**：同一指标族单位混用 |
| L3-14 | 无（新发现） | 两套独立裁剪路径字段集不同 | **新发现**：widgetCompactSnapshot vs sanitizedHistorySnapshot |
| L3-15 | 无（新发现） | networkBytesPerSecond 保留但 widget 不读取 | **新发现**：冗余数据传输 |
| L3-16 | 无（新发现） | runningApps Codable key="topProcesses" 语义不一致 | **新发现**：property name vs JSON key |

---

## 六、汇总

共发现 **16 条** 不一致：

| 优先级 | 数量 | 编号 |
|--------|------|------|
| L-高 | 0 | — |
| L-中 | 3 | L3-3, L3-8, L3-9, L3-12 |
| L-低 | 13 | L3-1, L3-2, L3-4, L3-5, L3-6, L3-7, L3-10, L3-11, L3-13, L3-14, L3-15, L3-16 |

**关键结论**：
1. **B3 anchor 验证通过**：widgetCompactSnapshot 裁剪后字段当前不被 widget 读取，功能正确。但裁剪契约靠手工列举 ~40 字段、~11 字段依赖 init 默认值静默置零/nil，无编译期保证。
2. **P2-14 anchor 验证并扩展**：5 个 hasXxxReport 字段 init/Codable 策略不对称。其中 hasNetworkDirectionByteCounters 有可触发的 edge case（JSON 含两 key 但值均为 0 时 init/Codable 派生结果分歧）。
3. **量纲一致性**：batteryPercent(0-1)、cpuUsage(0-1)、memoryUsage(0-1)、diskUsage(0-1)、loadAverage(三值映射)、timestamp/snapshotAge(秒) 全链路一致。唯一量纲问题是 networkText(bits/s) vs networkInText/networkOutText(bytes/s) 单位混用（L3-9）。
4. **新发现**：sampleWidgetCompact 与 widgetCompactSnapshot 字段集不对称（L3-3）是跨路径数据契约不一致，当前无可见影响但违反一致性原则。
