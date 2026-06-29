# R2 — 代码重复专项报告

审查范围：`PulseDockApp`（主 App target）、`PulseDockWidget`（Widget Extension target）、`SharedMetrics`（两者共同依赖的共享模块）。
审查方法：提取三个文件中的全部 `private func` / 文件级 `func`，比对签名与实现逐行；提取颜色/布局/文案常量跨文件比对；评估合并可行性（App↔Widget 不能直接互依赖，但二者均可依赖 `SharedMetrics`）。

---

## 一、重复函数矩阵

| 函数名 | 位置1 | 位置2 | 位置3 | 实现差异 | 合并可行性 |
|--------|-------|-------|-------|---------|-----------|
| `normalizedRate(_ bytesPerSecond: UInt64) -> Double` | DashboardView.swift:2148 | WidgetPanelView.swift:132 | —（SystemDashboardWidget 直接内联 `MetricScales.networkRateProgress`） | 完全相同（均为 `MetricScales.networkRateProgress(bytesPerSecond:)` 单行包装） | 可移除包装，调用方直接使用 `MetricScales.networkRateProgress` |
| `reportedProgress(hasReport:progress:) -> Double?` | DashboardView.swift:2152 | WidgetPanelView.swift:136 | SystemDashboardWidget.swift:771 | 三处逐行完全相同 | 可提取到 `SharedMetrics`（纯逻辑，无 UI 依赖） |
| `progressFillWidth(_:in:minimumVisibleWidth:) -> CGFloat` | DashboardView.swift:2157 | WidgetPanelView.swift:311 | SystemDashboardWidget.swift:776 | 三处逐行完全相同，均依赖 `MetricScales.clampedProgress` | 可提取到 `SharedMetrics`（依赖 `MetricScales` 已在共享模块） |
| `reportedTint(hasReport:fallback:) -> Color` | WidgetPanelView.swift:141 | SystemDashboardWidget.swift:783 | — | 签名不同（widget 侧多 `for colorScheme:` 参数）；fallback 取色源不同（Palette vs WidgetColor）；逻辑相同 | 需保留色源差异，可提取逻辑骨架到共享扩展，颜色由调用方注入 |
| `powerTint(_ snapshot: MetricSnapshot) -> Color` | DashboardView.swift:2276 | WidgetPanelView.swift:146 | SystemDashboardWidget.swift:788 | 逻辑完全相同（switch `powerStatusTone` 四分支），仅色源枚举名不同（`DashboardColor.green` vs `Palette.green(for:)` vs `WidgetColor.green(for:)`） | 可提取到 `SharedMetrics`：返回 `MetricStatusTone`，由调用方映射为颜色；或将颜色映射表注入 |
| `thermalTint(_ state: String) -> Color` | WidgetPanelView.swift:159 | SystemDashboardWidget.swift:736 | —（DashboardView 用 `thermalStatus(_:).color` 间接得到） | 逻辑相同（critical/hot→red, warm→amber, nominal→green, unknown→cyan），仅色源不同 | 可提取 `ThermalState → MetricStatusTone` 映射到 `SharedMetrics`，颜色由调用方注入 |
| `networkTint(_ snapshot: MetricSnapshot) -> Color` | WidgetPanelView.swift:168 | SystemDashboardWidget.swift:745 | —（DashboardView 用 `networkStatusLevel(_:).color` 间接得到） | 逻辑相同（satisfied→green, requiresConnection→amber, unsatisfied→red, unknown→cyan），仅色源不同 | 可提取 `NetworkPathState → MetricStatusTone` 映射到 `SharedMetrics` |
| `networkPathProgress(_ snapshot: MetricSnapshot) -> Double` | DashboardView.swift:2252 | SystemDashboardWidget.swift:758 | — | 两处逐行完全相同（satisfied→1, requiresConnection→0.45, unsatisfied→0, unknown→0） | 可提取到 `SharedMetrics`（纯逻辑） |

> 说明：任务锚点 R2-1 称 `normalizedRate` 在「三处」，实际 `SystemDashboardWidget.swift` **未定义** `normalizedRate` 私有函数（已用 `grep "func normalizedRate"` 全仓验证，仅 2 处定义）。`SystemDashboardWidget.swift:771-776` 对应的是 `reportedProgress` 与 `progressFillWidth`，已在上表分别列出。

---

## 二、重复常量/枚举矩阵

| 常量/枚举 | 位置1 | 位置2 | 位置3 | 值差异 | 合并可行性 |
|-----------|-------|-------|-------|-------|-----------|
| `green` | DashboardColor.green (DashboardVisualTokens.swift:61) `0.04,0.62,0.39` | Palette.green (WidgetPanelView.swift:323) light `0.04,0.62,0.39` / dark `0.26,0.82,0.58` | WidgetColor.green (WidgetVisualTokens.swift:44) light `0.04,0.62,0.39` / dark `0.24,0.82,0.62` | light 完全一致；dark 中 Palette 与 WidgetColor 的 R/B 分量略不同（0.26/0.58 vs 0.24/0.62） | 可统一：DashboardColor 无 dark 变体，应升级为 `for colorScheme`；三者 dark 值需先对齐 |
| `blue` | DashboardColor.blue `0.14,0.43,0.95` | Palette.blue light `0.14,0.43,0.95` / dark `0.42,0.66,1.00` | WidgetColor.blue light `0.14,0.43,0.95` / dark `0.36,0.62,1.00` | light 一致；dark Palette `0.42,0.66` vs WidgetColor `0.36,0.62` 不同 | 同上 |
| `amber` | DashboardColor.amber `0.93,0.54,0.10` | Palette.amber light `0.93,0.54,0.10` / dark `1.00,0.70,0.30` | WidgetColor.amber light `0.93,0.54,0.10` / dark `1.00,0.68,0.28` | light 一致；dark G/B 分量 0.70/0.30 vs 0.68/0.28 不同 | 同上 |
| `cyan` | DashboardColor.cyan `0.04,0.56,0.70` | Palette.cyan light `0.04,0.56,0.70` / dark `0.24,0.76,0.86` | WidgetColor.cyan light `0.04,0.56,0.70` / dark `0.29,0.78,0.88` | light 一致；dark 不同 | 同上 |
| `red` | DashboardColor.red `0.84,0.16,0.16` | Palette.red light `0.84,0.16,0.16` / dark `1.00,0.38,0.36` | WidgetColor.red light `0.84,0.16,0.16` / dark `1.00,0.42,0.42` | light 一致；dark G/B 0.38/0.36 vs 0.42/0.42 不同 | 同上 |
| `purple` | DashboardColor.purple `0.48,0.34,0.88` | —（Palette/WidgetColor 无 purple） | — | 仅 App 侧定义 | 无重复，但 Widget 若需紫色需新增，建议同步进共享 tokens |
| `muted` / `border` / `canvas` / `panel` | DashboardColor (DashboardVisualTokens.swift:54-59) | — | — | 仅 App 侧，使用 `NSColor` 语义色 | 无直接重复 |
| 文本/面板/轨道填充色 | popoverPrimaryText (WidgetPanelView.swift:295) `white.0.92 / .primary` | widgetPrimaryText (WidgetVisualTokens.swift:85) `white.0.92 / .primary` | popoverSecondaryText (WidgetPanelView.swift:299) `white.0.62 / .secondary` == widgetSecondaryText (WidgetVisualTokens.swift:89) | primary/secondary 文本色**逐字节相同**；popoverTrackFill (0.11/0.13) 与 widgetTrackFill (0.14/0.14) opacity 略不同 | 可合并为单一 `WidgetSurfaceToken` 系列，popover 与 widget 共用 |
| `localized(_:defaultValue:bundle:)` | PulseDockAppStrings.swift:1338 (table "PulseDockApp") | SharedMetricStrings.swift:391 (table "SharedMetrics") | PulseDockWidgetStrings.swift:116 (table "PulseDockWidget") | 实现体完全相同：`bundle.localizedString(forKey:value:table:)`，仅默认 bundle 与 table 名不同 | 实现可提取到 `SharedMetrics` 公共 helper，各 Strings 表只保留 `table` 常量与默认 bundle 注入 |
| `localizedFormat(_:defaultValue:_:)` | PulseDockAppStrings.swift:1346 | SharedMetricStrings.swift:399 | —（WidgetStrings 无此 helper） | 两处逐行完全相同 | 可合并进上述公共 helper |
| "Not reported" 文案 | PulseDockAppStrings.notReported (PulseDockAppStrings.swift:1070) key `app.not_reported` | SharedMetricStrings.notReported (SharedMetricStrings.swift:4) key `shared_metrics.not_reported` | PulseDockWidgetStrings.notReported (PulseDockWidgetStrings.swift:88) key `widget.not_reported` | 默认值均为 `"Not reported"`；三套 key、三套 bundle | App 与 Widget 可复用 `SharedMetricStrings.notReported`，去掉各自的 `notReported`（仅保留 App 专属 `systemDidNotReport` 等变体） |

---

## 三、代码重复发现

### 重复 R2-1: `reportedProgress(hasReport:progress:)` 三处完全相同
- **位置1**: DashboardView.swift:2152-2155 — `guard hasReport else { return nil }; return progress`
- **位置2**: WidgetPanelView.swift:136-139 — 同上
- **位置3**: SystemDashboardWidget.swift:771-774 — 同上
- **重复描述**: 三处独立维护同一「有报告则返回进度，否则 nil」的纯逻辑函数。
- **实现差异**: 完全相同（逐字符）。
- **合并可行性**: 可提取到 `SharedMetrics`（无 SwiftUI 依赖，仅 `Double`/`Bool`）。
- **风险**: rename `hasReport` 语义或调整 nil 策略时，三处可能静默分歧。
- **建议**: 在 `MetricScales` 或新建 `MetricPresentation` 中提供 `public static func reportedProgress(hasReport: Bool, progress: Double) -> Double?`，三处调用方删除本地定义。
- **优先级**: R-高

### 重复 R2-2: `progressFillWidth(_:in:minimumVisibleWidth:)` 三处完全相同
- **位置1**: DashboardView.swift:2157-2162
- **位置2**: WidgetPanelView.swift:311-316
- **位置3**: SystemDashboardWidget.swift:776-781
- **重复描述**: 三处独立实现「进度→填充宽度」计算，均依赖 `MetricScales.clampedProgress`。
- **实现差异**: 完全相同。
- **合并可行性**: 可提取到 `SharedMetrics`（仅依赖 `MetricScales` + `CoreGraphics`，后者可通过 `CGFloat` 在 Foundation 上可用）。
- **风险**: 最小可见宽度策略变更时三处分歧。
- **建议**: 提取为 `MetricScales.fillWidth(_:in:minimumVisibleWidth:)`。
- **优先级**: R-高

### 重复 R2-3: `normalizedRate(_:)` 两处包装（锚点修正）
- **位置1**: DashboardView.swift:2148-2150 — `MetricScales.networkRateProgress(bytesPerSecond: bytesPerSecond)`
- **位置2**: WidgetPanelView.swift:132-134 — 同上
- **重复描述**: 两处均为对 `MetricScales.networkRateProgress` 的零附加值包装函数。
- **实现差异**: 完全相同。
- **合并可行性**: 直接删除包装，调用方使用 `MetricScales.networkRateProgress(bytesPerSecond:)`。
- **风险**: 包装层无附加价值，徒增维护点。
- **建议**: 移除两处 `normalizedRate`，调用点改为直接调用 `MetricScales.networkRateProgress`。`networkTrendValues` 内部亦可直接用共享 API。
- **优先级**: R-中
- **注**: 任务锚点 R2-1 称「三处」，实际 `SystemDashboardWidget.swift` 未定义此函数（已 grep 验证），故修正为两处。

### 重复 R2-4: `powerTint(_:)` 三处仅色源不同
- **位置1**: DashboardView.swift:2276-2287 — switch `powerStatusTone` → `DashboardColor.green/amber/red/cyan`
- **位置2**: WidgetPanelView.swift:146-157 — 同结构 → `Palette.green(for:)/amber/red/cyan`
- **位置3**: SystemDashboardWidget.swift:788-799 — 同结构 → `WidgetColor.green(for:)/amber/red/cyan`
- **重复描述**: 三处独立维护 `MetricStatusTone → Color` 映射，分支结构与语义完全一致。
- **实现差异**: 仅色源枚举名不同；`MetricStatusTone` 已在 `SharedMetrics` 中定义。
- **合并可行性**: 可在 `SharedMetrics` 提供 `MetricStatusTone` 的语义映射骨架（如返回 `enum AccentColor { case green, amber, red, cyan }`），由各 target 提供 `AccentColor → Color` 表；或直接让 `MetricSnapshot` 暴露 `powerStatusTone`（已存在），调用方各自 switch。
- **风险**: 新增 tone 分支时三处可能遗漏。
- **建议**: 短期保留各 target 颜色表，但将 switch 收敛为单一 `tone → accent` 函数；长期统一颜色 tokens（见 R2-9）。
- **优先级**: R-中

### 重复 R2-5: `thermalTint(_:)` 两处仅色源不同
- **位置1**: WidgetPanelView.swift:159-166
- **位置2**: SystemDashboardWidget.swift:736-743
- **重复描述**: `ThermalState → Color` 映射，两处分支完全一致（critical/hot→red, warm→amber, nominal→green, unknown→cyan）。
- **实现差异**: 仅色源（Palette vs WidgetColor）。
- **合并可行性**: 与 R2-4 同策略。`ThermalState` 已在 `SharedMetrics`。
- **风险**: 同 R2-4。
- **建议**: 统一进 `ThermalState` 的 `metricStatusTone` 计算属性（见 R2-17）。
- **优先级**: R-中

### 重复 R2-6: `networkTint(_:)` 两处仅色源不同
- **位置1**: WidgetPanelView.swift:168-179
- **位置2**: SystemDashboardWidget.swift:745-756
- **重复描述**: `NetworkPathState → Color` 映射，两处分支完全一致。
- **实现差异**: 仅色源。
- **合并可行性**: `NetworkPathState` 已在 `SharedMetrics`，可加 `metricStatusTone` 计算属性。
- **风险**: 同 R2-4。
- **建议**: 在 `NetworkPathState` 上加 `var metricStatusTone: MetricStatusTone`，调用方统一 `tone.color`。
- **优先级**: R-中

### 重复 R2-7: `networkPathProgress(_:)` 两处完全相同
- **位置1**: DashboardView.swift:2252-2263
- **位置2**: SystemDashboardWidget.swift:758-769
- **重复描述**: `NetworkPathState → Double` 进度映射，两处逐行相同（satisfied→1, requiresConnection→0.45, unsatisfied→0, unknown→0）。
- **实现差异**: 完全相同。
- **合并可行性**: 可作为 `NetworkPathState` 的 `var progress: Double` 计算属性加入 `SharedMetrics`。
- **风险**: 0.45 这个魔法数两处独立维护。
- **建议**: 移入 `NetworkPathState.progress`。
- **优先级**: R-高

### 重复 R2-8: `reportedTint(hasReport:fallback:)` 两处签名略不同
- **位置1**: WidgetPanelView.swift:141-144 — `reportedTint(hasReport:fallback:) -> Color`（colorScheme 来自环境）
- **位置2**: SystemDashboardWidget.swift:783-786 — `reportedTint(hasReport:fallback:for colorScheme:) -> Color`
- **重复描述**: 同一「无报告则用 cyan 作 fallback，否则用传入色」逻辑。
- **实现差异**: 签名差异（widget 显式传 colorScheme）；色源不同（Palette.cyan vs WidgetColor.cyan）。
- **合并可行性**: 与 R2-4 同策略，统一进 `MetricStatusTone` 体系。
- **风险**: 低。
- **建议**: 统一颜色 tokens 后可合并。
- **优先级**: R-低

### 重复 R2-9: 三套颜色 tokens（DashboardColor / Palette / WidgetColor）
- **位置1**: DashboardColor — DashboardVisualTokens.swift:53-66（无 dark 变体，单值）
- **位置2**: Palette — WidgetPanelView.swift:318-337（light + dark）
- **位置3**: WidgetColor — WidgetVisualTokens.swift:39-59（light + dark）
- **重复描述**: 三套语义颜色表（green/blue/amber/red/cyan）并存。
- **实现差异**: **light 模式 RGB 三处完全一致**；dark 模式 Palette 与 WidgetColor 的 green/blue/amber/cyan/red 的 R/G/B 分量均有微小差异（如 green dark：Palette `0.26,0.82,0.58` vs WidgetColor `0.24,0.82,0.62`）；DashboardColor 完全没有 dark 变体（App 窗口在 dark 下复用 light 单值，与 Widget/Popover 的 dark 表现不一致）。
- **合并可行性**: App 与 Widget 均可依赖 `SharedMetrics`。可在 `SharedMetrics` 新建 `enum MetricAccent { static func green(for:) ... }`，三处调用方替换。需先对齐 dark 值（决策：以哪套为准）。
- **风险**: 当前 dark 下 App 主窗口与 Widget/Popover 的强调色肉眼可辨不一致；任一处调色其他两处不会跟随。
- **建议**: 高优先级统一。先冻结 dark 值（建议采用 WidgetColor 的值，因 Widget 在 dark 下更频繁展示），再迁移 DashboardColor 与 Palette 到共享 tokens，并给 DashboardColor 补 dark 分支。
- **优先级**: R-高

### 重复 R2-10: 文本/面板/轨道表面色 helper 重复
- **位置1**: popoverPrimaryText/popoverSecondaryText/popoverPanelFill/popoverPanelStroke/popoverTrackFill/popoverTintFill — WidgetPanelView.swift:287-309
- **位置2**: widgetPrimaryText/widgetSecondaryText/widgetPanelFill/widgetPanelStroke/widgetTrackFill/widgetPlaceholderFill — WidgetVisualTokens.swift:77-99
- **重复描述**: 「popover 表面色」与「widget 表面色」两组 helper 并存，语义高度重叠。
- **实现差异**: primary/secondary 文本色**逐字节相同**（`white.opacity(0.92)` dark / `Color.primary` light；`white.opacity(0.62)` dark / `Color.secondary` light）；panelFill/Stroke/TrackFill 的 opacity 有微小数值差异（popover panelFill dark `0.58` vs widget `0.08` — 实际差异较大；popoverTrackFill `0.11/0.13` vs widgetTrackFill `0.14/0.14`）。
- **合并可行性**: WidgetPanelView 属 App target，可调用 `SharedMetrics` 或 widget tokens 模块；但 widget tokens 当前在 Widget target，App 不能依赖。需将 tokens 上移到 `SharedMetrics` 或新建 `SharedUI` 模块。
- **风险**: 同一「卡片背景」在 popover 与 widget 下数值不同，视觉不一致。
- **建议**: 将表面色 tokens 上移到 `SharedMetrics`（或新建 `SharedSurfaceTokens`），popover 与 widget 共用；数值差异若是刻意则保留为两个语义命名（如 `surfaceCard` vs `surfaceWidget`）。
- **优先级**: R-中

### 重复 R2-11: "Not reported" 文案三套 strings
- **位置1**: PulseDockAppStrings.notReported — PulseDockAppStrings.swift:1070（key `app.not_reported`）
- **位置2**: SharedMetricStrings.notReported — SharedMetricStrings.swift:4（key `shared_metrics.not_reported`）
- **位置3**: PulseDockWidgetStrings.notReported — PulseDockWidgetStrings.swift:88（key `widget.not_reported`）
- **重复描述**: 同一「Not reported」默认值在三个 strings 表各维护一份。
- **实现差异**: key 前缀不同，默认值均为 `"Not reported"`。
- **合并可行性**: App 与 Widget 均可依赖 `SharedMetricStrings`。App/Widget 的 `notReported` 可直接复用 `SharedMetricStrings.notReported`，删除本地定义。
- **风险**: 翻译时同一字符串在三处分别维护，可能译文不一致。
- **建议**: App 与 Widget 的 `notReported` 改为 `SharedMetricStrings.notReported` 的 typealias 或直接调用；仅保留 App 专属变体（如 `systemDidNotReport`）。
- **优先级**: R-中

### 重复 R2-12: `localized(_:defaultValue:bundle:)` 三处实现相同
- **位置1**: PulseDockAppStrings.swift:1338-1344（table "PulseDockApp"）
- **位置2**: SharedMetricStrings.swift:391-397（table "SharedMetrics"）
- **位置3**: PulseDockWidgetStrings.swift:116-122（table "PulseDockWidget"）
- **重复描述**: 同一 `bundle.localizedString(forKey:value:table:)` 包装在三处独立实现。
- **实现差异**: 仅默认 bundle 与 table 名不同。
- **合并可行性**: 可在 `SharedMetrics` 提供 `public func localizedString(_ key:defaultValue:table:bundle:)`，三处 Strings 表改为调用并注入各自 table/bundle。
- **风险**: 低（实现简单），但三处独立维护无收益。
- **建议**: 提取公共 helper。
- **优先级**: R-低

### 重复 R2-13: `localizedFormat(_:defaultValue:_:)` 两处相同
- **位置1**: PulseDockAppStrings.swift:1346-1352
- **位置2**: SharedMetricStrings.swift:399-405
- **重复描述**: `String(format:localized(...),locale:Locale.current,arguments:)` 包装重复。
- **实现差异**: 完全相同。
- **合并可行性**: 随 R2-12 一并提取。
- **风险**: 低。
- **建议**: 与 R2-12 合并提取。
- **优先级**: R-低

### 重复 R2-14: StatusDot 与多处内联「圆点」组件
- **位置1**: StatusDot — DashboardView.swift:2122-2132（`Circle().fill(color).frame(7x7).shadow(...)`）
- **位置2**: PopoverSmallStat 内联 — WidgetPanelView.swift:243（`Circle().fill(tint).frame(7x7)`，无 shadow）
- **位置3**: MiniStatus 内联 — SystemDashboardWidget.swift:673（`Circle().fill(tint).frame(6x6)`）
- **位置4**: StatTile 内联 — SystemDashboardWidget.swift:697（`Circle().fill(tint).frame(6x6)`）
- **重复描述**: 「状态圆点」组件在 App 抽象为 `StatusDot`，在 popover/widget 内联手写，尺寸与是否带 shadow 不一致。
- **实现差异**: 尺寸 7/6/6，shadow 仅 StatusDot 有。
- **合并可行性**: 需先统一尺寸/-shadow 决策；tokens 上移后可在 `SharedMetrics`（或共享 UI 模块）提供 `StatusDot`。
- **风险**: 视觉不一致；改一处不带其他跟随。
- **建议**: 统一 `StatusDot` 组件，参数化 size 与 shadow，三处复用。
- **优先级**: R-中

### 重复 R2-15: PopoverMetricRow 与 WidgetRow 结构重复
- **位置1**: PopoverMetricRow — WidgetPanelView.swift:182-233（title + value + detail + 进度条 Capsule + progressFillWidth）
- **位置2**: WidgetRow — SystemDashboardWidget.swift:627-663（title + value + 进度条 Capsule + progressFillWidth）
- **重复描述**: 两者均为「标题+值+Capsule 进度条」行布局，进度条绘制逻辑完全相同（`Capsule().fill(track)` + `Capsule().fill(tint.gradient).frame(width: progressFillWidth(...))`）。
- **实现差异**: PopoverMetricRow 多 `detail` 文本、外层 padding/background/overlay；WidgetRow 更精简；进度条高度 6 vs 5，minimumVisibleWidth 7 vs 6。
- **合并可行性**: 可提取共享 `MetricProgressBar` 子视图（仅进度条部分），行布局因装饰差异保留各自版本。
- **风险**: 进度条绘制逻辑分散，R2-2 修复后仍有两个行容器分别维护。
- **建议**: 提取 `MetricProgressBar(progress:tint:height:minimumVisibleWidth:)` 到共享模块，两行复用。
- **优先级**: R-中

### 重复 R2-16: PopoverSmallStat / MiniStatus / StatTile 三套「小状态卡」
- **位置1**: PopoverSmallStat — WidgetPanelView.swift:235-264（圆点 + title + value，竖排，minHeight 60）
- **位置2**: MiniStatus — SystemDashboardWidget.swift:665-687（圆点 + title + value，横排）
- **位置3**: StatTile — SystemDashboardWidget.swift:689-717（圆点 + title + value，竖排）
- **重复描述**: 三处均为「圆点+标题+值」小卡，语义同源。
- **实现差异**: 布局方向、尺寸、字号、背景装饰均不同。
- **合并可行性**: 难以完全合并（布局差异大），但圆点部分可随 R2-14 合并；可考虑参数化统一组件。
- **风险**: 中等；视觉风格可能有意分歧。
- **建议**: 短期保留，长期参数化。
- **优先级**: R-低

### 重复 R2-17: `thermalStatus`/`thermalProgress` 魔法数映射仅一处但应共享
- **位置1**: thermalStatus — DashboardView.swift:2321-2328（`ThermalState → StatusLevel`）
- **位置2**: thermalProgress — DashboardView.swift:2330-2337（`ThermalState → Double?`，critical:1, hot:0.78, warm:0.52, nominal:0.24, unknown:nil）
- **重复描述**: 虽仅 App 单处定义，但 `ThermalState` 已在 `SharedMetrics`，且 Widget 侧 `thermalTint`（R2-5）做了同源的 tone 映射；`thermalProgress` 的 0.78/0.52/0.24 魔法数若 Widget 未来需要趋势进度将重新出现。
- **实现差异**: 与 `MetricSnapshot.thermalText`/`thermalLimitText`（MetricSnapshot.swift:1233-1253）属不同层（文本 vs 进度/tone），非直接重复但同源语义。
- **合并可行性**: 在 `ThermalState` 上加 `var metricStatusTone: MetricStatusTone` 与 `var progress: Double?` 计算属性，加入 `SharedMetrics`。
- **风险**: 魔法数无单一来源；Widget 侧如需进度会复制。
- **建议**: 将 tone 与 progress 映射上移到 `ThermalState` 扩展。
- **优先级**: R-中

### 重复 R2-18: 三套背景渐变
- **位置1**: windowBackdropColors — DashboardView.swift:170-184（App 主窗口，3 段渐变，使用 `NSColor.windowBackgroundColor`）
- **位置2**: widgetPreviewBackgroundColors — DashboardView.swift:1407-1419（App 内 Widget 预览，2 段渐变，使用 `NSColor.controlBackgroundColor`/`textBackgroundColor`）
- **位置3**: widgetBackgroundColors — WidgetVisualTokens.swift:61-75（真实 Widget，3 段渐变，纯 RGB）
- **重复描述**: 三处各自定义「深/浅模式背景渐变色组」。
- **实现差异**: 段数（3/2/3）、色源（NSColor 语义色 vs 纯 RGB）、opacity 均不同。
- **合并可行性**: 部分可合并。`widgetPreviewBackgroundColors` 应与 `widgetBackgroundColors` 对齐（预览应还原真实 Widget 外观），当前两者不一致是 bug 风险。
- **风险**: App 内 Widget 预览与真实 Widget 背景不一致，误导设计评审。
- **建议**: 让 `widgetPreviewBackgroundColors` 直接复用 `widgetBackgroundColors`（需将该 helper 上移到共享模块），`windowBackdropColors` 保留为 App 专属。
- **优先级**: R-中

### 重复 R2-19: trend 提取器在 OverviewPage 与 HistoryPage 的调用不一致
- **位置1**: OverviewPage body — DashboardView.swift:424-427 — `networkTrendValues(from: history)`（无 keyPath 参数，内部默认 `\.networkBytesPerSecond`）
- **位置2**: HistoryPage body — DashboardView.swift:1042 — `networkTrendValues(from: history, keyPath: \.networkBytesPerSecond)`（显式传同一 keyPath）
- **重复描述**: 两处调用语义等价（最终 keyPath 相同），但一个用默认重载、一个用显式重载。
- **实现差异**: 调用形式不同，结果相同。
- **合并可行性**: 统一调用风格。
- **风险**: 低；但若未来 default keyPath 改变，两处行为会静默分歧。
- **建议**: 统一为无 keyPath 形式（或两者都显式）。
- **优先级**: R-低

---

## 四、已验证为有意的重复（排除项）

### 排除 E1: Sparkline（DashboardView.swift:1520）— Widget 无对应实现
- Widget 侧使用 `RingMetric`（SystemDashboardWidget.swift:590，环形进度）而非折线图。
- 二者是**不同可视化范式**，共享 `MetricScales.clampedProgress` 作为单一来源，属合理设计，非重复。

### 排除 E2: CapacityBar / MemorySegmentBar 与 RingMetric
- `CapacityBar`/`MemorySegmentBar`（DashboardView.swift:1679, 1732）为分段条形，`RingMetric` 为环形，视觉范式不同。
- 三者均通过 `MetricScales.clampedProgress` / `normalizedBytes` 归一化，单一来源正确。
- 分段条的「最小可见宽度」逻辑（`segmentWidth` at DashboardView.swift:1718）与 `progressFillWidth` 语义相近但参数不同（按 bytes/total vs 按 progress），不构成可合并重复。

### 排除 E3: 三套 strings 表的 `localized` 默认 bundle/table
- `PulseDockApp` / `SharedMetrics` / `PulseDockWidget` 三套 strings 表必须分属不同 target 的 Bundle（`.module`），table 名亦不同。
- 此「重复」是模块边界的必然结果，**但实现体可共享**（见 R2-12）。表/bundle 差异本身保留，仅提取实现函数。

### 排除 E4: `windowBackdropColors` 与 `widgetBackgroundColors` 的差异
- 主窗口背景使用 `NSColor` 语义色以跟随系统主题，Widget 受限只能用纯 RGB（Widget 进程无 `NSColor` 语义色支持）。
- 此差异是平台约束，保留；但 `widgetPreviewBackgroundColors` 应与 `widgetBackgroundColors` 对齐（见 R2-18）。

### 排除 E5: `MetricFormatting` 与 `SharedMetricStrings.localizedFormat` 分层
- `MetricFormatting`（MetricFormatting.swift）负责数值格式化（percentage/bytes/rate/load/duration），`SharedMetricStrings.localizedFormat` 负责 `%` 占位符插值。
- 二者职责不同，非重复。`MetricFormatting` 内部调用 `SharedMetricStrings.notReported` 作为兜底，依赖关系正确。

---

## 五、合并可行性总结

| 共享目标模块 | 可承接的重复项 | 备注 |
|--------------|----------------|------|
| `SharedMetrics.MetricScales`（已存在） | R2-1 reportedProgress、R2-2 progressFillWidth、R2-7 networkPathProgress、R2-3 normalizedRate（直接删除） | 均为纯逻辑/数值，无 SwiftUI 依赖 |
| `SharedMetrics` 类型扩展（ThermalState/NetworkPathState/MetricStatusTone） | R2-4 powerTint、R2-5 thermalTint、R2-6 networkTint、R2-17 thermalStatus/thermalProgress | 在已有枚举上加 `metricStatusTone` / `progress` 计算属性 |
| `SharedMetrics` 新建 `SharedColorTokens` / `SharedSurfaceTokens` | R2-9 三套颜色、R2-10 表面色 helper、R2-14 StatusDot、R2-15 MetricProgressBar | 需先对齐 dark 值；`SharedMetrics` 当前只导入 Foundation，引入 SwiftUI 颜色需评估是否新建 `SharedUI` 模块 |
| `SharedMetrics` 新建 `LocalizationSupport` | R2-12 localized、R2-13 localizedFormat、R2-11 notReported | 三套 strings 表保留各自 table/bundle，仅共享实现函数 |

---

## 六、优先级汇总

| 优先级 | 重复项 | 数量 |
|--------|--------|------|
| R-高 | R2-1, R2-2, R2-7, R2-9 | 4 |
| R-中 | R2-3, R2-4, R2-5, R2-6, R2-10, R2-11, R2-14, R2-15, R2-17, R2-18 | 10 |
| R-低 | R2-8, R2-12, R2-13, R2-16, R2-19 | 5 |
| **合计** | | **19** |

**核心结论**：最严重的是「三套颜色 tokens + 三处纯逻辑函数」两类。前者导致 App/Popover/Widget 在 dark 模式下强调色肉眼不一致且无单一来源；后者（reportedProgress/progressFillWidth/networkPathProgress）已是逐字节相同的死复制，应立即上移到 `SharedMetrics`。`normalizedRate` 是零附加值包装，建议直接删除。`thermalStatus`/`thermalProgress`/`thermalTint`/`networkTint`/`powerTint` 五个 tint/status 映射应统一收敛到 `SharedMetrics` 中已有枚举的 `metricStatusTone` 计算属性，由各 target 提供 `tone → Color` 表，从而消除「rename 一处即静默分歧」的风险。
