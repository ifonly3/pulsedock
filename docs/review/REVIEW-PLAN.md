# Pulse Dock 全面代码 Review 计划 — Bug 与设计缺陷专项

> 制定日期：2026-06-27
> 审查目标：系统性发现 Bug（崩溃/数据错误/资源泄漏/并发问题）与设计缺陷（耦合/可维护性/性能/可测试性/可访问性/本地化）
> 审查基准：当前 working tree（HEAD 已含近期的 stability-optimization 修复）
> 复用资产：`docs/review/top/final-review.md`（2026-06-19 三层 review）、`docs/superpowers/plans/2026-06-27-pulse-dock-stability-optimization.md`

---

## 一、审查范围与规模

| 模块 | 路径 | 行数 | 关键文件 |
|------|------|------|----------|
| SharedMetrics | `Sources/SharedMetrics/` | ~3,935 | `SystemSampler.swift`(1331) / `MetricSnapshot.swift`(1756) / `SharedSnapshotStore.swift`(67) / `MetricFormatting.swift`(98) / `MenuBarPopoverGeometry.swift`(175) |
| PulseDockApp | `Sources/PulseDockApp/` | ~4,813 | `DashboardView.swift`(2060) / `PulseDockAppStrings.swift`(1379) / `AppDelegate.swift`(455) / `MetricsStore.swift`(491) / `WidgetPanelView.swift`(338) |
| PulseDockWidget | `Sources/PulseDockWidget/` | ~844 | `SystemDashboardWidget.swift`(735) / `PulseDockWidgetStrings.swift`(109) |
| Tests | `Tests/SharedMetricsTests/` | ~10,123 | 仅覆盖 `MetricFormatting` / `LocalizationGate` / `AppStoreScreenshot`；**无 sampler/store/widget 测试** |
| 资源/脚本 | `Resources/`, `scripts/`, `*.plist`, `*.entitlements` | — | App/Widget Info.plist、entitlements、打包脚本 |
| 构建 | `Package.swift`, `PulseDock.xcodeproj/` | — | Swift 6 严格并发、macOS 14 部署目标 |

**审查重点声明**：本次以**发现真实可触发的 Bug**与**结构性设计缺陷**为首要目标，整洁级问题（命名/魔法数字/注释）仅作附录，不占用主流程。

---

## 二、审查方法与分层

沿用项目已验证的三层并行结构（见 `docs/review/top/final-review.md:11-32`），但扩大覆盖面并对每个模块单独开子 agent。

```
顶层复核（本计划产出最终行动清单）
  ├─ 对照源码验证子 agent 发现
  ├─ 修正误判/降级/升级
  ├─ 标注已被 stability-optimization 计划覆盖的项
  └─ 生成 Bug→Fix 映射 + 优先级矩阵
        ↑
中层整合（middle/integrated-review-v2.md）
  ├─ 收集 6 份子 agent 报告
  ├─ 跨模块系统性问题识别（App Group 共享链路、采样线程模型、字符串契约）
  └─ 重复去重 + 上架风险评估
        ↑
子层逐行审查（subagents/，并行）
  ├─ 01-sharedmetrics-sampler.md     → SystemSampler + 依赖
  ├─ 02-sharedmetrics-model.md       → MetricSnapshot + Store + Formatting
  ├─ 03-pulsedockapp-lifecycle.md    → AppDelegate + MetricsStore + main
  ├─ 04-pulsedockapp-ui.md           → DashboardView + WidgetPanelView
  ├─ 05-pulsedockwidget.md           → SystemDashboardWidget + Strings
  └─ 06-build-resources-tests.md     → Package.swift/plist/entitlements/scripts/Tests
```

**并行执行要求**：6 个子 agent 必须在单条消息中并发派发；每个 agent 指定 `very thorough`，并要求返回 `file_path:line_number` 引用。每个 agent 的 prompt 末尾强制约束："**最终消息必须是完整报告，不得截断，不得以 'let me look at' 等过渡语结尾**"（前次探索曾出现结果被截断的问题）。

---

## 三、子 agent 任务清单（每项一份报告）

### 子任务 01 — SharedMetrics / SystemSampler 深审
**目标文件**：`Sources/SharedMetrics/SystemSampler.swift`（1331 行）
**重点审查项**：
- mach API 使用正确性：`host_processor_info` / `host_statistics64` / `mach_port_deallocate` / `vm_deallocate` 是否成对释放（参考 `SystemSampler.swift:345-349` 的 `mach_host_self` + `defer` 模式是否贯穿所有 mach 端口）
- IOKit 资源：`IOPSCopyPowerSourcesInfo` / `IOPSGetPowerSourceDetail` 返回的 CFType 是否正确 release
- CPU 采样数学：`previousCPUInfo` 比较与增量计算（`SystemSampler.swift:341` 起），UInt64 减法溢出、除零保护
- 网络速率采样：`sampleNetworkRate`（`SystemSampler.swift:770-795`）的 `elapsed > 0` 与计数器回退保护是否覆盖接口重置/休眠场景
- 缓存逻辑：`cachedStorage`/`cachedBattery`/`cachedGPUDevices`/`cachedDisplays`（`SystemSampler.swift:822-861`）的 `isCacheFresh` 时间窗判断是否有负数/时钟回拨漏洞
- **后台线程访问 NSScreen 问题**：`screenRefreshRatesByDisplayID` / `screenScalesByDisplayID` / `screenColorSpacesByDisplayID`（`SystemSampler.swift:1040,1060,1078`）`guard Thread.isMainThread else { return [:] }`，但 `MetricsStore` 通过 `Task.detached` 调用 `sample()`（`MetricsStore.swift:287-290, 321-324`）→ 显示器 scale/color/refresh **永远为空**（已被前次 review 标为硬阻塞 Bug-1，需确认是否已修）
- `@unchecked Sendable` + `NSLock` 的并发正确性，锁粒度是否过大（整个 `sample()` 串行化）
- `NetworkPathObserver` 的 `NWPathMonitor` 生命周期、队列选择、`current` 读取一致性

### 子任务 02 — SharedMetrics / 数据模型 + 持久化深审
**目标文件**：
- `MetricSnapshot.swift`（1756 行）— 数据模型、`Codable` 编解码、计算属性
- `SharedSnapshotStore.swift`（67 行）— App Group 持久化
- `MetricFormatting.swift`（98 行）+ `MetricSnapshot+WidgetCompact.swift`（61 行）+ `MetricScales.swift`（11 行）+ `MenuBarPopoverGeometry.swift`（175 行）

**重点审查项**：
- `MetricSnapshot` 的 `Codable` 实现：`decodeIfPresent ?? derived` 模式（`MetricSnapshot.swift:1667-1752`）的向前/向后兼容性；新增字段时旧 widget 解码是否会崩
- `widgetCompactSnapshot()`（`MetricSnapshot+WidgetCompact.swift:4-60`）裁剪后字段与 widget 读取契约的一致性（widget 仍读取 `storageVolumes`/`networkInterfaces` 等被裁空的字段，需确认 fallback 行为）
- `SharedSnapshotStore` 的 App Group 校验：`PulseDockAppGroup.supportsAppGroup`（`PulseDockAppGroup.swift:8-10`）要求 `Bundle.main.bundleIdentifier` 严格匹配 `com.ifonly3.pulsedock(.widget)`；**SPM 直接运行的 executable bundle id 为 nil → 静默失败、widget 永不更新**（需验证当前打包流程是否规避）
- `saveLatestSnapshot` 的 `try?` + `#if DEBUG` 静默失败（`SharedSnapshotStore.swift:47-49`）→ release 下 widget 停更无任何日志/告警
- `loadLatestSnapshot` 的 `try?` 解码（`SharedSnapshotStore.swift:57`）→ schema drift 时静默回退，无版本字段
- `MetricFormatting` 的 `String(format:)` 使用 C locale（`MetricFormatting.swift:24,41,53,57,60,69`）与 `SharedMetricStrings.localizedFormat` 的 `Locale.current`（`SharedMetricStrings.swift:404`）混用 → 本地化数字格式不一致
- `MetricScales.tenGigabitBytesPerSecond` 硬上限（`MetricScales.swift:4`）对 25/40/100 GbE 链路的钳制
- 数值转换陷阱：`Int(Double.nan)` / `Int(Double.infinity)` / `Int(UInt64.max)` 是否仍存在（stability-optimization Task 1 应已修，需确认）

### 子任务 03 — PulseDockApp / 生命周期与状态管理深审
**目标文件**：
- `AppDelegate.swift`（455 行）+ `main.swift`（14 行）
- `MetricsStore.swift`（491 行）
- `PulseDockLinks.swift`（49 lines）+ `VisualEffectView.swift`（27 行）

**重点审查项**：
- **采样线程模型 Bug**：`Task.detached(priority: .userInitiated) { sampler.sample() }`（`MetricsStore.swift:288-290, 322-324`）与 `SystemSampler` 内 NSScreen 主线程守卫冲突（见子任务 01）—— 这是跨模块系统性 Bug，本 agent 需确认 MetricsStore 侧的调用上下文
- `MainActor.assumeIsolated` in `deinit`（`MetricsStore.swift:94-100`）—— 若 store 被非主线程释放则 trap；评估实际可达性
- **主线程阻塞**：`saveSharedSnapshotIfNeeded`（`MetricsStore.swift:349-359`）JSON 编码、`persistHistoryIfNeeded`（`MetricsStore.swift:377-398`）最多 360 个 snapshot 的 JSON 编码、`applyVisibleApplicationSummary`（`MetricsStore.swift:423-459`）`NSWorkspace.shared.runningApplications` 全在主 actor
- **错误吞噬**：`_ = sharedSnapshotStore.saveLatestSnapshot(snapshot)`（`MetricsStore.swift:358`）丢弃返回值；`try?` 编解码（`MetricsStore.swift:196-199, 395-397`）静默失败
- Timer 生命周期：`Timer.scheduledTimer` 闭包用 `[weak self]`（`MetricsStore.swift:275`）但 RunLoop 持有 Timer，若未 `invalidate()` 则不释放；`stop()` 是否覆盖所有路径
- `refreshGeneration` 过期任务失效机制（`MetricsStore.swift:304-309, 318, 327-331, 343-345`）的正确性
- **缺系统事件观察**：无 `NSWorkspaceDidWakeNotification` / `NSWorkspaceDidSleepNotification` / 屏幕配置变更通知 → 唤醒后首个采样网络速率近零（`elapsed` 巨大）、显示器热插拔延迟 15s
- AppDelegate 内存管理：`NSStatusItem` 在 `applicationWillTerminate` 移除（`AppDelegate.swift:61-64`）；`statusPopover` 未显式关闭；`cancellables` 未清空（生命周期内可接受）
- `applicationShouldHandleReopen` 忽略 `hasVisibleWindows`（`AppDelegate.swift:67-70`）的 UX 影响
- 字符串选择器 `Selector(("undo:"))` / `Selector(("redo:"))`（`AppDelegate.swift:124-125`）死 UI

### 子任务 04 — PulseDockApp / UI 层深审
**目标文件**：
- `DashboardView.swift`（2060 行）— god file，11 个页面 + 25+ 组件 + 15+ 辅助函数
- `WidgetPanelView.swift`（338 行）
- `PulseDockAppStrings.swift`（1379 行）

**重点审查项**：
- **god file 设计缺陷**：2060 行单文件，应拆分为 `pages/` / `components/` / `helpers/`
- **性能 Bug**：trend-value 提取器 `cpuTrendValues`/`memoryTrendValues`/`networkTrendValues` 等（`DashboardView.swift:1904-1940`）在 `body` 中多次调用（`OverviewPage` `:362-403` 等处），每次 O(n) filter+map 遍历最多 360 个 snapshot，无 memoization → 每次渲染重复计算
- `Sparkline.preparedValues`（`DashboardView.swift:1347-1357`）每次渲染 `values.suffix(80)` 重新分配
- `ThresholdControlRow` / `SettingsPage` 拖拽时 `Binding(get:set:)`（`DashboardView.swift:1776-1779, 959-968, 972-977, 981-988`）每个 drag tick 触发 `@Published` → 整页重渲染
- **字符串契约脆弱**：`thermalStatus`/`thermalProgress`（`DashboardView.swift:2041-2060`）、`thermalTint`/`networkTint`（`WidgetPanelView.swift:159-180`）用小写字面量匹配 `SystemSampler` 输出的 Title-case 字符串；rename 即静默落入 `default`；存在死分支（`"fair"`/`"serious"` 永不命中，`SystemSampler.swift:494-507` 只输出 Nominal/Warm/Hot/Critical/Unknown）
- **跨文件重复代码**：`normalizedRate`/`reportedProgress`/`progressFillWidth` 在 `DashboardView` + `WidgetPanelView` 各一份；`Palette` 与 `DashboardColor` 颜色重复
- **本地化缺失**：硬编码 `"Pulse Dock"`（`DashboardView.swift:212,1183`）、`"CPU"`（`:875,888`；`WidgetPanelView.swift:54`）、`"MEM"`（`:1194`）、`"Core \(index)"`（`:1438,1455`）、`"DNS"/"IPv4"/"IPv6"`（`:605-607`）、`"5m"` widget 刷新值（`:979`，与详情文案"由系统时间线调度"矛盾）
- **可访问性不均**：`TrendRow`（`:1279-1300`）、`CompactMetricLine`（`:1365-1384`）、`DataChip`（`:1666-1684`）、`LegendDot`（`:1539-1551`）、`CapacityBar`（`:1507-1537`）、`MemorySegmentBar`（`:1459-1499`）、`DashboardSidebar` 行（`:201-247`）、`DashboardTopBar`（`:314-349`）缺 accessibility label
- `@State`/`@ObservedObject` 用法：对象由 `AppDelegate` 持有、视图用 `@ObservedObject`（正确）；无 `@StateObject` 误用
- `isRefreshing` `@Published` 但无视图消费（`MetricsStore.swift:47`）→ 死状态触发额外渲染

### 子任务 05 — PulseDockWidget 深审
**目标文件**：`Sources/PulseDockWidget/SystemDashboardWidget.swift`（735 行）+ `PulseDockWidgetStrings.swift`（109 行）

**重点审查项**：
- **WidgetKit 线程阻塞**：`getSnapshot`/`getTimeline`（`SystemDashboardWidget.swift:34-43`）同步调用 `sampledSnapshot()`，fallback 路径 `WidgetSamplerCache.sample()`（`:17-22`）在 widget 线程跑完整 `SystemSampler.sample()`（mach/IOKit/Metal/CG/NWPathMonitor）→ watchdog 超时风险
- **首次采样退化**：fallback 路径首次 tick CPU `hasCPUUsageReport=false`、网络速率 `0`（`SystemSampler.swift:367-370, 784`，双采样需求），UI 显示"Not reported"/`0 B/s`，5 分钟后才恢复
- **缺 widget families**：`supportedFamilies` 仅 `[.systemSmall, .systemMedium, .systemLarge]`（`:85`），缺 `.systemExtraLarge`、`.accessoryInline/Circular/Rectangular`；`default` 分支静默渲染 `SmallWidget`（`:57-66`）→ 新 family 布局错乱
- **placeholder 误导**：`placeholder(in:)` 返回 `snapshot: nil`（`:30-32`）→ gallery 显示加载骨架而非代表性预览
- **无 staleness 指示**：`MediumWidget` 用 `CompactWidgetHeader`（`:421-443`）隐藏 sample clock；freshness 窗口 600s > 刷新间隔 300s（`:28` vs `:41`），10 分钟内显示过期数据无任何视觉警告
- **字符串契约**：`thermalTint`/`networkTint`/`networkPathProgress`（`:653-687`）依赖 `SystemSampler` 输出字符串；存在死分支 `"requires_connection"`/`"requires connection"`（`SystemSampler` 只输出 `"requiresConnection"`，`:184`）
- **本地化缺失**：`configurationDisplayName("Pulse Dock")`（`:83`）、`"Pulse Dock"` header（`:110,138,328`）、`"CPU"`（`:115,189`）、`"UPS"`（`:729`）硬编码
- **可访问性不均**：`WidgetHeader`（`:399-419`）无 label、装饰圆点未 hidden；`CompactWidgetHeader`（`:421-443`）label 挂在 HStack 但子元素仍可单独聚焦；`SmallWidget`/`MediumWidget`/`LargeWidget` 根视图无 `.contain` 分组
- `@unchecked Sendable` 的 `WidgetSamplerCache`（`:13`）与 `SystemSampler.sampleLock`（`SystemSampler.swift:208`）双重锁，串行化但冗余
- `@main` 被 `#if !SWIFT_PACKAGE` 包裹（`:90-97`）→ SPM 构建无入口点，`swift test` 不编译 widget 源（stability-optimization Task 7 应已修，需确认）
- 静态 `samplerCache`/`sharedSnapshotStore`（`:26-27`）无依赖注入 → 不可测试
- UserDefaults 跨进程缓存：widget 侧无 `synchronize()`，可能读到上一轮 stale 值
- `networkPathProgress` 返回非 Optional `Double`（`:676-687`）→ 未识别状态渲染空进度条而非"Not reported"

### 子任务 06 — 构建、资源、脚本、测试深审
**目标文件**：
- `Package.swift`、`PulseDock.xcodeproj/project.pbxproj`
- `Resources/App/AppInfo.plist`、`Resources/Widget/WidgetInfo.plist`
- `Resources/App/PulseDock.entitlements`、`Resources/Widget/PulseDockWidgetExtension.entitlements`
- `Resources/App/PrivacyInfo.xcprivacy`、`Resources/Widget/PrivacyInfo.xcprivacy`
- `scripts/*.sh`、`scripts/*.rb`、`scripts/*.swift`
- `Tests/SharedMetricsTests/*.swift`

**重点审查项**：
- **App Group 一致性**：`PulseDockAppGroup.swift:4` 硬编码 `group.com.ifonly3.pulsedock`；entitlements 文件中 `com.apple.security.application-groups` 必须包含该 group；Info.plist 的 `CFBundleIdentifier` 必须为 `com.ifonly3.pulsedock(.widget)` —— 三处任一不一致则 widget 静默停更（对照验证）
- **`ITSAppUsesNonExemptEncryption`**：AppInfo.plist 是否声明（前次 review Bug-5，需确认是否已加）
- **entitlements 最小权限**：核对 app/widget entitlements 是否声明了不必要的权限（网络、摄像头、麦克风等）—— 隐私合规
- **PrivacyInfo.xcprivacy**：声明的数据采集类型是否与实际行为一致（README 声明"不采集个人数据"，需核对 `NSPrivacyCollectedDataTypes` 为空或匹配）
- `Package.swift` Swift 6 严格并发下是否 `swift build` / `swift test` 通过（widget target 是否被 test target 依赖；stability-optimization Task 7/16 应已修，需确认）
- 脚本安全：`scripts/package-app.sh` / `install-system-widget.sh` / `archive-app-store.sh` 是否硬编码路径、是否处理失败、是否 `set -e`、是否在 `~/Library` 写入需 sudo 的位置
- `generate-xcodeproj.rb` 生成的工程是否覆盖 SPM 无法处理的 widget extension 配置
- **测试覆盖缺口**：`Tests/` 仅 3 文件，全在 `SharedMetricsTests`；**无 `SystemSampler` 测试、无 `MetricsStore` 测试、无 `SharedSnapshotStore` 测试、无 widget 视图测试、无快照测试**；`MetricFormattingTests.swift` 9312 行但仅测纯函数
- 测试是否能在 CI（非主线程、无 NSScreen）环境通过
- `dist/` 目录是否纳入版本控制（应 gitignore 但未确认）
- `design/` 与 `designs/` 两个设计资产目录是否冗余

---

## 四、Bug 优先级矩阵（基于探索阶段已识别）

> 标注 `[NEW]` = 本次探索新发现；`[VERIFY]` = 需对照 stability-optimization 计划确认是否已修；`[EXIST]` = 前次 review 已记录

**P0 mapping used by v2 review docs**:
- P0-1 Display metadata is lost when detached sampling needs NSScreen metadata.
- P0-2 Widget synchronous fallback sampler must not synchronously run the full SystemSampler path.

### P0 — 崩溃/数据错误（硬阻塞）

| ID | 模块 | 位置 | 问题 | 状态 |
|----|------|------|------|------|
| P0-1 | SharedMetrics/App | `SystemSampler.swift:1040,1060,1078,1001` + `MetricsStore.swift:287-290,321-324` | Display metadata is lost when detached sampling needs NSScreen metadata；CGDisplay may still provide refresh rate, so this must not be described as refresh always empty | `[EXIST]` Bug-1，需 `[VERIFY]` |
| P0-2 | PulseDockWidget | `SystemDashboardWidget.swift:34-43,17-22` | Widget synchronous fallback sampler must not synchronously run the full SystemSampler path | `[NEW]` |
| P0-3 | SharedMetrics | `SystemSampler.swift` 数值转换 | `Int(Double.nan)` / `Int(Double.infinity)` / `Int(UInt64.max)` 是否仍 trap | `[VERIFY]` stability Task 1 |

### P1 — 严重功能缺陷（软阻塞）

| ID | 模块 | 位置 | 问题 | 状态 |
|----|------|------|------|------|
| P1-1 | PulseDockApp | `MetricsStore.swift:349-359,377-398` | 主 actor 上 JSON 编码最多 360 个 snapshot（每 15s）+ 共享 snapshot（每 60s）→ 帧卡顿 | `[NEW]` |
| P1-2 | PulseDockApp | `AppDelegate.swift`（全文） | 无 `NSWorkspaceDidWakeNotification`/屏幕变更观察 → 唤醒后首采样网络速率近零、显示器热插拔延迟 15s | `[NEW]` |
| P1-3 | SharedMetrics/App | `PulseDockAppGroup.swift:8-10` + `SharedSnapshotStore.swift:16-35` | App Group 校验要求 `Bundle.main.bundleIdentifier` 严格匹配；生产签名/开发入口需 release gate 验证，否则 widget 可能静默停更 | `[NEW]` |
| P1-4 | PulseDockWidget | `SystemDashboardWidget.swift:45-48` + `SystemSampler.swift:367-370,784` | fallback 首次 tick CPU/网络显示 "Not reported"/0，5 分钟才恢复 | `[EXIST]` Bug-4，需 `[VERIFY]` |
| P1-5 | PulseDockWidget | `SystemDashboardWidget.swift:85,57-66` | 缺 `.systemExtraLarge`/accessory families；`default` 静默渲染 SmallWidget | `[EXIST]`，需 `[VERIFY]` |
| P1-6 | PulseDockApp | `MetricsStore.swift:94-100` | `MainActor.assumeIsolated` in `deinit`，非主线程释放则 trap | `[NEW]` |

### P2 — 设计缺陷与质量

| ID | 模块 | 位置 | 问题 | 状态 |
|----|------|------|------|------|
| P2-1 | PulseDockApp | `DashboardView.swift`（2060 行） | god file，应拆分 | `[EXIST]` |
| P2-2 | PulseDockApp | `DashboardView.swift:1904-1940`（调用点 `:362-403`） | trend 提取器 O(n) 重复调用无 memoization | `[NEW]` |
| P2-3 | App/Widget | `DashboardView.swift:2041-2060`、`WidgetPanelView.swift:159-180`、`SystemDashboardWidget.swift:653-687` | 字符串字面量匹配 sampler 输出，rename 即静默失效；含死分支 | `[EXIST]` 跨模块 |
| P2-4 | App/Widget | `DashboardView.swift`+`WidgetPanelView.swift`+`SystemDashboardWidget.swift` | `progressFillWidth`/`normalizedRate`/`reportedProgress`/`Palette` 三处重复 | `[EXIST]` |
| P2-5 | 全模块 | 多处 | 硬编码 `"Pulse Dock"`/`"CPU"`/`"MEM"`/`"Core N"`/`"5m"` 未走本地化 | `[EXIST]` |
| P2-6 | PulseDockApp | `DashboardView.swift:1279,1365,1666,1539,1507,1459,201,314` | 多组件缺 accessibility label | `[EXIST]` |
| P2-7 | PulseDockWidget | `SystemDashboardWidget.swift:399-443` | `WidgetHeader`/`CompactWidgetHeader` 可访问性不一致；`MediumWidget` 隐藏时钟 | `[EXIST]` |
| P2-8 | PulseDockApp | `MetricsStore.swift:358,196-199,395-397` | 多处 `try?`/`_ =` 静默吞噬错误，无日志/遥测 | `[NEW]` |
| P2-9 | PulseDockWidget | `SystemDashboardWidget.swift:30-32,28,41` | placeholder 返回 nil；freshness 600s > 刷新 300s，无 staleness 指示 | `[NEW]` |
| P2-10 | 测试 | `Tests/` | 无 sampler/store/widget 测试，仅纯函数测试；CI 环境可运行性未验证 | `[NEW]` |
| P2-11 | SharedMetrics | `SharedSnapshotStore.swift:47-49,57` | release 下 save/load 失败静默，无 schema 版本字段 | `[NEW]` |

### P3 — 整洁级（附录，不阻塞）
- 魔法数字（`MenuBarPopoverGeometry.windowChromeAllowance=28`、widget 布局常量 166/148/52 等）
- `MetricScales.tenGigabitBytesPerSecond` 硬上限
- `MetricFormatting` 的 C locale vs `Locale.current` 混用
- `applicationShouldHandleReopen` 忽略 `hasVisibleWindows`
- `Selector(("undo:"))`/`Selector(("redo:"))` 死 UI
- `isRefreshing` `@Published` 死状态
- `design/` vs `designs/` 目录冗余

---

## 五、执行步骤

### 阶段 1：并发派发 6 个子 agent（单消息）
每 agent 读取对应文件全集，输出结构化报告（types/bugs/design/concurrency/line refs）。**强制要求完整报告、不截断**。

### 阶段 2：中层整合
- 收集 6 份报告 → `docs/review/middle/integrated-review-v2.md`
- 交叉比对去重（特别是 P0-1/P1-3 的跨模块采样线程问题、P2-3 的字符串契约问题）
- 识别跨模块系统性问题：
  1. **采样线程模型**（App `Task.detached` → SharedMetrics NSScreen 守卫 → Widget 同步采样）
  2. **App Group 共享链路**（bundle id 校验 → 静默失败 → widget fallback → 首次退化）
  3. **字符串契约**（sampler 输出 Title-case → UI 小写匹配 → 死分支）
  4. **重复代码与并行颜色系统**

### 阶段 3：顶层复核
- 对照源码验证每条发现（避免子 agent 误判，前次 review 已有先例：Bug-4 降级为整洁级）
- 标注 stability-optimization 计划已覆盖项（Task 1-8），避免重复工作
- 标注前次 review（2026-06-19）已修复项（commit 2488804）
- 生成 `docs/review/top/final-review-v2.md`：Bug→Fix 映射 + 优先级矩阵 + 工作量估算 + 上架风险评估

### 阶段 4：验证清单
对每条 P0/P1 Bug，要求 agent 给出：
- 触发条件（具体 macOS 版本/硬件/用户操作）
- 复现步骤
- 影响范围（崩溃/数据错误/性能）
- 修复建议（方案 A/B）+ 工作量估算
- 验证方法（单元测试/手动测试/CI gate）

---

## 六、验证与回归命令

审查期间/修复后需运行的验证：

```bash
# 构建（Swift 6 严格并发）
swift build

# 测试（确认 widget 源是否纳入编译）
swift test

# 本地打包验证 App Group 一致性
scripts/package-app.sh

# 本地化键一致性
scripts/audit-localization.sh

# 公开页面（隐私政策/支持页）验证
scripts/validate-public-pages.sh

# App Store 截图规格
scripts/validate-app-store-screenshots.sh

# Xcode 工程生成
scripts/generate-xcodeproj.rb
```

**关键验证点**：
1. `swift test` 是否编译 `Sources/PulseDockWidget`（stability-optimization Task 7/16）
2. 打包后 `dist/Pulse Dock.app/Contents/Info.plist` 的 `CFBundleIdentifier` 是否为 `com.ifonly3.pulsedock`
3. entitlements 是否包含 `group.com.ifonly3.pulsedock`
4. `PrivacyInfo.xcprivacy` 的 `NSPrivacyCollectedDataTypes` 是否为空（与 README 隐私声明一致）

---

## 七、交付物

1. `docs/review/subagents/01-sharedmetrics-sampler.md` ~ `06-build-resources-tests.md`（6 份子报告）
2. `docs/review/middle/integrated-review-v2.md`（整合报告 + 跨模块系统问题）
3. `docs/review/top/final-review-v2.md`（最终行动清单 + 优先级矩阵 + 上架风险）
4. 更新本计划文件的 checkbox 状态

---

## 八、约束与边界

- **只审查，不修改源码**（除非用户明确指示修复）
- 不引入新功能、新权限、新依赖
- 不改变现有公开 API（`SystemSampler.sample`、`SharedSnapshotStore` 等）的签名，除非 Bug 修复必需
- 修复建议必须与 stability-optimization 计划（`docs/superpowers/plans/2026-06-27-pulse-dock-stability-optimization.md`）对齐，不冲突
- 保持 Swift 6 严格并发合规
- 保持 macOS 14 部署目标

---

## 执行 Checklist

- [ ] 阶段 1：并发派发 6 个子 agent，收集 6 份子报告
- [ ] 阶段 2：中层整合，识别跨模块系统性问题
- [ ] 阶段 3：顶层复核，对照源码验证、标注已修项、生成优先级矩阵
- [ ] 阶段 4：为每条 P0/P1 Bug 给出触发条件 + 修复建议 + 验证方法
- [ ] 输出 `docs/review/top/final-review-v2.md` 最终行动清单
- [ ] 运行 `swift build` + `swift test` 确认基线状态
- [ ] 核对 App Group / entitlements / bundle id 三处一致性
- [ ] 核对 `PrivacyInfo.xcprivacy` 与 README 隐私声明一致
