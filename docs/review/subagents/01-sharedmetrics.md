# SharedMetrics 模块深度审查报告

## 审查概要
- 文件数：5
- 总行数：3258
  - MetricSnapshot.swift: 1753
  - SystemSampler.swift: 1235
  - MetricFormatting.swift: 94
  - MenuBarPopoverGeometry.swift: 173
  - WidgetTimelineKind.swift: 3
- 发现问题数：22
  - Bug 级：2
  - 质量级：13
  - 整洁级：7

---

## 逐文件审查

### MetricSnapshot.swift（1753 行）

#### ProcessMetric（第 10–105 行）

**第 11 行** `public var id: Int { index }` — Identifiable 基于 index。在单一快照数组中 index 唯一，可接受。当前用法安全。

**第 32 行** `self.name = Self.reportedName(name)` — init 中对 name 做归一化（trim + 空值→"未报告"），确保存储值始终非空。

**第 52–66 行** 自定义 `init(from decoder:)`：
- 第 58 行：`decodeIfPresent(String.self)` 返回 `String?`，传入 `reportedName(_ name: String?)`，返回 `String`。类型安全。
- 第 54–56 行：先记录 `hasActivationPolicyKey` / `hasActiveKey` / `hasHiddenKey` 是否存在。
- 第 62–63 行：`hasStateReport` 在 key 缺失时，用 **OR** 逻辑从相关 key 存在性推断。向后兼容推断，合理。

**第 73–80 行** `stateText` — 优先级：无报告→"未报告"；isActive→"前台"；isHidden→"已隐藏"；有 policy→policy 文本；否则→"运行"。逻辑清晰。

**第 92–100 行** `hasInventoryReport` — 通过 `name != "未报告"` 等魔法字符串比较判断。此模式全文重复，脆弱但一致。**整洁级**：若 `reportedName` 归一化值改变，所有 `!= "未报告"` 检查需同步修改。

#### GPUDeviceMetric（第 107–246 行）

**第 190–193 行** 解码推断逻辑：
```swift
hasDeviceKindReport = ...
    ?? ((hasLowPowerKey && isLowPower) || (hasRemovableKey && isRemovable) || (hasLowPowerKey && hasRemovableKey))
```
第三条件覆盖两 key 都在但值都为 false 的情况。但如果**只有** `hasLowPowerKey=true, isLowPower=false`（无 `hasRemovableKey`），三条件全 false → `hasDeviceKindReport=false`。此时 `kindText`（第 201 行）返回"未报告"，尽管已知设备不是低功耗。**质量级**：单 key 存在且值为 false 时推断过于保守。

**第 219 行** `MetricFormatting.bytes(UInt64(maxThreadgroupMemoryLength))` — `Int` 转 `UInt64`。Metal 保证非负，安全。

**第 222–228 行** `threadgroupSizeText` — 要求 width/height/depth **全部** > 0 才显示。保守但合理。

#### DisplayMetric（第 248–426 行）

**第 352–354 行** 解码推断：
```swift
hasTopologyReport = ... ?? (hasBuiltinKey && hasMainKey && hasMirroredKey)  // AND
hasRotationReport = ... ?? hasRotationKey  // 单 key
```
**质量级**：`hasTopologyReport` 用 **AND** 要求三个 key 全部存在。旧 JSON 若缺一个，整个拓扑报告被视为未报告。与 ProcessMetric 的 OR 逻辑不一致。

**第 374–378 行** `backingScaleText` — 先四舍五入到 1 位小数，再检查是否整数。2.0→"2x"，1.5→"1.5x"。正确。

**第 399–401 行** `rotationText` — `truncatingRemainder(dividingBy: 360)` 可能为负，再加 360 归正。正确处理负角度。

**第 406 行** `let role = isMain ? "主屏幕" : (isBuiltin ? "内建" : "外接")` — 优先级：主屏 > 内建 > 外接。UI 选择。

#### StorageVolumeMetric（第 428–577 行）

**第 512–515 行** `usedBytes` — `hasCapacityReport`（第 522–524 行）检查 `totalBytes > 0 && availableBytes <= totalBytes`，保证 `totalBytes - availableBytes` 不下溢。

**第 517–520 行** `usage` — `min(Double(usedBytes) / Double(totalBytes), 1)`。有 guard 保证 totalBytes > 0，不会除零。

**第 526–530 行** `reportedAvailableBytes` — 优先用 `importantAvailableBytes`，验证不超过 totalBytes 否则回退。逻辑完善。

**第 501–503 行** 解码推断 `hasKindReport` 用 OR-ish 逻辑，`hasAccessReport` 用单 key。与 DisplayMetric 的 AND 逻辑不一致。**质量级**。

#### NetworkInterfaceMetric（第 579–746 行）

**第 625 行** `self.hasByteCounterValues = hasByteCounterValues ?? hasByteCounters` — 未显式传入时默认等于 `hasByteCounters`。合理。

**第 668–671 行** 解码推断：
```swift
hasByteCounters = ... ?? (hasBytesReceivedKey && hasBytesSentKey)  // AND
hasByteCounterValues = ... ?? (hasBytesReceivedKey && hasBytesSentKey)  // AND
```
**质量级**：AND 逻辑要求收发两个 key 都存在。旧数据若只有 `bytesReceived`，则 byte counters 整体被视为未报告。

**第 734–745 行** `compactCount` — 用 "B" 表示 Billion（十亿），但同代码库 `MetricFormatting.bytes` 用 "B" 表示 Byte。**质量级**：容易混淆，建议用 "G"。

#### MetricSnapshot 主体（第 748–1753 行）

**第 899–901 行** `hasLoadAverageReport` 计算：
```swift
self.hasLoadAverageReport = hasLoadAverageReport
    || loadAverage > 0 || loadAverage5 > 0 || loadAverage15 > 0
```
**质量级**：系统极度空闲时 load average 全为 0.00 → `hasLoadAverageReport` 为 false → 显示"未报告"。SystemSampler 成功时总传 `true`（第 271 行），实践中不影响。但解码旧数据时（第 1689–1690 行）同样有此问题。

**第 915–925 行** network byte counter 标志互相依赖：第 922 行引用第 915–919 行刚赋值的 `self.hasNetworkDirectionByteCounters`。有意为之——方向计数器存在意味着字节计数器存在。逻辑正确。

**第 944–947 行** `hasRunningAppCountReport` — 同样用 `|| count > 0` 推断。所有计数为 0 时视为未报告。实践中 processCount 永远 > 0。**质量级**。

**第 952 行** `self.hasUptimeReport = hasUptimeReport || uptimeSeconds > 0` — 刚开机 uptime 可能为 0，但 SystemSampler 总传 `true`（第 305 行）。**质量级**。

**第 1016–1029 行** `memoryUsage` / `memorySwapUsage` / `diskUsage` — 均有 guard 防止除零。`min(..., 1)` 额外保险。

**第 1031–1034 行** `diskUsedBytes` — `guard diskTotalBytes >= diskFreeBytes else { return 0 }` 防下溢。

**第 1049–1054 行** `memoryActiveBytes`：
```swift
return memoryUsedBytes > memoryWiredBytes + memoryCompressedBytes
    ? memoryUsedBytes - memoryWiredBytes - memoryCompressedBytes
    : memoryUsedBytes
```
**质量级**：`memoryWiredBytes + memoryCompressedBytes` 是两个 `UInt64` 相加，理论上可能溢出。实践中两者不超过物理内存总量（~128GB），不会溢出。防御性编程建议先转 Double 比较或分段比较。

**第 1115–1116 行** `reportedLoadProgress` — `guard ... activeProcessorCount > 0` 防止除零。

**第 1218–1225 行** `thermalText` — `thermalState.lowercased()` 做 switch。SystemSampler 输出 "Nominal"/"Warm" 等，lowercased 后匹配。同时兼容 "fair"/"serious" 原始值。

**第 1272–1289 行** `powerStatusProgress` — 无 batteryPercent 时根据电源类型返回魔法值（0.45/0.7/0.55）。**整洁级**：魔法数字未注释。

**第 1290–1322 行** `powerStatusTone` — 电池 < 20% → critical；充电中或 AC → normal；电池/UPS → warning。逻辑合理。

**第 1330–1337 行** `hasNetworkPathReport` — 匹配 "satisfied"/"unsatisfied"/"requiresconnection" 等（含下划线和空格变体）。

**第 1662–1752 行** 自定义 `init(from decoder:)`：
- 全面使用 `decodeIfPresent` + 默认值，支持向后兼容。
- 第 1681–1685 行：`hasMemoryCompositionReport` 推断用 **AND**（4 个 key 全在）。
- 第 1711–1712 行：`hasNetworkPathCostReport` 推断用 **AND**（2 个 key 全在）。
- 第 1719–1720 行：`hasNetworkPathSupportReport` 推断用 **AND**（3 个 key 全在）。
- 第 1742–1743 行：`hasRunningAppCountReport` 推断用 **AND**（3 个 key 全在）。

**质量级（跨类型一致性问题）**：向后兼容推断策略在类型间不一致：
- ProcessMetric：**OR**（lenient）
- GPUDeviceMetric：**混合**
- DisplayMetric：**AND**（strict）
- StorageVolumeMetric：**OR-ish**
- NetworkInterfaceMetric：**混合**
- MetricSnapshot：**AND**（strict）

AND 策略过于严格——缺少一个 key 就使整个报告被视为未报告。建议统一为 OR 或 partial-report 策略。

**第 1689–1690 行 vs 第 899–901 行** — memberwise init 用 `||` 合并传入值和推断值；decoder 用 `??`（key 存在则直接用，不合并推断）。若旧 JSON 有 `hasLoadAverageReport: false` 且 `loadAverage: 5.0`，decoder 读到 false，但 init 会算出 true。**质量级**：decoder 与 init 的推断语义不完全对称。

**第 1664/1668–1670/1686/1749 行 vs 第 1674–1680 行** — 部分默认值用 `Self.placeholder.xxx`，部分用字面量 `0`。两者结果相同但风格不一致。**整洁级**。

**Codable 对称性总体评估**：自动合成的 `encode(to:)` 编码所有属性，自定义 `init(from:)` 用 `decodeIfPresent` 读取。encode→decode round-trip 对称（所有 key 都在 JSON 中）。decode 旧 JSON（缺 key）使用默认值。decode 新 JSON（多 key）忽略多余 key。对称性满足。

---

### SystemSampler.swift（1235 行）

#### NetworkPathObserver（第 128–194 行）

**第 128 行** `@unchecked Sendable` — `latest` 用 NSLock 保护（第 147–149 行 / 152–156 行）。`monitor` 和 `queue` 在 init 后不可变，实际安全。但 `@unchecked` 要求开发者自行保证，若后续添加访问 `monitor` 的方法可能引入竞争。

**第 135 行** `latest = Self.sample(from: monitor.currentPath)` — 在 `monitor.start(queue:)` 之前访问 `currentPath`。Apple 文档允许此用法（初始值可用）。

**第 136–138 行** `[weak self]` 防止循环引用。handler 在 queue 上执行，weak self 安全。

**第 142–144 行** `deinit { monitor.cancel() }` — cancel 后不再有新回调。若有正在执行的 handler，`[weak self]` 返回 nil 安全。

**第 185–193 行** `interfaceKinds` — 检查 `usesInterfaceType` 各类型。`@unknown default` 无需处理（NWPath.InterfaceType 无 @unknown 案例因为它是 struct 而非 enum，此处编译器不强制）。正确。

#### SystemSampler 类（第 201–1235 行）

**第 201 行** `@unchecked Sendable` — `sampleLock` 保护所有可变状态。`networkPathObserver` 是 `let`（自带内部锁），`systemInfo` 是 `let`。`@unchecked` 合规。

**第 229–231 行** `sample()` 持锁整个采样周期：
```swift
sampleLock.lock()
defer { sampleLock.unlock() }
```
**质量级**：锁粒度过粗——整个 `sample()` 期间（含 CPU、内存、网络、电池、GPU、显示器等 I/O）都持锁。并发调用 `sample()` 会串行化，可能造成延迟。但这些操作本身是只读的系统查询，且需要一致的快照，所以粗锁是合理的设计取舍。

**第 316–317 行** CPU 采样 Mach port：
```swift
let host = mach_host_self()
defer { mach_port_deallocate(mach_task_self_, host) }
```
正确释放 host send right。

**第 329–332 行** CPU 采样 vm_deallocate：
```swift
defer {
    let size = vm_size_t(processorMsgCount) * vm_size_t(MemoryLayout<integer_t>.stride)
    vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: processorInfo)), size)
}
```
此 defer 在第 327 行 guard-let **之后**注册。若 guard 失败（result != KERN_SUCCESS），defer 不注册——此时 buffer 未分配，无需释放。`UInt(bitPattern:)` 正确转换指针。size 计算正确（msgCount × integer_t.stride）。

**第 334–336 行** `withMemoryRebound` — 将 `integer_t` 数组重新绑定为 `processor_cpu_load_info` 结构体数组。`Array(UnsafeBufferPointer(...))` 复制数据。原始 buffer 由 defer 释放，Array 独立持有副本。

**第 338 行** `guard previousCPUInfo.count == info.count else { previousCPUInfo = info; return (0, [], isReported: false) }` — CPU 核数变化时重置基线。无法计算 delta。正确。

**第 354 行** `let delta = current[tickIndex] >= previous[tickIndex] ? UInt64(current[tickIndex] - previous[tickIndex]) : 0` — 处理计数器回绕。若 current < previous（回绕），delta 为 0。保守但安全。

**第 353 行** `for tickIndex in 0..<Int(CPU_STATE_MAX)` — `CPU_STATE_MAX` = 4。`tickArray` 返回 4 元素数组。索引 0–3 安全。

**第 364–368 行** `if coreTotalTicks > 0` guard 防止除零。

**第 373–374 行** `guard totalTicks > 0 else { return (0, coreUsages, isReported: false) }` — guard 后 `isReported: totalTicks > 0` 恒为 true。**整洁级**：冗余表达式。

**第 389–398 行** 内存采样 host_statistics64：
```swift
var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
let result = withUnsafeMutablePointer(to: &stats) {
    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(host, HOST_VM_INFO64, $0, &count)
    }
}
```
标准模式。count 为 vm_statistics64 的 integer_t 单元数。指针重绑定安全。

**第 391–392 行** `mach_host_self()` + `mach_port_deallocate` — 正确。

**第 411–413 行** 页数计算：
```swift
let usedPages = UInt64(stats.active_count + stats.wire_count + stats.compressor_page_count)
let cachedPages = UInt64(stats.inactive_count + stats.purgeable_count)
let reclaimableFreePages = UInt64(stats.free_count + stats.speculative_count)
```
**质量级**：`active_count`、`wire_count` 等为 `natural_t`（UInt32）。三个 UInt32 先相加再转 UInt64，若和超过 UInt32.max（~40 亿页 ≈ 16TB）会回绕。当前 macOS 最大 ~128GB ≈ 3300 万页，远不溢出。但防御性编程建议逐项转 UInt64 后相加：`UInt64(stats.active_count) + UInt64(stats.wire_count) + ...`。

**第 406–409 行** `host_page_size` 失败时返回 `hasCompositionReport: false`。正确降级。

**第 429–441 行** `sampleSwapUsage` — `sysctlbyname("vm.swapusage", ...)` 标准用法。`xsw_usage` 字段已是 `uint64_t`，`UInt64()` 无损转换。

**第 443–447 行** `sampleLoadAverages` — `getloadavg(&loads, 3) == 3` 验证全部三个值获取成功。数组大小 3，访问 `loads[0/1/2]` 安全。

**第 459–463 行** `sampleKernelRelease` — `uname(&systemInfo)` + `stringFromFixedCString(systemInfo.release)`。正确读取 utsname 固定数组。

**第 465–478 行** `sampleThermalState` — `ProcessInfo.processInfo.thermalState` 映射到字符串。`.fair` → "Warm"（有意的 UI 归一化）。`@unknown default` → "Unknown"。

**第 480–539 行** `sampleBattery` — IOKit 电池采样：
- 第 481 行：`IOPSCopyPowerSourcesInfo()?.takeRetainedValue()` — Copy 语义，takeRetained 消费 +1 retain。正确。
- 第 491 行：`IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]` — 同上。
- 第 542 行：`IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?` — Get 语义，takeUnretained 借用（生命周期绑定到 info）。info 仍然存活，安全。
- 第 547 行：`IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]` — 同上。
- 第 521–524 行：`maximum.flatMap { maxValue -> Double? in guard let current, maxValue > 0 else { return nil }; return current / maxValue }` — 除以 maxValue，guard > 0 防除零。
- 第 533–534 行：`current.map(Int.init)` / `maximum.map(Int.init)` — Double → Int 截断。电池容量 0–100 范围，无损。

**第 568–644 行** `sampleNetworkInterfaces` — getifaddrs 网络接口采样：
- 第 569–571 行：`getifaddrs(&interfaces)` + `defer { freeifaddrs(interfaces) }` — 正确释放。
- 第 580 行：`let flags = Int32(current.pointee.ifa_flags)` — `ifa_flags` 在 macOS 上是 `UInt32`，转 `Int32` 可能变负。但 `flags & IFF_UP` 位运算对负数同样正确。安全。
- 第 594–596 行：仅处理 `AF_LINK` 地址族，读取 `ifa_data` 统计。不提取 IP 地址。隐私安全。
- 第 597 行：`name.withCString { if_nametoindex($0) }` — `withCString` 提供临时 C 字符串。安全。
- 第 609 行：`data.assumingMemoryBound(to: if_data.self).pointee` — 对 AF_LINK 条目，`ifa_data` 指向 `if_data` 结构。data 生命周期绑定到 ifaddrs 链表节点，在 `freeifaddrs` 前有效。安全。
- 第 610–620 行：从 `if_data` 读取 32 位计数器。优先使用 `interfaceStats`（64 位 `if_msghdr2`，第 598 行），回退到 `if_data`（32 位）。良好策略。
- 第 628–643 行：过滤 down 且无流量的接口，排序（loopback 靠后、up 靠前、kind/displayName 字典序），重新编号 index。

**第 679–722 行** `networkInterfaceStatsByIndex` — sysctl NET_RT_IFLIST2：
- 第 686–690 行：`UnsafeMutableRawPointer.allocate(byteCount:alignment:)` + `defer { buffer.deallocate() }` — 正确分配/释放。
- 第 699–718 行：遍历路由消息缓冲区。`offset + MemoryLayout<if_msghdr2>.size <= byteCount` 防越界。`ifm_msglen > 0` 防零长度。
- **第 700 行** `buffer.advanced(by: offset).assumingMemoryBound(to: if_msghdr2.self).pointee` — **质量级**：`assumingMemoryBound` 假设指针对齐满足 `if_msghdr2` 的 alignment 要求。内核通常保证路由消息对齐，但严格来说应使用 `load(fromByteOffset:as:)` 更安全。
- 第 704 行：`header.ifm_type == UInt8(RTM_IFINFO2)` — 只处理 IFINFO2 消息。正确过滤。

**第 735–764 行** `sampleNetworkRate` — 网络速率计算：
- 第 740–745 行：无 byte counters 时重置基线，返回 0。
- 第 747–751 行：`defer` 更新基线。注意：defer 在第 740 行 guard **之后**注册，所以仅在 `hasByteCounters` 为 true 时执行。
- 第 755–759 行：`elapsed > 0` 防除零；`totalBytes.input >= previousNetworkInBytes` 防下溢。计数器回绕时返回 0 但更新基线（下次从新值开始计算）。
- 第 761–762 行：`UInt64(Double(delta) / elapsed)` — delta 是 UInt64 差值（已验证 >= 0），elapsed > 0。截断为 UInt64。安全。

**第 766–774 行** `sampleDiskSpace` — `FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())`。沙盒应用中 NSHomeDirectory() 返回容器路径，但文件系统属性是卷级别的，返回启动卷的容量。正确。

**第 812–866 行** `sampleStorage` — 存储卷采样：
- 第 823–826 行：`mountedVolumeURLs(includingResourceValuesForKeys:options:)` + `.skipHiddenVolumes`。
- **第 855 行** `homePath.hasPrefix($0.mountPath)` — **质量级**：`hasPrefix` 可能匹配部分路径段（如 `/Volumes/Mac` 匹配 `/Volumes/Macintosh HD/...`）。第 856 行 `.sorted { $0.mountPath.count > $1.mountPath.count }` 按路径长度降序排列，优先匹配最长路径，缓解了此问题。但建议加 trailing `/` 做精确匹配（`$0.mountPath == "/"` 例外）。
- 第 858–862 行：标记 primary volume。逻辑正确。

**第 868–893 行** `sampleGPUDevices` — `MTLCopyAllDevices()` 返回 `[MTLDevice]`，ARC 管理。属性全部只读。安全。

**第 895–939 行** `sampleDisplays` — CGGetActiveDisplayList + CGDisplay API：
- 第 897 行：第一次调用获取 count。第 902 行：第二次调用填充数组。两次调用间显示器数量可能变化，但 `prefix(Int(displayCount))` 处理了此情况。
- 第 910 行：`CGDisplayCopyDisplayMode(displayID)` — Copy 语义，ARC 管理，无需手动释放。
- 第 906–908 行：调用 `screenRefreshRatesByDisplayID()` / `screenScalesByDisplayID()` / `screenColorSpacesByDisplayID()`。

**第 906–908 行 + 第 979–1034 行** — **Bug 级**：这三个方法及 `fallbackDisplaysFromScreens()`（第 941–977 行）访问 `NSScreen.screens`、`NSScreen.main`、`NSScreen.backingScaleFactor`、`NSScreen.maximumFramesPerSecond`、`NSScreen.colorSpace`、`NSScreen.frame`、`NSScreen.deviceDescription`。这些 AppKit API 要求在主线程调用。`sample()` 通过 `sampleLock` 保护但可在任意线程执行。若在后台线程调用（典型采样场景），违反 AppKit 线程规则，可能导致数据不一致或 crash。建议：将 NSScreen 相关调用 dispatch 到主线程，或仅使用 CoreGraphics API（CGDirectDisplayID 系列）替代。

**第 1037–1040 行** `screenRefreshRate` — **质量级**：使用 `screen.maximumFramesPerSecond` 作为刷新率。对于 ProMotion 显示器，`CGDisplayModeGetRefreshRate` 返回 0（已知问题），此 fallback 返回 120（最大刷新率），而非当前实际刷新率。对于系统监控应用，显示 120 Hz 可接受（代表显示器能力），但不精确。

**第 1077–1091 行** battery helpers — `validBatteryMinutes` 过滤 < 0 和 >= 65535（IOPS 哨兵值）。`IOPSGetTimeRemainingEstimate` 返回秒，除以 60 转分钟。正确。

**第 1188–1202 行** `intValue` / `doubleValue` — 处理 IOPS 字典中 `Any?` 值的多类型转换。覆盖 Int/Int64/UInt64/NSNumber/String。`Double` 未处理 `Int` 直接转换，但 IOPS 值来自 CFNumber → NSNumber，`as? Double` 通过 NSNumber 桥接生效。安全。

**第 1204–1230 行** sysctl helpers — 标准模式。`sysctlInteger` 在 little-endian 上即使 sysctl 返回较小类型也正确（高位为 0）。`sysctlString` 先查 size 再分配 buffer。`stringFromFixedCString` 用 `withUnsafeBytes` 泛型处理固定 C 数组。正确。

**第 1232–1234 行** `tickArray` — 元组转数组，每次调用分配新 `[UInt32]`。**整洁级**：轻微分配开销，可用 `(UInt32, UInt32, UInt32, UInt32)` 直接索引避免分配。

---

### MetricFormatting.swift（94 行）

**第 4–8 行** `percentage` — `guard value.isFinite` 处理 NaN/Infinity。`min(max(value, 0), 1)` 钳位到 [0, 1]。`Int((clamped * 100).rounded())` 四舍五入。正确。

**第 10–25 行** `bytes` — 除以 1024 循环选择单位，units 数组到 "TB" 为止。
- **质量级**：无 PB/EB 单位。`UInt64.max` ≈ 18.4 EB。累积网络字节计数器理论上可超过 1024 TB，此时显示如 "2048.0 TB" 而非 "2.0 PB"。当前 macOS 存储最大 ~8TB，内存 ~128GB，TB 足够。但 `compactBytes` 用于网络累积计数（MetricSnapshot 第 692 行），长期运行可能超过。
- 第 20–21 行：`unitIndex == 0`（字节）时用整数显示，避免 "1024.0 B"。正确。

**第 27–42 行** `compactBytes` — 同 `bytes` 但用 `%.0f`（无小数）。同上缺少 PB/EB。**质量级**。

**第 44–47 行** `networkRate` — `Double(bytesPerSecond) * 8` 转 bit/s。UInt64.max × 8 不溢出 Double。

**第 49–61 行** `bitRate` — `guard isFinite` + `max(0, ...)`。三档：Gbps/Mbps/Kbps。
- **质量级**：无 Tbps 档。1000 Gbps 显示 "1000.0 Gbps" 而非 "1.0 Tbps"。100 Gbps 网络已存在，长远可能需要。
- **质量级**：低于 500 bps 时 `Int((500/1000).rounded())` = `Int(0)` = 0 → 显示 "0 Kbps"。应增加 bps 档或特殊处理 0 值。

**第 63–65 行** `byteRate` — `"\(compactBytes(bytesPerSecond))/s"`。简洁。

**第 67–70 行** `load` — `guard isFinite` + `%.1f`。正确。未处理负值（load average 不会为负）。

**第 72–76 行** `duration` — `Int(seconds / 60)` 转分钟。`Int(Double)` 在值超过 Int.max 时会 crash，但需要 seconds > 5.5×10^20（~17 万亿年），不可能。

**第 78–93 行** `minutes` — `max(value, 0)` 防负。天/小时/分钟分解。`totalMinutes % 1440 / 60` 和 `totalMinutes % 60` 正确。
- 0 分钟 → "0m"。1440 分钟 → "1d 0h"。60 分钟 → "1h 0m"。正确。

---

### MenuBarPopoverGeometry.swift（173 行）

**第 4 行** `windowChromeAllowance: CGFloat = 28` — **整洁级**：魔法数字未注释说明 28 的来源（窗口标题栏 + 边框估算值）。

**第 23–67 行** `placement` — 组合 availableHeight/clampedHeight/clampedWidth/preferredEdge/anchorScreenMidX。各子函数职责清晰。

**第 31–38 行** `visibleFrame == nil` 时 availableHeight = preferredSize.height — 无屏幕信息时的降级。合理。

**第 69–88 行** `constrainedWindowFrame` — 将 proposedFrame 限制在 visibleFrame inset by margin 内。
- 第 74–75 行：`min(max(0, screenMargin), max(0, visibleFrame.width / 2))` — margin 钳位到 [0, width/2]。防止 margin 超过半屏。
- 第 77–78 行：`constrainedWidth = min(proposedFrame.width, availableFrame.width)` 保证 `availableFrame.maxX - constrainedWidth >= availableFrame.minX`。constrainedX 不会越界。正确。
- 第 79–80 行：X/Y 双重钳位 `min(max(min, proposed), max - size)`。正确。

**第 90–107 行** `anchorScreenMidX` — 计算弹出窗口中心 X 坐标。
- 第 102–104 行：`minimumCenter > maximumCenter`（窗口比可用区域宽）时回退到 `visibleFrame.midX`。正确。
- 第 106 行：`min(max(anchorFrame.midX, minimumCenter), maximumCenter)` — 钳位锚点中心。正确。

**第 109–117 行** `clampedWidth` — `min(preferredWidth, max(0, visibleFrame.width - horizontalMargin * 2))`。`max(0, ...)` 防止浮点误差导致负值。正确。

**第 119–144 行** `availableHeight` — statusBar 锚点用 anchorFrame.minY 上方空间；regular 锚点取上下空间最大值。减去 windowChromeAllowance 后 `max(1, ...)` 保证至少 1。正确。

**第 146–162 行** `preferredEdge` — statusBar 固定 .minY；regular 比较上下空间选择边。第 158 行 `availableBelow >= contentHeight || availableBelow >= availableAbove` — 下方能放下或下方更大则选下方。合理。

**第 164–172 行** `clampedHeight` — `availableHeight < minimumHeight` 时返回 visibleHeight（允许缩到最小以下）；否则 `max(minimumHeight, visibleHeight)` 保证至少 minimumHeight。逻辑正确。

**总体评价**：纯值类型 enum/struct，无副作用，无外部依赖，无线程安全问题。几何计算严谨，边界条件处理完善。代码质量高。

---

### WidgetTimelineKind.swift（3 行）

```swift
public enum WidgetTimelineKind {
    public static let pulseDock = "PulseDockWidget"
}
```

无 case 的 enum 作为命名空间，防止实例化。`public static let` 字符串常量。

**整洁级**：未声明 `Sendable`。无 case 的 enum 隐式 Sendable（无可变状态），但 Swift 6 严格模式可能要求显式声明。建议添加 `: Sendable`。

---

## 问题汇总

### Bug 级（必须修）
| # | 文件:行号 | 问题 | 严重度 | 建议 |
|---|-----------|------|--------|------|
| 1 | SystemSampler:906-908,941-977,979-1034 | NSScreen.screens/main/backingScaleFactor/maximumFramesPerSecond/colorSpace/frame/deviceDescription 在后台线程访问。AppKit NSScreen 要求主线程。sample() 可在任意线程调用，违反线程安全规则。 | 高 | 将 NSScreen 相关调用 dispatch 到主线程同步获取，或完全改用 CoreGraphics API（CGDirectDisplayID 系列）替代 NSScreen。 |
| 2 | SystemSampler:1037-1040 | `screenRefreshRate` 使用 `maximumFramesPerSecond` 作为刷新率。ProMotion 显示器在降频时（如 60Hz）仍返回 120，不准确。 | 中 | 使用 `CGDisplayModeGetRefreshRate` 或 NSScreen 的 `minimumRefreshInterval`/`maximumRefreshInterval` 获取实际刷新率。若 CGDisplayMode 返回 0（ProMotion 已知问题），可考虑读取 `screen.availableModes` 匹配当前 mode 的刷新率。 |

### 质量级（建议修）
| # | 文件:行号 | 问题 | 严重度 | 建议 |
|---|-----------|------|--------|------|
| 1 | SystemSampler:411-413 | UInt32 页计数相加可能溢出（active+wire+compressor）。实践中不溢出（~128GB → 3300万页 << 40亿）但防御性不足。 | 低 | 改为 `UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)`。 |
| 2 | SystemSampler:700 | `assumingMemoryBound(to: if_msghdr2.self)` 假设指针对齐满足要求。内核通常保证但非显式。 | 低 | 改用 `buffer.load(fromByteOffset: offset, as: if_msghdr2.self)` 避免对齐假设。 |
| 3 | SystemSampler:855 | `homePath.hasPrefix($0.mountPath)` 可能匹配部分路径段（如 `/Volumes/Mac` 匹配 `/Volumes/Macintosh HD/...`）。sorted-by-length 降序缓解了此问题。 | 低 | 改为精确匹配：`homePath == $0.mountPath \|\| homePath.hasPrefix($0.mountPath + "/") \|\| $0.mountPath == "/"`。 |
| 4 | MetricFormatting:11,28 | bytes/compactBytes 缺少 PB/EB 单位。累积网络计数器长期运行可能超过 1024 TB。 | 低 | 添加 "PB"/"EB" 到 units 数组。 |
| 5 | MetricFormatting:52-60 | bitRate 缺少 Tbps 档和 bps 档。低于 500 bps 显示 "0 Kbps"，高于 999.9 Gbps 显示超大 Gbps 值。 | 低 | 增加 bps 档（< 1000 bps）和 Tbps 档（>= 1e12 bps）。 |
| 6 | MetricSnapshot:跨类型 | 向后兼容推断策略不一致：ProcessMetric 用 OR（lenient），DisplayMetric/MetricSnapshot 用 AND（strict）。AND 策略缺一个 key 就使整个报告视为未报告。 | 中 | 统一为 OR 策略或引入"部分报告"中间状态。至少在 MetricSnapshot 的 hasMemoryCompositionReport/hasNetworkPathCostReport/hasNetworkPathSupportReport/hasRunningAppCountReport 推断中改用 OR。 |
| 7 | MetricSnapshot:1689-1690 vs 899-901 | decoder 用 `??`（key 存在则直接用），init 用 `||`（合并推断）。旧 JSON 有 `hasLoadAverageReport:false` + `loadAverage:5.0` 时，decoder 保留 false 但 init 会算 true。 | 低 | decoder 也用 OR 合并：`decodedValue \|\| (loadAverage > 0 \|\| ...)`。 |
| 8 | MetricSnapshot:899-901,1689-1690 | load average 全为 0.00 时 hasLoadAverageReport=false → 显示"未报告"。极罕见（getloadavg 返回 0.00 几乎不可能）。 | 低 | hasLoadAverageReport 的推断不应依赖值 > 0；仅依赖 getloadavg 调用是否成功（SystemSampler 已正确处理）。decoder 推断可改为检查 key 存在而非值 > 0。 |
| 9 | MetricSnapshot:1049-1054 | memoryActiveBytes 中 `memoryWiredBytes + memoryCompressedBytes` 是 UInt64 相加，理论可溢出。 | 低 | 改用 `memoryUsedBytes > memoryWiredBytes && memoryUsedBytes - memoryWiredBytes > memoryCompressedBytes` 分段比较。 |
| 10 | MetricSnapshot:190-193 | GPUDeviceMetric hasDeviceKindReport 推断：单 key 存在且值为 false 时不报告，双 key 存在且值都为 false 时报告。不对称。 | 低 | 简化为 `hasLowPowerKey \|\| hasRemovableKey`（任一 key 存在即有 kind 报告）。 |
| 11 | MetricSnapshot:734-745 | compactCount 用 "B" 表示 Billion，与 MetricFormatting 中 "B" 表示 Byte 容易混淆。 | 低 | 改用 "G" 表示 Giga（十亿），或拼写出 "Billion"。 |
| 12 | SystemSampler:229-231 | sampleLock 持锁整个采样周期（含所有 I/O），并发调用串行化。 | 低 | 设计取舍：粗锁保证快照一致性。若需优化可分离 inventory cache 锁（已缓存时快速返回）。当前可接受。 |
| 13 | MetricSnapshot:944-947,952 | hasRunningAppCountReport/hasUptimeReport 用 `|| count > 0` 推断。全 0 值被视为未报告。实践中不影响。 | 低 | 仅依赖显式标志，不做值推断。或改为检查 key 存在而非值 > 0。 |

### 整洁级（可后续）
| # | 文件:行号 | 问题 | 严重度 | 建议 |
|---|-----------|------|--------|------|
| 1 | MetricSnapshot:全文 | `!= "未报告"` 魔法字符串比较遍布全文（hasInventoryReport 等）。若归一化值变更需全文修改。 | 低 | 定义常量 `static let unreported = "未报告"` 或用 Optional 表示"未报告"。 |
| 2 | MetricSnapshot:1664-1751 | decoder 默认值混用 `Self.placeholder.xxx` 和字面量 `0`，风格不一致。 | 低 | 统一用一种风格。 |
| 3 | MetricSnapshot:1272-1289 | powerStatusProgress 魔法数字（0.45/0.7/0.55）未注释。 | 低 | 添加注释说明各电源类型的进度条显示值含义。 |
| 4 | MenuBarPopoverGeometry:4 | windowChromeAllowance = 28 未注释来源。 | 低 | 添加注释说明 28 的计算依据。 |
| 5 | SystemSampler:374 | `isReported: totalTicks > 0` 在 guard totalTicks > 0 之后，恒为 true，冗余。 | 低 | 直接写 `isReported: true`。 |
| 6 | SystemSampler:1232-1234 | tickArray 每次调用分配新 [UInt32]。 | 低 | 直接用元组索引 `ticks.0/ticks.1/...` 避免分配。 |
| 7 | WidgetTimelineKind:1 | 未声明 Sendable。 | 低 | 添加 `: Sendable`。 |

---

## 亮点（做得好的部分）

1. **Mach/IOKit 内存管理严谨**：`mach_port_deallocate`（第 317/392 行）、`vm_deallocate`（第 329–332 行）、`freeifaddrs`（第 571 行）、`takeRetainedValue`/`takeUnretainedValue`（第 481/491/542/547 行）的 CF 生命周期管理全部正确。defer 注册位置正确（guard 之后的 defer 不会在 guard 失败时误释放）。

2. **计数器回绕处理**：CPU ticks（第 354 行）和网络字节（第 756–757 行）都正确处理了计数器回绕（current < previous 时 delta = 0）。

3. **向后兼容解码**：所有自定义 decoder 使用 `decodeIfPresent` + key 存在性检查推断 missing 标志。支持新旧 JSON 格式共存。

4. **除零防护全面**：所有除法操作（memoryUsage、diskUsage、loadProgress、networkRate）均有 guard 防护除数 > 0。

5. **UInt64 下溢防护**：`diskUsedBytes`（第 1032 行）和 `usedBytes`（第 512–515 行）均检查被减数 >= 减数。

6. **隐私安全**：网络接口采样仅读取 AF_LINK 统计数据，不提取 IP/MAC 地址。不收集序列号或硬件 UUID。仅使用公开 API。

7. **线程安全**：`NetworkPathObserver` 和 `SystemSampler` 的 `@unchecked Sendable` 合规——所有可变状态受锁保护，`let` 属性不可变。锁顺序一致（sampleLock → networkPathObserver.lock），无死锁风险。

8. **`@unknown default` 处理**：thermalState switch（第 475 行）和 NWPath.Status switch（第 180 行）均处理了未来未知案例。

9. **64 位网络计数器优先**：`sampleNetworkInterfaces` 优先使用 `if_msghdr2`（64 位计数器）的 sysctl 路径，回退到 `if_data`（32 位）。减少了计数器回绕风险。

10. **Codable 对称性**：encode→decode round-trip 保证所有属性保留。decoder 的推断逻辑镜像 init 的计算逻辑（虽有细微不对称，见质量级 #7）。

---

## 模块整体评价

SharedMetrics 模块整体质量**高**，代码成熟度高，适合 App Store 上架。

**核心优势**：
- 底层系统 API（Mach/IOKit/CFNetwork）的使用和内存管理正确且严谨
- 数据模型设计完善——"已报告/部分报告/未报告"三态标志贯穿全文
- 隐私合规——不收集设备指纹，仅使用公开 API
- Codable 向后兼容设计周到

**主要风险**：
- **Bug #1（NSScreen 线程安全）是上架前应修复的项目**——虽然实践中常不 crash，但 Apple 审核可能 flagged，且在特定条件下可能导致 UI 线程相关问题
- **Bug #2（ProMotion 刷新率）影响数据显示准确性**——用户可能注意到刷新率显示不正确

**建议修复优先级**：
1. 上架前修复 Bug #1（NSScreen 主线程访问）
2. 上架前评估 Bug #2（ProMotion 刷新率是否影响用户体验）
3. 质量级 #6（推断策略统一）可作为后续版本改进
4. 其余质量级/整洁级可纳入技术债务 backlog

**App Store 合规评估**：无私有 API 使用，无设备指纹收集，无隐私敏感数据泄露。IOKit/Mach/Network/SystemConfiguration/Metal/CoreGraphics 均为公开框架。网络接口采样仅读取流量统计，不涉及 IP 地址。电池信息通过公开 IOKit API 获取。合规风险低。
