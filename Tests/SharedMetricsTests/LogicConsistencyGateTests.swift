import Foundation
import Testing
@testable import SharedMetrics

private func fixture(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

@Test func logicReviewFinalReportUsesVerifiedCountsAndCorrections() throws {
    let report = try fixture("docs/review/top/logic-consistency-final.md")

    #expect(report.contains("| 原始发现 | 51 条 |"))
    #expect(report.contains("| 去重后有效发现 | 51 条（L-中:14 / L-低:37 / L-高:0） |"))
    #expect(report.contains("LC-2 部分误报"))
    #expect(report.contains("D1 不属实"))
    #expect(report.contains("L4-12 已由几何压缩与滚动缓解"))
}

@Test func dataCapabilityAuditDoesNotClaimGpuDisplayWidgets() throws {
    let audit = try fixture("docs/data-capability-audit.md")
    let gpuLine = audit
        .split(separator: "\n")
        .first { $0.contains("| GPU and display |") }
        .map(String.init) ?? ""

    #expect(!gpuLine.localizedCaseInsensitiveContains("widgets"))
}

@Test func widgetRefreshCopyDoesNotExposeGuaranteedFiveMinuteLabel() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let strings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")

    #expect(!dashboard.contains("control: \"5m\""))
    #expect(dashboard.contains("control: PulseDockAppStrings.settingsWidgetRefreshValue"))
    #expect(strings.contains("app.settings.widget.refresh.value"))
    #expect(strings.contains("System Scheduled"))
}

@Test func widgetTimelinePolicyUsesNonEqualFreshnessThresholds() {
    #expect(WidgetTimelinePolicy.sharedSnapshotMaxAge < WidgetTimelinePolicy.staleThreshold)
    #expect(WidgetTimelinePolicy.requestedRefreshInterval < WidgetTimelinePolicy.agingThreshold)
    #expect(WidgetTimelinePolicy.appReloadThrottle == WidgetTimelinePolicy.requestedRefreshInterval)
}

@Test func chargingLowBatteryDoesNotRenderCriticalPowerTone() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0,
        hasCPUUsageReport: false,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.19,
        batteryIsCharging: true,
        batteryPowerSource: "AC Power",
        diskFreeBytes: 0,
        timestamp: Date()
    )

    #expect(snapshot.powerStatusTone == .normal)
}

@Test func unknownPowerSourceUsesLocalizedExternalPowerText() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0,
        hasCPUUsageReport: false,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "Wireless Power",
        diskFreeBytes: 0,
        timestamp: Date()
    )

    #expect(snapshot.powerSourceText == SharedMetricStrings.powerSourceExternal)
    #expect(snapshot.powerStatusText == SharedMetricStrings.powerSourceExternal)
    #expect(snapshot.hasPowerStatusReport)
}

@Test func powerSourceNoBatteryBranchIsRemovedFromRuntimePath() throws {
    let snapshot = try fixture("Sources/SharedMetrics/MetricSnapshot.swift")

    #expect(!snapshot.contains("powerSourceNoBattery"))
    #expect(snapshot.contains("powerSourceExternal"))
}

@Test func statusRuleTablesUseOneVocabulary() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let strings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")

    #expect(dashboard.contains("PulseDockAppStrings.localRuleTableTitle"))
    #expect(dashboard.contains("PulseDockAppStrings.localRuleTableSubtitle"))
    #expect(dashboard.contains("PulseDockAppStrings.statusWarning"))
    #expect(!dashboard.contains("PulseDockAppStrings.statusTriggered"))
    #expect(dashboard.contains("PulseDockAppStrings.statusPerformanceLimitTitle"))
    #expect(strings.contains("app.dashboard.local_rules.title"))
}

@Test func processesSummaryLabelsDisplayedRowsExplicitly() throws {
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")

    #expect(!appStrings.contains("processesListItemsTitle"))
    #expect(appStrings.contains("processesDisplayedAppsTitle"))
    #expect(appStrings.contains("Displayed Apps"))
}

@Test func widgetCompactSnapshotPreservesWidgetFallbackVisibleFields() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.2,
        hasCPUUsageReport: true,
        memoryUsedBytes: 8_000,
        memoryTotalBytes: 16_000,
        memoryFreeBytes: 2_000,
        memoryWiredBytes: 1_000,
        memoryCompressedBytes: 500,
        memoryCachedBytes: 3_000,
        memorySwapUsedBytes: 128,
        memorySwapTotalBytes: 256,
        memorySwapAvailableBytes: 128,
        hasMemoryCompositionReport: true,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.62,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        batteryCycleCount: 12,
        batteryHealth: "Good",
        batteryCurrentCapacity: 82,
        batteryMaxCapacity: 90,
        batteryDesignCapacity: 100,
        batteryVoltageMillivolts: 12_000,
        batteryAmperageMilliamps: -300,
        diskFreeBytes: 0,
        timestamp: Date()
    )

    let compact = snapshot.widgetCompactSnapshot()

    #expect(compact.hasMemoryCompositionReport)
    #expect(compact.memoryFreeBytes == 2_000)
    #expect(compact.memoryWiredBytes == 1_000)
    #expect(compact.memoryCompressedBytes == 500)
    #expect(compact.memoryCachedBytes == 3_000)
    #expect(compact.batteryCycleCount == 12)
    #expect(compact.batteryHealth == "Good")
    #expect(compact.batteryCurrentCapacity == 82)
    #expect(compact.batteryMaxCapacity == 90)
    #expect(compact.batteryDesignCapacity == 100)
    #expect(compact.batteryVoltageMillivolts == 12_000)
    #expect(compact.batteryAmperageMilliamps == -300)
}

@Test func decodedNetworkDirectionCountersMatchInitializerFallback() throws {
    let json = """
    {
      "cpuUsage": 0,
      "hasCPUUsageReport": false,
      "memoryUsedBytes": 0,
      "memoryTotalBytes": 0,
      "loadAverage": 0,
      "thermalState": "Unknown",
      "batteryPercent": null,
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "hasNetworkByteCounters": false,
      "networkInBytesPerSecond": 0,
      "networkOutBytesPerSecond": 0,
      "networkPathStatus": "unknown",
      "diskFreeBytes": 0,
      "diskTotalBytes": 0,
      "uptimeSeconds": 0,
      "timestamp": 0
    }
    """

    let decoded = try JSONDecoder().decode(MetricSnapshot.self, from: Data(json.utf8))
    let constructed = MetricSnapshot(
        cpuUsage: 0,
        hasCPUUsageReport: false,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        loadAverage: 0,
        thermalState: "Unknown",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        hasNetworkByteCounters: false,
        networkInBytesPerSecond: 0,
        networkOutBytesPerSecond: 0,
        diskFreeBytes: 0,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(decoded.hasNetworkDirectionByteCounters == constructed.hasNetworkDirectionByteCounters)
}

@Test func networkTotalAndDirectionTextsUseSameUnitFamily() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0,
        hasCPUUsageReport: false,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 125_000,
        hasNetworkByteCounters: true,
        hasNetworkDirectionByteCounters: true,
        networkInBytesPerSecond: 62_500,
        networkOutBytesPerSecond: 62_500,
        diskFreeBytes: 0,
        timestamp: Date()
    )

    #expect(snapshot.networkText == "1 Mbps")
    #expect(snapshot.networkInText == "500 Kbps")
    #expect(snapshot.networkOutText == "500 Kbps")
}

@Test func networkRateProgressDocumentsReferenceCapacity() {
    #expect(MetricScales.networkRateReferenceBytesPerSecond == 12_500_000_000)
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 1_250_000_000) < 1)
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 12_500_000_000) == 1)
}

@Test func sharedSnapshotStoreRejectsUnsupportedSchemaVersion() throws {
    let suiteName = "logic-consistency-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = SharedSnapshotStore(defaults: defaults)

    var snapshot = MetricSnapshot.placeholder
    snapshot.schemaVersion = MetricSnapshot.currentSchemaVersion + 1
    snapshot.timestamp = Date()

    #expect(store.saveLatestSnapshot(snapshot))
    #expect(store.loadLatestSnapshot(maxAge: 60, now: snapshot.timestamp) == nil)
}

@Test func metricsStoreUpdatesSharedSnapshotWriteDateOnlyAfterSuccessfulSave() throws {
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")

    #expect(metricsStore.contains("if sharedSnapshotStore.saveLatestSnapshot(snapshot) {"))
    #expect(metricsStore.contains("lastSharedSnapshotWriteDate = snapshot.timestamp"))
    #expect(!metricsStore.contains("_ = sharedSnapshotStore.saveLatestSnapshot(snapshot)"))
}

@Test func thermalStateCanonicalizesLegacyAliases() {
    #expect(ThermalState(raw: "nominal") == .nominal)
    #expect(ThermalState(raw: "fair") == .warm)
    #expect(ThermalState(raw: "serious") == .hot)
    #expect(ThermalState(raw: "unknown") == .unknown)
}

@Test func networkPathStateCanonicalizesLegacyAliases() {
    #expect(NetworkPathState(raw: "satisfied") == .satisfied)
    #expect(NetworkPathState(raw: "requiresConnection") == .requiresConnection)
    #expect(NetworkPathState(raw: "requires_connection") == .requiresConnection)
    #expect(NetworkPathState(raw: "requires connection") == .requiresConnection)
    #expect(NetworkPathState(raw: "unknown") == .unknown)
}
