# R4 — 跨模块重复模式报告

> 审查日期：2026-06-28
> 审查范围：`Sources/PulseDockApp/`、`Sources/PulseDockWidget/`、`Sources/SharedMetrics/` 三模块间重复逻辑
> 审查基准：当前 working tree（HEAD `9db73ee`）
> 关联计划：`docs/review/REDUNDANCY-REVIEW-PLAN.md` 子任务 R4、`docs/review/REVIEW-PLAN.md` P2-4、`docs/review/LOGIC-CONSISTENCY-REVIEW-PLAN.md` B1/B2

---

## 〇、模块边界约束（审查前提）

| 依赖关系 | 可用性 | 含义 |
|---------|--------|------|
| app → SharedMetrics | ✅ | app 可调用 SharedMetrics 的全部 public API |
| widget → SharedMetrics | ✅ | widget 可调用 SharedMetrics 的全部 public API |
| app → widget | ❌ | app 不可引用 widget 任何符号 |
| widget → app | ❌ | widget 不可引用 app 任何符号 |

**推论**：
- "app 和 widget 都需要的逻辑" = 可提取到 SharedMetrics 的候选
- "仅 app 或仅 widget 需要的逻辑" = 必须保持独立
- SharedMetrics 当前为 **Foundation-only**（`MetricFormatting.swift`/`MetricScales.swift`/`SharedMetricStrings.swift` 均 `import Foundation`，无 SwiftUI/AppKit）。提取 `Color`/`NSColor` 返回逻辑需先决定是否给 SharedMetrics 加 SwiftUI 依赖，或仅提取"语义决策"（枚举/数值），把颜色适配留在各侧。

**关键既有资产**：SharedMetrics 已存在 `MetricStatusTone` 枚举（`MetricSnapshot.swift:3-8`，`neutral/normal/warning/critical`）和 `ThermalState`/`NetworkPathState` 枚举（`MetricStateContracts.swift:3-52`）。跨模块语义映射应基于这两个枚举，而非再创建新的。

---

## 一、跨模块重复模式矩阵

| 重复模式 | app 位置 | popover 位置 | widget 位置 | shared 位置 | 实现差异 | 合并可行性 |
|---------|---------|-------------|------------|------------|---------|-----------|
| **reportedProgress** | `DashboardView.swift:2152` | `WidgetPanelView.swift:136` | `SystemDashboardWidget.swift:771` | — | 三处实现**完全相同**（`guard hasReport else { nil }; return progress`） | **可提取**到 `MetricScales` |
| **progressFillWidth** | `DashboardView.swift:2157` | `WidgetPanelView.swift:311` | `SystemDashboardWidget.swift:776` | — | 三处实现**完全相同**（`clampedProgress` + `max(min, w*p)`），依赖 `MetricScales.clampedProgress`（已在 shared） | **可提取**到 `MetricScales`（需 `import CoreGraphics` for `CGFloat`） |
| **networkPathProgress** | `DashboardView.swift:2252` | — | `SystemDashboardWidget.swift:758` | — | app 与 widget 实现**完全相同**（satisfied=1/requiresConnection=0.45/unsatisfied=0/unknown=0）；popover 无此函数 | **可提取**到 `NetworkPathState.progress`（SharedMetrics） |
| **thermalState→语义色调** | `DashboardView.swift:2321` (`thermalStatus`→`StatusLevel`) | `WidgetPanelView.swift:159` (`thermalTint`→`Color`) | `SystemDashboardWidget.swift:736` (`thermalTint`→`Color`) | `MetricStateContracts.swift:3` (`ThermalState` 枚举) | ⚠️ **语义分歧**：app 把 `hot` 归入 `.warning`(amber)，popover/widget 把 `hot` 归入 critical(red)；app 的 `unknown`→`.neutral`→**blue**，popover/widget 的 `unknown`→**cyan** | **可提取** canonical 映射到 `ThermalState.semanticTone`（需先统一 hot 归类） |
| **networkPathState→语义色调** | `DashboardView.swift:2235` (`networkStatusLevel`→`StatusLevel`) | `WidgetPanelView.swift:168` (`networkTint`→`Color`) | `SystemDashboardWidget.swift:745` (`networkTint`→`Color`) | `MetricStateContracts.swift:30` (`NetworkPathState` 枚举) | satisfied/requiresConnection/unsatisfied 三处语义一致（green/amber/red）；⚠️ `unknown`：app→`.neutral`→**blue**，popover/widget→**cyan** | **可提取** canonical 映射到 `NetworkPathState.semanticTone`（需先统一 unknown 色调） |
| **thermalState→progress** | `DashboardView.swift:2330` (`thermalProgress`) | — | — | — | 仅 app 有（critical=1/hot=0.78/warm=0.52/nominal=0.24/unknown=nil）；popover/widget 不渲染热进度条 | **可提取**到 `ThermalState.progress`（仅 app 消费，但放在 shared 供未来 widget 复用，且消除 app 内 switch 字面量匹配） |
| **powerStatusTone→色调** | `DashboardView.swift:2276` (`powerTint`→`Color`) | `WidgetPanelView.swift:146` (`powerTint`→`Color`) | `SystemDashboardWidget.swift:788` (`powerTint`→`Color`) | `MetricSnapshot.swift:1283` (`powerStatusTone: MetricStatusTone`) | 三处 switch `MetricStatusTone`→Color **语义一致**（normal→green/warning→amber/critical→red/neutral→cyan）；仅颜色来源不同（DashboardColor vs Palette vs WidgetColor） | **可提取** canonical 映射 `MetricStatusTone.semanticColor`，但需解决 Color vs 数值问题 |
| **reportedTint** | — | `WidgetPanelView.swift:141` | `SystemDashboardWidget.swift:783` | — | popover/widget 两处语义相同（未报告→cyan，已报告→fallback）；签名不同（popover 捕获环境 colorScheme，widget 显式传参）；app 无对应函数 | popover/widget 跨模块重复，但依赖各自 Palette/WidgetColor 的 cyan；可提取"未报告→cyan 语义"决策，颜色适配留各侧 |
| **normalizedRate** | `DashboardView.swift:2148` | `WidgetPanelView.swift:132` | — | `MetricScales.networkRateProgress` (`MetricScales.swift:6`) | app+popover 各一份 1 行 alias（`MetricScales.networkRateProgress(bytesPerSecond:)`）；widget 无此函数（widget 不渲染吞吐量进度条） | **非跨模块**（仅 app target 内部）；alias 可直接删除，改为调用 shared 函数 |
| **语义颜色 RGB（light）** | `DashboardVisualTokens.swift:60-65` (`DashboardColor`) | `WidgetPanelView.swift:318-337` (`Palette`) | `WidgetVisualTokens.swift:39-58` (`WidgetColor`) | — | light 模式 RGB **三处完全一致**（blue=0.14/0.43/0.95, green=0.04/0.62/0.39, amber=0.93/0.54/0.10, red=0.84/0.16/0.16, cyan=0.04/0.56/0.70） | **可提取** light RGB 到 SharedMetrics 数值常量 |
| **语义颜色 RGB（dark）** | `DashboardColor` 无 dark 变体（用 light 值） | `Palette` dark 变体 | `WidgetColor` dark 变体 | — | ⚠️ Palette 与 WidgetColor 的 dark RGB **不一致**（见 §二 R4-8）；app 完全无 dark 适配 | 需先确认是"有意区分"还是"复制后漂移"；若是漂移可提取统一 dark RGB |
| **"Not reported" 话术** | `PulseDockAppStrings.swift:1070` (`app.not_reported`) | (popover 用 app strings) | `PulseDockWidgetStrings.swift:88` (`widget.not_reported`) | `SharedMetricStrings.swift:4` (`shared_metrics.not_reported`) | 三处 defaultValue 均为 `"Not reported"`，但 key/table/bundle 不同 | **可合并**：app/widget 改用 `SharedMetricStrings.notReported`（除非刻意要 per-module 翻译，但 default 相同说明无此意图） |
| **localized 函数** | `PulseDockAppStrings.swift:1338` | — | `PulseDockWidgetStrings.swift:116` | `SharedMetricStrings.swift:391` | 三处实现结构相同，仅 `bundle` 默认值与 `table` 名不同（"PulseDockApp"/"PulseDockWidget"/"SharedMetrics"） | **需保持独立**（table 名是模块标识，不可共享） |
| **localizedFormat 函数** | `PulseDockAppStrings.swift:1346` | — | — | `SharedMetricStrings.swift:399` | app+shared 两处相同（`String(format:locale:Locale.current,arguments:)`）；widget 无 | 可提取为 shared 工具，但仅 2 处且私有，收益低 |
| **格式化 locale** | `MetricFormatting.swift:24,41,57` (`String(format:)` 无 locale → C locale) | — | — | `SharedMetricStrings.swift:404` (`Locale.current`) | ⚠️ `MetricFormatting` 用 C locale（始终点号小数），`localizedFormat` 用 `Locale.current` → 同一数字在 app 不同位置格式可能不一致 | **可统一**：`MetricFormatting` 的 `String(format:)` 应传 `Locale.current` |
| **powerSource switch 结构** | (app 用 shared `powerStatusText`) | (popover 用 shared `powerStatusText`) | `SystemDashboardWidget.swift:801` (`compactPowerStatusText`) | `MetricSnapshot.swift:1258` (`powerSourceText`) | shared 与 widget 的 switch 结构相同（ac/battery/ups/.some/default），但输出字符串集不同（全称 vs 缩写） | **部分可提取**：switch 骨架可参数化，字符串集保持各侧独立 |
| **网络速率 scale vs 路径 scale** | `MetricScales.networkRateProgress`（log10 吞吐量→进度） | (popover 用 `normalizedRate`→同 app) | `SystemDashboardWidget.swift:758`（`networkPathProgress` 线性 0/0.45/1） | `MetricScales.networkRateProgress` | **非重复**：`networkRateProgress` 是吞吐量量纲缩放（bytes→0..1），`networkPathProgress` 是连接质量映射（状态→0/0.45/1）。两者度量不同对象，不应合并。但 `networkPathProgress` 本身 app↔widget 重复（见上） | — |
| **布局常量** | `DashboardVisualTokens.swift:3-51` (`DashboardSpacing`/`DashboardLayout`/`DashboardTypography`) | `WidgetPanelView.swift:6-11` (`MenuPopoverLayout`) | `WidgetVisualTokens.swift`（inline 常量，无 spacing enum） | — | `DashboardSpacing`(3/4/8/12/16/24) 是通用设计间距，但 widget 用 inline 字面量（8/11/7 等）；`DashboardLayout` 是 app 窗口专属；`MenuPopoverLayout` 是 popover 专属 | **需保持独立**（布局尺寸是各 UI 容器专属；间距 token 化收益低） |

---

## 二、可提取到 SharedMetrics 的重复

### 重复 R4-1: reportedProgress（三处完全相同）

- **app 位置**：`DashboardView.swift:2152-2155`
  ```swift
  private func reportedProgress(hasReport: Bool, progress: Double) -> Double? {
      guard hasReport else { return nil }
      return progress
  }
  ```
- **popover 位置**：`WidgetPanelView.swift:136-139` — 实现完全相同
- **widget 位置**：`SystemDashboardWidget.swift:771-774` — 实现完全相同
- **实现差异**：无。三处逐字符相同。
- **提取方案**：在 `Sources/SharedMetrics/MetricScales.swift` 增加：
  ```swift
  public static func reportedProgress(hasReport: Bool, progress: Double) -> Double? {
      guard hasReport else { return nil }
      return progress
  }
  ```
  app/popover/widget 三处删除本地实现，改为调用 `MetricScales.reportedProgress(...)`。
- **类型适配**：无（纯 `Double`/`Bool`，Foundation 类型）。
- **优先级**：**R-中**（三处完全相同，rename 风险明确；但逻辑极简，错误概率低）

### 重复 R4-2: progressFillWidth（三处完全相同）

- **app 位置**：`DashboardView.swift:2157-2162`
  ```swift
  private func progressFillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat {
      guard let normalizedProgress = MetricScales.clampedProgress(progress), normalizedProgress > 0 else {
          return 0
      }
      return max(minimumVisibleWidth, totalWidth * normalizedProgress)
  }
  ```
- **popover 位置**：`WidgetPanelView.swift:311-316` — 实现完全相同
- **widget 位置**：`SystemDashboardWidget.swift:776-781` — 实现完全相同
- **实现差异**：无。三处均依赖已在 shared 的 `MetricScales.clampedProgress`。
- **提取方案**：在 `MetricScales.swift` 增加（需 `import CoreGraphics`，CoreGraphics 在 macOS 上可用且不引入 SwiftUI）：
  ```swift
  import CoreGraphics
  public static func progressFillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat {
      guard let normalizedProgress = clampedProgress(progress), normalizedProgress > 0 else { return 0 }
      return max(minimumVisibleWidth, totalWidth * normalizedProgress)
  }
  ```
- **类型适配**：`CGFloat` 来自 CoreGraphics，SharedMetrics 加 `import CoreGraphics` 即可（不破坏 Foundation-only 约束，CoreGraphics 是更低层框架）。
- **优先级**：**R-中**（与 R4-1 同源，常一起调用；提取后可保证进度条最小可见宽度策略一致）

### 重复 R4-3: networkPathProgress（app ↔ widget 完全相同）

- **app 位置**：`DashboardView.swift:2252-2263`
  ```swift
  private func networkPathProgress(_ snapshot: MetricSnapshot) -> Double {
      switch snapshot.canonicalNetworkPathState {
      case .satisfied: 1
      case .requiresConnection: 0.45
      case .unsatisfied: 0
      case .unknown: 0
      }
  }
  ```
- **popover 位置**：无（popover 不渲染网络路径进度条）
- **widget 位置**：`SystemDashboardWidget.swift:758-769` — 实现完全相同
- **实现差异**：无。app 与 widget 逐字符相同。
- **提取方案**：在 `MetricStateContracts.swift` 的 `NetworkPathState` 上增加计算属性：
  ```swift
  public var progress: Double {
      switch self {
      case .satisfied: 1
      case .requiresConnection: 0.45
      case .unsatisfied: 0
      case .unknown: 0
      }
  }
  ```
  app/widget 删除本地 `networkPathProgress(_:)`，改为 `snapshot.canonicalNetworkPathState.progress`。
- **类型适配**：纯 `Double`，无 Color 依赖。
- **优先级**：**R-高**（app↔widget 跨模块重复；当前 `0.45` 魔法数任一处改动即静默分歧；提取到枚举上消除分歧风险）

### 重复 R4-4: thermalState → 语义色调映射（三处，含语义分歧 ⚠️）

- **app 位置**：`DashboardView.swift:2321-2328`（`thermalStatus` 返回 `StatusLevel`）
  ```swift
  case .critical: .critical        // → red
  case .hot, .warm: .warning       // → amber  ⚠️ hot 归 warning
  case .nominal: .normal           // → green
  case .unknown: .neutral          // → blue   ⚠️ unknown 归 blue
  ```
- **popover 位置**：`WidgetPanelView.swift:159-166`（`thermalTint` 返回 `Color`）
  ```swift
  case .critical, .hot: Palette.red(...)   // ⚠️ hot 归 critical(red)
  case .warm: Palette.amber(...)
  case .nominal: Palette.green(...)
  case .unknown: Palette.cyan(...)         // ⚠️ unknown 归 cyan
  ```
- **widget 位置**：`SystemDashboardWidget.swift:736-743`（`thermalTint` 返回 `Color`）
  ```swift
  case .critical, .hot: WidgetColor.red(...)   // ⚠️ hot 归 critical(red)
  case .warm: WidgetColor.amber(...)
  case .nominal: WidgetColor.green(...)
  case .unknown: WidgetColor.cyan(...)         // ⚠️ unknown 归 cyan
  ```
- **实现差异**：
  1. ⚠️ **`hot` 归类分歧**：app 把 `hot` 归入 `warning`(amber)，popover/widget 把 `hot` 归入 `critical`(red)。用户在 app 主窗口看到"hot=琥珀色"，在 popover/widget 看到"hot=红色"——同屏跨 surface 颜色不一致。
  2. ⚠️ **`unknown` 色调分歧**：app 经 `StatusLevel.neutral`→`DashboardColor.blue`(0.14/0.43/0.95)，popover/widget 用 cyan(0.04/0.56/0.70)。app 内部也不一致：`powerTint`(`DashboardView.swift:2285`) 的 `.neutral`→`DashboardColor.cyan`，但 `StatusLevel.color`(`DashboardView.swift:1791`) 的 `.neutral`→`DashboardColor.blue`。
- **提取方案**：在 `MetricStateContracts.swift` 的 `ThermalState` 上增加：
  ```swift
  public var semanticTone: MetricStatusTone {
      switch self {
      case .critical: .critical
      case .hot: .critical      // 统一为 critical（与 popover/widget 对齐，hot 已接近 throttling）
      case .warm: .warning
      case .nominal: .normal
      case .unknown: .neutral
      }
  }
  ```
  app 侧 `thermalStatus` 改为 `ThermalState(raw:).semanticTone`→映射到 `StatusLevel`；popover/widget 侧 `thermalTint` 改为 `ThermalState(raw:).semanticTone`→映射到各自 Color。
- **类型适配**：返回 `MetricStatusTone`（已在 SharedMetrics），各侧再 `tone → Color`：
  - app：`tone → StatusLevel → DashboardColor`（需修正 `StatusLevel.neutral` 从 blue 改为 cyan，与 `powerTint` 一致）
  - popover：`tone → Palette.green/amber/red/cyan(for:)`
  - widget：`tone → WidgetColor.green/amber/red/cyan(for:)`
- **前置决策**：需产品确认 `hot` 应归 warning 还是 critical（建议 critical，与 popover/widget 多数派一致，且热状态已是 throttling 前兆）。
- **优先级**：**R-高**（语义分歧导致同设备跨 surface 颜色不一致，用户可感知）

### 重复 R4-5: networkPathState → 语义色调映射（三处，unknown 色调分歧 ⚠️）

- **app 位置**：`DashboardView.swift:2235-2246`（`networkStatusLevel` 返回 `StatusLevel`）
  ```swift
  case .satisfied: .normal          // → green
  case .unsatisfied: .critical      // → red
  case .requiresConnection: .warning // → amber
  case .unknown: .neutral           // → blue ⚠️
  ```
- **popover 位置**：`WidgetPanelView.swift:168-179`（`networkTint` 返回 `Color`）
  ```swift
  case .satisfied: Palette.green(...)
  case .requiresConnection: Palette.amber(...)
  case .unsatisfied: Palette.red(...)
  case .unknown: Palette.cyan(...)   // ⚠️ cyan
  ```
- **widget 位置**：`SystemDashboardWidget.swift:745-756`（`networkTint` 返回 `Color`） — 与 popover 相同
- **实现差异**：
  - satisfied/requiresConnection/unsatisfied 三处语义一致（green/amber/red）。
  - ⚠️ `unknown`：app→blue（经 `StatusLevel.neutral`→`DashboardColor.blue`），popover/widget→cyan。与 R4-4 同源（`StatusLevel.neutral` 错误映射到 blue）。
- **提取方案**：在 `NetworkPathState` 上增加：
  ```swift
  public var semanticTone: MetricStatusTone {
      switch self {
      case .satisfied: .normal
      case .requiresConnection: .warning
      case .unsatisfied: .critical
      case .unknown: .neutral
      }
  }
  ```
  各侧 `semanticTone → Color`。
- **类型适配**：同 R4-4。
- **前置决策**：需修正 app `StatusLevel.neutral` 从 blue 改为 cyan（见 §三）。
- **优先级**：**R-高**（与 R4-4 同类语义分歧）

### 重复 R4-6: thermalState → progress（仅 app，但应 canonical 化）

- **app 位置**：`DashboardView.swift:2330-2337`
  ```swift
  private func thermalProgress(_ state: String) -> Double? {
      switch ThermalState(raw: state) {
      case .critical: 1
      case .hot: 0.78
      case .warm: 0.52
      case .nominal: 0.24
      case .unknown: nil
      }
  }
  ```
- **popover 位置**：无（popover 不渲染热进度条）
- **widget 位置**：无（widget 不渲染热进度条）
- **实现差异**：仅 app 有。但 `0.78/0.52/0.24` 是 canonical 进度值，应在 SharedMetrics 定义，避免未来 widget 添加热进度条时重新推导。
- **提取方案**：在 `ThermalState` 上增加：
  ```swift
  public var progress: Double? {
      switch self {
      case .critical: 1
      case .hot: 0.78
      case .warm: 0.52
      case .nominal: 0.24
      case .unknown: nil
      }
  }
  ```
- **类型适配**：纯 `Double?`。
- **优先级**：**R-低**（当前仅 app 消费，但提取后消除 app 内 `ThermalState(raw:)` 字面量 switch，与 R4-4 一并修复时边际成本低）

### 重复 R4-7: "Not reported" 话术（三处定义，default 相同）

- **app 位置**：`PulseDockAppStrings.swift:1070-1072`
  ```swift
  static var notReported: String {
      localized("app.not_reported", defaultValue: "Not reported")
  }
  ```
- **popover 位置**：复用 `PulseDockAppStrings.notReported`（`WidgetPanelView.swift:231`）
- **widget 位置**：`PulseDockWidgetStrings.swift:88-90`
  ```swift
  static var notReported: String {
      localized("widget.not_reported", defaultValue: "Not reported")
  }
  ```
- **shared 位置**：`SharedMetricStrings.swift:4-6`
  ```swift
  static var notReported: String {
      localized("shared_metrics.not_reported", defaultValue: "Not reported")
  }
  ```
- **实现差异**：三处 `defaultValue` 均为 `"Not reported"`，仅 localization key/table/bundle 不同。SharedMetrics 已有该字符串，且 `MetricFormatting`/`MetricSnapshot` 等共享代码已大量使用 `SharedMetricStrings.notReported`（97 处引用）。
- **提取方案**：app 侧把 `PulseDockAppStrings.notReported` 的 13 处引用（`DashboardView.swift`×10、`WidgetPanelView.swift`×1、`AppDelegate.swift`×1、`PulseDockAppStrings.swift:1800` StatusLevel.text 内×1）改为 `SharedMetricStrings.notReported`，删除 `PulseDockAppStrings.notReported` 定义；widget 侧把 `PulseDockWidgetStrings.notReported` 的引用改为 `SharedMetricStrings.notReported`，删除 widget 定义。
- **类型适配**：无（纯 String）。
- **风险**：app/widget 的本地化 strings 表中 `app.not_reported`/`widget.not_reported` 的翻译可能与 `shared_metrics.not_reported` 不同（若已有 zh-Hans 翻译）。需核对三套 strings 表的翻译是否一致；若一致则安全合并，若不一致需先统一翻译。
- **优先级**：**R-中**（消除三处定义，但需核对本地化翻译一致性）

### 重复 R4-8: 语义颜色 light RGB（三处完全一致）

- **app 位置**：`DashboardVisualTokens.swift:60-65`（`DashboardColor`，单值=light）
  ```
  blue  = (0.14, 0.43, 0.95)
  green = (0.04, 0.62, 0.39)
  amber = (0.93, 0.54, 0.10)
  red   = (0.84, 0.16, 0.16)
  cyan  = (0.04, 0.56, 0.70)
  purple= (0.48, 0.34, 0.88)   // 仅 app 有
  ```
- **popover 位置**：`WidgetPanelView.swift:318-337`（`Palette`，light 分支）— RGB 与 app 完全相同
- **widget 位置**：`WidgetVisualTokens.swift:39-58`（`WidgetColor`，light 分支）— RGB 与 app 完全相同
- **实现差异**：light 模式三处 RGB 完全一致。⚠️ dark 模式 Palette 与 WidgetColor 不一致（见下表）；app 无 dark 变体。

  | 颜色 | Palette dark | WidgetColor dark | 差异 |
  |------|-------------|-----------------|------|
  | blue  | (0.42, 0.66, 1.00) | (0.36, 0.62, 1.00) | widget 更深 |
  | green | (0.26, 0.82, 0.58) | (0.24, 0.82, 0.62) | 微差 |
  | amber | (1.00, 0.70, 0.30) | (1.00, 0.68, 0.28) | 微差 |
  | cyan  | (0.24, 0.76, 0.86) | (0.29, 0.78, 0.88) | 微差 |
  | red   | (1.00, 0.38, 0.36) | (1.00, 0.42, 0.42) | 微差 |

- **提取方案**：在 SharedMetrics 新增 `SemanticColorComponents`（纯数值，不依赖 SwiftUI）：
  ```swift
  public enum SemanticColorComponents {
      public static let blueLight  = (r: 0.14, g: 0.43, b: 0.95)
      public static let blueDark   = (r: 0.36, g: 0.62, b: 1.00)  // 统一为 widget 值
      public static let greenLight = (r: 0.04, g: 0.62, b: 0.39)
      // ... 其余颜色
  }
  ```
  各侧 `DashboardColor`/`Palette`/`WidgetColor` 改为 `Color(red:green:blue:)` 引用这些常量。
- **类型适配**：SharedMetrics 只存 `(Double, Double, Double)` 元组，不引入 SwiftUI；各侧用 `Color(red:g:b:)` 构造。
- **前置决策**：
  1. dark 模式 RGB 差异是"有意区分"还是"复制后漂移"？popover 与 widget 都是小尺寸深色背景 surface，颜色应一致——**判定为漂移**，建议统一为 widget 值（widget 是最终展示层，且 widget 经 WidgetKit 渲染色彩管理更严格）。
  2. app `DashboardColor` 是否应增加 dark 变体？当前 app 用 light 值渲染 dark 模式，颜色偏深不够鲜明。但这是 app 自身设计问题，非跨模块重复范畴。
- **优先级**：**R-中**（light 一致说明本是同源；dark 漂移是维护风险，任一处调色不会传播）

### 重复 R4-9: powerStatusTone → 色调映射（三处语义一致）

- **app 位置**：`DashboardView.swift:2276-2287`（`powerTint`）
  ```swift
  case .normal: DashboardColor.green
  case .warning: DashboardColor.amber
  case .critical: DashboardColor.red
  case .neutral: DashboardColor.cyan
  ```
- **popover 位置**：`WidgetPanelView.swift:146-157`（`powerTint`） — 语义相同，用 `Palette`
- **widget 位置**：`SystemDashboardWidget.swift:788-799`（`powerTint`） — 语义相同，用 `WidgetColor`
- **实现差异**：三处语义完全一致（normal→green/warning→amber/critical→red/neutral→cyan）。仅颜色来源不同。
- **提取方案**：与 R4-4/R4-5 同模式——`MetricStatusTone` 已在 SharedMetrics，增加 `MetricStatusTone.semanticColor` 需 Color 类型；建议改为各侧实现 `tone → Color` 的统一映射函数，但决策（哪个 tone 用哪个语义色）已在 `MetricStatusTone` 枚举中隐含定义。可提取的是"tone→语义色名"的映射表（如 `.normal → .green`），各侧再 `语义色名 → Color`。
- **类型适配**：需引入中间枚举 `SemanticColorName { green, blue, amber, red, cyan, purple }`（可放 SharedMetrics，纯 Foundation），各侧 `SemanticColorName → Color`。
- **优先级**：**R-低**（三处语义已一致，无分歧风险；提取收益主要是减少重复 switch，非消除分歧）

### 重复 R4-10: powerSource switch 结构（shared vs widget）

- **shared 位置**：`MetricSnapshot.swift:1258-1273`（`powerSourceText`）
  ```swift
  switch batteryPowerSource?.lowercased() {
  case "ac power":     → powerSourceAdapterCharging / powerSourceAdapter
  case "battery power": → powerSourceBattery
  case "ups power":    → powerSourceUPS
  case .some:          → powerSourceExternal
  default:             → notReported / fallback
  }
  ```
- **widget 位置**：`SystemDashboardWidget.swift:801-817`（`compactPowerStatusText`）
  ```swift
  if let batteryPercent = snapshot.batteryPercent { return MetricFormatting.percentage(batteryPercent) }
  switch snapshot.batteryPowerSource?.lowercased() {
  case "ac power":     → compactPowerCharging / compactPowerAdapter
  case "battery power": → compactPowerBattery
  case "ups power":    → powerUPS
  case .some:          → compactPowerExternal
  default:             → notReported
  }
  ```
- **实现差异**：
  - switch 骨架相同（`ac power`/`battery power`/`ups power`/`.some`/`default`）。
  - 输出字符串集不同：shared 用全称（`SharedMetricStrings.powerSourceAdapter` 等），widget 用缩写（`PulseDockWidgetStrings.compactPowerCharging` 等）。
  - widget 优先返回 `batteryPercent` 百分比，shared 的 `powerStatusText` 也有相同优先级（`batteryPercent == nil ? powerSourceText : batteryPercentText`，`MetricSnapshot.swift:1274-1275`）。
- **提取方案**：在 SharedMetrics 定义 `PowerSourceLabel` 枚举（`adapterCharging/adapter/battery/ups/external/notReported`），`MetricSnapshot` 增加 `powerSourceLabel: PowerSourceLabel` 计算属性（封装 switch）。shared 的 `powerSourceText` 与 widget 的 `compactPowerStatusText` 各自 `PowerSourceLabel → String` 查表。
- **类型适配**：纯 Foundation 枚举。
- **优先级**：**R-低**（逻辑重复但输出刻意不同，提取骨架收益有限；widget 缩写是有意区分）

---

## 三、需保持独立的重复（及原因）

| 重复项 | 位置 | 保持独立原因 |
|--------|------|------------|
| **`StatusLevel` 枚举**（app） | `DashboardView.swift:1780-1803` | app 专属：携带 `.color`（→`DashboardColor`，AppKit/SwiftUI Color）和 `.text`（→`PulseDockAppStrings`）两个 app-only 关联值；widget/popover 无此枚举。⚠️ 但 `StatusLevel.neutral`→`blue` 是 **app 内部 bug**（与自身 `powerTint` 的 `.neutral`→`cyan` 矛盾，且与 popover/widget 的 unknown→cyan 矛盾），应在提取 R4-4/R4-5 时一并修正为 cyan。 |
| **`WidgetFreshnessTone` 枚举**（widget） | `WidgetVisualTokens.swift:6-37` | widget 专属：依赖 `WidgetTimelinePolicy.staleThreshold`/`agingThreshold`（widget 刷新策略）和 `WidgetColor`，app 无需 freshness 概念。 |
| **`Palette` dark/light 颜色函数**（popover） | `WidgetPanelView.swift:318-337` | popover 专属 SwiftUI Color 构造；若 R4-8 提取 RGB 数值到 shared，此 enum 可改为引用 shared 常量，但 `Color` 构造仍需在 app target 内（SharedMetrics 不引入 SwiftUI）。 |
| **`WidgetColor` dark/light 颜色函数**（widget） | `WidgetVisualTokens.swift:39-58` | 同上，widget 专属。 |
| **`DashboardColor` 单值颜色**（app） | `DashboardVisualTokens.swift:53-65` | app 专属，且用 `Color(nsColor:)` 桥接 AppKit 系统色（`windowBackgroundColor`/`textBackgroundColor` 等），这些是 app 窗口 chrome 专属，widget/popover 不需要。语义色（blue/green/...）部分可引用 shared RGB（R4-8），系统色部分保持独立。 |
| **`localized` 函数**（三处） | `PulseDockAppStrings.swift:1338` / `PulseDockWidgetStrings.swift:116` / `SharedMetricStrings.swift:391` | 每处的 `table` 名（"PulseDockApp"/"PulseDockWidget"/"SharedMetrics"）是模块本地化资源标识，不可共享。bundle 默认值也不同（`.pulseDockAppLocalization`/`.pulseDockWidgetLocalization`/`.sharedMetricsLocalization`）。 |
| **`DashboardLayout`/`DashboardSpacing`/`DashboardTypography`**（app） | `DashboardVisualTokens.swift:3-51` | app 窗口专属布局（`minimumContentSize`/`sidebarWidth`/`compactBreakpoint` 等），widget/popover 尺寸完全不同。`DashboardSpacing`(3/4/8/12/16/24) 虽是通用间距，但 widget 用 inline 字面量且无 enum，token 化需同时改 widget，收益低。 |
| **`MenuPopoverLayout`**（popover） | `WidgetPanelView.swift:6-11` | popover 专属尺寸（width=356/height=520），app/widget 不共享。 |
| **`normalizedRate` alias**（app+popover） | `DashboardView.swift:2148` / `WidgetPanelView.swift:132` | 非跨模块（仅 app target 内部）；是 `MetricScales.networkRateProgress` 的 1 行 alias，已在 SharedMetrics。widget 不需要（不渲染吞吐量进度条）。建议直接删除 alias，改为调用 shared 函数。 |
| **`compactPowerStatusText` 输出字符串**（widget） | `SystemDashboardWidget.swift:801-817` | widget 缩写（"Power"/"Charging"/"Battery"/"UPS"/"External Power"）与 shared 全称（"Power Adapter"/"Power Adapter (Charging)"/"Battery"/"UPS"/"External Power"）刻意不同，因 widget 空间受限。switch 骨架可提取（R4-10），但字符串集保持独立。 |
| **`networkRateProgress`（log10）vs `networkPathProgress`（线性）** | `MetricScales.swift:6` vs `DashboardView.swift:2252`/`SystemDashboardWidget.swift:758` | **非重复**：`networkRateProgress` 度量吞吐量量纲（bytes/sec→0..1），`networkPathProgress` 度量连接质量（状态→0/0.45/1）。两者度量不同对象，不应合并。`networkPathProgress` 本身的 app↔widget 重复由 R4-3 处理。 |
| **`popoverPanelFill`/`widgetPanelFill`/`popoverPrimaryText`/`widgetPrimaryText` 等 surface 色** | `WidgetPanelView.swift:287-309` / `WidgetVisualTokens.swift:77-99` | 各 surface 的背景/描边/文本色依赖各自容器设计（popover 在 NSPopover 内、widget 在 WidgetKit 容器内），透明度与底色不同，刻意区分。 |

---

## 四、与 REVIEW-PLAN.md / LOGIC-CONSISTENCY-REVIEW-PLAN.md 重叠项

| 本报告条目 | 重叠项 | 关系 |
|-----------|--------|------|
| R4-1 (reportedProgress) | `REVIEW-PLAN.md` P2-4；`REDUNDANCY-REVIEW-PLAN.md` [ANCHOR-R2-1] | 本报告确认三处逐字符相同，提供提取方案与 SharedMetrics 落点 |
| R4-2 (progressFillWidth) | `REVIEW-PLAN.md` P2-4；`REDUNDANCY-REVIEW-PLAN.md` [ANCHOR-R2-1] | 同上 |
| R4-3 (networkPathProgress) | `LOGIC-CONSISTENCY-REVIEW-PLAN.md` L4-6（`networkPathProgress` 返回非 Optional）；`REDUNDANCY-REVIEW-PLAN.md` [ANCHOR-R2-2] | 本报告确认 app↔widget 完全相同，提取到 `NetworkPathState.progress`；L4-6 的"非 Optional"问题独立存在（提取后仍需决定是否改 Optional） |
| R4-4 (thermal→色调) | `LOGIC-CONSISTENCY-REVIEW-PLAN.md` [ANCHOR-B1]（thermal 死分支 fair/serious）；`REDUNDANCY-REVIEW-PLAN.md` [ANCHOR-R2-2] | **本报告新发现**：除死分支外，`hot` 归类在三处语义分歧（app=warning vs popover/widget=critical），是跨模块颜色不一致的根因。提取 `semanticTone` 时需先决策 hot 归类。 |
| R4-5 (network→色调) | `LOGIC-CONSISTENCY-REVIEW-PLAN.md` [ANCHOR-B2]（network path 变体冗余）；`REDUNDANCY-REVIEW-PLAN.md` [ANCHOR-R2-2] | **本报告新发现**：`unknown` 色调在 app=blue vs popover/widget=cyan，根因是 app `StatusLevel.neutral`→`DashboardColor.blue`。 |
| R4-6 (thermal→progress) | `LOGIC-CONSISTENCY-REVIEW-PLAN.md` [ANCHOR-B1] | 本报告建议提取到 `ThermalState.progress`，消除 app 内字面量 switch |
| R4-7 ("Not reported") | `REVIEW-PLAN.md` P2-5（硬编码话术）；`LOGIC-CONSISTENCY-REVIEW-PLAN.md` L1-9（双术语）；`REDUNDANCY-REVIEW-PLAN.md` [ANCHOR-R2-5] | 本报告确认三处 default 相同，提供合并到 `SharedMetricStrings.notReported` 的方案与本地化翻译核对风险 |
| R4-8 (语义颜色 RGB) | `REVIEW-PLAN.md` P2-4（Palette 重复）；`REDUNDANCY-REVIEW-PLAN.md` [ANCHOR-R2-3] | **本报告新发现**：light RGB 三处完全一致（同源证据），dark RGB Palette↔WidgetColor 存在微差（漂移证据），app 完全无 dark 适配 |
| R4-9 (powerStatusTone→色调) | `LOGIC-CONSISTENCY-REVIEW-PLAN.md` [ANCHOR-C3]（powerStatusText 优先级歧义） | 本报告确认三处 tone→Color 语义一致（无分歧），提取收益低；C3 的优先级歧义是独立设计问题 |
| R4-10 (powerSource switch) | `LOGIC-CONSISTENCY-REVIEW-PLAN.md` L4-13（compactPowerStatusText 同状态两套输出） | 本报告确认 switch 骨架可提取，字符串集刻意区分保持独立 |
| normalizedRate alias | `REVIEW-PLAN.md` P2-4；`REDUNDANCY-REVIEW-PLAN.md` [ANCHOR-R2-1] | 本报告判定**非跨模块重复**（仅 app target 内，widget 无此函数），建议直接删除 alias 调用 shared |
| 格式化 locale | `REVIEW-PLAN.md` P3（C locale vs Locale.current 混用）；`LOGIC-CONSISTENCY-REVIEW-PLAN.md` L3-13 | 本报告确认 `MetricFormatting` 6 处 `String(format:)` 未传 locale，与 `localizedFormat` 的 `Locale.current` 不一致；建议统一传 `Locale.current` |
| StatusLevel.neutral→blue | — | **本报告新发现**：app 内部 `StatusLevel.neutral`→`blue`(`DashboardView.swift:1791`) 与自身 `powerTint` 的 `.neutral`→`cyan`(`DashboardView.swift:2285`) 矛盾，且与 popover/widget 的 unknown→cyan 矛盾。是 R4-4/R4-5 跨模块分歧的 app 侧根因。 |

---

## 五、提取优先级汇总

| ID | 名称 | 优先级 | 前置条件 |
|----|------|--------|---------|
| R4-3 | networkPathProgress → `NetworkPathState.progress` | **R-高** | 无 |
| R4-4 | thermal→色调 → `ThermalState.semanticTone` | **R-高** | 需产品确认 `hot` 归 warning 还是 critical |
| R4-5 | network→色调 → `NetworkPathState.semanticTone` | **R-高** | 需修正 app `StatusLevel.neutral`→blue 改 cyan |
| R4-1 | reportedProgress → `MetricScales.reportedProgress` | **R-中** | 无 |
| R4-2 | progressFillWidth → `MetricScales.progressFillWidth` | **R-中** | SharedMetrics 加 `import CoreGraphics` |
| R4-7 | "Not reported" 合并到 `SharedMetricStrings.notReported` | **R-中** | 核对三套 strings 表翻译一致性 |
| R4-8 | 语义颜色 RGB 提取到 `SemanticColorComponents` | **R-中** | 确认 dark RGB 差异是漂移（建议统一为 widget 值） |
| R4-6 | thermal→progress → `ThermalState.progress` | **R-低** | 与 R4-4 一并实施 |
| R4-9 | powerStatusTone→色调 | **R-低** | 需引入 `SemanticColorName` 中间枚举 |
| R4-10 | powerSource switch 骨架 | **R-低** | 需引入 `PowerSourceLabel` 枚举 |

**建议实施顺序**：
1. 先修 `StatusLevel.neutral`→blue 改 cyan（app 内 bug，独立修复，无 API 变更）
2. R4-3（`NetworkPathState.progress`）+ R4-1/R4-2（`MetricScales` 两个函数）——纯数值，无 Color 依赖，风险最低
3. R4-4/R4-5（`semanticTone`）——需先决策 hot 归类，但修复后消除跨 surface 颜色分歧
4. R4-7（"Not reported" 合并）——需核对翻译
5. R4-8（颜色 RGB）——需确认 dark 漂移判定
6. R4-6/R4-9/R4-10——边际收益项，随其他提取一并落地

---

## 六、模块边界约束验证

| 提取项 | 落点 | app 可用 | widget 可用 | 边界合规 |
|--------|------|---------|------------|---------|
| R4-1 reportedProgress | `MetricScales` (SharedMetrics) | ✅ | ✅ | ✅ |
| R4-2 progressFillWidth | `MetricScales` (SharedMetrics, +CoreGraphics) | ✅ | ✅ | ✅ |
| R4-3 NetworkPathState.progress | `MetricStateContracts` (SharedMetrics) | ✅ | ✅ | ✅ |
| R4-4 ThermalState.semanticTone | `MetricStateContracts` (SharedMetrics) | ✅ | ✅ | ✅ |
| R4-5 NetworkPathState.semanticTone | `MetricStateContracts` (SharedMetrics) | ✅ | ✅ | ✅ |
| R4-6 ThermalState.progress | `MetricStateContracts` (SharedMetrics) | ✅ | ✅ | ✅ |
| R4-7 notReported | `SharedMetricStrings` (SharedMetrics) | ✅ | ✅ | ✅ |
| R4-8 SemanticColorComponents | 新文件 (SharedMetrics, 纯数值) | ✅ | ✅ | ✅（不引入 SwiftUI） |
| R4-9 SemanticColorName | 新枚举 (SharedMetrics) | ✅ | ✅ | ✅ |
| R4-10 PowerSourceLabel | 新枚举 (SharedMetrics) | ✅ | ✅ | ✅ |
| StatusLevel 枚举 | 保持 app 专属 | — | — | ✅（app-only） |
| WidgetFreshnessTone | 保持 widget 专属 | — | — | ✅（widget-only） |
| Palette/WidgetColor Color 构造 | 保持各侧 | — | — | ✅（SwiftUI Color 留各侧） |
| localized 函数 | 保持各模块 | — | — | ✅（table 名模块专属） |

**结论**：全部 10 条可提取项均落在 SharedMetrics，app 与 widget 均可访问，不违反模块边界。需保持独立的 12 项均因"模块专属类型/资源/框架依赖"不可共享。SharedMetrics 维持 Foundation-only（R4-2 加 CoreGraphics 是更低层框架，不破坏约束；R4-8 用数值元组而非 Color，不引入 SwiftUI）。
