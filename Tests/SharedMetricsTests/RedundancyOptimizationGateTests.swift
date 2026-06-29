import Foundation
import Testing
@testable import SharedMetrics

private func redundancyFixture(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private func redundancyFixtureExists(_ relativePath: String) -> Bool {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
}

@Suite("RedundancyOptimizationGateTests")
struct RedundancyOptimizationGateTests {
    @Test func redundancyReviewDocsUseCurrentVerifiedCorrections() throws {
        let final = try redundancyFixture("docs/review/top/redundancy-final.md")
        let middle = try redundancyFixture("docs/review/middle/redundancy-integrated.md")
        let r3 = try redundancyFixture("docs/review/subagents/R3-dead-state.md")

        #expect(final.contains("HEAD `876bcc2`"))
        #expect(final.contains("normalizedRate 仅 2 处"))
        #expect(final.contains("widgetCompact 20 个死字段"))
        #expect(final.contains("R1-3 是规则语义重复，不是逐字符重复"))
        #expect(middle.contains("widgetCompact 20 个死字段"))
        #expect(r3.contains("20 个死字段"))
        #expect(!final.contains("widgetCompact 25 个死字段"))
        #expect(!middle.contains("widgetCompact 25 个死字段"))
    }

    @Test func sharedMetricContractsExposeToneAndProgress() {
        #expect(ThermalState.nominal.metricStatusTone == .normal)
        #expect(ThermalState.warm.metricStatusTone == .warning)
        #expect(ThermalState.hot.metricStatusTone == .critical)
        #expect(ThermalState.critical.metricStatusTone == .critical)
        #expect(ThermalState.unknown.metricStatusTone == .neutral)
        #expect(ThermalState.hot.progress == 0.78)

        #expect(NetworkPathState.satisfied.metricStatusTone == .normal)
        #expect(NetworkPathState.requiresConnection.metricStatusTone == .warning)
        #expect(NetworkPathState.unsatisfied.metricStatusTone == .critical)
        #expect(NetworkPathState.unknown.metricStatusTone == .neutral)
        #expect(NetworkPathState.requiresConnection.progress == 0.45)
    }

    @Test func metricScalesOwnPresentationProgressHelpers() {
        #expect(MetricScales.reportedProgress(hasReport: false, progress: 0.7) == nil)
        #expect(MetricScales.reportedProgress(hasReport: true, progress: 0.7) == 0.7)
        #expect(MetricScales.fillWidth(0, in: 100, minimumVisibleWidth: 8) == 0)
        #expect(MetricScales.fillWidth(0.01, in: 100, minimumVisibleWidth: 8) == 8)
        #expect(MetricScales.fillWidth(0.5, in: 100, minimumVisibleWidth: 8) == 50)
    }

    @Test func accentComponentsOwnSharedLightAndDarkColors() {
        #expect(MetricAccentComponents.components(for: .green, appearance: .light) == MetricColorComponents(red: 0.04, green: 0.62, blue: 0.39))
        #expect(MetricAccentComponents.components(for: .green, appearance: .dark) == MetricColorComponents(red: 0.24, green: 0.82, blue: 0.62))
        #expect(MetricAccentComponents.components(for: .blue, appearance: .dark) == MetricColorComponents(red: 0.36, green: 0.62, blue: 1.00))
        #expect(MetricAccentComponents.components(for: .amber, appearance: .dark) == MetricColorComponents(red: 1.00, green: 0.68, blue: 0.28))
        #expect(MetricAccentComponents.components(for: .cyan, appearance: .dark) == MetricColorComponents(red: 0.29, green: 0.78, blue: 0.88))
        #expect(MetricAccentComponents.components(for: .red, appearance: .dark) == MetricColorComponents(red: 1.00, green: 0.42, blue: 0.42))
    }

    @Test func accentTokensReadSharedComponentsAcrossSurfaces() throws {
        let dashboardTokens = try redundancyFixture("Sources/PulseDockApp/DashboardVisualTokens.swift")
        let popover = try redundancyFixture("Sources/PulseDockApp/WidgetPanelView.swift")
        let widgetTokens = try redundancyFixture("Sources/PulseDockWidget/WidgetVisualTokens.swift")

        #expect(dashboardTokens.contains("MetricAccentComponents.components(for: accent"))
        #expect(popover.contains("MetricAccentComponents.components(for: accent"))
        #expect(widgetTokens.contains("MetricAccentComponents.components(for: accent"))
        #expect(!popover.contains("Color(red: 0.42, green: 0.66, blue: 1.00)"))
        #expect(!popover.contains("Color(red: 1.00, green: 0.38, blue: 0.36)"))
    }

    @Test func widgetCompactSnapshotTrimsCurrentDeadFields() {
        let source = MetricSnapshot(
            cpuUsage: 0.42,
            cpuCoreUsages: [0.1, 0.2],
            hasCPUUsageReport: true,
            physicalCoreCount: 8,
            logicalCoreCount: 10,
            activeProcessorCount: 10,
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
            loadAverage: 1.1,
            loadAverage5: 1.2,
            loadAverage15: 1.3,
            hasLoadAverageReport: true,
            thermalState: "Nominal",
            batteryPercent: 0.62,
            batteryIsCharging: false,
            batteryPowerSource: "Battery Power",
            batteryTimeRemainingMinutes: 42,
            batteryCycleCount: 12,
            batteryHealth: "Good",
            batteryCurrentCapacity: 82,
            batteryMaxCapacity: 90,
            batteryDesignCapacity: 100,
            batteryVoltageMillivolts: 12_000,
            batteryAmperageMilliamps: -300,
            networkPathStatus: "satisfied",
            diskFreeBytes: 4_000,
            diskTotalBytes: 10_000,
            uptimeSeconds: 120,
            hasUptimeReport: true,
            osVersion: "macOS",
            kernelRelease: "Darwin",
            timestamp: Date(timeIntervalSince1970: 1_000)
        )

        let compact = source.widgetCompactSnapshot()

        #expect(compact.cpuCoreUsages.isEmpty)
        #expect(compact.physicalCoreCount == 0)
        #expect(compact.memoryFreeBytes == 0)
        #expect(compact.memoryWiredBytes == 0)
        #expect(compact.memoryCompressedBytes == 0)
        #expect(compact.memoryCachedBytes == 0)
        #expect(compact.memorySwapUsedBytes == 0)
        #expect(compact.memorySwapTotalBytes == 0)
        #expect(compact.memorySwapAvailableBytes == 0)
        #expect(!compact.hasMemoryCompositionReport)
        #expect(compact.loadAverage5 == 0)
        #expect(compact.loadAverage15 == 0)
        #expect(compact.batteryTimeRemainingMinutes == nil)
        #expect(compact.batteryCycleCount == nil)
        #expect(compact.batteryHealth == nil)
        #expect(compact.batteryCurrentCapacity == nil)
        #expect(compact.batteryMaxCapacity == nil)
        #expect(compact.batteryDesignCapacity == nil)
        #expect(compact.batteryVoltageMillivolts == nil)
        #expect(compact.batteryAmperageMilliamps == nil)

        #expect(compact.cpuUsage == source.cpuUsage)
        #expect(compact.logicalCoreCount == source.logicalCoreCount)
        #expect(compact.activeProcessorCount == source.activeProcessorCount)
        #expect(compact.memoryUsedBytes == source.memoryUsedBytes)
        #expect(compact.memoryTotalBytes == source.memoryTotalBytes)
        #expect(compact.loadAverage == source.loadAverage)
        #expect(compact.batteryPercent == source.batteryPercent)
        #expect(compact.batteryPowerSource == source.batteryPowerSource)
        #expect(compact.canonicalNetworkPathState == .satisfied)
        #expect(compact.diskFreeBytes == source.diskFreeBytes)
        #expect(compact.diskTotalBytes == source.diskTotalBytes)
    }

    @Test func duplicateUiPanelsAreRemovedFromDashboardSource() throws {
        let dashboard = try redundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let sidebar = componentBody(named: "SidebarHealthCard", in: dashboard)
        let sensors = componentBody(named: "SensorsPage", in: dashboard)
        let history = componentBody(named: "HistoryAlertsPage", in: dashboard)
        let settings = componentBody(named: "SettingsPage", in: dashboard)

        #expect(!sidebar.contains("snapshot.sampleTimeText"))
        #expect(sensors.contains("statusRealtimeSignalsTitle"))
        #expect(!sensors.contains("statusSystemSignalsTitle"))
        #expect(!history.contains("localRuleTableTitle"))
        #expect(!settings.contains("settingsWidgetRefreshLabel"))
        #expect(!settings.contains("settingsWidgetMainWindowLabel"))
    }

    @Test func lowRiskPresentationDuplicationIsCentralized() throws {
        let appStrings = try redundancyFixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
        let widgetStrings = try redundancyFixture("Sources/PulseDockWidget/PulseDockWidgetStrings.swift")
        let popover = try redundancyFixture("Sources/PulseDockApp/WidgetPanelView.swift")
        let widget = try redundancyFixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
        let dashboard = try redundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let history = componentBody(named: "HistoryAlertsPage", in: dashboard)

        #expect(appStrings.contains("static var notReported: String {\n        SharedMetricStrings.notReported\n    }"))
        #expect(widgetStrings.contains("static var notReported: String {\n        SharedMetricStrings.notReported\n    }"))
        #expect(popover.contains("private struct PopoverStatusDot: View"))
        #expect(popover.contains("PopoverStatusDot(color: statusTint)"))
        #expect(popover.contains("PopoverStatusDot(color: tint)"))
        #expect(widget.contains("private struct WidgetStatusDot: View"))
        #expect(widget.contains("WidgetStatusDot(color: freshnessTone.color(for: colorScheme))"))
        #expect(widget.contains("WidgetStatusDot(color: tint)"))
        #expect(history.contains("let networkTrend = networkTrendValues(from: history)"))
        #expect(!history.contains("let networkTrend = networkTrendValues(from: history, keyPath: \\.networkBytesPerSecond)"))
    }

    @Test func designReferenceAssetsAreCanonicalized() throws {
        let rootReadme = try redundancyFixture("README.md")
        let designReadme = try redundancyFixture("design/gptimage2-system-monitor/README.md")

        #expect(rootReadme.contains("Design reference assets live in `design/gptimage2-system-monitor/`."))
        #expect(designReadme.contains("canonical tracked design reference for Pulse Dock"))
        #expect(!redundancyFixtureExists("designs/macos-monitor-ui"))
    }

    @Test func generatedXcodeProjectKeepsSharedMetricsAsImportableModule() throws {
        let generator = try redundancyFixture("scripts/generate-xcodeproj.rb")

        #expect(generator.contains("shared_target = project.new_target(:static_library, \"SharedMetrics\""))
        #expect(generator.contains("shared_files.each { |file| shared_target.add_file_references([file]) }"))
        #expect(!generator.contains("(shared_files + app_files).each"))
        #expect(!generator.contains("(shared_files + widget_files).each"))
        #expect(generator.contains("app_target.frameworks_build_phase.add_file_reference(shared_target.product_reference)"))
        #expect(generator.contains("widget_target.frameworks_build_phase.add_file_reference(shared_target.product_reference)"))
        #expect(generator.contains("app_target.add_dependency(shared_target)"))
        #expect(generator.contains("widget_target.add_dependency(shared_target)"))
    }

    @Test func widgetCompactSamplerDoesNotRunFullInventorySamplingBeforeCompaction() throws {
        let sampler = try redundancyFixture("Sources/SharedMetrics/SystemSampler.swift")
        let compactSampler = functionBody(containing: "public func sampleWidgetCompact(now: Date = Date())", in: sampler)
        let lightweightSampler = functionBody(containing: "private func sampleWidgetSnapshot(now: Date)", in: sampler)

        #expect(compactSampler.contains("widgetCompactSnapshot()"))
        #expect(!compactSampler.contains("sample(now:"))
        #expect(lightweightSampler.contains("MetricSnapshot("))
        #expect(lightweightSampler.contains("sampleDiskSpace()"))
        #expect(!compactSampler.contains("screenDisplaySnapshot"))
        #expect(!compactSampler.contains("cachedStorage"))
        #expect(!compactSampler.contains("cachedGPUDevices"))
        #expect(!compactSampler.contains("cachedDisplays"))
        #expect(!compactSampler.contains("storageVolumes: storage.volumes"))
        #expect(!compactSampler.contains("gpuDevices: gpuDevices"))
        #expect(!compactSampler.contains("displays: displays"))
        #expect(!lightweightSampler.contains("screenDisplaySnapshot"))
        #expect(!lightweightSampler.contains("cachedStorage"))
        #expect(!lightweightSampler.contains("cachedGPUDevices"))
        #expect(!lightweightSampler.contains("cachedDisplays"))
        #expect(!lightweightSampler.contains("sampleStorage"))
        #expect(!lightweightSampler.contains("sampleGPUDevices"))
        #expect(!lightweightSampler.contains("sampleDisplays"))
        #expect(!lightweightSampler.contains("storageVolumes:"))
        #expect(!lightweightSampler.contains("gpuDevices:"))
        #expect(!lightweightSampler.contains("displays:"))
    }

    @Test func historySampleChipUsesSameVisibleLimitAsSparkline() throws {
        let dashboard = try redundancyFixture("Sources/PulseDockApp/DashboardView.swift")

        #expect(dashboard.contains("private let sparklineVisibleSampleLimit = 80"))
        #expect(dashboard.contains("return values.suffix(sparklineVisibleSampleLimit)"))
        #expect(dashboard.contains("min(reportedSampleCount, sparklineVisibleSampleLimit)"))
        #expect(!dashboard.contains("return PulseDockAppStrings.recentSampleChipCount(reportedSampleCount)"))
    }
}

private func componentBody(named name: String, in source: String) -> String {
    guard let range = source.range(of: "private struct \(name)") else { return "" }
    let tail = source[range.lowerBound...]
    if let next = tail.dropFirst().range(of: "\nprivate struct ") {
        return String(tail[..<next.lowerBound])
    }
    if let next = tail.dropFirst().range(of: "\nprivate func ") {
        return String(tail[..<next.lowerBound])
    }
    return String(tail)
}

private func functionBody(containing signature: String, in source: String) -> String {
    guard let range = source.range(of: signature) else { return "" }
    let tail = source[range.lowerBound...]
    if let next = tail.dropFirst().range(of: "\n    private func ") {
        return String(tail[..<next.lowerBound])
    }
    if let next = tail.dropFirst().range(of: "\n    public func ") {
        return String(tail[..<next.lowerBound])
    }
    return String(tail)
}
