# Pulse Dock 深度代码审查 v2 — 中层整合报告

> 审查日期：2026-06-27
> 子 agent 数：6（01 SystemSampler / 02 数据模型 / 03 App 生命周期 / 04 App UI / 05 Widget / 06 构建资源测试）
> 审查文件：22 源文件 + 8 脚本 + 4 plist/entitlements + 3 测试文件 + Xcode 工程
> 基准：当前 working tree（HEAD 已含 stability-optimization Task 1/2/5/7/8 的部分落地证据）
> 前序资产：`docs/review/top/final-review.md`（2026-06-19 三层 review）、`docs/superpowers/plans/2026-06-27-pulse-dock-stability-optimization.md`

---

## 一、审查规模与去重

- 原始发现：6 份子报告共 **约 48 条** P0/P1/P2 发现
- 去重合并：4 组跨模块重复问题合并（采样线程模型 2→1、字符串契约 3→1、App Group 链路 2→1、错误静默 3→1）
- 去重后有效发现：**42 条**（P0: 2 / P1: 12 / P2: 28）
- 已被 stability-optimization 计划覆盖且已落地：**9 条**（标注 `[PLAN-DONE]`）
- 本次新发现：**33 条**（标注 `[NEW]`）

---

## 二、跨模块系统性问题（4 组）

**P0 mapping used by v2 review docs**:
- P0-1 Display metadata is lost when detached sampling needs NSScreen metadata.
- P0-2 Widget timeline fallback must not synchronously run the full SystemSampler path.

### 系统性问题 1：采样线程模型错配（P0，跨子 01/03）

**影响模块**：SharedMetrics/SystemSampler + PulseDockApp/MetricsStore + PulseDockWidget

**根因链路**：
```
MetricsStore.refresh() / startInitialRefresh()
  └─ Task.detached(priority: .userInitiated) { sampler.sample() }   [MetricsStore.swift:287-290, 322-324]
       └─ SystemSampler.sample() 恒在后台线程执行
            └─ sampleDisplays() → screenRefreshRatesByDisplayID()/screenScalesByDisplayID()/screenColorSpacesByDisplayID()
                 └─ guard Thread.isMainThread else { return [:] }    [SystemSampler.swift:1040, 1060, 1078]
                      └─ 后台线程全部返回空字典
                           └─ DisplayMetric.backingScaleFactor = 0 / colorSpaceModel = nil / refreshRate 不可靠
```

**后果**：
- App 端：Dashboard 显示器面板 Retina 倍数永远显示 "Not reported"，色彩空间空，ProMotion 刷新率 0Hz
- Widget 端：`widgetCompactSnapshot()` 裁剪 displays 字段，widget 不受影响；但 fallback 路径 `WidgetSamplerCache.sample()` 同样命中此 bug（结果被裁剪丢弃，无显示影响）
- 测试 `MetricFormattingTests.swift:3249-3256` 把 `guard Thread.isMainThread` 锁死为预期行为 → 退步被固化
- 文档 `docs/data-capability-audit.md:183` 描述与实际行为不符

**前次 review 状态**：2026-06-19 review 已识别为 Bug-1（硬阻塞），但 applied fix 选择了 "非主线程返回空" 而非 "dispatch 到主线程同步取值"，把潜在 crash 换成了确定性数据丢失。stability-optimization 计划 8 个 task 均未触及采样线程模型。

**修复方向**：
- 方案 A（推荐）：SystemSampler 内部对 NSScreen 部分用 `DispatchQueue.main.sync` 同步取值（sample 在 detached task 上不会自死锁，NSScreen.screens 只读访问亚毫秒）
- 方案 B：MetricsStore 在主 actor 预先捕获 NSScreen 快照，作为参数注入 `sample(now:displayContext:)`
- 方案 C：SystemSampler.sample() 标注 @MainActor，全部采样回主线程（需配合 P1 主线程阻塞 offload）

### 系统性问题 2：字符串契约脆弱（跨子 04/05，三处独立维护）

**影响模块**：SharedMetrics/SystemSampler + SharedMetrics/MetricSnapshot + PulseDockApp/DashboardView + PulseDockApp/WidgetPanelView + PulseDockWidget

**现状**：
- `SystemSampler.sampleThermalState()`（SystemSampler.swift:494-507）输出 Title-case：`"Nominal"/"Warm"/"Hot"/"Critical"/"Unknown"`
- `SystemSampler.statusText()`（SystemSampler.swift:178-188）输出：`"satisfied"/"unsatisfied"/"requiresConnection"/"unknown"`
- 下游三处独立用 `.lowercased()` 字符串匹配：
  1. `MetricSnapshot.thermalText/hasThermalStateReport/thermalLimitText`（MetricSnapshot.swift:1226-1251）
  2. `DashboardView.thermalStatus/thermalProgress/networkStatusLevel/networkPathProgress`（DashboardView.swift:1955-1983, 2041-2060）
  3. `WidgetPanelView.thermalTint/networkTint`（WidgetPanelView.swift:159-180）+ `SystemDashboardWidget.thermalTint/networkTint/networkPathProgress`（SystemDashboardWidget.swift:653-687）

**死分支**：
- thermal：`"fair"`/`"serious"` 永不命中（sampler 已把 Apple 的 `.fair→"Warm"`、`.serious→"Hot"` 预映射）
- network：`"requires_connection"`/`"requires connection"` 永不命中（sampler 只输出 camelCase `"requiresConnection"`）

**风险**：任一方改字符串大小写/拼写，其他两处静默落入 `default` 分支 → 显示错误颜色/进度，无编译错误，无运行时告警。

**修复方向**：在 SharedMetrics 暴露 `enum ThermalState: String` 与 `enum NetworkPathStatus: String`（或 `static let` 常量），sampler/MetricSnapshot/UI 全部引用同一常量，UI 接受枚举值实现编译期穷尽性检查。

### 系统性问题 3：App Group 共享链路脆弱（跨子 02/06）

**影响模块**：SharedMetrics/PulseDockAppGroup + SharedSnapshotStore + 构建/签名流程

**现状**：
- 四处 App Group 标识当前完全一致（Swift 常量 / app entitlements / widget entitlements / pbxproj bundle IDs）✅
- `SharedSnapshotStore.init` 双重校验：`supportsAppGroup(bundleIdentifier:)` 严格 `==` 匹配 + `containerURL` 非空
- **风险点 1（P1 release gate）**：SPM 直接运行 executable 时 `Bundle.main.bundleIdentifier` 为 nil → `supportsAppGroup` 返回 false → `defaults = nil` → save/load 静默 no-op，widget 永不更新，无日志
- **风险点 2（P1-1 新）**：生产签名下 App Group capability 未在 Apple Developer Portal 为两个 App ID 显式启用 → `containerURL` 返回 nil → 同样静默降级；`archive-app-store.sh` 用 automatic signing，不保证 profile 含 group
- **风险点 3（P1 新）**：`loadLatestSnapshot` 解码失败 `try?` 静默返回 nil（SharedSnapshotStore.swift:57），save 端有 DEBUG print 但 load 端无任何日志 → schema drift 时 widget 静默回退，开发者零线索
- **风险点 4（P2 新）**：无 schema 版本字段，字段类型变更时无法做迁移分支
- **风险点 5（P1-2 新）**：无 pbxproj bundle ID ↔ Swift 常量 ↔ entitlements 的自动交叉校验测试

**修复方向**：
- DEBUG 下 `supportsAppGroup` 返回 false 时打印一次警告
- `loadLatestSnapshot` 改 `do/catch` + DEBUG print（与 save 对称）
- 加 `schemaVersion: Int = 1` 字段
- 新增 pbxproj 解析测试，交叉校验四处一致
- archive 脚本末尾用 `codesign -d --entitlements` 校验 group 存在
- 闭环 `docs/app-store-readiness-checklist.md` 的 App Group 生产验证项

### 系统性问题 4：主线程性能与错误静默（跨子 03/04）

**影响模块**：PulseDockApp/MetricsStore + DashboardView

**主线程性能**：
- `saveSharedSnapshotIfNeeded`（MetricsStore.swift:349-359）JSON 编码 widgetCompactSnapshot，每 60s，主 actor
- `persistHistoryIfNeeded`（MetricsStore.swift:377-398）JSON 编码最多 360 个 MetricSnapshot，每 15s，主 actor → **帧卡顿风险**
- `applyVisibleApplicationSummary`（MetricsStore.swift:423-459）`NSWorkspace.shared.runningApplications` 每次 refresh 主 actor
- `isRefreshing` @Published 死状态（MetricsStore.swift:47）无视图消费，但每次 refresh 触发 2 次 objectWillChange → **3-4× 全树重渲染**
- trend 提取器（DashboardView.swift:1904-1940）O(n) 遍历最多 360 snapshot，在 OverviewPage body 中多次重复调用（:362-403），无 memoization → 每 tick ~36 次 O(n) 扫描
- `Sparkline.preparedValues`（DashboardView.swift:1347-1357）每次渲染 `suffix(80)` 重分配 + 2× 访问
- 阈值滑块拖拽（DashboardView.swift:1776-1789）每个 drag tick 触发 @Published → 整页重渲染 60 次/拖

**错误静默**：
- `_ = sharedSnapshotStore.saveLatestSnapshot(snapshot)`（MetricsStore.swift:358）丢弃 Bool 返回值
- `savedHistory` `try?` 解码（MetricsStore.swift:196-199）静默清空历史
- `persistHistoryIfNeeded` `try?` 编码（MetricsStore.swift:395-397）静默不持久化

**修复方向**：
- JSON 编码 offload 到 `Task.detached`，回主 actor 仅写 UserDefaults
- NSWorkspace 摘要加 5s TTL 缓存
- `isRefreshing` 移除 @Published 或拆分到独立 ObservableObject
- trend 提取器在 page body 顶部 `let` 一次，传值给各子组件
- `Sparkline.preparedValues` hoist 到 body 内 `let`
- 滑块用本地 @State + onEditingChanged commit
- try? 改 do/catch + DEBUG print

---

## 三、上架风险评估

| 风险等级 | 项 | 阻塞类型 |
|----------|-----|----------|
| 高 | 采样线程模型导致显示器数据永远空（P0-1） | 功能性缺陷，用户可见 |
| 高 | widget fallback 线程阻塞 watchdog 风险（P0 widget） | 可能 widget 停滞 |
| 中 | App Group 生产签名未验证（P1-1 构建） | 可能 widget 静默停更 |
| 中 | 主线程 JSON 编码帧卡顿（P1-2 性能） | 体验降级 |
| 中 | 唤醒后首采样网络速率近零（P1-3） | 用户体验缺陷 |
| 中 | 首次 widget tick CPU/网络 "Not reported"（P1 widget） | 首次体验缺陷 |
| 低 | 字符串契约死分支 | 维护风险，非用户可见 |
| 低 | 本地化硬编码 | 中国区 v1 非阻塞，全球发布阻塞 |
| 低 | 可访问性缺口 | App Store 不强制，HIG 鼓励 |

---

## 四、与 stability-optimization 计划的对齐

stability-optimization 计划 8 个 task 的落地状态（本次审查确认）：

| Task | 计划内容 | 落地状态 | 证据 |
|------|----------|----------|------|
| Task 1 | 数值转换硬化（Int(Double.nan) 防 trap） | ✅ 已落地 | SystemSampler.swift:1270-1298 `intValue/doubleValue/finiteInt` |
| Task 2 | CPU 基线重置 + 电池缓存 | ✅ 已落地 | SystemSampler.swift:251-256 `resetCPUBaselines`；MetricsStore.swift:125-126；cachedBattery |
| Task 3 | 电源状态色调语义 | ✅ 已落地 | MetricSnapshot.swift:1283-1319 powerStatusTone 已重写 |
| Task 4 | 格式化边界（PB/EB、<60s） | ✅ 已落地 | MetricFormatting.swift:11,28,92-94 |
| Task 5 | 共享快照写入可观测 | ✅ 已落地（save 端） | SharedSnapshotStore.swift:37-52 返回 Bool + DEBUG print；**load 端未覆盖（本报告新发现）** |
| Task 6 | 网络 rate 对数尺度 | ✅ 已落地 | MetricScales.swift log10 曲线 |
| Task 7 | widget 编译/family/cache | ✅ 已落地 | #if !SWIFT_PACKAGE；default→SmallWidget；无死 priming 状态 |
| Task 8 | 可注入性/常量清理 | ⚠️ 部分 | StatusPopoverTiming enum 已加；NetworkPathObserving 协议存在；**popover 竞态/采样线程未触及** |

**结论**：stability-optimization 计划 8 个 task 在源码层基本落地，但**遗留 2 个关键盲区**：
1. 采样线程模型（P0-1）—— 计划完全未覆盖，是当前最严重的用户可见功能缺陷
2. App Group 生产验证 + load 端可观测性 —— 计划仅覆盖 save 端

本次审查新发现的 33 条 `[NEW]` 项中，**P0 级 2 条、P1 级 10 条** 不在现有计划内，建议补入 stability-optimization 计划或新建 hardening 计划。

---

## 五、子报告索引

6 份子 agent 报告已在对话中产出，核心发现已整合入本报告与 `top/final-review-v2.md`。如需落盘存档，可按以下路径保存：
- `docs/review/subagents/01-sharedmetrics-sampler.md`
- `docs/review/subagents/02-sharedmetrics-model.md`
- `docs/review/subagents/03-pulsedockapp-lifecycle.md`
- `docs/review/subagents/04-pulsedockapp-ui.md`
- `docs/review/subagents/05-pulsedockwidget.md`
- `docs/review/subagents/06-build-resources-tests.md`

（子 05 widget 报告尾部因输出长度被截断并存至 `tool-output` 文件，核心 P0-P2 发现已在前半部分完整获取并整合。）
