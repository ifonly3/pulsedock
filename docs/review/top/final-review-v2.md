# Pulse Dock 深度代码审查 v2 — 顶层复核最终报告

> 审查日期：2026-06-27
> 审查方法：三层并行 review（6 子 agent 逐行 → 中层整合 → 顶层复核）
> 审查基准：当前 working tree（HEAD 已含 stability-optimization Task 1-8 部分落地）
> 前序 review：`docs/review/top/final-review.md`（2026-06-19，commit 2488804）
> 关联计划：`docs/superpowers/plans/2026-06-27-pulse-dock-stability-optimization.md`

---

## 一、审查概要

| 维度 | 数值 |
|------|------|
| 子 agent 数 | 6 |
| 审查文件 | 22 源文件 + 8 脚本 + 4 plist/entitlements + 3 测试 + Xcode 工程 |
| 原始发现 | ~48 条 |
| 去重后有效发现 | 42 条（P0: 2 / P1: 12 / P2: 28） |
| 已被 stability 计划覆盖且落地 | 9 条 `[PLAN-DONE]` |
| 本次新发现 | 33 条 `[NEW]` |
| 上架阻塞项 | 2 硬阻塞 + 6 软阻塞 |

---

## 二、顶层复核修正

### 2.1 确认 stability-optimization 计划已落地的项（从新发现清单移除）

| 计划 Task | 内容 | 验证证据 | 状态 |
|-----------|------|----------|------|
| Task 1 | Int(Double.nan)/Int(UInt64.max) 防 trap | `SystemSampler.swift:1270-1298` `intValue/doubleValue/finiteInt` | ✅ 已落地 |
| Task 2 | CPU 基线重置 + 电池缓存 | `SystemSampler.swift:251-256` + `MetricsStore.swift:125-126` + `cachedBattery` | ✅ 已落地 |
| Task 3 | 电源状态色调语义 | `MetricSnapshot.swift:1283-1319` powerStatusTone 重写；前次 review N2 已修 | ✅ 已落地 |
| Task 4 | 格式化边界 PB/EB + <60s | `MetricFormatting.swift:11,28,92-94` | ✅ 已落地 |
| Task 5（save 端） | 共享快照写入返回 Bool + DEBUG print | `SharedSnapshotStore.swift:37-52` | ✅ 已落地（**load 端未覆盖，见 P1-4**） |
| Task 6 | 网络 rate 对数尺度 | `MetricScales.swift` log10 曲线 | ✅ 已落地 |
| Task 7 | widget 编译/family/cache | `#if !SWIFT_PACKAGE`；default→SmallWidget；无死 priming | ✅ 已落地 |
| Task 8（部分） | popover 抑制常量命名 + NetworkPathObserving 协议 | `StatusPopoverTiming` enum；协议存在 | ⚠️ 部分落地 |

### 2.2 严重度确认与文字修正

本次复核确认大多数高优先级问题属实，但 P1-9、P2-5、P2-7/P2-8、P2-16、P2-19、P2-20、P2-25 需要降级、改写或删除，避免把产品判断写成事实。

P0-1 修正：NSScreen-derived scale/color and refresh fallback are dropped when sampling runs off-main. CGDisplay can still provide refresh rate, so do not describe refresh as always empty.

P0-2 修正：Widget fallback synchronously invokes a sampler path that can touch mach/IOKit/Metal/CG work. The watchdog risk is unmeasured in this review.

P2-19 removed: undo:/redo: are valid AppKit responder-chain selectors for text editing menus.

---

## 三、最终问题清单（按优先级）

### P0 — 硬阻塞（上架前必须修复）

| # | 模块 | 位置 | 问题 | 修复方案 | 工作量 |
|---|------|------|------|----------|--------|
| P0-1 | SharedMetrics/App | `SystemSampler.swift:1040,1060,1078,1001` + `MetricsStore.swift:287-290,322-324` | **Display metadata is lost when detached sampling needs NSScreen metadata**。`sample()` 经 detached task 恒在后台执行，旧实现会丢失 NSScreen-derived scale/color and refresh fallback；CGDisplay can still provide refresh rate，因此不应描述为 refresh always empty。 | 方案 A（推荐）：`screen*ByDisplayID` 内 `guard Thread.isMainThread else { return DispatchQueue.main.sync { /*现有body*/ } }`（detached 不自死锁，NSScreen.scripts 只读亚毫秒）。同步更新测试与 `docs/data-capability-audit.md:183`。方案 B：MetricsStore 主 actor 预取 NSScreen 快照注入 sample()。 | 0.5-1d |
| P0-2 | PulseDockWidget | `SystemDashboardWidget.swift:34-43,17-22,45-48` | **Widget timeline fallback must not synchronously run the full SystemSampler path**。fallback 路径在 widget 线程执行 mach/IOKit/Metal/CG/NWPathMonitor 全量采样；watchdog risk is unmeasured，但同步全量采样风险真实存在。getSnapshot 同步阻塞 gallery。 | (1) fallback 改为 widget-light sampler（只采 CPU/memory/thermal/battery，跳过 GPU/displays/storageVolumes 枚举）；(2) getSnapshot 返回 representative fixture（避免 gallery 阻塞）；(3) getTimeline 内 async + Task.detached(priority:.utility)。 | 1.5-2d |

### P1 — 软阻塞（建议上架前修复）

| # | 模块 | 位置 | 问题 | 修复方案 | 工作量 |
|---|------|------|------|----------|--------|
| P1-1 | App | `MetricsStore.swift:94-100` | `MainActor.assumeIsolated` in deinit，非主线程释放则 trap。当前隐式不变量脆弱。 | 方案 A：`nonisolated deinit`，移除 assumeIsolated（Timer.invalidate/Task.cancel 线程安全）。方案 B：stop() 完成全部清理，deinit no-op + assert(Thread.isMainThread) 文档化。 | 0.1-0.3d |
| P1-2 | App | `MetricsStore.swift:349-359,377-398,423-459` | 主线程阻塞：JSON 编码最多 360 snapshot（每 15s）+ 共享快照（每 60s）+ NSWorkspace 枚举（每 refresh）全在主 actor。 | 编码 offload 到 `Task.detached`，回主 actor 仅写 UserDefaults；NSWorkspace 摘要加 5s TTL 缓存。配合 P0-1 修复方案调整线程边界。 | 0.5-1d |
| P1-3 | App | `AppDelegate.swift`（全文无 observer） | 缺系统事件观察：无 NSWorkspaceDidWakeNotification/屏幕变更通知 → 唤醒后首采样网络速率近零（elapsed 巨大）、显示器热插拔延迟 15s。 | start() 注册 NSWorkspace.didWakeNotification → resetNetworkBaselines/resetCPUBaselines/invalidateDisplaysCache + refresh；注册 didChangeScreenParametersNotification → 失效 displaysCache。给 SystemSampler 加 invalidateDisplaysCache()。 | 0.5-1d |
| P1-4 | SharedMetrics/App | `SharedSnapshotStore.swift:57` + `MetricsStore.swift:358,196-199,395-397` | 错误静默：loadLatestSnapshot `try?` 无日志（save 有 DEBUG print 不对称）；MetricsStore 自身 `try?` 编解码静默失败。 | loadLatestSnapshot 改 do/catch + DEBUG print（与 save 对称）；MetricsStore 内 try? 同样加 DEBUG print；考虑暴露 @Published lastPersistenceError。 | 0.2-0.5d |
| P1-5 | App UI | `DashboardView.swift:1904-1940`（调用 :362-403,873-883） | trend 提取器 O(n) 无 memoization，每次最多 360 snapshot 遍历，OverviewPage 中多次重复调用 → 每 tick ~36 次 O(n) 扫描。 | page body 顶部 `let cpu = cpuTrendValues(from: history)` 一次，传值给 MetricCard + TrendRow；或引入 TrendCache 按 history identity memoize。 | 0.5-1.5d |
| P1-6 | App UI | `MetricsStore.swift:47` + `DashboardView.swift:1347-1357` | `isRefreshing` @Published 死状态无视图消费，每次 refresh 触发 2 次 objectWillChange → 3-4× 全树重渲染；Sparkline.preparedValues 2× 访问 + suffix(80) 重分配。 | isRefreshing 移除 @Published 或拆独立 ObservableObject；preparedValues hoist 到 body 内 `let`。 | 0.3-0.5d |
| P1-7 | App UI | `DashboardView.swift:1776-1789,959-988` | 阈值滑块/Picker 拖拽每个 tick 触发 @Published → 整页重渲染 60 次/拖。 | 本地 @State + onEditingChanged commit；或阈值拆独立 ThresholdStore。 | 0.5-1d |
| P1-8 | Widget | `SystemDashboardWidget.swift:45-48` + `SystemSampler.swift:367-370,784` | fallback 首次 tick CPU "Not reported"/网络速率 0（双采样需求），5 分钟才恢复。 | fallback 时显示 EmptyDataWidget 骨架（而非误导性 "Not reported"）；或 WidgetSamplerCache 一次性 priming warm-up。 | 0.5-1d |
| P1-9 | Widget | `SystemDashboardWidget.swift:85,57-66,255-337` | 缺 .systemExtraLarge/accessory families；default 静默渲染 SmallWidget；EmptyDataWidget 仅处理 small/medium/large。 | switch 改 @unknown default + 明确错误视图；EmptyDataWidget 按 family 完整分支。若新增 accessory family 需独立设计布局。 | 0.5d（防御性）/ 2-3d（实际新增） |
| P1-10 | Widget | `SystemDashboardWidget.swift:30-32,28,41,421-443` | placeholder 返回 nil → gallery 显示骨架而非预览；freshness 600s > 刷新 300s，10 分钟内过期数据无 staleness 指示；MediumWidget 隐藏时钟。 | placeholder 返回 representative fixture；SystemEntry 加 staleness 字段，header 圆点按 staleness 渐变（green/amber/red）；CompactWidgetHeader 渲染时钟或 staleness 圆点。 | 1d |
| P1-11 | 构建 | `docs/app-store-readiness-checklist.md` + `archive-app-store.sh` | App Group 生产签名共享未验证：automatic signing 不保证 profile 含 group；containerURL 返回 nil 则 widget 静默停更。 | (1) Apple Developer Portal 为两个 App ID 启用 App Group + 添加 group；(2) TestFlight 实测 containerURL 非 nil；(3) archive 脚本末尾 `codesign -d --entitlements` 校验 group 存在。 | 0.5d（外部 + 脚本） |
| P1-12 | 构建 | 测试缺口 | 无 pbxproj bundle ID ↔ Swift 常量 ↔ entitlements 交叉校验测试。 | 新增测试解析 pbxproj PRODUCT_BUNDLE_IDENTIFIER，断言 == PulseDockAppGroup 常量 + entitlements group。 | 0.3d |

### P2 — 设计缺陷与质量（择机批量处理）

| # | 模块 | 问题摘要 | 修复方向 |
|---|------|----------|----------|
| P2-1 | App/Widget | 字符串契约死分支（thermal "fair"/"serious"、network "requires_connection"） | 提取 enum ThermalState/NetworkPathStatus 到 SharedMetrics，编译期穷尽 |
| P2-2 | App/Widget | normalizedRate/reportedProgress/progressFillWidth/色板 三处重复 | 提取共享 PulseDockTheme 模块 |
| P2-3 | App | DashboardView.swift 2060 行 god file | 拆分 Pages/Components/Theme/Helpers |
| P2-4 | App | MetricsStore 491 行 god object（7 项职责） | 拆分 HistoryStore/SharedSnapshotCoordinator/WidgetReloadScheduler 等 |
| P2-5 | 全模块 | 硬编码 "Pulse Dock"/"CPU"/"MEM"/"Core N"/"5m"/"UPS" 未走本地化 | 路由 PulseDockAppStrings，新增 coreLabel/metricMEM 等 key |
| P2-6 | App UI | DashboardView "5m" widget 刷新值与 "System Scheduled" 详情文案矛盾 | 用 settingsWidgetRefreshValue 替换 |
| P2-7 | App UI | 13 个组件缺 accessibility（TrendRow/CompactMetricLine/DataChip/LegendDot/CapacityBar/MemorySegmentBar 等） | .accessibilityElement(.combine) + label；装饰圆点 .accessibilityHidden |
| P2-8 | Widget | WidgetHeader 无 a11y、CompactWidgetHeader label 未 combine、装饰圆点未 hidden | 同 P2-7 模式 |
| P2-9 | Widget | configurationDisplayName("Pulse Dock")/"CPU"/"UPS" 硬编码 | 走 PulseDockWidgetStrings |
| P2-10 | SharedMetrics | 无 schema 版本字段，字段类型变更静默破坏共享快照 | 加 schemaVersion: Int = 1 + decoder 版本门控 |
| P2-11 | SharedMetrics | widgetCompactSnapshot 裁剪契约靠手工列举，无类型级强制 | 引入独立 WidgetCompactSnapshot 类型或裁剪断言测试 |
| P2-12 | SharedMetrics | MetricFormatting String(format:) C locale vs SharedMetricStrings Locale.current 混用 | MetricFormatting 显式传 locale: Locale.current |
| P2-13 | SharedMetrics | MetricScales 10GbE 硬上限对 25/100 GbE 钳制 | 提取带注释常量，暴露配置或自适应分位 |
| P2-14 | SharedMetrics | decoder/init 推断策略不一致（AND/OR 混用） | 统一为 OR 策略，与 init 对称 |
| P2-15 | SharedMetrics | PulseDockAppGroup 严格匹配致 SPM/测试静默禁用共享存储 | DEBUG 下返回 false 时打印警告 |
| P2-16 | SharedMetrics | SharedMetricStrings .main bundle 在 widget extension 本地化风险 | 用 Bundle(for:) 锚定 framework bundle |
| P2-17 | App | AppDelegate 终止时 statusPopover 未 close、cancellables 未清空、dashboardWindow 未 orderOut | applicationWillTerminate 补全清理 |
| P2-18 | App | applicationShouldHandleReopen 忽略 hasVisibleWindows → 焦点闪烁 | if !flag { showWindow() }; return true |
| P2-19 | App | removed | undo:/redo: are valid AppKit responder-chain selectors for text editing menus |
| P2-20 | App | popover toggle 防抖 0.25s 竞态（慢机/辅助功能减速可能不足） | 依赖 popover.isShown 实际状态，或 popoverDidClose 严格门控 |
| P2-21 | App | MemorySegmentBar/CapacityBar 8pt 最小宽度窄布局溢出 | min(max(width,8), totalWidth*0.4) |
| P2-22 | Widget | WidgetSamplerCache 与 SystemSampler.sampleLock 双重锁冗余 | 移除外层锁，依赖 SystemSampler 内部锁 |
| P2-23 | Widget | networkPathProgress 返回非 Optional Double → 未识别状态空进度条 | 改返回 Double?，unknown 返回 nil |
| P2-24 | Widget | NaN 进度值 min(max(NaN,0),1) 不过滤，RingMetric trim(to:NaN) 行为未定义 | 派生属性层 sanitize isNaN；widget 加 clampedProgress 工具 |
| P2-25 | Widget | UserDefaults 跨进程无同步机制，可能读到 stale 值 | app 写后 WidgetCenter.reloadTimelines 主动通知（已部分有 60s 节流） |
| P2-26 | Widget | fallback 与 app 双 sampler 独立 baseline，CPU/网络速率可能不一致 | UI 加 source 标记；长期废弃 widget 本地 fallback，改 BGTask 维护共享快照 |
| P2-27 | Widget | MTLCopyAllDevices/mountedVolumeURLs 浪费：fallback 跑完整采样但 widget 只用主盘 | SharedMetrics 加 sampleWidgetCompact(now:) 轻量采样器 |
| P2-28 | 构建 | design/ vs designs/ 冗余目录；dist/ legacy System Dashboard.app 残留；pbxproj SWIFT_VERSION 项目级 5.0 vs target 6.0 | 合并设计目录；清理 dist；generate-xcodeproj.rb 设项目级 6.0 |

---

## 四、Bug→Fix 映射与验证方法

### P0-1 验证
- 触发条件：任何 macOS 14+ 设备运行 app，打开 Dashboard 显示器面板
- 复现：当前 backingScaleFactor 显示 "Not reported"
- 修复后验证：
  1. 单元测试：非主线程调用 `sampler.sample()`，断言 `displays.first?.backingScaleFactor != 0`
  2. 手动测试：运行 app，显示器面板应显示 Retina 倍数（2x）与色彩空间（Display P3）
  3. 更新 `MetricFormattingTests.swift:3249-3256` 断言
  4. 更新 `docs/data-capability-audit.md:183`

### P0-2 验证
- 触发条件：首次安装 widget / app 未运行超过 10 分钟
- 修复后验证：
  1. widget-light sampler 单元测试：断言不调用 MTLCopyAllDevices/mountedVolumeURLs
  2. gallery 预览：placeholder 返回 fixture，getSnapshot 不阻塞
  3. 手动测试：首次添加 widget 不卡顿，gallery 预览显示代表性数据

### P1 验证（通用）
- P1-1 deinit：构造 MetricsStore 在 detached Task 中释放，不应 trap
- P1-2 主线程阻塞：Instruments Time Profiler 验证编码不在主线程
- P1-3 唤醒：系统睡眠→唤醒后首次 refresh 网络速率非零
- P1-5/1-6 性能：Instruments SwiftUI 验证每 tick objectWillChange 次数减少
- P1-11 App Group：TestFlight build 运行后 widget 显示 app 共享数据

---

## 五、修复优先级与工作量汇总

| 优先级 | 项数 | 总工作量估算 |
|--------|------|-------------|
| P0（硬阻塞） | 2 | 2-3 人日 |
| P1（软阻塞） | 12 | 5-8 人日 |
| P2（质量） | 28 | 8-12 人日（可分批） |
| **合计** | **42** | **15-23 人日** |

**建议执行顺序**：
1. **第一周**：P0-1（采样线程）+ P0-2（widget 线程）— 上架硬阻塞
2. **第二周**：P1-1/1-2/1-3/1-4（生命周期/性能/事件/错误）— 核心稳定性
3. **第三周**：P1-5/1-6/1-7（UI 性能）+ P1-8/1-9/1-10（widget 体验）
4. **第四周**：P1-11/1-12（构建/签名验证）+ P2 批量处理

---

## 六、验证命令清单

修复后需运行的验证：

```bash
# 构建（Swift 6 严格并发）
swift build

# 测试（确认 widget 源编译 + 所有断言通过）
swift test

# 本地化键一致性
scripts/audit-localization.sh

# 公开页面验证
scripts/validate-public-pages.sh

# App Store 截图规格
scripts/validate-app-store-screenshots.sh

# Xcode 工程生成
scripts/generate-xcodeproj.rb

# 本地打包验证 App Group
scripts/package-app.sh

# App Store archive（需生产签名输入）
APP_BUNDLE_IDENTIFIER=com.ifonly3.pulsedock \
WIDGET_BUNDLE_IDENTIFIER=com.ifonly3.pulsedock.widget \
DEVELOPMENT_TEAM=<team> \
scripts/archive-app-store.sh
```

**关键验证点**：
1. `swift test` 通过（含更新后的 NSScreen 主线程断言）
2. 打包后 `dist/Pulse Dock.app/Contents/Info.plist` CFBundleIdentifier == com.ifonly3.pulsedock
3. entitlements 含 group.com.ifonly3.pulsedock
4. `codesign -d --entitlements - dist/Pulse\ Dock.app` 输出含 group
5. PrivacyInfo.xcprivacy NSPrivacyCollectedDataTypes 为空
6. 运行 app 显示器面板显示 Retina 2x + Display P3

---

## 七、约束与边界

- 本审查为只读，未修改任何源码
- 修复建议应与 stability-optimization 计划对齐，不冲突
- 保持 Swift 6 严格并发合规
- 保持 macOS 14 部署目标
- 不引入新功能、新权限、新依赖
- 不改变公开 API 签名（除非 Bug 修复必需）

---

## 八、 strengths（值得保留的设计优点）

审查中发现以下设计良好，应在重构中保留：
- @MainActor 覆盖一致（AppDelegate/MetricsStore/DashboardRouter）
- @ObservedObject 用法正确（对象由 AppDelegate 持有，非视图）
- [weak self] 在所有 Combine/Task/Timer 捕获
- Sendable 值类型跨 detached task 边界
- refreshGeneration 过期任务失效机制
- Codable decodeIfPresent 向前/向后兼容
- PulseDockLinks URL 校验健壮（https + host）
- 隐私清单与 README 一致
- App Group 四处标识一致
- entitlements 最小权限（仅 sandbox + app group）
- 脚本均 set -euo pipefail 且失败处理完备
- generate-xcodeproj.rb 正确覆盖 widget extension 配置

---

**审查完成。** 本报告与 `docs/review/middle/integrated-review-v2.md` 共同构成完整审查交付物。
