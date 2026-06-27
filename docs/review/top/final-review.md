# Pulse Dock 深度代码审查 - 顶层复核报告

> 审查日期：2026-06-19
> 审查方法：三层并行 review（5 子 agent 逐行 → 中 agent 整合 → 顶层比对复核）
> 审查基准：commit 2488804（最新）

---

## 一、审查架构与方法

```
┌─────────────────────────────────────────────────────────┐
│  顶层复核（本文档）                                       │
│  · 对照源码验证子 agent 发现                              │
│  · 修正误判/降级/升级                                     │
│  · 标注已被最新 commit 修复的项                           │
│  · 生成最终行动清单                                       │
├─────────────────────────────────────────────────────────┤
│  中层整合（middle/integrated-review.md）                  │
│  · 收集 5 份子 agent 报告                                 │
│  · 交叉比对、去重                                         │
│  · 跨模块系统性问题识别                                   │
│  · 上架风险评估                                           │
├─────────────────────────────────────────────────────────┤
│  子层逐行审查（subagents/01-05）                          │
│  · 01-sharedmetrics.md    3258 行 / 22 问题              │
│  · 02-systemdashboardapp.md 3224 行 / 27 问题            │
│  · 03-systemdashboardwidget.md 750 行 / 15 问题          │
│  · 04-resources-scripts.md 14 文件 / 17 问题             │
│  · 05-tests.md 7702 行 / 24 问题                         │
└─────────────────────────────────────────────────────────┘
```

**审查规模**：27 文件 / ~16,444 行代码 / 105 原始发现 → 去重 88 条 → 顶层复核后修正为 72 条有效发现

---

## 二、顶层复核修正

### 2.1 已被 commit 2488804 修复的项（从问题清单移除）

| 原 # | 问题 | 修复方式 | 验证 |
|-------|------|----------|------|
| Bug-1.1 | About 面板版权用未文档化 rawValue key | 改用 `NSHumanReadableCopyright` plist key + 移除 raw value | `AppInfo.plist:34-35` ✅ |
| Bug-1.2 | LICENSE 与 About 版权人不一致 | LICENSE 改为 "乔尼的铃角"，与 plist 一致 | `LICENSE:3` ✅ |
| 质量-3 | 窗口位置不持久（缺 frameAutosaveName） | 添加 `window.setFrameAutosaveName("PulseDockMainWindow")` | `AppDelegate.swift:194` ✅ |
| 质量-4 | MemorySegmentBar 硬编码 420pt | 改用 GeometryReader + `segmentWidth(bytes:in:)` | `DashboardView.swift:1389-1417` ✅ |
| 质量-5a | MetricCard 缺 accessibility | 添加 `.accessibilityElement(children:.combine)` + label/value/hint | `DashboardView.swift:1025-1028` ✅ |
| 质量-5b | RingGauge 缺 accessibility | 添加 combine + label + value | `DashboardView.swift:1202-1204` ✅ |
| 质量-5c | Sparkline 缺 accessibility | 添加 label "趋势图" + value（末值百分比） | `DashboardView.swift:1272-1273` ✅ |
| 质量-5d | StatusDot 装饰元素未 hidden | 添加 `.accessibilityHidden(true)` | `DashboardView.swift:1773` ✅ |

### 2.2 严重度修正（子 agent 误判）

| 原 # | 子 agent 判定 | 顶层修正 | 理由 |
|-------|---------------|----------|------|
| Bug-4 | 硬阻塞：productReference.path 与 PRODUCT_NAME 不一致 | **降级为整洁级** | `PBXFileReference.path` 仅影响 Xcode 导航栏显示名，实际构建产物由 `PRODUCT_NAME` 决定。脚本引用 "Pulse Dock.app" 匹配 PRODUCT_NAME，功能无误。仅导航栏显示 "SystemDashboard.app" 不美观 |
| Bug-3 | 硬阻塞：缺共享 .xcscheme | **维持 Bug 级但降为软阻塞** | `xcodebuild -scheme` 在首次运行（未开 Xcode）时可能找不到 scheme。但 `generate-xcodeproj.rb` 每次重建工程后，本地运行 `package-app.sh` 实测能通过（Xcode 自动生成 scheme 到 xcuserdata）。CI/headless 环境才是真正风险点 |
| Bug-2 | 硬阻塞：Widget accessibility 全面缺失 | **维持，但降为软阻塞** | Apple HIG 鼓励 accessibility 但不因 widget 缺 accessibility label 直接拒审。Widget 是 glanceable 介质，VoiceOver 支持优先级低于主 app。主 app 的关键控件已在 2488804 中补齐 |

### 2.3 新发现（子 agent 未报告，顶层复核发现）

| # | 文件:行号 | 问题 | 严重度 |
|---|-----------|------|--------|
| N1 | `AppDelegate.swift:162` | About 面板已移除 Copyright key 但未移除 `.version` 行尾逗号 → 实际无逗号问题（Swift 允许尾逗号），但 `AboutPanelOptionKey.version` 对应的是 build 版本号（CFBundleVersion），Apple About 面板规范中 `.version` 显示为 "Version X (Y)" 格式。当前实现正确 | 无问题 |
| N2 | `MetricSnapshot.swift:1290-1322` | `powerStatusTone` 逻辑：电量 ≥ 20% 且用电池供电时返回 `.warning`。但 MacBook 满电拔掉电源后应显示什么？当前逻辑：`batteryPercent=1.0, batteryPowerSource="Battery Power"` → 不充电 → 不是 AC → 走 `"battery power"` → `.warning`。满电用电池显示琥珀色不合理 | 质量级 |

---

## 三、修正后的问题清单

### 上架阻塞项（Bug 级）

| # | 模块 | 文件:行号 | 问题 | 阻塞等级 | 修复建议 | 工作量 |
|---|------|-----------|------|----------|----------|--------|
| 1 | SharedMetrics | SystemSampler:906-908,941-1034 | **NSScreen API 在后台线程访问**。`sample()` 通过 `Task.detached` 在后台执行，但 `screenRefreshRatesByDisplayID()`、`screenScalesByDisplayID()`、`screenColorSpacesByDisplayID()`、`fallbackDisplaysFromScreens()` 均直接调用 `NSScreen.screens`/`.main`/`.backingScaleFactor`/`.maximumFramesPerSecond`/`.colorSpace`/`.deviceDescription`，违反 AppKit 主线程规则 | **硬阻塞** | 方案 A：将这些方法的主线程调用结果缓存，在主线程预取后传入 sample()。方案 B：完全改用 CoreGraphics API（CGDirectDisplayID 系列）替代 NSScreen | 0.5-1d |
| 2 | SystemDashboardApp | AppDelegate:54-55 | **DispatchQueue.main.async 跨 actor 调用**。`store` 是 `@MainActor`，闭包是 `@Sendable` 非 `@MainActor`。Swift 6 严格并发会报错 | 软阻塞 | 改为 `Task { @MainActor in store.start() }` 或直接同步调用 `store.start()` | 0.1d |
| 3 | SystemDashboardApp | MetricsStore | **缺 deinit**。若 MetricsStore 被释放前未调用 `stop()`，Timer 被 RunLoop 持有不会失效 | 软阻塞 | 添加 `deinit { timer?.invalidate(); initialRefreshTask?.cancel(); refreshTask?.cancel() }` | 0.1d |
| 4 | SystemDashboardWidget | SystemDashboardWidget:22-27 | **CPU prime 首次采样不可信**。`isPrimed` prime 后立即二次 sample，CPU tick 增量微秒级 → 首次显示 0% 或接近 100% | 软阻塞 | getTimeline 生成两个 entry：now→prime（CPU 未报告），now+2s→real | 0.5d |
| 5 | Resources | AppInfo.plist | **缺 `ITSAppUsesNonExemptEncryption`**。每次提交 App Store Connect 弹出口岸合规问卷 | 软阻塞 | 添加 `<key>ITSAppUsesNonExemptEncryption</key><false/>` | 0.1d |
| 6 | Resources/Scripts | generate-xcodeproj.rb | **缺共享 .xcscheme**。CI/headless 归档可能 "scheme not found" | 软阻塞 | ruby 脚本显式写出 `xcshareddata/xcschemes/SystemDashboard.xcscheme` | 0.5d |
| 7 | SharedMetrics | SystemSampler:1037-1040 | **ProMotion 刷新率不准**。`maximumFramesPerSecond` 返回 120 而非当前实际刷新率 | 软阻塞 | 改用 CGDisplayMode 的 refreshRate 或 NSScreen 的 availableModes | 0.5d |

### 首发版本建议修（质量级，Top 15）

| # | 模块 | 问题 | 建议 | 工作量 |
|---|------|------|------|--------|
| 1 | SharedMetrics | 向后兼容推断策略不一致（OR vs AND） | 统一为 OR 策略 | 1d |
| 2 | SharedMetrics | MetricFormatting 缺 PB/EB/Tbps 单位 | 添加到 units 数组 | 0.1d |
| 3 | SharedMetrics | UInt32 页计数相加可能溢出 | 逐项转 UInt64 后相加 | 0.1d |
| 4 | SystemDashboardApp | 菜单栏 "未报告" 异常文本 | 仅 hasCPUUsageReport 时显示文字 | 0.1d |
| 5 | SystemDashboardApp | popover 每次打开重建 NSHostingController | 复用 hostingController | 0.5d |
| 6 | SystemDashboardApp | store.$snapshot 与 $showsMenuBarCPU 两个 sink 触发两次 | 用 CombineLatest 合并 | 0.1d |
| 7 | SystemDashboardApp | SettingRow 死代码 | 删除 | 0.1d |
| 8 | SystemDashboardApp | ProcessesPage ForEach 无 prefix 限制 | 加 .prefix(8) | 0.1d |
| 9 | SystemDashboardWidget | Widget accessibility 仍缺失 | 各 family 根视图加 combine + 汇总 label | 0.5d |
| 10 | SystemDashboardWidget | compactWidgetSnapshot 依赖 init 默认值裁剪 | 加 widgetCompact() 工厂方法 | 0.5d |
| 11 | 跨模块 | progressFillWidth/thermalTint/powerTint 等跨 2-3 文件重复 | 提取到 SharedMetrics 共享工具 | 1d |
| 12 | 跨模块 | 硬编码中文未走 LocalizedStringKey | 视市场计划决定 | 1-2d |
| 13 | MetricSnapshot | powerStatusTone 满电用电池显示 warning | 满电（≥0.95）用电池时改为 normal | 0.1d |
| 14 | Tests | ~79% 源码字符串扫描测试，重构脆弱 | 逐步改为行为测试 | 3-5d |
| 15 | Tests | 7702 行单文件 | 按功能域拆分为 ~15 个文件 | 1-2d |

### 后续迭代项（整洁级，Top 10）

| # | 问题 | 建议 |
|---|------|------|
| 1 | `!= "未报告"` 魔法字符串遍布全文 | 定义常量或用 Optional |
| 2 | productReference.path 与 PRODUCT_NAME 不一致 | 同步或在 ruby 脚本中对齐 |
| 3 | pbxproj project 级 SWIFT_VERSION=5.0 与 target 级 6.0 不一致 | ruby 脚本对 project 级也设 6.0 |
| 4 | developmentRegion=en 与 Info.plist zh-Hans 不一致 | 设为 zh-Hans |
| 5 | AppInfo.plist 缺 CFBundleDisplayName | 添加 "Pulse Dock" |
| 6 | powerStatusProgress 魔法数字（0.45/0.7/0.55）未注释 | 添加注释 |
| 7 | windowChromeAllowance=28 未注释来源 | 添加注释 |
| 8 | WidgetTimelineKind 未声明 Sendable | 添加 : Sendable |
| 9 | tickArray 每次分配新 [UInt32] | 用元组索引 |
| 10 | TableHeader 用 String 作 ForEach id | 改用 enumerated id |

---

## 四、上架风险评估（修正后）

### 风险等级：低（修复 1 项硬阻塞后为极低）

### 合规基本面（已就位 ✅）

| 检查项 | 状态 | 验证位置 |
|--------|------|----------|
| App Sandbox | ✅ | entitlements 两份均 `app-sandbox=true` |
| Hardened Runtime | ✅ | pbxproj `ENABLE_HARDENED_RUNTIME=YES` |
| Privacy Manifest - DiskSpace | ✅ | `85F4.1` 匹配 `FileManager.attributesOfFileSystem` |
| Privacy Manifest - UserDefaults | ✅ | `CA92.1` 匹配 `defaults.set/get` |
| Privacy Manifest - SystemBootTime | ✅ | `35F9.1` 匹配 `ProcessInfo.systemUptime` |
| 无私有 API | ✅ | IOKit/Mach/Network/Metal/CG 均公开 |
| 无设备指纹 | ✅ | 不收集 UUID/序列号/MAC/IP |
| 无数据收集 | ✅ | `NSPrivacyCollectedDataTypes = []` |
| 无 Tracking | ✅ | `NSPrivacyTracking = false` |
| 菜单完整 | ✅ | App/Edit/View/Window 四级 |
| About 面板 | ✅ | `NSHumanReadableCopyright` 已设 |
| 本地化声明 | ✅ | `zh-Hans` |
| 分类 | ✅ | `public.app-category.utilities` |
| 最低系统版本 | ✅ | 14.0 |
| 版本号 | ✅ | 1.0.0 (MARKETING_VERSION) |

### 硬性阻塞（1 项）

**NSScreen 后台线程访问**（Bug #1）：
- `SystemSampler.sample()` 被 `Task.detached(priority:.userInitiated)` 在后台线程调用
- `sampleDisplays()` → `screenRefreshRatesByDisplayID()` / `screenScalesByDisplayID()` / `screenColorSpacesByDisplayID()` / `fallbackDisplaysFromScreens()` 直接访问 `NSScreen.screens` 等 AppKit API
- AppKit 文档明确要求 NSScreen 在主线程访问
- 实践中可能不 crash（NSScreen 内部有锁），但 Apple 审核工具可能 flag，且在极端条件下可能导致数据不一致
- **修复方案**：在 `sample()` 入口处将 NSScreen 数据在主线程预取（`DispatchQueue.main.sync` 或预缓存），或完全改用 CoreGraphics API

### 软性阻塞（6 项，强烈建议首发前修）

| 项 | 影响面 | 不修的后果 |
|----|--------|------------|
| DispatchQueue 跨 actor | Swift 6 兼容 | 当前 Swift 5 编译器告警，未来报错 |
| MetricsStore 无 deinit | 内存/timer 泄漏 | 实践不触发（app 级生命周期），测试暴露 |
| Widget CPU prime | 首次显示不准 | 用户首次添加 widget 看到 0% 或 100% |
| 缺 ITSAppUsesNonExemptEncryption | 提交体验 | 每次提交弹问卷 |
| 缺共享 scheme | CI 归档 | headless 环境可能 "scheme not found" |
| ProMotion 刷新率 | 数据准确性 | 降频时显示 120Hz |

---

## 五、模块评价汇总（修正后）

| 模块 | 文件 | 行数 | Bug | 质量 | 整洁 | 评分 | 核心亮点 | 核心风险 |
|------|------|------|-----|------|------|------|--------|----------|
| SharedMetrics | 5 | 3258 | 2 | 13 | 7 | **8/10** | Mach 内存管理严谨、Codable 向后兼容、隐私合规 | NSScreen 线程安全 |
| SystemDashboardApp | 6 | 3224 | 3 | 10 | 8 | **7.5/10** | generation 防竞态、菜单完整、accessibility 投入 | DispatchQueue 跨 actor、无 deinit |
| SystemDashboardWidget | 1 | 750 | 2 | 6 | 5 | **6.5/10** | WidgetKit 现代 API、三 family 布局 | CPU prime、accessibility |
| Resources/Scripts | 14 | 1510 | 2 | 6 | 6 | **8/10** | 隐私 manifest 精准、签名链路完整 | 缺 scheme、缺 encryption 声明 |
| Tests | 1 | 7702 | 0 | 19 | 0 | **6/10** | 覆盖广（234 测试）、几何真测优秀 | 79% 源码扫描、单文件过大 |

---

## 六、架构观察

### 分层设计（合理 ✅）

```
SharedMetrics（核心层，无 UI 依赖）
  ├── MetricSnapshot       纯值类型数据模型（Codable+Equatable+Sendable）
  ├── SystemSampler        系统采样（Mach/IOKit/Network/Metal/CG）
  ├── MetricFormatting     格式化工具
  ├── MenuBarPopoverGeometry  popover 几何计算
  └── WidgetTimelineKind   共享常量

SystemDashboardApp（应用层）
  ├── main.swift           AppKit 手动生命周期
  ├── AppDelegate          菜单/窗口/popover/status item
  ├── DashboardView        11 页面 + 通用组件库（SwiftUI）
  ├── MetricsStore         @MainActor ObservableObject，桥接采样与 UI
  ├── WidgetPanelView      菜单栏 popover 内容
  └── VisualEffectView     NSVisualEffectView 桥接

SystemDashboardWidget（扩展层）
  └── SystemDashboardWidget  WidgetKit extension（Small/Medium/Large）
```

### 并发模型（专业 ✅）

- `refreshGeneration` 守卫：cancel 时递增，在途 Task 自动作废——优雅防陈旧覆盖
- 采样卸载到 `Task.detached(.userInitiated)`，不阻塞主 actor
- `SystemSampler` 用 `NSLock` + `@unchecked Sendable`，锁顺序一致无死锁
- `NetworkPathObserver` 独立队列 + NSLock

### 架构债务（4 项）

1. **跨模块重复**：`progressFillWidth`/`thermalTint`/`networkTint`/`powerTint`/`Palette` 在 2-3 文件重复 → 提取到 SharedMetrics
2. **Widget 字段裁剪脆弱**：`compactWidgetSnapshot` 逐字段手动设置 ~40 字段，10 个依赖 init 默认值 → 加 `widgetCompact()` 工厂
3. **推断策略不统一**：`has*Report` 在 OR/AND 间不一致 → 统一为 OR
4. **测试方法论偏移**：79% 源码扫描非行为测试 → 逐步改造

### 总体评价

架构设计**合理且成熟**：分层清晰、并发专业、隐私合规到位、Codable 向后兼容周到。最新 commit 2488804 已修复了 About 版权、窗口持久化、MemorySegmentBar 硬编码、部分 accessibility 等问题。主要剩余风险集中在 NSScreen 线程安全和 Widget CPU prime，修复后可提交 App Store 审核。

---

## 七、最终行动清单

### 上架前必须修（1 项硬阻塞）

- [ ] **NSScreen 后台线程访问**：将 `screenRefreshRatesByDisplayID()`/`screenScalesByDisplayID()`/`screenColorSpacesByDisplayID()`/`fallbackDisplaysFromScreens()` 的 NSScreen 调用改为主线程预取或替换为 CoreGraphics API

### 上架前强烈建议修（6 项软阻塞）

- [ ] `DispatchQueue.main.async` 改为 `Task { @MainActor in store.start() }`
- [ ] MetricsStore 添加 `deinit`
- [ ] Widget CPU prime：getTimeline 生成两个 entry
- [ ] AppInfo.plist 添加 `ITSAppUsesNonExemptEncryption = false`
- [ ] generate-xcodeproj.rb 生成共享 .xcscheme
- [ ] ProMotion 刷新率改用 CGDisplayMode

### 首发版本建议修（Top 10 质量级）

- [ ] 菜单栏 "未报告" 文本处理
- [ ] popover 复用 hostingController
- [ ] powerStatusTone 满电用电池改为 normal
- [ ] Widget accessibility 补齐
- [ ] 删除 SettingRow 死代码
- [ ] ProcessesPage 加 prefix
- [ ] MetricFormatting 加 PB/EB
- [ ] 跨模块重复代码提取
- [ | 推断策略统一为 OR
- [ ] UInt32 页计数逐项转 UInt64

### 后续迭代

- [ ] 测试改造（源码扫描→行为测试，拆分文件）
- [ ] 本地化（LocalizedStringKey + String Catalog）
- [ ] App Group 共享最近样本
- [ ] 内部 target/scheme 改名为 PulseDock
- [ ] 整洁级 10 项

---

## 八、文档索引

| 层级 | 文档 | 行数 |
|------|------|------|
| 顶层 | `docs/review/top/final-review.md`（本文档） | ~250 |
| 中层 | `docs/review/middle/integrated-review.md` | 249 |
| 子层 | `docs/review/subagents/01-sharedmetrics.md` | 443 |
| 子层 | `docs/review/subagents/02-systemdashboardapp.md` | ~400 |
| 子层 | `docs/review/subagents/03-systemdashboardwidget.md` | ~300 |
| 子层 | `docs/review/subagents/04-resources-scripts.md` | ~350 |
| 子层 | `docs/review/subagents/05-tests.md` | ~300 |
