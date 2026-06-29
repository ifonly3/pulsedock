# L4 — 设计语义合理性报告

> 审查对象：Pulse Dock macOS 系统监控应用
> 审查维度：复用同一 UI 容器/标题/控件但语义随状态变化；阈值/窗口自相矛盾
> 审查基准：当前 working tree（MetricSnapshot.swift 1763 行 / SystemDashboardWidget.swift 757 行 / DashboardView.swift 2337 行 / MetricsStore.swift 513 行）
> 制定日期：2026-06-28

---

## 一、状态空间矩阵

### 1.1 powerStatus 系列完整状态矩阵

派生属性来源：
- `powerStatusText`：`MetricSnapshot.swift:1279-1281` → `batteryPercent == nil ? powerSourceText : batteryPercentText`
- `powerStatusTitle`：`MetricSnapshot.swift:1325-1327` → `batteryPercent == nil ? "Power" : "Battery"`
- `powerStatusProgress`：`MetricSnapshot.swift:1285-1287` → 直接返回 `batteryPercent`（Optional）
- `powerStatusTone`：`MetricSnapshot.swift:1288-1323`
- `powerSourceText`：`MetricSnapshot.swift:1261-1277`

`batteryPercent` 取 4 档（nil / 低 <0.2 / 中 0.2-0.5 / 高 ≥0.5），`batteryPowerSource` 取 5 档（nil / AC / Battery / UPS / Other-non-empty），`batteryIsCharging` 取 2 档，共 4×5×2=40 组合。下表枚举现实中可达的组合（标 ✅ 现实可达 / ⚠️ 罕见 / ❌ 不现实但代码会处理）。

| batteryPercent | batteryPowerSource | batteryIsCharging | powerStatusText | powerStatusTitle | powerStatusProgress | powerStatusTone | 合理性评估 |
|---|---|---|---|---|---|---|---|
| nil | nil | false | "Not Reported" | "Power" | nil | neutral | ✅ 桌面 Mac 启动早期 / 无电源信息；语义自洽 |
| nil | "AC Power" | false | "Power Adapter" | "Power" | nil | normal | ✅ 桌面 Mac 常态；标题"Power"+空环+"Power Adapter" 文本，用户可能误读空环为 0% 电量 |
| nil | "AC Power" | true | "Power Adapter · Charging" | "Power" | nil | normal | ⚠️ 桌面 Mac 不应报 charging=true；若发生，文案自洽但"charging"语义对无电池设备困惑 |
| nil | "Battery Power" | false | "Battery Power" | "Power" | nil | warning | ⚠️ 电量未报但来源为 Battery；标题"Power"+空环+"Battery Power" 文本——空环 vs "Battery Power" 互相矛盾 |
| nil | "UPS Power" | false | "UPS Power" | "Power" | nil | warning | ✅ UPS 接入；自洽 |
| nil | Other non-empty | * | (原值透传) | "Power" | nil | neutral | ⚠️ "Wireless Power" 等新电源类型直接以英文原值展示（未本地化），且 `powerSourceNoBattery` "No Battery" 分支不可达（见 L4-7） |
| 低 <0.2 | "AC Power" | true | "18%" | "Battery" | 0.18 | **critical** | ⚠️ **语义冲突**：插着适配器充电但显示 critical(红)；红色通常意味"需立即行动"，但用户已行动（插电）。详见 L4-2 |
| 低 <0.2 | "AC Power" | false | "18%" | "Battery" | 0.18 | critical | ✅ 满电临界充电中止；合理 |
| 低 <0.2 | "Battery Power" | false | "18%" | "Battery" | 0.18 | critical | ✅ 笔记本低电量；合理 |
| 低 <0.2 | "Battery Power" | true | "18%" | "Battery" | 0.18 | critical | ⚠️ 笔记本边充边用极低电量；与 AC+charging 同样矛盾（L4-2） |
| 中 0.2-0.5 | "AC Power" | true | "35%" | "Battery" | 0.35 | **warning** | ⚠️ **语义冲突**：充电中显示 warning(琥珀)，用户可能误以为充电异常。详见 L4-2 |
| 中 0.2-0.5 | "AC Power" | false | "35%" | "Battery" | 0.35 | warning | ✅ 充满后用适配器运行但电量未满；合理 |
| 中 0.2-0.5 | "Battery Power" | false | "35%" | "Battery" | 0.35 | warning | ✅ 笔记本中等电量；合理 |
| 高 ≥0.5 | "AC Power" | true | "75%" | "Battery" | 0.75 | normal | ✅ 充电中且已过半；合理 |
| 高 ≥0.5 | "AC Power" | false | "100%" | "Battery" | 1.0 | normal | ✅ 满电接适配器；合理 |
| 高 ≥0.5 | "Battery Power" | false | "75%" | "Battery" | 0.75 | normal | ✅ 笔记本高电量使用；合理（无提前告警，到 50% 才转 warning） |
| 高 ≥0.5 | "Battery Power" | true | "75%" | "Battery" | 0.75 | normal | ⚠️ "Battery Power" + charging=true 状态机不该同时出现；若发生，色调 normal 合理 |
| 高 ≥0.5 | "UPS Power" | false | "80%" | "Battery" | 0.80 | **warning** | ✅ UPS 供电；合理 |
| 高 ≥0.5 | nil | * | "Power Adapter · Charging" 或 "Power state not reported" | "Battery" | 0.80 | normal | ⚠️ 电量已报但来源未报；fallback 文案"Power state not reported"在 `powerSourceText` 中（line 1276），但 `powerStatusText` 此时显示的是百分比，所以这条文案实际不出现在主卡片，只在 Power 页表格的 Power Source 行出现 |

**矩阵结论**：
1. `powerStatusTone` 在 `batteryPercent < 0.5` 时**完全忽略 `batteryIsCharging`**，导致充电中仍显示 warning/critical。审查计划 [ANCHOR-C1] 描述的"batteryIsCharging → normal 覆盖低电量"前提**与实际代码相反**——实际是低电量无条件覆盖充电状态。
2. `powerStatusTitle` 在有/无电池之间从"Battery"切换到"Power"，`powerStatusProgress` 从有数值切换到 nil（空环），`powerStatusText` 从百分比切换到电源来源描述。同一卡片三维度同时切换语义类别（量化 → 定性），见 L4-1。
3. `powerSourceText` 中 `powerSourceNoBattery` "No Battery" 分支（MetricSnapshot.swift:1273-1274）**不可达**，见 L4-7。

### 1.2 networkPathProgress 状态矩阵

`networkPathProgress`（SystemDashboardWidget.swift:697-708 与 DashboardView.swift:2249-2260 完全镜像）返回 `Double`（非 Optional）：

| networkPathStatus | hasNetworkPathReport | networkPathProgress | UI 表现 (WidgetRow) |
|---|---|---|---|
| "satisfied" | true | 1.0 | 标题"Connection" + 值"Online" + 满 progress 条（绿色） |
| "unsatisfied" | true | 0.0 | 标题"Connection" + 值"Offline" + 0 宽 progress 条（红色） |
| "requiresconnection" | true | 0.45 | 标题"Connection" + 值"Requires Connection" + 45% progress 条（琥珀） |
| 空字符串 / 未识别 / "unknown" | **false** | 0.0 | 标题"Connection" + 值"Not Reported" + **无 progress 条**（外层 `reportedProgress` 返回 nil） |

**结论**：所有 widget 调用点（SystemDashboardWidget.swift:221, 270-272）都用 `reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: networkPathProgress(snapshot))` 包装，所以未识别状态实际不会渲染空 progress 条——审查计划描述的"未识别状态渲染空进度条"风险**在当前调用点不成立**。但 `networkPathProgress` 本身返回非 Optional Double 且 default=0，与 `unsatisfied` 的 0 不可区分，依赖外层 `hasNetworkPathReport` 才能区分"未报告"与"离线"。这是防御性设计薄弱，见 L4-5。

### 1.3 widget freshness 状态矩阵

`WidgetFreshnessTone.resolve(age:)`（WidgetVisualTokens.swift:8-13）：

| snapshotAge | freshnessTone | 圆点颜色 | 可访问性文案 | 视觉文案 |
|---|---|---|---|---|
| nil 或 <0 | fresh | 绿 | "Pulse Dock" | 仅 6px 圆点 |
| 0 ≤ age < 300 | fresh | 绿 | "Pulse Dock" | 仅 6px 圆点 |
| 300 ≤ age < 600 | aging | 琥珀 | "Stale data" | 仅 6px 圆点 |
| ≥ 600 | stale | 红 | "Stale data" | 仅 6px 圆点 |

**结论**：`staleData` 文案（PulseDockWidgetStrings.swift:108）**仅作为 accessibilityLabel 消费**，视觉上只有圆点颜色变化（6px 直径）。`sharedSnapshotMaxAge=600s` 与 stale 阈值重合，意味着 widget 接受数据的最长寿命 = 触发红色"stale"的阈值，即 widget 在最长允许的过期数据下恰好显示红色但**不会拒绝展示**——见 L4-3。

---

## 二、设计合理性发现

### 发现 L4-1: powerStatus 卡片三维度语义随电池存在性同时切换
- **设计点**: 
  - `MetricSnapshot.swift:1279-1281` (powerStatusText)
  - `MetricSnapshot.swift:1285-1287` (powerStatusProgress)
  - `MetricSnapshot.swift:1325-1327` (powerStatusTitle)
  - `MetricSnapshot.swift:1288-1323` (powerStatusTone)
  - 消费点：`DashboardView.swift:815` (RingGauge in PowerPage)、`DashboardView.swift:780, 990` (表格行)、`WidgetPanelView.swift:61` (PopoverSmallStat)、`SystemDashboardWidget.swift:188, 238, 262` (MiniStatus/StatTile)
- **语义冲突描述**: 同一个"powerStatus"卡片族在 `batteryPercent` 是否为 nil 之间发生**三维度同时切换**：
  - 标题：`"Battery"` ↔ `"Power"`（量化实体 ↔ 抽象概念）
  - 文本：`"86%"`（百分比，量化） ↔ `"Power Adapter"` / `"Battery Power"` / `"UPS Power"`（电源类型，定性）
  - 进度：`0.86`（实数） ↔ `nil`（无进度，环空）
  - 色调：基于电量阈值 ↔ 基于电源来源
- **用户影响**: 
  - 桌面 Mac 用户（无电池）看到 "Power: Power Adapter" + **空环**——容易误读为"0% 电量"而非"无电池"。
  - MacBook 在 SMC/电池通信异常导致 `batteryPercent` 暂时返回 nil 时（实际发生过），卡片从 "Battery: 86%" + 绿色 86% 环 突变为 "Power: Battery Power" + 空环 + warning 琥珀色——用户以为电量瞬间掉到 0。
  - PopoverSmallStat（WidgetPanelView.swift:61）甚至不显示进度，只有标题+文本+小圆点，标题/文本突变更明显。
- **建议**: 
  - 在无电池场景下渲染**明确的"No Battery"标签**而非空环 + 电源来源文本。
  - 将 `powerStatusTitle` 拆为两个独立概念：`batteryLevelTitle`（量化，仅在有 `batteryPercent` 时显示）与 `powerSourceTitle`（定性，无电池时显示）。当前用一个标题复用两个语义是根因。
  - 至少在 RingGauge 上 nil 进度时显示"SystePower"占位图标或"—"而非纯空环。
- **优先级**: L-中

### 发现 L4-2: powerStatusTone 低电量充电时显示 critical/warning，与"已接入电源"语义冲突
- **设计点**: `MetricSnapshot.swift:1288-1323`
  ```swift
  if let batteryPercent {
      if batteryPercent < 0.2 { return .critical }      // 早返回，忽略 charging
      if batteryPercent < 0.5 { return .warning }       // 早返回，忽略 charging
      if batteryIsCharging { return .normal }
      switch batteryPowerSource?.lowercased() { ... }
  }
  ```
- **语义冲突描述**: 色调在 `< 0.5` 区间**完全忽略 `batteryIsCharging`**。实际行为：
  - 19% + charging → **critical（红）**
  - 35% + charging → **warning（琥珀）**
  - 60% + charging → normal（绿）
  
  审查计划 [ANCHOR] 描述的"batteryIsCharging → normal 覆盖低电量"**与代码相反**——实际是低电量阈值早返回覆盖了充电状态。
- **用户影响**: 
  - 用户在电量 19% 时插入适配器，期待"正在恢复"的视觉反馈（绿/向上箭头），却看到**红色 critical**——红色通常意味"需立即行动"，但用户已经行动（插电）。造成"充电是不是没生效？"的疑惑。
  - 35% 充电中显示琥珀，与 60% 充电中显示绿色之间是 50% 处的**硬台阶**，用户在充电过程中观察颜色从红→琥珀→绿突变，缺少过渡。
  - 色调语义在不同电量区间**不一致**：低电量区="当前严重度"，高电量区="充电/来源状态"。同一属性混合两种语义。
- **建议**: 
  - 让 `batteryIsCharging` 在低电量区也参与判定：`batteryPercent < 0.2 && !batteryIsCharging → critical`；`batteryPercent < 0.2 && batteryIsCharging → warning`（"正在恢复但仍偏低"）。
  - 或在色调外引入"trend"维度（charging/discharging），用箭头图标而非颜色表达。
- **优先级**: L-中

### 发现 L4-3: widget freshness 窗口 (600s) 等于 stale 阈值，导致最长允许数据恰好显示红色但不拒绝展示
- **设计点**: 
  - `SystemDashboardWidget.swift:41` — `sharedSnapshotMaxAge = 600`
  - `SystemDashboardWidget.swift:58` — `nextRefresh = 5 minutes (300s)`
  - `WidgetVisualTokens.swift:10` — `if age >= 600 { return .stale }`
  - `PulseDockWidgetStrings.swift:108` — `staleData = "Stale data"`
- **语义冲突描述**: 
  - `sharedSnapshotMaxAge=600s` 是 widget **愿意接受并展示**的最长数据寿命。
  - `WidgetFreshnessTone.stale` 阈值也是 600s。
  - `nextRefresh=300s` 是请求系统下次刷新的间隔。
  
  三者关系：`nextRefresh(300) < sharedSnapshotMaxAge(600) = staleThreshold(600)`。
  
  这意味着：
  1. 系统按时刷新（300s 一次）→ 数据最长 300s 旧 → 显示 `aging`（琥珀）而非 `fresh`。**正常运作下永远不会显示绿色 fresh**（除非 app 持续写入 shared snapshot 让 widget 在 300s 内拿到新数据）。
  2. App 崩溃/被杀 → widget 在 600s 内继续展示最后写入的数据，恰好显示红色 stale，但**仍然展示**，不切到 fallback。
  3. 超过 600s → `loadLatestSnapshot` 返回 nil → `sampleCompact()` 实时采样 → 显示真实新数据。
  
  **窗口矛盾**：`nextRefresh=300s` 与 `aging=300s` 重合，意味着系统即使按时刷新，widget 也可能显示琥珀"stale data"——把"正常刷新周期"标记为"老化"。
- **用户影响**: 
  - 视觉上仅 6px 圆点颜色变化（无文案），用户几乎不会注意到 staleness 指示。
  - `staleData` 文案仅在 `accessibilityLabel` 中消费，明眼用户看不到。
  - 在 app 被杀的 10 分钟窗口内，widget 显示红色圆点 + 真实但过期的数据，用户可能据此误判系统状态。
- **建议**: 
  - `sharedSnapshotMaxAge` 应**小于** `staleThreshold`（例如 300s），让 stale 状态触发 fallback 到 `sampleCompact()` 而非继续展示过期数据。
  - 或在 stale 时显示明确的"Stale data"文案而非仅圆点变色。
  - 调整 `nextRefresh` 与 `aging` 阈值的关系：`nextRefresh` 应 ≤ `aging` 阈值，避免正常刷新就被标"老化"。
- **优先级**: L-中

### 发现 L4-4: Sparkline 展示窗口 (80) 与历史窗口 (90/180/360) 及 chip 文案不对齐
- **设计点**: 
  - `DashboardView.swift:1562-1572` — `preparedValues` 取 `values.suffix(80)`
  - `DashboardView.swift:2171-2174` — `reportedHistorySampleChipText` 报告 `history.filter(\.hasSampleTimeReport).count`（最多 360）
  - `MetricsStore.swift:22-30` — `HistoryDepthOption` 90/180/360
  - trend 提取器（DashboardView.swift:2177-2217）返回**全部**匹配 history 的值，最多 360 个
- **语义冲突描述**: 
  - 用户选择"Extended (360 samples)" → history 数组最多 360 个 snapshot。
  - CPU 页 `processorPanel`（DashboardView.swift:538）渲染 chip 文本"Recent 360"（来自 `reportedHistorySampleChipText`），但下方 Sparkline 只画最后 80 个点。
  - 用户看到"Recent 360 samples"标签 + 一条曲线，自然认为曲线代表 360 个采样点。**实际曲线只代表最近 80 个采样点**，相当于展示了历史窗口的 22%。
- **用户影响**: 
  - 历史深度选择"360"与"90"在 sparkline 视觉上**几乎无差别**（都画 80 个点），用户无法感知历史深度切换的视觉变化。
  - chip 文案"Recent 360"与曲线点数（80）矛盾。
- **建议**: 
  - 让 chip 文案反映实际绘制的采样数：`reportedHistorySampleChipText` 应基于 `min(history.count, 80)` 而非 `history.count`。
  - 或让 `Sparkline.preparedValues` 的 `suffix(80)` 改为 `suffix(historyDepth.sampleCount)`，让曲线真正反映所选历史深度（需评估 360 点在 46px 高度的可读性）。
  - 或拆分语义：chip 标"Recent 360 (showing last 80)"。
- **优先级**: L-中

### 发现 L4-5: networkPathProgress 返回非 Optional Double，"未报告"与"离线"在函数内部不可区分
- **设计点**: 
  - `SystemDashboardWidget.swift:697-708` — `networkPathProgress` 返回 `Double`，default=0
  - `DashboardView.swift:2249-2260` — 镜像实现
  - 所有调用点（SystemDashboardWidget.swift:221, 270-272; DashboardView.swift:2202）外层包 `reportedProgress(hasReport:hasNetworkPathReport, progress: networkPathProgress(snapshot))`
- **语义冲突描述**: `networkPathProgress` 对 `unsatisfied` 返回 0，对未识别状态（default）也返回 0。两者在函数返回值上**完全相同**，仅靠外层 `hasNetworkPathReport` 区分。如果未来新增调用点忘记包 `reportedProgress`，未报告状态会被渲染为 0% 进度条（视觉上等同"离线"）。
- **用户影响**: 当前调用点都正确包装，无用户可见影响。**未来维护风险**：新增 widget family 或重构时容易遗漏包装。
- **建议**: 将 `networkPathProgress` 改为返回 `Double?`，未识别状态返回 nil，与 `networkPathText` 的 "Not Reported" 分支对齐。或封装为 `networkPathReportedProgress(snapshot)` 一次性返回 Optional，消除包装样板。
- **优先级**: L-低

### 发现 L4-6: MetricScales.tenGigabitBytesPerSecond 硬上限使 25/40/100 GbE 链路"满格"语义误导
- **设计点**: 
  - `MetricScales.swift:4` — `tenGigabitBytesPerSecond = 1_250_000_000` (10 GbE = 1.25 GB/s)
  - `MetricScales.swift:6-10` — `networkRateProgress` 用 `min(Double(bytesPerSecond), tenGigabitBytesPerSecond)` 钳制后做 log10 归一化
- **语义冲突描述**: 
  - 进度条语义：log10 归一化的"饱和度"，硬上限 10 GbE。
  - 文本语义（`networkText` MetricSnapshot.swift:1328-1331）：`MetricFormatting.networkRate` 输出真实速率（如"3.5 GB/s"）。
  - 两者单位一致但**量程不同**：进度条到 10 GbE 满格，文本可继续增长。
  - 25 GbE 链路在 50% 利用率（1.25 GB/s）时进度条=100%，文本="1.25 GB/s"；100 GbE 链路在 12.5% 利用率（1.25 GB/s）时进度条也=100%。**完全不同的链路状态呈现为相同的进度条**。
- **用户影响**: 
  - 消费级 Mac（千兆/2.5G/10G）几乎不会触发，影响小。
  - Mac Pro / Mac Studio with 25/40/100 GbE 卡的专业用户会看到满格进度条但实际链路未饱和——误判性能瓶颈。
- **建议**: 
  - 提升硬上限到 100 GbE 或更高（`12_500_000_000`）。
  - 或进度条不钳制，让 log10 比例值反映真实饱和度（但低速率区分度下降）。
  - 或在 UI 上明确进度条语义为"relative to 10 GbE"，避免用户误读为链路饱和度。
- **优先级**: L-低

### 发现 L4-7: powerSourceText 中 "No Battery" 分支不可达（dead code + 设计意图与实现漂移）
- **设计点**: 
  - `MetricSnapshot.swift:1261-1277` — `powerSourceText` switch
  - `MetricSnapshot.swift:962-965` — `reportedPowerSource` 在 init 时 trim 空白，空字符串转为 nil
  - `SharedMetricStrings.swift:277-279` — `powerSourceNoBattery = "No Battery"` 仅在 MetricSnapshot.swift:1274 引用
- **语义冲突描述**: 
  ```swift
  public var powerSourceText: String {
      switch batteryPowerSource?.lowercased() {
      case "ac power": ...
      case "battery power": ...
      case "ups power": ...
      case .some(let value) where !value.isEmpty: return value   // 任何非空字符串都被这里捕获
      default:
          if batteryPercent == nil {
              guard batteryPowerSource != nil else { return SharedMetricStrings.notReported }
              return SharedMetricStrings.powerSourceNoBattery   // ← 不可达
          }
          return batteryIsCharging ? ... : ...
      }
  }
  ```
  - `reportedPowerSource` 保证 `batteryPowerSource` 要么是 nil 要么是非空非空白字符串。
  - 任何非空字符串都会被 `case .some(let value) where !value.isEmpty` 捕获并原值透传。
  - 因此 `default` 分支只在 `batteryPowerSource == nil` 时进入；`guard batteryPowerSource != nil` 必定失败，return "Not Reported"。
  - 紧接其后的 `return SharedMetricStrings.powerSourceNoBattery` 永远不会执行。
- **设计意图与实现漂移**: 从 `SharedMetricStrings.powerSourceNoBattery` 的存在可推断设计意图是"电源来源已报但未识别（如新型无线供电）→ 显示 No Battery"。但实际代码把所有未识别来源都透传原值，导致：
  - "Wireless Power" 等新型来源以**英文原值**展示（未本地化）。
  - "No Battery" 本地化字符串（en/zh-Hans 都有翻译）**永远不会展示给用户**。
- **用户影响**: 
  - 极少数新型电源来源用户看到未本地化的英文原值。
  - 本地化翻译工作做了但没生效（维护成本浪费）。
- **建议**: 
  - 删除 `case .some(let value) where !value.isEmpty` 透传分支，改为 fallthrough 到 default 的 "No Battery" 路径，让未识别来源统一显示"No Battery"。
  - 或保留透传但在 default 路径前显式判断 `batteryPowerSource` 是否在已知集合内。
- **优先级**: L-低（dead code）+ L-中（设计意图漂移）

### 发现 L4-8: 设置页"5m"硬编码标签与同页"System Scheduled"文案语义冲突
- **设计点**: 
  - `DashboardView.swift:1167` — `SettingReadOnlyRow(title: settingsWidgetRefreshTitle, detail: settingsWidgetRefreshDetail, control: "5m")`
  - `PulseDockAppStrings.swift:1018-1020` — `settingsWidgetRefreshDetail = "Scheduled by the system timeline"`
  - `PulseDockAppStrings.swift:1054-1056` — `settingsWidgetRefreshValue = "System Scheduled"`
  - `DashboardView.swift:1354` — `DataChip(icon: "timer", text: settingsWidgetRefreshValue)` 在 WidgetPreviewPanel 内
  - `SystemDashboardWidget.swift:58` — `nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: now)`
- **语义冲突描述**: 
  - 同一个 Settings 页面，同一个"Widget Refresh"概念：
    - 行 1167 显示 `"5m"`（硬编码字符串，未走 localized）作为 control 文本，detail 为"Scheduled by the system timeline"。
    - 行 1354 在 WidgetMiniPreview 旁的 DataChip 显示 `"System Scheduled"`。
  - 用户在同一屏看到"5m"和"System Scheduled"两个不同标签指代同一事实。
  - "5m" 暗示**确定性**的 5 分钟刷新；但 WidgetKit 的 `.after(nextRefresh)` 是**请求值非保证值**——系统可能因低功耗/后台限制延后。
  - "System Scheduled" 与 detail "Scheduled by the system timeline" 是诚实表述。
  - "5m" 硬编码字符串绕过 `PulseDockAppStrings.localized` 路径，多语言下不会翻译。
- **用户影响**: 
  - 用户看到"5m"以为 widget 每 5 分钟准点刷新；实际可能延迟到 10 分钟（与 L4-3 的 600s 窗口吻合）。
  - 同屏两个标签语义冲突引发困惑。
- **建议**: 
  - 将 "5m" 替换为 `settingsWidgetRefreshValue`（"System Scheduled"）或新增 `settingsWidgetRefreshIntervalValue = "≈ 5m"` 暗示非确定性。
  - 走 localized 路径。
- **优先级**: L-中

### 发现 L4-9: Processes 页四个 SummaryCard 标题语义重叠，"List Items" 是 UI 元数据而非系统指标
- **设计点**: 
  - `DashboardView.swift:922-925` — 四个 SummaryCard：
    - `processesRunningAppsTitle` ("Running Apps") → `runningAppCountText`（= `processCount`，运行中应用总数）
    - `processesListItemsTitle` ("List Items") → `runningAppListCountText`（= `runningApps.filter(\.hasInventoryReport).count`，截断后列表行数，max 8）
    - `processesForegroundAppsTitle` ("Foreground Apps") → `activeApplicationCountText`（= `activeApplicationCount`，通常 1）
    - `processesHiddenAppsTitle` ("Hidden Apps") → `hiddenApplicationCountText`（= `hiddenApplicationCount`）
  - `MetricSnapshot.swift:1182-1203` — count 派生属性
  - `MetricsStore.swift:445-481` — `applyVisibleApplicationSummary` 把 `processCount` 设为 `NSWorkspace.runningApplications` 总数，`runningApps` 截断为前 8
- **语义冲突描述**: 
  - "Running Apps"（如 23）与"List Items"（如 8）并列展示，但**前者是系统级总数，后者是 UI 列表行数**——两个不同语义层级的数值以相同视觉权重呈现。
  - 用户会问："Running Apps 是 23，为什么 List Items 只有 8？"——"List Items"是 UI 元数据，本不该作为系统状态指标展示。
  - `processesRunningAppsTitle` 在 CPU 页（DashboardView.swift:522）、Memory 页（:582）、Processes 页（:928）重复出现，但 subtitle 不一致：
    - CPU 页：`processesDefaultSubtitle` = "Foreground first, sorted by name"
    - Memory 页：`processesCurrentSessionSubtitle`（不同文案）
    - Processes 页：`processesDefaultSubtitle`
  - 同一标题 + 同一数据 + 不同 subtitle 在不同页面切换时引发"这是同一面板还是不同面板？"的困惑。
- **用户影响**: 
  - "List Items" 概念陌生，用户不理解其含义。
  - "Running Apps" 23 vs 列表实际显示 8 行，用户以为漏数据。
- **建议**: 
  - 删除"List Items" SummaryCard，或改名为"Displayed Apps"并在 subtitle 标注"showing first 8"。
  - 统一 `processesRunningAppsTitle` 面板在 CPU/Memory/Processes 三页的 subtitle，或在 CPU/Memory 页改用不同标题（如"Active Session"）。
- **优先级**: L-中

### 发现 L4-10: placeholder / getSnapshot / getTimeline 三条路径数据真实性层级未在 UI 体现
- **设计点**: 
  - `SystemDashboardWidget.swift:43-45` — `placeholder(in:)` 返回 `representativeSnapshot()`（合成 fixture：CPU 37%, Mem 8.6/16GB, Battery 86%, Network 1.2MB/s 等）
  - `SystemDashboardWidget.swift:47-49` — `getSnapshot(in:)` 同样返回 `representativeSnapshot()`
  - `SystemDashboardWidget.swift:51-61` — `getTimeline(in:)` 返回 `sampledSnapshotForTimeline(now:)`，先尝试 `loadLatestSnapshot(maxAge: 600s)`（app 写入的真实数据），fallback 到 `sampleCompact()`（实时采样）
  - `SystemDashboardWidget.swift:68-111` — `representativeSnapshot()` fixture 数据
- **语义冲突描述**: 
  - **placeholder**（WidgetKit gallery / 首次加载）：合成 fixture，用户在 widget gallery 看到的预览数据是固定的 37% CPU、86% battery 等。
  - **getSnapshot**（WidgetKit 临时请求）：**也是合成 fixture**，不是真实数据。WidgetKit 在 timeline 还没准备好时调用 getSnapshot。
  - **getTimeline**（正常 timeline）：真实数据（shared store 或 fresh sample）。
  
  三条路径数据真实性递增：synthetic → synthetic → real。但 UI 上**没有任何标识**区分 fixture 数据与真实数据。fixture 数据看起来与真实数据视觉一致（同样的卡片、同样的颜色）。
- **用户影响**: 
  - Widget gallery 中预览数据是 fixture（用户可能误以为是当前系统状态）。
  - 极少触发 getSnapshot 的场景下，用户看到 fixture 数据（CPU 37% 等）但以为是真的。
  - `representativeSnapshot()` 的 battery 86% 在桌面 Mac（无电池）的 gallery 预览中显示，与实际硬件矛盾。
- **建议**: 
  - 在 `representativeSnapshot()` 上标记 `isPlaceholder: true`，UI 渲染时加 watermark 或淡化。
  - 或让 `getSnapshot` 也尝试读取 shared store（与 getTimeline 一致），仅在 store 为空时才用 fixture。
  - Widget gallery 场景下 fixture 不可避免（系统限制），可接受；但应避免 fixture 数据看起来"过于真实"。
- **优先级**: L-低

### 发现 L4-11: refreshGeneration 失效机制导致历史采样间隙，sparkline 出现不可见缺口
- **设计点**: 
  - `MetricsStore.swift:62` — `refreshGeneration = 0`
  - `MetricsStore.swift:321` — `cancelRefreshTask()` 自增 `refreshGeneration += 1`
  - `MetricsStore.swift:337-344` — refresh 任务捕获 generation，async 完成后 `guard generation == refreshGeneration else { return }` 直接返回，**不更新 snapshot、不 append history、不写 shared store**
  - `MetricsStore.swift:114-128` — `togglePause()` 调用 `cancelRefreshTask()`
- **语义冲突描述**: 
  - 用户在 t=0 触发 refresh，sampler 开始采样（耗时 100-500ms）。
  - t=0.2s 用户按 Pause → `cancelRefreshTask()` 自增 generation。
  - t=0.4s sampler 完成，回到 main actor 检查 generation 不匹配 → **静默丢弃采样结果**。
  - t=2s 用户按 Resume → `startInitialRefresh()` 重新采样。
  - 结果：t=0 到 t=2s 之间无 history sample，sparkline 在该处有不可见缺口。
  - 用户快速 toggle pause/resume 多次 → 多个采样被丢弃 → history 出现多个缺口，但 sparkline 用线性插值连接相邻点，缺口视觉上不可见——**用户以为数据连续**。
- **用户影响**: 
  - 频繁暂停/恢复的用户看到"平滑"曲线但实际有缺失采样。
  - 历史持久化（`persistHistoryIfNeeded`）保存的 history 已经过滤掉丢弃的采样，从磁盘恢复后缺口永久存在。
- **建议**: 
  - 在丢弃采样时记录 `lastSkippedRefreshDate`，UI 在 sparkline 上以虚线或断点标识。
  - 或在 pause 时仍完成 in-flight 采样再切换状态，避免半完成的工作被丢弃。
- **优先级**: L-低

### 发现 L4-12: MenuBarPopoverGeometry minimumHeight=420 在小屏/多 dock 场景下可能导致内容裁切
- **设计点**: 
  - `WidgetPanelView.swift:6-11` — `MenuPopoverLayout.height=520, minimumHeight=420, screenMargin=12`
  - `MenuBarPopoverGeometry.swift:166-174` — `clampedHeight`：若 `availableHeight < minimumHeight`，返回 `availableHeight`（小于 minimum）
  - `MenuBarPopoverGeometry.swift:144` — `availableHeight` 减去 `popoverChromeHeightAllowance=28`
- **语义冲突描述**: 
  - `clampedHeight` 逻辑：`visibleHeight = min(preferredHeight=520, max(1, availableHeight))`；若 `availableHeight >= minimumHeight=420` 则 `max(minimumHeight, visibleHeight)`，否则返回 `visibleHeight`（可能 < 420）。
  - 即当屏幕可用高度 < 420+28=448 时，popover 高度被压缩到 < 420。
  - `WidgetPanelView` 内容：header(16+34+12=62) + ScrollView(动态) + actions(16+22+16=54) ≈ 116 + ScrollView 高度。
  - 在 420 高度下，ScrollView 可用 ≈ 304px，足够显示 4 个 PopoverMetricRow（每个 ~52px = 208）+ 3 行 PopoverSmallStat（每行 ~60px = 180）+ padding ≈ 400——**接近溢出**。
  - 在小屏 MacBook（如 12" MacBook 1440x800，visibleFrame 高度 ~720 减 dock/menu ≈ 600）通常 OK；但若 dock 占大 + 多显示器主屏分辨率低，可能触发压缩。
  - `popoverChromeHeightAllowance=28` 是基于当前 AppKit popover chrome 的魔法数；macOS 未来版本若调整 chrome 尺寸，此值失效。
- **用户影响**: 
  - 在极端屏幕布局下 popover 内容可能需滚动才能看完，但 ScrollView 存在所以不会裁切——只是体验下降。
  - 真实风险低。
- **建议**: 
  - 在 `clampedHeight` 返回 < minimumHeight 时记录诊断日志，便于排查用户报告的"popover 太小"问题。
  - 将 `popoverChromeHeightAllowance` 提取为命名常量并注释来源（前次 review 已提，未落地）。
- **优先级**: L-低

### 发现 L4-13: Small widget 用 compactPowerStatusText，Medium/Large 用 powerStatusText，同状态文案不一致
- **设计点**: 
  - `SystemDashboardWidget.swift:740-757` — `compactPowerStatusText`：无电池时 AC+charging→"Charging", AC→"Adapter", Battery→"Battery", UPS→"UPS", other→"External", nil→"Not Reported"
  - `MetricSnapshot.swift:1279-1281` — `powerStatusText`：无电池时走 `powerSourceText`：AC+charging→"Power Adapter · Charging", AC→"Power Adapter", Battery→"Battery Power", UPS→"UPS Power", other→原值, nil→"Not Reported"
  - Small 消费点：`SystemDashboardWidget.swift:188`
  - Medium 消费点：`SystemDashboardWidget.swift:238`（MediumStatusStrip）
  - Large 消费点：`SystemDashboardWidget.swift:262`（StatTile）
- **语义冲突描述**: 
  - 同一台无电池的桌面 Mac，Small widget 显示"Adapter"，Medium widget 显示"Power Adapter"，Large widget 显示"Power Adapter"。
  - Small 用缩写集合（"Charging"/"Adapter"/"Battery"/"UPS"/"External"），Medium/Large 用全称集合（"Power Adapter · Charging"/"Power Adapter"/"Battery Power"/"UPS Power"/原值）。
  - "External" vs 原值透传：Small 把未识别来源统一显示为"External"，Medium/Large 显示原值（如"Wireless Power"）。
- **用户影响**: 
  - 用户同时放 Small 和 Medium widget 在桌面，看到"Adapter"和"Power Adapter"指代同一事实，可能以为是两个不同概念。
  - 缩写与全称的差异属于"有意区分"（Small 空间小），但"External" vs 原值透传是**真矛盾**——同状态两套不同输出。
- **建议**: 
  - 让 Small 的"External"对齐 Medium/Large 的原值透传，或让 Medium/Large 也归类为"External"。统一未识别来源的展示策略。
  - 缩写差异可保留，但应建立显式映射表（compact ↔ full）。
- **优先级**: L-低

---

## 三、阈值/窗口矛盾

### 矛盾 L4-W1: widget freshness 窗口与刷新间隔、stale 阈值的关系自相矛盾
- **涉及阈值**: 
  - `nextRefresh = 300s`（SystemDashboardWidget.swift:58）
  - `sharedSnapshotMaxAge = 600s`（SystemDashboardWidget.swift:41）
  - `WidgetFreshnessTone.aging = 300s`（WidgetVisualTokens.swift:11）
  - `WidgetFreshnessTone.stale = 600s`（WidgetVisualTokens.swift:10）
- **矛盾**: `nextRefresh(300) == aging(300) < maxAge(600) == stale(600)`
  - 正常按时刷新 → 数据 age 接近 300s → 显示 aging（琥珀），**正常状态被标记为老化**。
  - 数据寿命 maxAge = stale 阈值 → 最长允许的数据恰好是"stale"——widget 显示 stale 红点但**仍然展示该数据**而非 fallback。
- **应满足的关系**: `nextRefresh < aging < maxAge ≤ stale`（或 `nextRefresh ≤ aging < maxAge < stale`），当前 `nextRefresh == aging` 与 `maxAge == stale` 两处等号导致语义模糊。
- **优先级**: L-中（与 L4-3 同根因）

### 矛盾 L4-W2: powerStatusTone 阈值 0.5 在充电/非充电下语义不一致
- **涉及阈值**: 
  - `batteryPercent < 0.2 → .critical`（MetricSnapshot.swift:1290）
  - `batteryPercent < 0.5 → .warning`（MetricSnapshot.swift:1294）
  - `batteryIsCharging → .normal`（MetricSnapshot.swift:1298，仅在 ≥0.5 时执行）
- **矛盾**: 
  - 阈值 0.5 在充电中是"normal/warning 分界"，在非充电中也是"normal/warning 分界"，但**充电中本不该 warning**（电量在恢复）。
  - 阈值 0.2 同理：充电中 19% 显示 critical，与非充电中 19% 显示 critical 语义不同（前者在恢复，后者在恶化）。
- **应满足的关系**: 充电状态下，阈值应放松（如充电中 < 0.1 → critical，< 0.3 → warning）；或引入 trend 维度替代纯阈值。
- **优先级**: L-中（与 L4-2 同根因）

### 矛盾 L4-W3: Sparkline suffix(80) 与 historyDepth 90/180/360 不对齐
- **涉及窗口**: 
  - `Sparkline.preparedValues` `suffix(80)`（DashboardView.swift:1564）
  - `HistoryDepthOption.compact=90`（MetricsStore.swift:24）
  - `HistoryDepthOption.standard=180`（MetricsStore.swift:25）
  - `HistoryDepthOption.extended=360`（MetricsStore.swift:26）
  - `reportedHistorySampleChipText` 报告 `history.count`（最多 360）
- **矛盾**: 即使 historyDepth 选 90（最小档），sparkline 也只画 80 个点——**90 与 80 几乎无差**。选 360 时 chip 报"Recent 360"但曲线只有 80 个点。
- **应满足的关系**: `sparklineWindowSize ≤ historyDepth.compact` 且 chip 文案 = sparkline 实际点数。当前 `80 < 90` 满足前者但 chip 文案 != sparkline 点数。
- **优先级**: L-中（与 L4-4 同根因）

### 矛盾 L4-W4: ThresholdControlRow slider 范围 0.5...0.98 与 normalizedThreshold 0.5...0.98 一致，但 default 0.9 与 0.98 上限的关系未解释
- **涉及阈值**: 
  - `MetricsStore.swift:81-83` — `cpuAlertThreshold` default 0.9, `memoryAlertThreshold` default 0.85, `diskAlertThreshold` default 0.9
  - `MetricsStore.swift:201-203` — `normalizedThreshold` clamp to [0.5, 0.98]
  - `DashboardView.swift:2014` — `Slider(in: 0.5...0.98, step: 0.01)`
- **矛盾**: 无直接矛盾，但 0.98 上限意味用户无法设到 0.99/1.0（"仅当 100% 满时告警"不可达）。default 0.9 与 upper bound 0.98 之间只有 8% 余量——用户调到上限时告警几乎不触发。语义上"阈值"应允许接近 1.0。
- **优先级**: L-低

### 矛盾 L4-W5: widgetReloadInterval=60s 与 nextRefresh=300s 不一致，widget timeline 与 app 触发频率脱节
- **涉及窗口**: 
  - `MetricsStore.swift:67` — `widgetReloadInterval = 60`
  - `SystemDashboardWidget.swift:58` — `nextRefresh = 300`
- **矛盾**: app 每 60s 调用 `WidgetCenter.shared.reloadTimelines`（MetricsStore.swift:432-443），但 widget timeline 策略是 `.after(nextRefresh=300s)`。即 app 主动 reload 5 次，widget 才到自然刷新点。reload 会**重置** timeline 还是仅触发一次 entry 计算？WidgetKit 行为是 reload 触发 `getTimeline` 重新计算——所以实际 widget 每 60s 拿到新 entry，但 nextRefresh 策略是 300s。两者矛盾：要么 app 不该这么频繁 reload（浪费），要么 nextRefresh 该是 60s。
- **优先级**: L-低（功能性无大碍，但语义混乱）

---

## 四、与 REVIEW-PLAN.md 重叠项

| 本报告 ID | REVIEW-PLAN.md / LOGIC-CONSISTENCY-REVIEW-PLAN.md 项 | 重叠描述 | 处置 |
|---|---|---|---|
| L4-1 | [ANCHOR-C3] powerStatusText 优先级歧义（LOGIC-CONSISTENCY-REVIEW-PLAN.md:93-95） | 同一标题 powerStatusTitle 下有电池时展示电量、无电池时展示电源来源 | 本报告扩展为"三维度同时切换"（标题/文本/进度/色调），并新增 PopoverSmallStat 与 RingGauge 空环误读分析 |
| L4-2 | LOGIC-CONSISTENCY-REVIEW-PLAN.md:199 powerStatusTone 低电量充电语义 | 计划描述"batteryIsCharging → normal 覆盖低电量"——**与代码相反** | 本报告纠正前提：实际是低电量早返回覆盖 charging；保留语义冲突发现但反转方向 |
| L4-3 | [ANCHOR-C1] freshness 600s > 刷新 300s（LOGIC-CONSISTENCY-REVIEW-PLAN.md:84-87; REVIEW-PLAN.md:128, 201 P2-9） | freshness 窗口 > 刷新间隔 | 本报告扩展为"nextRefresh==aging 且 maxAge==stale"双重等号矛盾，并指出 staleData 文案仅作 accessibility 消费 |
| L4-4 | LOGIC-CONSISTENCY-REVIEW-PLAN.md:201 Sparkline suffix(80) vs 360 | 展示窗口与历史窗口不对齐 | 本报告新增 chip 文案"Recent 360"与实际 80 点的矛盾 |
| L4-5 | LOGIC-CONSISTENCY-REVIEW-PLAN.md:200 networkPathProgress 非 Optional | 未识别状态渲染空进度条 | 本报告纠正：当前所有调用点都包 reportedProgress，无用户可见 bug；降级为防御性设计薄弱 |
| L4-6 | REVIEW-PLAN.md:81 MetricScales.tenGigabitBytesPerSecond 硬上限 | 25/40/100 GbE 钳制 | 本报告扩展"满格"语义误导分析，区分消费级 vs 专业级影响 |
| L4-7 | (新发现) | powerSourceText "No Battery" 分支不可达 | 无重叠，新发现 |
| L4-8 | REVIEW-PLAN.md P2-6 (5m 矛盾) | widget 刷新三处话术 | 本报告聚焦"5m"硬编码 vs "System Scheduled" 同屏冲突，扩展硬编码绕过 localized 路径 |
| L4-9 | LOGIC-CONSISTENCY-REVIEW-PLAN.md:202 processes 四标题语义重叠 | Apps 页标题语义重叠 | 本报告扩展"List Items" 是 UI 元数据而非系统指标的分析，新增 CPU/Memory/Processes 三页 subtitle 不一致 |
| L4-10 | REVIEW-PLAN.md P1-10 (placeholder 返回 nil → 骨架) | placeholder vs getSnapshot vs getTimeline | REVIEW-PLAN 关注 placeholder=nil 导致骨架；本报告关注 placeholder/getSnapshot 返回 fixture 数据但 UI 不标识 |
| L4-11 | REVIEW-PLAN.md:96 refreshGeneration 过期任务失效机制 | 失效机制正确性 | 本报告新增"丢弃采样导致 history 不可见缺口"分析 |
| L4-12 | (新发现) | popover 几何在小屏裁切 | 无重叠，新发现 |
| L4-13 | LOGIC-CONSISTENCY-REVIEW-PLAN.md A1 缩写 vs 全称有意区分 | Small compactPowerStatusText vs Medium/Large powerStatusText | 本报告区分"缩写差异（有意）" vs "External vs 原值透传（真矛盾）" |

---

## 五、汇总

共发现 **13 条**设计语义合理性问题：

| ID | 名称 | 优先级 |
|---|---|---|
| L4-1 | powerStatus 卡片三维度语义随电池存在性同时切换 | L-中 |
| L4-2 | powerStatusTone 低电量充电显示 critical/warning | L-中 |
| L4-3 | widget freshness 窗口=stale 阈值，正常刷新被标老化 | L-中 |
| L4-4 | Sparkline 展示窗口 80 与历史窗口 360 及 chip 文案不对齐 | L-中 |
| L4-5 | networkPathProgress 非 Optional，"未报告"与"离线"内部不可区分 | L-低 |
| L4-6 | MetricScales 10GbE 硬上限使 25/100 GbE 满格语义误导 | L-低 |
| L4-7 | powerSourceText "No Battery" 分支不可达 + 设计意图漂移 | L-低 + L-中 |
| L4-8 | 设置页"5m"硬编码与"System Scheduled"同屏语义冲突 | L-中 |
| L4-9 | Processes 页四标题语义重叠，"List Items" 是 UI 元数据 | L-中 |
| L4-10 | placeholder/getSnapshot/getTimeline 数据真实性层级未在 UI 体现 | L-低 |
| L4-11 | refreshGeneration 失效导致 history 不可见采样缺口 | L-低 |
| L4-12 | MenuBarPopoverGeometry minimumHeight 在小屏可能裁切 | L-低 |
| L4-13 | Small vs Medium/Large widget powerStatusText 同状态文案不一致 | L-低 |

**L-中 6 条** / **L-低 7 条**（L4-7 兼有 L-低 与 L-中 维度）。

**关键纠正**：
1. 审查计划 [ANCHOR] 描述的"batteryIsCharging → normal 覆盖低电量"前提与代码相反——实际是低电量阈值早返回覆盖 `batteryIsCharging` 检查。L4-2 据此反转方向。
2. 审查计划描述"networkPathProgress 未识别状态渲染空进度条"在当前调用点不成立——所有调用都包 `reportedProgress`。L4-5 降级为防御性设计薄弱。
3. `staleData` 文案（PulseDockWidgetStrings.swift:108）**被消费**于 `WidgetFreshnessTone.accessibilityText`（WidgetVisualTokens.swift:30-31），不是完全未消费；但仅作 accessibility，视觉上只有圆点变色。L4-3 据此修正"无 staleness 指示"为"无视觉文案指示"。

**新发现（不在 REVIEW-PLAN.md / LOGIC-CONSISTENCY-REVIEW-PLAN.md 中）**：
- L4-7：`powerSourceNoBattery` "No Battery" 分支不可达（dead code）+ 设计意图与实现漂移
- L4-12：MenuBarPopoverGeometry 在小屏可能裁切内容
- L4-13：Small widget "External" vs Medium/Large 原值透传，同状态两套输出
