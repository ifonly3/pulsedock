# L1 — 话术矛盾专项报告

> 审查日期：2026-06-28
> 审查范围：app / widget / shared 三套 strings 表 + DashboardView / AppDelegate / WidgetPanelView / SystemDashboardWidget 消费点 + Info.plist + README
> 方法：建立概念词典 → 同屏/同卡片矛盾扫描 → 跨模块同义对照

---

## 一、概念词典

| 概念 | 位置 | 文案 | file:line |
|------|------|------|-----------|
| Widget 刷新 | app settings 只读行标题 | "Widget Refresh" | PulseDockAppStrings.swift:1014 |
| Widget 刷新 | app settings 只读行 detail | "Scheduled by the system timeline" | PulseDockAppStrings.swift:1019 |
| Widget 刷新 | app settings 只读行 control（硬编码） | "5m" | DashboardView.swift:1167 |
| Widget 刷新 | app widget 预览面板 label | "Refresh" | PulseDockAppStrings.swift:1051 |
| Widget 刷新 | app widget 预览面板 value | "System Scheduled" | PulseDockAppStrings.swift:1055 |
| Widget 刷新 | app 概览 widget 预览描述 | "The widget refreshes core status on the system timeline..." | PulseDockAppStrings.swift:745 |
| Widget 刷新 | widget 实际请求值 | nextRefresh = +5 分钟（请求，非兑现） | SystemDashboardWidget.swift:58 |
| 电源/电池 | app 侧栏页标题 | "Power" | PulseDockAppStrings.swift:29 |
| 电源/电池 | app 电源页主面板标题 | "Power & Battery" | PulseDockAppStrings.swift:507 |
| 电源/电池 | app 电源信息表第一行标题（无电池时） | "Power"（powerStatusTitlePower） | SharedMetricStrings.swift:286 |
| 电源/电池 | app 电源 KeyValueGrid 标签 | "Power"（powerSourceLabel） | PulseDockAppStrings.swift:515 |
| 电源/电池 | 无电池时 powerSourceText | "No Battery" | SharedMetricStrings.swift:278 / MetricSnapshot.swift:1274 |
| 电源/电池 | hasPowerStatusReport 判定 | batteryPercent not nil or batteryPowerSource not nil | MetricSnapshot.swift:1282 |
| 电源/电池 | 数据源表 "Power / Thermal State" 行状态 | "Reported" / "Partial report" / "Not reported" | MetricSnapshot.swift:1217-1223 |
| 电源/电池 | widget 紧凑 AC 未充电 | "Power"（compactPowerAdapter） | PulseDockWidgetStrings.swift:92 |
| 热状态 | app 指标缩写 | "Thermal" | PulseDockAppStrings.swift:1115 |
| 热状态 | app 热面板标题 | "Thermal State" | PulseDockAppStrings.swift:834 |
| 热状态 | widget 指标缩写 | "Thermal" | PulseDockWidgetStrings.swift:49 |
| 热状态 | widget small mini 标签 | "Heat" | PulseDockWidgetStrings.swift:13 |
| System Status | app Overview 状态面板标题 | "System Status" | PulseDockAppStrings.swift:133 |
| System Status | app Sensors 热面板内行标题（值=thermalLimitText） | "System Status" | PulseDockAppStrings.swift:842 / DashboardView.swift:1007 |
| System Status | app 侧栏 Sensors 页标题 | "Status" | PulseDockAppStrings.swift:37 |
| System Status | widget Large 头部标题 | "System Status" | PulseDockWidgetStrings.swift:73 |
| GPU/显示器 | app 侧栏/顶栏页标题 | "GPU / Display"（单数） | PulseDockAppStrings.swift:13 |
| GPU/显示器 | app Overview 行 / Settings 数据源行 | "GPU / Displays"（复数） | PulseDockAppStrings.swift:1163 |
| GPU/显示器 | app GPU 页主面板标题 | "GPU & Unified Memory" | PulseDockAppStrings.swift:615 |
| GPU/显示器 | app GPU 页 SourceCapabilityCard 标题 | "GPU" / "Displays"（分开） | PulseDockAppStrings.swift:1111 / 1127 |
| 状态规则 | app Sensors 页规则面板标题 | "Status Rules" | PulseDockAppStrings.swift:854 |
| 状态规则 | app Sensors 页规则面板 subtitle | "Local results for the current sample"（复数） | PulseDockAppStrings.swift:858 |
| 状态规则 | app History 页评估面板标题 | "Status Evaluation" | PulseDockAppStrings.swift:725 |
| 状态规则 | app History 页评估面板 subtitle | "Local result for the current sample"（单数） | PulseDockAppStrings.swift:729 |
| 状态规则 | app Sensors 页超阈值状态文案 | "Warning" | PulseDockAppStrings.swift:919 |
| 状态规则 | app History 页超阈值状态文案 | "Triggered" | PulseDockAppStrings.swift:927 |
| Not reported | app | "Not reported" | PulseDockAppStrings.swift:1087 |
| Not reported | widget | "Not reported" | PulseDockWidgetStrings.swift:85 |
| Not reported | shared | "Not reported" | SharedMetricStrings.swift:5 |
| Not reported（同义长句） | app | "System did not report" | PulseDockAppStrings.swift:1083 |
| Not reported（同义长句） | shared | "System did not report" | SharedMetricStrings.swift:85 |
| 网络连接 | app 指标全称 | "Network Connection" | PulseDockAppStrings.swift:1103 |
| 网络连接 | widget 指标 | "Connection" | PulseDockWidgetStrings.swift:37 |
| 网络连接 | app 网络页卡片标题 | "Connection Status" | PulseDockAppStrings.swift:378 |
| 样本措辞 | app Sensors 实时信号 subtitle | "Latest sample" | PulseDockAppStrings.swift:850 |
| 样本措辞 | app Sensors 规则 subtitle | "Local results for the current sample" | PulseDockAppStrings.swift:858 |
| 进程排序 | app 默认 subtitle | "Foreground first, sorted by name" | PulseDockAppStrings.swift:805 |
| 进程排序 | 实际排序逻辑 | isActive 优先 → 非 hidden 优先 → 名称 localizedStandardCompare | MetricsStore.swift:456-467 |
| Widget 尺寸 | app settings value | "Small / Medium / Large" | PulseDockAppStrings.swift:1039 |
| Widget 尺寸 | widget supportedFamilies | [.systemSmall, .systemMedium, .systemLarge] | SystemDashboardWidget.swift:148 |
| 隐私 | app settings detail | "Local sampling, no account, no tracking" | PulseDockAppStrings.swift:947 |
| 隐私 | README | "...does not create accounts, collect personal data, track users, run analytics, or send remote probes" | README.md:61 |
| Bundle 名称 | AppInfo.plist CFBundleDisplayName | "Pulse Dock" | Resources/AppInfo.plist:24 |
| Bundle 名称 | WidgetInfo.plist CFBundleDisplayName | "Pulse Dock Widget" | Resources/WidgetInfo.plist:14 |
| Bundle 名称 | widget configurationDisplayName | "Pulse Dock"（widgetDisplayName） | PulseDockWidgetStrings.swift:5 |
| 菜单暂停/恢复 | popover 动作 | "Resume" / "Pause" | PulseDockAppStrings.swift:1239 / 1243 |
| 菜单暂停/恢复 | popover 状态徽章 | "Paused" / "Live" | PulseDockAppStrings.swift:1251 / 1255 |

---

## 二、话术矛盾发现

### 矛盾 L1-1: Widget 刷新事实在同屏两面板给出冲突语义（锚点 A1）
- **位置1**: DashboardView.swift:1167 — SettingReadOnlyRow(title="Widget Refresh", detail="Scheduled by the system timeline", control="5m")（Refresh & Display 面板）
- **位置2**: DashboardView.swift:1192 — KeyValueGrid (settingsWidgetRefreshLabel="Refresh", settingsWidgetRefreshValue="System Scheduled")（Widget 预览面板）
- **位置3**: PulseDockAppStrings.swift:1019 — detail="Scheduled by the system timeline"
- **位置4**: PulseDockAppStrings.swift:1055 — value="System Scheduled"
- **位置5**: SystemDashboardWidget.swift:58 — nextRefresh = +5 分钟，policy .after(nextRefresh)，仅为请求值，系统时间线可推迟
- **矛盾描述**: 同一设置页（非 compact 布局下两面板左右并排，DashboardView.swift:1101-1105）对"widget 刷新"同一事实给出两种语义：左面板给出具体数值 "5m"，右面板给出模糊描述 "System Scheduled" 且无数值。"5m" 是 widget 请求的 timeline 间隔，并非系统实际兑现的刷新周期，以具体数值呈现会误导用户认为"每 5 分钟固定刷新"。
- **是否有意区分**: 部分——"5m" 是请求值、"System Scheduled" 强调系统决定，二者各自成立；但同屏并列且无统一措辞/数值口径，属无意漂移。
- **用户可感知表现**: 用户在设置页同时看到 "5m" 与 "System Scheduled"，疑惑"到底是 5 分钟还是系统决定"。当系统实际刷新间隔 ≠ 5 分钟时，"5m" 构成失实承诺。
- **建议**: 统一为单一表述。推荐：将 SettingReadOnlyRow 的 control 从硬编码 "5m" 改为 settingsWidgetRefreshValue（"System Scheduled"），并把 "5m" 请求间隔移入 detail 文案（如 "Requests every 5 minutes, scheduled by the system timeline"），同时去掉同屏重复的 Refresh 行。
- **优先级**: L-中

### 矛盾 L1-2: 无电池设备 "No Battery" 与数据源状态 "Reported" 语义冲突（锚点 A2）
- **位置1**: MetricSnapshot.swift:1272-1274 — batteryPercent == nil 且 batteryPowerSource != nil（未识别值）→ 返回 powerSourceNoBattery = "No Battery"
- **位置2**: MetricSnapshot.swift:1282-1283 — hasPowerStatusReport = (batteryPercent != nil) or (batteryPowerSource != nil) → 此场景为 true
- **位置3**: MetricSnapshot.swift:1217-1223 — powerThermalSourceStatusText 因 hasPowerReport=true 返回 "Reported" 或 "Partial report"
- **位置4**: DashboardView.swift:1129 — Settings 数据源表 "Power / Thermal State" 行显示该状态
- **位置5**: DashboardView.swift:780 / 822 — Power 页同时显示 powerSourceText="No Battery" 与电源信息表
- **矛盾描述**: 桌面 Mac（无电池）且 IOKit 报告了非空 powerSource 时，powerSourceText 显示 "No Battery"，但 hasPowerStatusReport 判定为"已报告"，数据源表显示 "Reported"。用户看到电源文案 "No Battery"（易读作"未报告/无电池信息"）却看到数据源标记"已报告"，语义打架。技术上是"系统报告了：没有电池"，但措辞 "No Battery" 未区分"未报告"与"报告了-无电池"两种状态。
- **是否有意区分**: 否——"No Battery" 同时承担"未报告"歧义，未与数据源状态文案对齐。
- **用户可感知表现**: 桌面 Mac 用户在 Power 页看到 "No Battery"，在 Settings → Data Sources 看到 "Power / Thermal State = Reported"，产生"到底报没报"的困惑。
- **建议**: 将无电池场景的 powerSourceText 改为更明确措辞（如 "No Battery Installed" 或 "Battery Not Present"），或在数据源状态对"已报告但内容为无电池"使用独立中间态文案，避免与"未报告"混淆。
- **优先级**: L-中

### 矛盾 L1-3: "System Status" 概念在 app/widget 三处指代不同范围
- **位置1**: PulseDockAppStrings.swift:133 — overviewSystemStatusTitle="System Status"，用作 Overview 页状态面板标题（DashboardView.swift:478），面板内含 thermal/uptime/kernel/CPU/mem/load/apps/network/GPU/disk 共 10 行宽汇总
- **位置2**: PulseDockAppStrings.swift:842 — statusSystemStatusTitle="System Status"，用作 Sensors 页热面板内一行标题（DashboardView.swift:1007），值=thermalLimitText（"Likely throttling" 等性能限制文案）
- **位置3**: PulseDockWidgetStrings.swift:73 — headerSystemStatus="System Status"，用作 Large widget 头部标题（SystemDashboardWidget.swift:250）
- **位置4**: PulseDockAppStrings.swift:37 — dashboardPageSensorsTitle="Status"（侧栏 Sensors 页名）
- **矛盾描述**: 同一字符串 "System Status" 在 Overview 指代"全系统状态汇总"，在 Sensors 热面板指代"热性能限制"，在 widget Large 指代"widget 整体标题"。Sensors 热面板用 "System Status" 作为 thermalLimitText 的行标题尤其违和——同行已存在 "Current State"（thermalText），"System Status" 与之并列时用户无法推断该行展示的是热限制。
- **是否有意区分**: 否——同一字面量复用而无语义统一。
- **用户可感知表现**: 用户在 Sensors 页看到 "System Status" 行显示 "Likely throttling"，无法联想到这是热性能限制；与 Overview 的 "System Status" 面板范围不一致。
- **建议**: 将 Sensors 热面板该行标题改为 statusPerformanceLimitTitle（"Performance Limit"，已用于 Power 页热面板 DashboardView.swift:839），消除 "System Status" 在热面板的误用；Overview 与 widget 的 "System Status" 范围通过 subtitle 明确。
- **优先级**: L-中

### 矛盾 L1-4: 同一规则表在 Sensors / History 两页以不同标题、subtitle、状态文案呈现
- **位置1**: DashboardView.swift:968-979 — Sensors 页 statusRulesTitle="Status Rules" + statusRulesSubtitle="Local results for the current sample"（复数 results）+ 超阈值文案 statusWarning="Warning"
- **位置2**: DashboardView.swift:1070-1081 — History 页 historyStatusEvaluationTitle="Status Evaluation" + historyStatusEvaluationSubtitle="Local result for the current sample"（单数 result）+ 超阈值文案 statusTriggered="Triggered"
- **位置3**: 两表行数据完全相同（CPU/Memory/Disk/Network 四条规则，DashboardView.swift:972-975 vs 1074-1077）
- **矛盾描述**: 同一份阈值规则评估结果在两个页面以不同标题（"Status Rules" vs "Status Evaluation"）、不同 subtitle（"results" vs "result"）、不同超阈值状态词（"Warning" vs "Triggered"）呈现。用户在 Sensors 页看到 CPU 超阈值标 "Warning"，切到 History 页同一 CPU 超阈值标 "Triggered"，会误以为两处评估口径不同。
- **是否有意区分**: 部分——History 页侧重"历史评估"、Sensors 页侧重"实时规则"，但数据源完全相同（均取当前 snapshot），区分缺乏事实依据。
- **用户可感知表现**: 跨页看到同一指标状态词不一致（Warning vs Triggered），怀疑评估逻辑不同。
- **建议**: 统一标题与状态文案：两页共用一套（建议 "Status Rules" + "Triggered"，或 "Status Evaluation" + "Warning"），subtitle 单复数对齐。
- **优先级**: L-中

### 矛盾 L1-5: GPU/显示器标题在单数/复数/连词三种写法间漂移
- **位置1**: PulseDockAppStrings.swift:13 — dashboardPageGPUTitle="GPU / Display"（单数 Display，侧栏 + 顶栏页标题）
- **位置2**: PulseDockAppStrings.swift:1163 — metricGPUDisplays="GPU / Displays"（复数 Displays，Overview 行 DashboardView.swift:488 与 Settings 数据源行 :1127）
- **位置3**: PulseDockAppStrings.swift:615 — gpuUnifiedMemoryPanelTitle="GPU & Unified Memory"（& 连词，GPU 页主面板 DashboardView.swift:859）
- **位置4**: PulseDockAppStrings.swift:1111 / 1127 — metricGPU="GPU" / metricDisplays="Displays"（GPU 页 SourceCapabilityCard 分开标题 :854-855）
- **矛盾描述**: 进入 GPU 页（DashboardView.swift:847-913），顶栏显示 "GPU / Display"（单数），页面内主面板标题 "GPU & Unified Memory"，另一面板 "Displays"；而 Overview 与 Settings 同一概念用 "GPU / Displays"（复数）。"Display" 单数 vs "Displays" 复数、"/" vs "&" 在同一应用内对同一指标组合呈现三种写法。
- **是否有意区分**: 否——单复数与连词差异无功能含义。
- **用户可感知表现**: 跨页看到 "GPU / Display" 与 "GPU / Displays"，以为是不同概念。
- **建议**: 统一为复数 "GPU / Displays"（与 Overview/Settings 对齐），或将页标题改为 "Graphics" 与面板标题解耦。
- **优先级**: L-低

### 矛盾 L1-6: widget 描述 "core status" / widgetDescription 指标清单与 Large widget 实际展示范围不一致（锚点 A3）
- **位置1**: PulseDockAppStrings.swift:745 — widgetPreviewDescription="The widget refreshes core status on the system timeline for quick local status checks."
- **位置2**: PulseDockWidgetStrings.swift:9 — widgetDescription="Show Mac CPU, memory, connection, battery, and thermal status on your desktop."（widget gallery 描述，仅列 5 项）
- **位置3**: SystemDashboardWidget.swift:243-298 — Large widget 实际展示 CPU/Memory/Disk/Load/Power/Thermal/Connection/Path/Interface/Uptime/System/Kernel 共 12 类
- **位置4**: SystemDashboardWidget.swift:51-61 — getTimeline 含 fallback 路径（SharedSnapshotStore 失败时 WidgetSamplerCache.sampleCompact()），首次 tick CPU/网络可能显示 "Not reported"，与 "core status" 实时性措辞略有出入
- **矛盾描述**: widgetPreviewDescription 用 "core status" 泛指，widgetDescription（gallery）只列 CPU/memory/connection/battery/thermal 5 项，但 Large widget 实际还展示 disk/load/uptime/system/kernel。gallery 描述对 Large widget 范围失实（少列 5 项），"core status" 措辞范围模糊。
- **是否有意区分**: 部分——gallery 描述可能有意精简，但与 Large 实际内容偏差较大。
- **用户可感知表现**: 用户在 widget gallery 看到"仅 CPU/内存/连接/电池/热"，添加 Large 后发现还有磁盘/负载/uptime 等，与描述不符。
- **建议**: widgetDescription 补全为 "CPU, memory, disk, network, battery, thermal, and system status"，或按 family 分描述；app 内 widgetPreviewDescription 的 "core status" 明确范围。
- **优先级**: L-低

### 矛盾 L1-7: 热状态在 widget small 用 "Heat"，其余位置用 "Thermal"
- **位置1**: PulseDockWidgetStrings.swift:13 — miniThermal="Heat"（SmallWidget 与 MediumStatusStrip mini 标签，SystemDashboardWidget.swift:184/237）
- **位置2**: PulseDockWidgetStrings.swift:49 — metricThermalState="Thermal"（Large widget StatTile，:263）
- **位置3**: PulseDockAppStrings.swift:1115 — metricThermalState="Thermal"（app 一律用 Thermal）
- **矛盾描述**: 同一热状态指标，在 small/medium widget mini 标签显示 "Heat"，在 large widget 与全 app 显示 "Thermal"。"Heat" 与 "Thermal" 在用户认知中并非同义缩写，且 widget 内部随尺寸切换出现词义跳变。
- **是否有意区分**: 是（空间约束缩写），但 "Heat" 不是 "Thermal" 的标准缩写，属无意漂移。
- **用户可感知表现**: 用户从 small widget 切到 large，看到 "Heat" 变 "Thermal"，疑惑是否同一指标。
- **建议**: mini 标签统一为 "Therm" 或 "Temp"，与 "Thermal" 保持同源；或在 widget strings 注释说明缩写策略。
- **优先级**: L-低

### 矛盾 L1-8: 网络连接指标 app "Network Connection" vs widget "Connection"
- **位置1**: PulseDockAppStrings.swift:1103 — metricNetworkConnection="Network Connection"（app Overview/Sensors/Settings 多处）
- **位置2**: PulseDockWidgetStrings.swift:37 — metricConnection="Connection"（Medium/Large widget，SystemDashboardWidget.swift:221/270）
- **位置3**: PulseDockAppStrings.swift:378 — networkConnectionStatusTitle="Connection Status"（网络页卡片）
- **矛盾描述**: app 用全称 "Network Connection"，widget 用 "Connection"，网络页卡片用 "Connection Status"。三者指代同一 networkPath 指标。widget 简化属有意，但 app 内 "Network Connection" 与 "Connection Status" 并存属漂移。
- **是否有意区分**: widget 简化为有意（空间），app 内 "Network Connection" vs "Connection Status" 为无意漂移。
- **用户可感知表现**: 跨 app 页面/卡片看到 "Network Connection" 与 "Connection Status"，语义重叠措辞不一。
- **建议**: app 内统一为 "Network Connection" 或 "Connection"，并在 widget strings 注释标注为缩写变体。
- **优先级**: L-低

### 矛盾 L1-9: "Not reported" 与 "System did not report" 双术语并存
- **位置1**: PulseDockAppStrings.swift:1087 — notReported="Not reported"（app 主用）
- **位置2**: PulseDockAppStrings.swift:1083 — systemDidNotReport="System did not report"（DashboardView.swift:512 per-core 空、:753 网络接口空）
- **位置3**: SharedMetricStrings.swift:5 / 85 — shared 表同时定义 notReported="Not reported" 与 systemDidNotReport="System did not report"
- **位置4**: ProcessMetric.architectureText/launchText 使用 systemDidNotReport（MetricSnapshot.swift:83/87），而 stateText 用 notReported（:73）
- **矛盾描述**: "未报告"概念存在两套措辞："Not reported"（短）与 "System did not report"（长），且在同一 ProcessMetric 内按字段切换（stateText 用短、architectureText/launchText 用长）。用户在同一进程表行内看到 State 列 "Not reported"、Architecture 列 "System did not report"。
- **是否有意区分**: 否——无文档说明两术语的适用边界。
- **用户可感知表现**: 同表内相邻列出现两种"未报告"措辞，显得不统一。
- **建议**: 统一为 "Not reported"；如需强调"系统未提供"，在 detail/source 列说明，不污染 value 列。
- **优先级**: L-低

### 矛盾 L1-10: Widget bundle display name "Pulse Dock Widget" vs gallery 名 "Pulse Dock"
- **位置1**: Resources/WidgetInfo.plist:14 — CFBundleDisplayName="Pulse Dock Widget"
- **位置2**: PulseDockWidgetStrings.swift:5 — widgetDisplayName="Pulse Dock"（configurationDisplayName，SystemDashboardWidget.swift:146）
- **位置3**: AppInfo.plist:24 — CFBundleDisplayName="Pulse Dock"
- **矛盾描述**: widget 在系统 widget gallery 中显示名为 "Pulse Dock"（configurationDisplayName），但其 bundle 显示名为 "Pulse Dock Widget"。安装后系统设置/扩展列表显示 "Pulse Dock Widget"，gallery 显示 "Pulse Dock"，两个 UI 入口对同一 widget 给出不同名称。
- **是否有意区分**: 部分——gallery 名有意缩短，但缺乏统一规范。
- **用户可感知表现**: 用户在 gallery 添加 "Pulse Dock"，在系统设置扩展列表看到 "Pulse Dock Widget"，疑为两个组件。
- **建议**: 统一为 "Pulse Dock"（gallery 与 bundle display name 一致），或 gallery 名显式带 "Widget" 后缀。
- **优先级**: L-低

### 矛盾 L1-11: Sensors 页 "Latest sample" vs "Local results for the current sample" 同页同义异述
- **位置1**: PulseDockAppStrings.swift:850 — statusRealtimeSignalsSubtitle="Latest sample"（实时信号面板，DashboardView.swift:1013）
- **位置2**: PulseDockAppStrings.swift:858 — statusRulesSubtitle="Local results for the current sample"（规则面板，DashboardView.swift:968）
- **位置3**: 两面板同在 Sensors 页（DashboardView.swift:953-999）
- **矛盾描述**: 同一 Sensors 页内，"实时信号"面板 subtitle 用 "Latest sample"，"规则"面板 subtitle 用 "Local results for the current sample"。两者都指"当前样本"，措辞差异（Latest vs current、sample vs results for the current sample）在用户看来是不必要的话术分裂。
- **是否有意区分**: 部分——一个强调"最新采样值"、一个强调"本地评估结果"，但底层是同一样本，区分过细。
- **用户可感知表现**: 同页两面板 subtitle 风格不一，感觉话术未统一。
- **建议**: 统一为 "Latest sample" 或 "Current sample"，规则面板补充 "locally evaluated" 而非换主语。
- **优先级**: L-低

### 矛盾 L1-12: 桌面 Mac（无电池）Power 页 "Power" 标签 + "Power Adapter" 值在相邻三处重复
- **位置1**: DashboardView.swift:780 — 电源信息表第一行 [snapshot.powerStatusTitle, snapshot.powerStatusText, snapshot.powerSourceText] → 无电池时 ["Power", "Power Adapter", "Power Adapter"]
- **位置2**: DashboardView.swift:822 — powerDetails KeyValueGrid (powerSourceLabel="Power", snapshot.powerSourceText="Power Adapter")
- **位置3**: DashboardView.swift:815 — powerGauge 用 snapshot.powerStatusTitle="Power" + snapshot.powerStatusText="Power Adapter"
- **矛盾描述**: 无电池桌面 Mac 上，Power 页三处相邻展示均以 "Power" 为标签、"Power Adapter" 为值：gauge 标题 "Power"/值 "Power Adapter"、信息表第一行 "Power"|"Power Adapter"|"Power Adapter"、KeyValueGrid "Power"|"Power Adapter"。同面板内 "Power = Power Adapter" 重复三次，且信息表 description 列与 value 列同为 "Power Adapter"。
- **是否有意区分**: 否——未针对无电池场景裁剪文案。
- **用户可感知表现**: 桌面 Mac 用户看到 "Power / Power Adapter / Power Adapter" 与 "Power = Power Adapter" 反复，信息冗余且像 bug。
- **建议**: 无电池场景下 powerStatusText 与 powerSourceText 二选一展示，或 powerStatusText 改为 "Connected" 等状态词，避免标签值同义重复。
- **优先级**: L-低

### 矛盾 L1-13: 隐私文案 app settings 与 README 范围不一致
- **位置1**: PulseDockAppStrings.swift:947 — settingsPrivacyPolicyDetail="Local sampling, no account, no tracking"
- **位置2**: README.md:61 — "samples local system metrics on device. It does not create accounts, collect personal data, track users, run analytics, or send remote probes."
- **矛盾描述**: app 内隐私摘要列 3 项（local sampling / no account / no tracking），README 列 5 项（+ collect personal data / run analytics / send remote probes）。app 摘要未覆盖"不采集个人数据/不做分析/不发远程探测"，用户在 app 内看到的隐私承诺范围窄于 README 公开声明。
- **是否有意区分**: 部分——app 摘要有意精简，但"不采集个人数据"是关键隐私承诺，缺失会让 app 内文案显得承诺不足。
- **用户可感知表现**: 用户对比 app 隐私页与 README，发现 app 未提"不采集个人数据"。
- **建议**: app 摘要补全为 "Local sampling, no personal data, no account, no tracking, no remote probes" 或与 README 完全对齐。
- **优先级**: L-低

---

## 三、跨模块同义对照表

| 概念 | app 变体 | widget 变体 | shared 变体 | 是否一致 |
|------|----------|-------------|-------------|----------|
| CPU | "CPU"（metricCPU） | "CPU"（metricCPU） | — | 一致 |
| Memory | "Memory"（metricMemory） | "Memory"/"MEM"（metricMemory / metricMemoryCompact） | — | widget 内 "Memory" vs "MEM" 双形（有意缩写） |
| Thermal | "Thermal"（metricThermalState） | "Thermal" / "Heat"（metricThermalState / miniThermal） | thermalStateNominal 等 | widget "Heat" 漂移（L1-7） |
| Network Connection | "Network Connection"（metricNetworkConnection）/ "Connection Status" | "Connection"（metricConnection） | networkPathStatusOnline 等 | 不一致（L1-8） |
| Disk | "Disk"（metricDisk） | "Disk"（metricDisk） | — | 一致 |
| Load | "Load"（metricLoad） | "Load"（metricLoad） | — | 一致 |
| Power | "Power"（powerSourceLabel / powerStatusTitlePower）/ "Power & Battery" | "Power"（compactPowerAdapter） | powerSourceAdapter / powerSourceNoBattery 等 | "Power" 多义（L1-12） |
| Uptime | "Uptime"（metricUptime） | "Uptime"（metricUptime） | — | 一致 |
| System Version | "System Version"（metricSystemVersion） | "System"（metricSystem） | — | widget 简化为 "System"（有意） |
| Kernel | "Kernel Version"（metricKernelVersion）/ "Kernel"（metricKernel） | "Kernel"（metricKernel） | — | app 内 "Kernel" vs "Kernel Version" 双形 |
| GPU/Displays | "GPU / Display"（页）/ "GPU / Displays"（行）/ "GPU & Unified Memory"（面板） | — | gpuKindExternal 等 | 不一致（L1-5） |
| Not reported | "Not reported" / "System did not report" | "Not reported" | "Not reported" / "System did not report" | 三表 defaultValue 一致；双术语漂移（L1-9） |
| System Status | "System Status"（Overview 面板 / Sensors 热行） | "System Status"（Large 头部） | — | 同字面三义（L1-3） |
| Widget Refresh | "Scheduled by the system timeline" / "System Scheduled" / "5m" | nextRefresh=5min（请求） | — | 同屏冲突（L1-1） |
| Widget Sizes | "Small / Medium / Large" | [.systemSmall, .systemMedium, .systemLarge] | — | 一致（已验证，无 ExtraLarge/accessory，与文案吻合） |
| Pause/Resume | "Resume"/"Pause"（动作）+ "Paused"/"Live"（状态） | — | — | 一致（已验证：paused→Resume+Paused，live→Pause+Live，无冲突） |
| Bundle name | "Pulse Dock"（AppInfo） | "Pulse Dock"（gallery）/ "Pulse Dock Widget"（WidgetInfo） | — | widget 内部不一致（L1-10） |
| Privacy | "Local sampling, no account, no tracking" | — | — | 与 README 范围不一（L1-13） |
| Process sort | "Foreground first, sorted by name" | — | — | 一致（已验证 MetricsStore.swift:456-467：isActive 优先→非 hidden→名称排序，与 subtitle 吻合；仅未提 hidden 中间排序，非矛盾） |

---

## 四、与 REVIEW-PLAN.md 重叠项

| 本报告 ID | REVIEW-PLAN.md 对应项 | 重叠说明 |
|-----------|----------------------|----------|
| L1-1 | P2-5（"5m" widget 刷新值硬编码，与 detail "由系统时间线调度"矛盾） | REVIEW-PLAN 已列为整洁/本地化级（P2-5），本报告升级为话术矛盾 L-中，补充同屏 "System Scheduled" 对照与 nextRefresh 仅为请求值的事实 |
| L1-5 | P2-5（硬编码 "Pulse Dock"/"CPU"/"MEM"/"Core N" 未走本地化） | 部分重叠：本报告聚焦 "GPU / Display" 单复数与 "/" vs "&" 连词漂移，REVIEW-PLAN 侧重本地化缺失 |
| L1-7 | P2-5（widget "CPU"/"UPS" 硬编码） | 部分重叠：本报告聚焦 "Heat" vs "Thermal" 同源缩写问题 |
| L1-9 | P3（"Not reported" 双术语） | REVIEW-PLAN 未单独列出，但属 P3 整洁级本地化范畴 |
| L1-2 | 无（新发现） | "No Battery" 与 hasPowerStatusReport 语义冲突为新发现，REVIEW-PLAN 未涉及 |
| L1-3 | 无（新发现） | "System Status" 同字面三义为新发现 |
| L1-4 | 无（新发现） | Sensors/History 同表异题异状态词为新发现 |
| L1-6 | P1-4/P2-9（widget fallback 首次退化、freshness） | 部分重叠：本报告从话术角度指出 widgetDescription 指标清单与 Large 实际范围不符，REVIEW-PLAN 侧重 fallback 数据退化 |
| L1-8/L1-10/L1-11/L1-12/L1-13 | 无（新发现） | 均为本报告话术专项新发现 |

---

## 五、已验证为一致的项（排除项）

以下锚点经对照源码验证后确认**不构成矛盾**，列出以避免重复审查：

1. **settingsWidgetSizesValue vs supportedFamilies**：app "Small / Medium / Large"（PulseDockAppStrings.swift:1039）与 widget supportedFamilies=[.systemSmall, .systemMedium, .systemLarge]（SystemDashboardWidget.swift:148）完全吻合，无 ExtraLarge/accessory，文案未失实。
2. **menuResumeRefresh/menuPauseRefresh vs menuStatusPaused/menuStatusLive**：popover 内 paused 态显示 "Resume" 动作 + "Paused" 徽章，live 态显示 "Pause" 动作 + "Live" 徽章（WidgetPanelView.swift:87/122），动作与状态语义自洽，无冲突。
3. **processesDefaultSubtitle vs 实际排序**："Foreground first, sorted by name"（:805）与 MetricsStore.swift:456-467 排序逻辑（isActive 优先 → 非 hidden 优先 → localizedStandardCompare 名称）吻合；subtitle 未提 hidden 中间排序属精简，非矛盾。
4. **"Not reported" defaultValue 三表一致**：app（:1087）/widget（:85）/shared（:5）defaultValue 均为 "Not reported"，跨模块字面一致（DRY 重复属维护问题，见 L1-9）。
5. **AppInfo.plist ITSAppUsesNonExemptEncryption**：已声明为 false（AppInfo.plist:31-32），与 README 隐私声明一致。
