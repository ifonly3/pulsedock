# Pulse Dock 冗余与重复审查 — 中层整合报告

> 审查日期：2026-06-28
> 子 agent 数：4（R1 信息冗余 / R2 代码重复 / R3 死状态 / R4 跨模块重复）
> 原始发现：66 条（R1:9 + R2:19 + R3:28 + R4:10 可提取 + 12 需保持独立）
> 去重合并后：52 条有效发现（R-高:7 / R-中:18 / R-低:27）
> 前序资产：`docs/review/REDUNDANCY-REVIEW-PLAN.md`、`docs/review/top/logic-consistency-final.md`、`docs/review/top/final-review-v2.md`

---

## 一、去重与合并

### 1.1 跨报告重复项合并（9 组）

| 合并组 | R2 ID | R4 ID | 合并后 ID | 说明 |
|--------|-------|-------|-----------|------|
| reportedProgress 三处 | R2-1 | R4-1 | RD-1 | 三处逐字节相同 |
| progressFillWidth 三处 | R2-2 | R4-2 | RD-2 | 三处逐字节相同 |
| networkPathProgress 两处 | R2-7 | R4-3 | RD-3 | app↔widget 完全相同 |
| 三套颜色 tokens | R2-9 | R4-8 | RD-4 | light RGB 一致，dark 漂移 |
| "Not reported" 三套 | R2-11 | R4-7 | RD-5 | default 相同 |
| powerTint 三处 | R2-4 | R4-9 | RD-6 | 语义一致，仅色源不同 |
| thermalTint → 色调 | R2-5 | R4-4 | RD-7 | ⚠️ hot 归类分歧 |
| networkTint → 色调 | R2-6 | R4-5 | RD-8 | ⚠️ unknown 色调分歧 |
| normalizedRate alias | R2-3 | R4（非跨模块） | RD-9 | 仅 app 2 处，非跨模块 |

### 1.2 去重后有效发现：52 条

| 维度 | 数量 | 来源 |
|------|------|------|
| R-高 | 7 | R1:2 + R2/R4:4 + R4 新发现:1 |
| R-中 | 18 | R1:4 + R2/R4:10 + R2:4 |
| R-低 | 27 | R1:3 + R2:5 + R3:28 - 已修复1 |

---

## 二、跨模块系统性问题（4 组）

### 系统性问题 1：三套颜色 tokens + dark 模式漂移

**影响报告**：R2 / R4
**合并发现**：RD-4

**完整链路**：
```
DashboardColor（DashboardVisualTokens.swift:53）— 单值（light），无 dark 变体
Palette（WidgetPanelView.swift:318）— light + dark
WidgetColor（WidgetVisualTokens.swift:39）— light + dark

light RGB 三处完全一致（同源证据）
dark RGB Palette ↔ WidgetColor 微差（漂移证据）：
  green dark: Palette 0.26,0.82,0.58 vs WidgetColor 0.24,0.82,0.62
  blue dark:  Palette 0.42,0.66 vs WidgetColor 0.36,0.62
  amber dark: Palette 1.00,0.70,0.30 vs WidgetColor 1.00,0.68,0.28
DashboardColor 完全无 dark 适配（app 窗口 dark 下用 light 值，偏深）
```

**后果**：app 主窗口与 popover/widget 在 dark 模式下强调色肉眼可辨不一致；任一处调色其他两处不会跟随。

### 系统性问题 2：thermal/network 色调跨 surface 语义分歧

**影响报告**：R4（新发现）
**合并发现**：RD-7 + RD-8

**完整链路**：
```
thermalState → 色调：
  app（DashboardView.swift:2321）: hot → .warning(amber)
  popover（WidgetPanelView.swift:159）: hot → critical(red)
  widget（SystemDashboardWidget.swift:736）: hot → critical(red)
  → app 主窗口 hot=琥珀色，popover/widget hot=红色，同设备跨 surface 不一致

networkPathStatus → 色调：
  app（DashboardView.swift:2235）: unknown → .neutral → blue
  popover/widget: unknown → cyan
  → 根因：app StatusLevel.neutral → DashboardColor.blue（DashboardView.swift:1791）
     但 app 自身 powerTint 的 .neutral → DashboardColor.cyan（:2285）—— app 内部矛盾

新发现：StatusLevel.neutral → blue 是 app 内 bug
  DashboardView.swift:1791 StatusLevel.color 的 .neutral → DashboardColor.blue
  DashboardView.swift:2285 powerTint 的 .neutral → DashboardColor.cyan
  同一 app 内同一 .neutral 枚举值映射到两个不同颜色
```

**后果**：用户在 app 主窗口看到 thermal hot=琥珀色，在 popover 看到 hot=红色；network unknown 在 app=蓝色，popover/widget=青色。同设备跨 surface 颜色不一致，用户可感知。

### 系统性问题 3：Sensors 页同页 8 项重叠（单点冗余量最大）

**影响报告**：R1（新发现）

**完整链路**：
```
Sensors 页两个面板：
  statusSystemSignalsTitle 表（DashboardView.swift:980-997）— 10 行 [指标, 值, 来源]
  statusRealtimeSignalsTitle 卡片网格（:1011-1027）— 11 张 SourceCapabilityCard

8 个完全重叠的数据点：
  osVersionText / uptimeText / loadDetailText / powerStatusText /
  networkPathText / displaySummaryText / gpuSummaryText / storageVolumeSummaryText

差异仅在第三列：表显示"来源"文本，卡片显示状态徽章+来源
但状态徽章对这 8 项大多是 .normal/.neutral，信息增量极低
```

**后果**：同页 8 项重叠，是本次审查单点冗余量最大的一处。用户看到两份几乎相同的清单。

### 系统性问题 4：widgetCompact 20 个死字段（共享存储载荷浪费）

**影响报告**：R3

**完整链路**：
```
widgetCompactSnapshot() 当前保留 44 个非裁剪字段
widget 渲染只读取 ~28 字段（含 hasXxxReport 布尔守卫）
20 字段经 App Group JSON 编解码后从不读取：
  CPU: cpuCoreUsages, physicalCoreCount
  内存: memoryFreeBytes/Wired/Compressed/Cached/Swap×3, hasMemoryCompositionReport
  负载: loadAverage5, loadAverage15
  电池: batteryTimeRemainingMinutes/CycleCount/Health/CurrentCapacity/MaxCapacity/DesignCapacity/Voltage/Amperage

纠正：初版报告把 networkBytesPerSecond/hasNetworkByteCounters/hasNetworkDirectionByteCounters/networkInBytesPerSecond/networkOutBytesPerSecond 也列入此处，但当前 MetricSnapshot+WidgetCompact.swift 已不再传入这些网络速率字段。

每次共享存储写入（60s）浪费编解码字节，单 snapshot 载荷冗余 ~30-40%
```

**后果**：无用户可见影响，但 App Group UserDefaults 载荷与编解码开销增加 ~30-40%。

---

## 三、数据点 × 展示位置矩阵（摘要）

| 数据点 | 展示位置数 | 冗余评估 |
|--------|----------|---------|
| sampleTimeText | app 6 处 + popover 1 处 | R1-1/R1-2：侧栏 vs 顶栏双常驻；CPU/Power 页与顶栏重复 |
| cpuText | app 9 处 + popover/menubar/widget | 侧栏常驻=有意；Overview 三处=不同视角；History=超集 |
| 规则表 4 行 | Sensors 页 + History 页 | R1-3：规则语义重复（R-高）；History 前三行标题更具体，不是逐字符重复 |
| 趋势 5 行 | Overview + History | R1-4：Overview 是 History 纯子集 |
| Sensors 8 项 | 信号表 + 信号卡 | R1-6：同页 8 项重叠（R-高） |
| Widget 预览 | Overview + Settings | R1-7：完全相同渲染两次 |

---

## 四、代码重复矩阵（摘要）

| 重复函数 | 位置数 | 实现差异 | 合并落点 |
|---------|--------|---------|---------|
| reportedProgress | 3 | 完全相同 | MetricScales |
| progressFillWidth | 3 | 完全相同 | MetricScales（+CoreGraphics） |
| networkPathProgress | 2 | 完全相同 | NetworkPathState.progress |
| thermalTint/Status | 3 | ⚠️ hot 归类分歧 | ThermalState.semanticTone |
| networkTint/Status | 3 | ⚠️ unknown 色调分歧 | NetworkPathState.semanticTone |
| powerTint | 3 | 语义一致 | MetricStatusTone 映射 |
| normalizedRate | 2 | 完全相同（alias） | 直接删除，调用 MetricScales |

---

## 五、死状态/死字段清单（摘要）

| 死项 | 位置 | 优先级 |
|------|------|--------|
| isRefreshing | MetricsStore.swift:47 | R-低 |
| widgetCompact 20 死字段 | MetricSnapshot+WidgetCompact.swift | R-低 |
| Undo/Redo 菜单 | AppDelegate.swift:152-153 | R-低（约定性样板） |
| design/ vs designs/ | 项目根目录 | R-低 |
| "No Battery" 分支 | 已修复（前次 L4-7） | — |

---

## 六、与前两次审查的对齐

| 本次发现 | 前次审查对应项 | 关系 |
|---------|--------------|------|
| RD-1/RD-2（reportedProgress/progressFillWidth） | REVIEW-PLAN P2-4 | 确认三处逐字节相同，提供提取方案 |
| RD-4（三套颜色） | REVIEW-PLAN P2-4 | 扩展：发现 dark RGB 漂移 + app 无 dark 适配 |
| RD-7/RD-8（色调分歧） | LOGIC-CONSISTENCY LC-6（死分支） | **新发现**：除死分支外，hot/unknown 归类跨 surface 分歧 |
| StatusLevel.neutral→blue | 无 | **新发现**：app 内 bug |
| R1-3（规则表跨页重复） | LOGIC-CONSISTENCY L1-4（话术不一致） | 互补：L1-4 关注标题/状态词不一致，本报告关注数据渲染重复 |
| R3-2（20 死字段） | LOGIC-CONSISTENCY L3-15（networkBytesPerSecond） | 当前代码确认仍有 20 个 compact 死字段；初版列入的 5 个网络速率字段已不在 compact 投影中 |
| R3-3（"No Battery"） | LOGIC-CONSISTENCY L4-7 | 确认已修复 |
| R3-1（isRefreshing） | REVIEW-PLAN P1-6 | 确认完全无消费者 |

---

## 七、子报告索引

4 份子 agent 报告已落盘：
- `docs/review/subagents/R1-info-redundancy.md`（9 条信息冗余）
- `docs/review/subagents/R2-code-duplication.md`（19 条代码重复）
- `docs/review/subagents/R3-dead-state.md`（28 条死项）
- `docs/review/subagents/R4-cross-module.md`（10 条可提取 + 12 需保持独立）

本报告与 `docs/review/top/redundancy-final.md` 共同构成完整审查交付物。
