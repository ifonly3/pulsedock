# Pulse Dock 深度代码审查计划 — 逻辑一致性与数据一致性专项

> 制定日期：2026-06-28
> 审查目标：系统性发现**逻辑不通顺的话术矛盾**、**数据流不一致**、**不合理设计**三类问题
> 审查基准：当前 working tree（HEAD `9db73ee`，含 stability-optimization Task 1-8 落地）
> 关联资产：
> - `docs/review/REVIEW-PLAN.md`（2026-06-27，Bug 与设计缺陷专项 —— 本计划与之互补，不重复其崩溃/性能/并发审查）
> - `docs/review/middle/integrated-review-v2.md`、`docs/review/top/final-review-v2.md`（前次审查产出）
> - `docs/superpowers/plans/2026-06-27-pulse-dock-stability-optimization.md`

---

## 一、定位与边界

本计划**不重复** `REVIEW-PLAN.md` 已覆盖的崩溃/资源泄漏/并发/性能问题，而是聚焦三类"静态分析难以发现、需要人/agent 逐句对照才能识别"的语义层缺陷：

| 类别 | 定义 | 典型症状 |
|------|------|----------|
| A. 话术逻辑矛盾 | 同一事实在 UI 不同位置/文档/代码中以相互冲突的方式表达 | 设置页同屏一处写 `"5m"`、另一处写 `"System Scheduled"`、详情文案写 `"Scheduled by the system timeline"` |
| B. 数据一致性 | 数据从产生（sampler）→ 模型（snapshot）→ 持久化（store）→ 消费（UI/widget）链路中，字段语义、取值集合、大小写、单位、报告状态判定不一致 | sampler 输出 Title-case `Nominal/Warm/Hot/Critical/Unknown`，下游用小写匹配并包含 sampler 永不产生的 `"fair"/"serious"` 死分支 |
| C. 不合理设计 | 设计选择在语义上自相矛盾或与平台契约不符，且无法用"性能/安全"解释 | widget freshness 窗口 600s 大于刷新间隔 300s，导致 10 分钟内展示过期数据无任何 staleness 指示 |

**与 `REVIEW-PLAN.md` 的关系**：前次审查的 P2-3（字符串契约死分支）、P2-6（`"5m"` 与 `"System Scheduled"` 矛盾）已点到为止；本计划将其升级为**独立审查维度**，逐句扫描全部话术与数据字段，目标是从"已知 2 条"扩展到"全量清单"。

---

## 二、审查范围

| 模块 | 路径 | 话术/数据相关重点文件 |
|------|------|----------------------|
| SharedMetrics | `Sources/SharedMetrics/` | `SystemSampler.swift`(1411) 事实来源 · `MetricSnapshot.swift`(1763) 派生文本与报告状态判定 · `SharedMetricStrings.swift`(423) 共享话术 · `SharedSnapshotStore.swift`(74) 持久化契约 · `MetricSnapshot+WidgetCompact.swift`(62) 裁剪契约 · `MetricFormatting.swift`(98) 单位/格式 · `MetricScales.swift`(16) 量纲 |
| PulseDockApp | `Sources/PulseDockApp/` | `PulseDockAppStrings.swift`(1379) app 话术 · `DashboardView.swift`(2337) 话术消费 + 派生文本（thermalStatus/networkStatusLevel 等）· `WidgetPanelView.swift`(339) 重复派生 · `AppDelegate.swift`(501) 菜单话术 |
| PulseDockWidget | `Sources/PulseDockWidget/` | `SystemDashboardWidget.swift`(757) timeline 契约 + 重复派生 · `PulseDockWidgetStrings.swift`(129) widget 话术 |
| 文档/资产 | `docs/`、`Resources/` | `docs/data-capability-audit.md`(551) 能力声明 vs 实际行为 · `Resources/*/Info.plist` 用户可见文案 · 本地化 strings 表 |

---

## 三、探索阶段已确认的锚点发现（种子清单）

> 以下为本次探索已对照源码确认的具体问题，作为各子任务的起始线索。标注 `[ANCHOR]` = 已直接定位到行号。

### A 类 — 话术逻辑矛盾

- **[ANCHOR-A1] Widget 刷新话术三处不一致**：
  - `Sources/PulseDockApp/DashboardView.swift:1167` — Refresh & Display 面板用硬编码 `"5m"` 作为只读控件值
  - `Sources/PulseDockApp/PulseDockAppStrings.swift:1019` — 同一行 detail = `"Scheduled by the system timeline"`
  - `Sources/PulseDockApp/PulseDockAppStrings.swift:1055` — Widget 预览面板 = `"System Scheduled"`
  - 矛盾：`"5m"` 暗示 app 承诺的固定 5 分钟刷新；`"Scheduled by the system timeline"` / `"System Scheduled"` 说明实际由系统调度（app 仅通过 `getTimeline` 的 `.after(nextRefresh)` 请求）。同屏两个面板对同一事实给出冲突语义。实参见 `Sources/PulseDockWidget/SystemDashboardWidget.swift:58` —— 5 分钟只是请求值，系统可延后。
  - 待审延伸：是否存在其他"设置页只读控件值"与"相邻 detail 文案"语义冲突的同类模式。

- **[ANCHOR-A2] 电源状态 `No Battery` 与报告状态判定自相矛盾**：
  - `Sources/SharedMetrics/MetricSnapshot.swift:1272-1274` —— `batteryPercent == nil` 且 `batteryPowerSource != nil` 时 `powerSourceText` 返回 `"No Battery"`（`SharedMetricStrings.powerSourceNoBattery`）
  - `Sources/SharedMetrics/MetricSnapshot.swift:1282-1284` —— `hasPowerStatusReport = batteryPercent != nil || batteryPowerSource != nil`
  - 矛盾：当 `batteryPowerSource` 已报告（如台式机接适配器）时，`hasPowerStatusReport` 判定为"已报告"，但展示文案却是 `"No Battery"`。用户看到"未报告电池"却同时看到数据源标记"已报告"。
  - 待审延伸：UPS / 纯适配器 / 无电池台式机场景下文案是否准确。

- **[ANCHOR-A3] widget 预览描述与实际刷新机制措辞需对照**：
  - `Sources/PulseDockApp/PulseDockAppStrings.swift:745` — `widgetPreviewDescription = "The widget refreshes core status on the system timeline for quick local status checks."`
  - 需对照 widget `getTimeline` 实际行为（含 fallback 路径）是否与"core status"措辞范围一致（fallback 时 GPU/displays/storageVolumes 被裁剪）。

### B 类 — 数据一致性

- **[ANCHOR-B1] Thermal 字符串契约死分支**：
  - `Sources/SharedMetrics/SystemSampler.swift`（`sampleThermalState`）输出 Title-case：`Nominal/Warm/Hot/Critical/Unknown`（参见前次 review `integrated-review-v2.md:60`）
  - `Sources/SharedMetrics/MetricSnapshot.swift:1231-1256` — `thermalText`/`hasThermalStateReport`/`thermalLimitText` 用 `.lowercased()` 匹配，分支含 `"fair"`/`"serious"`
  - `Sources/PulseDockApp/DashboardView.swift:2321-2332`、`Sources/PulseDockApp/WidgetPanelView.swift:161-162`、`Sources/PulseDockWidget/SystemDashboardWidget.swift:676-677` — 同样含 `"fair"`/`"serious"`
  - 不一致：sampler 永不输出 `fair`/`serious`（已预映射为 Warm/Hot），四处死分支永远不命中；任一方改大小写即静默落入 `default`，无编译期保护。

- **[ANCHOR-B2] Network path 字符串契约变体冗余**：
  - `Sources/SharedMetrics/SystemSampler.swift:198-199` — 仅输出 `"requiresConnection"`
  - `Sources/SharedMetrics/MetricSnapshot.swift:1334,1349,1361`、`Sources/PulseDockApp/DashboardView.swift:2238,2253`、`Sources/PulseDockApp/WidgetPanelView.swift:173`、`Sources/PulseDockWidget/SystemDashboardWidget.swift:688,701` — 同时匹配 `"requiresconnection"`/`"requires_connection"`/`"requires connection"` 三种变体
  - 不一致：sampler 只产出一种，其余两种是防御性历史残留；说明上下游对"权威字符串"无单一来源，靠穷举变体兜底。

- **[ANCHOR-B3] widgetCompactSnapshot 裁剪契约与 widget 读取契约未类型化对齐**：
  - `Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift:4-60` 手工列举裁剪字段
  - widget 侧仍读取 `storageVolumes`/`networkInterfaces` 等被裁空的字段，依赖 fallback 行为（前次 review 子任务 02 已标注，需确认当前是否仍存在读取-裁空-静默回退链路）

- **[ANCHOR-B4] Not-reported 判定靠多语言字面量穷举**：
  - `Sources/SharedMetrics/SharedMetricStrings.swift:376-389` — `isNotReportedText`/`isOtherText` 通过比对 `legacyEnglishNotReported`/`legacyChineseNotReported`/`legacyEnglishOther`/`legacyChineseOther` 判定
  - 不一致：报告状态判定依赖"展示文本"而非"结构化标志"，本地化文案一旦变更（或新增语言）即失效。

### C 类 — 不合理设计

- **[ANCHOR-C1] Widget freshness 窗口 > 刷新间隔**：
  - `Sources/PulseDockWidget/SystemDashboardWidget.swift:41` — `sharedSnapshotMaxAge = 600`
  - `Sources/PulseDockWidget/SystemDashboardWidget.swift:58` — `nextRefresh` = 5 分钟（300s）
  - 不合理：可接受数据最大年龄（600s）是请求刷新间隔（300s）的 2 倍 → 系统即使按时刷新，widget 仍可能展示最长 10 分钟前的数据，且无 staleness 视觉指示（`staleData` 文案存在但未消费，见 `PulseDockWidgetStrings.swift:108`）。

- **[ANCHOR-C2] 文档能力声明与实际行为漂移**：
  - `docs/data-capability-audit.md:183` 声称"Display metadata ... collected through a main-thread snapshot before CoreGraphics display rows are assembled. This preserves Retina scale ... when app sampling runs from detached tasks."
  - 需对照 `SystemSampler` 当前 NSScreen 主线程守卫实际行为（前次 review P0-1 已指出显示器元数据在 detached 采样下丢失，文档描述与实际不符）—— 本计划负责逐句核对文档每条声明与代码行为。

- **[ANCHOR-C3] `powerStatusText` 优先级歧义**：
  - `Sources/SharedMetrics/MetricSnapshot.swift:1279-1281` — `batteryPercent == nil ? powerSourceText : batteryPercentText`
  - 不合理：有电池百分比时只展示百分比、隐藏电源来源；无百分比时展示电源来源。两种状态下"Power Status"卡片语义不同（有时是电量、有时是电源类型），但共享同一标题 `powerStatusTitle`。

---

## 四、审查方法与子任务划分

沿用项目已验证的并行子 agent 结构，但按"话术/数据/设计"三维度切分，确保每类问题有专门 agent 用对应方法论审查。

```
顶层复核（本计划产出最终逻辑/数据一致性清单）
  ├─ 逐条对照源码验证子 agent 发现（重点排除"话术是产品刻意区分"的误判）
  ├─ 区分"真矛盾"与"有意区分"（如 mini 缩写 Pwr/Net/Mem vs 全称）
  └─ 生成 话术矛盾表 + 数据字段一致性矩阵 + 设计合理性评估
        ↑
中层整合（middle/logic-consistency-integrated.md）
  ├─ 收集 5 份子 agent 报告
  ├─ 跨模块话术对齐检查（同一概念在 app/widget/shared 三处话术表是否一致）
  ├─ 数据字段端到端追踪（sampler 输出集合 → snapshot 字段 → store schema → UI 消费）
  └─ 文档 vs 代码声明一致性核对
        ↑
子层逐句审查（subagents/logic-*, 并行）
  ├─ L1-copy-consistency.md    → 话术矛盾专项（app strings + widget strings + shared strings + 菜单 + plist）
  ├─ L2-data-contract.md       → 字符串契约 + 报告状态判定一致性
  ├─ L3-data-flow.md           → snapshot 字段端到端 + 裁剪契约 + 持久化 schema
  ├─ L4-design-semantics.md    → 不合理设计（窗口/优先级/语义复用同一标题等）
  └─ L5-doc-code-drift.md      → docs/data-capability-audit.md 逐句 vs 代码 + README 隐私声明 vs 行为
```

**并行执行要求**：5 个子 agent 在单消息中并发派发，每个指定 `very thorough`，返回 `file_path:line_number` 引用，prompt 末尾强制约束"**最终消息必须是完整报告，不得截断，不得以过渡语结尾**"。

---

## 五、子任务详细清单

### 子任务 L1 — 话术矛盾专项

**目标文件**：`PulseDockAppStrings.swift`、`PulseDockWidgetStrings.swift`、`SharedMetricStrings.swift`、`DashboardView.swift`（话术消费点）、`AppDelegate.swift`（菜单）、`Resources/*/Info.plist`

**审查方法**：
1. 建立概念词典：提取所有用户可见概念（刷新、采样、电源、电池、热状态、网络路径、数据源、报告状态等），列出每个概念在 app/widget/shared/文档中的全部文案变体。
2. 同屏/同卡片内矛盾扫描：对每个设置面板、每个 widget 尺寸、每个菜单，检查"标题 / detail / 控件值 / 预览值"是否对同一事实给出一致语义。
3. 跨模块同义对照：app 与 widget 对同一指标（如 CPU/Memory/Thermal）的缩写与全称是否"有意区分"还是"无意漂移"。

**必查项**：
- [ANCHOR-A1] widget 刷新三处话术
- [ANCHOR-A2] `No Battery` vs `hasPowerStatusReport`
- [ANCHOR-A3] widget 预览描述 vs 实际刷新范围
- `settingsWidgetSizesValue = "Small / Medium / Large"` vs widget 实际 supportedFamilies（是否包含/排除 ExtraLarge、accessory）
- `metricGPUDisplays = "GPU / Displays"`（app）vs `gpuUnifiedMemoryPanelTitle = "GPU & Unified Memory"`（app 内部两处 GPU 面板标题不一致）
- 菜单 `menuResumeRefresh = "Resume"` / `menuPauseRefresh = "Pause"` vs `menuStatusPaused`/`menuStatusLive` 状态文案是否在同一 popover 内冲突
- `processesDefaultSubtitle = "Foreground first, sorted by name"` vs 实际排序逻辑（`applyVisibleApplicationSummary`）是否一致
- `statusRealtimeSignalsSubtitle = "Latest sample"` vs `statusRulesSubtitle = "Local results for the current sample"` —— 两处描述同一样本，措辞差异是否构成用户困惑
- Info.plist 的 `NSHumanReadableCopyright` / `CFBundleDisplayName` / 描述文案与 README/隐私页是否一致

**输出**：话术矛盾表（概念 / 位置1 / 位置2 / 矛盾描述 / 是否有意区分 / 建议）

### 子任务 L2 — 字符串契约与报告状态一致性

**目标文件**：`SystemSampler.swift`（输出端）、`MetricSnapshot.swift`（派生 + 报告状态判定）、`DashboardView.swift`/`WidgetPanelView.swift`/`SystemDashboardWidget.swift`（消费端）

**审查方法**：
1. 对每个 sampler 输出的字符串字段（thermalState、batteryPowerSource、networkPathStatus、gpuKind、storageKind、displayTopology、processState 等），列出其**完整可能取值集合**。
2. 对每个下游匹配点，列出其 switch/case 分支集合。
3. 比对两集合：sampler 不产出但下游匹配的 = 死分支；sampler 产出但下游无分支的 = 静默落入 default 的漏分支。
4. 报告状态判定（`hasXxxReport`）的判定条件是否与"展示文案为 not-reported"的判定条件一致。

**必查项**：
- [ANCHOR-B1] thermal 死分支 `fair`/`serious`
- [ANCHOR-B2] network path 变体冗余 `requires_connection`/`requires connection`
- [ANCHOR-B4] `isNotReportedText`/`isOtherText` 多语言字面量穷举
- `powerSourceText` 的 `batteryPowerSource` 取值集合（`"AC Power"`/`"Battery Power"`/`"UPS Power"`）vs 下游 `.lowercased()` 匹配是否覆盖全部
- `hasThermalStateReport`（MetricSnapshot.swift:1240-1247）的判定集合与 `thermalText` 的展示集合是否完全一致
- gpuKind / storageKind / displayTopology 的 sampler 输出 vs 下游展示是否经过 SharedMetricStrings 集中映射

**输出**：字段一致性矩阵（字段 / sampler 输出集合 / 下游匹配集合 / 死分支 / 漏分支 / 报告状态判定是否对齐）

### 子任务 L3 — 数据字段端到端一致性

**目标文件**：`SystemSampler.swift`、`MetricSnapshot.swift`、`MetricSnapshot+WidgetCompact.swift`、`SharedSnapshotStore.swift`、`MetricsStore.swift`、widget 读取点

**审查方法**：
1. 列出 `MetricSnapshot` 全部字段及其"报告状态"派生属性。
2. 追踪每个字段从 sampler 赋值 → snapshot init → Codable 编解码 → store 持久化 → widget 读取的完整链路。
3. 检查：裁剪后字段是否被 widget 读取并依赖 fallback；编解码 `decodeIfPresent ?? derived` 模式是否与 init 默认值策略对称；单位/量纲（bytes vs GB、秒 vs 分钟、0-1 vs 0-100）在链路中是否一致。

**必查项**：
- [ANCHOR-B3] widgetCompactSnapshot 裁剪契约
- `MetricSnapshot.swift:1667-1752` Codable `decodeIfPresent ?? derived` vs init 默认值的 AND/OR 策略不一致（前次 review P2-14）
- `MetricScales.tenGigabitBytesPerSecond` 硬上限对 25/40/100 GbE 钳制是否与"展示实测速率"语义冲突
- `MetricFormatting` 的 `String(format:)` C locale vs `SharedMetricStrings.localizedFormat` 的 `Locale.current` 混用 → 同一数字在 app 不同位置格式不一致
- `batteryPercent` 0-1 vs 展示百分比 `MetricFormatting.percentage` 的量纲
- `networkBytesPerSecond` 是否在所有消费点用相同 scale 函数（`MetricScales.networkRateProgress`）

**输出**：字段端到端追踪表（字段 / sampler / init / Codable / store / widget / 单位一致性 / 报告状态一致性）

### 子任务 L4 — 设计语义合理性

**目标文件**：全模块，重点 `MetricSnapshot.swift`（派生属性）、`SystemDashboardWidget.swift`（timeline 契约）、`DashboardView.swift`（卡片语义）

**审查方法**：对每个"复用同一 UI 容器/标题/控件但语义随状态变化"的设计，评估是否构成用户困惑；对每个"阈值/窗口"设计，评估是否自相矛盾。

**必查项**：
- [ANCHOR-C1] freshness 600s > 刷新 300s
- [ANCHOR-C3] `powerStatusText` 优先级歧义（同一标题下有时展示电量、有时展示电源类型）
- `powerStatusTone`（MetricSnapshot.swift:1288-1323）色调语义：`batteryPercent < 0.2` → critical，但接适配器充电时 `batteryIsCharging` → normal 覆盖了低电量 —— 低电量充电时展示 normal 是否合理
- `networkPathProgress`（SystemDashboardWidget.swift:676-687）返回非 Optional Double → 未识别状态渲染空进度条而非 "Not reported"
- `Sparkline` 用 `values.suffix(80)` 但 trend 提取器遍历最多 360 snapshot —— 展示窗口与历史窗口语义是否对齐
- `processesForegroundAppsTitle` / `processesHiddenAppsTitle` / `processesRunningAppsTitle` / `processesListItemsTitle` 四个标题在 Apps 页是否语义重叠

**输出**：设计合理性评估表（设计点 / 语义冲突描述 / 用户影响 / 建议）

### 子任务 L5 — 文档与代码声明一致性

**目标文件**：`docs/data-capability-audit.md`（551 行）、`README.md`、`docs/app-store-readiness-checklist.md`、`docs/app-store-release-checklist.md`、`docs/privacy-policy/`

**审查方法**：逐句阅读 `data-capability-audit.md` 每条声明，对照 `SystemSampler`/`MetricSnapshot`/UI 当前行为，标注"声明 vs 行为"差异。

**必查项**：
- [ANCHOR-C2] `data-capability-audit.md:183` 显示器元数据主线程快照声明 vs 实际 detached 采样行为
- `data-capability-audit.md:207` "Network card progress bars may use normalized baselines ... but the UI must not present those baselines as measured percentages" vs UI 是否真的未把归一化基线呈现为百分比
- README 隐私声明"does not ... send remote probes" vs `NetworkPathObserver` 的 `NWPathMonitor` 行为（NWPath 不发起外部探测，但需确认文档措辞与用户理解一致）
- `app-store-readiness-checklist.md` 的 App Group 验证项 vs `PulseDockAppGroup.swift` 严格匹配逻辑

**输出**：文档-代码差异表（文档位置 / 声明 / 代码实际行为 / 差异类型 / 影响）

---

## 六、优先级定义

本计划优先级独立于 `REVIEW-PLAN.md` 的 P0/P1/P2，聚焦"用户可感知的语义困惑"与"维护期静默失败风险"：

| 级别 | 标准 | 示例 |
|------|------|------|
| L-高 | 同屏可见的话术矛盾，或数据字段在链路中静默取错值，用户直接困惑 | A1（`5m` vs `System Scheduled` 同屏）、B1（thermal 死分支致颜色错误） |
| L-中 | 跨模块/跨文档不一致，需特定状态才暴露，或维护风险 | A2（`No Battery` vs 已报告）、B4（not-reported 靠字面量判定）、C1（freshness 窗口） |
| L-低 | 防御性冗余或措辞可优化，无用户可见影响 | B2（network path 变体冗余）、A3（预览描述措辞） |

---

## 七、执行步骤

### 阶段 1：并发派发 5 个子 agent（单消息）
每 agent 读取对应文件全集，按上述"审查方法"输出结构化报告。强制完整报告、不截断。

### 阶段 2：中层整合
- 收集 5 份报告 → `docs/review/middle/logic-consistency-integrated.md`
- 生成两张主表：
  1. **话术概念矩阵**：概念 × {app strings, widget strings, shared strings, 文档, plist} 的全部文案变体
  2. **数据字段端到端矩阵**：字段 × {sampler 输出集合, 下游匹配集合, 报告状态判定, 单位, 裁剪行为}
- 识别跨模块系统性话术漂移模式

### 阶段 3：顶层复核
- 对照源码验证每条发现，重点区分"真矛盾"与"产品有意区分"（如 widget mini 缩写是有意为之）
- 标注已被 `REVIEW-PLAN.md` 覆盖项（避免重复）
- 生成 `docs/review/top/logic-consistency-final.md`：话术矛盾清单 + 数据一致性矩阵 + 设计合理性评估 + 修复优先级

### 阶段 4：验证
对每条 L-高问题，要求给出：
- 触发条件（用户操作 / 系统状态）
- 用户可感知表现
- 与 `REVIEW-PLAN.md` 是否重叠
- 修复建议（优先用 SharedMetrics 暴露枚举/常量消除字面量匹配）

---

## 八、验证命令

```bash
# 构建与测试基线
swift build
swift test

# 本地化键一致性（验证话术是否走 localized 路径）
scripts/audit-localization.sh

# 公开页面与隐私声明一致性
scripts/validate-public-pages.sh
```

**关键验证点**：
1. `swift test` 通过（确认审查期间无回归）
2. `audit-localization.sh` 报告的缺失键是否覆盖本计划发现的硬编码话术
3. `data-capability-audit.md` 每条声明能在代码中找到对应行为证据

---

## 九、约束与边界

- **只审查，不修改源码**（除非用户明确指示修复）
- 不引入新功能、新依赖、新本地化语言
- 修复建议优先选择"在 SharedMetrics 暴露枚举/常量"而非"再增加一个变体分支"
- 区分"真矛盾"与"有意区分"：widget mini 缩写（Pwr/Net/Mem）、缩略词（CPU/MEM）属于有意区分，不算矛盾
- 与 `REVIEW-PLAN.md` 重叠项（如 P2-3 字符串契约、P2-6 `5m` 矛盾）标注引用关系，不重复定级

---

## 执行 Checklist

- [ ] 阶段 1：并发派发 5 个子 agent（L1-L5），收集 5 份子报告
- [ ] 阶段 2：中层整合，生成话术概念矩阵 + 数据字段端到端矩阵
- [ ] 阶段 3：顶层复核，区分真矛盾与有意区分，标注与 REVIEW-PLAN.md 重叠项
- [ ] 阶段 4：为每条 L-高问题给出触发条件 + 修复建议
- [ ] 输出 `docs/review/top/logic-consistency-final.md` 最终清单
- [ ] 运行 `swift build` + `swift test` 确认基线
- [ ] 运行 `scripts/audit-localization.sh` 核对硬编码话术
- [ ] 逐句核对 `docs/data-capability-audit.md` 与代码行为
