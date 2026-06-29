# Pulse Dock 前端冗余显示清理计划

> 制定日期：2026-06-29
> 目标：排除前端 UI 中"同一数据在多处展示无新增价值"的设计冗余
> 触发缘由：侧栏左下角 `SidebarHealthCard`（"Live Sampling"卡片）仍在渲染 CPU/Memory/Disk 三行，与 Overview MetricCard 重复，用户质疑其必要性
> 基准：当前 working tree（HEAD `876bcc2`，含前三轮审查修复）

---

## 一、当前已确认的冗余显示（6 处）

### 冗余 1：侧栏 SidebarHealthCard 与 Overview 重复 ❌ 未修
- **位置**：`DashboardView.swift:266` 调用 / `:325-348` 定义
- **内容**：StatusDot + "Live Sampling" 标签 + CPU/Memory/Disk 三行 CompactMetricLine
- **重复对象**：Overview 页 MetricCard（`:430-433`）展示相同 CPU/Memory/Disk 值+进度条+趋势，且更详细（含 sparkline、badgeText、detail）
- **判定**：**真冗余**。sampleTimeText 行已在上轮修复中移除，但 CPU/Mem/Disk 三行仍在。侧栏"切页时常驻可见"的有意冗余论证不成立——顶栏 chip 已常驻采样时间，且 Overview 是默认首页，CPU/Mem/Disk 在 MetricCard 中已一眼可见
- **方案**：**整个移除** SidebarHealthCard，侧栏底部留白

### 冗余 2：CPU 页/Power 页 "Recent Sample" 行与顶栏 chip 重复 ❌ 未修
- **位置**：`DashboardView.swift:559`（CPU 页 loadPanel KeyValueGrid）/ `:839`（Power 页 thermalPanel StatusSummaryRow）
- **内容**：`(cpuRecentSampleLabel, snapshot.sampleTimeText)`
- **重复对象**：顶栏 `:408` `DataChip(icon: "clock", text: dashboardSampleChip(snapshot.sampleTimeText))` 常驻显示同一 sampleTimeText
- **判定**：**真冗余**。顶栏每页可见，页面内"Recent Sample"行无新增价值
- **方案**：移除 CPU 页 `:559` 行 + Power 页 `:839` 行

### 冗余 3：Overview 趋势面板 5 行是 History 趋势面板的纯子集 ❌ 未修
- **位置**：`DashboardView.swift:465-472`（overviewTrendPanel，5 行 TrendRow）vs `:1029-1037`（History 趋势面板，8 行 TrendRow）
- **内容**：Overview 的 CPU/Load/Memory/Network/Disk 5 行 = History 前 5 行，同 history 数据源、同提取器
- **判定**：**真冗余**（Overview 5 行是 History 8 行的纯子集，无新增信息）。Overview MetricCard 已含各自 sparkline 提供趋势预览
- **方案**：移除 Overview `overviewTrendPanel`，Overview 页保留 MetricCards + StatusPanel + ProcessList + WidgetPreview。趋势详情由 History 页提供

### 冗余 4：Power 页 thermalPanel 错位放置 uptime/sampleTime ❌ 未修
- **位置**：`DashboardView.swift:838-839`（thermalPanel 内 uptimeText + sampleTimeText 两行）
- **内容**：StatusSummaryRow(metricUptime, uptimeText) + StatusSummaryRow(cpuRecentSampleLabel, sampleTimeText)
- **重复对象**：Overview StatusPanel `:480`（uptimeText）/ 顶栏 chip（sampleTimeText）
- **判定**：**真冗余**。Power 页 thermalPanel 应聚焦热状态+性能限制，uptime/sampleTime 与主题无关且已在 Overview/顶栏覆盖
- **方案**：移除 Power 页 thermalPanel 的 `:838`（uptimeText）和 `:839`（sampleTimeText）行

### 冗余 5：Network 页连接状态 MetricCard 与连通性表首行重复 ❌ 未修
- **位置**：`DashboardView.swift:707`（MetricCard networkConnectionStatusTitle）vs `:715`（连通性表首行 networkPathLabel）
- **内容**：MetricCard 展示 networkPathText + networkPathDetailText；表首行展示相同值
- **判定**：**真冗余**。MetricCard 更丰富（含进度条+sparkline），表首行无新增价值
- **方案**：移除连通性表首行 `:715`

### 冗余 6：WidgetMiniPreview 在 Overview 与 Settings 完全相同渲染两次 ❌ 未修
- **位置**：`DashboardView.swift:451-461`（Overview 页 WidgetPreviewPanel）vs `:1185-1199`（Settings 页 widgetPreviewPanel）
- **内容**：两处用相同入参 snapshot 调用 WidgetMiniPreview，渲染完全相同
- **判定**：**真冗余**。Settings 页是配置上下文的自然位置；Overview 页的 WidgetMiniPreview CPU/MEM 环形图还与同页 MetricCards 重复
- **方案**：移除 Overview 页 `:451-461` WidgetPreviewPanel，widget 预览仅保留在 Settings 页

---

## 二、执行步骤

### 阶段 1：移除 6 处冗余显示

| 序号 | 操作 | 文件:行号 | 具体改动 |
|------|------|----------|---------|
| 1 | 移除 SidebarHealthCard | `DashboardView.swift:266` | 删除 `SidebarHealthCard(snapshot: snapshot)` 调用 + `:325-348` 结构体定义 + `PulseDockAppStrings.swift:96-98` dashboardSidebarLiveSampling（如无其他引用） |
| 2 | 移除 CPU 页 Recent Sample 行 | `DashboardView.swift:559` | 从 loadPanel KeyValueGrid items 中删除 `(cpuRecentSampleLabel, sampleTimeText)` 行 |
| 3 | 移除 Overview 趋势面板 | `DashboardView.swift:465-475` | 删除 `overviewTrendPanel` 方法及其调用（Overview body 中 `:437-448` 的 isCompact/else 分支调用） |
| 4 | 移除 Power 页 thermalPanel 错位行 | `DashboardView.swift:838-839` | 删除 uptimeText + sampleTimeText 两行 StatusSummaryRow |
| 5 | 移除 Network 页连通性表首行 | `DashboardView.swift:715` | 从连通性表 rows 中删除 `[networkPathLabel, networkPathText, networkPathDetailText]` 行 |
| 6 | 移除 Overview WidgetPreviewPanel | `DashboardView.swift:451-461` | 删除 Overview 页的 WidgetPreviewPanel if/else 块（ProcessListPanel 保留） |

### 阶段 2：清理关联代码

- 检查 `overviewTrendPanel` 方法移除后，`cpuTrend`/`memoryTrend`/`networkTrend` 局部变量在 Overview body 中是否仍有其他消费点（MetricCard values 参数仍需要）
- 检查 `CompactMetricLine` 结构体在移除 SidebarHealthCard 后是否还有其他引用（如无则一并删除）
- 检查 `dashboardSidebarLiveSampling` 本地化键移除后 strings 表是否需清理
- 检查 `WidgetPreviewPanel` 结构体在移除 Overview 引用后是否仅 Settings 页使用（如是则可简化）

### 阶段 3：验证

```bash
swift build
swift test
```

关键验证点：
1. `swift build` 编译通过（无未使用变量/函数警告）
2. `swift test` 全部通过（376 tests）
3. Overview 页布局：MetricCards（4 张）+ StatusPanel + ProcessListPanel（无趋势面板、无 widget 预览）
4. 侧栏：导航列表 + 底部留白（无 Live Sampling 卡片）
5. CPU 页 loadPanel：KeyValueGrid 不含 Recent Sample 行
6. Power 页 thermalPanel：仅 thermalText + thermalLimitText（无 uptime/sampleTime）
7. Network 页连通性表：从 Capability 行开始（无 Path 首行）

### 阶段 4：更新测试

- 检查 `VisualFrontendGateTests` / `LogicConsistencyGateTests` 中是否有断言依赖被移除的视图
- 如有断言验证 SidebarHealthCard/overviewTrendPanel/WidgetPreviewPanel 存在，需更新
- 确保无测试引用 `dashboardSidebarLiveSampling` 本地化键

---

## 三、不修改的项（有意冗余）

以下冗余经判定为有意设计，**不修改**：

| 项 | 理由 |
|----|------|
| 顶栏 DataChip(clock, sampleTimeText) 常驻 | 切页时常驻可见，是唯一常驻时间锚点 |
| Widget（SystemDashboardWidget）与 app 同一数据 | 跨进程无法共享视图 |
| Popover（WidgetPanelView）与 dashboard 同一数据 | 不同入口点，用户可能仅开 popover |
| AppDelegate menubar title cpuText | 系统级常驻微指示器，独立表面 |
| MetricCard badgeText 重复 value | 视觉层级设计（大数+徽章） |
| Overview StatusPanel 10 行摘要 | "一屏概览"摘要模式，vs 各 dedicated 页是"摘要 vs 详情"关系 |

---

## 执行 Checklist

- [ ] 移除 SidebarHealthCard（调用 + 定义 + 本地化键）
- [ ] 移除 CPU 页 Recent Sample 行
- [ ] 移除 Overview 趋势面板
- [ ] 移除 Power 页 thermalPanel uptime/sampleTime 行
- [ ] 移除 Network 页连通性表首行
- [ ] 移除 Overview WidgetPreviewPanel
- [ ] 清理关联代码（CompactMetricLine/WidgetPreviewPanel/overviewTrendPanel 如无其他引用）
- [ ] `swift build` 通过
- [ ] `swift test` 通过
- [ ] 更新依赖被移除视图的测试断言
