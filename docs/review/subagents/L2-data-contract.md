# L2 — 字符串契约与报告状态一致性报告

> 审查日期：2026-06-28
> 审查范围：SystemSampler.swift 字符串输出端 ↔ MetricSnapshot.swift 派生文本/报告状态判定 ↔ DashboardView.swift / WidgetPanelView.swift / SystemDashboardWidget.swift 消费端
> 审查方法：逐字段枚举 sampler 输出集合 → 逐点枚举下游 switch/case 分支 → 比对死分支/漏分支 → 校验 hasXxxReport 与展示文案 not-reported 判定一致性

---

## 一、字段一致性矩阵

| 字段 | sampler 输出集合 | 下游匹配点 | 下游分支集合 | 死分支 | 漏分支 | 报告状态判定对齐 |
|------|-----------------|-----------|-------------|--------|--------|-----------------|
| thermalState | Nominal / Warm / Hot / Critical / Unknown (SystemSampler.swift:598-611) | MetricSnapshot.swift:1232 (thermalText), :1241 (hasThermalStateReport), :1249 (thermalLimitText); DashboardView.swift:2319 (thermalStatus), :2329 (thermalProgress); WidgetPanelView.swift:160 (thermalTint); SystemDashboardWidget.swift:675 (thermalTint) | nominal, warm, fair, hot, serious, critical + default（7处统一） | fair, serious（每处2个死值×7处=14个死分支实例） | 无（Unknown 落 default → notReported，有意设计） | 一致 — hasThermalStateReport(:1240) case 集合 = thermalText(:1232) case 集合 = thermalLimitText(:1248) case 集合，三者完全相同，Unknown 统一落 default |
| networkPathStatus | satisfied / unsatisfied / requiresConnection / unknown (SystemSampler.swift:192-203, :132) | MetricSnapshot.swift:1333 (hasNetworkPathReport), :1344 (networkPathText), :1360 (networkPathDetailText); DashboardView.swift:2233 (networkStatusLevel), :2250 (networkPathProgress); WidgetPanelView.swift:170 (networkTint); SystemDashboardWidget.swift:685 (networkTint), :698 (networkPathProgress) | satisfied, unsatisfied, requiresconnection, requires_connection, requires connection + default（8处统一） | requires_connection, requires connection（每处2个死值×8处=16个死分支实例） | 无（unknown 落 default → notReported/false，有意设计） | 一致 — hasNetworkPathReport(:1332) 的 true 分支集合 = networkPathText(:1344) 的非 default 分支集合 = networkPathDetailText(:1360) 的非 default 分支集合，unknown 统一落 default |
| batteryPowerSource | "AC Power" / "Battery Power" / "UPS Power" (IOKit kIOPSPowerSourceStateKey / IOPSGetProvidingPowerSourceType) 或 nil (SystemSampler.swift:645, :674-676) | MetricSnapshot.swift:1262 (powerSourceText), :1302 (powerStatusTone-battery), :1314 (powerStatusTone-no battery); SystemDashboardWidget.swift:745 (compactPowerStatusText) | ac power, battery power, ups power, .some(non-empty), default | 无 | 无 | 一致 — hasPowerStatusReport(:1282) = `batteryPercent != nil \|\| batteryPowerSource != nil`；powerSourceText(:1262) default 分支在两者皆 nil 时返回 notReported |
| batteryHealth | "Good" / "Fair" / "Poor" / "Check Battery" / "Permanent Battery Failure" (IOKit kIOPSBatteryHealthKey/ConditionKey) 或 nil (SystemSampler.swift:652-653) | MetricSnapshot.swift:1536 (batteryHealthText) | good, fair, poor, check battery, permanent battery failure, default | 无 | 无（default 回传原始字符串） | N/A — 无独立 hasBatteryHealthReport；batteryHealthText(:1532) 以空字符串判定 notReported，与 nil 一致 |
| gpuKind (GPUDeviceMetric.kindText) | 非字符串字段 — 由 isRemovable/isLowPower 布尔派生 (SystemSampler.swift:1038-1039 → MetricSnapshot.swift:199-203) | 无 switch 匹配 — 仅展示 | N/A | 无 | 无 | N/A — hasDeviceKindReport 由 sampler 硬编码 true (SystemSampler.swift:1047) |
| storageKind (StorageVolumeMetric.kindText) | 非字符串字段 — 由 isRemovable/isEjectable/isInternal 布尔派生 (SystemSampler.swift:1004-1007 → MetricSnapshot.swift:551-556) | 无 switch 匹配 — 仅展示 | N/A | 无 | 无 | N/A — hasKindReport 由 sampler 条件设置 (SystemSampler.swift:1008) |
| displayTopology (DisplayMetric.stateText) | 非字符串字段 — 由 isMain/isBuiltin/isMirrored 布尔派生 (SystemSampler.swift:1090-1092 → MetricSnapshot.swift:401-408) | 无 switch 匹配 — 仅展示 | N/A | 无 | 无 | N/A — hasTopologyReport 由 sampler 硬编码 true (SystemSampler.swift:1094) |
| processState (ProcessMetric.stateText) | 非字符串字段 — 由 isActive/isHidden/activationPolicy 派生 (MetricSnapshot.swift:72-79) | 无 switch 匹配 — 仅展示 | N/A | 无 | 无 | N/A — hasStateReport 由调用方设置 |
| networkInterface kind | "Wi-Fi" / "Ethernet" / "VPN" / "Loopback" / "Bridge" / "Thunderbolt" / "Apple Wireless Direct" / "Bluetooth" / "Cellular" / SharedMetricStrings.other / SharedMetricStrings.networkInterface (SystemSampler.swift:1316-1330) | 无 switch 匹配 — 仅展示；NetworkInterfaceMetric.reportedInterfaceKind(:684) 将 "Other" 映射为 notReported | N/A | 无 | 无 | N/A — 模型层归一化，无下游 switch |
| networkInterface stateText | 非字符串字段 — 由 isUp/isLoopback 布尔派生 (MetricSnapshot.swift:714-718) | 无 switch 匹配 — 仅展示 | N/A | 无 | 无 | N/A |
| networkPathInterfaceKinds | "Wi-Fi" / "Ethernet" / "Cellular" / "Loopback" / SharedMetricStrings.other (SystemSampler.swift:205-213) | 无 switch 匹配 — networkPathDetailText(:1365) 直接 joined 展示 | N/A | 无 | 无 | N/A |
| colorSpaceModel | "Gray" / "RGB" / "CMYK" / "Lab" / "DeviceN" / "Indexed" / "Patterned" / nil (SystemSampler.swift:1193-1216) | 无 switch 匹配 — DisplayMetric.colorText(:378) 直接展示 | N/A | 无 | 无 | N/A |
| fileSystem (storage) | statfs.f_fstypename 原始字符串 (如 "apfs"/"hfs") 或 SharedMetricStrings.notReported (SystemSampler.swift:1332-1336) | 无 switch 匹配 — StorageVolumeMetric.reportedFileSystemName(:506) 将 "unknown" 映射为 notReported | N/A | 无 | 无 | N/A |
| osVersion | ProcessInfo.operatingSystemVersionString (SystemSampler.swift:587) | 无 switch 匹配 — hasOSVersionReport(:1490) 排除 "macOS" 占位值 | N/A | 无 | 无 | 一致 — placeholder osVersion="macOS" → hasOSVersionReport=false → osVersionText=notReported |
| kernelRelease | uname().release 或 "" (SystemSampler.swift:592-596) | 无 switch 匹配 — hasKernelReleaseReport(:1502) 检查非空 | N/A | 无 | 无 | 一致 — "" → hasKernelReleaseReport=false → kernelText=notReported |

---

## 二、死分支详情

### 死分支 L2-1: thermalState "fair"

- **sampler 输出点**: SystemSampler.swift:602-603 — `case .fair: return "Warm"`（.fair 被重命名为 "Warm"，不输出 "fair"）
- **下游匹配点（7处）**:
  1. MetricSnapshot.swift:1234 — `case "warm", "fair": return SharedMetricStrings.thermalStateWarm`
  2. MetricSnapshot.swift:1242 — `case "nominal", "warm", "fair", "hot", "serious", "critical": return true`
  3. MetricSnapshot.swift:1252 — `case "warm", "fair": return SharedMetricStrings.thermalLimitWarm`
  4. DashboardView.swift:2321 — `case "hot", "serious", "warm", "fair": .warning`
  5. DashboardView.swift:2332 — `case "warm", "fair": 0.52`
  6. WidgetPanelView.swift:162 — `case "warm", "fair": Palette.amber(for: colorScheme)`
  7. SystemDashboardWidget.swift:677 — `case "warm", "fair": WidgetColor.amber(for: colorScheme)`
- **死值**: `"fair"`（lowercased 后）— sampler 从不输出此字符串
- **历史原因推测**: ProcessInfo.thermalState 枚举有 `.fair` case，开发者可能认为 sampler 会直接输出枚举名 "fair"，但 sampler 实际将 `.fair` 重命名为 "Warm"（SystemSampler.swift:602）。另一可能是为兼容旧版持久化数据中可能存的 "fair" 字符串。
- **风险**: 低 — "fair" 分支与 "warm" 分支共享同一返回值，删除 "fair" 不改变任何行为。但存在误导性：阅读者可能以为 sampler 会输出 "fair"。
- **建议**: 删除所有 `"fair"` 分支（7处），或添加注释说明其为旧数据兼容。若需兼容旧持久化数据，应在 Codable decoder 层做归一化（`decode → "fair" ? "warm"`），而非在所有消费端冗余匹配。
- **优先级**: L-低

### 死分支 L2-2: thermalState "serious"

- **sampler 输出点**: SystemSampler.swift:604-605 — `case .serious: return "Hot"`（.serious 被重命名为 "Hot"，不输出 "serious"）
- **下游匹配点（7处）**:
  1. MetricSnapshot.swift:1235 — `case "hot", "serious": return SharedMetricStrings.thermalStateHot`
  2. MetricSnapshot.swift:1242 — `case "nominal", "warm", "fair", "hot", "serious", "critical": return true`
  3. MetricSnapshot.swift:1251 — `case "hot", "serious": return SharedMetricStrings.thermalLimitHot`
  4. DashboardView.swift:2321 — `case "hot", "serious", "warm", "fair": .warning`
  5. DashboardView.swift:2331 — `case "hot", "serious": 0.78`
  6. WidgetPanelView.swift:161 — `case "critical", "hot", "serious": Palette.red(for: colorScheme)`
  7. SystemDashboardWidget.swift:676 — `case "critical", "hot", "serious": WidgetColor.red(for: colorScheme)`
- **死值**: `"serious"`（lowercased 后）— sampler 从不输出此字符串
- **历史原因推测**: 同 L2-1，ProcessInfo.thermalState 枚举有 `.serious` case，但 sampler 重命名为 "Hot"。
- **风险**: 低 — "serious" 分支与 "hot" 分支共享同一返回值，删除不改变行为。
- **建议**: 同 L2-1，删除或注释说明。建议与 L2-1 一并处理。
- **优先级**: L-低

### 死分支 L2-3: networkPathStatus "requires_connection"

- **sampler 输出点**: SystemSampler.swift:198-199 — `case .requiresConnection: return "requiresConnection"`（camelCase，不输出下划线变体）
- **下游匹配点（8处）**:
  1. MetricSnapshot.swift:1334 — `case "satisfied", "unsatisfied", "requiresconnection", "requires_connection", "requires connection": return true`
  2. MetricSnapshot.swift:1349 — `case "requiresconnection", "requires_connection", "requires connection": return ...`
  3. MetricSnapshot.swift:1361 — `case "satisfied", "requiresconnection", "requires_connection", "requires connection": ...`
  4. DashboardView.swift:2238 — `case "requiresconnection", "requires_connection", "requires connection": .warning`
  5. DashboardView.swift:2253 — `case "requiresconnection", "requires_connection", "requires connection": 0.45`
  6. WidgetPanelView.swift:173 — `case "requiresconnection", "requires_connection", "requires connection": ...`
  7. SystemDashboardWidget.swift:688 — `case "requiresconnection", "requires_connection", "requires connection": ...`
  8. SystemDashboardWidget.swift:701 — `case "requiresconnection", "requires_connection", "requires connection": 0.45`
- **死值**: `"requires_connection"`（下划线变体）— sampler 从不输出此格式
- **历史原因推测**: 可能是防御性编码，猜测 NWPath.Status 可能输出下划线格式；或为兼容外部/旧持久化数据。NWPath.Status 枚举实际只输出 camelCase `requiresConnection`。
- **风险**: 低 — 与 "requiresconnection" 共享同一返回值，删除不改变行为。但 8 处冗余匹配增加了维护负担。
- **建议**: 删除所有 `"requires_connection"` 和 `"requires connection"` 变体，仅保留 `"requiresconnection"`（8处）。若需兼容旧数据，在 decoder 层归一化。
- **优先级**: L-低

### 死分支 L2-4: networkPathStatus "requires connection"

- **sampler 输出点**: 同 L2-3，SystemSampler.swift:198-199 只输出 `"requiresConnection"`
- **下游匹配点**: 同 L2-3 的 8 处
- **死值**: `"requires connection"`（空格变体）
- **历史原因推测**: 同 L2-3，可能为防御性编码或兼容外部数据。
- **风险**: 低 — 同上。
- **建议**: 同 L2-3，与 L2-3 一并处理。
- **优先级**: L-低

---

## 三、漏分支详情

### 漏分支 L2-5: thermalState "unknown" 无显式 case

- **sampler 输出点**: SystemSampler.swift:608-609 — `@unknown default: return "Unknown"`
- **下游匹配点**:
  - MetricSnapshot.swift:1237 (thermalText) — default → notReported
  - MetricSnapshot.swift:1244 (hasThermalStateReport) — default → false
  - MetricSnapshot.swift:1254 (thermalLimitText) — default → notReported
  - DashboardView.swift:2323 (thermalStatus) — **有显式 `case "unknown": .neutral`**
  - DashboardView.swift:2334 (thermalProgress) — **有显式 `case "unknown": nil`**
  - WidgetPanelView.swift:164 (thermalTint) — **有显式 `case "unknown": Palette.cyan`**
  - SystemDashboardWidget.swift:679 (thermalTint) — **有显式 `case "unknown": WidgetColor.cyan`**
- **分析**: MetricSnapshot.swift 中 3 处 thermal 相关属性 **无** "unknown" 显式 case，依赖 default 兜底。DashboardView/WidgetPanelView/SystemDashboardWidget 中 4 处 **有** "unknown" 显式 case。这不是真正的"漏分支"——default 行为与 "unknown" 显式 case 行为一致（notReported/false/nil/cyan 都等于"未报告"语义），但代码风格不一致：部分显式处理 "unknown"，部分依赖 default 隐式覆盖。
- **风险**: 极低 — 行为正确但风格不统一。若未来有人将 default 行为改为其他值，MetricSnapshot 的 3 处会与 UI 的 4 处产生分歧。
- **建议**: 在 MetricSnapshot.swift 的 thermalText/hasThermalStateReport/thermalLimitText 中添加显式 `case "unknown"` 分支，与 UI 层保持一致。
- **优先级**: L-低

### 漏分支 L2-6: networkPathStatus "unknown" 无显式 case

- **sampler 输出点**: SystemSampler.swift:200-201 — `@unknown default: return "unknown"`；NetworkPathSample 默认值 `status = "unknown"` (SystemSampler.swift:132)
- **下游匹配点**:
  - MetricSnapshot.swift:1336 (hasNetworkPathReport) — default → false
  - MetricSnapshot.swift:1351 (networkPathText) — default → notReported
  - MetricSnapshot.swift:1369 (networkPathDetailText) — default → notReported（但受 guard hasNetworkPathReport 保护）
  - DashboardView.swift:2240 (networkStatusLevel) — default → .neutral
  - DashboardView.swift:2257 (networkPathProgress) — default → 0
  - WidgetPanelView.swift:177 (networkTint) — default → cyan
  - SystemDashboardWidget.swift:692 (networkTint) — default → cyan
  - SystemDashboardWidget.swift:705 (networkPathProgress) — default → 0
- **分析**: 所有 8 处均无 "unknown" 显式 case，统一依赖 default 兜底。行为一致（false/notReported/neutral/0/cyan 都等于"未报告"语义）。风格统一但缺少自文档化。
- **风险**: 极低 — 行为正确。若未来新增其他非 sampler 产出的 status 值，default 会静默吞掉。
- **建议**: 可选添加 `case "unknown"` 显式分支以提高可读性。
- **优先级**: L-低

---

## 四、报告状态判定一致性

### 4.1 thermalState — hasThermalStateReport vs thermalText vs thermalLimitText

| 属性 | 位置 | case 集合 | "Unknown" 行为 |
|------|------|----------|---------------|
| hasThermalStateReport | MetricSnapshot.swift:1240-1247 | nominal, warm, fair, hot, serious, critical → true; default → false | false |
| thermalText | MetricSnapshot.swift:1231-1239 | nominal, warm, fair, hot, serious, critical → 译文; default → notReported | notReported |
| thermalLimitText | MetricSnapshot.swift:1248-1256 | critical, hot, serious, warm, fair, nominal → 译文; default → notReported | notReported |

**判定**: **一致**。三者 case 集合完全相同（nominal/warm/fair/hot/serious/critical），"Unknown" 统一落 default。`hasThermalStateReport == false` 当且仅当 `thermalText == notReported` 当且仅当 `thermalLimitText == notReported`。含相同的死分支 fair/serious。

### 4.2 networkPathStatus — hasNetworkPathReport vs networkPathText vs networkPathDetailText vs networkPathCapabilityText vs networkRuleStatusText

| 属性 | 位置 | true/非default 分支集合 | "unknown" 行为 |
|------|------|------------------------|---------------|
| hasNetworkPathReport | MetricSnapshot.swift:1332-1339 | satisfied, unsatisfied, requiresconnection, requires_connection, requires connection → true | false (default) |
| networkPathText | MetricSnapshot.swift:1343-1354 | satisfied, unsatisfied, requiresconnection, requires_connection, requires connection → 译文 | notReported (default) |
| networkPathDetailText | MetricSnapshot.swift:1355-1382 | satisfied, requiresconnection, requires_connection, requires connection → 接口列表; unsatisfied → 无连接 | notReported (guard + default) |
| networkPathCapabilityText | MetricSnapshot.swift:1383-1397 | 依赖 hasNetworkPathReport + isNetworkPathOffline | notReported (guard) |
| networkRuleStatusText | MetricSnapshot.swift:1398-1403 | 依赖 hasNetworkPathReport; satisfied → Normal; 其他 → Attention | notReported (guard) |

**判定**: **一致**。`hasNetworkPathReport == false` 当且仅当 `networkPathText == notReported`。networkPathDetailText/CapabilityText/RuleStatusText 均通过 `guard hasNetworkPathReport` 保护，unknown 时统一返回 notReported。含相同的死分支 requires_connection/requires connection。

**注意**: `networkPathDetailText` 的 case 集合略有不同——它将 `unsatisfied` 单独分一组（→ "No Connection"），将 `satisfied` + `requiresConnection` 变体分另一组（→ 接口列表）。但这不影响报告状态判定一致性，因为 guard 在前。

### 4.3 batteryPowerSource — hasPowerStatusReport vs powerSourceText vs powerStatusText

| 属性 | 位置 | 判定条件 | nil+nil 行为 |
|------|------|---------|-------------|
| hasPowerStatusReport | MetricSnapshot.swift:1282-1284 | `batteryPercent != nil \|\| batteryPowerSource != nil` | false |
| powerSourceText | MetricSnapshot.swift:1261-1278 | switch + default fallback | notReported (default → guard 失败) |
| powerStatusText | MetricSnapshot.swift:1279-1281 | `batteryPercent == nil ? powerSourceText : batteryPercentText` | powerSourceText → notReported |

**判定**: **一致**。当 `batteryPercent == nil && batteryPowerSource == nil` 时：hasPowerStatusReport=false，powerSourceText 走 default → `guard batteryPowerSource != nil` 失败 → notReported，powerStatusText=powerSourceText=notReported。

**边界情况**: `batteryPowerSource == nil && batteryPercent != nil` → hasPowerStatusReport=true（batteryPercent 非 nil），powerSourceText 走 default → `batteryIsCharging ? adapterCharging : stateNotReported`。这是"有电量但无电源类型"的合理降级。

### 4.4 isNotReportedText / isOtherText 中英文字面量穷举（B4 锚点）

**SharedMetricStrings.swift:376-389**:
```swift
static func isNotReportedText(_ text: String) -> Bool {
    return trimmed.isEmpty
        || trimmed == notReported           // 本地化 "Not reported"
        || trimmed == legacyEnglishNotReported  // 硬编码 "Not reported"
        || trimmed == legacyChineseNotReported  // 硬编码 "未报告"
}
static func isOtherText(_ text: String) -> Bool {
    return trimmed == other                 // 本地化 "Other"
        || trimmed == legacyEnglishOther       // 硬编码 "Other"
        || trimmed == legacyChineseOther       // 硬编码 "其他"
}
```

**分析**:
1. `notReported` 与 `legacyEnglishNotReported` 在英文环境下值相同（"Not reported"），比较冗余但不冲突。
2. 中文字面量 `"未报告"` / `"其他"` 用于兼容旧版持久化数据（可能在中文字区环境下保存了中文 not-reported/other 字符串）。
3. **潜在问题**: 若 app 本地化为日语、韩语等，`notReported`/`other` 会返回日/韩译文，`isNotReportedText` 仍能匹配（通过 `trimmed == notReported`）。但若有第三方/旧数据含日/韩字面量的 "Not reported" 译文，则无法匹配。这在当前架构下不会发生（所有 not-reported 字符串都由 SharedMetricStrings.notReported 生成），但对外部数据无防御力。
4. **碰撞风险**: 若系统存在名为 "Not reported" / "未报告" / "Other" / "其他" 的进程/GPU/显示器，会被误判为 not-reported/other。概率极低但理论存在。`NetworkInterfaceMetric.reportedInterfaceKind`（:684-687）用 `isOtherText` 过滤 "Other" kind → notReported，若系统接口 kind 真为 "Other" 会被误过滤。

**判定**: 当前架构下**功能正确**，但设计脆弱——依赖字面量穷举而非结构化标记。建议长期改为 sentinel 对象或专用 not-reported 标记类型。

### 4.5 gpuKind / storageKind / displayTopology / processState — 无字符串契约

均为布尔字段派生的展示文本（GPUDeviceMetric.kindText / StorageVolumeMetric.kindText / DisplayMetric.stateText / ProcessMetric.stateText），sampler 不输出字符串 kind/type，下游无 switch 匹配。`hasXxxReport` 布尔由 sampler 直接设置。**无契约一致性风险**。

### 4.6 空字符串 vs nil vs not-reported 三层一致性

| 字段 | sampler 空字符串输出 | 模型层归一化 | 展示层 notReported 判定 | 一致性 |
|------|-------------------|------------|----------------------|--------|
| kernelRelease | `""` (SystemSampler.swift:594) | 无归一化 | `hasKernelReleaseReport` 检查非空 (:1502) → false → kernelText=notReported | 一致 |
| batteryPowerSource | nil (不输出空串) | `reportedPowerSource` 空串→nil (:962-965) | hasPowerStatusReport 检查 != nil (:1283) | 一致 |
| batteryHealth | nil (不输出空串) | 无归一化 | batteryHealthText 检查空串→notReported (:1534) | 一致 |
| cpuBrandName | nil (sysctl 失败时) | 无归一化 | cpuBrandText 检查 nil+空→notReported (:1082) | 一致 |
| osVersion | 永不空 (ProcessInfo) | 无归一化 | hasOSVersionReport 排除 "macOS" 占位 (:1492) | 一致 |
| fileSystem | notReported (statfs 失败时, :1334) | reportedFileSystemName "unknown"→notReported (:508) | 无独立 hasReport | 一致 |
| displayName/kind (network) | 可能空或 "Interface" | reportedInterfaceDisplayName 空/"Interface"→notReported (:679-682) | hasInventoryReport 用 isNotReportedText (:721-722) | 一致 |

**判定**: **全部一致**。未发现空字符串/nil/not-reported 三层不一致。

---

## 五、与 REVIEW-PLAN.md 重叠项

| REVIEW-PLAN 项 | 本报告对应发现 | 状态 |
|---------------|--------------|------|
| P2-3 字符串字面量匹配 sampler 输出，rename 即静默失效；含死分支 (`DashboardView.swift:2041-2060`、`WidgetPanelView.swift:159-180`、`SystemDashboardWidget.swift:653-687`) | L2-1 ~ L2-4（thermalState fair/serious + networkPathStatus requires_connection/requires connection 死分支） | **已验证并扩展** — 确认死分支 4 个死值 × 15 个匹配点 = 30 个死分支实例；补充了 MetricSnapshot.swift 中的 3+3 处匹配点（REVIEW-PLAN 仅列出 UI 层 3 文件） |
| B1 thermal 死分支 (REVIEW-PLAN 提及 `SystemSampler.swift:494-507` 只输出 Nominal/Warm/Hot/Critical/Unknown) | L2-1, L2-2 | **已验证** — sampler 行号更新为 :598-611（REVIEW-PLAN 行号偏移），确认 .fair→"Warm" / .serious→"Hot" 重命名 |
| B2 network path 变体冗余 (REVIEW-PLAN 提及 `SystemSampler.swift:198-199` 只输出 "requiresConnection") | L2-3, L2-4 | **已验证** — 确认 8 处下游匹配点含 requires_connection/requires connection 死变体 |
| B4 isNotReportedText/isOtherText 中英文字面量穷举 (REVIEW-PLAN 提及 `SharedMetricStrings.swift:376-389`) | 4.4 节 | **已验证并扩展** — 确认功能正确但设计脆弱；新增碰撞风险分析（进程/GPU/接口名碰巧为 "Not reported"/"Other"） |
| batteryPowerSource 取值集合 vs 下游 .lowercased() 匹配覆盖 | 4.3 节 + 矩阵 | **已验证** — "AC Power"/"Battery Power"/"UPS Power" 全覆盖，.some(non-empty) 兜底 |
| hasThermalStateReport vs thermalText vs thermalLimitText 三者一致性 | 4.1 节 | **已验证** — 三者 case 集合完全相同，一致 |
| gpuKind/storageKind/displayTopology/processState 集中映射 | 矩阵 + 4.5 节 | **已验证** — 均为布尔派生，无字符串契约风险 |
| networkPathStatus sampler 输出 vs 所有下游匹配 | 矩阵 + 4.2 节 | **已验证** — 8 处匹配点全部覆盖，unknown 统一落 default |
| 空字符串 vs nil vs not-reported 三层不一致 | 4.6 节 | **已验证** — 全部一致，未发现三层不一致 |

---

## 六、汇总

| 类别 | 数量 | 详情 |
|------|------|------|
| 死分支（唯一死值） | 4 | thermalState "fair" / "serious"；networkPathStatus "requires_connection" / "requires connection" |
| 死分支实例（匹配点×死值） | 30 | thermal: 2死值 × 7处 = 14；network: 2死值 × 8处 = 16 |
| 漏分支 | 0 | 所有 sampler 产出值均有对应匹配或有意 default 兜底 |
| 风格不一致（非功能 bug） | 2 | L2-5 thermalState "unknown" 在 MetricSnapshot 3处无显式 case / UI 4处有显式；L2-6 networkPathStatus "unknown" 全 8 处无显式 case |
| 报告状态判定不一致 | 0 | hasThermalStateReport/hasNetworkPathReport/hasPowerStatusReport 与对应展示文案 not-reported 判定全部一致 |
| 设计脆弱项 | 1 | isNotReportedText/isOtherText 依赖中英文字面量穷举，存在碰撞风险（4.4 节） |
| 优先级分布 | L-低 × 6 | 所有发现均为低优先级——死分支不影响运行时行为（共享同一返回值），报告状态判定全部一致 |

**核心结论**: 字符串契约层面**无功能 bug**——所有死分支与活跃分支共享同一返回值，不会导致错误行为；所有 hasXxxReport 判定与展示文案 not-reported 判定一致。主要问题是**代码冗余与风格不一致**（30 个死分支实例 + 2 处 "unknown" 显式/隐式风格分歧），建议通过 decoder 层归一化 + 删除冗余分支 + 添加显式 "unknown" case 统一解决。
