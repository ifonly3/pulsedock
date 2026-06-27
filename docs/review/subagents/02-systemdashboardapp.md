# SystemDashboardApp 模块深度审查报告

## 审查概要
- 文件数：6
- 总行数：3224（main.swift 6 / AppDelegate.swift 423 / DashboardView.swift 1976 / MetricsStore.swift 448 / VisualEffectView.swift 21 / WidgetPanelView.swift 350）
- 发现问题数：27（Bug 级 4 / 质量级 12 / 整洁级 11）
- 审查基准：macOS App Store 上架合规、Swift 5.x 并发模型、AppKit 生命周期、SwiftUI 性能

---

## 逐文件审查

### main.swift（6 行）

```
1: import AppKit
2:
3: let app = NSApplication.shared
4: let delegate = AppDelegate()
5: app.delegate = delegate
6: app.run()
```

- **L3** `NSApplication.shared` 首次访问隐式初始化 NSApplication，标准做法。
- **L4** `delegate` 为顶层常量。`NSApplication.delegate` 是 `weak` 引用，但因 `delegate` 处于顶层代码作用域，其生命周期等同于进程，不会被提前释放。模式正确但脆弱——若后续重构包入函数/闭包会立即被释放（因 weak）。建议在注释中标注“必须保持顶层强引用”。
- **L5** 赋值给 `app.delegate`，AppDelegate 为 `@MainActor` 类，启动时已在主线程，无并发问题。
- **L6** `app.run()` 阻塞进入运行循环。其后代码不会执行（事实上也没有）。

整体：简洁、符合 AppKit 程序入口惯例。

---

### AppDelegate.swift（423 行）

#### 头部与类型定义（L1-L34）
- **L1-L6** 导入 AppKit/Combine/SwiftUI，`#if canImport(SharedMetrics)` 守护，正确处理模块可选依赖。
- **L8-L11** `MenuBarStatusItemLayout`：`compactLength = NSStatusItem.squareLength`（即 -1，系统自适应），`cpuTitleLength = 72`。常量集中，良好。
- **L13-L18** `StatusPopoverPresentation` 值类型，封装展示参数，良好。
- **L20-L23** `HiddenStatusPopoverContent` 用于隐藏/恢复内容透明度的快照，良好。
- **L25-L34** `MenuBarPopoverGeometry.Edge.nsRectEdge` 扩展：`.minY`/`.maxY` 一一映射到 `NSRectEdge`。命名重叠但语义一致，编译器可区分。OK。

#### AppDelegate 类声明与属性（L36-L47）
- **L36-L37** `@MainActor final class AppDelegate`，主 actor 隔离，符合 UI 层要求。
- **L38-L44** 窗口/状态项/popover/hostingController/cancellables/store/router 均为强持有私有属性。`store` 与 `router` 在属性初始化时即构造，`MetricsStore()` 会触发其 `init`（读取 UserDefaults）。注意此时 `applicationDidFinishLaunching` 尚未调用，但 `init` 仅读取 defaults，不启动定时器，安全。
- **L45-L47** `menuPopoverSize` 计算属性，依赖 `MenuPopoverLayout`（定义在 WidgetPanelView.swift），跨文件常量。OK。

#### 启动与终止（L49-L74）
- **L50** `setActivationPolicy(.regular)`：作为有 Dock 图标的常规应用。对于菜单栏+主窗口混合型应用合理。
- **L51-L53** 菜单 → 主窗口 → 状态项 顺序构建。
- **L54-L56** `DispatchQueue.main.async { [store] in store.start() }`：
  - **并发隐患（重要）**：`DispatchQueue.main.async(execute:)` 的闭包是 `@Sendable` 且非 `@MainActor` 隔离；而 `MetricsStore` 是 `@MainActor` 类，`store.start()` 是主 actor 方法。在 Swift 严格并发模式下属于跨 actor 调用，需 `await` 或 `MainActor.assumeIsolated`。当前 Swift 5 普通模式可能仅告警，但 Swift 6 下会报错。
  - **意图推测**：延迟到下一 runloop 以让窗口先显示。但 `store.start()` 本身很快（只调度定时器+启动初始采样 Task），延迟并非必要。
  - **建议**：改为 `Task { @MainActor in store.start() }`，或直接同步调用 `store.start()`（已在主 actor）。
- **L59-L65** `applicationWillTerminate`：`store.stop()` 持久化历史并取消定时器；移除状态项并置 nil。清理完整。未显式置空 `cancellables`，但进程即将退出，无害。
- **L67-L70** `applicationShouldHandleReopen`：Dock 点击时重新显示主窗口。`flag` 参数未使用（可改 `_ flag`，但保留可读性也可）。始终 `return true` 并显示窗口，即使已有可见窗口——行为无害但忽略 `hasVisibleWindows` 语义。
- **L72-L74** `applicationSupportsSecureRestorableState` 返回 `true`：App Store 必需项，正确。

#### 菜单构建（L76-L155）
- **L76-L83** `configureMainMenu`：App / Edit / View / Window 四级菜单，设置 `NSApp.mainMenu`。结构完整。
- **L85-L114** `makeAppMenu`：
  - **L89** “关于 Pulse Dock” → `showAboutPanel`，良好。
  - **L92-L93** `NSMenuItem(title:"设置...", action:..., keyEquivalent: ",")` 已在初始化设 keyEquivalent 为 `,`，**L93 又重复赋值 `settingsItem.keyEquivalent = ","`**：冗余代码。
  - **L97-L101** Services 子菜单，`NSApp.servicesMenu = servicesMenu`，系统标准项。
  - **L104-L108** 隐藏 / 隐藏其他（⌥⌘H）/ 全部显示，完整。
  - **L110** 退出 ⌘Q，绑定 `NSApplication.terminate`，正确。
  - 合规性：App 菜单完整，符合 HIG。
- **L116-L134** `makeEditMenu`：撤销/重做/剪切/复制/粘贴/删除/全选。`Selector(("undo:"))`/`Selector(("redo:"))` 为私有 selector 常见用法。响应链支持文本输入。良好。
- **L136-L143** `makeViewMenu`：⌘1 显示总览、打开设置。注意 App 菜单的“设置”是 ⌘,，View 菜单的“打开设置”无快捷键——两条入口一致但快捷键不对齐，可接受。
- **L145-L155** `makeWindowMenu`：最小化 ⌘M / 缩放 / 全部置于前方，`NSApp.windowsMenu` 设置。完整。

#### About 面板与菜单动作（L157-L173）
- **L157-L163** `showAboutPanel`：`orderFrontStandardAboutPanel` 传入应用名、短版本、构建版本，从 Bundle 读取并带默认值兜底。App Store 合规，良好。
- **L165-L168** `openSettingsFromMenu`：显示窗口 + `router.selectedPage = .settings`。先显示窗口再切页，顺序合理。
- **L170-L173** `showDashboardFromMenu`：切到 overview。

#### 主窗口（L175-L200）
- **L175-L184** `showDashboardWindow`：惰性创建窗口，`makeKeyAndOrderFront`，按需 `NSApp.activate()`。注意使用无参 `activate()`（macOS 14+ 推荐），测试也确认不使用旧 `ignoringOtherApps:` API，正确。
- **L186-L200** `createDashboardWindow`：
  - **L188** contentRect 1320×860，与 DashboardView idealSize 一致。
  - **L189** styleMask 含 titled/closable/miniaturizable/resizable，完整。
  - **L194** `setFrameAutosaveName("PulseDockMainWindow")`：持久化窗口位置，良好。
  - **L195** minSize 1180×760，与视图 minWidth/minHeight 一致。
  - **L196** `isReleasedWhenClosed = false`：ARC 管理窗口对象，关闭后对象存活以便 reopen，正确。
  - **L197** `NSHostingView(rootView: DashboardView(store:router:))`：SwiftUI 托管。

#### 状态栏项与 Popover 创建（L202-L262）
- **L202-L235** `createStatusItem`：
  - **L203** `squareLength` 初始长度，后由 `updateStatusButtonTitle` 动态调整。
  - **L204-L209** SF Symbol `waveform.path.ecg.rectangle`，accessibilityDescription 为 "Pulse Dock"，target/action 绑定 `toggleStatusPopover`。良好。
  - **L213-L220** 创建 `NSPopover`，`.transient`（失焦自动关闭），`animates = false`（避免与自定义几何动画冲突），设置 contentSize 与 hostingController。良好。
  - **L222-L232** 订阅 `store.$snapshot` 与 `store.$showsMenuBarCPU`，`[weak self]` 捕获，存入 `cancellables`。每次 snapshot 更新（1-5 秒）都会调用 `updateStatusButtonTitle`。
    - **可优化**：两个订阅都调用同一方法，可用 `CombineLatest` 合并为一个订阅，减少触发次数。
  - **L234** 赋值 `statusPopover`。
- **L237-L251** `makeWidgetPanelView`：构建 `WidgetPanelView`，三个闭包分别用 `[weak self]`（openDashboard/openSettings）和 `[store]`（togglePause）。`[store]` 强引用 store——因 store 由 self 持有，闭包由 popover 内容持有，不构成循环（store 不持有闭包）。安全。
- **L253-L262** `makeStatusHostingController`：`sizingOptions = []` 禁用自动尺寸（手动管理），设置 preferredContentSize 与 frame，`layoutSubtreeIfNeeded`。良好。

#### 状态按钮标题更新（L264-L267）
- **L265** 根据 `showsMenuBarCPU` 切换 `length`（squareLength ↔ 72）。
- **L266** `" \(store.snapshot.cpuText)"`：前导空格作为图标与文字间距。
  - **UX 问题**：当 `cpuText` 为 “未报告”（placeholder 或采样失败）时，菜单栏会显示 “ 未报告”，在菜单栏中显得异常。建议在 `!hasCPUUsageReport` 时隐藏文字并恢复 `compactLength`。

#### Popover 切换与展示（L269-L295）
- **L269-L278** `toggleStatusPopover`：shown 则 performClose，否则 prepare + show。`.transient` 下点击按钮可能先触发失焦关闭再触发 action，此处 isShown 检查覆盖两种情况。良好。
- **L280-L295** `showPreparedStatusPopover`：
  - **L281** 先隐藏内容透明度（防闪烁）。
  - **L282** `popover.show(relativeTo:of:preferredEdge:)`。
  - **L283-L285** guard window：若 show 后无 window（异常），恢复内容透明度并返回。
  - **L288-L293** window.alphaValue = 0 → 约束几何 → 布局 → 显示 → 恢复 alpha → 恢复内容 alpha。精细的防闪烁处理。
  - 逻辑严谨。

#### 内容隐藏/恢复（L297-L307）
- `hideStatusPopoverContentBeforeShowing` / `restoreStatusPopoverContentAfterShowing`：成对使用，保存/恢复 alpha。良好。

#### Popover 几何准备（L309-L374）
- **L309-L329** `prepareStatusPopover`：
  - **L310** `button.window?.layoutIfNeeded()` 确保按钮几何最新。
  - **L311** 计算 `visibleFrame`。
  - **L312** 计算 `placement`（内部**再次**调用 `statusPopoverVisibleFrame(for: button)`，见 L336）。
    - **重复计算**：`statusPopoverPlacement`（L331-L340）在 L336 又调一次 `statusPopoverVisibleFrame`，而 L311 已算过。两次结果通常相同（屏幕不会在微秒内变化），但冗余。建议将 visibleFrame 作为参数传入。
  - **L314-L321** **每次打开都新建 `NSHostingController`**：`makeStatusHostingController` 会重建 WidgetPanelView 整个 SwiftUI 树。
    - **性能/状态问题**：用户每次点击状态栏图标都重建视图树。WidgetPanelView 当前无本地 @State，尚可接受；但若未来加入滚动位置、动画等本地状态会丢失。且 `fitStatusPopoverContent`（L399-L412）可能在同一帧内**再次**新建 hostingController，一次打开最多创建 2 个 hostingController 实例。建议复用并仅更新 preferredContentSize。
  - **L323-L328** 构造 `StatusPopoverPresentation`。
- **L331-L340** `statusPopoverPlacement`：委托 `MenuBarPopoverGeometry.placement`，参数完整。
- **L342-L349** `statusPopoverAnchorKind` / `isStatusBarAnchorWindow`：用 `window.level >= statusBar` 判断锚点是否在状态栏。启发式合理。
- **L351-L353** `statusPopoverVisibleFrame`：`button.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame`。两级回退，良好。
- **L355-L358** `statusButtonScreenFrame`：`convertToScreen(button.convert(button.bounds, to: nil))`。bounds 转父坐标再转屏幕坐标，正确。
- **L360-L374** `statusButtonAnchorRect`：anchorWidth 钳制 18-30；若 `placement.anchorScreenMidX` 存在则水平居中对齐屏幕中点偏移。逻辑正确，避免窄屏时 popover 超出屏幕。

#### Popover 窗口约束（L376-L412）
- **L376-L397** `constrainStatusPopoverWindow`：
  - **L377-L378** guard window 与 visibleFrame（带回退）。
  - **L380-L384** 一次约束。
  - **L385-L393** 若高度被压缩（heightDelta > 0），调用 `fitStatusPopoverContent` 缩减内容高度并**再次约束**。迭代式收敛，合理。
  - **L394-L396** 若无变化则跳过 setFrame。
- **L399-L412** `fitStatusPopoverContent`：
  - **L400** `fittedHeight = max(1, min(popover.contentSize.height, height))`，保证 ≥1。
  - **L401** 仅在实际需要缩减时执行。
  - **L404-L411** **再次新建 hostingController**（见上述重复创建问题）。

#### Popover 动作回调（L414-L422）
- **L414-L417** `openDashboardFromPopover`：关闭 popover + 显示主窗口。
- **L419-L422** `openSettingsFromPopover`：**先** `router.openSettings()`（设置页面）**再** `openDashboardFromPopover()`（关闭 popover + 显示窗口）。顺序正确——窗口出现时已是设置页。

---

### DashboardView.swift（1976 行）

#### Router 与根视图（L1-L72）
- **L6-L13** `DashboardRouter`：`@MainActor ObservableObject`，`@Published selectedPage`，`openSettings()` 方法。简单清晰。
- **L15-L17** `DashboardView` 用 `@ObservedObject`（非 `@StateObject`）持有 store/router。因 store/router 由 AppDelegate 拥有且生命周期长于视图，`@ObservedObject` 正确（外部管理生命周期）。
- **L19-L40** body：HStack(sidebar, divider, VStack(topbar, ScrollView(pageContent)))。`.frame(minWidth:1180, idealWidth:1320, minHeight:760, idealHeight:860)` 与窗口尺寸对齐。`.background(WindowBackdrop())`。
- **L42-L71** `pageContent`：
  - **L44-L45** `let snapshot = store.snapshot` / `let history = store.recentSnapshots`：每次 body 求值捕获一次，避免子视图中多次属性访问触发Combine刷新。良好实践。
  - switch 11 个页面，`@ViewBuilder` 仅构造选中分支。良好。
  - **性能**：store 每次 tick（1-5s）触发 objectWillChange，整个可见页面重建。大多数页面是静态布局+Text，SwiftUI diff 成本低。Sparkline 用 Canvas（L1237）绘制，单次绘制成本低。可接受。

#### DashboardPage 枚举（L74-L136）
- CaseIterable + Identifiable，title/subtitle/icon 中文文案与 SF Symbol。完整。

#### 颜色与背景（L138-L182）
- **L138-L151** `DashboardColor`：语义色 + 品牌色（blue/green/amber/red/purple/cyan 为硬编码 RGB）。硬编码颜色在暗色模式下仍可读（已选适中明度），但未做动态适配。可接受。
- **L153-L166** `WindowBackdrop`：VisualEffectView + LinearGradient，响应 colorScheme。良好。
- **L168-L182** `windowBackdropColors`：暗/亮色三段渐变。良好。

#### 侧边栏（L184-L267）
- **L184-L230** `DashboardSidebar`：
  - **L185** `@Binding selection`。
  - **L186** `let snapshot: MetricSnapshot`——值传递拷贝。MetricSnapshot 是 struct，每次重建拷贝一次。可接受。
  - **L208-L212** `ForEach(DashboardPage.allCases)`，11 项 SidebarRow。
  - **L222** `frame(width: 224)` 固定侧边栏宽度。
  - **L223-L228** 背景 VisualEffectView + 色块。
- **L232-L267** `SidebarRow`：Button(.plain) 包裹整行，可访问性良好。选中态有背景圆角 + 左侧蓝色指示条。良好。

#### 侧边栏健康卡与顶栏（L269-L332）
- **L269-L295** `SidebarHealthCard`：采样时间 + CPU/内存/磁盘 CompactMetricLine。`thermalColor` 计算属性。
- **L297-L332** `DashboardTopBar`：页面副标题 + 描述 + DataChip 行。`frame(height: 82)` 固定高度。背景 VisualEffectView。

#### OverviewPage（L334-L384）
- **L342** LazyVGrid 4 列，4 个 MetricCard。CPU/内存/网络/电源。
- **L345** 网络 progress 用 `normalizedRate(..., baseline: 40_000_000)`。
- **L349-L375** HStack：趋势面板（5 TrendRow）+ 系统状态面板（10 StatusSummaryRow，width 330）。
- **L365-L366** CPU/内存状态使用 `store.cpuAlertThreshold`/`store.memoryAlertThreshold` 做阈值判断。良好。
- **L377-L381** ProcessListPanel + WidgetPreviewPanel(width 360)。
- 整体密度高但结构清晰。

#### CPUPage（L386-L444）
- **L405** Sparkline height 170。
- **L429-L438** 每核心使用率：空则“系统未报告”，否则 LazyVGrid 5 列。
  - **L434** `ForEach(Array(snapshot.cpuCoreUsages.enumerated()), id: \.offset)`：用 offset 作 id。核心数通常恒定，可接受；但若核心数变化（极罕见）SwiftUI diff 可能错位。
- **L441** ProcessListPanel（内部 prefix 6）。

#### MemoryPage（L446-L490）
- RingGauge(148) + MemorySegmentBar + KeyValueGrid(7 项) + 组成面板(width 360, 5 StatLine)。良好。

#### StoragePage（L492-L543）
- **L526** `ForEach(snapshot.storageVolumes.filter(\.hasInventoryReport).prefix(8))`：限制 8 行。TableRow 8 值匹配 TableHeader 8 列。良好。
- **L511** `CapacityBar(segments: diskCapacitySegments(snapshot))`。

#### NetworkPage（L545-L605）
- **L551** LazyVGrid 4 列，5 个 MetricCard（第 5 个换行）。
- **L559-L570** 连接能力表 7 行 3 列。
- **L572-L579** 网络趋势 4 TrendRow。
- **L581-L602** 接口表：空则 TableEmptyRow，否则 prefix(10)，8 列匹配。良好。

#### PowerPage（L607-L662）
- RingGauge(152) + KeyValueGrid(9 项) + 热状态面板(width 340) + 电池信息表 9 行 3 列。良好。

#### GPUDisplayPage（L664-L727）
- **L669** LazyVGrid 3 列 SourceCapabilityCard。
- **L678** ForEach gpuDevices，7 列。**L695** ForEach displays，9 列。均带 `filter(\.hasInventoryReport)`。
- **L713-L726** 统一内存摘要计算属性，逻辑清晰。

#### ProcessesPage（L729-L756）
- **L734** 4 个 SummaryCard。
- **L741-L753** DashboardPanel 内直接 ForEach：
  - **L744** `ForEach(snapshot.topProcesses.filter(\.hasInventoryReport))` **无 prefix 限制**。与 `ProcessListPanel`（L1071 用 prefix(6)）不一致。topProcesses 通常由 sampler 或 `applyVisibleApplicationSummary` 限制为 8 条，但若 sampler 返回更多则无上限。建议加 prefix 保持一致。

#### SensorsPage（L758-L819）
- **L776** LazyVGrid 2 列，11 个 SourceCapabilityCard。信息量大但 LazyVGrid 惰性加载。
- **L792-L800** 本地规则表 4 行。
- **L802-L816** 系统信号表 10 行。

#### HistoryAlertsPage（L821-L863）
- 历史趋势（Sparkline + 7 TrendRow）+ 阈值设置（3 ThresholdControlRow）+ 状态判断表 4 行。良好。

#### SettingsPage（L865-L944）
- **L875-L887** 刷新间隔 Picker（segmented），Binding get/set 调用 `store.updateRefreshInterval`。
- **L888-L895** 菜单栏 CPU Toggle。
- **L896** `SettingReadOnlyRow(title:"小组件刷新", detail:"由系统按时间线调度", control: "5m")`：
  - **硬编码 "5m"**：若 WidgetKit 时间线间隔调整，此标签会过时。建议提取为常量或从配置读取。
- **L897-L909** 历史深度 Picker。
- **L913-L926** 小组件预览面板(width 360)。
- **L929-L941** 数据来源表 8 行。

#### 通用组件（L946-L1790）
- **L946-L977** `DashboardPanel` 泛型容器：标题/副标题/图标 + content，`.panel(cornerRadius:8)`。
- **L979-L1030** `MetricCard`：含 `accessibilityElement(children:.combine)` + accessibilityLabel/Value/Hint。**可访问性优秀**。
- **L1032-L1060** `SummaryCard`：无显式可访问性修饰。Text 自身可访问，但未组合。建议补充。
- **L1062-L1082** `ProcessListPanel`：`prefix(6)` 限制行数。良好。
- **L1084-L1142** `WidgetPreviewPanel` / `WidgetMiniPreview`：固定 160×150，含 RingGauge×2，colorScheme 适配。良好。
- **L1176-L1206** `RingGauge`：Circle trim 进度环，clamp 0-1，含可访问性。良好。
- **L1208-L1229** `TrendRow`：标题+值+Sparkline。
- **L1231-L1292** `Sparkline`：
  - **L1237** `Canvas` 绘制——性能优良。
  - **L1239** `guard normalized.count > 1`：保证 L1245 除法 `count-1` 不为零。正确。
  - **L1245** `CGFloat(normalized.count - 1)`：count > 1 已保证，无除零。
  - **L1278** `values.suffix(80)`：限制 80 点，防止过长数组。良好。
  - **L1281-L1283** 单值时返回 `[value, value]` 画平线。良好。
  - **L1288-L1291** 可访问性值。
- **L1294-L1333** `CompactMetricLine` / `StatProgress`：GeometryReader 进度条，`progressFillWidth` 钳制。良好。
- **L1356-L1381** `CoreUsageTile`：
  - **L1372** `StatProgress(progress: value, ...)`：value 为 `Double`（非 Optional），StatProgress 接受 `Double?`，自动包装。但 CoreUsageTile 未检查 `hasReport`——若 value 为 0 或异常仍显示 0%。核心使用率通常仅在存在时出现，可接受。
- **L1383-L1423** `MemorySegmentBar`：
  - **L1421** `return max(width, 8)`：每段最小 8px。3 段共 24px+间距，窄面板可能溢出，但父级有 clipShape 处理。轻微视觉问题。
- **L1431-L1461** `CapacityBar`：
  - **L1445** `max(8, proxy.size.width * CGFloat(max(segment.value, 0)))`：同上最小 8px。2 段（已用/空闲）通常一段较大，溢出由 clipShape（L1448）裁剪。可接受。
- **L1477-L1500** `StatusLevel`：color + text。良好。
- **L1502-L1526** `StatusSummaryRow`：状态点 + 标题 + 值 + 状态标签。良好。
- **L1528-L1560** `SourceCapabilityCard`：无显式可访问性。建议补充。
- **L1562-L1583** `KeyValueGrid`：`ForEach(Array(items.enumerated()), id: \.offset)`。offset 作 id，items 静态可接受。
- **L1585-L1603** `DataChip`。
- **L1605-L1629** `SettingRow`：
  - **死代码**：全项目搜索仅 `SettingControlRow` 与 `SettingReadOnlyRow` 被使用，`SettingRow` 从未被调用。测试文件（MetricFormattingTests.swift L6736/L6985）甚至断言 `SettingRow` 不被使用。应删除。
- **L1631-L1657** `SettingReadOnlyRow`。
- **L1659-L1679** `SettingControlRow`。
- **L1681-L1705** `ThresholdControlRow`：Slider 0.5...0.98 step 0.01，与 `normalizedThreshold` 钳制范围一致。良好。
- **L1707-L1723** `TableHeader`：
  - **L1712** `ForEach(columns, id: \.self)`：String 作 id，若列名重复会 id 冲突。当前列名均唯一，但脆弱。
- **L1725-L1745** `TableRow`：`ForEach(Array(values.enumerated()), id: \.offset)`，首列加粗。未校验 values 数量与 header 列数一致（硬编码配对，OK）。
- **L1747-L1763** `TableEmptyRow`。
- **L1765-L1775** `StatusDot`：`accessibilityHidden(true)`，装饰性正确。
- **L1777-L1790** `panel()` 扩展：背景+描边+阴影，统一面板样式。良好。

#### 辅助函数（L1792-L1976）
- **L1792-L1795** `normalizedRate(_:baseline:)`：guard baseline > 0，防除零。良好。
- **L1797-L1800** `reportedProgress`：hasReport 守卫。
- **L1802-L1806** `progressFillWidth`：钳制 0-1，最小可见宽度。
  - **重复定义**：此函数在 WidgetPanelView.swift L338 也有一份（private），重复代码。
- **L1808-L1818** `reportedHistorySampleCountText` / `reportedHistorySampleChipText`：过滤 `hasSampleTimeReport` 计数。
- **L1820-L1856** 趋势值函数：均先 filter hasReport 再 map。
  - **L1825** `loadTrendValues`：`min($0.loadAverage / Double($0.activeProcessorCount), 1)`，guard `activeProcessorCount > 0`。正确。
  - **L1849-L1851** `uptimeTrendValues`：按最大 uptime 归一化。guard max > 0。正确。
- **L1858-L1869** `normalizedBytes` / `diskCapacitySegments`。
- **L1871-L1899** `networkStatusLevel` / `networkStatusColor` / `networkPathProgress`：字符串小写匹配。与 WidgetPanelView 的 `networkTint`（L181）逻辑重复。
- **L1901-L1906** `activeInterfaceProgress`。
- **L1908-L1940** `powerGaugeProgress` / `powerTint` / `powerStatusLevel` / `powerTrendTitle`。
- **L1942-L1945** `volumeLabel`：主卷/卷 N+1。
- **L1947-L1955** `usageStatusLevel` / `thresholdStatusText`。
- **L1957-L1976** `thermalStatus` / `thermalProgress`：字符串匹配，与 WidgetPanelView 的 `thermalTint`（L171）逻辑重复。

---

### MetricsStore.swift（448 行）

#### 枚举与常量（L1-L40）
- **L12-L20** `RefreshIntervalOption`：1/2/5 秒，`id`/`seconds`/`label`。良好。
- **L22-L30** `HistoryDepthOption`：90/180/360，`id`/`sampleCount`/`label`。良好。
- **L32-L40** `DefaultsKeys`：字符串常量集中管理。良好。

#### 类与属性（L42-L64）
- **L42-L43** `@MainActor final class MetricsStore: ObservableObject`。
- **L44-L52** `@Published private(set)`：snapshot/recentSnapshots/isPaused/refreshInterval/historyDepth/三个阈值/showsMenuBarCPU。封装良好，外部只读。
  - **L45** `recentSnapshots: [MetricSnapshot] = [.placeholder]`：初始为占位单元素。
- **L54-L64** 私有属性：sampler、defaults、timer、两个 Task、generation 计数、两个日期、三个间隔常量。
  - **L62** `initialSampleWarmUpDelayNanoseconds = 150_000_000`（150ms）。
  - **L63-L64** widget 60s / 历史 15s 节流间隔。

#### init（L66-L85）
- **L72** `RefreshIntervalOption(rawValue: defaults.double(forKey:))`：defaults 缺失返回 0.0，rawValue 0 无对应 case → nil → `.balanced`。正确兜底。
- **L73** `HistoryDepthOption(rawValue: defaults.integer(forKey:))`：缺失返回 0 → nil → `.standard`。正确。
- **L74-L76** `savedThreshold`：guard object 存在 else 返回默认；否则读取并 normalize。正确。
- **L77-L79** `showsMenuBarCPU`：`object(forKey:) == nil ? true : bool(forKey:)`。首次安装默认 true。正确。
- **L81-L84** 加载持久化历史，非空则替换 `recentSnapshots`。
  - **注意**：`snapshot`（L44）仍为 `.placeholder`，直到首次 refresh。即启动初期历史图有数据但“当前”卡片为占位。可接受的启动体验。

#### start / stop / togglePause（L87-L114）
- **L87-L91** `start`：guard timer nil，调度定时器 + 初始刷新。幂等。
- **L93-L99** `stop`：取消两个 Task、强制持久化、失效定时器、置 nil。完整。
  - **无 deinit**：类未定义 `deinit`。若 MetricsStore 被释放但未调用 `stop()`，`timer` 被 run loop 持有（闭包 `[weak self]` 不会泄漏 self，但 Timer 对象本身不会失效）。当前 store 由 AppDelegate 持有、生命周期=进程，实际不会触发。但单元测试或未来重构可能暴露此问题。建议添加 `deinit { timer?.invalidate() }`（@MainActor 类的 deinit 为 nonisolated，`timer?.invalidate()` 是线程安全的 NSObjective-C 调用，可安全执行）。
- **L101-L114** `togglePause`：
  - 暂停时：取消 Task、强制持久化、失效定时器。
  - 恢复时：`sampler.resetNetworkBaselines()`（避免暂停期间累计导致流量尖峰）、重新调度定时器 + 初始刷新。
  - 逻辑完整，恢复时重置网络基线是良好细节。

#### 更新方法（L116-L164）
- **L116-L124** `updateRefreshInterval`：guard 变化，更新+持久化，仅当 timer 存在（运行中）才重新调度。正确——暂停时不重建定时器。
- **L126-L133** `updateHistoryDepth`：更新+持久化+trim+强制持久化。正确。
- **L135-L157** 三个 `update*Threshold`：normalize + guard 变化 + 更新 + 持久化。正确。
- **L159-L164** `updateShowsMenuBarCPU`。正确。

#### 历史文本与阈值辅助（L166-L177）
- **L166-L168** `historyDurationText`：`sampleCount * seconds`。良好。
- **L170-L177** `savedThreshold` / `normalizedThreshold`：钳制 0.5-0.98。与 UI Slider 范围一致。

#### 历史持久化与净化（L179-L255）
- **L179-L188** `savedHistory`：解码 + suffix(limit) + sanitize。`try?` 失败返回 []。正确。
- **L190-L255** `sanitizedHistorySnapshot`：重建 MetricSnapshot，将易变/大体积字段置空（cpuBrandName、batteryCycle/Health/Design/Voltage/Amperage、networkInterfaces、storageVolumes、processCount、topProcesses、gpuDevices、displays）。
  - **L251-L252** `osVersion/kernelRelease = MetricSnapshot.placeholder.osVersion/kernelRelease`：历史快照统一用占位 OS 版本。若系统升级，旧历史会显示新版本字符串。因这些是展示性字段且已从历史剥离，影响轻微。
  - 净化逻辑减少存储体积，设计合理。

#### 定时器调度（L257-L265）
- **L257-L265** `scheduleTimer`：
  - **L258** 失效旧定时器。
  - **L259-L263** `Timer.scheduledTimer`，闭包 `[weak self]` + `Task { @MainActor in self?.refresh() }`。Timer 回调在主 run loop，但闭包本身非 @MainActor 隔离；通过 Task @MainActor 跳转正确。
  - **L264** `tolerance = min(seconds * 0.18, 0.5)`：允许 18% 容差（上限 0.5s），降低功耗。良好。
  - **Timer 泄漏隐患**：见上述“无 deinit”。

#### 初始刷新与任务管理（L267-L291）
- **L267-L280** `startInitialRefresh`：
  - **L271-L274** `Task { @MainActor ... await Task.detached(priority:.userInitiated){ sampler.sample() }.value }`：采样在 detached Task（后台线程）执行，`.value` 等待结果。正确——采样是 CPU 密集型，不阻塞主 actor。
  - **L275** `try? await Task.sleep(nanoseconds: warmUpDelay)`：150ms 暖机。
  - **L276** `guard !Task.isCancelled, let self, timer != nil`：取消/释放/已停止则跳过。`timer != nil` 确保仅在运行中刷新。
  - 良好。
- **L282-L285** `cancelInitialRefresh`：cancel + nil。
- **L287-L291** `cancelRefreshTask`：**generation += 1** + cancel + nil。generation 递增用于竞态防护。

#### refresh（L293-L316）
- **L294** `guard !isPaused, refreshTask == nil`：防止并发刷新。
- **L296-L297** 捕获 sampler 与 generation 快照。
- **L298-L315** `Task { @MainActor [weak self] in ... }`：
  - **L299-L301** detached 采样。
  - **L303** guard self。
  - **L304** `guard generation == refreshGeneration`：若期间有新 refresh 或 cancel（generation 变化），丢弃本次结果。**竞态防护核心，设计优秀**。
  - **L305** 清除 refreshTask。
  - **L306** `guard !Task.isCancelled, !isPaused`：双重检查。
  - **L308-L314** 应用可见应用摘要、设置 snapshot、追加历史、trim、持久化、重载 widget。
- 并发模型设计严谨。

#### 历史追加与裁剪（L318-L332）
- **L318-L326** `appendHistorySnapshot`：
  - **L319-L323** 若当前仅占位单元素，先移除。`isPlaceholderHistorySnapshot` 判断。正确。
  - **L325** 追加净化版。`recentSnapshots` 始终存净化版，而 `snapshot`（当前）存完整版。设计合理——当前显示富数据，历史只存趋势必需字段。
- **L328-L332** `trimHistoryIfNeeded`：超出 depth 则 removeFirst。正确。

#### 持久化与占位判断（L334-L365）
- **L334-L355** `persistHistoryIfNeeded`：
  - **L335-L339** 非 force 时 15s 节流。降低磁盘 IO。
  - **L341** 更新 lastPersistenceDate。
  - **L342-L345** sanitize + filter 占位 + suffix(limit)。
  - **L347-L350** 空则移除 key。
  - **L352-L354** `try?` 编码失败静默跳过。可接受（历史非关键数据）。
- **L357-L365** `isPlaceholderHistorySnapshot`：多字段零/空判断。良好启发式。

#### Widget 重载（L367-L378）
- **L367-L378** `reloadWidgetsIfNeeded`：60s 节流，`WidgetCenter.shared.reloadTimelines(ofKind:)`。WidgetKit 最佳实践是减少重载，60s 间隔合理。

#### 可见应用摘要（L380-L416）
- **L380-L381** guard `processCount == 0 && topProcesses.isEmpty`：仅当 sampler 未提供时填充。避免覆盖 sampler 数据。
- **L383-L384** `NSWorkspace.shared.runningApplications.filter{ !$0.isTerminated }`。
- **L386-L389** 设置 processCount/active/hidden 计数 + `hasRunningAppCountReport = true`。
- **L391-L402** 排序：active 优先 → 非 hidden → 名称升序。`localizedStandardCompare` 本地化排序。良好。
- **L404** `.prefix(8)`：限制 8 个。合理。
- **L406-L414** 构造 `ProcessMetric`：
  - **L413** `application.executableArchitecture`（Int），传给 `processArchitectureText`。该 API 自 10.6 可用，当前未弃用。测试也确认使用此 API。
  - **L412** `launchDate`：可选，直接传入。

#### 架构文本辅助（L418-L447）
- **L418-L421** `reportedApplicationName`：trim + 空则“未报告”。良好。
- **L423-L434** `activationPolicyText`：含 `@unknown default`。良好——面向未来兼容。
- **L436-L447** `processArchitectureText`：`cpu_type_t(architecture)` 转换，匹配 ARM64/X86_64/I386，default nil。良好。

---

### VisualEffectView.swift（21 行）

- **L3-L21** `NSViewRepresentable` 封装 `NSVisualEffectView`。默认 `.hudWindow` / `.behindWindow` / `.active`。`makeNSView` 创建并配置，`updateNSView` 在 SwiftUI 更新时同步属性。标准实现，良好。
- **注意**：未设置 `view.wantsLayer` 或自动布局约束，SwiftUI 通过 NSHostingView 管理尺寸，无需手动处理。正确。

---

### WidgetPanelView.swift（350 行）

#### 布局常量与入口（L1-L30）
- **L6-L11** `MenuPopoverLayout`：width 356 / height 520 / minimumHeight 420 / screenMargin 12。集中常量。良好。
- **L13-L30** `WidgetPanelView`：`@ObservedObject store` + popoverHeight + 三个闭包。body 委托 `MenuPopoverPreview`。良好。

#### MenuPopoverPreview（L32-L193）
- **L33** `@Environment(\.colorScheme)`。
- **L41-L111** body：VStack(header, ScrollView, actions)。
  - **L48** `ScrollView(showsIndicators: false)`：隐藏滚动指示器， popover 紧凑视觉。良好。
  - **L49-L77** 内容：4 PopoverMetricRow + 3+3+2 PopoverSmallStat。
  - **L79-L92** 三个 Button(.plain) 动作。
  - **L94** `frame(width: 356, height: popoverHeight, alignment: .topLeading)`。
  - **L95-L104** 背景 VisualEffectView + 渐变。
  - **L105-L109** clipShape + overlay 描边。
  - **L110** shadow。
- **L113-L142** header：图标 + 标题 + 采样时间 + 暂停/实时状态胶囊。良好。
- **L144-L146** `normalizedRate(_:)`：baseline 40M。
  - **重复**：DashboardView.swift L1792 有同名不同签名函数（带 baseline 参数）。均 private，无冲突但重复。
- **L148-L151** `reportedProgress`：与 DashboardView L1797 重复。
- **L153-L156** `reportedTint`：
  - **命名反直觉**：`guard hasReport else { return Palette.cyan }`——未报告返回 cyan，报告则返回 fallback。函数名“reportedTint”暗示“已报告时的色调”，实际返回的是 fallback。建议改名为 `tintOrUnavailable` 或注释说明。
- **L158-L169** `powerTint`：与 DashboardView `powerTint`（L1912）逻辑重复。
- **L171-L179** `thermalTint`：字符串匹配，与 DashboardView `thermalStatus`（L1957）映射重复（返回 Color vs StatusLevel）。
- **L181-L192** `networkTint`：与 DashboardView `networkStatusColor`（L1884）重复。

#### 子视图（L195-L292）
- **L195-L243** `PopoverMetricRow`：标题+详情+值 + GeometryReader 进度条。
  - **L229** `progressFillWidth`——与 DashboardView L1802 重复定义。
  - **L236** `minHeight: 52`。
  - **无障碍性**：未添加 accessibility 修饰。建议补充 accessibilityLabel/Value。
- **L245-L271** `PopoverSmallStat`：圆点+标题+值。`minHeight: 60`。无显式可访问性。
- **L273-L292** `PopoverActionLabel`：图标+文字胶囊。无显式可访问性（Button 自带，但内容未组合标注）。

#### 颜色辅助（L294-L350）
- **L294-L336** 一组 `popover*` 颜色函数：背景/面板填充/描边/主文字/次文字/轨道/色调填充/阴影。暗/亮色分支完整。良好。
- **L338-L342** `progressFillWidth`：第三处定义（前两处 DashboardView L1802、本文件 L229 调用此版）。private 重复。
- **L344-L350** `Palette`：blue/green/amber/cyan/red。
  - **重复**：颜色值与 DashboardView `DashboardColor`（L145-L150）完全相同。可提取共享。

---

## 问题汇总

### Bug 级（必须修）

| # | 文件:行号 | 问题 | 严重度 | 建议 |
|---|-----------|------|--------|------|
| 1 | AppDelegate.swift:54-56 | `DispatchQueue.main.async` 闭包（@Sendable 非 @MainActor）调用 `@MainActor` 方法 `store.start()`，违反 Swift 并发隔离。Swift 5 普通模式可能仅告警，Swift 6 严格模式报错。 | 高 | 改为 `Task { @MainActor in store.start() }`，或直接同步调用（已在主 actor）。 |
| 2 | MetricsStore.swift:(无 deinit) | 类无 `deinit`，若对象释放前未调用 `stop()`，`timer` 被 run loop 持有不会失效（闭包 weak self 不泄漏 self 但 Timer 对象泄漏）。当前进程级生命周期不触发，但测试/重构会暴露。 | 中 | 添加 `deinit { timer?.invalidate(); initialRefreshTask?.cancel(); refreshTask?.cancel() }`。 |
| 3 | AppDelegate.swift:314,404 | 每次打开 popover 都新建 `NSHostingController`（最多一次打开创建 2 个），重建整个 SwiftUI 视图树，丢失潜在本地 @State 且浪费性能。 | 中 | 复用 `statusHostingController`，仅更新 `preferredContentSize` 与 `view.frame`；或缓存按高度分组的 controller。 |
| 4 | AppDelegate.swift:266 | `updateStatusButtonTitle` 在 `cpuText` 为“未报告”时仍设置标题为“ 未报告”并使用 cpuTitleLength=72，菜单栏显示异常文本。 | 中 | 仅在 `store.snapshot.hasCPUUsageReport` 为 true 时显示文字并切换长度，否则恢复 compactLength + 空标题。 |

### 质量级（建议修）

| # | 文件:行号 | 问题 | 严重度 | 建议 |
|---|-----------|------|--------|------|
| 5 | AppDelegate.swift:92-93 | `settingsItem.keyEquivalent = ","` 重复赋值（init 已设）。 | 低 | 删除 L93 冗余行。 |
| 6 | AppDelegate.swift:311,336 | `statusPopoverVisibleFrame(for:)` 在 `prepareStatusPopover` 内被调用两次（L311 直接调、L336 经 `statusPopoverPlacement` 间接调）。 | 低 | 将 visibleFrame 作为参数传入 `statusPopoverPlacement`。 |
| 7 | AppDelegate.swift:222-232 | `store.$snapshot` 与 `store.$showsMenuBarCPU` 两个独立 sink 均调用 `updateStatusButtonTitle`，每次 snapshot tick 触发一次。 | 低 | 用 `CombineLatest` 合并为单个订阅。 |
| 8 | AppDelegate.swift:67 | `applicationShouldHandleReopen` 的 `hasVisibleWindows flag` 参数未使用，始终显示窗口。 | 低 | 可改为 `_ flag` 或在 `flag` 为 true 时跳过；保留当前行为则加注释说明。 |
| 9 | DashboardView.swift:1605-1629 | `SettingRow` 视图为死代码，全项目未使用（测试亦断言不使用）。 | 低 | 删除 `SettingRow` 结构体。 |
| 10 | DashboardView.swift:896 | `SettingReadOnlyRow` 的 `control: "5m"` 为硬编码字符串，与实际 WidgetKit 时间线间隔无关联。 | 低 | 提取为常量或从配置/注释说明来源。 |
| 11 | DashboardView.swift:744 | `ProcessesPage` 内 `ForEach(snapshot.topProcesses.filter(\.hasInventoryReport))` 无 prefix 限制，与 `ProcessListPanel`（L1071 prefix(6)）不一致。 | 低 | 加 `.prefix(8)` 或与 ProcessListPanel 统一。 |
| 12 | WidgetPanelView.swift:153-156 | `reportedTint` 命名反直觉：未报告返回 cyan，报告返回 fallback。 | 低 | 改名 `tintOrUnavailable` 或 `reportedTint(fallback:unusedTint:)` 并注释。 |
| 13 | WidgetPanelView.swift:195-243,245-271 | `PopoverMetricRow`/`PopoverSmallStat` 未添加可访问性修饰（MetricCard/RingGauge 有）。 | 低 | 补充 `accessibilityElement(children:.combine)` + label/value。 |
| 14 | DashboardView.swift:1032-1060,1528-1560 | `SummaryCard`/`SourceCapabilityCard` 无可访问性组合修饰。 | 低 | 补充 accessibilityLabel/Value。 |
| 15 | AppDelegate.swift:197 | DashboardView 用 `@ObservedObject` 持有 store/router，若 NSHostingView 被重建会丢失绑定（当前不重建，安全但脆弱）。 | 低 | 可在注释标注“hostingView 不可重建”约束，或改用环境注入。 |
| 16 | MetricsStore.swift:251-252 | 历史快照 `osVersion`/`kernelRelease` 统一取 `placeholder` 值，系统升级后旧历史显示新版本字符串。 | 低 | 历史已剥离这些字段作展示，可接受；或在 sanitized 中置 nil 而非 placeholder。 |

### 整洁级（可后续）

| # | 文件:行号 | 问题 | 严重度 | 建议 |
|---|-----------|------|--------|------|
| 17 | WidgetPanelView.swift:338 与 DashboardView.swift:1802 | `progressFillWidth` 在两文件各定义一份（均 private）。 | 低 | 提取到 SharedMetrics 共享工具函数。 |
| 18 | WidgetPanelView.swift:144-146 与 DashboardView.swift:1792 | `normalizedRate` 两处定义（签名不同）。 | 低 | 统一为带 baseline 参数版本并共享。 |
| 19 | WidgetPanelView.swift:148-151 与 DashboardView.swift:1797 | `reportedProgress` 两处重复。 | 低 | 提取共享。 |
| 20 | WidgetPanelView.swift:171-179 与 DashboardView.swift:1957 | `thermalTint` 与 `thermalStatus` 映射逻辑重复（Color vs StatusLevel）。 | 低 | 统一为 StatusLevel + `.color` 访问。 |
| 21 | WidgetPanelView.swift:181-192 与 DashboardView.swift:1871 | `networkTint` 与 `networkStatusLevel` 重复。 | 低 | 同上，统一。 |
| 22 | WidgetPanelView.swift:344-350 与 DashboardView.swift:145-150 | `Palette` 与 `DashboardColor` 颜色值完全相同。 | 低 | 提取共享 Palette 类型。 |
| 23 | DashboardView.swift:1712 | `TableHeader` 的 `ForEach(columns, id: \.self)` 用 String 作 id，列名重复时冲突。 | 低 | 改用 `id: \.self` + 唯一性约束，或用 enumerated id。 |
| 24 | DashboardView.swift:1421,1445 | `MemorySegmentBar`/`CapacityBar` 每段 `max(width, 8)` 最小宽度，窄面板可能溢出（虽有 clipShape 裁剪）。 | 低 | 可用比例分配替代固定最小值，或减小最小值。 |
| 25 | DashboardView.swift:434 | `ForEach(Array(cpuCoreUsages.enumerated()), id: \.offset)` 用 offset 作 id，核心数变化时 diff 错位（极罕见）。 | 低 | 可用 `CoreUsage(index:)` 包装 Identifiable 类型。 |
| 26 | main.swift:4 | `delegate` 顶层常量靠作用域存活，`app.delegate` 为 weak，模式脆弱。 | 低 | 加注释“顶层强引用不可移除”，或用强引用 holder。 |
| 27 | AppDelegate.swift:140 | View 菜单“打开设置”无快捷键，App 菜单“设置”为 ⌘,，两入口快捷键不对齐。 | 低 | 可统一或保留差异并注释。 |

---

## 亮点（做得好的部分）

1. **并发竞态防护**（MetricsStore.swift L288-L306）：`refreshGeneration` 机制配合 `guard generation == refreshGeneration` 优雅防止过期采样覆盖新数据，cancel 时递增 generation 使在途 Task 自动作废。设计专业。
2. **采样卸载到后台**（MetricsStore.swift L272-L274, L299-L301）：`Task.detached(priority:.userInitiated)` 执行 `sampler.sample()`，避免 CPU 密集采样阻塞主 actor，结果通过 `.value` 回主线程。正确运用 Swift 并发。
3. **菜单栏 popover 几何**（AppDelegate.swift L309-L397）：结合 `MenuBarPopoverGeometry`（SharedMetrics）做屏幕可见区域约束、高度迭代收敛、锚点居中偏移，并配合 alpha 隐藏防闪烁。处理了窄屏、多屏、状态栏/普通窗口等边界。
4. **可访问性**（DashboardView.swift MetricCard L1025-L1028, RingGauge L1202-L1204, Sparkline L1272-L1273, StatusDot L1773）：关键控件有 accessibilityLabel/Value/Hint，装饰元素 accessibilityHidden。超出多数 macOS 应用水平。
5. **菜单完整性**（AppDelegate.swift L85-L155）：App/Edit/View/Window 四级菜单齐全，About 面板读 Bundle 版本，Services 菜单挂载，退出 ⌘Q，`applicationSupportsSecureRestorableState` 返回 true。完全符合 App Store 上架要求。
6. **历史数据净化**（MetricsStore.swift L190-L255）：`sanitizedHistorySnapshot` 剥离大体积集合与易变字段后再持久化，显著降低 UserDefaults 存储体积，15s 节流写入。工程考量到位。
7. **Sparkline 用 Canvas**（DashboardView.swift L1237）：趋势图用 Canvas 而非 Path/Shape 堆叠，单次绘制性能好，suffix(80) 限制点数。良好性能选择。
8. **资源清理**（AppDelegate.swift L59-L65）：`applicationWillTerminate` 调用 `store.stop()` 持久化并取消定时器，移除状态项。退出行为干净。
9. **暂停恢复网络基线重置**（MetricsStore.swift L110）：`togglePause` 恢复时 `sampler.resetNetworkBaselines()`，避免暂停期间字节计数累积导致恢复瞬间流量假尖峰。细节考究。
10. **窗口位置持久化**（AppDelegate.swift L194）：`setFrameAutosaveName` 自动保存/恢复窗口位置尺寸，提升用户体验。

---

## 模块整体评价

SystemDashboardApp 模块作为 Pulse Dock 的主应用层，整体工程质量**较高**，体现了对 AppKit 生命周期、SwiftUI 性能、Swift 并发模型的扎实理解。并发设计（generation 防竞态、detached 采样、Task 取消）与 popover 几何约束处理尤为出色，可访问性投入超出同类应用平均水平。App Store 合规性（菜单、About、退出、安全可恢复状态）已满足。

**上架前需优先处理的 4 个 Bug 级问题**：
1. `DispatchQueue.main.async` 跨 actor 调用（并发合规，影响 Swift 6 迁移）；
2. MetricsStore 缺 deinit（测试/重构健壮性）；
3. popover hostingController 重复创建（性能+未来状态丢失风险）；
4. 菜单栏“未报告”异常文本（用户可见 UX 瑕疵）。

**建议后续清理**：跨文件重复的工具函数（progressFillWidth/normalizedRate/reportedProgress/thermal/network 映射/Palette 颜色）应提取到 SharedMetrics 共享，当前三处重复定义虽 private 无冲突但增加维护成本。死代码 `SettingRow` 应删除。

整体判断：**修复 4 个 Bug 级问题后即可上架**，质量级与整洁级问题可在后续迭代中逐步收敛。
