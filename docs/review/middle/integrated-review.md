# Pulse Dock 深度代码审查 - 整合报告

## 审查概要
- 审查日期：2026-06-19
- 子 agent 数：5
- 审查文件数：27
- 审查总行数：16,444
  - SharedMetrics：5 文件 / 3,258 行
  - SystemDashboardApp：6 文件 / 3,224 行
  - SystemDashboardWidget：1 文件 / 750 行
  - Resources/Scripts/工程配置：14 文件 / 1,510 行
  - Tests：1 文件 / 7,702 行
- 去重后问题总数：88（原始 101，去重合并 13 条）
  - Bug 级：12
  - 质量级：55
  - 整洁级：21

> **去重说明**：5 份子 agent 报告原始共 101 条问题（17 Bug + 55 质量 + 29 整洁）。经交叉比对，4 组跨模块重复问题合并（可访问性 3→1、跨文件重复代码 7→1、本地化缺失 4→1、魔法数字 3→1），共减少 13 条。测试报告中的 5 条"Bug 级"为测试质量缺陷（非 App Bug），重新归类至质量级。

---

## 跨模块系统性问题

### 1. 可访问性缺失（Accessibility）
- **影响模块**：SystemDashboardWidget（全面缺失）、SystemDashboardApp（Popover 部分缺失）
- **严重度**：高（Bug 级）
- **现象**：
  - Widget 三个 family（Small/Medium/Large）根视图及所有子组件（RingMetric / WidgetRow / MiniStatus / StatTile / WidgetHeader / EmptyDataWidget）均无 `accessibilityLabel`，VoiceOver 用户只能听到零散 Text 片段。
  - `CompactWidgetHeader` 的 accessibilityLabel 包含 timeText，但视觉上不显示时间——信息不对称（Bug 03-B3）。
  - 主应用 DashboardView 中 MetricCard / RingGauge / Sparkline / StatusDot 有良好可访问性，但 PopoverMetricRow / PopoverSmallStat / SummaryCard / SourceCapabilityCard 缺失组合修饰。
- **建议**：在每个 family 根视图加 `.accessibilityElement(children: .contain)` + 汇总 label；为各子组件加组合 label（如 `"CPU 45%"`）；装饰元素用 `.accessibilityHidden(true)`；合并 WidgetHeader/CompactWidgetHeader 并统一 accessibility 逻辑。

### 2. 跨文件重复代码
- **影响模块**：SystemDashboardApp（DashboardView + WidgetPanelView）、SystemDashboardWidget
- **严重度**：低（整洁级，维护成本隐患）
- **现象**：
  - `progressFillWidth` 在 DashboardView、WidgetPanelView、SystemDashboardWidget **三处**各定义一份（均 private）。
  - `normalizedRate` / `reportedProgress` / `thermalTint`(thermalStatus) / `networkTint`(networkStatusLevel) / `powerTint` 在 DashboardView 与 WidgetPanelView **两处**重复。
  - `Palette`(WidgetPanelView) 与 `DashboardColor`(DashboardView) 颜色值完全相同。
  - `WidgetHeader` 与 `CompactWidgetHeader` 近似重复且可访问性不一致。
- **建议**：提取到 SharedMetrics 共享工具模块（如 `MetricTint`、`Palette`、`ProgressGeometry` 类型），单点维护。

### 3. 硬编码中文 / 本地化缺失
- **影响模块**：SystemDashboardWidget、Resources/Scripts、Tests、SharedMetrics
- **严重度**：中（质量级）
- **现象**：
  - Widget `configurationDisplayName("Pulse Dock")` / `description("...")` 硬编码中文字面量，未走 `LocalizedStringKey` / String Catalog。
  - AppInfo.plist 仅声明 `zh-Hans` 一种本地化，`CFBundleLocalizations` 覆盖面窄。
  - pbxproj `developmentRegion = en` / `knownRegions = (en, Base)` 与 Info.plist `CFBundleDevelopmentRegion = zh-Hans` 语义不一致。
  - 测试中将中文字符串（"未报告"、"在线"等）当硬编码契约扫描，与本地化声明存在潜在不一致风险。
- **建议**：改用 `LocalizedStringKey` / String Catalog；统一 pbxproj developmentRegion 为 `zh-Hans`；视市场计划补充 `en` 本地化；增加本地化键与 fallback 一致性测试。

### 4. 魔法数字未注释
- **影响模块**：SharedMetrics、SystemDashboardWidget
- **严重度**：低（整洁级）
- **现象**：
  - `MenuBarPopoverGeometry.windowChromeAllowance = 28` 未注释来源。
  - `MetricSnapshot.powerStatusProgress` 魔法值（0.45/0.7/0.55）未注释。
  - Widget 布局多处魔数（166 / 148 / 52 / 14 / 11 / 18 等）散落代码中。
- **建议**：提取为命名常量（如 `enum WidgetMetrics`）并添加注释说明计算依据。

### 5. 源码字符串扫描测试反模式
- **影响模块**：Tests
- **严重度**：中（质量级，影响测试可信度）
- **现象**：7702 行测试文件中 234 个测试函数、2623 条断言，其中约 79%（2129 条）为 `.contains(...)` 源码字符串扫描，仅 17% 为真实行为断言。367 条 `audit.contains(...)` 把 `docs/data-capability-audit.md` 锁成不可改写的契约，形成测试↔文档自引用闭环。
- **核心危害**：(1) 重构脆弱——任何 SwiftFormat/重命名触发数十误报；(2) 行为盲区——guard 存在性被扫描但 NaN 输入从未调用、并发守卫被扫描但竞态从未触发、可访问性字面量被扫描但 `accessibilityAudit()` 从未执行；(3) 文档锁定——任何文档润色破坏测试。
- **建议**：将格式化器/几何/Codable/阈值分级/状态机改为真实单元测试；删除大部分 `audit.contains` 断言；按功能域拆分 7702 行单文件为约 15 个测试文件；以 `MenuBarPopoverGeometry` 真实单测为改造模板。

### 6. 向后兼容推断策略不一致（OR vs AND）
- **影响模块**：SharedMetrics（影响 App/Widget 解码旧数据）
- **严重度**：中（质量级）
- **现象**：`MetricSnapshot` 各类型的 `has*Report` 推断策略在类型间不一致——ProcessMetric 用 OR（lenient），DisplayMetric / MetricSnapshot 用 AND（strict）。AND 策略缺一个 key 就使整个报告视为未报告。decoder 与 memberwise init 的推断语义也不完全对称（decoder 用 `??`，init 用 `||`）。
- **建议**：统一为 OR 策略或引入"部分报告"中间状态；decoder 推断也用 OR 合并。

---

## 上架阻塞项清单（Bug 级，必须修）

| # | 模块 | 文件:行号 | 问题 | 影响 | 阻塞等级 | 修复建议 | 工作量 |
|---|------|-----------|------|------|----------|----------|--------|
| 1 | SharedMetrics | SystemSampler:906-908,941-977,979-1034 | NSScreen.screens/main/backingScaleFactor 等在后台线程访问，违反 AppKit 线程规则。`sample()` 可在任意线程调用 | 数据不一致或 crash；Apple 审核可能 flagged | **硬阻塞** | 将 NSScreen 调用 dispatch 到主线程同步获取，或改用 CoreGraphics API（CGDirectDisplayID 系列）替代 | 0.5-1d |
| 2 | SystemDashboardWidget | SystemDashboardWidget:130-595 | Widget 三个 family 及所有子组件全面缺失 accessibilityLabel，VoiceOver 用户无法获得整体语义 | HIG 红线；可能被审核 flagged | **硬阻塞** | 每个 family 根视图加 `.accessibilityElement(children:.contain)` + 汇总 label；各子组件加组合 label | 0.5d |
| 3 | Resources/Scripts | generate-xcodeproj.rb:86; archive-app-store.sh:96 | 工程未生成显式共享 `.xcscheme`，`xcodebuild -scheme` 依赖 Xcode 运行时自动生成 | headless/CI 归档可能 "scheme not found" | **硬阻塞** | ruby 脚本显式写出 `SystemDashboard.xcscheme`（含 widget 依赖的 Build/Archive 动作） | 0.5d |
| 4 | Resources/Scripts | pbxproj:80,84; generate-xcodeproj.rb:37-38 vs 81 | productReference.path（`SystemDashboard.app`/`SystemDashboardWidgetExtension.appex`）与 PRODUCT_NAME 不一致 | 签名脚本/工具误导；隐式契约脆弱 | **硬阻塞** | 同步 productReference.path = PRODUCT_NAME，或 target 名与 PRODUCT_NAME 对齐 | 0.5d |
| 5 | SharedMetrics | SystemSampler:1037-1040 | `screenRefreshRate` 用 `maximumFramesPerSecond` 作为刷新率。ProMotion 降频时仍返回 120 | 数据显示不准确，用户可感知 | 软阻塞 | 用 `CGDisplayModeGetRefreshRate` 或 NSScreen `minimumRefreshInterval`/`maximumRefreshInterval` | 0.5d |
| 6 | SystemDashboardApp | AppDelegate:54-56 | `DispatchQueue.main.async` 闭包（@Sendable 非 @MainActor）调用 `@MainActor` 方法 `store.start()`，违反 Swift 并发隔离 | Swift 5 告警；Swift 6 报错 | 软阻塞 | 改为 `Task { @MainActor in store.start() }` 或直接同步调用 | 0.1d |
| 7 | SystemDashboardApp | MetricsStore:(无 deinit) | 类无 `deinit`，若释放前未调 `stop()`，timer 被 run loop 持有不会失效 | 进程级生命周期不触发；测试/重构暴露 | 软阻塞 | 添加 `deinit { timer?.invalidate(); initialRefreshTask?.cancel(); refreshTask?.cancel() }` | 0.1d |
| 8 | SystemDashboardApp | AppDelegate:314,404 | 每次打开 popover 新建 NSHostingController（一次打开最多 2 个），重建 SwiftUI 视图树 | 性能浪费；未来本地 @State 丢失 | 软阻塞 | 复用 hostingController，仅更新 preferredContentSize 与 frame | 0.5d |
| 9 | SystemDashboardApp | AppDelegate:266 | `cpuText` 为"未报告"时菜单栏显示" 未报告"异常文本 | 用户可见 UX 瑕疵 | 软阻塞 | 仅 `hasCPUUsageReport` 为 true 时显示文字，否则恢复 compactLength + 空标题 | 0.1d |
| 10 | SystemDashboardWidget | SystemDashboardWidget:22-27 | `isPrimed` prime 后立即二次 sample，CPU tick 增量微秒级 → 首次显示 CPU 噪声极大（可能 0% 或接近 100%） | widget 冷启动首次显示不可信 | 软阻塞 | prime 时直接返回首采（CPU 未报告）；或 getTimeline 生成两个 entry（now→prime, now+2s→real） | 0.5d |
| 11 | SystemDashboardWidget | SystemDashboardWidget:475 | CompactWidgetHeader accessibilityLabel 包含 timeText，但视觉不显示时间 | VoiceOver 信息不对称 | 软阻塞 | 移除 label 中 timeText，或恢复视觉显示 | 0.1d |
| 12 | Resources/Scripts | AppInfo.plist | 缺 `ITSAppUsesNonExemptEncryption`，App Store Connect 每次提交弹出口岸合规问卷 | 提交体验摩擦（不阻断但繁琐） | 软阻塞 | 增加 `ITSAppUsesNonExemptEncryption = false` | 0.1d |

> **硬阻塞**：可能导致审核拒绝/crash/归档失败，**必须**在上架前修复。
> **软阻塞**：不会直接被拒但影响质量/体验/未来兼容，**强烈建议**首发前修复。

---

## 首发版本建议修（质量级）

| # | 模块 | 文件:行号 | 问题 | 影响 | 修复建议 | 工作量 |
|---|------|-----------|------|------|----------|--------|
| 1 | SharedMetrics | MetricSnapshot:跨类型 | 向后兼容推断策略不一致（OR vs AND），AND 策略缺一 key 即整体未报告 | 旧数据显示"未报告" | 统一为 OR 策略或引入"部分报告"中间状态 | 1d |
| 2 | SharedMetrics | MetricSnapshot:1689-1690 vs 899-901 | decoder 用 `??`，init 用 `||`，推断语义不对称 | 旧 JSON 有 false+非零值时结果不一致 | decoder 也用 OR 合并 | 0.5d |
| 3 | SharedMetrics | MetricSnapshot:899-901,1689-1690 | load average 全 0 时 hasLoadAverageReport=false → 显示"未报告" | 极罕见，getloadavg 返回 0.00 几乎不可能 | 推断仅依赖 key 存在而非值 > 0 | 0.5d |
| 4 | SharedMetrics | MetricSnapshot:1049-1054 | memoryActiveBytes 中 `memoryWiredBytes + memoryCompressedBytes` UInt64 相加理论可溢出 | 实践不溢出（~128GB），防御性不足 | 分段比较：`memoryUsedBytes > memoryWiredBytes && memoryUsedBytes - memoryWiredBytes > memoryCompressedBytes` | 0.1d |
| 5 | SharedMetrics | MetricSnapshot:190-193 | GPUDeviceMetric hasDeviceKindReport 推断：单 key 存在且值为 false 时不报告，双 key 存在且值都为 false 时报告，不对称 | 单 key 已知设备不是低功耗时仍显示"未报告" | 简化为 `hasLowPowerKey \|\| hasRemovableKey` | 0.1d |
| 6 | SharedMetrics | MetricSnapshot:944-947,952 | hasRunningAppCountReport/hasUptimeReport 用 `\|\| count > 0` 推断，全 0 值视为未报告 | 实践不影响（processCount 永远 > 0） | 仅依赖显式标志 | 0.1d |
| 7 | SharedMetrics | MetricSnapshot:734-745 | compactCount 用 "B" 表示 Billion，与 MetricFormatting 中 "B" 表示 Byte 混淆 | 可读性问题 | 改用 "G" 表示 Giga | 0.1d |
| 8 | SharedMetrics | SystemSampler:411-413 | UInt32 页计数相加可能溢出（active+wire+compressor） | 实践不溢出，防御性不足 | 逐项转 UInt64 后相加 | 0.1d |
| 9 | SharedMetrics | SystemSampler:700 | `assumingMemoryBound(to: if_msghdr2.self)` 假设对齐 | 内核通常保证但非显式 | 改用 `buffer.load(fromByteOffset:as:)` | 0.1d |
| 10 | SharedMetrics | SystemSampler:855 | `homePath.hasPrefix($0.mountPath)` 可能匹配部分路径段 | sorted-by-length 降序缓解 | 改为精确匹配 + trailing `/` | 0.1d |
| 11 | SharedMetrics | SystemSampler:229-231 | sampleLock 持锁整个采样周期，并发调用串行化 | 设计取舍（粗锁保证快照一致性） | 可分离 inventory cache 锁，当前可接受 | — |
| 12 | SharedMetrics | MetricFormatting:11,28 | bytes/compactBytes 缺少 PB/EB 单位，累积网络计数器长期运行可能超 1024 TB | 长期运行显示异常 | 添加 "PB"/"EB" 到 units 数组 | 0.1d |
| 13 | SharedMetrics | MetricFormatting:52-60 | bitRate 缺少 Tbps 档和 bps 档，低于 500 bps 显示 "0 Kbps" | 极端值显示异常 | 增加 bps 档和 Tbps 档 | 0.1d |
| 14 | SystemDashboardApp | AppDelegate:92-93 | `settingsItem.keyEquivalent = ","` 重复赋值（init 已设） | 冗余代码 | 删除 L93 | 0.1d |
| 15 | SystemDashboardApp | AppDelegate:311,336 | `statusPopoverVisibleFrame(for:)` 在 prepareStatusPopover 内被调用两次 | 冗余计算 | 将 visibleFrame 作为参数传入 | 0.1d |
| 16 | SystemDashboardApp | AppDelegate:222-232 | `store.$snapshot` 与 `store.$showsMenuBarCPU` 两个独立 sink 均调用同一方法 | 每次 tick 触发两次 | 用 CombineLatest 合并 | 0.1d |
| 17 | SystemDashboardApp | AppDelegate:67 | `applicationShouldHandleReopen` 的 `flag` 参数未使用 | 语义不对齐 | 改为 `_ flag` 或加注释 | 0.1d |
| 18 | SystemDashboardApp | DashboardView:1605-1629 | `SettingRow` 视图为死代码，全项目未使用（测试亦断言不使用） | 维护负担 | 删除 `SettingRow` 结构体 | 0.1d |
| 19 | SystemDashboardApp | DashboardView:896 | `SettingReadOnlyRow` 的 `control: "5m"` 硬编码，与实际 WidgetKit 时间线间隔无关联 | 标签可能过时 | 提取为常量或从配置读取 | 0.1d |
| 20 | SystemDashboardApp | DashboardView:744 | ProcessesPage 内 ForEach 无 prefix 限制，与 ProcessListPanel(prefix 6) 不一致 | 若 sampler 返回更多则无上限 | 加 `.prefix(8)` | 0.1d |
| 21 | SystemDashboardApp | WidgetPanelView:153-156 | `reportedTint` 命名反直觉：未报告返回 cyan，报告返回 fallback | 可读性差 | 改名 `tintOrUnavailable` 并注释 | 0.1d |
| 22 | SystemDashboardApp | AppDelegate:197 | DashboardView 用 @ObservedObject 持有 store/router，若 NSHostingView 重建会丢失绑定 | 当前不重建，安全但脆弱 | 注释标注约束或改用环境注入 | 0.1d |
| 23 | SystemDashboardApp | MetricsStore:251-252 | 历史快照 osVersion/kernelRelease 统一取 placeholder 值，系统升级后旧历史显示新版本 | 影响轻微（已从历史剥离展示） | sanitized 中置 nil 而非 placeholder | 0.1d |
| 24 | SystemDashboardWidget | SystemDashboardWidget:54-109 | compactWidgetSnapshot 约 10 字段依赖 init 默认值静默置零，未来新增字段会被悄悄丢弃 | 当前正确但脆弱 | 在 MetricSnapshot 上加 `widgetCompact()` 工厂方法 | 0.5d |
| 25 | SystemDashboardWidget | SystemDashboardWidget:111-128 | compactWidgetInterfaces 将 displayName/kind 覆写为"未报告"，原始接口名丢失 | 当前不展示，OK | 加注释说明 widget 仅需 isUp/isLoopback 计数 | 0.1d |
| 26 | SystemDashboardWidget | SystemDashboardWidget:326-371 | EmptyDataWidget skeleton 看似真实数据，无"加载中"文字 | 首次加载可能误导 | header 加极小"加载中"标识 | 0.1d |
| 27 | SystemDashboardWidget | SystemDashboardWidget:606-609 | WidgetBackground 的 overlay alignment 对全填充 Rectangle 无效，是死代码 | 效果等同去掉 alignment | 删掉 alignment 或改为局部 frame | 0.1d |
| 28 | SystemDashboardWidget | SystemDashboardWidget:42-47 | getTimeline 只生成 1 个 entry，错失修复 CPU prime Bug 的机会 | 与 Bug #10 相关 | 首次返回 [now→prime, now+2s→real] 两个 entry | 0.1d |
| 29 | Resources/Scripts | install-system-widget.sh:25 | `pluginkit -a` 在 `set -e` 下非条件分支，返回非 0 直接终止重试循环 | 与"最多 5 次重试"语义冲突 | 加 `\|\| true` | 0.1d |
| 30 | Resources/Scripts | pbxproj:421,501 | project 级 SWIFT_VERSION=5.0 与 target 级 6.0 不一致 | 功能无误但具误导性 | ruby 脚本对 project 级也设 6.0 | 0.1d |
| 31 | Resources/Scripts | pbxproj:288,290-293 | developmentRegion=en / knownRegions=(en,Base) 与 Info.plist zh-Hans 不一致 | 无 .lproj 时无功能影响 | 设 developmentRegion=zh-Hans | 0.1d |
| 32 | Resources/Scripts | AppInfo.plist | 缺 CFBundleDisplayName（widget 侧已设） | 展示一致性 | 增加 CFBundleDisplayName=Pulse Dock | 0.1d |
| 33 | Resources/Scripts | generate-app-icon.swift:22 | colorSpaceName=.deviceRGB 为设备相关色彩空间，App Store 图标推荐 sRGB | 跨机器色彩不一致 | 改为 .sRGB 或 .extendedSRGB | 0.1d |
| 34 | Resources/Scripts | archive-app-store.sh:64 | manageAppVersionAndBuildNumber=false 且无自增逻辑，重复上传同版本会失败 | 流程级风险 | 文档化递增要求或改为 true 由 ASC 托管 | 0.1d |
| 35 | Resources/Scripts | generate-xcodeproj.rb:14-25 | bundle id 正则不允许下划线，Apple 实际允许 | 若将来 id 含 `_` 会被误拒 | 正则段允许 `_` | 0.1d |
| 36 | Tests | 全文 | 源码字符串扫描占 ~79%（2129/2623 断言），对重构极度脆弱 | 重构时大量误报 | 行为可测部分改为真实单元测试 | 3-5d |
| 37 | Tests | 全文 | 367 条 audit.contains 把 data-capability-audit.md 锁成不可改写契约 | 文档润色即破坏测试 | 删除大部分文档措辞断言 | 0.5d |
| 38 | Tests | 全文 | 7702 行单文件、234 测试混杂 20 功能域 | 定位与增删困难 | 按域拆分为约 15 个测试文件 | 1-2d |
| 39 | Tests | 全文 | 重复样板 `let root = URL(...); let x = try String(contentsOf:...)` 约 180 次 | 约 1500 行冗余 | 抽取 `func source(_ path:)` helper | 0.5d |
| 40 | Tests | 全文 | 依赖 FileManager.default.currentDirectoryPath | 工作目录变更即全部失败 | 改用 Bundle(for:) 或 #filePath | 0.5d |
| 41 | Tests | 7220-7230 | formattersGuard 测试只源码扫描 guard，从未调用 NaN/Infinity 验证实际返回"未报告" | guard 被替换测试仍通过 | 改为真实调用并断言 | 0.5d |
| 42 | Tests | 1640-1645 | samplerDoesNotExposeCrossProcessDetails 断言 processCount==0 但未断言模式开关，环境依赖 | 非沙盒环境可能误失败 | 注释环境前提或注入配置 | 0.1d |
| 43 | Tests | 13-17 | bytesFormatter 测试名声称"BinaryUnits"但输出十进制命名+1024 除法，未覆盖 TB 分支与 1024 边界 | 名实不符+边界缺失 | 补充边界并修正测试名 | 0.5d |
| 44 | Tests | 19-24 | networkRateFormatter 未测试 Mbps↔Gbps 阈值边界和 bitRate(0)/bitRate(.nan) | 边界缺失 | 补充阈值边界与异常输入测试 | 0.5d |
| 45 | Tests | 7376-7403 | 打包脚本测试仅字符串扫描，archive-app-store.sh 实际执行正确性从未验证 | 脚本 bug 无法检出 | 增加 bash -n 语法检查 + 关键函数行为测试 | 0.5d |
| 46 | Tests | 4995-5024,5261-5312 | range(of:) 顺序断言用 `??` 回退，缺失标记会静默通过 | 标记被重构删除时测试假通过 | 用 `try #require(...)` 代替 `??` | 0.1d |
| 47 | Tests | 614-618 | minutesFormatter 未覆盖 minutes(0)、minutes(1440)（刚好 1 天）、负数 | 边界缺失 | 补充边界 | 0.1d |
| 48 | Tests | 620-648 | displaySnapshotExposesExpectedStrings 只覆盖一个组合快照 | 未覆盖各字段单独"未报告"路径 | 拆分为按字段的参数化测试 | 0.5d |
| 49 | Tests | 7541-7582 | powerToneDistinguishesChargingBatteryAndLowPowerStates 只覆盖三态 | 未覆盖 low-power 模式等组合 | 扩展为参数化测试矩阵 | 0.5d |
| 50 | Tests | 全文 | 无并发测试：refreshGeneration 守卫、Task.detached 取消等全部只源码扫描 | 并发 bug 无法检出 | 用 Task + async 测试实际并发场景 | 1-2d |
| 51 | Tests | 全文 | 无 UI 渲染/可访问性行为测试，仅扫描 .accessibilityLabel 字样 | 可访问性实际行为未验证 | 添加 accessibilityAudit() 或快照测试 | 1d |
| 52 | Tests | 全文 | compactBytes/byteRate/load/duration 四个格式化器零直接测试 | 覆盖率盲区 | 补充单元测试 | 0.5d |
| 53 | Tests | 全文 | 无 MetricSnapshot 编码 round-trip 测试 | 编码正确性未验证 | 增加 encode→decode→等价测试 | 0.5d |
| 54 | Tests | 7405-7427 | appStoreReadinessChecklist 校验 markdown checklist 的 [x] 状态 | 清单更新即破坏测试 | 移除或改为校验已完成项数 ≥ 阈值 | 0.1d |
| 55 | 跨模块 | — | 硬编码中文/本地化缺失（系统性问题 #3） | 多语言上架风险 | 改用 LocalizedStringKey + String Catalog；统一 developmentRegion | 1-2d |

---

## 后续迭代项（整洁级）

| # | 模块 | 文件:行号 | 问题 | 建议 |
|---|------|-----------|------|------|
| 1 | SharedMetrics | MetricSnapshot:全文 | `!= "未报告"` 魔法字符串比较遍布全文 | 定义常量 `static let unreported = "未报告"` 或用 Optional 表示 |
| 2 | SharedMetrics | MetricSnapshot:1664-1751 | decoder 默认值混用 Self.placeholder.xxx 和字面量 0，风格不一致 | 统一用一种风格 |
| 3 | SharedMetrics | SystemSampler:374 | `isReported: totalTicks > 0` 在 guard totalTicks > 0 之后恒为 true，冗余 | 直接写 `isReported: true` |
| 4 | SharedMetrics | SystemSampler:1232-1234 | tickArray 每次调用分配新 [UInt32] | 直接用元组索引避免分配 |
| 5 | SharedMetrics | WidgetTimelineKind:1 | 未声明 Sendable | 添加 `: Sendable` |
| 6 | SystemDashboardApp | DashboardView:1712 | TableHeader 的 ForEach(columns, id: \.self) 用 String 作 id，列名重复时冲突 | 改用 enumerated id 或唯一性约束 |
| 7 | SystemDashboardApp | DashboardView:1421,1445 | MemorySegmentBar/CapacityBar 每段 max(width, 8) 最小宽度，窄面板可能溢出 | 用比例分配替代固定最小值 |
| 8 | SystemDashboardApp | DashboardView:434 | ForEach(Array(cpuCoreUsages.enumerated()), id: \.offset) 用 offset 作 id | 用 CoreUsage(index:) 包装 Identifiable |
| 9 | SystemDashboardApp | main.swift:4 | delegate 顶层常量靠作用域存活，app.delegate 为 weak，模式脆弱 | 加注释"顶层强引用不可移除" |
| 10 | SystemDashboardApp | AppDelegate:140 | View 菜单"打开设置"无快捷键，App 菜单"设置"为 ⌘,，不对齐 | 统一或保留差异并注释 |
| 11 | SystemDashboardWidget | SystemDashboardWidget:727-730 | activeInterfaceProgress 对 networkInterfaces 两次 filter | 合并为一次 reduce |
| 12 | SystemDashboardWidget | SystemDashboardWidget:54,111 | compactWidgetSnapshot/compactWidgetInterfaces 为文件级 free function，仅 SystemProvider 使用 | 改为 SystemProvider 的 private static 方法 |
| 13 | SystemDashboardWidget | SystemDashboardWidget:174-177 | largeRingColumns 定义在文件作用域 | 移入 LargeWidget 内部 private static let |
| 14 | SystemDashboardWidget | SystemDashboardWidget:692-694 | networkPathProgress default 返回 0，但 unknown 时 reportedProgress 返回 nil，0 永不被使用 | 保留作防御或加注释 |
| 15 | Resources/Scripts | pbxproj:87-104 | 框架路径硬编码 MacOSX15.0.sdk | 工程为生成产物，保持"改工程先跑 ruby 脚本"约定 |
| 16 | Resources/Scripts | pbxproj widget frameworks | widget 经 Cocoa 自动链接引入 AppKit，widget 用 SwiftUI 无需 | 可忽略；如需精简在 ruby 中移除 widget 的 Cocoa |
| 17 | Resources/Scripts | Package.swift | 未含 widget target（SwiftPM 限制） | 维持现状，注释说明 |
| 18 | Resources/Scripts | package-app.sh:79-80 | lsregister 路径硬编码系统框架内部路径 | 可接受；可用软链/PATH 兜底 |
| 19 | Resources/Scripts | archive-app-store.sh:94-103 | 归档后未校验 .xcarchive 存在 | 归档后 `[ -d "$ARCHIVE_PATH" ] \|\| exit` |
| 20 | 跨模块 | DashboardView + WidgetPanelView + Widget | progressFillWidth/normalizedRate/reportedProgress/thermalTint/networkTint/powerTint/Palette 跨 2-3 文件重复定义（系统性问题 #2） | 提取到 SharedMetrics 共享工具模块 |
| 21 | 跨模块 | SharedMetrics + Widget | 魔法数字未注释：windowChromeAllowance=28、powerStatusProgress 0.45/0.7/0.55、Widget 布局魔数（系统性问题 #4） | 提取为命名常量并注释 |

---

## 模块评价汇总

| 模块 | 文件数 | 行数 | Bug | 质量 | 整洁 | 评分 | 亮点 |
|------|--------|------|-----|------|------|------|------|
| SharedMetrics | 5 | 3,258 | 2 | 13 | 7 | 8/10 | Mach/IOKit 内存管理严谨、计数器回绕处理、隐私合规、Codable 向后兼容、除零/下溢防护全面 |
| SystemDashboardApp | 6 | 3,224 | 4 | 12 | 11 | 7/10 | 并发竞态防护（generation 守卫）、采样卸载后台、popover 几何约束、菜单完整、可访问性投入超平均 |
| SystemDashboardWidget | 1 | 750 | 3 | 7 | 5 | 6/10 | WidgetKit 现代 API、三 family 布局梯度、placeholder skeleton 对齐、防御性编码扎实、线程安全严谨 |
| Resources/Scripts | 14 | 1,510 | 3 | 8 | 6 | 8/10 | 权限最小化、隐私 manifest 精准（RR API 一一对应）、脚本工程规范、签名链路完整、图标管线自包含 |
| Tests | 1 | 7,702 | 0 | 19 | 0 | 6/10 | 回归门覆盖极广（234 测试）、MenuBarPopoverGeometry 真实单测优秀、遗留 JSON 解码测试有价值、测试命名规范 |

---

## App Store 上架风险评估

### 风险等级：中低（修复 4 项硬阻塞后为低）

### 合规基本面（已就位）
- **Sandbox**：App + Widget 均 `app-sandbox=true`，entitlements 仅最小权限 ✓
- **Hardened Runtime**：build settings 已开启 ✓
- **Privacy Manifest**：两份 xcprivacy 的 RR API（DiskSpace `85F4.1`、UserDefaults `CA92.1`、SystemBootTime `35F9.1`）均与源码实际调用一一对应，无遗漏、无多余 ✓
- **无私有 API**：IOKit/Mach/Network/SystemConfiguration/Metal/CoreGraphics 均为公开框架 ✓
- **无设备指纹收集**：网络采样仅读 AF_LINK 统计不提取 IP/MAC，不收集序列号/UUID ✓
- **菜单完整**：App/Edit/View/Window 四级菜单齐全，About 面板读 Bundle 版本，`applicationSupportsSecureRestorableState = true` ✓

### 硬性阻塞风险（4 项，必须修）
1. **NSScreen 后台线程访问**——AppKit 线程规则违反，可能导致 crash 或审核 flagged。
2. **Widget 可访问性全面缺失**——HIG 红线，VoiceOver 用户基本不可用，审核可能 flagged。
3. **缺共享 Scheme**——CI/headless 归档可能 "scheme not found"，恰在 App Store 归档链路上。
4. **productReference 与 PRODUCT_NAME 不一致**——签名脚本隐式契约脆弱，归档/签名链路风险。

### 软性风险（8 项 Bug 级，强烈建议首发前修）
ProMotion 刷新率不准、DispatchQueue 跨 actor、MetricsStore 无 deinit、hostingController 重复创建、菜单栏"未报告"文本、CPU prime Bug、CompactWidgetHeader 信息不对称、缺 ITSAppUsesNonExemptEncryption。这些不会直接导致审核拒绝，但影响用户体验、数据准确性和未来 Swift 6 兼容性。

### 结论
**修复 4 项硬阻塞后可提交 App Store 审核**。合规基本面扎实（sandbox/hardened runtime/privacy manifest 均已正确落实且经源码交叉验证），无私有 API、无隐私敏感数据收集。建议首发前同步修复 8 项软阻塞 Bug 以提升首次用户体验。质量级和整洁级问题可纳入后续迭代 backlog。

---

## 架构观察

### 分层设计（合理）
项目采用三层分离架构：
- **SharedMetrics**（核心层）：数据模型 + 系统采样。`MetricSnapshot` 为纯值类型（Codable + Equatable + Sendable），贯穿全栈；`SystemSampler` 封装所有底层系统 API（Mach/IOKit/CFNetwork/CoreGraphics）。该层无 UI 依赖，可被 App 和 Widget 共享。
- **SystemDashboardApp**（应用层）：AppKit 生命周期 + SwiftUI 主界面 + 菜单栏 popover。`MetricsStore` 作为 `@MainActor ObservableObject` 桥接采样与 UI，`DashboardView` 11 页面 + 通用组件库。
- **SystemDashboardWidget**（扩展层）：WidgetKit 扩展，复用 SharedMetrics 的 `SystemSampler` + `MetricSnapshot`，通过 `compactWidgetSnapshot` 裁剪字段适配 widget 展示。

### 并发设计（专业）
`MetricsStore` 的并发模型是该架构的亮点：
- `refreshGeneration` 守卫机制：cancel 时递增 generation，在途 Task 的 `guard generation == refreshGeneration` 自动作废过期采样——优雅防止陈旧结果覆盖新数据。
- 采样卸载到 `Task.detached(priority: .userInitiated)`，避免 CPU 密集采样阻塞主 actor，结果通过 `.value` 回主线程。
- `Timer` 闭包通过 `Task { @MainActor in ... }` 跳转正确隔离。
- `SystemSampler` 用 `NSLock` 保护可变状态，`@unchecked Sendable` 合规。

### 架构债务
1. **跨模块重复**：`progressFillWidth` / `thermalTint` / `networkTint` / `powerTint` / `Palette` 等工具函数和颜色定义在 DashboardView、WidgetPanelView、SystemDashboardWidget 2-3 处重复。应提取到 SharedMetrics 的共享 UI 工具模块（如 `MetricTint`、`Palette`、`ProgressGeometry`），单点维护。当前虽 private 无冲突但增加维护成本。
2. **Widget 字段裁剪脆弱**：`compactWidgetSnapshot` 逐字段手动设置约 40 个字段，约 10 个字段依赖 init 默认值静默置零。未来 `MetricSnapshot` 新增带默认值字段且 widget 需要时不会编译报错，数据被悄悄丢弃。应在 `MetricSnapshot` 上提供 `widgetCompact()` 工厂方法单点维护。
3. **推断策略不统一**：`MetricSnapshot` 各类型的 `has*Report` 向后兼容推断在 OR（lenient）与 AND（strict）间不一致，AND 策略过于严格。应统一为 OR 或引入"部分报告"中间状态。
4. **测试架构**：7702 行单文件、234 测试混杂 20 功能域，且 ~79% 为源码字符串扫描而非行为测试。应按功能域拆分，并将行为可测部分（格式化器、几何、Codable、并发、阈值分级）改为真实单元测试。

### 总体评价
架构设计整体**合理且成熟**：分层清晰、并发专业、隐私合规到位、Codable 向后兼容周到。主要债务集中在跨模块重复代码和测试方法论偏移，均不影响功能正确性，可在后续迭代中逐步收敛。
