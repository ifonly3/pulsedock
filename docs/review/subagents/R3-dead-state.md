# R3 — 死状态/死代码/死资源报告

审查范围：MetricsStore 状态声明、MetricSnapshot+WidgetCompact 裁剪契约、MetricSnapshot 派生属性、widget/popover/dashboard 视图消费点、design/ 与 designs/ 资源目录、dist/ 残留、.gitignore 覆盖。

审查方法：对每个 `@Published`/`private(set) var` 与每个 widgetCompact 保留字段，用 grep 在 DashboardView.swift / WidgetPanelView.swift / AppDelegate.swift / SystemDashboardWidget.swift 中搜索直接读取（`store.xxx`、`snapshot.xxx`）与间接读取（派生属性消费链）。仅被赋值/序列化但不被任何视图或数据校验读取 = 死项。

---

## 一、死状态清单（MetricsStore.swift 声明）

| 状态变量 | 声明位置 | 赋值位置 | 读取位置 | 状态 |
|---------|---------|---------|---------|------|
| snapshot | MetricsStore.swift:44 | :354 | DashboardView:22,28,61,421,642,950,1037,1090；WidgetPanelView:23；AppDelegate:337,338 | 活跃 |
| recentSnapshots | MetricsStore.swift:45 | :90,387,392,404 | DashboardView:62（别名 `history`） | 活跃 |
| isPaused | MetricsStore.swift:46 | :115 | WidgetPanelView:24；AppDelegate 间接（togglePause） | 活跃 |
| **isRefreshing** | **MetricsStore.swift:47** | **:326,336,347** | **（无）** | **死状态** |
| refreshInterval | MetricsStore.swift:48 | :145 | DashboardView:28,1142,1198 | 活跃 |
| historyDepth | MetricsStore.swift:49 | :155 | DashboardView:1171,1173 | 活跃 |
| cpuAlertThreshold | MetricsStore.swift:50 | :165 | DashboardView:483,971,1014,1063,1073 | 活跃 |
| memoryAlertThreshold | MetricsStore.swift:51 | :173 | DashboardView:484,972,1015,1064,1074 | 活跃 |
| diskAlertThreshold | MetricsStore.swift:52 | :181 | DashboardView:489,973,1016,1065,1075 | 活跃 |
| showsMenuBarCPU | MetricsStore.swift:53 | :188 | AppDelegate:277,344；DashboardView:1160 | 活跃 |

**结论**：10 个状态变量中仅 `isRefreshing` 为死状态。

---

## 二、死字段清单（MetricSnapshot+WidgetCompact.swift 保留但 widget 不读取）

widget 读取的 snapshot 属性全集（SystemDashboardWidget.swift，排除 placeholder fixture）：`batteryIsCharging`、`batteryPercent`、`batteryPowerSource`、`canonicalNetworkPathState`、`cpuText`、`cpuUsage`、`diskUsage`、`diskUsageText`、`hasCPUUsageReport`、`hasDiskUsageReport`、`hasKernelReleaseReport`、`hasMemoryUsageReport`、`hasNetworkPathReport`、`hasOSVersionReport`、`hasSampleTimeReport`、`hasUptimeReport`、`kernelText`、`loadAverageProgress`、`loadText`、`logicalCoreSummaryText`、`memoryUsage`、`memoryUsageText`、`networkPathCapabilityText`、`networkPathDetailText`、`networkPathText`、`osVersionText`、`powerStatusText`、`powerStatusTitle`、`powerStatusTone`、`sampleClockText`、`thermalState`、`thermalText`、`timestamp`、`uptimeText`。

派生属性消费链已追溯（如 `loadAverageProgress`→`reportedLoadProgress` 用 `activeProcessorCount`；`networkPathDetailText` 用 `networkPathIsExpensive/IsConstrained/InterfaceKinds`；`networkPathCapabilityText` 用 `networkPathSupportsDNS/IPv4/IPv6`）。

| 字段 | widgetCompact 保留? | widget 读取?（直接/间接） | 状态 |
|------|-------------------|-------------------------|------|
| cpuUsage | yes (:8) | yes（cpuText/cpuUsage） | 活跃 |
| **cpuCoreUsages** | **yes (:9)** | **no**（仅 placeholder fixture :82 用，无渲染消费） | **死字段** |
| hasCPUUsageReport | yes (:10) | yes | 活跃 |
| **physicalCoreCount** | **yes (:11)** | **no**（widget 用 logicalCoreCount，不用 physicalCoreCount） | **死字段** |
| logicalCoreCount | yes (:12) | yes（logicalCoreSummaryText） | 活跃 |
| activeProcessorCount | yes (:13) | yes（loadAverageProgress→reportedLoadProgress 守卫） | 活跃 |
| cpuBrandName | nil (:14) | n/a（已裁剪） | 已裁剪 |
| memoryUsedBytes | yes (:16) | yes（memoryUsageText/memoryUsage） | 活跃 |
| memoryTotalBytes | yes (:17) | yes | 活跃 |
| **memoryFreeBytes** | **yes (:18)** | **no**（memoryUsageText 仅用 used/total） | **死字段** |
| **memoryWiredBytes** | **yes (:19)** | **no** | **死字段** |
| **memoryCompressedBytes** | **yes (:20)** | **no** | **死字段** |
| **memoryCachedBytes** | **yes (:21)** | **no** | **死字段** |
| **memorySwapUsedBytes** | **yes (:22)** | **no**（widget 不读 memorySwapText） | **死字段** |
| **memorySwapTotalBytes** | **yes (:23)** | **no** | **死字段** |
| **memorySwapAvailableBytes** | **yes (:24)** | **no** | **死字段** |
| **hasMemoryCompositionReport** | **yes (:25)** | **no** | **死字段** |
| loadAverage | yes (:26) | yes（loadText） | 活跃 |
| **loadAverage5** | **yes (:27)** | **no**（widget 不读 loadAverage5Text/Progress） | **死字段** |
| **loadAverage15** | **yes (:28)** | **no** | **死字段** |
| hasLoadAverageReport | yes (:29) | yes（loadText/loadAverageProgress 守卫） | 活跃 |
| thermalState | yes (:30) | yes | 活跃 |
| batteryPercent | yes (:31) | yes | 活跃 |
| batteryIsCharging | yes (:32) | yes | 活跃 |
| batteryPowerSource | yes (:33) | yes | 活跃 |
| **batteryTimeRemainingMinutes** | **yes (:34)** | **no** | **死字段** |
| **batteryCycleCount** | **yes (:35)** | **no** | **死字段** |
| **batteryHealth** | **yes (:36)** | **no** | **死字段** |
| **batteryCurrentCapacity** | **yes (:37)** | **no** | **死字段** |
| **batteryMaxCapacity** | **yes (:38)** | **no** | **死字段** |
| **batteryDesignCapacity** | **yes (:39)** | **no** | **死字段** |
| **batteryVoltageMillivolts** | **yes (:40)** | **no** | **死字段** |
| **batteryAmperageMilliamps** | **yes (:41)** | **no** | **死字段** |
| networkPathStatus | yes (:46) | yes（canonicalNetworkPathState） | 活跃 |
| networkPathIsExpensive | yes (:47) | yes（networkPathDetailText） | 活跃 |
| networkPathIsConstrained | yes (:48) | yes（networkPathDetailText） | 活跃 |
| hasNetworkPathCostReport | yes (:49) | yes（networkPathDetailText） | 活跃 |
| networkPathSupportsDNS | yes (:50) | yes（networkPathCapabilityText） | 活跃 |
| networkPathSupportsIPv4 | yes (:51) | yes（networkPathCapabilityText） | 活跃 |
| networkPathSupportsIPv6 | yes (:52) | yes（networkPathCapabilityText） | 活跃 |
| hasNetworkPathSupportReport | yes (:53) | yes（networkPathCapabilityText） | 活跃 |
| networkPathInterfaceKinds | yes (:54) | yes（networkPathDetailText） | 活跃 |
| networkInterfaces | [] (:57) | n/a（已裁剪） | 已裁剪 |
| diskFreeBytes | yes (:58) | yes（diskUsage/diskText） | 活跃 |
| diskTotalBytes | yes (:59) | yes | 活跃 |
| storageVolumes | [] (:60) | n/a（已裁剪） | 已裁剪 |
| processCount | 0 (:61) | n/a（已裁剪） | 已裁剪 |
| activeApplicationCount | 0 (:62) | n/a（已裁剪） | 已裁剪 |
| hiddenApplicationCount | 0 (:63) | n/a（已裁剪） | 已裁剪 |
| hasRunningAppCountReport | false (:64) | n/a（已裁剪） | 已裁剪 |
| runningApps | [] (:65) | n/a（已裁剪） | 已裁剪 |
| gpuDevices | [] (:66) | n/a（已裁剪） | 已裁剪 |
| displays | [] (:67) | n/a（已裁剪） | 已裁剪 |
| uptimeSeconds | yes (:68) | yes（uptimeText） | 活跃 |
| hasUptimeReport | yes (:69) | yes | 活跃 |
| osVersion | yes (:70) | yes（osVersionText） | 活跃 |
| kernelRelease | yes (:71) | yes（kernelText） | 活跃 |
| timestamp | yes (:72) | yes（sampleClockText/hasSampleTimeReport） | 活跃 |
| schemaVersion | yes (:73) | yes（SharedSnapshotStore.loadLatestSnapshot:62 校验） | 活跃（数据路径） |

**结论**：widgetCompact 当前保留的 44 个非裁剪字段中，**20 个为死字段**（widget 渲染从不读取，仅占用 App Group 共享存储编解码与 UserDefaults 载荷）。初版报告列入的 5 个网络速率字段已经不在当前 `MetricSnapshot+WidgetCompact.swift` 投影中。这些字段在宿主应用 DashboardView 中多数为活跃（通过 `loadAverage5Text`/`memorySwapText`/`batteryTimeRemainingText` 等派生属性消费），但在 widget compact 契约中是死字段。

---

## 三、死分支清单

| 分支 | 位置 | 可达性 | 状态 |
|------|------|--------|------|
| powerSourceText "No Battery"（powerSourceNoBattery） | MetricSnapshot.swift:1274（前次 L4-7 引用） | **当前代码已不存在** — `powerSourceNoBattery` 已从 SharedMetricStrings.swift 移除，`powerSourceText`（:1258-1272）当前 `case .some` 返回 `powerSourceExternal`，`default` 返回 `notReported`/`adapterCharging`/`stateNotReported` | **已修复**（前次死分支已删除） |
| ThermalState "fair"/"serious" 别名 | MetricStateContracts.swift:14,16 | 防御性别名 — SystemSampler.sampleThermalState（SystemSampler.swift:600-612）将 `ProcessInfo.thermalState` 的 `.fair`/`.serious` 翻译为 "Warm"/"Hot" 后存储，故 "fair"/"serious" 字符串值永不进入 snapshot；仅在外部/非采样器数据源下可达 | 防御性别名（实际数据流不可达） |
| NetworkPathState "requires_connection"/"requires connection" 别名 | MetricStateContracts.swift:42 | 防御性别名 — SystemSampler（:194-201）产出 "requiresConnection"（camelCase），lowercased → "requiresconnection" 命中首个别名；下划线/空格变体永不来自采样器 | 防御性别名（实际数据流不可达） |
| Edit 菜单 Undo/Redo（Selector(("undo:"))/Selector(("redo:"))） | AppDelegate.swift:152,153 | 响应器链菜单项 — 应用无文本编辑表面（Dashboard 仅有标签/滑块/按钮，Popover 仅有按钮，Settings 仅有滑块/按钮），Undo/Redo 永远禁用 | 死 UI（约定性样板，永远禁用） |

---

## 四、死资源清单

| 资源 | 位置 | 状态 |
|------|------|------|
| design/ 目录 | design/gptimage2-system-monitor/（13 PNG + README，42 行实现说明） | 与 designs/ 冗余 — 两个设计资产目录服务同一产品，git 跟踪，README.md 未引用任一目录 |
| designs/ 目录 | designs/macos-monitor-ui/（12 PNG + README，19 行） | 与 design/ 冗余 — 两个设计资产目录服务同一产品，git 跟踪 |
| dist/ 目录 | dist/Pulse Dock.app/（构建产物） | **已正确 gitignore**（`git check-ignore dist/` 返回 `dist/`；.gitignore:14 `dist/`）；非版本控制死资源，仅为本地构建残留 |

---

## 五、发现详情

### 死项 R3-1: isRefreshing（死状态）
- **声明位置**: MetricsStore.swift:47 `private(set) var isRefreshing = false`
- **赋值位置**: MetricsStore.swift:326（cancelRefreshTask）、:336（refresh 入口）、:347（refresh 任务完成）
- **确认无消费**: `grep -rn "isRefreshing" Sources/ Tests/` 仅返回 MetricsStore.swift 声明与赋值，以及 Tests/SharedMetricsTests/MetricFormattingTests.swift:4141-4142, 9386-9387 的元测试（验证源码字符串形式："private(set) var isRefreshing" 且非 "@Published"）。无任何视图（DashboardView/WidgetPanelView/AppDelegate）或业务逻辑读取其值。
- **影响**: 状态被维护（每次 refresh 翻转）但从不驱动任何 UI 或决策。测试锁定了其"非 @Published"形式，但未消费值。维护成本：refresh 路径多两行赋值 + 一行声明 + 两处元测试断言。
- **建议**: 删除 `isRefreshing` 声明及 :326,336,347 三处赋值；同步删除 MetricFormattingTests.swift:4141-4142, 9386-9387 的元测试断言。若未来需暴露刷新状态给 UI，改为 `@Published private(set) var isRefreshing` 并在视图中消费。
- **优先级**: R-低（无用户可见影响，纯维护成本）

### 死项 R3-2: widgetCompact 20 个死字段（共享存储载荷浪费）
- **声明位置**: MetricSnapshot+WidgetCompact.swift:9,11,17-24,26-27,33-40（20 个字段，当前行号可能随后续裁剪变化）
- **确认无消费**: `grep -oE "snapshot\.[a-zA-Z]+" SystemDashboardWidget.swift` 提取 widget 读取的 34 个属性全集；逐字段追溯派生属性消费链（MetricSnapshot.swift:1019-1432），确认以下 20 字段无任何 widget 渲染路径消费：
  - CPU：`cpuCoreUsages`、`physicalCoreCount`
  - 内存：`memoryFreeBytes`、`memoryWiredBytes`、`memoryCompressedBytes`、`memoryCachedBytes`、`memorySwapUsedBytes`、`memorySwapTotalBytes`、`memorySwapAvailableBytes`、`hasMemoryCompositionReport`
  - 负载：`loadAverage5`、`loadAverage15`
  - 电池：`batteryTimeRemainingMinutes`、`batteryCycleCount`、`batteryHealth`、`batteryCurrentCapacity`、`batteryMaxCapacity`、`batteryDesignCapacity`、`batteryVoltageMillivolts`、`batteryAmperageMilliamps`
- **当前纠正**: 初版报告中的 `networkBytesPerSecond`、`hasNetworkByteCounters`、`hasNetworkDirectionByteCounters`、`networkInBytesPerSecond`、`networkOutBytesPerSecond` 已经不在当前 compact 投影中，不再计入死字段。
- **影响**: 这 20 字段在 widgetCompactSnapshot() 中保留，经 SharedSnapshotStore.saveLatestSnapshot（SharedSnapshotStore.swift:40）JSON 编码写入 App Group UserDefaults，widget 端 JSONDecoder 解码后从不读取。每次共享存储写入浪费编解码字节（保守估计单 snapshot 载荷冗余 ~30-40%）。DashboardView 中这些字段多数活跃（如 `loadAverage5Text` DashboardView:551、`memorySwapText` :617、`networkText` :433、`batteryTimeRemainingText` :780），但宿主用全量 in-memory snapshot，不需共享存储承载。
- **建议**: 从 `widgetCompactSnapshot()` 中将这 20 字段降级为 nil/0/[]/false（与已裁剪字段同策略），仅保留 widget 实际渲染所需字段。需同步检查 SystemSampler.sampleWidgetCompact() 是否独立产出这些字段（若是，一并裁剪）。注意 `activeProcessorCount` 须保留（widget 经 loadAverageProgress 间接消费）；`schemaVersion` 须保留（loadLatestSnapshot:62 校验）。
- **优先级**: R-低（无用户可见影响，减少 App Group 载荷与编解码开销）

### 死项 R3-3: powerSourceText "No Battery" 分支（已修复，确认当前状态）
- **声明位置**: 前次 L4-7 引用 MetricSnapshot.swift:1273-1274 + SharedMetricStrings.swift:277-279
- **当前状态**: `grep -rn "No Battery|noBattery|powerSourceNoBattery" Sources/` 返回 **无匹配**。当前 `powerSourceText`（MetricSnapshot.swift:1258-1272）结构：
  - `case "ac power"` → adapter/adapterCharging
  - `case "battery power"` → battery
  - `case "ups power"` → UPS
  - `case .some` → `powerSourceExternal`（"External Power"）
  - `default` → `notReported` 或 `adapterCharging`/`stateNotReported`
  - **无 "No Battery" 分支**。`SharedMetricStrings.powerSourceNoBattery` 已从 SharedMetricStrings.swift:261-283 移除（当前仅保留 powerSourceAdapter/AdapterCharging/Battery/UPS/External/StateNotReported）。
- **影响**: 前次死分支已删除，本地化字符串已清理。无残留。
- **建议**: 无需行动。标记为"已验证修复"。
- **优先级**: 无（已修复）

### 死项 R3-4: design/ vs designs/ 目录冗余
- **位置**: design/gptimage2-system-monitor/（13 PNG，Jun 10 22:10）、designs/macos-monitor-ui/（12 PNG，Jun 10 21:14）
- **确认冗余**: 两个目录均为同一 macOS 系统监控应用的设计概念图集，分别由两次图像生成流程产出（gptimage2 vs macos-monitor-ui）。内容高度重叠（overview/dashboard、cpu、memory、storage/network、power/battery、gpu/display、processes、sensors/thermal、history/alerts、settings/permissions、desktop-widgets、menu-bar/menubar-popover）。两者均 git 跟踪（`git ls-files design/ designs/` 列出全部 26 PNG + 2 README）。项目 README.md 未引用任一目录。docs/review/top/final-review-v2.md:109（P2-28）已标记此冗余。
- **影响**: 仓库冗余 ~30MB 设计资产（25 PNG 重复主题），维护成本（两套 README 描述同一产品意图）。
- **建议**: 合并为单一 `design/` 目录，保留更完整的 gptimage2-system-monitor 集（13 PNG + 含实现说明的 README），删除 `designs/` 目录；或反之。合并后更新 README.md 引用。
- **优先级**: R-低（无功能影响，仓库卫生）

### 死项 R3-5: AppDelegate Edit 菜单 Undo/Redo（死 UI）
- **位置**: AppDelegate.swift:152 `Selector(("undo:"))`、:153 `Selector(("redo:"))`
- **确认无消费**: 应用无文本编辑表面 — DashboardView（标签/滑块/按钮/图表）、WidgetPanelView（标签/按钮）、Settings 子页（滑块/按钮）。Undo/Redo 菜单项经响应器链绑定，无 `NSResponder` 子类实现 `undo:`/`redo:`，菜单项将永远禁用。
- **影响**: 约定性 macOS Edit 菜单样板，用户可见但永远灰色禁用。无功能危害，仅为 UX 噪音。
- **建议**: 保留（符合 macOS 应用菜单规范，HIG 期望 Edit 菜单存在）或移除 Undo/Redo 两项仅保留 Cut/Copy/Paste/Delete/SelectAll（这些绑定 NSText 选择器，对无文本表面的应用也禁用，但更接近 HIG）。低优先级，可不动。
- **优先级**: R-低（约定性样板，无功能影响）

### 死项 R3-6: dist/ 目录（已正确 gitignore，非死资源）
- **位置**: dist/Pulse Dock.app/（构建产物 bundle）
- **确认**: `git check-ignore dist/` 返回 `dist/`；.gitignore:14 `dist/`。`git status --porcelain dist/` 无输出（未跟踪）。`git ls-files dist/` 无输出。
- **影响**: 无版本控制影响。仅为本地构建残留（Pulse Dock.app bundle，含 MacOS 可执行、AppIcon.icns、Info.plist、CodeResources）。
- **建议**: 无需行动。可定期 `rm -rf dist/` 清理本地构建产物。
- **优先级**: 无（已正确配置）

---

## 六、已验证为活跃的项（排除项）

### MetricsStore 状态（9 项活跃）
| 变量 | 读取证据 |
|------|---------|
| snapshot | DashboardView:22,28,61,421,642,950,1037,1090；WidgetPanelView:23；AppDelegate:337,338 |
| recentSnapshots | DashboardView:62 `let history = store.recentSnapshots`（无独立 `history` 属性，`recentSnapshots` 即历史消费点） |
| isPaused | WidgetPanelView:24；togglePause 经 AppDelegate:295 间接 |
| refreshInterval | DashboardView:28,1142,1198 |
| historyDepth | DashboardView:1171,1173 |
| cpuAlertThreshold | DashboardView:483,971,1014,1063,1073 |
| memoryAlertThreshold | DashboardView:484,972,1015,1064,1074 |
| diskAlertThreshold | DashboardView:489,973,1016,1065,1075 |
| showsMenuBarCPU | AppDelegate:277（combineLatest 订阅）,344（guard）；DashboardView:1160（settings toggle） |

### widgetCompact 活跃字段（24 项 widget 渲染消费 + 1 项数据路径消费）
- 渲染消费：cpuUsage、hasCPUUsageReport、logicalCoreCount、activeProcessorCount、memoryUsedBytes、memoryTotalBytes、loadAverage、hasLoadAverageReport、thermalState、batteryPercent、batteryIsCharging、batteryPowerSource、networkPathStatus、networkPathIsExpensive、networkPathIsConstrained、hasNetworkPathCostReport、networkPathSupportsDNS、networkPathSupportsIPv4、networkPathSupportsIPv6、hasNetworkPathSupportReport、networkPathInterfaceKinds、diskFreeBytes、diskTotalBytes、uptimeSeconds、hasUptimeReport、osVersion、kernelRelease、timestamp（共 28 字段，含 hasCPUUsageReport 等布尔守卫）
- 数据路径消费：schemaVersion（SharedSnapshotStore.loadLatestSnapshot:62 校验 `snapshot.schemaVersion == MetricSnapshot.currentSchemaVersion`）

### 防御性别名分支（非死代码，保留）
- ThermalState "fair"/"serious"（MetricStateContracts.swift:14,16）：Apple `ProcessInfo.thermalState` 枚举 case 名别名，SystemSampler 翻译为 "Warm"/"Hot" 后存储，别名仅对外部数据可达。保留为前向兼容。
- NetworkPathState "requires_connection"/"requires connection"（MetricStateContracts.swift:42）：拼写变体别名，SystemSampler 产出 "requiresConnection"。保留为前向兼容。

### 资源（已正确配置）
- dist/：.gitignore:14 正确覆盖，未跟踪。
- design/ 与 designs/：均 git 跟踪但内容冗余（见 R3-4）。

---

## 七、汇总

| 类别 | 数量 | 优先级分布 |
|------|------|-----------|
| 死状态 | 1（isRefreshing） | R-低 ×1 |
| 死字段（widget compact） | 20 | R-低 ×20 |
| 死分支 | 0（R3-3 已修复；thermal/network 别名为防御性保留） | — |
| 死 UI | 1（Undo/Redo 菜单，约定性样板） | R-低 ×1 |
| 死资源 | 1（design/ vs designs/ 冗余） | R-低 ×1 |
| 已修复确认 | 1（R3-3 "No Battery" 分支已删除） | — |
| **合计 actionable** | **23** | **全部 R-低** |

**核心结论**：
1. **R3-1 isRefreshing** 是唯一死状态 — 已被测试锁定形式但无消费方，可安全删除。
2. **R3-2 widgetCompact 20 死字段** 是最大冗余源 — widget 渲染只需 ~28 字段，但契约当前保留 44 个非裁剪字段，20 字段经 App Group 共享存储编解码后从不读取。裁剪可降低 UserDefaults 载荷与编解码开销。
3. **R3-3 "No Battery"** 前次死分支已在当前代码修复（powerSourceNoBattery 移除，case .some 改为 powerSourceExternal）。
4. **R3-4 design/ vs designs/** 两套设计资产目录冗余，建议合并。
5. **dist/** 已正确 gitignore，非死资源。
6. 所有 actionable 项均为 R-低（无用户可见功能影响，仅维护成本/载荷/仓库卫生）。
