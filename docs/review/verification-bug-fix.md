# Bug 专项修复复查报告

> 复查日期：2026-06-28
> 复查基准：当前 working tree（基于 `docs/review/top/final-review-v2.md` 的 42 条问题清单）
> 复查方法：逐条 grep/read 当前源码，对照 P0/P1/P2 位置与问题，判定修复状态
> 状态图例：✅ 已修复 / ⚠️ 部分修复 / ❌ 未修复 / 🔄 改为其他方案 / ➖ 不适用（P2-19 已从清单移除）

---

## 一、P0 修复验证

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| P0-1 | Display metadata 在 detached 采样下丢失（NSScreen 元数据需主线程桥接） | ✅ 已修复 | `screenDisplaySnapshot()` 增加 `Thread.isMainThread` 守卫：主线程直接调用 `screenDisplaySnapshotOnMainThread()`，非主线程通过 `DispatchQueue.main.sync { ... }` 桥接读取 NSScreen.scale/colorSpace/refreshRate。`#if canImport(AppKit)` 守卫非 AppKit 平台返回 `.empty`。 | `Sources/SharedMetrics/SystemSampler.swift:1023-1035`（主线程桥接）；`:1037-1098`（OnMainThread 实现） |
| P0-2 | Widget fallback 同步跑完整 SystemSampler（mach/IOKit/Metal/CG 全量采样） | ✅ 已修复 | (1) `getSnapshot` 返回 `representativeSnapshot()` fixture，gallery 不阻塞 ✅；(2) `getTimeline` 通过 `DispatchQueue.global(qos: .utility).async` 异步采样 ✅；(3) `sampleWidgetCompact()` 改为 `sampleWidgetSnapshot(now:).widgetCompactSnapshot()`，轻量 helper 跳过 `cachedGPUDevices`/`cachedDisplays`/`cachedStorage`，不再触发 MTLCopyAllDevices、CG display inventory 或 mountedVolumeURLs 全量枚举。 | `Sources/PulseDockWidget/SystemDashboardWidget.swift:50-77`（fixture/async/fallback）；`Sources/SharedMetrics/SystemSampler.swift:364-421`（轻量 widget sampler）；`Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift`（轻量采样守卫） |

**P0 小结：2/2 已修复。** P0-1 主线程桥接完整落地；P0-2 timeline 异步化、gallery fixture 与轻量 widget fallback 均已补齐。

---

## 二、P1 修复验证

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| P1-1 | `MainActor.assumeIsolated` in deinit 非主线程释放则 trap | ✅ 已修复 | `deinit {}` 空实现，移除 `assumeIsolated`。清理工作移至 `stopForTermination()`（cancel task/invalidate timer/persist history）。 | `Sources/PulseDockApp/MetricsStore.swift:94`（deinit {}）；`:106-112`（stopForTermination） |
| P1-2 | 主线程 JSON 编码 + NSWorkspace 枚举未 offload | ❌ 未修复 | `persistHistoryIfNeeded` 仍在 MainActor 执行 `JSONEncoder().encode(Array(snapshots))`（line 415）；`applyVisibleApplicationSummary` 仍在 MainActor 同步枚举 `NSWorkspace.shared.runningApplications` 并排序/map（line 450-482），无 5s TTL 缓存。仅 `Task.detached` 跑采样本身。 | `Sources/PulseDockApp/MetricsStore.swift:414-421`（主线程编码）；`:447-483`（NSWorkspace 主线程枚举） |
| P1-3 | 缺 NSWorkspaceDidWakeNotification / 屏幕变更通知 | ✅ 已修复 | `registerSystemEventObservers()` 注册 `NSWorkspace.didWakeNotification` 与 `NSApplication.didChangeScreenParametersNotification`；handler 调用 `store.handleSystemWake()`（resetNetworkBaselines + resetCPUBaselines + invalidateDisplaysCache + refresh）与 `store.handleScreenConfigurationChange()`。SystemSampler 已加 `invalidateDisplaysCache()`。 | `Sources/PulseDockApp/AppDelegate.swift:90-103`（注册）；`:105-111`（handler）；`Sources/PulseDockApp/MetricsStore.swift:130-140`（handleSystemWake/handleScreenConfigurationChange） |
| P1-4 | loadLatestSnapshot `try?` 静默失败（与 save 不对称） | ✅ 已修复 | `loadLatestSnapshot` 改 `do/catch` + `#if DEBUG print("SharedSnapshotStore failed to decode latest snapshot: \(error)")`，与 save 端对称。同时加 `schemaVersion` 门控与 `acceptedFutureSkew` 校验。 | `Sources/SharedMetrics/SharedSnapshotStore.swift:60-75`（do/catch + DEBUG print）；`:42-51`（save 端对称） |
| P1-5 | trend 提取器 O(n) 无 memoization，OverviewPage ~36 次/ tick | ✅ 已修复 | OverviewPage/CPUPage/MemoryPage/NetworkPage/PowerPage/HistoryAlertsPage body 顶部 `let cpuTrend = cpuTrendValues(from: history)` 等一次提取，传值给 `MetricCard`/`TrendRow`/`overviewTrendPanel`。少量残留：`overviewTrendPanel` 内 `loadTrendValues`/`diskTrendValues` 仍直接调用（2 次 O(n)，非 36 次），影响可忽略。 | `Sources/PulseDockApp/DashboardView.swift:421-424`（OverviewPage 顶部 memoize）；`:498`（CPUPage）；`:570`（MemoryPage）；`:1018-1021`（HistoryAlertsPage）；`:466,469`（残留 loadTrend/diskTrend） |
| P1-6 | isRefreshing @Published 死状态 + Sparkline.preparedValues 2× 访问 | ⚠️ 部分修复 | (1) `isRefreshing` 已移除 `@Published`：`private(set) var isRefreshing = false` ✅；(2) **`Sparkline.preparedValues` 仍为计算属性**（`private var preparedValues`），body 内 `let normalized = preparedValues`（Canvas 闭包）+ `sparklineAccessibilityValue` 内 `preparedValues.last` 各触发一次 `values.suffix(sparklineVisibleSampleLimit)` 重分配，未 hoist 到 body 顶部 `let`。 | `Sources/PulseDockApp/MetricsStore.swift:47`（isRefreshing 无 @Published）；`Sources/PulseDockApp/DashboardView.swift`（preparedValues 仍计算属性，2× 访问） |
| P1-7 | 阈值滑块每 tick @Published → 整页重渲染 60 次/拖 | ✅ 已修复 | HistoryAlertsPage 加 `@State private var draftCPUThreshold: Double?`（含 memory/disk）；`ThresholdControlRow` 用 `Slider(... onEditingChanged: { editing in guard !editing, let draftValue else { update(draftValue); self.draftValue = nil } })`——仅拖拽结束时 commit 到 store。 | `Sources/PulseDockApp/DashboardView.swift:1011-1013`（@State draft）；`:1977-1984`（onEditingChanged commit） |
| P1-8 | fallback 首次 tick CPU "Not reported"/网络速率 0 | ⚠️ 部分修复 | (1) `EmptyDataWidget` 骨架已实现（PlaceholderMetricSkeleton/PlaceholderBar/PlaceholderDot + `PulseDockWidgetStrings.waitingSystemData`）✅；(2) `getTimeline` 当 `sampledSnapshotForTimeline` 返回 nil 时显示 EmptyDataWidget ✅；(3) **但 `sampleCompact()` 始终返回非 nil MetricSnapshot**（`sample()` 永不返回 nil），`?? Self.samplerCache.sampleCompact()` 使 timeline 路径永不进入 `.empty` 分支；widget 独立 SystemSampler 首次无 baseline 时网络速率 0/CPU 可能为 Not reported，仍显示误导性数值而非骨架。getSnapshot（gallery）已用 fixture ✅。 | `Sources/PulseDockWidget/SystemDashboardWidget.swift:74-77`（sampledSnapshotForTimeline 永不 nil）；`:58-72`（empty 分支不可达）；`:335-415`（EmptyDataWidget 骨架存在但不可达） |
| P1-9 | 缺 .systemExtraLarge/accessory families；default 非 @unknown；EmptyDataWidget 分支不全 | ❌ 未修复 | `supportedFamilies` 仍为 `[.systemSmall, .systemMedium, .systemLarge]`（无 extraLarge/accessory）；`SystemDashboardWidgetView.body` switch 末尾为 `default:`（非 `@unknown default:`）；`EmptyDataWidget` 仅按 small/medium/large 分支（line 352-378），无 extraLarge/accessory 分支。防御性 @unknown default（0.5d 工作量）未做。 | `Sources/PulseDockWidget/SystemDashboardWidget.swift:159`（supportedFamilies）；`:138-140`（default 非 @unknown）；`:339,352,362,372`（EmptyDataWidget 仅 small/medium/large） |
| P1-10 | placeholder 返回 nil；freshness 600s > 刷新 300s 无 staleness 指示；MediumWidget 隐藏时钟 | ✅ 已修复 | (1) `placeholder` 返回 `Self.representativeSnapshot()` fixture（含代表性 CPU/memory/network 值）✅；(2) `SystemEntry.freshnessTone` 按 `WidgetFreshnessTone.resolve(age:)` 分 fresh/aging/stale，header 圆点按 tone 着色（green/amber/red）✅；(3) `CompactWidgetHeader` 渲染时钟 + freshness 圆点 + preview 标签 ✅；(4) `WidgetTimelinePolicy`: agingThreshold=360s, staleThreshold=600s, requestedRefreshInterval=300s——存在 aging 渐变指示。 | `Sources/PulseDockWidget/SystemDashboardWidget.swift:50-52`（placeholder fixture）；`:79-122`（representativeSnapshot）；`:20-22`（freshnessTone）；`:471-526`（WidgetHeader 圆点+时钟）；`:528-583`（CompactWidgetHeader）；`Sources/SharedMetrics/WidgetTimelinePolicy.swift:3-8` |
| P1-11 | App Group 生产签名共享未验证 | ✅ 已修复 | `archive-app-store.sh` 加 `verify_entitlements()` 函数：`codesign -d --entitlements :- "$bundle_path"` 提取 entitlements，`grep -Fq "group.com.ifonly3.pulsedock"` 校验，缺失则报错退出。对 `Pulse Dock.app` 与 `PulseDockWidgetExtension.appex` 均调用。 | `scripts/archive-app-store.sh:27-36`（verify_entitlements 函数）；`:120-121`（app + widget 调用） |
| P1-12 | 无 pbxproj bundle ID ↔ Swift 常量 ↔ entitlements 交叉校验测试 | ✅ 已修复 | `LocalizationGateTests.releaseBuildGatesVerifyBundleIdentifiersEntitlementsAndSwiftVersion` 解析 pbxproj，断言 `PRODUCT_BUNDLE_IDENTIFIER = com.ifonly3.pulsedock;`/`com.ifonly3.pulsedock.widget;`、`PulseDockAppGroup.swift` 含 appBundleIdentifier/widgetBundleIdentifier 常量、entitlements 含 `group.com.ifonly3.pulsedock`、archive 脚本含 `verify_entitlements`、SWIFT_VERSION=6.0 一致。 | `Tests/SharedMetricsTests/LocalizationGateTests.swift:134-162`（交叉校验测试） |

**P1 小结：8/12 已修复，2/12 部分修复（P1-6、P1-8），2/12 未修复（P1-2、P1-9）。**

---

## 三、P2 修复验证（抽查关键项 + 顺带覆盖项）

| ID | 问题摘要 | 修复状态 | 当前实现 | 验证证据 |
|----|---------|---------|---------|---------|
| P2-1 | 字符串契约死分支（thermal fair/serious、network requires_connection） | ✅ 已修复 | `MetricStateContracts.swift` 定义 `ThermalState` enum（nominal/warm/hot/critical/unknown，`init(raw:)` 映射 "fair"→warm、"serious"→hot）与 `NetworkPathState` enum（satisfied/unsatisfied/requiresConnection/unknown，`init(raw:)` 映射 "requires_connection"→requiresConnection）。MetricSnapshot 暴露 `canonicalThermalState`/`canonicalNetworkPathState` 派生属性，App/Widget 均通过 enum 消费。 | `Sources/SharedMetrics/MetricStateContracts.swift:3-56`（ThermalState）；`:58-103`（NetworkPathState）；`Sources/SharedMetrics/MetricSnapshot.swift:1230-1231,1327-1328`（canonical 派生） |
| P2-2 | normalizedRate/reportedProgress/progressFillWidth/色板 三处重复 | ⚠️ 部分修复 | `MetricScales.swift`（SharedMetrics）提取 `reportedProgress(hasReport:progress:)`、`fillWidth(_:in:minimumVisibleWidth:)`、`clampedProgress(_:)`、`networkRateProgress(bytesPerSecond:)`——App/Widget 均调用。**但色板未统一**：`DashboardColor`（App）、`WidgetColor`（Widget）、`Palette`（WidgetPanelView）三套并存；`normalizedBytes` 仍为 `DashboardView.swift` 私有函数。 | `Sources/SharedMetrics/MetricScales.swift:4-29`（共享工具）；`Sources/PulseDockApp/DashboardView.swift:2169`（normalizedBytes 仍私有）；`Sources/PulseDockApp/WidgetPanelView.swift:54-57`（Palette 独立） |
| P2-3 | DashboardView.swift 2060 行 god file | ❌ 未修复 | 文件已增长至 **2261 行**（较 2060 增加 201 行），未拆分为 Pages/Components/Theme/Helpers。所有 Page/组件仍在单文件内。 | `Sources/PulseDockApp/DashboardView.swift`（wc -l = 2261） |
| P2-4 | MetricsStore 491 行 god object（7 项职责） | ❌ 未修复 | 文件已增长至 **515 行**（较 491 增加 24 行），未拆分 HistoryStore/SharedSnapshotCoordinator/WidgetReloadScheduler 等。 | `Sources/PulseDockApp/MetricsStore.swift`（wc -l = 515） |
| P2-5 | 硬编码 "Pulse Dock"/"CPU"/"MEM"/"Core N"/"5m"/"UPS" 未走本地化 | ❌ 未修复 | DashboardView 仍有字面量 `"Pulse Dock"`（:239,:1338）、`"CPU"`（:1028,:1041,:1348）、`"MEM"`（:1349）；WidgetPanelView `"CPU"`（:54）、`"Pulse Dock"`（:109）；AppDelegate `"Pulse Dock"`（:115,:191,:233,:263）。PulseDockAppStrings.metricCPU 已存在（:1080）但 DashboardView 未引用。Widget 侧 PulseDockWidgetStrings 已本地化（widgetDisplayName/metricCPU/metricMemoryCompact/ups）✅。 | `Sources/PulseDockApp/DashboardView.swift:239,1028,1041,1338,1348,1349`；`Sources/PulseDockApp/WidgetPanelView.swift:54,109`；`Sources/PulseDockApp/AppDelegate.swift:115,191,233,263` |
| P2-6 | DashboardView "5m" widget 刷新值与 "System Scheduled" 详情文案矛盾 | ✅ 已修复 | `SettingsPage` 用 `PulseDockAppStrings.settingsWidgetRefreshValue`（:1134），不再用字面量 "5m"。 | `Sources/PulseDockApp/DashboardView.swift:1134` |
| P2-7 | App 13 个组件缺 accessibility | ✅ 已修复 | MetricCard/TrendRow/Sparkline/CompactMetricLine/CoreUsageTile/MemorySegmentBar/CapacityBar/StatusSummaryRow/SourceCapabilityCard/ThresholdControlRow/LegendDot/StatLine 均加 `.accessibilityElement(children: .combine)` + `.accessibilityLabel(...)` +（可选）`.accessibilityValue`/`.accessibilityHint`；装饰圆点/图标 `.accessibilityHidden(true)`。 | `Sources/PulseDockApp/DashboardView.swift:1247-1250,1282-1283,1434-1436,1459-1460,1524-1525,1607-1609,1637-1638,1671-1672,1794-1795,1811,1831-1832,1993-1994,2062-2063`；`:1267,1811,2093`（accessibilityHidden） |
| P2-8 | Widget WidgetHeader 无 a11y、CompactWidgetHeader label 未 combine、装饰圆点未 hidden | ✅ 已修复 | WidgetHeader/CompactWidgetHeader 加 `.accessibilityElement(children: .combine)` + `.accessibilityLabel(accessibilityLabel)`（拼接 title/time/preview/freshness）；装饰图标 `.accessibilityHidden(true)`（:484,:541）；`WidgetStatusDot` `.accessibilityHidden(true)`（:592）；RingMetric/WidgetRow/StatTile/MiniStatus 均 combine + label。 | `Sources/PulseDockWidget/SystemDashboardWidget.swift:484,492,503-504,515-525,541,560-561,572-582,592,627-628,665-666,689-690,719-720` |
| P2-9 | Widget configurationDisplayName("Pulse Dock")/"CPU"/"UPS" 硬编码 | ✅ 已修复 | `SystemDashboardWidget` 用 `PulseDockWidgetStrings.widgetDisplayName`/`widgetDescription`；metricCPU/metricMemoryCompact/ups 等均走 PulseDockWidgetStrings.localized。 | `Sources/PulseDockWidget/SystemDashboardWidget.swift:157-158`；`Sources/PulseDockWidget/PulseDockWidgetStrings.swift:6,30,34,110` |
| P2-10 | 无 schema 版本字段，字段类型变更静默破坏共享快照 | ✅ 已修复 | `MetricSnapshot` 加 `schemaVersion: Int` 字段（默认 `currentSchemaVersion = 1`）；decoder `decodeIfPresent(.schemaVersion) ?? currentSchemaVersion`；`SharedSnapshotStore.loadLatestSnapshot` 加 `guard snapshot.schemaVersion == MetricSnapshot.currentSchemaVersion else { return nil }` 门控；`widgetCompactSnapshot()` 保留 schemaVersion。 | `Sources/SharedMetrics/MetricSnapshot.swift:748,750,879,881,1598,1666`；`Sources/SharedMetrics/SharedSnapshotStore.swift:62-64` |
| P2-11 | widgetCompactSnapshot 裁剪契约靠手工列举，无类型级强制 | ✅ 已修复（裁剪断言测试方案） | 未引入独立 `WidgetCompactSnapshot` 类型（仍返回 MetricSnapshot），但新增多个裁剪断言测试锁定契约：(1) `widgetCompactSnapshotTrimsCurrentDeadFields`；(2) `widgetCompactSnapshotPreservesWidgetFallbackVisibleFields`；(3) `widgetCompactSnapshotPreservesSummarySignalsAndDropsPrivateLists`。字段裁剪在 `MetricSnapshot+WidgetCompact.swift` 集中实现，SharedSnapshotStore.save 与 widget fallback 共用。 | `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift:4-68`；`Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift:82`；`Tests/SharedMetricsTests/LogicConsistencyGateTests.swift:111`；`Tests/SharedMetricsTests/MetricFormattingTests.swift:8394,8474` |
| P2-12 | MetricFormatting String(format:) C locale vs Locale.current 混用 | ❌ 未修复 | `MetricFormatting.swift` 仍用 `String(format: "%.1f %@", value, units[...])`（:24,:41,:57,:73）无 `locale:` 参数；`MetricSnapshot.swift` 同样 `String(format: "%.0fx", ...)`（:373,:375,:386,:398,:735,:738,:741）无 locale。仅 `SharedMetricStrings.localizedFormat` 传 `Locale.current`（:404）。 | `Sources/SharedMetrics/MetricFormatting.swift:24,41,57,73`；`Sources/SharedMetrics/MetricSnapshot.swift:373,386,735` |
| P2-13 | MetricScales 10GbE 硬上限对 25/100 GbE 钳制 | ✅ 已修复 | `networkRateReferenceBytesPerSecond = 12_500_000_000`（12.5 GB/s ≈ 100 Gbps），log10 曲线对 25/100 GbE 不再钳制至 1.0。 | `Sources/SharedMetrics/MetricScales.swift:5,7-11` |
| P2-14 | decoder/init 推断策略不一致（AND/OR 混用） | ✅ 已修复 | decoder 统一 `decodeIfPresent(...) ?? default`（OR 策略）；`hasCPUUsageReport` 等布尔标记用 `?? (cpuUsage > 0 || !cpuCoreUsages.isEmpty)` 由值推断，与 init 默认值策略一致。 | `Sources/SharedMetrics/MetricSnapshot.swift:1666-1684`（decodeIfPresent + OR fallback） |
| P2-15 | PulseDockAppGroup 严格匹配致 SPM/测试静默禁用共享存储 | ❌ 未修复 | `supportsAppGroup(bundleIdentifier:)` 仍 `return bundleIdentifier == appBundleIdentifier || ...`，DEBUG 下返回 false 时无 print 警告。 | `Sources/SharedMetrics/PulseDockAppGroup.swift:8-10` |
| P2-16 | SharedMetricStrings .main bundle 在 widget extension 本地化风险 | ❌ 未修复 | `Bundle.sharedMetricsLocalization` 在非 SPM 下返回 `Bundle.main`（非 `Bundle(for:)` 锚定 framework bundle）。Widget extension 的 `Bundle.main` 为 widget bundle，若 SharedMetrics.strings 仅随 app 资源则 widget 端可能回退 defaultValue。 | `Sources/SharedMetrics/SharedMetricStrings.swift:415-422`（.main 非 Bundle(for:)） |
| P2-17 | AppDelegate 终止时 statusPopover/cancellables/dashboardWindow 未清理 | ✅ 已修复 | `applicationWillTerminate`：`removeObserver(self)` + `store.stopForTermination()` + `statusPopover?.close()` + `resetStatusPopoverContentHost()` + `dashboardWindow?.orderOut(nil)` + `NSStatusBar.system.removeStatusItem`。 | `Sources/PulseDockApp/AppDelegate.swift:60-69` |
| P2-18 | applicationShouldHandleReopen 忽略 hasVisibleWindows → 焦点闪烁 | ❌ 未修复 | 仍无条件 `showDashboardWindow(activating: true); return true`，未 `if !flag { showWindow() }`。 | `Sources/PulseDockApp/AppDelegate.swift:72-75` |
| P2-19 | undo:/redo: 选择器（已从清单移除） | ➖ 不适用 | 复核确认 undo:/redo: 为 AppKit responder-chain 合法选择器，原报告已 remove。 | `docs/review/top/final-review-v2.md:48,100` |
| P2-20 | popover toggle 防抖 0.25s 竞态 | ⚠️ 部分修复 | 仍保留 `closeToggleSuppressionInterval = 0.25`，但 `shouldSuppressStatusPopoverToggle` 同时依赖 `isStatusPopoverClosing` 标志，`popoverDidClose` 重置标志——即 popoverDidClose 严格门控已实现；0.25s 仅为兜底。慢机仍可能 0.25s 内 popoverDidClose 未触发但标志位拦截。 | `Sources/PulseDockApp/AppDelegate.swift:15,455-470,490-500` |
| P2-21 | MemorySegmentBar/CapacityBar 8pt 最小宽度窄布局溢出 | ⚠️ 部分修复 | `segmentWidth` 用 `minimumVisibleWidth = min(8, totalWidth / memorySegmentCount)` 适应窄布局；但上限仍为 `totalWidth`（非建议的 `totalWidth*0.4`），单段可占满整条。 | `Sources/PulseDockApp/DashboardView.swift:1681-1686` |
| P2-22 | WidgetSamplerCache 与 SystemSampler.sampleLock 双重锁冗余 | ❌ 未修复 | `WidgetSamplerCache` 仍持 `private let lock = NSLock()`（:27），`sampleCompact()` 加锁后调用 `systemSampler.sampleWidgetCompact()`，后者内部 `sampleLock.lock()`（:282）——双重锁仍在。 | `Sources/PulseDockWidget/SystemDashboardWidget.swift:25-34`；`Sources/SharedMetrics/SystemSampler.swift:222,282-283` |
| P2-23 | networkPathProgress 返回非 Optional Double → 未识别空进度条 | 🔄 改为其他方案 | `NetworkPathState.progress` 仍返回 `Double`（unknown 返回 0）。但 Widget 用 `MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: ...)`，而 `hasNetworkPathReport = canonicalNetworkPathState.isReported`（unknown 时 false）→ `reportedProgress` 返回 nil → RingMetric 显示空轨道。等效达成"unknown 不显示进度"的 UX，但底层 progress 类型未改 Optional。 | `Sources/SharedMetrics/MetricStateContracts.swift:94-103`（progress: Double）；`Sources/SharedMetrics/MetricSnapshot.swift:1331`（isReported）；`Sources/PulseDockWidget/SystemDashboardWidget.swift:234,284-286`（reportedProgress 守卫） |
| P2-24 | NaN 进度值 min(max(NaN,0),1) 不过滤，trim(to:NaN) 未定义 | ✅ 已修复 | `MetricScales.clampedProgress(_:)` 守卫 `progress.isFinite` 否则返回 nil；RingMetric（:608）与 RingGauge（:1409-1410）均 `progress.flatMap(MetricScales.clampedProgress)` 后再 `.trim(from: 0, to: clampedProgress)`，NaN 不会进入 trim。 | `Sources/SharedMetrics/MetricScales.swift:25-28`；`Sources/PulseDockWidget/SystemDashboardWidget.swift:608-610`；`Sources/PulseDockApp/DashboardView.swift:1409-1422` |
| P2-25 | UserDefaults 跨进程无同步机制，可能读到 stale 值 | ✅ 已修复 | `MetricsStore.reloadWidgetsIfNeeded` 写共享快照后调用 `WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKind.pulseDock)`，含 `widgetReloadInterval` 节流。 | `Sources/PulseDockApp/MetricsStore.swift:434-445` |
| P2-26 | fallback 与 app 双 sampler 独立 baseline，CPU/网络速率可能不一致 | ❌ 未修复 | 未加 UI source 标记；widget fallback 仍用独立 `WidgetSamplerCache.systemSampler`（SystemSampler()），与 app store 的 sampler 各自维护 baseline。 | `Sources/PulseDockWidget/SystemDashboardWidget.swift:26`（独立 SystemSampler） |
| P2-27 | MTLCopyAllDevices/mountedVolumeURLs 浪费：fallback 跑完整采样但 widget 只用主盘 | ✅ 已修复 | `sampleWidgetCompact()` 改为轻量 `sampleWidgetSnapshot(now:)` 后再调用 `widgetCompactSnapshot()`，直接跳过 GPU/display/storage volume/running app inventory，仅保留 widget 可见汇总信号。 | `Sources/SharedMetrics/SystemSampler.swift:364-421`；`Tests/SharedMetricsTests/RedundancyOptimizationGateTests.swift` |
| P2-28 | design/ vs designs/ 冗余；dist/ legacy；pbxproj SWIFT_VERSION 项目级 5.0 vs target 6.0 | ⚠️ 部分修复 | (1) SWIFT_VERSION ✅：pbxproj 8 处全为 `= 6.0;`，generate-xcodeproj.rb 项目级与 target 均设 6.0；(2) design/ ✅：仅 `design/gptimage2-system-monitor`，无 `designs/` 冗余；(3) **dist/ ❌**：`dist/Pulse Dock.app` legacy 残留仍在。 | `PulseDock.xcodeproj/project.pbxproj`（8× SWIFT_VERSION=6.0）；`scripts/generate-xcodeproj.rb:32,126`；`design/`（单目录）；`dist/Pulse Dock.app`（未清理） |

**P2 小结（27 条有效，P2-19 移除）：**
- ✅ 已修复：13 条（P2-1, P2-6, P2-7, P2-8, P2-9, P2-10, P2-11, P2-13, P2-14, P2-17, P2-24, P2-25, P2-27）
- ⚠️ 部分修复：4 条（P2-2, P2-20, P2-21, P2-28）
- 🔄 改为其他方案：1 条（P2-23）
- ❌ 未修复：9 条（P2-3, P2-4, P2-5, P2-12, P2-15, P2-16, P2-18, P2-22, P2-26）

---

## 四、汇总

| 优先级 | 总数 | 已修复 ✅ | 部分修复 ⚠️ | 改为其他方案 🔄 | 未修复 ❌ | 不适用 ➖ |
|--------|------|----------|------------|----------------|----------|----------|
| P0 | 2 | 2 | 0 | 0 | 0 | 0 |
| P1 | 12 | 8 | 2 | 0 | 2 | 0 |
| P2 | 28 | 13 | 4 | 1 | 9 | 1 |
| **合计** | **42** | **23** | **6** | **1** | **11** | **1** |

### 整体修复率
- **P0：2/2 已修复**（P0-1 主线程桥接完整；P0-2 异步化、fixture 与轻量采样器均已修）
- **P1：8/12 已修复**（核心稳定性 P1-1/3/4/5/7/10/11/12 落地；P1-2 主线程阻塞、P1-9 widget family 防御未做）
- **P2：13/27 已修复 + 1 改方案**（契约/可访问性/schema/签名验证/轻量 widget fallback 已修；god file/object 拆分、硬编码本地化、locale/bundle 锚定未修）

### 上架阻塞评估
- **硬阻塞（P0）**：P0-2 已补齐轻量 widget fallback，当前无已知 P0 上架硬阻塞。
- **软阻塞（P1）**：P1-2 主线程 JSON 编码 + NSWorkspace 枚举未 offload，360 snapshot 编码可能造成可见卡顿；P1-9 缺 @unknown default 防御（未来 SDK 新 family 会静默渲染 SmallWidget）。
- **质量（P2）**：P2-3/P2-4 god file/object 未拆分、P2-5 硬编码话术、P2-16 widget 本地化 bundle 锚定风险为后续迭代重点。

### 验证命令建议
```bash
swift build                 # Swift 6 严格并发
swift test                  # 含 widgetCompactSnapshot 裁剪断言 + bundle ID 交叉校验
scripts/archive-app-store.sh # 含 verify_entitlements App Group 校验
```

---

**报告完成。** P0: 2/2 已修复，P1: 8/12 已修复（2 部分修复，2 未修复），P2: 13/28 已修复（4 部分修复，1 改方案，9 未修复，1 不适用）。
