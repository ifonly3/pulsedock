# Pulse Dock 逻辑与数据一致性审查 — 中层整合报告

> 审查日期：2026-06-28
> 子 agent 数：5（L1 话术矛盾 / L2 字符串契约 / L3 数据流 / L4 设计语义 / L5 文档漂移）
> 原始发现：51 条（L1:13 + L2:6 + L3:16 + L4:13 + L5:3）
> 去重合并后：45 条有效发现
> 前序资产：`docs/review/REVIEW-PLAN.md`、`docs/review/top/final-review-v2.md`

---

## 一、去重与合并

### 1.1 跨报告重复项合并（6 组）

| 合并组 | 原始 ID | 合并后 ID | 合理说明 |
|--------|---------|-----------|---------|
| Widget 刷新话术 | L1-1 + L4-8 | LC-1 | L1 从话术矛盾角度、L4 从设计语义角度描述同一"5m vs System Scheduled"同屏冲突 |
| Power status 语义 | L1-2 + L4-1 | LC-2 | L1 从"No Battery vs Reported"话术角度、L4 从"三维度同时切换"设计角度描述同一 powerStatus 卡片族 |
| Freshness 窗口矛盾 | L4-3 + L4-W1 | LC-3 | L4 发现与 L4 阈值矛盾表同一根因 |
| Sparkline 窗口矛盾 | L4-4 + L4-W3 | LC-4 | 同上 |
| powerStatusTone 充电矛盾 | L4-2 + L4-W2 | LC-5 | 同上 |
| Thermal 死分支 | L2-1 + L2-2 | LC-6 | "fair"/"serious" 两个死值同属 thermalState 字段，7 处匹配点 |

### 1.2 去重后有效发现：45 条

| 优先级 | 数量 | 来源分布 |
|--------|------|---------|
| L-中 | 14 | L1:4 + L3:4 + L4:6 |
| L-低 | 31 | L1:9 + L2:6 + L3:12 + L4:7 + L5:3 |
| L-高 | 0 | — |

**关键结论**：无 L-高问题。所有发现均为"用户可感知的语义困惑"或"维护期静默失败风险"，不涉及崩溃或数据错误。

---

## 二、跨模块系统性问题（5 组）

### 系统性问题 1：Widget 刷新周期话术-设计-窗口三重矛盾

**影响报告**：L1 / L4
**合并发现**：LC-1（话术）+ LC-3（窗口）+ L4-W5（频率脱节）

**完整链路**：
```
话术层（LC-1）：
  DashboardView.swift:1167 "5m"（硬编码，暗示确定性）
  vs PulseDockAppStrings.swift:1019 "Scheduled by the system timeline"
  vs PulseDockAppStrings.swift:1055 "System Scheduled"
  → 同屏两面板对同一事实给出冲突语义

设计层（LC-3）：
  SystemDashboardWidget.swift:58 nextRefresh=300s（请求值，非保证）
  vs WidgetVisualTokens.swift:11 aging阈值=300s
  vs SystemDashboardWidget.swift:41 sharedSnapshotMaxAge=600s
  vs WidgetVisualTokens.swift:10 stale阈值=600s
  → nextRefresh==aging 且 maxAge==stale：
    正常刷新即被标"老化"，最长允许数据恰好显示红色但不 fallback

频率层（L4-W5）：
  MetricsStore.swift:67 widgetReloadInterval=60s（app 主动 reload）
  vs SystemDashboardWidget.swift:58 nextRefresh=300s（widget timeline 策略）
  → app 每 60s reload 5 次，widget 才到自然刷新点，频率脱节
```

**后果**：
- 用户在设置页看到"5m"与"System Scheduled"并存，疑惑"到底多久刷新"
- 系统按时刷新（300s）后 widget 显示琥珀"aging"圆点，正常运作被标记为老化
- "5m"是请求值非保证值，系统可延后到 10 分钟（与 maxAge=600s 吻合），"5m"构成失实承诺
- `staleData` 文案仅作 accessibility 消费，明眼用户只看到 6px 圆点变色

**修复方向**：
1. 话术统一：删除"5m"硬编码，统一为"System Scheduled"或"≈ 5m（system scheduled）"
2. 窗口调整：`sharedSnapshotMaxAge` 应 < `staleThreshold`（如 300s），让 stale 触发 fallback
3. 频率对齐：`widgetReloadInterval` 与 `nextRefresh` 统一为相同量级

### 系统性问题 2：Power status 语义-设计-dead code 三重缺陷

**影响报告**：L1 / L4
**合并发现**：LC-2（话术）+ L4-2（色调）+ L4-7（dead code）+ L4-13（跨尺寸文案）+ L1-12（冗余展示）

**完整链路**：
```
话术层（LC-2 / L1-2）：
  MetricSnapshot.swift:1274 "No Battery"（powerSourceText）
  vs MetricSnapshot.swift:1282 hasPowerStatusReport=true（"Reported"）
  → 用户看到"No Battery"却看到数据源标记"已报告"

设计层（L4-1）：
  powerStatusTitle: "Battery" ↔ "Power"（随 batteryPercent 有无切换）
  powerStatusText: 百分比 ↔ 电源来源（量化 ↔ 定性）
  powerStatusProgress: 数值 ↔ nil（空环）
  → 同一卡片三维度同时切换，桌面 Mac 空环误读为 0% 电量

色调层（L4-2）：
  MetricSnapshot.swift:1290-1294 低电量(<0.5)早返回覆盖 charging
  → 19% 充电中显示 critical(红)，35% 充电中显示 warning(琥珀)
  → 红色通常意味"需行动"但用户已行动（插电）

Dead code 层（L4-7）：
  MetricSnapshot.swift:1273-1274 "No Battery" 分支不可达
  → case .some(non-empty) 捕获所有未识别来源并原值透传
  → "No Battery" 本地化字符串永远不展示，设计意图与实现漂移

跨尺寸文案层（L4-13）：
  Small widget: compactPowerStatusText → "Adapter"/"External"
  Medium/Large: powerStatusText → "Power Adapter"/原值透传
  → 同状态两套输出，"External" vs 原值是真矛盾

冗余展示层（L1-12）：
  桌面 Mac Power 页三处相邻："Power = Power Adapter" 重复三次
```

**后果**：
- 桌面 Mac 用户看到空环 + "Power Adapter" 误读为 0% 电量
- 低电量充电用户看到红色 critical，疑惑"充电是否生效"
- "No Battery" 本地化翻译做了但永不展示（维护成本浪费）
- 同一桌面 Mac 的 Small/Medium widget 显示不同电源文案

**修复方向**：
1. 拆分 `powerStatusTitle` 为 `batteryLevelTitle`（量化）与 `powerSourceTitle`（定性）
2. 让 `batteryIsCharging` 在低电量区也参与色调判定
3. 删除 `case .some(non-empty)` 透传分支，让未识别来源统一显示"No Battery"
4. 统一 Small/Medium/Large 的未识别来源展示策略

### 系统性问题 3：字符串契约死分支（30 个实例）

**影响报告**：L2
**合并发现**：LC-6（thermal）+ L2-3/L2-4（network）

**完整链路**：
```
thermalState:
  SystemSampler.swift:598-611 输出 Nominal/Warm/Hot/Critical/Unknown（Title-case）
  .fair → "Warm"（重命名），.serious → "Hot"（重命名）
  下游 7 处匹配含 "fair"/"serious" 死分支 → 14 个死分支实例

networkPathStatus:
  SystemSampler.swift:198-199 只输出 "requiresConnection"（camelCase）
  下游 8 处匹配含 "requires_connection"/"requires connection" 死变体 → 16 个死分支实例
```

**后果**：
- 死分支与活跃分支共享同一返回值，不影响运行时行为
- 但 30 个死分支实例增加维护负担，阅读者可能以为 sampler 会输出这些值
- 任一方改字符串大小写/拼写，其他多处静默落入 default，无编译错误

**修复方向**：在 SharedMetrics 暴露 `enum ThermalState: String` 与 `enum NetworkPathStatus: String`，sampler/MetricSnapshot/UI 全部引用同一枚举，实现编译期穷尽性检查。删除所有死分支，或移到 decoder 层做归一化。

### 系统性问题 4：裁剪契约脆弱 + init/Codable 策略不对称

**影响报告**：L3
**合并发现**：L3-1~L3-3（裁剪）+ L3-4~L3-8（策略不对称）+ L3-14（两套裁剪路径）

**完整链路**：
```
裁剪契约（L3-1~L3-3）：
  widgetCompactSnapshot() 手工列举 ~40 字段，~11 字段依赖 init 默认值静默置零/nil
  sampleWidgetCompact(fallback) 保留 memory composition + battery details
  widgetCompactSnapshot(shared store) 裁剪这些字段
  → 两条路径字段集不对称，当前 widget 不读取差异字段，功能正确但脆弱

两套裁剪路径（L3-14）：
  widgetCompactSnapshot（widget 裁剪）vs sanitizedHistorySnapshot（history 裁剪）
  → 字段集不同（widget 保留 osVersion/kernel，history 裁剪；widget 裁剪 memory composition，history 保留）
  → 新增字段时需同时更新两处，遗漏任一处导致数据静默丢失

init/Codable 策略不对称（L3-4~L3-8）：
  hasCPUUsageReport: init=直接赋值 vs Codable=OR 派生
  hasMemoryCompositionReport: init=直接 vs Codable=AND key 存在性
  hasNetworkPathCostReport: init=直接 vs Codable=AND
  hasNetworkPathSupportReport: init=直接 vs Codable=AND
  hasNetworkDirectionByteCounters: init=OR vs Codable=AND+OR 混合（有可触发 edge case）
```

**后果**：
- 当前无用户可见影响（widget 不读取被裁字段，JSONEncoder 总编码 Bool 字段）
- 但 `hasNetworkDirectionByteCounters` 有可触发 edge case：JSON 含两 key 但值均为 0 时 init/Codable 派生结果分歧
- 新增字段时裁剪/策略遗漏导致静默数据丢失

**修复方向**：
1. 提取统一裁剪策略枚举（`SnapshotTrimmingPolicy.forWidget`/`.forHistory`）
2. 统一 init/Codable 为 OR 策略，与 init 其他 hasXxxReport 派生一致
3. 引入独立 `WidgetCompactSnapshot` 类型获得编译期保证

### 系统性问题 5：同表异题/同概念异名的话术漂移

**影响报告**：L1
**合并发现**：L1-3（System Status 三义）+ L1-4（Sensors/History 同表异题）+ L1-5（GPU 标题漂移）+ L1-7（Heat vs Thermal）+ L1-8（Network Connection vs Connection）+ L1-9（Not reported 双术语）

**完整链路**：
```
同字面三义（L1-3）：
  "System Status" 在 Overview=全系统汇总 / Sensors 热面板=热性能限制 / widget Large=整体标题

同表异题（L1-4）：
  Sensors 页 "Status Rules" + "Warning" vs History 页 "Status Evaluation" + "Triggered"
  两表行数据完全相同，但标题/subtitle 单复数/状态词全不同

单复数/连词漂移（L1-5）：
  "GPU / Display"（单数）vs "GPU / Displays"（复数）vs "GPU & Unified Memory"（& 连词）

缩写漂移（L1-7）：
  widget small "Heat" vs widget large/app "Thermal"（"Heat" 不是 "Thermal" 的标准缩写）

全称/简称漂移（L1-8）：
  app "Network Connection" vs widget "Connection" vs 网络页 "Connection Status"

双术语（L1-9）：
  "Not reported" vs "System did not report" 在同一进程表行内按字段切换
```

**后果**：
- 用户跨页看到同一指标用不同标题/状态词，怀疑评估逻辑不同
- 同屏看到"5m"与"System Scheduled"，疑惑"到底是 5 分钟还是系统决定"

**修复方向**：建立概念词典，统一每个概念的跨模块文案变体；同表统一标题与状态词。

---

## 三、话术概念矩阵

| 概念 | app 变体 | widget 变体 | shared 变体 | 一致性 |
|------|----------|-------------|-------------|--------|
| Widget 刷新 | "5m" / "Scheduled by the system timeline" / "System Scheduled" | nextRefresh=5min（请求） | — | ❌ LC-1 |
| Power/Battery | "Power" / "Power & Battery" / "No Battery" | "Power" / "Adapter" / "External" | powerSourceAdapter / powerSourceNoBattery | ❌ LC-2 |
| System Status | "System Status"（Overview 面板 / Sensors 热行） | "System Status"（Large 头部） | — | ❌ L1-3 |
| 状态规则 | "Status Rules" + "Warning"（Sensors） | — | — | ❌ L1-4（vs History "Status Evaluation" + "Triggered"） |
| GPU/Displays | "GPU / Display" / "GPU / Displays" / "GPU & Unified Memory" / "GPU" / "Displays" | — | — | ❌ L1-5 |
| Thermal | "Thermal" | "Thermal" / "Heat" | thermalStateNominal 等 | ⚠️ L1-7（"Heat" 漂移） |
| Network Connection | "Network Connection" / "Connection Status" | "Connection" | networkPathStatusOnline 等 | ⚠️ L1-8 |
| Not reported | "Not reported" / "System did not report" | "Not reported" | "Not reported" / "System did not report" | ⚠️ L1-9 |
| Bundle name | "Pulse Dock"（AppInfo） | "Pulse Dock"（gallery）/ "Pulse Dock Widget"（WidgetInfo） | — | ⚠️ L1-10 |
| CPU | "CPU" | "CPU" | — | ✅ |
| Memory | "Memory" | "Memory" / "MEM" | — | ✅（MEM 有意缩写） |
| Disk | "Disk" | "Disk" | — | ✅ |
| Load | "Load" | "Load" | — | ✅ |
| Uptime | "Uptime" | "Uptime" | — | ✅ |
| Widget Sizes | "Small / Medium / Large" | [.systemSmall, .systemMedium, .systemLarge] | — | ✅ |
| Pause/Resume | "Resume"/"Pause" + "Paused"/"Live" | — | — | ✅ |

---

## 四、数据字段端到端矩阵（关键字段摘要）

| 字段 | sampler 量纲 | init 策略 | Codable 策略 | store 持久化 | widgetCompact 裁剪 | widget 读取 | 一致性 |
|------|-------------|-----------|-------------|-------------|-------------------|------------|--------|
| cpuUsage | 0-1 | 必填 | `?? placeholder` | JSON | 保留 | ✅ | ✅ |
| batteryPercent | 0-1 | nil | `?? nil` | JSON | 保留 | ✅ | ✅ |
| cpuUsage 量纲 | 0-1 | — | — | — | — | 0-1→×100 | ✅ |
| networkBytesPerSecond | bytes/s | 0 | `?? 0` | JSON | 保留 | 不读取 | ⚠️ L3-15（冗余） |
| networkText 展示 | bits/s | — | — | — | — | — | ❌ L3-9（vs networkInText/OutText bytes/s） |
| hasCPUUsageReport | direct | 直接赋值 | OR 派生 | JSON | 保留 | ✅ | ⚠️ L3-4（策略不对称） |
| hasMemoryCompositionReport | direct | 直接赋值 | AND key 派生 | JSON | 裁剪→false | 不读取 | ⚠️ L3-5（策略不对称 + 裁剪） |
| hasNetworkDirectionByteCounters | OR 派生 | OR 派生 | AND+OR 混合 | JSON | 保留 | 间接 | ❌ L3-8（可触发 edge case） |
| memoryFree/Wired/Compressed/Cached | bytes | 0 | `?? 0` | JSON | 裁剪→0 | 不读取 | ⚠️ L3-1（裁剪脆弱） |
| batteryCycleCount/Health/Design/Voltage/Amperage | 各自单位 | nil | `?? nil` | JSON | 裁剪→nil | 不读取 | ⚠️ L3-2（裁剪脆弱） |
| schemaVersion | Int(=1) | currentSchemaVersion | `?? currentSchemaVersion` | JSON | 保留 | 不校验 | ⚠️ L3-11（存在但未用） |
| runningApps | [ProcessMetric] | [] | key="topProcesses" | JSON | 裁剪→[] | 不读取 | ⚠️ L3-16（key 语义不一致） |
| thermalState | 字符串枚举 | 必填 | `?? "Unknown"` | JSON | 保留 | ✅ | ✅（量纲一致，死分支见 LC-6） |
| timestamp | Date | 必填 | `?? Date(1970)` | JSON | 保留 | snapshotAge 计算 | ✅（秒一致） |

---

## 五、文档-代码一致性核对摘要

| 维度 | 核对声明数 | 一致 | 漂移 |
|------|----------|------|------|
| data-capability-audit.md 否定声明 | 15+ | 15+ | 0 |
| "first...then fallback" 顺序 | 11 | 11 | 0 |
| "centralized on" 位置 | 20 | 20 | 0 |
| "legacy...remain not-reported" | 15 | 15 | 0 |
| Surfaces 列覆盖 | 14 | 12 | 2（D1 GPU/display 含 widgets / D2 Storage 缺 widgets） |
| 措辞精度 | ~40 | ~39 | 1（D3 "after shared writes" 暗示因果） |
| README 隐私声明 | 5 | 5 | 0 |
| PrivacyInfo.xcprivacy | 7 | 7 | 0 |
| entitlements | 6 | 6 | 0 |
| **合计** | **~120** | **~117** | **3** |

**C2 锚点确认**：`data-capability-audit.md:183` display 元数据主线程快照声明 — **已修复**，`SystemSampler.swift:1101-1113` 通过 `DispatchQueue.main.sync` 桥接 detached 采样，文档与代码一致。

---

## 六、与前次审查（REVIEW-PLAN.md / final-review-v2.md）的对齐

| 本次发现 | 前次审查对应项 | 关系 |
|---------|--------------|------|
| LC-1（Widget 刷新话术） | P2-6（"5m" vs "System Scheduled" 矛盾） | 升级：从整洁级升级为话术矛盾 L-中，补充同屏对照与 nextRefresh 请求值事实 |
| LC-6（thermal 死分支） | P2-3（字符串字面量匹配 sampler 输出） | 扩展：补充 MetricSnapshot.swift 6 处下游匹配点（前次仅列 UI 层 3 文件） |
| L2-3/L2-4（network 死分支） | P2-3 | 扩展：8 处下游匹配点含 requires_connection/requires connection 死变体 |
| L3-4~L3-8（init/Codable 策略不对称） | P2-14（decoder/init 推断策略不一致） | 扩展：发现 5 个不对称字段，其中 hasNetworkDirectionByteCounters 有可触发 edge case |
| L3-1~L3-3（裁剪契约脆弱） | P2-11（widgetCompactSnapshot 裁剪靠手工列举） | 验证确认：当前功能正确但脆弱，补充两条路径字段集不对称 |
| L3-10（MetricScales 硬上限） | P3（MetricScales 10GbE 硬上限） | 验证确认：仅 app 侧受影响，widget 不调用 networkRateProgress |
| L3-13（C locale 混用） | P3（MetricFormatting C locale vs Locale.current） | 验证确认：影响范围限定为浮点数格式化 |
| L3-12（save 失败静默） | P2-8（`_ =` 丢弃返回值） | 扩展：补充 lastSharedSnapshotWriteDate 无论成败都更新导致 60s 内不重试 |
| L3-11（schemaVersion 未校验） | P2-11（无 schema 版本字段） | 纠正：字段存在(=1)但 store 不校验，前次"无字段"描述不准确 |
| LC-3（freshness 窗口） | P2-9（freshness 600s > 刷新 300s） | 升级：扩展为"nextRefresh==aging 且 maxAge==stale"双重等号矛盾 |
| L4-10（placeholder fixture） | P1-10（placeholder 返回 nil → 骨架） | 纠正：当前 placeholder 返回 representativeSnapshot（fixture），非 nil；问题改为"fixture 未标识" |
| LC-2 / L4-1 / L4-2 / L4-7 | 无（新发现） | powerStatus 语义链全为新发现 |
| L1-3 / L1-4 / L1-5~L1-13 | 无（新发现） | 话术矛盾专项全为新发现 |
| L3-9 / L3-14 / L3-15 / L3-16 | 无（新发现） | 数据流专项新发现 |
| L4-9 / L4-11 / L4-12 / L4-13 | 无（新发现） | 设计语义专项新发现 |
| D1 / D2 / D3 | 无（新发现） | 文档 Surfaces 列漂移全为新发现 |

**前次 review 已修复项确认**：
- P0-1（NSScreen 主线程守卫）：已修复，`DispatchQueue.main.sync` 桥接
- P1-2（无系统事件观察）：已修复，`AppDelegate.swift:90-103` 注册 didWake/didChangeScreenParameters
- P0-2（widget fallback 完整采样）：部分修复，`sampleWidgetCompact` 跳过 GPU/display/volumes，但仍在 widget 线程同步采样

---

## 七、子报告索引

5 份子 agent 报告已落盘：
- `docs/review/subagents/L1-copy-consistency.md`（13 条话术矛盾）
- `docs/review/subagents/L2-data-contract.md`（6 条字符串契约问题）
- `docs/review/subagents/L3-data-flow.md`（16 条数据流不一致）
- `docs/review/subagents/L4-design-semantics.md`（13 条设计语义问题）
- `docs/review/subagents/L5-doc-code-drift.md`（3 条文档-代码漂移）

本报告与 `docs/review/top/logic-consistency-final.md` 共同构成完整审查交付物。
