# SystemDashboardWidget 模块深度审查报告

## 审查概要
- 文件数：1
- 总行数：750
- 发现问题数：15
  - Bug 级：3
  - 质量级：7
  - 整洁级：5

审查范围：`Sources/SystemDashboardWidget/SystemDashboardWidget.swift` 全部 750 行。同时交叉参考了 `SharedMetrics/MetricSnapshot.swift`、`SharedMetrics/SystemSampler.swift`、`SharedMetrics/WidgetTimelineKind.swift`、`Tests/SharedMetricsTests/MetricFormattingTests.swift` 以验证字段语义和测试覆盖。

---

## 逐段审查

### 1. 导入与 SystemEntry（1-11 行）

- 第 4-6 行：`#if canImport(SharedMetrics)` 条件导入，写法正确，便于在沙盒缺失时编译降级。
- 第 8-11 行：`SystemEntry` 仅包含 `date` + `snapshot: MetricSnapshot?`。`snapshot` 为可选，用于区分"有数据 / placeholder"两条路径，设计简洁。
- 无问题。

### 2. WidgetSamplerCache（13-29 行）

- 第 13 行：`@unchecked Sendable` + `NSLock`，手动线程安全。合理。
- 第 14 行：`systemSampler` 为常量强引用，由 static 单例持有，生命周期等于 widget extension 进程。
- 第 18-28 行：`sample()` 加锁后：
  - 若 `!isPrimed`：先调用一次 `systemSampler.sample()`（prime，结果被 `_ =` 丢弃），置 `isPrimed = true`；
  - 再调用一次 `systemSampler.sample()` 返回。

**关键 Bug**（见问题汇总 #1）：`SystemSampler.sampleCPUUsage()`（`SystemSampler.swift:338-341`）首次调用时 `previousCPUInfo` 为空，会写入当前 tick 数据并返回 `isReported: false`。prime 调用完成后立刻进行第二次 sample，两次调用间隔仅微秒级，CPU tick 增量极小但 > 0，于是 `hasCPUUsageReport` 被置为 `true`，而 `cpuUsage = 1 - idle/total` 在极小窗口内噪声极大（可能 0% 也可能接近 100%）。**widget 进程冷启动后首次显示的 CPU 百分比是不可信的**。

- 第 16 行：`isPrimed` 一旦置 true 永不复位。若运行期核心数变化导致 `previousCPUInfo.count != info.count`，`SystemSampler` 内部会自复位（`SystemSampler.swift:338-340`），后续采样仍能恢复——此场景在 widget 短生命周期内极罕见，可接受。

### 3. SystemProvider 与时间线（31-52 行）

- 第 32 行：`static let samplerCache = WidgetSamplerCache()`。Swift 静态 let 是懒加载且线程安全（dispatch_once 语义）。`SystemProvider` 是 struct，每次 WidgetKit 构造 provider 都共享同一缓存，便于保持 prime 状态。设计正确。
- 第 34-36 行：`placeholder` 返回 `snapshot: nil` → 走 `EmptyDataWidget` skeleton。这是 WidgetKit placeholder 的合理实现。
- 第 38-40 行：`getSnapshot` 同步调用 `sampledSnapshot()` 并 completion。`sample()` 涉及 mach host 调用、sysctl、battery 查询，但锁内执行且已 prime，延迟可控。可接受。
- 第 42-47 行：`getTimeline` 只生成 **1 个 entry**，`policy: .after(nextRefresh)`，5 分钟刷新。
  - 第 45 行：`Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)`，fallback 与主路径等价，防御性写法到位。
  - 5 分钟对系统指标合理；WidgetKit 实际刷新可能被系统节流到更久，这是平台行为，非代码问题。
  - 单 entry 策略对实时指标正确（预生成多 entry 会失真），但错失了用第二个 entry 修复 CPU prime Bug 的机会（见建议 #1）。

### 4. compactWidgetSnapshot（54-109 行）

逐字段对照 `MetricSnapshot` 的完整 init（`MetricSnapshot.swift:813-877`）：

| 字段 | 处理 | 备注 |
|------|------|------|
| cpuUsage / cpuCoreUsages / hasCPUUsageReport | 保留 | OK |
| physicalCoreCount / logicalCoreCount / activeProcessorCount | 保留 | OK |
| cpuBrandName | 显式 nil | widget 不显示品牌，OK |
| memoryUsedBytes / memoryTotalBytes | 保留 | OK |
| memoryFreeBytes / memoryWiredBytes / memoryCompressedBytes / memoryCachedBytes | **未传，走默认 0** | widget 不显示内存构成，OK 但脆弱 |
| memorySwap* | 保留 | OK |
| hasMemoryCompositionReport | **未传，走默认 false** | 与上面字段一致，OK |
| loadAverage* / hasLoadAverageReport | 保留 | OK |
| thermalState | 保留 | OK |
| batteryPercent / batteryIsCharging / batteryPowerSource / batteryTimeRemainingMinutes | 保留 | OK |
| batteryCycleCount / batteryHealth / batteryDesignCapacity / batteryVoltageMillivolts / batteryAmperageMilliamps | **未传，走默认 nil** | widget 不显示这些，OK 但脆弱 |
| hasNetworkByteCounters / hasNetworkDirectionByteCounters | 显式 false | OK |
| networkPath* / networkPathInterfaceKinds | 保留 | OK |
| networkInBytesPerSecond / networkOutBytesPerSecond | 显式 0 | OK |
| networkInterfaces | 经 `compactWidgetInterfaces` 裁剪 | 见下段 |
| diskFreeBytes / diskTotalBytes | 保留 | OK |
| storageVolumes | 显式 `[]` | OK |
| processCount / active/hiddenApplicationCount / hasRunningAppCountReport | 显式 0 / false | OK |
| topProcesses / gpuDevices / displays | 显式空 | OK |
| uptimeSeconds / hasUptimeReport / osVersion / kernelRelease / timestamp | 保留 | OK |

**质量隐患**（#4）：约 10 个字段依赖 init 默认值被静默置零/nil。当前 widget 视图未使用它们，功能正确；但若未来 `MetricSnapshot` 新增带默认值的字段且 widget 需要该字段，`compactWidgetSnapshot` 不会编译报错，数据会被悄悄丢弃。建议在 `MetricSnapshot` 上提供一个 `widgetCompact()` 工厂方法或用 `var` 拷贝修改，杜绝漏字段。

- 第 79-80 行：`hasNetworkByteCounters: false` + `hasNetworkDirectionByteCounters: false`。配合 `compactWidgetInterfaces` 中 `hasByteCounters: false`，`MetricSnapshot.init` 的派生逻辑（`MetricSnapshot.swift:914-925`）最终也得到 `false`，一致。
- 第 95-102 行：清空 `storageVolumes / topProcesses / gpuDevices / displays`，对应 `hasExternalStorageVolumeSummaryReport`、`hasGPUReport`、`hasDisplayReport` 等派生属性全部返回 false / "未报告"，与 widget 不展示这些信息一致。

### 5. compactWidgetInterfaces（111-128 行）

- 第 113 行：`filter(\.hasInterfaceStateReport)` 先剔除未报告接口。
- 第 114-115 行：`enumerated().map`，用新枚举下标作为 `index`。
- 第 118-119 行：`displayName: "未报告"`、`kind: "未报告"` —— 原始接口名被丢弃。
- 第 120-122 行：保留 `isUp` / `isLoopback` / `hasInterfaceStateReport: true`，这是 `networkInterfaceSummary`（`MetricSnapshot.swift:1586-1590`）和 `activeInterfaceProgress`（本文件 726-731 行）所依赖的字段，功能正确。
- 第 123-125 行：`bytesReceived/bytesSent: 0`、`hasByteCounters: false`，配合 `compactWidgetSnapshot` 已显式禁用网络字节计数。

**质量隐患**（#6）：`displayName` / `kind` 被覆写为字面量 "未报告"，未来若 widget 想展示接口名需回改此处。当前不展示，OK。

### 6. SystemDashboardWidgetView（130-148 行）

- 第 135-143 行：`switch family` 走 Small/Medium/Large；`default` 落到 `LargeWidget`。由于 `supportedFamilies` 只声明三种，`default` 永不命中，但作为兜底合理。
- 第 144-146 行：`snapshot == nil` 走 `EmptyDataWidget`。
- **可访问性缺失**（#2）：整个 `SystemDashboardWidgetView` 没有 `.accessibilityLabel`，内嵌的子视图也都缺失（详见下文）。VoiceOver 用户无法获得 widget 整体语义。

### 7. SystemDashboardWidget / Bundle（150-172 行）

- 第 151 行：`kind = WidgetTimelineKind.pulseDock`（值为 `"PulseDockWidget"`），与 WidgetKit 期望的稳定标识一致。
- 第 154-159 行：`StaticConfiguration` + `containerBackground(for: .widget) { WidgetBackground() }`。`containerBackground(for: .widget)` 是 macOS 14 / iOS 17+ 必需写法，正确。
- 第 160-161 行：`configurationDisplayName("Pulse Dock")` + 中文 `description`。
  - **质量隐患**（#5）：硬编码字符串未走 `LocalizedStringKey` / String Catalog。若 App Store 面向多语言发布，需本地化。若仅中文市场，可接受。
- 第 162 行：`.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])`。Mac widget 合理，无 `.systemExtraLarge`（iPad）和 accessory 系列（iOS 锁屏），符合 macOS 定位。
- 第 163 行：`.contentMarginsDisabled()`，widget 自管 padding（14/16/18）。合理。
- 第 167-172 行：`@main` WidgetBundle，仅含一个 widget。正确。

### 8. SmallWidget（179-203 行）

- 第 183 行：`VStack(alignment: .leading, spacing: 12)`。
- 第 184 行：`WidgetHeader` 含标题 + 时间。
- 第 186 行：`Spacer(minLength: 4)`。
- 第 188-191 行：两个 `RingMetric`（CPU / MEM），`spacing: 12`。
- 第 193-199 行：三个 `MiniStatus`（热 / 网 / 电），中间两个 `Spacer()` 均匀分布。
- 第 201 行：`.padding(14)`。
- 布局合理。`reportedProgress` 包装 nil 进度，未报告时 `RingMetric` 只画轨道，OK。
- 第 198 行：`compactPowerStatusText(snapshot)` 是 Small 专用简化版（733-749 行），Medium/Large 用 `powerStatusText`。差异合理：Small 空间小，显示百分比或"充电/电源/电池/UPS"短文本。
- **可访问性缺失**（#2）。

### 9. MediumWidget（205-238 行）

- 第 206 行：`@Environment(\.colorScheme)`。
- 第 210 行：`HStack(alignment: .center, spacing: 22)`。
- 第 226 行：左列固定 `width: 166`。Medium widget 标准宽约 329pt，减去左右 padding 18*2=36、间距 22，剩 271pt；左 166 + 右 105。右列 `WidgetRow` 进度条较窄，靠 `minimumScaleFactor` 兜底。
- 第 213-217 行：CPU 大字号 52pt + `minimumScaleFactor(0.60)` + `lineLimit(1)`。长文本 / 某些本地化下可能压到很小，但 widget 字体是设计意图，可接受。
- 第 218-222 行：`logicalCoreSummaryText` 11pt + `minimumScaleFactor(0.72)`。
- 第 224 行：`MediumStatusStrip`（热 + 电）。
- 第 228-232 行：右列三个 `WidgetRow`（内存 / 连接 / 磁盘），`progress` 用 `reportedProgress` 包装，`tint` 用对应色。
- 第 235-236 行：`.padding(.horizontal, 18)` + `.padding(.vertical, 18)`。
- **可访问性缺失**（#2）。

### 10. MediumStatusStrip（240-249 行）

- 两个 `MiniStatus` 左对齐，`spacing: 10`。无 Spacer，紧凑。OK。
- **可访问性缺失**。

### 11. LargeWidget（251-288 行）

- 第 255 行：`VStack(spacing: 16)`。
- 第 258 行：`HStack(alignment: .top, spacing: 18)`。
- 第 260-265 行：`LazyVGrid` 2 列 4 个 `RingMetric`（CPU / 内存 / 磁盘 / 负载）。
  - 第 264 行：`progress: snapshot.loadAverageProgress`。`loadAverageProgress` 本身返回 `Double?`（`MetricSnapshot.swift:1119`，未报告时 nil），直接传入 `RingMetric` 的 `Double?` 参数，**无需 `reportedProgress` 包装**，正确。与其他 RingMetric 用 `reportedProgress` 风格略不同但语义等价。
- 第 267-270 行：两个 `StatTile`（电源 / 热状态）。
- 第 272 行：左列固定 `width: 148`。2 列 ring 各 54pt + spacing 12 = 120，留 28 余量，OK。
- 第 274-283 行：右列 `LargeWidgetSection`（连接 / 路径 / 接口）+ `LargeInfoGrid`。
- 第 286 行：`.padding(18)`。
- **可访问性缺失**（#2）。

### 12. LargeInfoGrid（290-303 行）

- 第 295-298 行：两个 `StatTile`（运行 / 系统）横排。
- 第 300 行：一个 `StatTile`（内核）独占一行。
- `osVersionText` 可能为 "Version 14.5 (Build 23F79)"，`lineLimit(1)` + `minimumScaleFactor(0.58)` 在右列 flex 宽度内通常 OK，但极端长版本串仍可能截断。属于设计取舍。
- **可访问性缺失**。

### 13. LargeWidgetSection（305-324 行）

- 泛型容器，`@ViewBuilder` 初始化。
- 第 314 行：`VStack(spacing: 10)`。
- 第 317-318 行：`padding(10)` + `widgetPanelFill` 圆角背景。
- 第 319-322 行：`overlay` 描边 `lineWidth: 0.6`。
- 设计干净，复用性好。

### 14. EmptyDataWidget（326-371 行）

- 第 330 行：`spacing` 按 family 区分 12 / 14。
- 第 331-341 行：header 与 `WidgetHeader` 相似但 **circle 用 amber**（`WidgetColor.amber`，第 338 行），暗示"无数据"。而 `WidgetHeader` 用 green。差异是有意设计。
- 第 343-353 行：Small —— 2 个 `PlaceholderMetricSkeleton` + 3 个 `PlaceholderDot`，对应真实 Small 的 2 ring + 3 mini status。
- 第 354-367 行：Medium/Large —— 2（或 Large 3）个 skeleton ring + 3 个 `PlaceholderBar`。
- 第 369 行：`.padding(16)`。
- **质量隐患**（#7）：skeleton 的 ring trim 0.62、bar widthRatio 0.74/0.46/0.58 看起来像真实数据，且无"加载中/无数据"文字提示。Apple WidgetKit placeholder 指南确实推荐 skeleton 风格，amber 圆点是有效区分信号，但首次加载时仍可能误导用户以为是真实低数值。可考虑在 header 加极小的"加载中"标识或让 ring trim 走呼吸动画（widget 静态视图无动画，可忽略）。
- **可访问性缺失**（#2）：placeholder 也应有 "Pulse Dock 数据加载中" 之类的 label。

### 15. PlaceholderMetricSkeleton / PlaceholderBar / PlaceholderDot（373-425 行）

- 第 382-384 行：`trim(from: 0, to: 0.62)` + `rotationEffect(-90)`，与 `RingMetric` 的 ring 风格一致。
- 第 389-390 行：54pt frame + `maxWidth: .infinity`，与 `RingMetric` 尺寸一致。
- 第 405 行：`max(18, proxy.size.width * min(max(widthRatio, 0), 1))`，clamp + 最小可见宽，鲁棒。
- 第 423 行：`PlaceholderDot` `maxWidth: .infinity` 让三个 dot 均分。
- 实现整洁。

### 16. WidgetHeader / CompactWidgetHeader（427-477 行）

- `WidgetHeader`（427-453）：icon + title + green dot + Spacer + 可选 time。
  - **可访问性缺失**（#2）：无 `accessibilityLabel`，time 文本 VoiceOver 读取碎片化。
- `CompactWidgetHeader`（455-477）：icon + title + green dot，**无 time 显示**。
  - 第 475 行：`.accessibilityLabel(hasTimeReport ? "\(title), \(timeText)" : title)`。
  - **Bug**（#3）：当 `hasTimeReport == true`，accessibilityLabel 包含 `timeText`，但视觉上 CompactWidgetHeader **不显示时间**（与 `WidgetHeader` 不同，Compact 版删掉了 `if hasTimeReport { Text(timeText) }`）。VoiceOver 用户听到的时间信息，明眼用户看不到——信息不对称。若是有意"无障碍补偿"，应在注释说明；否则应移除 label 中的 timeText，或恢复视觉显示。

### 17. RingMetric / WidgetRow / MiniStatus / StatTile（479-595 行）

- `RingMetric`（479-511）：
  - 第 493 行：`min(max(progress, 0), 1))` clamp，OK。
  - 第 491 行：`if let progress` nil 时不画进度环，OK。
  - 第 501 行：`minimumScaleFactor(0.6)`，value 文本自适应。
  - **可访问性缺失**。
- `WidgetRow`（513-546）：
  - 第 539 行：`progressFillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 6)`，最小 6pt 可见，OK。
  - 第 536 行：`if let progress` nil 时不画进度条，OK。
  - **可访问性缺失**。
- `MiniStatus`（548-567）：
  - 第 564 行：`minimumScaleFactor(0.64)`。
  - **可访问性缺失**。
- `StatTile`（569-595）：
  - 第 585 行：`minimumScaleFactor(0.58)`。
  - 第 587-593 行：panel 背景 + 描边，与 `LargeWidgetSection` 风格一致。
  - **可访问性缺失**。

### 18. WidgetBackground 与颜色辅助函数（597-651 行）

- `WidgetBackground`（597-611）：
  - 第 601-605 行：`LinearGradient` 三色渐变。
  - 第 606-609 行：`overlay(alignment: .topLeading) { Rectangle().fill(...) }`。
  - **质量隐患**（#8）：`Rectangle()` 会填满整个 overlay 区域，`alignment: .topLeading` 对全填充 Rectangle 无任何效果——是死代码。若原意是只在左上角加高光，应改用 `Rectangle().fill(...).frame(height: ...)` 或 `LinearGradient` 局部叠加。当前效果是整张背景叠加一层白色 5%（暗）/24%（亮），功能上等同于去掉 alignment。
- `widgetBackgroundColors`（613-627）：暗色三色 + 亮色三色，opacity 渐变，设计到位。
- `widgetPrimaryText`（637-639）：暗色用 `Color.white.opacity(0.92)`，亮色用 `Color.primary`。不一致是有意的——因为背景是自定义渐变，亮色下 `Color.primary`（近黑）在浅色背景上对比度好；暗色下若用 `Color.primary`（近白）会过亮，故用 0.92 opacity。可接受，但建议两端都显式指定以避免 system accent 干扰。
- `widgetSecondaryText` / `widgetTrackFill` / `widgetPlaceholderFill`：暗色用 white opacity，亮色用 secondary opacity，模式一致。

### 19. WidgetColor 枚举（653-659 行）

- 5 个静态色：blue / green / amber / cyan / red。
- 全部在本文件内被使用：green（CPU/正常）、blue（内存/系统）、amber（磁盘/警告）、cyan（未知/网络能力）、red（热临界/离线/电量低）。
- 色值固定 RGB，不随系统 accent 变化。这是 widget 设计选择（保证背景上可读），OK。

### 20. tint / progress 辅助函数（661-731 行）

- `thermalTint`（661-669）：`state.lowercased()` switch。覆盖 nominal/fair/warm/serious/critical/hot/unknown + default cyan。macOS `ProcessInfo.thermalState` 映射为 nominal/fair/serious/critical，覆盖完整。"hot" 是冗余分支但无害。
- `networkTint`（671-682） + `networkPathProgress`（684-695）：基于 `networkPathStatus.lowercased()` switch，三种状态 + default。
  - 第 692-694 行：default 返回 0；但 `reportedProgress(hasReport: hasNetworkPathReport, ...)` 在 unknown 时 hasNetworkPathReport 为 false → 返回 nil，0 永不被使用。轻微冗余，无害。
- `reportedProgress`（697-700）：简洁的 nil 包装。
- `progressFillWidth`（702-706）：clamp + `guard > 0 else { return 0 }` + `max(minimumVisibleWidth, ...)`。逻辑严谨。
- `reportedTint`（708-711）：未报告统一 cyan，合理。
- `powerTint`（713-724）：基于 `MetricStatusTone` 枚举 switch，4 个 case 全覆盖。OK。
- `activeInterfaceProgress`（726-731）：
  - 第 727 行：`filter(\.hasInterfaceStateReport)`；
  - 第 728 行：`guard !isEmpty else { return 0 }`；
  - 第 729-730 行：再 `filter { isUp && !isLoopback }` + `min(.../..., 1)`。
  - **整洁级**（#9）：两次 filter 可合并为一次 `reduce` 或 `partition`，减少遍历。性能影响微乎其微。

### 21. compactPowerStatusText（733-749 行）

- 第 734-736 行：`if let batteryPercent` → 百分比。OK。
- 第 738-748 行：switch `batteryPowerSource?.lowercased()`，覆盖 ac / battery / ups / .some / nil（default）。
  - 第 740 行：`batteryIsCharging ? "充电" : "电源"`，AC 下区分充电/未充电，合理。
  - 第 745 行：`.some` 兜底"外接"，处理未知电源类型，OK。
  - 第 747-748 行：`default` "未报告"（含 nil 情况），OK。
- 与 `MetricSnapshot.powerStatusText`（1266-1268 行）的"电源 → batteryPercentText"分支不同，这里是 Small 专用的更短文本，差异合理。

### 22. 测试覆盖核查

`Tests/SharedMetricsTests/MetricFormattingTests.swift` 中关于本 widget 的测试（共 40+ 处引用）全部是 **结构断言**——用 `String(contentsOf:)` 读源文件后 `#expect(widget.contains("..."))` 检查字符串存在（如 3741 行验 `WidgetSamplerCache`、3742 行验 `static let samplerCache`、7344 行验 `compactWidgetSnapshot` 函数签名、1402 行验某 `RingMetric` 调用串）。

**无任何行为测试**：未测试 timeline 生成、未测试 `compactWidgetSnapshot` 字段映射正确性、未测试 `compactWidgetInterfaces` 过滤、未测试 `thermalTint` / `networkTint` / `powerTint` 分支、未测试三种 family 的视图组合。结构测试能防"被误删"，但防不了"语义改错"。

### 23. 隐私 / App Store 合规

- `Resources/Widget/PrivacyInfo.xcprivacy` 存在（已确认），widget extension 有独立隐私清单，符合 App Store 要求。
- widget 使用的 mach / sysctl / battery / network path API 都在 `SystemSampler` 内，本文件不直接调用私有 API。
- `configurationDisplayName` / `description` 中文硬编码（见 #5）。
- 无 `NSExtension` 配置在本文件，需在 widget extension 的 Info.plist / entitlements 中确认 `NSExtensionPointIdentifier = com.apple.widgetkit-extension`、`kind` 与 `WidgetTimelineKind.pulseDock` 一致——本审查无法验证，提示需在工程配置审查中覆盖。

---

## 问题汇总

### Bug 级（必须修）
| # | 行号 | 问题 | 严重度 | 建议 |
|---|------|------|--------|------|
| 1 | 22-27 | `isPrimed` prime 后立即二次 sample，CPU tick 增量仅微秒级 → `hasCPUUsageReport=true` 但 `cpuUsage` 噪声极大。widget 冷启动首次显示的 CPU 百分比不可信（可能 0% 或接近 100%） | 高 | 方案 A（最简）：prime 时直接返回首采 sample（`hasCPUUsageReport=false`，UI 显示"未报告"），5 分钟后刷新出真实值。方案 B：给 `SystemSampler` 增加 `prime()` 仅预热 `previousCPUInfo` 不跑全量采样。方案 C：`getTimeline` 首次生成两个 entry——`now` 用 prime sample（CPU 未报告）、`now+2s` 用真实 sample |
| 2 | 130-595（多处） | `SystemDashboardWidgetView` / `SmallWidget` / `MediumWidget` / `LargeWidget` / `EmptyDataWidget` / `RingMetric` / `WidgetRow` / `MiniStatus` / `StatTile` / `WidgetHeader` 全部缺失 `accessibilityLabel`。VoiceOver 用户无法获得 widget 整体语义，只能听到零散的 Text 片段 | 高 | 至少在每个 family 的根视图加 `.accessibilityElement(children: .contain)` 或 `.accessibilityLabel("...")` 汇总；为 `RingMetric` / `WidgetRow` / `StatTile` / `MiniStatus` 各加组合 label（如 `"CPU 45%"`）；`WidgetHeader` 的 green dot 用 `.accessibilityHidden(true)` |
| 3 | 475 | `CompactWidgetHeader.accessibilityLabel` 在 `hasTimeReport` 时包含 `timeText`，但该 header 视觉上不显示时间（删掉了 `Text(timeText)`）。VoiceOver 用户听到的时间，明眼用户看不到，信息不对称 | 中 | 二选一：(a) 移除 label 中的 timeText，保持 `accessibilityLabel(title)`；(b) 恢复视觉显示时间。若是有意无障碍补偿，需加注释说明意图 |

### 质量级（建议修）
| # | 行号 | 问题 | 严重度 | 建议 |
|---|------|------|--------|------|
| 4 | 54-109 | `compactWidgetSnapshot` 约 10 个字段（memoryFreeBytes / memoryWiredBytes / memoryCompressedBytes / memoryCachedBytes / hasMemoryCompositionReport / batteryCycleCount / batteryHealth / batteryDesignCapacity / batteryVoltageMillivolts / batteryAmperageMilliamps / networkBytesPerSecond）未显式传递，依赖 `MetricSnapshot.init` 默认值静默置零/nil。当前功能正确但脆弱：未来新增带默认值的字段会被悄悄丢弃且无编译告警 | 中 | 在 `MetricSnapshot` 上加 `func widgetCompact()` 工厂方法或 `mutating func stripForWidget()`，由 shared 模块单点维护裁剪逻辑；或改用 `var copy = snapshot; copy.cpuBrandName = nil; ...` 拷贝修改，保留所有未提及字段 |
| 5 | 160-161 | `configurationDisplayName("Pulse Dock")` 与 `description("在桌面显示...")` 为硬编码中文字面量，未走 `LocalizedStringKey` / String Catalog | 中 | 改用 `LocalizedStringKey` 或 `String(localized:)`，配合 `Localizable.xcstrings` 支持多语言上架 |
| 6 | 111-128 | `compactWidgetInterfaces` 将 `displayName` / `kind` 覆写为字面量 "未报告"，原始接口名丢失。当前 widget 不展示，但 `networkInterfaceSummary` 只数活动接口数，不需要名字 | 低 | 若未来 widget 可能展示接口名，改为保留 `displayName` / `kind` 仅清零字节计数；当前可加注释说明"widget 仅需 isUp/isLoopback 计数" |
| 7 | 326-371 | `EmptyDataWidget` skeleton 的 ring trim 0.62、bar widthRatio 0.74/0.46/0.58 看似真实数据，无"加载中/无数据"文字。amber 圆点是唯一区分信号，不够显眼 | 低 | 在 header 区域加极小字号 "加载中" 辅助文本，或将 skeleton ring 改为更明显的灰度（当前用 tint.opacity(0.42)，颜色偏实） |
| 8 | 606-609 | `WidgetBackground` 的 `overlay(alignment: .topLeading) { Rectangle().fill(...) }` 中 `Rectangle()` 全填充，`alignment` 无效，是死代码。实际效果是整张背景叠一层白色 5%/24% | 低 | 若原意是左上高光：改 `Rectangle().fill(...).frame(height: 40)` 或用第二个 `LinearGradient`；若就是全屏叠加：删掉 `alignment: .topLeading` 并加注释 |
| 9 | 427-477 | `WidgetHeader` 与 `CompactWidgetHeader` 近似重复，且可访问性不一致（前者无 label，后者有 label 但有 Bug #3） | 中 | 合并为单一 `WidgetHeader(title:timeText:hasTimeReport:showsTime:)`，统一 accessibility 逻辑 |
| 10 | 42-47 | `getTimeline` 只生成 1 个 entry，错失用第二 entry 修复 CPU prime Bug 的机会（见 Bug #1 方案 C） | 中 | 首次 prime 时返回 `[now→primeSample, now+2s→realSample]` 两个 entry，policy 仍 `.after(now+5min)` |

### 整洁级（可后续）
| # | 行号 | 问题 | 严重度 | 建议 |
|---|------|------|--------|------|
| 11 | 727-730 | `activeInterfaceProgress` 对 `networkInterfaces` 两次 `filter`，可一次 reduce 完成 | 极低 | 合并为 `reduce((0,0)) { acc, i in ... }` 或保持现状加注释 |
| 12 | 54、111 | `compactWidgetSnapshot` / `compactWidgetInterfaces` 为文件级 free function，仅 `SystemProvider` 使用 | 极低 | 改为 `SystemProvider` 的 `private static` 方法，收敛作用域 |
| 13 | 174-177 | `largeRingColumns` 定义在文件作用域 | 极低 | 移入 `LargeWidget` 内部 `private static let` |
| 14 | 226、272、214、218 等 | 布局含多处魔数（166 / 148 / 52 / 14 / 11 / 18 等） | 极低 | 提取为 `enum WidgetMetrics` 常量，便于统一调参 |
| 15 | 692-694 | `networkPathProgress` default 返回 0，但 unknown 时 `reportedProgress` 返回 nil，0 永不被使用 | 极低 | 保留作防御，或加注释说明 |

---

## 亮点

1. **`containerBackground(for: .widget)` + `contentMarginsDisabled()`**：正确采用 macOS 14 / iOS 17+ 的现代 WidgetKit 背景 API，并自管 padding，布局可控性强。
2. **防御性编码到位**：第 45 行 `?? now.addingTimeInterval(300)` 双保险；`progressFillWidth` 的 `min(max(progress,0),1)` + `guard > 0` + `max(minimumVisibleWidth,...)` 三层夹逼；`activeInterfaceProgress` 的 `guard !isEmpty` 防除零；`compactPowerStatusText` 的 `.some` / `default` 完备兜底。
3. **线程安全严谨**：`WidgetSamplerCache` 用 `NSLock` + `defer unlock`，`@unchecked Sendable` 边界清晰；`static let` 懒加载线程安全。
4. **三 family 布局分工清晰**：Small 重概览、Medium 重 CPU 大字 + 趋势条、Large 重 2×2 ring + 网络详情 + 系统信息，信息密度梯度合理。
5. **设计系统统一**：`WidgetColor` 调色板 + `widgetPanelFill` / `widgetPanelStroke` / `widgetTrackFill` / `widgetPlaceholderFill` 一组主题函数，暗/亮色分支明确，`StatTile` 与 `LargeWidgetSection` 共用 panel 风格。
6. **Placeholder skeleton 与真实布局对齐**：`PlaceholderMetricSkeleton` 54pt 与 `RingMetric` 一致，`PlaceholderBar` / `PlaceholderDot` 对应 `WidgetRow` / `MiniStatus`，视觉过渡自然。
7. **`reportedProgress` / `reportedTint` 辅助函数**：将"未报告 → nil / cyan"的语义集中收敛，调用点简洁。
8. **`compactWidgetSnapshot` 字段裁剪整体正确**：经逐字段核对，widget 视图用到的字段全部保留，清零的字段对应的派生属性（`hasNetworkByteCounters` / `hasRunningAppCountReport` / `hasGPUReport` 等）均正确产生 false / "未报告"，不会出现 UI 异常。
9. **`WidgetTimelineKind.pulseDock` 稳定标识**：与 widget extension 配置解耦，便于 App Group / 深链 / reload 代码引用。
10. **`MetricSnapshot` 为 `Codable + Equatable + Sendable`**：`SystemEntry` 持有它天然跨进程安全，WidgetKit 序列化无障碍。

---

## 模块整体评价

`SystemDashboardWidget` 是一个结构成熟、设计语言统一、防御性编码扎实的 widget 实现。WidgetKit 现代 API（`containerBackground` / `contentMarginsDisabled` / `StaticConfiguration`）使用规范，三 family 布局信息梯度合理，placeholder skeleton 与真实视图对齐，主题色与 panel 系统自洽。`compactWidgetSnapshot` 的字段裁剪经逐项核对功能正确。

主要风险集中在三处：
1. **CPU prime Bug**（#1）会让冷启动首次显示的 CPU 不可信——这是用户第一印象，必须修。
2. **可访问性全面缺失**（#2）——三个 family + 所有子组件 + placeholder 都没有 `accessibilityLabel`，对 VoiceOver 用户基本不可用，App Store 审核虽不强制但属于 HIG 红线。
3. **`CompactWidgetHeader` 无障碍信息与视觉不一致**（#3）——是一个易被忽视的体验 Bug。

质量层面，`compactWidgetSnapshot` 依赖 init 默认值静默裁剪字段的方式在当前正确但脆弱，建议收敛到 shared 模块单点维护；`WidgetHeader` / `CompactWidgetHeader` 的重复与 accessibility 不一致应一并重构；本地化字符串需为多语言上架做准备。

测试方面仅有结构断言（`contains(...)`），缺少行为测试，建议补充 `compactWidgetSnapshot` 字段映射、tint 分支、timeline entry 生成的单元测试。

总体而言，模块在修复 Bug #1 和 #2 后即可达到 App Store 上架质量；其余质量级 / 整洁级问题可作为后续迭代处理。
