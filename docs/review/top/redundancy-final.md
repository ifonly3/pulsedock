# Pulse Dock 冗余与重复审查 — 顶层复核最终报告

> 审查日期：2026-06-28
> 审查方法：三层并行 review（4 子 agent 逐处 → 中层整合 → 顶层复核）
> 审查基准：当前 working tree（HEAD `876bcc2`）
> 前序 review：`docs/review/top/final-review-v2.md`（Bug 专项）、`docs/review/top/logic-consistency-final.md`（逻辑/数据一致性专项）
> 关联计划：`docs/review/REDUNDANCY-REVIEW-PLAN.md`、`docs/review/middle/redundancy-integrated.md`

---

## 一、审查概要

| 维度 | 数值 |
|------|------|
| 子 agent 数 | 4（R1 信息冗余 / R2 代码重复 / R3 死状态 / R4 跨模块重复） |
| 原始发现 | 66 条 |
| 去重后有效发现 | 52 条（R-高:7 / R-中:18 / R-低:27） |
| 跨模块系统性问题 | 4 组 |
| 新发现（不在前两次审查内） | 35 条 |
| 前次审查已修复确认 | 1 条（"No Battery" 分支已删除） |

---

## 二、顶层复核修正

### 2.0 当前执行基准修正

本轮执行前复核以当前实现为准：HEAD `876bcc2`。normalizedRate 仅 2 处本地包装；widgetCompact 20 个死字段仍待裁剪；R1-3 是规则语义重复，不是逐字符重复。

### 2.1 锚点纠正（2 条）

| 锚点 | 计划描述 | 实际代码 | 处置 |
|------|---------|---------|------|
| [ANCHOR-R2-1] normalizedRate 三处 | "三处独立维护" | **实际仅 2 处**：DashboardView.swift:2148 + WidgetPanelView.swift:132。SystemDashboardWidget 未定义此函数（直接内联 MetricScales.networkRateProgress） | 修正为 2 处，降级为 R-中 |
| [ANCHOR-R3-3] "No Battery" 死分支 | "不可达，本地化字符串永不展示" | **当前代码已修复**：powerSourceNoBattery 已从 SharedMetricStrings 移除，case .some 改为 powerSourceExternal | 标记已修复 |

### 2.2 真冗余 vs 有意冗余裁定

| 发现 | 裁定 | 理由 |
|------|------|------|
| R1-1 侧栏 vs 顶栏 sampleTimeText | **真冗余** | 同窗口同可见，顶栏 chip 相对侧栏无新增价值 |
| R1-3 Sensors/History 规则表 | **真冗余** | 4 行规则语义重复；History 的前三行标题更具体，并非逐字符重复 |
| R1-6 Sensors 同页 8 项重叠 | **真冗余** | 表与卡片展示相同值，信息增量极低 |
| R1-4 Overview 趋势 ⊂ History | **真冗余**（但需权衡） | 5 行是 History 8 行的纯子集，但 Overview 有"首屏概览"体验价值 |
| 侧栏 CPU/Mem/Disk 常驻 | **有意冗余** | 切页时常驻可见，在 Network 页也能看 CPU |
| Widget 与 app 同一数据点 | **有意冗余** | 跨进程无法共享视图 |
| Popover 与 dashboard 同一数据点 | **有意冗余** | 不同入口点，用户可能仅开 popover |
| MetricCard badgeText 重复 value | **有意冗余** | 视觉层级设计（大数+徽章） |
| Widget 缩写 vs app 全称 | **有意冗余** | 空间约束 |

### 2.3 新发现（不在前两次审查内）

| 发现 | 严重度 | 说明 |
|------|--------|------|
| R4-4 thermal hot 归类跨 surface 分歧 | R-高 | app=warning(amber) vs popover/widget=critical(red) |
| R4-5 network unknown 色调跨 surface 分歧 | R-高 | app=blue vs popover/widget=cyan |
| StatusLevel.neutral→blue app 内 bug | R-高 | 同一 .neutral 映射到 blue 和 cyan 两个颜色 |
| R1-6 Sensors 同页 8 项重叠 | R-高 | 单点冗余量最大 |
| R2-9 dark RGB 漂移 | R-高 | Palette ↔ WidgetColor dark 值微差 |
| R3-2 widgetCompact 20 死字段 | R-低 | 载荷浪费 ~30-40% |
| R1-3 规则表跨页重复 | R-高 | 4 行规则语义重复；不是逐字符重复 |

---

## 三、最终问题清单（按优先级）

### R-高 — 用户可感知的冗余或跨 surface 不一致（7 条）

#### 信息冗余（2 条）

| # | 位置 | 问题 | 修复方向 | 工作量 |
|---|------|------|----------|--------|
| R1-3 | `DashboardView.swift:967-978` vs `:1069-1080` | 同一规则表在 Sensors 页与 History 页重复展示相同当前阈值判断；History 的前三行标题更具体，并非逐字符重复 | 移除 History 页规则表（History 页独有价值是阈值滑块编辑，已由 :1061-1067 覆盖） | 0.1d |
| R1-6 | `DashboardView.swift:980-997` vs `:1011-1027` | Sensors 页 SystemSignals 表与 realtimeSignalsPanel 同页 8 项重叠（osVersion/uptime/load/power/network/display/gpu/storage） | 合并为一个面板（保留信号卡含状态徽章，补充 kernelText；移除信号表） | 0.3d |

#### 代码重复 + 跨 surface 分歧（5 条）

| # | 位置 | 问题 | 修复方向 | 工作量 |
|---|------|------|----------|--------|
| RD-3 | `DashboardView.swift:2252` + `SystemDashboardWidget.swift:758` | networkPathProgress app↔widget 逐字符相同，0.45 魔法数两处独立维护 | 提取到 `NetworkPathState.progress` 计算属性（SharedMetrics） | 0.1d |
| RD-7 | `DashboardView.swift:2321` vs `WidgetPanelView.swift:159` vs `SystemDashboardWidget.swift:736` | thermal→色调三处语义分歧：app hot=warning(amber)，popover/widget hot=critical(red)。同设备跨 surface 颜色不一致 | 提取 `ThermalState.semanticTone` 到 SharedMetrics，统一 hot=critical；需产品确认 | 0.3d |
| RD-8 | `DashboardView.swift:2235` vs `WidgetPanelView.swift:168` vs `SystemDashboardWidget.swift:745` | network→色调 unknown 分歧：app=blue，popover/widget=cyan。根因：app `StatusLevel.neutral`→`DashboardColor.blue`（:1791）与自身 `powerTint` 的 .neutral→cyan（:2285）矛盾 | 修正 StatusLevel.neutral→blue 改 cyan；提取 `NetworkPathState.semanticTone` | 0.2d |
| RD-4 | `DashboardVisualTokens.swift:53` + `WidgetPanelView.swift:318` + `WidgetVisualTokens.swift:39` | 三套颜色 tokens：light RGB 一致（同源），dark RGB Palette↔WidgetColor 漂移，DashboardColor 完全无 dark 适配 | 提取 light/dark RGB 到 SharedMetrics `SemanticColorComponents`；统一 dark 值（建议用 WidgetColor 值）；给 DashboardColor 补 dark 分支 | 0.5d |
| RD-1 | `DashboardView.swift:2152` + `WidgetPanelView.swift:136` + `SystemDashboardWidget.swift:771` | reportedProgress 三处逐字节相同 | 提取到 `MetricScales.reportedProgress`（SharedMetrics） | 0.1d |

### R-中 — 维护风险或跨页面冗余（18 条）

#### 信息冗余（4 条）

| # | 位置 | 问题摘要 |
|---|------|---------|
| R1-1 | `DashboardView.swift:333` vs `:409` | 侧栏 sampleTimeText 与顶栏 chip 同窗口双重常驻 |
| R1-2 | `DashboardView.swift:560,840` vs `:409` | CPU/Power 页"Recent Sample"行与常驻顶栏 chip 重复 |
| R1-4 | `DashboardView.swift:468-472` vs `:1050-1057` | Overview 趋势 5 行是 History 趋势 8 行的纯子集 |
| R1-5 | `DashboardView.swift:1195,1198` vs `:1166,1141` | Settings widget 预览 Refresh/MainWindow 行与左面板控件重复 |

#### 代码重复（10 条）

| # | 位置 | 问题摘要 |
|---|------|---------|
| RD-2 | 三处 progressFillWidth | 完全相同，提取到 MetricScales（+CoreGraphics） |
| RD-5 | 三套 "Not reported" | default 相同，合并到 SharedMetricStrings.notReported |
| RD-6 | 三处 powerTint | 语义一致，仅色源不同；提取 tone→Color 映射 |
| RD-9 | 两处 normalizedRate | 零附加值 alias，直接删除调用 MetricScales |
| R2-10 | popover/widget 表面色 helper | primary/secondary 文本色逐字节相同；panelFill opacity 不同 |
| R2-14 | StatusDot 三处 | app 抽象为 StatusDot，popover/widget 内联手写，尺寸/shadow 不一致 |
| R2-15 | PopoverMetricRow/WidgetRow | 进度条绘制逻辑完全相同，提取 MetricProgressBar |
| R2-17 | thermalStatus/thermalProgress | 魔法数 0.78/0.52/0.24 应上移到 ThermalState.progress |
| R2-18 | 三套背景渐变 | widgetPreviewBackgroundColors 应与 widgetBackgroundColors 对齐 |
| R2-4/R2-5/R2-6 | thermalTint/networkTint/powerTint | 见 RD-7/RD-8/RD-6 |

#### 代码重复（续）

| # | 位置 | 问题摘要 |
|---|------|---------|
| R2-12 | 三处 localized 函数 | 实现相同，可提取公共 helper（table 名保持各模块） |
| R2-13 | 两处 localizedFormat | 完全相同 |
| R2-19 | trend 提取器调用不一致 | Overview 用默认重载，History 显式传 keyPath，结果相同 |

### R-低 — 死状态/死字段/死资源（27 条）

#### 死状态（1 条）

| # | 位置 | 问题摘要 |
|---|------|---------|
| R3-1 | `MetricsStore.swift:47` | isRefreshing 被赋值但无任何视图消费，可安全删除 |

#### 死字段（20 条，当前代码）

| # | 位置 | 问题摘要 |
|---|------|---------|
| R3-2 | `MetricSnapshot+WidgetCompact.swift` | 20 字段保留但 widget 从不读取：cpuCoreUsages/physicalCoreCount/memoryFree/Wired/Compressed/Cached/Swap×3/hasMemoryCompositionReport/loadAverage5/15/batteryTimeRemaining/CycleCount/Health/CurrentCapacity/MaxCapacity/DesignCapacity/Voltage/Amperage。初版报告列入的 networkBytesPerSecond/hasNetworkByteCounters/hasNetworkDirectionByteCounters/networkIn/OutBytesPerSecond 已不在当前 compact 投影中。裁剪可降低 App Group 载荷。 |

#### 死 UI / 死资源（2 条）

| # | 位置 | 问题摘要 |
|---|------|---------|
| R3-5 | `AppDelegate.swift:152-153` | Undo/Redo 菜单永远禁用（无文本编辑表面），约定性样板 |
| R3-4 | `design/` vs `designs/` | 两套设计资产目录冗余（25 PNG 重复主题），建议合并 |

#### 信息冗余（3 条 R-低）

| # | 位置 | 问题摘要 |
|---|------|---------|
| R1-7 | `DashboardView.swift:453` vs `:1191` | WidgetMiniPreview 在 Overview 与 Settings 完全相同渲染两次 |
| R1-8 | `DashboardView.swift:708` vs `:716` | Network 页连接状态 MetricCard 与连通性表首行重复 |
| R1-9 | `DashboardView.swift:837-840` vs `:480-481` | Power 页 thermalPanel 错位放置 uptime/sampleTime（与 Overview 重复） |

#### 代码重复（5 条 R-低）

| # | 位置 | 问题摘要 |
|---|------|---------|
| R2-8 | 两处 reportedTint | 签名略不同，语义相同 |
| R2-16 | 三套小状态卡 | PopoverSmallStat/MiniStatus/StatTile 布局差异大，圆点可随 R2-14 合并 |
| R4-6 | thermalProgress 仅 app | 魔法数应上移到 ThermalState.progress（随 RD-7 一并） |
| R4-9 | powerStatusTone→色调 | 三处语义一致，提取收益低 |
| R4-10 | powerSource switch 骨架 | shared vs widget，字符串集刻意不同 |

---

## 四、修复优先级与工作量汇总

| 优先级 | 项数 | 总工作量估算 | 建议批次 |
|--------|------|-------------|---------|
| R-高 | 7 | ~1.6 人日 | 第一批：RD-3/RD-1（纯数值提取 0.2d）+ R1-3（移除重复表 0.1d）+ RD-8（StatusLevel 修正 0.2d）+ R1-6（合并 Sensors 面板 0.3d）+ RD-7（thermal 统一 0.3d）+ RD-4（颜色 tokens 0.5d） |
| R-中 | 18 | ~2 人日 | 第二批：RD-2/RD-5/RD-6/RD-9（提取到 SharedMetrics 0.4d）+ R1-1/R1-2/R1-5（移除重复行 0.2d）+ R2-14/R2-15/R2-17/R2-18（组件/渐变统一 0.5d）+ R1-4（Overview 趋势 0.3d）+ R2-10/R2-12/R2-13（helper 合并 0.3d）+ R2-19（调用统一 0.1d）+ R2-4/R2-5/R2-6（随 RD-7/RD-8/RD-6） |
| R-低 | 27 | ~1.5 人日 | 第三批：R3-1（删 isRefreshing 0.1d）+ R3-2（裁剪 20 死字段 0.3d）+ R3-4（合并 design 目录 0.1d）+ R1-7/R1-8/R1-9（移除低冗余 0.2d）+ R2-8/R2-16/R4-6/R4-9/R4-10（择机处理 0.5d）+ R3-5（保留 Undo/Redo 样板） |
| **合计** | **52** | **~5 人日** | — |

---

## 五、跨模块系统性问题修复建议

### 系统性问题 1：三套颜色 tokens + dark 漂移
**一次性修复**：提取 `SemanticColorComponents`（纯数值元组）到 SharedMetrics；统一 dark 值（建议用 WidgetColor 值）；给 DashboardColor 补 dark 分支。
**工作量**：0.5d

### 系统性问题 2：thermal/network 色调跨 surface 分歧
**一次性修复**：先修 `StatusLevel.neutral`→blue 改 cyan（app 内 bug，0.1d）；再提取 `ThermalState.semanticTone` + `NetworkPathState.semanticTone` 到 SharedMetrics；统一 hot=critical（需产品确认）。
**工作量**：0.5d

### 系统性问题 3：Sensors 页同页 8 项重叠
**一次性修复**：合并 SystemSignals 表与 realtimeSignalsPanel 为一个面板。
**工作量**：0.3d

### 系统性问题 4：widgetCompact 20 死字段
**一次性修复**：从 widgetCompactSnapshot() 将 20 字段降级为 nil/0/[]/false。
**工作量**：0.3d

---

## 六、strengths（值得保留的设计优点）

- widgetCompact 裁剪了 gpuDevices/displays/storageVolumes/runningApps/networkInterfaces（大列表字段），仅保留 widget 渲染所需
- `MetricScales.networkRateProgress`（log10 对数缩放）作为单一来源被 app/popover 正确引用
- `ThermalState`/`NetworkPathState`/`MetricStatusTone` 枚举已在 SharedMetrics 定义，为提取 semanticTone 提供了基础
- `MetricSnapshot.canonicalNetworkPathState` 已封装字符串→枚举转换，消除字面量匹配风险
- 跨进程/widget/popover 的数据展示重复属有意冗余（无法共享视图）
- 侧栏 CPU/Mem/Disk 常驻属有意冗余（切页时常驻可见）
- 前次 LOGIC-CONSISTENCY L4-7 的 "No Battery" 死分支已修复确认

---

## 七、验证命令

```bash
swift build
swift test
```

---

## 八、约束与边界

- 本审查为只读，未修改任何源码
- 与 `final-review-v2.md`（Bug 专项）和 `logic-consistency-final.md`（逻辑/数据一致性专项）互补
- 修复建议优先选择"提取到 SharedMetrics"而非"再复制一份"
- 区分"真冗余"与"有意冗余"：跨进程/跨入口/切页常驻属有意冗余
- SharedMetrics 维持 Foundation-only（R4-2 加 CoreGraphics 是更低层框架，不破坏约束；颜色用数值元组而非 Color，不引入 SwiftUI）

---

**审查完成。** 本报告与 `docs/review/middle/redundancy-integrated.md` 及 4 份子报告共同构成完整审查交付物。
