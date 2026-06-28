# Pulse Dock 逻辑与数据一致性审查 — 顶层复核最终报告

> 审查日期：2026-06-28
> 审查方法：三层并行 review（5 子 agent 逐句 → 中层整合 → 顶层复核）
> 审查基准：当前 working tree（HEAD `9db73ee`）
> 前序 review：`docs/review/top/final-review-v2.md`（2026-06-27，Bug 与设计缺陷专项）
> 关联计划：`docs/review/LOGIC-CONSISTENCY-REVIEW-PLAN.md`、`docs/review/middle/logic-consistency-integrated.md`

---

## 一、审查概要

| 维度 | 数值 |
|------|------|
| 子 agent 数 | 5（L1 话术 / L2 字符串契约 / L3 数据流 / L4 设计语义 / L5 文档漂移） |
| 审查文件 | 22 源文件 + 文档 551 行 + plist/entitlements/PrivacyInfo |
| 原始发现 | 51 条 |
| 去重后有效发现 | 51 条（L-中:14 / L-低:37 / L-高:0） |
| 跨模块系统性问题 | 5 组 |
| 新发现（不在前次 review 内） | 32 条 |
| 前次 review 已修复确认 | 3 条（P0-1 / P1-2 / P0-2 部分） |

---

## 二、顶层复核修正

### 2.1 审查计划锚点纠正（2 条）

| 锚点 | 计划描述 | 实际代码 | 处置 |
|------|---------|---------|------|
| [ANCHOR-C3] powerStatusTone | "batteryIsCharging → normal 覆盖低电量" | **与代码相反**：`MetricSnapshot.swift:1290-1296` 低电量阈值(<0.2/<0.5)早返回覆盖 `batteryIsCharging` 检查(:1298) | 纠正方向，保留语义冲突发现（LC-5） |
| [ANCHOR] networkPathProgress | "未识别状态渲染空进度条" | 当前所有调用点都包 `reportedProgress(hasReport:)`，未识别状态不渲染进度条 | 降级为防御性设计薄弱（L-低） |

### 2.2 真矛盾 vs 有意区分裁定

| 发现 | 裁定 | 理由 |
|------|------|------|
| LC-1 "5m" vs "System Scheduled" | **真矛盾** | "5m" 暗示确定性，实际是请求值；同屏两面板语义冲突 |
| LC-2 "No Battery" vs "Reported" | **部分误报（保留实现漂移）** | 正常桌面 Mac 路径显示 "Power Adapter"，不是 "No Battery"；真实问题是 `powerSourceNoBattery` 分支近乎不可达 |
| L1-3 "System Status" 三义 | **真矛盾** | 同字面量在 Overview/Sensors/widget 指代不同范围 |
| L1-4 Sensors/History 同表异题 | **真矛盾** | 同一规则表两页标题/状态词不同，数据源相同 |
| L1-7 "Heat" vs "Thermal" | **有意区分（但漂移）** | Small widget 空间约束需缩写，但"Heat"不是"Thermal"的标准缩写 |
| widget "MEM" vs "Memory" | **有意区分** | 标准缩写，不矛盾 |
| widget "CPU" vs app "CPU" | **有意区分** | 完全一致 |
| L4-13 Small "External" vs Large 原值透传 | **真矛盾** | 同状态两套不同输出，非缩写差异 |
| L1-10 "Pulse Dock Widget" vs "Pulse Dock" | **有意区分（但缺规范）** | gallery 名有意缩短，但两 UI 入口名称不同缺统一规范 |

### 2.3 Codex 复核校正（2026-06-28）

| 发现 | 复核结论 | 处置 |
|------|----------|------|
| LC-2 "No Battery" vs "Reported" | **LC-2 部分误报**：正常桌面 Mac 路径会显示 "Power Adapter"，不是 "No Battery"。真实问题是 `powerSourceNoBattery` 分支近乎不可达。 | 保留 Power 语义修复任务，但不按 "No Battery vs Reported" 用户可见 bug 执行。 |
| D1 GPU/display widgets | **D1 不属实**：当前 `docs/data-capability-audit.md` 的 GPU/display Surfaces 未包含 widgets。 | 标记为 false positive；不按 GPU/display widget 漂移修产品代码。 |
| L4-12 menu bar popover minimumHeight | **L4-12 已由几何压缩与滚动缓解**：当前 geometry 在可用高度不足时允许低于 `minimumHeight`，内容主体在 `ScrollView` 内。 | 降级为回归测试/文档提醒，不作为明确产品 bug。 |
| LC-6/L2-3/L2-4 legacy aliases | 属实但属于兼容分支。 | 通过 canonical enum 收敛重复 switch，保留旧值解析能力。 |

---

## 三、最终问题清单（按优先级）

### L-中 — 用户可感知的语义困惑或维护期静默失败风险（14 条）

#### 话术矛盾（4 条）

| # | 位置 | 问题 | 修复方向 | 工作量 |
|---|------|------|----------|--------|
| LC-1 | `DashboardView.swift:1167` vs `:1192` | Widget 刷新同屏冲突：左面板硬编码 "5m"（暗示确定性），右面板 "System Scheduled"，detail "Scheduled by the system timeline"。"5m" 是请求值非保证值 | 统一为 "System Scheduled" 或 "≈ 5m（system scheduled）"，走 localized 路径 | 0.1d |
| LC-2 | `MetricSnapshot.swift:1274,1282` | 无电池设备 "No Battery"（powerSourceText）vs 数据源状态 "Reported"（hasPowerStatusReport=true）。且 "No Battery" 分支实际不可达（L4-7） | 改为 "No Battery Installed" 或拆分 powerStatusTitle 为 batteryLevelTitle/powerSourceTitle | 0.3d |
| L1-3 | `PulseDockAppStrings.swift:133,842` + `PulseDockWidgetStrings.swift:73` | "System Status" 同字面三义：Overview 全系统汇总 / Sensors 热性能限制 / widget Large 整体标题 | Sensors 热面板改用 statusPerformanceLimitTitle（"Performance Limit"） | 0.1d |
| L1-4 | `DashboardView.swift:968` vs `:1070` | 同一规则表在 Sensors("Status Rules"+"Warning") 与 History("Status Evaluation"+"Triggered") 两页标题/subtitle 单复数/状态词全不同 | 统一标题与状态词 | 0.1d |

#### 设计语义（6 条）

| # | 位置 | 问题 | 修复方向 | 工作量 |
|---|------|------|----------|--------|
| LC-3 | `SystemDashboardWidget.swift:41,58` + `WidgetVisualTokens.swift:10,11` | widget freshness：nextRefresh(300s)==aging(300s)，maxAge(600s)==stale(600s)。正常刷新被标"老化"，最长允许数据恰好红色但不 fallback | `sharedSnapshotMaxAge` 应 < `staleThreshold`（如 300s） | 0.2d |
| LC-4 | `DashboardView.swift:1562` vs `:2171` | Sparkline 只画 suffix(80) 但 chip 报"Recent 360"。历史深度切换视觉无差别 | chip 文案反映实际绘制点数，或 sparkline 窗口跟随 historyDepth | 0.2d |
| LC-5 | `MetricSnapshot.swift:1290-1298` | powerStatusTone 低电量(<0.5)早返回覆盖 charging：19% 充电中显示 critical(红)，35% 充电中显示 warning(琥珀)。红色意味"需行动"但用户已插电 | 让 batteryIsCharging 在低电量区参与判定 | 0.2d |
| L4-1 | `MetricSnapshot.swift:1279-1327` | powerStatus 卡片三维度同时切换（标题/文本/进度/色调）。桌面 Mac 空环误读为 0% 电量 | 拆分 batteryLevelTitle/powerSourceTitle，空环显示占位图标 | 0.5d |
| L4-7 | `MetricSnapshot.swift:1269-1274` | powerSourceText "No Battery" 分支不可达：`case .some(non-empty)` 捕获所有未识别来源并原值透传。"No Battery" 本地化字符串永不展示 | 删除透传分支或显式判断已知集合 | 0.1d |
| L4-9 | `DashboardView.swift:922-925` | Processes 页"List Items"是 UI 元数据（截断后列表行数 max 8）而非系统指标，与"Running Apps"（系统总数 23）并列展示 | 删除或改名"Displayed Apps"，subtitle 标"showing first 8" | 0.2d |

#### 数据流（4 条）

| # | 位置 | 问题 | 修复方向 | 工作量 |
|---|------|------|----------|--------|
| L3-3 | `SystemSampler.swift:362-443` vs `MetricSnapshot+WidgetCompact.swift:4-60` | sampleWidgetCompact(fallback) 保留 memory composition + battery details，widgetCompactSnapshot(shared store) 裁剪——两条路径字段集不对称 | 统一两条路径裁剪策略 | 0.3d |
| L3-8 | `MetricSnapshot.swift:919-923` vs `:1736-1740` | hasNetworkDirectionByteCounters init=OR vs Codable=AND+OR 混合。JSON 含两 key 但值均为 0 时 init/Codable 派生结果分歧（edge case 可触发） | 统一为纯 OR 值派生 | 0.1d |
| L3-9 | `MetricSnapshot.swift:1330` vs `:1435,1439` | networkText 展示 bits/s（networkRate），networkInText/networkOutText 展示 bytes/s（byteRate）。同一指标族单位混用 | 统一为 bits/s 或 bytes/s | 0.2d |
| L3-12 | `MetricsStore.swift:375` | `_ =` 丢弃 saveLatestSnapshot 返回值，且 lastSharedSnapshotWriteDate 无论成败都更新，失败后 60s 内不重试 | 检查返回值，仅在成功时更新 lastSharedSnapshotWriteDate | 0.1d |

### L-低 — 维护风险或防御性设计薄弱（37 条）

#### 话术漂移（9 条）

| # | 位置 | 问题摘要 |
|---|------|---------|
| L1-5 | `PulseDockAppStrings.swift:13,615,1163` | GPU 标题单复数/连词三种写法漂移："GPU / Display" / "GPU / Displays" / "GPU & Unified Memory" |
| L1-6 | `PulseDockWidgetStrings.swift:9` | widgetDescription 仅列 5 项但 Large widget 实际展示 12 类 |
| L1-7 | `PulseDockWidgetStrings.swift:13` vs `:49` | widget small "Heat" vs large/app "Thermal"（非标准缩写） |
| L1-8 | `PulseDockAppStrings.swift:1103,378` | app "Network Connection" vs 网络页 "Connection Status"（语义重叠措辞不一） |
| L1-9 | `PulseDockAppStrings.swift:1083,1087` | "Not reported" vs "System did not report" 双术语在同一进程表行内按字段切换 |
| L1-10 | `Resources/WidgetInfo.plist:14` vs `PulseDockWidgetStrings.swift:5` | widget bundle "Pulse Dock Widget" vs gallery "Pulse Dock" |
| L1-11 | `PulseDockAppStrings.swift:850,858` | Sensors 页 "Latest sample" vs "Local results for the current sample" 同页同义异述 |
| L1-12 | `DashboardView.swift:780,815,822` | 桌面 Mac Power 页 "Power = Power Adapter" 重复三次 |
| L1-13 | `PulseDockAppStrings.swift:947` vs `README.md:61` | app 隐私摘要 3 项 vs README 5 项 |

#### 字符串契约（6 条）

| # | 位置 | 问题摘要 |
|---|------|---------|
| LC-6 | 7 处下游匹配 | thermalState "fair"/"serious" 死分支（14 个实例），sampler 从不输出 |
| L2-3 | 8 处下游匹配 | networkPathStatus "requires_connection" 死分支（8 个实例） |
| L2-4 | 8 处下游匹配 | networkPathStatus "requires connection" 死分支（8 个实例） |
| L2-5 | `MetricSnapshot.swift:1241,1249` | thermalState "unknown" 在 MetricSnapshot 3 处无显式 case，UI 4 处有显式 case（风格不一致） |
| L2-6 | 全 8 处匹配点 | networkPathStatus "unknown" 全 8 处无显式 case（风格统一但缺自文档化） |
| L2-7 | `SharedMetricStrings.swift:376-389` | isNotReportedText/isOtherText 靠中英文字面量穷举，存在进程/GPU/接口名碰撞风险 |

#### 数据流（12 条）

| # | 位置 | 问题摘要 |
|---|------|---------|
| L3-1 | `MetricSnapshot+WidgetCompact.swift:13-17` | widgetCompact 裁剪 memory composition 字段，依赖 init 默认值静默置零（当前功能正确但脆弱） |
| L3-2 | `MetricSnapshot+WidgetCompact.swift:23-28` | widgetCompact 裁剪 battery detail 字段（同上） |
| L3-4 | `MetricSnapshot.swift:884` vs `:1676` | hasCPUUsageReport init=直接 vs Codable=OR（策略不对称） |
| L3-5 | `MetricSnapshot.swift:898` vs `:1691` | hasMemoryCompositionReport init=直接 vs Codable=AND（策略不对称） |
| L3-6 | `MetricSnapshot.swift:933` vs `:1720` | hasNetworkPathCostReport init=直接 vs Codable=AND |
| L3-7 | `MetricSnapshot.swift:937` vs `:1728` | hasNetworkPathSupportReport init=直接 vs Codable=AND |
| L3-10 | `MetricScales.swift:4` | tenGigabitBytesPerSecond 硬上限使 25/100 GbE 满格语义误导（仅 app 侧） |
| L3-11 | `SharedSnapshotStore.swift:54-73` | schemaVersion 字段存在(=1)但 store 不校验 |
| L3-13 | `MetricFormatting.swift` 全文 | String(format:) C locale vs SharedMetricStrings.localizedFormat Locale.current 混用（影响浮点数格式化） |
| L3-14 | widgetCompact vs sanitizedHistory | 两套独立裁剪路径字段集不同，新增字段时需同时更新两处 |
| L3-15 | `MetricSnapshot+WidgetCompact.swift:29,41,42` | networkBytesPerSecond 保留但 widget 不读取（冗余数据传输） |
| L3-16 | `MetricSnapshot.swift:1661` | runningApps Codable key="topProcesses"（property name 与 JSON key 语义不一致） |

#### 设计语义（7 条）

| # | 位置 | 问题摘要 |
|---|------|---------|
| L4-5 | `SystemDashboardWidget.swift:697-708` | networkPathProgress 返回非 Optional Double，"未报告"与"离线"内部不可区分（当前调用点都包 reportedProgress，降级为防御性薄弱） |
| L4-6 | `MetricScales.swift:4` | 10GbE 硬上限使 25/100 GbE 满格语义误导 |
| L4-10 | `SystemDashboardWidget.swift:43-49` | placeholder/getSnapshot 返回 fixture 数据但 UI 不标识，gallery 预览看起来过于真实 |
| L4-11 | `MetricsStore.swift:321,337-344` | refreshGeneration 失效导致 history 不可见采样缺口，sparkline 线性插值掩盖缺口 |
| L4-12 | `WidgetPanelView.swift:6-11` | MenuBarPopoverGeometry minimumHeight=420 在小屏可能压缩内容 |
| L4-13 | `SystemDashboardWidget.swift:752` vs `MetricSnapshot.swift:1269` | Small widget "External" vs Medium/Large 原值透传，同状态两套输出 |
| L4-W5 | `MetricsStore.swift:67` vs `SystemDashboardWidget.swift:58` | widgetReloadInterval=60s vs nextRefresh=300s 频率脱节 |

#### 文档漂移（3 条）

| # | 位置 | 问题摘要 |
|---|------|---------|
| D1 | `docs/data-capability-audit.md:27` | 复核后不属实：当前 GPU/display Surfaces 未包含 widgets；保留为误报记录 |
| D2 | `docs/data-capability-audit.md:23` | Storage Surfaces 列遗漏 widgets，但 Medium/Large widget 显示 primary disk usage |
| D3 | `docs/data-capability-audit.md:131` | "after shared writes" 措辞暗示因果触发，实际 write/reload 独立 60s 节流 |

### 已复核误报

| # | 原报告项 | 复核结论 |
|---|---------|----------|
| D1 | GPU/display Surfaces 包含 widgets | 当前文档未包含 widgets，代码也未显示 GPU/display widget 数据。 |

---

## 四、修复优先级与工作量汇总

| 优先级 | 项数 | 总工作量估算 | 建议批次 |
|--------|------|-------------|---------|
| L-中 | 14 | ~2.5 人日 | 第一批：LC-1/L1-3/L1-4/L4-7（话术快速修复 0.4d）+ LC-3/LC-5/L3-8/L3-12（设计/数据修复 0.6d）+ LC-2/L4-1/L4-9/L3-3/L3-9/LC-4（较大重构 1.5d） |
| L-低 | 37 | ~3-4 人日 | 第二批：字符串契约清理（LC-6/L2-3/L2-4，提取枚举 0.5d）+ 话术统一（L1-5~L1-13，0.5d）+ 数据流对称化（L3-4~L3-7，0.3d）+ 文档修正（D1/D2/D3，0.1d）+ 其余择机处理 |
| **合计** | **51** | **~5.5-6.5 人日** | — |

---

## 五、跨模块系统性问题修复建议

### 系统性问题 1：Widget 刷新周期三重矛盾
**一次性修复**：统一话术（删除"5m"硬编码）+ 调整窗口（maxAge < staleThreshold）+ 对齐频率（reloadInterval 与 nextRefresh 统一量级）
**工作量**：0.5d

### 系统性问题 2：Power status 语义三重缺陷
**一次性修复**：拆分 powerStatusTitle + 让 charging 参与低电量色调 + 删除不可达分支 + 统一跨尺寸文案
**工作量**：1d

### 系统性问题 3：字符串契约死分支
**一次性修复**：在 SharedMetrics 暴露 `enum ThermalState: String` + `enum NetworkPathStatus: String`，删除 30 个死分支实例
**工作量**：0.5d

### 系统性问题 4：裁剪契约 + 策略不对称
**一次性修复**：提取统一裁剪策略枚举 + 统一 init/Codable 为 OR 策略
**工作量**：0.5d

### 系统性问题 5：话术漂移
**一次性修复**：建立概念词典，统一跨模块文案变体
**工作量**：0.5d

---

## 六、strengths（值得保留的设计优点）

- 所有 `hasXxxReport` 判定与展示文案 not-reported 判定**全部一致**（L2 验证 0 条不一致）
- 空字符串/nil/not-reported 三层**全部一致**（L3 验证）
- data-capability-audit.md ~120 条声明中 ~117 条与代码一致（L5 验证）
- 所有否定声明（不存储/不采集/不执行）**全部一致**，隐私合规无漂移
- PrivacyInfo.xcprivacy / entitlements / README / Info.plist 四层隐私声明一致
- batteryPercent(0-1) / cpuUsage(0-1) / loadAverage 三值 / timestamp(秒) 全链路量纲一致
- 前次 review P0-1（NSScreen 主线程）已通过 `DispatchQueue.main.sync` 修复
- 前次 review P1-2（系统事件观察）已通过 `registerSystemEventObservers` 修复
- Swift 6 严格并发合规，@MainActor 覆盖一致，[weak self] 捕获一致

---

## 七、验证命令

```bash
swift build
swift test
scripts/audit-localization.sh
scripts/validate-public-pages.sh
```

---

## 八、约束与边界

- 本审查为只读，未修改任何源码
- 与 `REVIEW-PLAN.md`（Bug 专项）互补，不重复其崩溃/性能/并发审查
- 与 `final-review-v2.md` 重叠项已标注引用关系
- 修复建议优先选择"在 SharedMetrics 暴露枚举/常量"而非"增加变体分支"
- 保持 Swift 6 严格并发合规、macOS 14 部署目标

---

**审查完成。** 本报告与 `docs/review/middle/logic-consistency-integrated.md` 及 5 份子报告共同构成完整审查交付物。
