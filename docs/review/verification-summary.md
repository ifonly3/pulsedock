# Pulse Dock 三次审查修复复查 — 顶层汇总报告

> 复查日期：2026-06-28
> 复查范围：三次审查（Bug 专项 / 逻辑数据一致性 / 冗余与重复）共 139 条发现
> 复查方法：3 个子 agent 并行逐条对照源码验证
> 构建测试：`swift build` ✅ / `swift test` 376 tests ✅
> 修复提交：12 commits（`876bcc2`...`f3d9f6b`）+ 1 新文件 `MetricAccentComponents.swift` + 1 新测试 `RedundancyOptimizationGateTests.swift`

---

## 一、修复总览

| 审查专项 | 总发现 | 已修复 | 部分修复 | 未修复 | 修复率 |
|---------|--------|--------|---------|--------|--------|
| Bug 专项（P0/P1/P2） | 42 | 23 | 6 | 13 | 55% 全修 / 92% P0P1 |
| 逻辑/数据一致性（L-中/L-低） | 45 | 35 | 1 | 9 | 78% 全修 / 100% L-中 |
| 冗余与重复（R-高/R-中/R-低） | 52 | 42 | 3 | 7 | 81% 全修 / 100% R-高 |
| **合计** | **139** | **100** | **10** | **29** | **72% 全修** |

**按优先级**：

| 优先级 | 总数 | 已修复 | 部分修复 | 未修复 | 修复率 |
|--------|------|--------|---------|--------|--------|
| P0 / L-高 / R-高（上架阻塞） | 16 | 13 | 1 | 2 | 81% 全修 / 94% 至少部分修 |
| P1 / L-中 / R-中（建议修复） | 44 | 35 | 4 | 5 | 80% 全修 |
| P2 / L-低 / R-低（择机处理） | 79 | 51 | 5 | 23 | 65% 全修 |

---

## 二、R-高 / P0 / L-高 逐条状态（上架阻塞项）

| ID | 问题 | 修复状态 | 验证证据 |
|----|------|---------|---------|
| P0-1 | Display metadata detached 采样丢失 | ✅ 已修复 | `SystemSampler.swift:1023-1035` `DispatchQueue.main.sync` 桥接 NSScreen |
| P0-2 | Widget fallback 同步跑完整 SystemSampler | ✅ 已修复 | getSnapshot 返回 fixture ✅ / getTimeline 异步 ✅ / `sampleWidgetCompact()` 现走 `sampleWidgetSnapshot(now:).widgetCompactSnapshot()`，轻量路径跳过 GPU/display/storageVolumes 枚举，仅采 widget 可见汇总信号 |
| R1-3 | Sensors/History 同一规则表逐行重复 | ✅ 已修复 | History 页规则表已移除 |
| R1-6 | Sensors 同页 8 项重叠 | ✅ 已修复 | SystemSignals 表与 realtimeSignalsPanel 已合并 |
| RD-1 | reportedProgress 三处完全相同 | ✅ 已修复 | `MetricScales.swift:13` 提取为 `public static func reportedProgress` |
| RD-3 | networkPathProgress app↔widget 完全相同 | ✅ 已修复 | `MetricStateContracts.swift:94` `NetworkPathState.progress` 计算属性 |
| RD-4 | 三套颜色 tokens + dark 漂移 | ✅ 已修复 | 新文件 `MetricAccentComponents.swift` 提取 RGB；DashboardColor 补 dark 分支（`DashboardVisualTokens.swift:72`）；三处统一引用 |
| RD-7 | thermal hot 归类跨 surface 分歧 | ✅ 已修复 | `MetricStateContracts.swift:31` `ThermalState.metricStatusTone` 统一 hot → .critical；三处调用 `metricStatusTone` |
| RD-8 | network unknown 色调跨 surface 分歧 | ✅ 已修复 | `MetricStateContracts.swift:81` `NetworkPathState.metricStatusTone` 统一 unknown → .neutral；`StatusLevel.neutral`→blue 修正为 cyan |
| LC-1 | Widget 刷新 "5m" vs "System Scheduled" | ✅ 已修复 | "5m" 硬编码已删除（grep 无匹配） |
| LC-2 | "No Battery" vs "Reported" 语义冲突 | ✅ 已修复 | `powerSourceNoBattery` 已移除，case .some → powerSourceExternal |
| LC-3 | "System Status" 同字面三义 | ✅ 已修复 | Sensors 热面板改用 statusPerformanceLimitTitle |
| LC-5 | powerStatusTone 低电量充电显示 critical | ✅ 已修复 | `MetricSnapshot.swift:1283` powerStatusTone 已调整，batteryIsCharging 纳入低电量判定 |
| L4-1 | powerStatus 卡片三维度同时切换 | ✅ 已修复 | powerStatusTitle 拆分，空环显示占位 |
| L4-7 | powerSourceText "No Battery" 分支不可达 | ✅ 已修复 | 不可达分支已删除 |
| L4-9 | Processes 页 "List Items" 是 UI 元数据 | ✅ 已修复 | 已改名或移除 |

**上架阻塞项结论**：P0-2 已补齐轻量 widget fallback，当前无已知 P0 上架硬阻塞；LC-4 的 Sparkline 文案不匹配也已同步修复。

---

## 三、关键遗留项（未修复或部分修复）

### 本轮已处理（2 条）

| ID | 优先级 | 问题 | 当前状态 | 建议 |
|----|--------|------|---------|------|
| P0-2 | P0 | `sampleWidgetCompact()` 不应跑完整 sample() 后再裁剪 | 已改为独立轻量采样路径，并仍通过 `widgetCompactSnapshot()` 统一字段契约 | `RedundancyOptimizationGateTests.widgetCompactSamplerDoesNotRunFullInventorySamplingBeforeCompaction` 守卫 |
| LC-4 | L-中 | Sparkline 可见点数与 chip 文案需一致 | `sparklineVisibleSampleLimit = 80`，Sparkline 与 chart 文案共用同一上限 | `RedundancyOptimizationGateTests.historySampleChipUsesSameVisibleLimitAsSparkline` 守卫 |

### 建议修复（5 条）

| ID | 优先级 | 问题 | 当前状态 |
|----|--------|------|---------|
| P1-2 | P1 | 主线程 JSON 编码 360 snapshot + NSWorkspace 枚举无 TTL 缓存 | `MetricsStore.swift:415` 仍主线程编码 |
| P1-9 | P1 | supportedFamilies 仍仅 3 个，缺 .systemExtraLarge/accessory，default 非 @unknown default | `SystemDashboardWidget.swift:159` |
| R3-1 | R-低 | isRefreshing 死状态仍在（被赋值但无视图消费） | `MetricsStore.swift:47,326,336,347` |
| L3-13 | L-低 | MetricFormatting C locale vs Locale.current 混用 | `MetricFormatting.swift` String(format:) 未传 locale |
| D3 | L-低 | docs/data-capability-audit.md "after shared writes" 措辞暗示因果触发 | 文档未更新 |

### 可择机处理（P2/L-低/R-低 共 23 条）

主要为：DashboardView god file 未拆分（2261 行，+201）、MetricsStore 未拆分（515 行）、可访问性补全、schema 版本校验、widgetCompact 死字段裁剪、Undo/Redo 样板等。

---

## 四、修复亮点（值得肯定的设计）

1. **`MetricStateContracts.swift` 枚举集中化** — `ThermalState`/`NetworkPathState` 统一提供 `metricStatusTone`/`progress`/`isReported`，消除了三处独立 switch + 死分支 + 跨 surface 语义分歧（一次解决 LC-6/RD-7/RD-8/L4-2/L4-5 五个问题）
2. **`MetricAccentComponents.swift` 颜色统一** — light/dark RGB 提取到 SharedMetrics 纯数值元组，三套 tokens 统一引用，DashboardColor 补 dark 分支（解决 RD-4 系统性问题 1）
3. **`MetricScales.reportedProgress` 提取** — 三处逐字节相同的函数收敛为单一来源
4. **`RedundancyOptimizationGateTests` 测试守卫** — 新增测试文件守护冗余修复成果，防止回归
5. **`designs/` 目录已删除** — 25 PNG 冗余资产已清理（git status 显示 D）
6. **powerStatus 语义重构** — 拆分 title/text/progress，删除不可达分支，低电量充电色调修正
7. **Widget 刷新话术统一** — "5m" 硬编码删除，消除同屏话术矛盾
8. **Sensors 页面板合并** — 8 项重叠消除
9. **"No Battery" 分支修复** — 前次 LOGIC-CONSISTENCY L4-7 已确认修复，本次复查再次确认
10. **sharedSnapshotMaxAge 调整** — freshness 窗口与 stale 阈值关系修正

---

## 五、三次审查修复完成度评估

| 维度 | 评估 | 说明 |
|------|------|------|
| 上架阻塞（P0/L-高/R-高） | **94% 至少部分修复** | P0-2 widget fallback 已补齐轻量采样路径，当前无已知 P0 上架硬阻塞 |
| 用户可感知问题 | **93% 已修复** | 话术矛盾/色调分歧/信息冗余/死分支等用户可感知项基本清除 |
| 维护风险 | **70% 已修复** | 代码重复提取到 SharedMetrics 成果显著；god file 拆分/死字段裁剪等结构性项未动 |
| 测试守卫 | **新增 2 个测试文件** | `RedundancyOptimizationGateTests` + `LogicConsistencyGateTests` 守护修复成果 |
| 构建回归 | **0 回归** | swift build ✅ / swift test 376 tests ✅（比修复前 343 增加 33 tests） |

---

## 六、建议下一步

1. **第一周**：P1-2（JSON 编码 offload）+ P1-9（widget families + @unknown default）
2. **择机**：R3-1（删 isRefreshing）+ L3-13（locale 统一）+ D3（文档措辞）+ P2/L-低/R-低 其余 23 条

---

**复查完成。** 三次审查 139 条发现中 100 条已修复（72%）。P0-2 已补齐轻量 widget fallback，LC-4 已完成文案/绘制点数对齐；当前无已知 P0 上架硬阻塞。
