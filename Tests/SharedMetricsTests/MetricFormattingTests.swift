import CoreGraphics
import Foundation
import ImageIO
import MachO
import Testing
@testable import SharedMetrics

@Test func percentageFormatterClampsAndRoundsValues() {
    #expect(MetricFormatting.percentage(0.184) == "18%")
    #expect(MetricFormatting.percentage(-0.2) == "0%")
    #expect(MetricFormatting.percentage(1.4) == "100%")
}

@Test func bytesFormatterUsesBinaryUnits() {
    #expect(MetricFormatting.bytes(512) == "512 B")
    #expect(MetricFormatting.bytes(2_097_152) == "2.0 MB")
    #expect(MetricFormatting.bytes(13_314_867_200) == "12.4 GB")
    #expect(MetricFormatting.bytes(1_125_899_906_842_624) == "1.0 PB")
    #expect(MetricFormatting.compactBytes(1_152_921_504_606_846_976) == "1 EB")
}

@Test func networkRateFormatterUsesBitsPerSecond() {
    #expect(MetricFormatting.networkRate(bytesPerSecond: 0) == "0 Kbps")
    #expect(MetricFormatting.networkRate(bytesPerSecond: 5_250_000) == "42 Mbps")
    #expect(MetricFormatting.networkRate(bytesPerSecond: 125_000_000) == "1.0 Gbps")
    #expect(MetricFormatting.bitRate(bitsPerSecond: 1_200_000_000) == "1.2 Gbps")
}

@Test func networkRateFormattingLabelsBytesAndBitsExplicitly() {
    #expect(MetricFormatting.byteRate(bytesPerSecond: 1_024) == "1 KB/s")
    #expect(MetricFormatting.bitRate(bitsPerSecond: 1_000) == "1 Kbps")
    #expect(MetricFormatting.bitRate(bitsPerSecond: 1_000_000) == "1 Mbps")
    #expect(MetricFormatting.networkRate(bytesPerSecond: 125_000) == "1 Mbps")
    #expect(MetricFormatting.directionalNetworkRate(bytesPerSecond: 62_500) == "500 Kbps")
}

@Test func networkRateProgressUsesSharedLogarithmicScale() {
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 0) == 0)
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 40_000_000) > 0.5)
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 1_250_000_000) < 1)
    #expect(MetricScales.networkRateProgress(bytesPerSecond: 12_500_000_000) == 1)
}

@Test func networkSamplerUsesPublic64BitInterfaceCountersWhenAvailable() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(sampler.contains("private struct NetworkInterfaceStats64"))
    #expect(sampler.contains("let interfaceStats = networkInterfaceStatsByIndex()"))
    #expect(sampler.contains("private func networkInterfaceStatsByIndex() -> [UInt32: NetworkInterfaceStats64]"))
    #expect(sampler.contains("NET_RT_IFLIST2"))
    #expect(sampler.contains("if_msghdr2"))
    #expect(sampler.contains("header.ifm_data"))
    #expect(sampler.contains("interfaceStats[interfaceIndex]"))
    #expect(sampler.contains("data.assumingMemoryBound(to: if_data.self)"))
    #expect(audit.contains("64-bit interface counters"))
}

@Test func networkInterfaceFallbackDoesNotAssumeEn0IsWifi() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(!sampler.contains("if name.hasPrefix(\"en\") { return name == \"en0\" ? \"Wi-Fi\" : \"Ethernet\" }"))
    #expect(sampler.contains("if name.hasPrefix(\"en\") { return \"Network\" }"))
    #expect(sampler.contains("private func interfaceKindDisplayName(sortKind: String) -> String"))
    #expect(sampler.contains("case \"Network\": return SharedMetricStrings.networkInterface"))
    #expect(audit.contains("Network interface kind falls back to a generic interface label when SystemConfiguration cannot identify en* devices."))
}

@Test func networkFallbackDoesNotTrustIfDataByteCounters() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(!sampler.contains("record.bytesReceived = UInt64(interfaceData.ifi_ibytes)"))
    #expect(!sampler.contains("record.bytesSent = UInt64(interfaceData.ifi_obytes)"))
    #expect(sampler.contains("record.hasByteCounters = false"))
    #expect(audit.contains("Network byte counters prefer sysctl interface statistics and do not mark legacy getifaddrs fallback counters as authoritative."))
    #expect(!audit.contains("fall back to `getifaddrs` counters when route sysctl data is unavailable"))
    #expect(audit.contains("remain not-reported when route sysctl byte counters are unavailable"))
}

@Test func networkPathStatusUsesUserReadableLabels() {
    let online = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkPathStatus: "satisfied",
        networkPathIsConstrained: true,
        hasNetworkPathCostReport: true,
        networkPathInterfaceKinds: ["Wi-Fi", "VPN"],
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    let offline = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkPathStatus: "unsatisfied",
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let unknown = MetricSnapshot.placeholder

    #expect(online.networkPathText == SharedMetricStrings.networkPathStatusOnline)
    #expect(online.hasNetworkPathReport)
    #expect(online.networkPathDetailText == "Wi-Fi / VPN · \(SharedMetricStrings.networkPathLowDataMode)")
    #expect(offline.networkPathText == SharedMetricStrings.networkPathStatusOffline)
    #expect(offline.hasNetworkPathReport)
    #expect(offline.networkPathDetailText == SharedMetricStrings.networkPathNoConnection)
    #expect(unknown.networkPathText == SharedMetricStrings.notReported)
    #expect(!unknown.hasNetworkPathReport)
    #expect(unknown.networkPathDetailText == SharedMetricStrings.notReported)
    #expect(unknown.networkPathCapabilityText == SharedMetricStrings.notReported)
}

@Test func unknownNetworkPathDoesNotBorrowOnlineDetailsOrProgress() throws {
    let unknownWithCostFlags = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkPathStatus: "unknown",
        networkPathIsExpensive: true,
        networkPathIsConstrained: true,
        hasNetworkPathCostReport: true,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!unknownWithCostFlags.hasNetworkPathReport)
    #expect(unknownWithCostFlags.networkPathDetailText == SharedMetricStrings.notReported)
    #expect(unknownWithCostFlags.networkLowDataModeText == SharedMetricStrings.notReported)
    #expect(unknownWithCostFlags.networkMeteredText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var networkPathDetailText: String {\n        guard hasNetworkPathReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("case .unknown:\n            parts.append(SharedMetricStrings.notReported)"))
    #expect(!dashboardView.contains("activeNetworkInterfaceCount(snapshot) > 0 ? 0.65 : 0.2"))
    #expect(!dashboardView.contains("activeNetworkInterfaceCount(snapshot) > 0 ? .neutral : .warning"))
    #expect(dashboardView.contains("private func networkStatusLevel(_ snapshot: MetricSnapshot) -> StatusLevel"))
    #expect(dashboardView.contains("statusLevel(for: snapshot.canonicalNetworkPathState.metricStatusTone)"))
    #expect(widget.contains("MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress)"))
    #expect(!widget.contains("default:\n        0.35"))
    #expect(audit.contains("Unknown network path state keeps detail and progress in a not-reported state"))
    #expect(audit.contains("Unknown network path state keeps dashboard status neutral instead of warning, so missing path data is not treated as a network issue."))
    #expect(audit.contains("Network path detail suppresses low-data and metered qualifiers when path status itself is not reported."))
    #expect(audit.contains("Source-level tests prevent unknown network path state from borrowing online details or positive progress"))
    #expect(audit.contains("Source-level tests require unknown network path status to remain neutral instead of warning."))
    #expect(audit.contains("Source-level tests require network path detail to guard cost qualifiers behind reported path state."))
}

@Test func sampleTimeUsesReportedStateInsteadOfPlaceholderTimestampAcrossSurfaces() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let missingTimestampJSON = """
    {
      "cpuUsage": 0,
      "hasCPUUsageReport": false,
      "memoryUsedBytes": 0,
      "memoryTotalBytes": 0,
      "loadAverage": 0,
      "hasLoadAverageReport": false,
      "thermalState": "Unknown",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "hasNetworkByteCounters": false,
      "networkPathStatus": "unknown",
      "diskFreeBytes": 0,
      "diskTotalBytes": 0,
      "uptimeSeconds": 0,
      "hasUptimeReport": false,
      "osVersion": "macOS"
    }
    """.data(using: .utf8)!
    let decodedMissingTimestamp = try JSONDecoder().decode(MetricSnapshot.self, from: missingTimestampJSON)

    let reported = MetricSnapshot(
        cpuUsage: 0.1,
        hasCPUUsageReport: true,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        hasLoadAverageReport: true,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 3_600)
    )

    #expect(MetricSnapshot.placeholder.hasSampleTimeReport == false)
    #expect(MetricSnapshot.placeholder.sampleTimeText == SharedMetricStrings.notReported)
    #expect(decodedMissingTimestamp.hasSampleTimeReport == false)
    #expect(decodedMissingTimestamp.sampleTimeText == SharedMetricStrings.notReported)
    #expect(decodedMissingTimestamp.sampleClockText == SharedMetricStrings.notReported)
    #expect(reported.hasSampleTimeReport)
    #expect(reported.sampleTimeText != SharedMetricStrings.notReported)
    #expect(reported.sampleClockText != SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasSampleTimeReport: Bool"))
    #expect(metricSnapshot.contains("public var sampleTimeText: String"))
    #expect(metricSnapshot.contains("public var sampleClockText: String"))
    #expect(metricSnapshot.contains("guard hasSampleTimeReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("timestamp: Date(timeIntervalSince1970: 0)"))
    #expect(metricSnapshot.contains("timestamp = try values.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date(timeIntervalSince1970: 0)"))
    #expect(!dashboardView.contains("snapshot.timestamp.formatted(.dateTime.hour().minute().second())"))
    #expect(!dashboardView.contains("snapshot.timestamp.formatted(.dateTime.hour().minute()))"))
    #expect(dashboardView.contains("PulseDockAppStrings.dashboardSampleChip(snapshot.sampleTimeText)"))
    #expect(dashboardView.contains("Text(snapshot.sampleClockText)"))
    #expect(!dashboardView.contains("StatusSummaryRow(title: PulseDockAppStrings.cpuRecentSampleLabel, value: snapshot.sampleTimeText"))
    #expect(widgetPanel.contains("Text(snapshot.sampleTimeText)"))
    #expect(!widgetPanel.contains("snapshot.timestamp.formatted(.dateTime.hour().minute().second())"))
    #expect(widget.contains("WidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport, freshnessTone: freshnessTone, entryKind: entryKind)"))
    #expect(widget.contains("CompactWidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport, freshnessTone: freshnessTone, entryKind: entryKind)"))
    #expect(widget.contains("WidgetHeader(title: PulseDockWidgetStrings.headerSystemStatus, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport, freshnessTone: freshnessTone, entryKind: entryKind)"))
    #expect(widget.contains("let hasTimeReport: Bool"))
    #expect(widget.contains("if hasTimeReport {"))
    #expect(widget.contains(".accessibilityLabel(accessibilityLabel)"))
    #expect(widget.contains("private var accessibilityLabel: String"))
    #expect(!widget.contains("timeText != \"未报告\""))
    #expect(!widget.contains("timeText == \"未报告\""))
    #expect(!widget.contains("timeText: snapshot.sampleTimeText"))
    #expect(!widget.contains("WidgetHeader(title: \"Pulse Dock\", time: snapshot.timestamp)"))
    #expect(!widget.contains("CompactWidgetHeader(title: \"Pulse Dock\", time: snapshot.timestamp)"))
    #expect(audit.contains("Sample timestamp display text reports the system-not-reported state for placeholder or missing timestamp snapshots."))
    #expect(audit.contains("Widget headers use minute-level sampled time text so narrow widget families stay readable."))
    #expect(audit.contains("Widget headers use explicit sample-time reported-state flags instead of comparing sampled time display text."))
    #expect(audit.contains("Source-level tests prevent app and widget surfaces from formatting placeholder snapshot timestamps as real sample times."))
}

@Test func networkPathSurfacesPublicPathCapabilities() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let widgetView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var networkPathSupportsDNS: Bool"))
    #expect(metricSnapshot.contains("public var networkPathSupportsIPv4: Bool"))
    #expect(metricSnapshot.contains("public var networkPathSupportsIPv6: Bool"))
    #expect(metricSnapshot.contains("public var networkPathCapabilityText: String"))
    #expect(sampler.contains("supportsDNS: path.supportsDNS"))
    #expect(sampler.contains("supportsIPv4: path.supportsIPv4"))
    #expect(sampler.contains("supportsIPv6: path.supportsIPv6"))
    #expect(sampler.contains("if path.usesInterfaceType(.other) { kinds.append(SharedMetricStrings.other) }"))
    #expect(!sampler.contains("if path.usesInterfaceType(.other) { kinds.append(\"Other\") }"))
    #expect(metricsStore.contains("networkPathSupportsDNS: snapshot.networkPathSupportsDNS"))
    #expect(dashboardView.contains("DashboardPanel(title: PulseDockAppStrings.networkConnectivityTitle"))
    #expect(dashboardView.contains("snapshot.networkPathCapabilityText"))
    #expect(widgetView.contains("WidgetRow(title: PulseDockWidgetStrings.metricPath, value: snapshot.networkPathCapabilityText"))
    #expect(audit.contains("DNS/IPv4/IPv6 path support"))
    #expect(audit.contains("Network path other-interface labels use localized product text instead of leaking internal enum wording."))
}

@Test func networkPathSupportFalseUsesUnsupportedInsteadOfNotReportedWhenPathIsReported() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let reportedNoCapability = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkPathStatus: "satisfied",
        networkPathSupportsDNS: false,
        networkPathSupportsIPv4: false,
        networkPathSupportsIPv6: false,
        hasNetworkPathSupportReport: true,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(reportedNoCapability.networkPathCapabilityText == SharedMetricStrings.networkPathUnsupported)
    #expect(reportedNoCapability.networkDNSCapabilityText == SharedMetricStrings.networkPathUnsupported)
    #expect(reportedNoCapability.networkIPv4CapabilityText == SharedMetricStrings.networkPathUnsupported)
    #expect(reportedNoCapability.networkIPv6CapabilityText == SharedMetricStrings.networkPathUnsupported)
    #expect(MetricSnapshot.placeholder.networkPathCapabilityText == SharedMetricStrings.notReported)
    #expect(MetricSnapshot.placeholder.networkDNSCapabilityText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("guard hasNetworkPathReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("return parts.isEmpty ? SharedMetricStrings.networkPathUnsupported : parts.joined(separator: \" / \")"))
    #expect(metricSnapshot.contains("public var networkDNSCapabilityText: String"))
    #expect(metricSnapshot.contains("public var networkIPv4CapabilityText: String"))
    #expect(metricSnapshot.contains("public var networkIPv6CapabilityText: String"))
    #expect(dashboardView.contains("[\"DNS\", snapshot.networkDNSCapabilityText, PulseDockAppStrings.networkNameResolutionSource]"))
    #expect(dashboardView.contains("[\"IPv4\", snapshot.networkIPv4CapabilityText, PulseDockAppStrings.networkSystemPathSubtitle]"))
    #expect(dashboardView.contains("[\"IPv6\", snapshot.networkIPv6CapabilityText, PulseDockAppStrings.networkSystemPathSubtitle]"))
    #expect(!dashboardView.contains("private func networkPathSupportText"))
    #expect(!dashboardView.contains("networkPathSupportText("))
    #expect(!dashboardView.contains("snapshot.networkPathSupportsDNS ? \"支持\" : \"未报告\""))
    #expect(audit.contains("Network path support rows distinguish reported unsupported DNS/IPv4/IPv6 capabilities from missing path data."))
    #expect(audit.contains("Source-level tests prevent reported false network path support flags from being displayed as not-reported."))
    #expect(audit.contains("Network path capability row display text is centralized on the shared snapshot model."))
    #expect(audit.contains("Source-level tests require Network page path capability labels to come from the shared snapshot model."))
}

@Test func legacyNetworkPathMissingSupportFlagsDoesNotInventUnsupportedCapabilities() throws {
    let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: Data("""
    {
      "cpuUsage": 0.1,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 2048,
      "loadAverage": 0.2,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "networkPathStatus": "satisfied",
      "diskFreeBytes": 1024,
      "timestamp": 0
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.networkPathText == SharedMetricStrings.networkPathStatusOnline)
    #expect(snapshot.networkPathCapabilityText == SharedMetricStrings.notReported)
    #expect(snapshot.networkDNSCapabilityText == SharedMetricStrings.notReported)
    #expect(snapshot.networkIPv4CapabilityText == SharedMetricStrings.notReported)
    #expect(snapshot.networkIPv6CapabilityText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasNetworkPathSupportReport: Bool"))
    #expect(metricSnapshot.contains("guard hasNetworkPathSupportReport else { return SharedMetricStrings.notReported }"))
    #expect(sampler.contains("hasSupportReport: true"))
    #expect(sampler.contains("hasNetworkPathSupportReport: networkPath.hasSupportReport"))
    #expect(audit.contains("Legacy network path snapshots missing DNS, IPv4, or IPv6 support flags remain not-reported instead of being displayed as unsupported capabilities."))
    #expect(audit.contains("Source-level tests prevent legacy network path support fields from inventing unsupported DNS, IPv4, or IPv6 capabilities."))
}

@Test func initializerNetworkPathStatusOnlyDoesNotInventSupportOrCostReports() throws {
    let statusOnlyPath = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkPathStatus: "satisfied",
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(statusOnlyPath.networkPathText == SharedMetricStrings.networkPathStatusOnline)
    #expect(statusOnlyPath.hasNetworkPathReport)
    #expect(!statusOnlyPath.hasNetworkPathSupportReport)
    #expect(!statusOnlyPath.hasNetworkPathCostReport)
    #expect(statusOnlyPath.networkPathCapabilityText == SharedMetricStrings.notReported)
    #expect(statusOnlyPath.networkDNSCapabilityText == SharedMetricStrings.notReported)
    #expect(statusOnlyPath.networkIPv4CapabilityText == SharedMetricStrings.notReported)
    #expect(statusOnlyPath.networkIPv6CapabilityText == SharedMetricStrings.notReported)
    #expect(statusOnlyPath.networkLowDataModeText == SharedMetricStrings.notReported)
    #expect(statusOnlyPath.networkMeteredText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("hasNetworkPathCostReport: Bool = false"))
    #expect(metricSnapshot.contains("hasNetworkPathSupportReport: Bool = false"))
    #expect(!metricSnapshot.contains("hasNetworkPathCostReport: Bool = true"))
    #expect(!metricSnapshot.contains("hasNetworkPathSupportReport: Bool = true"))
    #expect(audit.contains("MetricSnapshot initializer defaults do not mark network path support or cost flags as reported when only path status is provided."))
    #expect(audit.contains("Source-level tests prevent status-only network path snapshots from inventing unsupported capabilities or disabled path flags."))
}

@Test func networkPathSupportRowsUseUnavailableWhenPathIsOffline() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let offlineSnapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkPathStatus: "unsatisfied",
        networkPathSupportsDNS: false,
        networkPathSupportsIPv4: false,
        networkPathSupportsIPv6: false,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(offlineSnapshot.networkPathText == SharedMetricStrings.networkPathStatusOffline)
    #expect(offlineSnapshot.networkPathCapabilityText == SharedMetricStrings.networkPathUnavailable)
    #expect(offlineSnapshot.networkDNSCapabilityText == SharedMetricStrings.networkPathUnavailable)
    #expect(offlineSnapshot.networkIPv4CapabilityText == SharedMetricStrings.networkPathUnavailable)
    #expect(offlineSnapshot.networkIPv6CapabilityText == SharedMetricStrings.networkPathUnavailable)
    #expect(!dashboardView.contains("private func networkPathSupportText"))
    #expect(!dashboardView.contains("networkPathSupportText("))
    #expect(audit.contains("Network path support rows show unavailable when the reported path is offline instead of treating offline false flags as unsupported capabilities."))
    #expect(audit.contains("Source-level tests prevent offline network path support rows from being displayed as unsupported."))
}

@Test func networkPageSurfacesLowDataAndMeteredPathFlags() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let pathWithFlags = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkPathStatus: "satisfied",
        networkPathIsExpensive: false,
        networkPathIsConstrained: true,
        hasNetworkPathCostReport: true,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let offlinePath = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkPathStatus: "unsatisfied",
        networkPathIsExpensive: false,
        networkPathIsConstrained: false,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(pathWithFlags.networkLowDataModeText == SharedMetricStrings.networkPathEnabled)
    #expect(pathWithFlags.networkMeteredText == SharedMetricStrings.networkPathDisabled)
    #expect(MetricSnapshot.placeholder.networkLowDataModeText == SharedMetricStrings.notReported)
    #expect(offlinePath.networkLowDataModeText == SharedMetricStrings.networkPathUnavailable)
    #expect(offlinePath.networkMeteredText == SharedMetricStrings.networkPathUnavailable)
    #expect(dashboardView.contains("[PulseDockAppStrings.networkLowDataModeLabel, snapshot.networkLowDataModeText, PulseDockAppStrings.networkSystemPathSubtitle]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.networkMeteredLabel, snapshot.networkMeteredText, PulseDockAppStrings.networkSystemPathSubtitle]"))
    #expect(!dashboardView.contains("private func networkPathFlagText"))
    #expect(!dashboardView.contains("networkPathFlagText("))
    #expect(audit.contains("The Network page surfaces low-data-mode and metered-network path flags as explicit rows, not only inside the path detail string."))
    #expect(audit.contains("Source-level tests require the Network page to surface low-data and metered path flags with reported-state handling."))
    #expect(audit.contains("Network path flag display text is centralized on the shared snapshot model."))
    #expect(audit.contains("Source-level tests require Network page low-data and metered labels to come from the shared snapshot model."))
}

@Test func legacyNetworkPathMissingCostFlagsDoesNotInventDisabledPathFlags() throws {
    let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: Data("""
    {
      "cpuUsage": 0.1,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 2048,
      "loadAverage": 0.2,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "networkPathStatus": "satisfied",
      "diskFreeBytes": 1024,
      "timestamp": 0
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.networkPathText == SharedMetricStrings.networkPathStatusOnline)
    #expect(!snapshot.hasNetworkPathCostReport)
    #expect(snapshot.networkLowDataModeText == SharedMetricStrings.notReported)
    #expect(snapshot.networkMeteredText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasNetworkPathCostReport: Bool"))
    #expect(metricSnapshot.contains("guard hasNetworkPathCostReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("if hasNetworkPathCostReport && networkPathIsConstrained"))
    #expect(metricSnapshot.contains("if hasNetworkPathCostReport && networkPathIsExpensive"))
    #expect(sampler.contains("hasCostReport: true"))
    #expect(sampler.contains("hasNetworkPathCostReport: networkPath.hasCostReport"))
    #expect(metricsStore.contains("hasNetworkPathCostReport: snapshot.hasNetworkPathCostReport"))
    #expect(audit.contains("Legacy network path snapshots missing low-data-mode or metered-network flags remain not-reported instead of being displayed as disabled flags."))
    #expect(audit.contains("Source-level tests prevent legacy network path cost flags from inventing disabled low-data-mode or metered-network state."))
}

@Test func networkPageSurfacesAggregateThroughputTrend() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let networkStart = try #require(dashboardView.range(of: "private struct NetworkPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct PowerPage")?.lowerBound)
    let networkPage = String(dashboardView[networkStart..<nextStart])

    #expect(!networkPage.contains("DashboardPanel(title: PulseDockAppStrings.networkTrendTitle"))
    #expect(networkPage.contains("let networkTrend = networkTrendValues(from: history"))
    #expect(networkPage.contains("values: networkTrend"))
    #expect(audit.contains("Network metric cards surface aggregate throughput alongside download, upload, and connection status history."))
    #expect(audit.contains("Source-level tests require Network metric cards to retain aggregate throughput history."))
}

@Test func networkPageTrendPanelSurfacesPathStatusHistory() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let networkStart = try #require(dashboardView.range(of: "private struct NetworkPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct PowerPage")?.lowerBound)
    let networkPage = String(dashboardView[networkStart..<nextStart])

    #expect(networkPage.contains("let networkPathTrend = networkPathTrendValues(from: history)"))
    #expect(networkPage.contains("values: networkPathTrend"))
    #expect(dashboardView.contains("private func networkPathTrendValues(from history: [MetricSnapshot]) -> [Double]"))
    #expect(dashboardView.contains("history.filter(\\.hasNetworkPathReport).map { $0.canonicalNetworkPathState.progress }"))
    #expect(!dashboardView.contains("history.filter { $0.networkPathText != \"未报告\" }.map(networkPathProgress)"))
    #expect(!dashboardView.contains("history.filter(\\.hasNetworkPathReport).map(networkPathProgress)"))
    #expect(audit.contains("Network connection status history is derived from the public network path monitor."))
    #expect(audit.contains("Source-level tests require Network metric cards to retain network path status history."))
}

@Test func minutesFormatterUsesCompactDurations() {
    #expect(MetricFormatting.minutes(0) == "<1m")
    #expect(MetricFormatting.minutes(28) == "28m")
    #expect(MetricFormatting.minutes(318) == "5h 18m")
    #expect(MetricFormatting.minutes(1_540) == "1d 1h")
    #expect(MetricFormatting.duration(42) == "<1m")
}

@Test func displaySnapshotExposesExpectedStrings() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.184,
        hasCPUUsageReport: true,
        memoryUsedBytes: 13_314_867_200,
        memoryTotalBytes: 34_359_738_368,
        memorySwapUsedBytes: 1_073_741_824,
        memorySwapTotalBytes: 2_147_483_648,
        loadAverage: 2.13,
        thermalState: "Nominal",
        batteryPercent: 0.86,
        batteryIsCharging: false,
        networkBytesPerSecond: 5_250_000,
        diskFreeBytes: 334_984_495_104,
        diskTotalBytes: 549_755_813_888,
        uptimeSeconds: 90_061,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(snapshot.cpuText == "18%")
    #expect(snapshot.memoryText == "12.4 GB")
    #expect(snapshot.memoryDetailText == "32.0 GB")
    #expect(snapshot.loadText == "2.1")
    #expect(snapshot.batteryPercentText == "86%")
    #expect(snapshot.networkText == "42 Mbps")
    #expect(snapshot.diskText == SharedMetricStrings.diskAvailableSummary(availableText: "312 GB"))
    #expect(snapshot.memorySwapText == "1.0 GB")
    #expect(snapshot.uptimeText == "1d 1h")
}

@Test func missingLoadAveragesUseReportedStateInsteadOfZeroLoadAcrossSurfaces() throws {
    let missingSnapshot = MetricSnapshot.placeholder
    let reportedZeroSnapshot = try JSONDecoder().decode(MetricSnapshot.self, from: Data("""
    {
      "cpuUsage": 0.1,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 2048,
      "loadAverage": 0,
      "loadAverage5": 0,
      "loadAverage15": 0,
      "hasLoadAverageReport": true,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "diskFreeBytes": 1024,
      "timestamp": 0
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingSnapshot.loadText == SharedMetricStrings.notReported)
    #expect(missingSnapshot.loadDetailText == SharedMetricStrings.notReported)
    #expect(reportedZeroSnapshot.loadText == "0.0")
    #expect(reportedZeroSnapshot.loadDetailText == "0.0 / 0.0 / 0.0")
    #expect(metricSnapshot.contains("public var hasLoadAverageReport: Bool"))
    #expect(metricSnapshot.contains("public var loadAverage5Text: String"))
    #expect(metricSnapshot.contains("guard hasLoadAverageReport else { return SharedMetricStrings.notReported }"))
    #expect(sampler.contains("private func sampleLoadAverages() -> (one: Double, five: Double, fifteen: Double, isReported: Bool)"))
    #expect(sampler.contains("hasLoadAverageReport: loads.isReported"))
    #expect(metricsStore.contains("hasLoadAverageReport: snapshot.hasLoadAverageReport"))
    #expect(dashboardView.contains("value: snapshot.loadText"))
    #expect(dashboardView.contains("value: snapshot.loadAverage5Text"))
    #expect(dashboardView.contains("value: snapshot.loadAverage15Text"))
    #expect(dashboardView.contains("status: snapshot.hasLoadAverageReport ? .normal : .neutral"))
    #expect(!dashboardView.contains("MetricFormatting.load(snapshot.loadAverage)"))
    #expect(!dashboardView.contains("MetricFormatting.load(snapshot.loadAverage5)"))
    #expect(!dashboardView.contains("MetricFormatting.load(snapshot.loadAverage15)"))
    #expect(audit.contains("Load average display text reports the system-not-reported state when getloadavg does not return a sample"))
    #expect(audit.contains("Source-level tests prevent missing load averages from being formatted as 0.0"))
}

@Test func loadProgressRequiresReportedActiveProcessorCount() throws {
    var missingProcessorCount = MetricSnapshot.placeholder
    missingProcessorCount.loadAverage = 2
    missingProcessorCount.loadAverage5 = 1
    missingProcessorCount.loadAverage15 = 0.5
    missingProcessorCount.hasLoadAverageReport = true
    missingProcessorCount.activeProcessorCount = 0

    var reportedProcessorCount = missingProcessorCount
    reportedProcessorCount.activeProcessorCount = 4

    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingProcessorCount.loadAverageProgress == nil)
    #expect(missingProcessorCount.loadAverage5Progress == nil)
    #expect(missingProcessorCount.loadAverage15Progress == nil)
    #expect(reportedProcessorCount.loadAverageProgress == 0.5)
    #expect(reportedProcessorCount.loadAverage5Progress == 0.25)
    #expect(reportedProcessorCount.loadAverage15Progress == 0.125)
    #expect(metricSnapshot.contains("private func reportedLoadProgress(_ value: Double) -> Double?"))
    #expect(metricSnapshot.contains("guard hasLoadAverageReport, activeProcessorCount > 0 else { return nil }"))
    #expect(dashboardView.contains("progress: snapshot.loadAverageProgress"))
    #expect(dashboardView.contains("progress: snapshot.loadAverage5Progress"))
    #expect(dashboardView.contains("progress: snapshot.loadAverage15Progress"))
    #expect(widget.contains("RingMetric(title: PulseDockWidgetStrings.metricLoad, value: snapshot.loadText, progress: snapshot.loadAverageProgress, tint: WidgetColor.green(for: colorScheme))"))
    #expect(!dashboardView.contains("Double(max(snapshot.activeProcessorCount, 1))"))
    #expect(!widget.contains("Double(max(snapshot.activeProcessorCount, 1))"))
    #expect(audit.contains("Current load-average progress requires both reported load averages and a sampled active processor count, so widgets and CPU page bars do not invent a one-core denominator."))
    #expect(audit.contains("Source-level tests require load-average progress in the CPU page and large widget to use shared optional progress instead of `max(activeProcessorCount, 1)`."))
}

@Test func missingCPUBrandUsesReportedStateInsteadOfGenericMacLabel() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var cpuBrandText: String"))
    #expect(metricSnapshot.contains("return SharedMetricStrings.notReported"))
    #expect(dashboardView.contains("(PulseDockAppStrings.cpuProcessorLabel, snapshot.cpuBrandText)"))
    #expect(!dashboardView.contains("snapshot.cpuBrandName ?? \"Mac\""))
    #expect(audit.contains("CPU brand display text reports the system-not-reported state when the sysctl brand string is unavailable"))
    #expect(audit.contains("Source-level tests prevent missing CPU brand strings from being displayed as a generic Mac label"))
}

@Test func missingPrimaryDiskCapacityUsesReportedStateInsteadOfZeroBytes() throws {
    let snapshot = MetricSnapshot.placeholder
    let invalidCapacitySnapshot = MetricSnapshot(
        cpuUsage: 0.1,
        hasCPUUsageReport: true,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        diskFreeBytes: 2_048,
        diskTotalBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 3_600)
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.diskText == SharedMetricStrings.notReported)
    #expect(snapshot.diskUsedText == SharedMetricStrings.notReported)
    #expect(snapshot.hasDiskUsageReport == false)
    #expect(invalidCapacitySnapshot.hasDiskUsageReport == false)
    #expect(invalidCapacitySnapshot.diskText == SharedMetricStrings.notReported)
    #expect(invalidCapacitySnapshot.diskUsageText == SharedMetricStrings.notReported)
    #expect(invalidCapacitySnapshot.diskAvailableText == SharedMetricStrings.notReported)
    #expect(invalidCapacitySnapshot.diskTotalText == SharedMetricStrings.notReported)
    #expect(invalidCapacitySnapshot.diskUsage == 0)
    #expect(metricSnapshot.contains("public var hasDiskUsageReport: Bool"))
    #expect(metricSnapshot.contains("diskTotalBytes > 0 && diskFreeBytes <= diskTotalBytes"))
    #expect(metricSnapshot.contains("guard hasDiskUsageReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("public var diskTotalText: String"))
    #expect(metricSnapshot.contains("public var diskAvailableText: String"))
    #expect(dashboardView.contains("snapshot.diskTotalText"))
    #expect(dashboardView.contains("snapshot.diskAvailableText"))
    #expect(!dashboardView.contains("MetricFormatting.bytes(snapshot.diskTotalBytes)"))
    #expect(!dashboardView.contains("MetricFormatting.compactBytes(snapshot.diskFreeBytes)"))
    #expect(audit.contains("Primary disk display text reports the system-not-reported state when total capacity is unavailable"))
    #expect(audit.contains("Primary disk display text treats impossible free-greater-than-total capacity samples as not-reported"))
    #expect(audit.contains("Source-level tests prevent missing primary disk capacity from being formatted as 0 B"))
    #expect(audit.contains("Source-level tests prevent impossible primary disk capacity samples from being displayed as 0% usage"))
}

@Test func missingStorageVolumeCapacityUsesReportedStateInsteadOfZeroBytes() throws {
    let missingVolume = StorageVolumeMetric(
        index: 0,
        fileSystem: "apfs",
        totalBytes: 0,
        availableBytes: 0,
        importantAvailableBytes: nil,
        isInternal: true,
        isRemovable: false,
        isEjectable: false,
        isPrimary: true
    )
    let invalidCapacityVolume = StorageVolumeMetric(
        index: 1,
        fileSystem: "apfs",
        totalBytes: 1_024,
        availableBytes: 2_048,
        importantAvailableBytes: nil,
        isInternal: true,
        isRemovable: false,
        isEjectable: false,
        isPrimary: false
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingVolume.totalText == SharedMetricStrings.notReported)
    #expect(missingVolume.usedText == SharedMetricStrings.notReported)
    #expect(missingVolume.availableText == SharedMetricStrings.notReported)
    #expect(missingVolume.usageText == SharedMetricStrings.notReported)
    #expect(invalidCapacityVolume.usedBytes == 0)
    #expect(invalidCapacityVolume.usage == 0)
    #expect(invalidCapacityVolume.totalText == SharedMetricStrings.notReported)
    #expect(invalidCapacityVolume.usedText == SharedMetricStrings.notReported)
    #expect(invalidCapacityVolume.availableText == SharedMetricStrings.notReported)
    #expect(invalidCapacityVolume.usageText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var usedBytes: UInt64 {\n        guard hasCapacityReport else { return 0 }"))
    #expect(metricSnapshot.contains("public var usage: Double {\n        guard hasCapacityReport else { return 0 }"))
    #expect(metricSnapshot.contains("public var totalText: String"))
    #expect(metricSnapshot.contains("public var usedText: String"))
    #expect(metricSnapshot.contains("public var availableText: String"))
    #expect(metricSnapshot.contains("public var usageText: String"))
    #expect(dashboardView.contains("volume.totalText"))
    #expect(dashboardView.contains("volume.usedText"))
    #expect(dashboardView.contains("volume.availableText"))
    #expect(dashboardView.contains("volume.usageText"))
    #expect(!dashboardView.contains("MetricFormatting.bytes(volume.totalBytes)"))
    #expect(!dashboardView.contains("MetricFormatting.bytes(volume.usedBytes)"))
    #expect(!dashboardView.contains("MetricFormatting.bytes(volume.importantAvailableBytes ?? volume.availableBytes)"))
    #expect(!dashboardView.contains("MetricFormatting.percentage(volume.usage)"))
    #expect(audit.contains("Per-volume display text reports the system-not-reported state when capacity is unavailable"))
    #expect(audit.contains("Per-volume raw used and usage values use the same capacity reported-state guard as display text."))
    #expect(audit.contains("Source-level tests prevent missing per-volume storage capacity from being formatted as 0 B"))
}

@Test func missingStorageInventoryUsesReportedStateInsteadOfZeroVolumeCountsAcrossSurfaces() throws {
    let reportedSnapshot = try JSONDecoder().decode(MetricSnapshot.self, from: Data("""
    {
      "cpuUsage": 0.1,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 2048,
      "loadAverage": 0.1,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "diskFreeBytes": 1024,
      "diskTotalBytes": 2048,
      "storageVolumes": [
        {
          "index": 0,
          "fileSystem": "apfs",
          "totalBytes": 2048,
          "availableBytes": 1024,
          "isInternal": true,
          "isRemovable": false,
          "isEjectable": false,
          "isPrimary": true
        },
        {
          "index": 1,
          "fileSystem": "exfat",
          "totalBytes": 4096,
          "availableBytes": 2048,
          "isInternal": false,
          "isRemovable": true,
          "isEjectable": true,
          "isPrimary": false
        }
      ],
      "timestamp": 0
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(MetricSnapshot.placeholder.storageVolumes.isEmpty)
    #expect(MetricSnapshot.placeholder.hasStorageVolumeReport == false)
    #expect(reportedSnapshot.storageVolumes.count == 2)
    #expect(reportedSnapshot.hasStorageVolumeReport == true)
    #expect(reportedSnapshot.storageVolumes.filter { !$0.isInternal || $0.isRemovable || $0.isEjectable }.count == 1)
    #expect(metricSnapshot.contains("public var hasStorageVolumeReport: Bool"))
    #expect(metricSnapshot.contains("public var storageVolumeSummaryText: String"))
    #expect(metricSnapshot.contains("public var externalStorageVolumeSummaryText: String"))
    #expect(metricSnapshot.contains("guard hasStorageVolumeReport else { return SharedMetricStrings.notReported }"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.storageCapacityStatsTitle, value: snapshot.storageVolumeSummaryText"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.storageExternalVolumesTitle, value: snapshot.externalStorageVolumeSummaryText"))
    #expect(dashboardView.contains("status: snapshot.hasStorageVolumeReport ? .normal : .neutral"))
    #expect(!dashboardView.contains("value: \"\\(snapshot.storageVolumes.count) 个卷\""))
    #expect(!dashboardView.contains("value: \"\\(externalVolumeCount) 个\""))
    #expect(!dashboardView.contains("private var externalVolumeCount"))
    #expect(widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricVolumes, value: snapshot.storageVolumeSummaryText, tint: reportedTint(hasReport: snapshot.hasStorageVolumeReport, fallback: Palette.blue(for: colorScheme)))"))
    #expect(!widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricVolumes, value: snapshot.storageVolumeSummaryText, tint: reportedTint(valueText: snapshot.storageVolumeSummaryText, fallback: Palette.blue))"))
    #expect(!widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricVolumes, value: \"\\(snapshot.storageVolumes.count)\""))
    #expect(audit.contains("Storage volume count surfaces use shared storage summary text so missing storage inventory is not formatted as 0 volumes"))
    #expect(audit.contains("Storage volume reported state is centralized on the shared snapshot model instead of being inferred from user-facing text."))
    #expect(audit.contains("Source-level tests prevent missing storage inventory from being formatted as 0 volumes on dashboard and menu bar surfaces"))
    #expect(audit.contains("Source-level tests require storage volume reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons."))
}

@Test func legacyStorageVolumeRecordWithoutReportedFieldsDoesNotInventVolumeInventory() throws {
    let legacyVolume = try JSONDecoder().decode(StorageVolumeMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    var snapshot = MetricSnapshot.placeholder
    snapshot.storageVolumes = [legacyVolume]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!legacyVolume.hasInventoryReport)
    #expect(!snapshot.hasStorageVolumeReport)
    #expect(snapshot.storageVolumeSummaryText == SharedMetricStrings.notReported)
    #expect(snapshot.externalStorageVolumeSummaryText == SharedMetricStrings.notReported)
    #expect(snapshot.storageSourceStatusText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasInventoryReport: Bool"))
    #expect(metricSnapshot.contains("storageVolumes.contains(where: \\.hasInventoryReport)"))
    #expect(metricSnapshot.contains("let reportedVolumeCount = storageVolumes.filter(\\.hasInventoryReport).count"))
    #expect(metricSnapshot.contains("let reportedVolumes = storageVolumes.filter(\\.hasInventoryReport)"))
    #expect(dashboardView.contains("snapshot.storageVolumes.filter(\\.hasInventoryReport).prefix(8)"))
    #expect(audit.contains("Legacy storage volume records with no reported fields remain not-reported instead of being counted as mounted volumes."))
    #expect(audit.contains("Source-level tests prevent legacy storage volume records with only an index from inventing mounted-volume inventory."))
}

@Test func missingMemoryCapacityUsesReportedStateInsteadOfZeroBytes() throws {
    let snapshot = MetricSnapshot.placeholder
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.memoryText == SharedMetricStrings.notReported)
    #expect(snapshot.memoryDetailText == SharedMetricStrings.notReported)
    #expect(snapshot.memorySwapText == SharedMetricStrings.notReported)
    #expect(snapshot.hasMemoryUsageReport == false)
    #expect(metricSnapshot.contains("private var hasMemoryCapacityReport: Bool"))
    #expect(metricSnapshot.contains("public var hasMemoryUsageReport: Bool"))
    #expect(metricSnapshot.contains("public var memoryFreeText: String"))
    #expect(metricSnapshot.contains("public var memoryWiredText: String"))
    #expect(metricSnapshot.contains("public var memoryCompressedText: String"))
    #expect(metricSnapshot.contains("public var memoryCachedText: String"))
    #expect(metricSnapshot.contains("public var memoryActiveText: String"))
    #expect(!dashboardView.contains("MetricFormatting.bytes(snapshot.memoryFreeBytes)"))
    #expect(!dashboardView.contains("MetricFormatting.bytes(snapshot.memoryWiredBytes)"))
    #expect(!dashboardView.contains("MetricFormatting.bytes(snapshot.memoryCompressedBytes)"))
    #expect(!dashboardView.contains("MetricFormatting.bytes(snapshot.memoryCachedBytes)"))
    #expect(!dashboardView.contains("MetricFormatting.bytes(activeMemory)"))
    #expect(dashboardView.contains("snapshot.memoryFreeText"))
    #expect(dashboardView.contains("snapshot.memoryWiredText"))
    #expect(dashboardView.contains("snapshot.memoryCompressedText"))
    #expect(dashboardView.contains("snapshot.memoryCachedText"))
    #expect(dashboardView.contains("snapshot.memoryActiveText"))
    #expect(audit.contains("Memory display text reports the system-not-reported state when total memory capacity is unavailable"))
    #expect(audit.contains("Source-level tests prevent missing memory capacity from being formatted as 0 B"))
}

@Test func legacyMemorySnapshotMissingCompositionDoesNotInventZeroByteDetails() throws {
    let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: Data("""
    {
      "cpuUsage": 0.1,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 4096,
      "loadAverage": 0.2,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "diskFreeBytes": 1024,
      "timestamp": 0
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.hasMemoryUsageReport)
    #expect(!snapshot.hasMemoryCompositionReport)
    #expect(snapshot.memoryUsageText == "25%")
    #expect(snapshot.memoryText == "1.0 KB")
    #expect(snapshot.memoryDetailText == "4.0 KB")
    #expect(snapshot.memoryFreeText == SharedMetricStrings.notReported)
    #expect(snapshot.memoryWiredText == SharedMetricStrings.notReported)
    #expect(snapshot.memoryCompressedText == SharedMetricStrings.notReported)
    #expect(snapshot.memoryCachedText == SharedMetricStrings.notReported)
    #expect(snapshot.memoryActiveText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasMemoryCompositionReport: Bool"))
    #expect(metricSnapshot.contains("private func reportedMemoryCompositionText(_ bytes: UInt64) -> String"))
    #expect(metricSnapshot.contains("guard hasMemoryCompositionReport else { return SharedMetricStrings.notReported }"))
    #expect(sampler.contains("hasMemoryCompositionReport: memory.hasCompositionReport"))
    #expect(dashboardView.contains("MetricScales.reportedProgress(hasReport: snapshot.hasMemoryCompositionReport, progress: normalizedBytes(snapshot.memoryActiveBytes, total: snapshot.memoryTotalBytes))"))
    #expect(audit.contains("Legacy memory snapshots missing composition fields keep free, wired, compressed, cached, and active memory as not-reported instead of zero bytes."))
    #expect(audit.contains("Source-level tests prevent legacy memory composition snapshots from inventing zero-byte detail rows."))
}

@Test func memoryActiveBytesDoesNotOverstateWhenCompositionIsInvalid() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_000,
        memoryTotalBytes: 2_000,
        memoryWiredBytes: 700,
        memoryCompressedBytes: 500,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(snapshot.memoryActiveBytes == 0)
}

@Test func memoryActiveBytesRequiresReportedComposition() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_000,
        memoryTotalBytes: 2_000,
        memoryWiredBytes: 100,
        memoryCompressedBytes: 100,
        hasMemoryCompositionReport: false,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(snapshot.memoryActiveBytes == 0)
    #expect(snapshot.memoryActiveText == SharedMetricStrings.notReported)
}

@Test func initializerMemoryCapacityOnlyDoesNotInventZeroByteComposition() throws {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.1,
        hasCPUUsageReport: true,
        memoryUsedBytes: 1024,
        memoryTotalBytes: 4096,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        diskFreeBytes: 1024,
        diskTotalBytes: 4096,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.hasMemoryUsageReport)
    #expect(!snapshot.hasMemoryCompositionReport)
    #expect(snapshot.memoryUsageText == "25%")
    #expect(snapshot.memoryFreeText == SharedMetricStrings.notReported)
    #expect(snapshot.memoryWiredText == SharedMetricStrings.notReported)
    #expect(snapshot.memoryCompressedText == SharedMetricStrings.notReported)
    #expect(snapshot.memoryCachedText == SharedMetricStrings.notReported)
    #expect(snapshot.memoryActiveText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("hasMemoryCompositionReport: Bool = false"))
    #expect(!metricSnapshot.contains("hasMemoryCompositionReport: Bool = true"))
    #expect(audit.contains("MetricSnapshot initializer defaults memory composition to not-reported when only memory capacity and usage are provided."))
    #expect(audit.contains("Source-level tests prevent capacity-only memory snapshots from inventing zero-byte composition details."))
}

@Test func missingUsagePercentagesUseReportedStateInsteadOfZeroPercentAcrossSurfaces() throws {
    let snapshot = MetricSnapshot.placeholder
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.memoryUsageText == SharedMetricStrings.notReported)
    #expect(snapshot.diskUsageText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var memoryUsageText: String"))
    #expect(metricSnapshot.contains("public var diskUsageText: String"))
    #expect(dashboardView.contains("snapshot.memoryUsageText"))
    #expect(dashboardView.contains("snapshot.diskUsageText"))
    #expect(widgetPanel.contains("snapshot.memoryUsageText"))
    #expect(widgetPanel.contains("snapshot.diskUsageText"))
    #expect(widget.contains("snapshot.memoryUsageText"))
    #expect(widget.contains("snapshot.diskUsageText"))
    #expect(!dashboardView.contains("MetricFormatting.percentage(snapshot.memoryUsage)"))
    #expect(!dashboardView.contains("MetricFormatting.percentage(snapshot.diskUsage)"))
    #expect(!widgetPanel.contains("MetricFormatting.percentage(snapshot.memoryUsage)"))
    #expect(!widgetPanel.contains("MetricFormatting.percentage(snapshot.diskUsage)"))
    #expect(!widget.contains("MetricFormatting.percentage(snapshot.memoryUsage)"))
    #expect(!widget.contains("MetricFormatting.percentage(snapshot.diskUsage)"))
    #expect(audit.contains("Memory and disk usage percentage text reports the system-not-reported state when capacity is unavailable"))
    #expect(audit.contains("Source-level tests prevent missing memory or disk usage percentages from being formatted as 0%"))
}

@Test func thresholdSurfacesUseReportedStateInsteadOfNormalWhenUsageIsMissing() throws {
    let snapshot = MetricSnapshot.placeholder
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.memoryUsageText == SharedMetricStrings.notReported)
    #expect(snapshot.diskUsageText == SharedMetricStrings.notReported)
    #expect(dashboardView.contains("private func usageStatusLevel(hasReport: Bool, usage: Double, threshold: Double) -> StatusLevel"))
    #expect(dashboardView.contains("private func thresholdStatusText(hasReport: Bool, usage: Double, threshold: Double, warningText: String) -> String"))
    #expect(!dashboardView.contains("private func usageStatusLevel(valueText: String, usage: Double, threshold: Double) -> StatusLevel"))
    #expect(!dashboardView.contains("private func thresholdStatusText(valueText: String, usage: Double, threshold: Double, warningText: String) -> String"))
    #expect(!dashboardView.contains("guard valueText != \"未报告\" else { return \"未报告\" }"))
    #expect(!dashboardView.contains("guard valueText != \"未报告\" else { return .neutral }"))
    #expect(dashboardView.contains("usageStatusLevel(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold)"))
    #expect(dashboardView.contains("usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold)"))
    #expect(dashboardView.contains("thresholdStatusText(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold, warningText: PulseDockAppStrings.statusWarning)"))
    #expect(dashboardView.contains("thresholdStatusText(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold, warningText: PulseDockAppStrings.statusWarning)"))
    #expect(!dashboardView.contains("PulseDockAppStrings.statusTriggered"))
    #expect(!dashboardView.contains("snapshot.memoryUsage > store.memoryAlertThreshold ? \"注意\" : \"正常\""))
    #expect(!dashboardView.contains("snapshot.diskUsage > store.diskAlertThreshold ? \"注意\" : \"正常\""))
    #expect(!dashboardView.contains("snapshot.memoryUsage > store.memoryAlertThreshold ? \"触发\" : \"正常\""))
    #expect(!dashboardView.contains("snapshot.diskUsage > store.diskAlertThreshold ? \"触发\" : \"正常\""))
    #expect(audit.contains("Threshold status surfaces report missing memory or disk usage as not-reported instead of normal"))
    #expect(audit.contains("Threshold status surfaces use explicit snapshot reported-state flags instead of user-facing text comparisons."))
    #expect(audit.contains("Source-level tests prevent missing threshold usage values from being displayed as normal local rule results"))
}

@Test func statusSummaryNeutralBadgeUsesNotReportedLabelInsteadOfOptional() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("case .neutral: PulseDockAppStrings.notReported"))
    #expect(!dashboardView.contains("case .neutral: \"可选\""))
    #expect(audit.contains("Status summary neutral badges use not-reported wording instead of optional wording, so missing sampled values are not framed as configurable features"))
}

@Test func missingCPUUsageUsesReportedStateInsteadOfZeroPercentAcrossSurfaces() throws {
    let snapshot = MetricSnapshot.placeholder
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.cpuText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasCPUUsageReport: Bool"))
    #expect(metricSnapshot.contains("guard hasCPUUsageReport else { return SharedMetricStrings.notReported }"))
    #expect(sampler.contains("isReported: false"))
    #expect(sampler.contains("isReported: totalTicks > 0"))
    #expect(dashboardView.contains("usageStatusLevel(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold)"))
    #expect(dashboardView.contains("thresholdStatusText(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold, warningText: PulseDockAppStrings.statusWarning)"))
    #expect(!dashboardView.contains("PulseDockAppStrings.statusTriggered"))
    #expect(widget.contains("snapshot.cpuText"))
    #expect(!dashboardView.contains("snapshot.cpuUsage > store.cpuAlertThreshold ? .warning : .normal"))
    #expect(!dashboardView.contains("snapshot.cpuUsage > store.cpuAlertThreshold ? \"注意\" : \"正常\""))
    #expect(!dashboardView.contains("snapshot.cpuUsage > store.cpuAlertThreshold ? \"触发\" : \"正常\""))
    #expect(audit.contains("CPU usage text reports the system-not-reported state when Mach CPU counters have not produced a delta sample"))
    #expect(audit.contains("Source-level tests prevent missing CPU usage from being formatted as 0% or judged as normal"))
}

@Test func initializerCPUValueDoesNotReportUsageWithoutExplicitSampleState() throws {
    let valueOnlySnapshot = MetricSnapshot(
        cpuUsage: 0.42,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0,
        thermalState: "Unknown",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        diskFreeBytes: 0,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(valueOnlySnapshot.cpuText == SharedMetricStrings.notReported)
    #expect(!valueOnlySnapshot.hasCPUUsageReport)
    #expect(metricSnapshot.contains("hasCPUUsageReport: Bool = false"))
    #expect(!metricSnapshot.contains("hasCPUUsageReport: Bool = true"))
    #expect(audit.contains("MetricSnapshot initializer defaults CPU usage to not-reported unless a sampler explicitly reports a Mach CPU delta sample."))
    #expect(audit.contains("Source-level tests prevent value-only snapshots from reporting CPU usage without explicit sample state."))
}

@Test func cpuTrendChartsFilterMissingUsageSamplesInsteadOfPlottingZeroDips() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("private func cpuTrendValues(from history: [MetricSnapshot]) -> [Double]"))
    #expect(dashboardView.contains("history.filter(\\.hasCPUUsageReport).map(\\.cpuUsage)"))
    #expect(dashboardView.contains("let cpuTrend = cpuTrendValues(from: history)"))
    #expect(dashboardView.contains("MetricCard(title: PulseDockAppStrings.overviewCPUUsageTitle, value: snapshot.cpuText, detail: snapshot.logicalCoreSummaryText, icon: \"cpu\", tint: DashboardColor.green, badgeText: snapshot.cpuText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), values: cpuTrend)"))
    #expect(dashboardView.contains("TrendRow(title: \"CPU\", value: snapshot.cpuText, tint: DashboardColor.green, values: cpuTrend)"))
    #expect(dashboardView.contains("Sparkline(values: cpuTrend, tint: DashboardColor.green, fill: true)"))
    #expect(!dashboardView.contains("history.map(\\.cpuUsage)"))
    #expect(audit.contains("CPU trend charts filter out samples whose CPU counters were not reported, so missing samples do not appear as 0% dips"))
}

@Test func capacityAndNetworkTrendChartsFilterMissingSamplesInsteadOfPlottingZeroDips() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("private func memoryTrendValues(from history: [MetricSnapshot]) -> [Double]"))
    #expect(dashboardView.contains("history.filter(\\.hasMemoryUsageReport).map(\\.memoryUsage)"))
    #expect(dashboardView.contains("private func diskTrendValues(from history: [MetricSnapshot]) -> [Double]"))
    #expect(dashboardView.contains("history.filter(\\.hasDiskUsageReport).map(\\.diskUsage)"))
    #expect(dashboardView.contains("private func networkTrendValues(from history: [MetricSnapshot], keyPath: KeyPath<MetricSnapshot, UInt64>) -> [Double]"))
    #expect(dashboardView.contains("history.filter(\\.hasNetworkByteCounters).map { MetricScales.networkRateProgress(bytesPerSecond: $0[keyPath: keyPath]) }"))
    #expect(dashboardView.contains("let memoryTrend = memoryTrendValues(from: history)"))
    #expect(dashboardView.contains("values: memoryTrend"))
    #expect(dashboardView.contains("values: diskTrendValues(from: history)"))
    #expect(dashboardView.contains("let networkTrend = networkTrendValues(from: history)"))
    #expect(dashboardView.contains("values: networkTrend"))
    #expect(dashboardView.contains("let networkDownloadTrend = networkTrendValues(from: history, keyPath: \\.networkInBytesPerSecond)"))
    #expect(dashboardView.contains("values: networkDownloadTrend"))
    #expect(dashboardView.contains("let networkUploadTrend = networkTrendValues(from: history, keyPath: \\.networkOutBytesPerSecond)"))
    #expect(dashboardView.contains("values: networkUploadTrend"))
    #expect(dashboardView.contains("MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkBytesPerSecond)"))
    #expect(!dashboardView.contains("history.map(\\.memoryUsage)"))
    #expect(!dashboardView.contains("history.map(\\.diskUsage)"))
    #expect(!dashboardView.contains("history.map { normalizedRate($0.network"))
    #expect(audit.contains("Memory, disk, and network trend charts filter out samples whose capacity or byte-counter data was not reported, so missing samples do not appear as zero-value dips"))
    #expect(audit.contains("Memory trend charts use the shared memory reported-state flag, so future capacity validation changes stay consistent across text and charts"))
    #expect(audit.contains("Disk trend charts use the shared primary-disk reported-state flag, so impossible capacity samples do not appear as 0% dips"))
}

@Test func currentProgressSurfacesSuppressMissingSamplesInsteadOfDrawingZeroProgress() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!dashboardView.contains("private func reportedProgress(hasReport: Bool, progress: Double) -> Double?"))
    #expect(!dashboardView.contains("private func reportedProgress(valueText: String, progress: Double) -> Double?"))
    #expect(!dashboardView.contains("guard valueText != \"未报告\" else { return nil }"))
    #expect(dashboardView.contains("let progress: Double?"))
    #expect(dashboardView.contains("if let progress {"))
    #expect(dashboardView.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage)"))
    #expect(dashboardView.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage)"))
    #expect(dashboardView.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage)"))
    #expect(dashboardView.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkBytesPerSecond))"))
    #expect(dashboardView.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkInBytesPerSecond))"))
    #expect(dashboardView.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkOutBytesPerSecond))"))
    #expect(dashboardView.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress)"))
    #expect(dashboardView.contains("progress: snapshot.loadAverageProgress"))
    #expect(dashboardView.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkInterfaceReport, progress: activeInterfaceProgress(snapshot))"))
    #expect(dashboardView.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemorySwapReport, progress: snapshot.memorySwapUsage)"))
    #expect(!dashboardView.contains("reportedProgress(valueText:"))
    #expect(dashboardView.contains("CapacityBar(segments: diskCapacitySegments(snapshot))"))
    #expect(dashboardView.contains("private func diskCapacitySegments(_ snapshot: MetricSnapshot) -> [CapacitySegment]"))
    #expect(dashboardView.contains("guard snapshot.hasDiskUsageReport else { return [] }"))
    #expect(dashboardView.contains("if snapshot.hasMemoryUsageReport && snapshot.hasMemoryCompositionReport {"))
    #expect(!widget.contains("private func reportedProgress(hasReport: Bool, progress: Double) -> Double?"))
    #expect(!widget.contains("private func reportedProgress(valueText: String, progress: Double) -> Double?"))
    #expect(widget.contains("RingMetric(title: PulseDockWidgetStrings.metricCPU, value: snapshot.cpuText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: WidgetColor.green(for: colorScheme))"))
    #expect(widget.contains("RingMetric(title: PulseDockWidgetStrings.metricMemory, value: snapshot.memoryUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue(for: colorScheme))"))
    #expect(widget.contains("RingMetric(title: PulseDockWidgetStrings.metricDisk, value: snapshot.diskUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: WidgetColor.amber(for: colorScheme))"))
    #expect(widget.contains("WidgetRow(title: PulseDockWidgetStrings.metricConnection, value: snapshot.networkPathText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress), tint: networkTint(snapshot, for: colorScheme))"))
    #expect(widget.contains("WidgetRow(title: PulseDockWidgetStrings.metricPath, value: snapshot.networkPathCapabilityText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress), tint: WidgetColor.cyan(for: colorScheme))"))
    #expect(!widget.contains("reportedProgress(valueText: snapshot.cpuText"))
    #expect(!widget.contains("reportedProgress(valueText: snapshot.memoryUsageText"))
    #expect(!widget.contains("reportedProgress(valueText: snapshot.diskUsageText"))
    #expect(!widget.contains("reportedProgress(valueText: snapshot.networkPathText"))
    #expect(audit.contains("Current progress bars and gauges in the app and widgets suppress filled progress when the paired live value is not reported, so missing samples do not render as 0% readings"))
    #expect(audit.contains("Memory segment bars use the shared memory composition reported-state flag, so missing detail samples do not render as zero-byte segments"))
    #expect(audit.contains("Disk capacity bars use the shared primary-disk reported-state flag, so impossible capacity samples do not render as fully free storage"))
    #expect(audit.contains("Dashboard progress bars and gauges use explicit snapshot reported-state flags instead of user-facing text comparisons."))
    #expect(audit.contains("Widget progress rings and rows use explicit snapshot reported-state flags instead of user-facing text comparisons."))
}

@Test func menuPopoverProgressSuppressesMissingSamplesInsteadOfDrawingZeroProgress() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!widgetPanel.contains("private func reportedProgress(hasReport: Bool, progress: Double) -> Double?"))
    #expect(!widgetPanel.contains("private func reportedProgress(valueText: String, progress: Double) -> Double?"))
    #expect(!widgetPanel.contains("guard valueText != \"未报告\" else { return nil }"))
    #expect(widgetPanel.contains("PopoverMetricRow(title: \"CPU\", value: snapshot.cpuText, detail: snapshot.logicalCoreSummaryText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: Palette.green(for: colorScheme))"))
    #expect(widgetPanel.contains("PopoverMetricRow(title: PulseDockAppStrings.metricMemory, value: snapshot.memoryUsageText, detail: snapshot.memoryText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: Palette.blue(for: colorScheme))"))
    #expect(widgetPanel.contains("PopoverMetricRow(title: PulseDockAppStrings.metricNetwork, value: snapshot.networkText, detail: \"\\(snapshot.networkPathText) · ↓ \\(snapshot.networkInText)  ↑ \\(snapshot.networkOutText)\", progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkBytesPerSecond)), tint: Palette.cyan(for: colorScheme))"))
    #expect(widgetPanel.contains("PopoverMetricRow(title: PulseDockAppStrings.metricDisk, value: snapshot.diskUsageText, detail: snapshot.diskText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: Palette.amber(for: colorScheme))"))
    #expect(widgetPanel.contains("let progress: Double?"))
    #expect(widgetPanel.contains("if let progress {"))
    #expect(audit.contains("Menu bar popover progress bars suppress filled progress when the paired live value is not reported, so missing samples do not render as 0% readings."))
    #expect(audit.contains("Menu bar popover progress bars use explicit snapshot reported-state flags instead of user-facing text comparisons."))
    #expect(audit.contains("Source-level tests require menu bar popover progress bars to use reported-state progress instead of drawing missing values as zero."))
}

@Test func missingNetworkInterfaceInventoryUsesReportedStateInsteadOfZeroActiveInterfaces() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let reportedLoopbackOnly = MetricSnapshot(
        cpuUsage: 0.3,
        memoryUsedBytes: 4_000,
        memoryTotalBytes: 8_000,
        loadAverage: 1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        hasNetworkByteCounters: true,
        networkInterfaces: [
            NetworkInterfaceMetric(
                index: 1,
                displayName: "Interface 1",
                kind: "Other",
                isUp: true,
                isLoopback: true,
                hasInterfaceStateReport: true,
                bytesReceived: 0,
                bytesSent: 0,
                hasByteCounters: true,
                linkSpeedBitsPerSecond: nil
            )
        ],
        diskFreeBytes: 1_000,
        diskTotalBytes: 2_000,
        timestamp: Date()
    )

    #expect(MetricSnapshot.placeholder.networkInterfaceSummary == SharedMetricStrings.notReported)
    #expect(MetricSnapshot.placeholder.hasNetworkInterfaceReport == false)
    #expect(reportedLoopbackOnly.networkInterfaceSummary == SharedMetricStrings.activeNetworkInterfaceSummary(activeCount: 0))
    #expect(reportedLoopbackOnly.hasNetworkInterfaceReport == true)
    #expect(metricSnapshot.contains("public var hasNetworkInterfaceReport: Bool"))
    #expect(metricSnapshot.contains("guard hasNetworkInterfaceReport else { return SharedMetricStrings.notReported }"))
    #expect(widget.contains("WidgetRow(title: PulseDockWidgetStrings.metricInterface, value: snapshot.networkPathDetailText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress), tint: WidgetColor.cyan(for: colorScheme))"))
    #expect(!widget.contains("private func activeInterfaceProgress(_ snapshot: MetricSnapshot) -> Double"))
    #expect(!widget.contains("Double(snapshot.networkInterfaces.count)"))
    #expect(!widget.contains("Double(activeCount) / 4"))
    #expect(audit.contains("Network interface summary text reports the system-not-reported state when the interface inventory is missing, instead of formatting missing inventory as 0 active interfaces."))
    #expect(audit.contains("Network interface reported state is centralized on the shared snapshot model instead of being inferred from user-facing text."))
    #expect(audit.contains("Widget interface rows use network path detail text so compact timeline snapshots do not need detailed interface inventory rows."))
    #expect(audit.contains("Source-level tests prevent missing network interface inventory from being formatted as 0 active interfaces."))
    #expect(audit.contains("Source-level tests require network interface reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons."))
}

@Test func networkInterfaceTableFiltersUnreportedRowsAndShowsEmptyState() throws {
    let legacyInterface = try JSONDecoder().decode(NetworkInterfaceMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    let reportedStateInterface = NetworkInterfaceMetric(
        index: 1,
        displayName: "Wi-Fi",
        kind: "Wi-Fi",
        isUp: true,
        isLoopback: false,
        hasInterfaceStateReport: true,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let reportedCounterInterface = NetworkInterfaceMetric(
        index: 2,
        displayName: "   ",
        kind: "   ",
        isUp: false,
        isLoopback: false,
        hasInterfaceStateReport: false,
        bytesReceived: 42,
        bytesSent: 0,
        hasByteCounters: true,
        linkSpeedBitsPerSecond: nil
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!legacyInterface.hasInventoryReport)
    #expect(reportedStateInterface.hasInventoryReport)
    #expect(reportedCounterInterface.hasInventoryReport)
    #expect(metricSnapshot.contains("public var hasInventoryReport: Bool"))
    #expect(dashboardView.contains("let reportedInterfaces = snapshot.networkInterfaces.filter(\\.hasInventoryReport)"))
    #expect(dashboardView.contains("emptyText: reportedInterfaces.isEmpty ? PulseDockAppStrings.systemDidNotReport : nil"))
    #expect(dashboardView.contains("TableEmptyRow(text: emptyText)"))
    #expect(dashboardView.contains("rows: reportedInterfaces.prefix(10).map { interface in"))
    #expect(!dashboardView.contains("ForEach(snapshot.networkInterfaces.prefix(10))"))
    #expect(dashboardView.contains("private struct TableEmptyRow"))
    #expect(audit.contains("Network interface detail table filters legacy rows without reported fields and shows an explicit not-reported row instead of an empty table."))
    #expect(audit.contains("Source-level tests require the network interface inventory table to show a not-reported empty row when filtered reported rows are unavailable."))
}

@Test func networkPageSummarySurfacesSampledInterfaceCount() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let networkStart = try #require(dashboardView.range(of: "private struct NetworkPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct PowerPage")?.lowerBound)
    let networkPage = String(dashboardView[networkStart..<nextStart])

    #expect(networkPage.contains("MetricCard(title: PulseDockAppStrings.networkInterfaceTitle, value: snapshot.networkInterfaceSummary"))
    #expect(networkPage.contains("progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkInterfaceReport, progress: activeInterfaceProgress(snapshot))"))
    #expect(dashboardView.contains("private func activeInterfaceProgress(_ snapshot: MetricSnapshot) -> Double"))
    #expect(audit.contains("The Network page summary surfaces sampled active interface count alongside throughput and path state."))
    #expect(audit.contains("Source-level tests require the Network page summary to surface sampled network interface count."))
}

@Test func networkPathTrendFiltersUnknownSamplesWithoutDroppingOfflineStates() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("private func networkPathTrendValues(from history: [MetricSnapshot]) -> [Double]"))
    #expect(dashboardView.contains("history.filter(\\.hasNetworkPathReport).map { $0.canonicalNetworkPathState.progress }"))
    #expect(dashboardView.contains("let networkPathTrend = networkPathTrendValues(from: history)"))
    #expect(dashboardView.contains("values: networkPathTrend"))
    #expect(!dashboardView.contains("history.filter { $0.networkPathText != \"未报告\" }.map(networkPathProgress)"))
    #expect(!dashboardView.contains("values: history.map(networkPathProgress)"))
    #expect(!dashboardView.contains("history.filter(\\.hasNetworkPathReport).map(networkPathProgress)"))
    #expect(audit.contains("Network path trend charts filter out unknown path samples while preserving reported offline states as zero-value status samples"))
    #expect(audit.contains("Network path reported state is centralized on the shared snapshot model instead of being inferred from user-facing text."))
    #expect(audit.contains("Source-level tests require network path reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons."))
}

@Test func networkRuleTablesUseReportedStateInsteadOfWarningWhenPathIsMissing() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    var online = MetricSnapshot.placeholder
    online.networkPathStatus = "satisfied"
    var offline = MetricSnapshot.placeholder
    offline.networkPathStatus = "unsatisfied"
    var requiresConnection = MetricSnapshot.placeholder
    requiresConnection.networkPathStatus = "requiresConnection"

    #expect(MetricSnapshot.placeholder.networkRuleStatusText == SharedMetricStrings.notReported)
    #expect(online.networkRuleStatusText == SharedMetricStrings.networkRuleNormal)
    #expect(offline.networkRuleStatusText == SharedMetricStrings.networkRuleAttention)
    #expect(requiresConnection.networkRuleStatusText == SharedMetricStrings.networkRuleAttention)
    #expect(metricSnapshot.contains("public var networkRuleStatusText: String"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricNetworkConnection, PulseDockAppStrings.statusOnline, snapshot.networkPathText, snapshot.networkRuleStatusText]"))
    #expect(!dashboardView.contains("private func networkRuleStatusText"))
    #expect(!dashboardView.contains("networkRuleStatusText(snapshot)"))
    #expect(!dashboardView.contains("[\"网络连接\", \"在线\", snapshot.networkPathText, isNetworkSatisfied(snapshot) ? \"正常\" : \"注意\"]"))
    #expect(audit.contains("Network local-rule rows report missing path state as not-reported instead of warning, while reported offline or requires-connection states remain warning results"))
    #expect(audit.contains("Network local-rule display text is centralized on the shared snapshot model."))
    #expect(audit.contains("Source-level tests require network local-rule labels to come from the shared snapshot model."))
}

@Test func samplerDoesNotExposeCrossProcessDetailsInAppStoreMode() {
    let snapshot = SystemSampler().sample()

    #expect(snapshot.processCount == 0)
    #expect(snapshot.runningApps.isEmpty)
}

@Test func diskFallbackUsesCurrentUserHomeUrlInsteadOfNSHomeDirectoryString() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(sampler.contains("FileManager.default.homeDirectoryForCurrentUser.path"))
    #expect(!sampler.contains("attributesOfFileSystem(forPath: NSHomeDirectory())"))
}

@Test func storagePrimaryVolumeMatchIsPathComponentSafe() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(sampler.contains("private func path(_ path: String, isInsideMountPath mountPath: String) -> Bool"))
    #expect(sampler.contains("standardizedFileURL.path"))
    #expect(sampler.contains("if normalizedMountPath == \"/\""))
    #expect(sampler.contains("return normalizedPath.hasPrefix(\"/\")"))
    #expect(sampler.contains("normalizedPath == normalizedMountPath || normalizedPath.hasPrefix(normalizedMountPath + \"/\")"))
    #expect(sampler.contains("path(homePath, isInsideMountPath: $0.mountPath)"))
    #expect(!sampler.contains("homePath.hasPrefix($0.mountPath)"))
}

@Test func runningAppInventoryUsesRunningAppsNamingAtAppBoundaries() throws {
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let snapshot = try fixture("Sources/SharedMetrics/MetricSnapshot.swift")
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    #expect(metricsStore.contains("snapshot.runningApps = visibleApplications.prefix(8)"))
    #expect(snapshot.contains("public var runningApps: [ProcessMetric]"))
    #expect(snapshot.contains("case runningApps = \"topProcesses\""))
    #expect(!snapshot.contains("@available(*, deprecated, renamed: \"runningApps\")"))
    #expect(!snapshot.contains("public var topProcesses: [ProcessMetric]"))
    #expect(dashboard.contains("snapshot.runningApps.filter"))
    #expect(!dashboard.contains("snapshot.topProcesses.filter"))
}

@Test func runningAppsUsePublicWorkspaceStateWithoutResourceScanning() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let appStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/PulseDockAppStrings.swift"),
        encoding: .utf8
    )
    let appStringCatalog = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings"),
        encoding: .utf8
    )
    let appEnglishStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings"),
        encoding: .utf8
    )
    let appChineseStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var id: Int { index }"))
    #expect(metricSnapshot.contains("public var index: Int"))
    #expect(metricSnapshot.contains("activationPolicy: String?"))
    #expect(metricSnapshot.contains("isActive: Bool"))
    #expect(metricSnapshot.contains("isHidden: Bool"))
    #expect(metricSnapshot.contains("launchDate: Date?"))
    #expect(metricSnapshot.contains("architecture: String?"))
    #expect(metricSnapshot.contains("public var activeApplicationCount: Int"))
    #expect(metricSnapshot.contains("public var hiddenApplicationCount: Int"))
    #expect(metricSnapshot.contains("public var hasRunningAppReport: Bool"))
    #expect(metricSnapshot.contains("public var runningAppSummaryText: String"))
    #expect(metricSnapshot.contains("public var runningAppCountText: String"))
    #expect(metricSnapshot.contains("public var runningAppListCountText: String"))
    #expect(metricSnapshot.contains("public var activeApplicationCountText: String"))
    #expect(metricSnapshot.contains("public var hiddenApplicationCountText: String"))
    #expect(metricSnapshot.contains("public static func listSubtitle(for processes: [ProcessMetric], defaultSubtitle: String) -> String"))
    let decodedMissingName = try JSONDecoder().decode(ProcessMetric.self, from: Data("""
    {
      "index": 1,
      "isActive": false,
      "isHidden": false
    }
    """.utf8))
    let blankName = ProcessMetric(index: 2, name: "   ")
    let reportedSnapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        processCount: 3,
        activeApplicationCount: 1,
        hiddenApplicationCount: 2,
        runningApps: [
            ProcessMetric(index: 0, name: "Finder"),
            ProcessMetric(index: 1, name: "Safari")
        ],
        timestamp: Date(timeIntervalSince1970: 0)
    )
    #expect(decodedMissingName.name == SharedMetricStrings.notReported)
    #expect(blankName.name == SharedMetricStrings.notReported)
    #expect(MetricSnapshot.placeholder.hasRunningAppReport == false)
    #expect(MetricSnapshot.placeholder.runningAppSummaryText == SharedMetricStrings.notReported)
    #expect(MetricSnapshot.placeholder.runningAppCountText == SharedMetricStrings.notReported)
    #expect(MetricSnapshot.placeholder.runningAppListCountText == SharedMetricStrings.notReported)
    #expect(MetricSnapshot.placeholder.activeApplicationCountText == SharedMetricStrings.notReported)
    #expect(MetricSnapshot.placeholder.hiddenApplicationCountText == SharedMetricStrings.notReported)
    #expect(reportedSnapshot.hasRunningAppReport)
    #expect(reportedSnapshot.runningAppSummaryText == SharedMetricStrings.runningAppSummary(processCount: 3, activeApplicationCount: 1, hiddenApplicationCount: 2))
    #expect(reportedSnapshot.runningAppCountText == "3")
    #expect(reportedSnapshot.runningAppListCountText == "2")
    #expect(reportedSnapshot.activeApplicationCountText == "1")
    #expect(reportedSnapshot.hiddenApplicationCountText == "2")
    #expect(ProcessMetric.listSubtitle(for: [], defaultSubtitle: "前台优先 · 按名称排序") == SharedMetricStrings.notReported)
    #expect(ProcessMetric.listSubtitle(for: reportedSnapshot.runningApps, defaultSubtitle: "前台优先 · 按名称排序") == "前台优先 · 按名称排序")
    #expect(metricsStore.contains("NSWorkspace.shared.runningApplications"))
    #expect(metricsStore.contains("application.isActive"))
    #expect(metricsStore.contains("application.isHidden"))
    #expect(metricsStore.contains("application.launchDate"))
    #expect(metricsStore.contains("application.executableArchitecture"))
    #expect(metricsStore.contains("processArchitectureText(application.executableArchitecture)"))
    #expect(metricsStore.contains("activationPolicyText(application.activationPolicy)"))
    #expect(metricsStore.contains("return PulseDockAppStrings.activationPolicyRegular"))
    #expect(metricsStore.contains("return PulseDockAppStrings.activationPolicyAccessory"))
    #expect(metricsStore.contains("return PulseDockAppStrings.activationPolicyBackground"))
    #expect(metricsStore.contains("return PulseDockAppStrings.systemDidNotReport"))
    #expect(!metricsStore.contains("return \"普通\""))
    #expect(!metricsStore.contains("return \"辅助\""))
    #expect(!metricsStore.contains("return \"后台\""))
    #expect(!metricsStore.contains("return \"系统未报告\""))
    #expect(appStrings.contains("app.running_app.activation.regular"))
    #expect(appStrings.contains("app.system.did_not_report"))
    #expect(appStringCatalog.contains("\"app.running_app.activation.background\""))
    #expect(appStringCatalog.contains("\"value\": \"Background\""))
    #expect(appStringCatalog.contains("\"value\": \"后台\""))
    #expect(appEnglishStrings.contains("\"app.running_app.activation.background\" = \"Background\";"))
    #expect(appChineseStrings.contains("\"app.running_app.activation.background\" = \"后台\";"))
    #expect(metricsStore.contains("reportedApplicationName(application.localizedName)"))
    #expect(metricsStore.contains("return trimmed"))
    #expect(!metricsStore.contains("return trimmed.isEmpty ? \"未报告\" : trimmed"))
    #expect(metricsStore.contains("snapshot.activeApplicationCount = applications.filter(\\.isActive).count"))
    #expect(metricsStore.contains("snapshot.hiddenApplicationCount = applications.filter(\\.isHidden).count"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.processesTableColumns"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.processesTableColumns"))
    #expect(dashboardView.contains("DashboardPanel(title: PulseDockAppStrings.processesRunningAppsTitle, subtitle: ProcessMetric.listSubtitle(for: snapshot.runningApps, defaultSubtitle: PulseDockAppStrings.processesDefaultSubtitle), icon: \"list.bullet.rectangle\")"))
    #expect(dashboardView.contains("defaultSubtitle: PulseDockAppStrings.processesDefaultSubtitle"))
    #expect(!dashboardView.contains("按应用名称排序"))
    #expect(dashboardView.contains("process.stateText"))
    #expect(dashboardView.contains("process.architectureText"))
    #expect(dashboardView.contains("process.launchText"))
    #expect(dashboardView.contains("SummaryCard(title: PulseDockAppStrings.processesRunningAppsTitle, value: snapshot.runningAppCountText, icon: \"app.badge\", tint: DashboardColor.blue)"))
    #expect(dashboardView.contains("SummaryCard(title: PulseDockAppStrings.processesDisplayedAppsTitle, value: snapshot.runningAppListCountText, icon: \"list.bullet.rectangle\", tint: DashboardColor.green)"))
    #expect(dashboardView.contains("SummaryCard(title: PulseDockAppStrings.processesForegroundAppsTitle, value: snapshot.activeApplicationCountText, icon: \"cursorarrow.click\", tint: DashboardColor.amber)"))
    #expect(dashboardView.contains("SummaryCard(title: PulseDockAppStrings.processesHiddenAppsTitle, value: snapshot.hiddenApplicationCountText, icon: \"eye.slash\", tint: DashboardColor.purple)"))
    #expect(!dashboardView.contains("private func processCountText"))
    #expect(!dashboardView.contains("private func processListCountText"))
    #expect(!dashboardView.contains("private func activeApplicationCountText"))
    #expect(!dashboardView.contains("private func hiddenApplicationCountText"))
    #expect(!dashboardView.contains("guard hasRunningAppReport(snapshot) else { return \"未报告\" }"))
    #expect(dashboardView.contains("KeyValueGrid(items: ["))
    #expect(dashboardView.contains("(PulseDockAppStrings.metricRunningApps, snapshot.runningAppCountText)"))
    #expect(dashboardView.contains("ProcessMetric.listSubtitle(for: processes, defaultSubtitle: subtitle)"))
    #expect(dashboardView.contains("ProcessMetric.listSubtitle(for: snapshot.runningApps, defaultSubtitle: PulseDockAppStrings.processesDefaultSubtitle)"))
    #expect(!dashboardView.contains("private func processListSubtitle"))
    #expect(!dashboardView.contains("SummaryCard(title: \"运行中 App\", value: \"\\(snapshot.processCount)\""))
    #expect(!dashboardView.contains("SummaryCard(title: \"前台 App\", value: \"\\(snapshot.activeApplicationCount)\""))
    #expect(!dashboardView.contains("SummaryCard(title: \"隐藏 App\", value: \"\\(snapshot.hiddenApplicationCount)\""))
    #expect(!dashboardView.contains("(\"运行中 App\", \"\\(snapshot.processCount)\")"))
    #expect(!dashboardView.contains("return \"暂无 App 数据\""))
    #expect(!dashboardView.contains("return \"暂无应用列表\""))
    #expect(audit.contains("executable architecture"))
    #expect(audit.contains("active apps first, hidden apps later, then localized app name ordering"))
    #expect(audit.contains("missing or blank running-app names as not-reported instead of a generic app label"))
    #expect(audit.contains("Running-app count surfaces report missing Workspace samples as not-reported instead of displaying zero counts"))
    #expect(audit.contains("Running-app summary display text is centralized on the shared snapshot model."))
    #expect(audit.contains("Source-level tests prevent missing running-app samples from being displayed as zero-count summaries"))
    #expect(audit.contains("Source-level tests require running-app summary labels to come from the shared snapshot model."))
    #expect(!dashboardView.contains("value: \"\\(activeApplicationCount(snapshot.runningApps))\""))
    #expect(!dashboardView.contains("value: \"\\(hiddenApplicationCount(snapshot.runningApps))\""))
    #expect(!metricSnapshot.contains("public var pid"))
    #expect(!metricSnapshot.contains("?? \"App\""))
    #expect(!metricsStore.contains("application.localizedName ?? \"App\""))
    #expect(!metricSnapshot.contains("bundleIdentifier"))
    #expect(!metricsStore.contains("processIdentifier"))
    #expect(!metricsStore.contains("bundleURL"))
    #expect(!metricsStore.contains("executableURL"))
    #expect(!metricsStore.contains("PID \\("))
    #expect(!dashboardView.contains("process.memoryBytes"))
    #expect(!dashboardView.contains("process.cpuTimeSeconds"))
}

@Test func legacyRunningAppListRecordWithoutReportedFieldsDoesNotInventAppListCounts() throws {
    let legacyProcess = try JSONDecoder().decode(ProcessMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    var snapshot = MetricSnapshot.placeholder
    snapshot.runningApps = [legacyProcess]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!legacyProcess.hasInventoryReport)
    #expect(!snapshot.hasRunningAppReport)
    #expect(snapshot.runningAppSummaryText == SharedMetricStrings.notReported)
    #expect(snapshot.runningAppListCountText == SharedMetricStrings.notReported)
    #expect(ProcessMetric.listSubtitle(for: snapshot.runningApps, defaultSubtitle: "前台优先 · 按名称排序") == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasInventoryReport: Bool"))
    #expect(metricSnapshot.contains("runningApps.contains(where: \\.hasInventoryReport)"))
    #expect(metricSnapshot.contains("let reportedListCount = runningApps.filter(\\.hasInventoryReport).count"))
    #expect(dashboardView.contains("ProcessMetric.listSubtitle(for: snapshot.runningApps, defaultSubtitle: PulseDockAppStrings.processesDefaultSubtitle)"))
    #expect(dashboardView.contains("processes.filter(\\.hasInventoryReport).prefix(6)"))
    #expect(dashboardView.contains("snapshot.runningApps.filter(\\.hasInventoryReport)"))
    #expect(audit.contains("Legacy running-app list records with no reported app fields remain not-reported instead of being counted as live app list entries."))
    #expect(audit.contains("Source-level tests prevent legacy running-app list records with only an index from inventing app list counts."))
}

@Test func legacyRunningAppListWithoutCountFieldsDoesNotInventZeroCounts() throws {
    let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: Data("""
    {
      "cpuUsage": 0.1,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 2048,
      "loadAverage": 0.2,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "diskFreeBytes": 1024,
      "topProcesses": [
        {
          "index": 0,
          "name": "Finder",
          "activationPolicy": "regular",
          "isActive": true,
          "isHidden": false
        }
      ],
      "timestamp": 0
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.hasRunningAppReport)
    #expect(!snapshot.hasRunningAppCountReport)
    #expect(snapshot.runningAppSummaryText == SharedMetricStrings.runningAppListOnly(reportedListCount: 1))
    #expect(snapshot.runningAppCountText == SharedMetricStrings.notReported)
    #expect(snapshot.runningAppListCountText == "1")
    #expect(snapshot.activeApplicationCountText == SharedMetricStrings.notReported)
    #expect(snapshot.hiddenApplicationCountText == SharedMetricStrings.notReported)
    #expect(snapshot.runningAppsSourceStatusText == SharedMetricStrings.sourceStatusPartial)
    #expect(metricSnapshot.contains("public var hasRunningAppCountReport: Bool"))
    #expect(metricSnapshot.contains("private var hasReportedRunningAppCounts: Bool"))
    #expect(metricSnapshot.contains("guard hasReportedRunningAppCounts else { return SharedMetricStrings.notReported }"))
    #expect(metricsStore.contains("snapshot.hasRunningAppCountReport = true"))
    #expect(audit.contains("Legacy running-app snapshots with a list but missing count fields keep total, active, and hidden counts as not-reported instead of zero."))
    #expect(audit.contains("Source-level tests prevent legacy running-app list snapshots from inventing zero total, active, or hidden counts."))
}

@Test func runningAppPageUsesSharedProcessDisplayText() throws {
    let launchDate = Date(timeIntervalSince1970: 1_700_000_000)
    let activeProcess = ProcessMetric(
        index: 0,
        name: "Active",
        activationPolicy: "普通",
        isActive: true,
        isHidden: false,
        hasStateReport: true,
        launchDate: launchDate,
        architecture: "Apple Silicon"
    )
    let hiddenProcess = ProcessMetric(
        index: 1,
        name: "Hidden",
        activationPolicy: "普通",
        isActive: false,
        isHidden: true,
        hasStateReport: true,
        architecture: "   "
    )
    let backgroundProcess = ProcessMetric(
        index: 2,
        name: "Background",
        activationPolicy: "后台",
        isActive: false,
        isHidden: false,
        hasStateReport: true,
        architecture: nil
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(activeProcess.stateText == SharedMetricStrings.processStateForeground)
    #expect(hiddenProcess.stateText == SharedMetricStrings.processStateHidden)
    #expect(backgroundProcess.stateText == "后台")
    #expect(ProcessMetric(index: 3, name: "Plain", hasStateReport: true).stateText == SharedMetricStrings.processStateRunning)
    #expect(activeProcess.architectureText == "Apple Silicon")
    #expect(hiddenProcess.architectureText == SharedMetricStrings.systemDidNotReport)
    #expect(backgroundProcess.architectureText == SharedMetricStrings.systemDidNotReport)
    #expect(activeProcess.launchText == launchDate.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))
    #expect(hiddenProcess.launchText == SharedMetricStrings.systemDidNotReport)
    #expect(metricSnapshot.contains("public var stateText: String"))
    #expect(metricSnapshot.contains("public var architectureText: String"))
    #expect(metricSnapshot.contains("public var launchText: String"))
    #expect(dashboardView.contains("process.stateText"))
    #expect(dashboardView.contains("process.architectureText"))
    #expect(dashboardView.contains("process.launchText"))
    #expect(!dashboardView.contains("processStateText(process)"))
    #expect(!dashboardView.contains("processArchitectureText(process.architecture)"))
    #expect(!dashboardView.contains("processLaunchText(process.launchDate)"))
    #expect(!dashboardView.contains("private func processStateText(_ process: ProcessMetric) -> String"))
    #expect(!dashboardView.contains("private func processArchitectureText(_ architecture: String?) -> String"))
    #expect(!dashboardView.contains("private func processLaunchText(_ date: Date?) -> String"))
    #expect(audit.contains("Running-app display text is centralized on the shared process model"))
    #expect(audit.contains("Source-level tests require running-app page labels to come from the shared process model"))
}

@Test func legacyRunningAppMissingStateFieldsDoesNotInventRunningState() throws {
    let decodedProcess = try JSONDecoder().decode(ProcessMetric.self, from: Data("""
    {
      "index": 0,
      "name": "Finder"
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(decodedProcess.stateText == SharedMetricStrings.notReported)
    #expect(ProcessMetric(index: 1, name: "Plain", hasStateReport: true).stateText == SharedMetricStrings.processStateRunning)
    #expect(metricSnapshot.contains("public var hasStateReport: Bool"))
    #expect(metricSnapshot.contains("guard hasStateReport else { return SharedMetricStrings.notReported }"))
    #expect(metricsStore.contains("hasStateReport: true"))
    #expect(audit.contains("Legacy running-app snapshots missing state fields remain not-reported instead of being displayed as running apps."))
    #expect(audit.contains("Source-level tests prevent legacy running-app state fields from inventing running state."))
}

@Test func initializerRunningAppCapabilityOnlyDoesNotInventRunningState() throws {
    let launchDate = Date(timeIntervalSince1970: 1_234)
    let capabilityOnlyProcess = ProcessMetric(
        index: 0,
        name: "Finder",
        launchDate: launchDate,
        architecture: "Apple Silicon"
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(capabilityOnlyProcess.stateText == SharedMetricStrings.notReported)
    #expect(capabilityOnlyProcess.architectureText == "Apple Silicon")
    #expect(capabilityOnlyProcess.launchText == launchDate.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))
    #expect(capabilityOnlyProcess.hasInventoryReport)
    #expect(metricSnapshot.contains("hasStateReport: Bool = false"))
    #expect(!metricSnapshot.contains("hasStateReport: Bool = true"))
    #expect(audit.contains("ProcessMetric initializer defaults running state to not-reported when only public app identity, launch time, or architecture fields are provided."))
    #expect(audit.contains("Source-level tests prevent capability-only running-app snapshots from inventing running state."))
}

@Test func runningAppModelDoesNotKeepZeroedResourcePlaceholders() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let resourcePlaceholders = ["memoryBytes", "threadCount", "cpuTimeSeconds"]

    for field in resourcePlaceholders {
        #expect(!metricSnapshot.contains(field))
        #expect(!metricsStore.contains(field))
        #expect(!sampler.contains(field))
    }
}

@Test func runningAppUIAvoidsProcessIdentifiers() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(!dashboardView.contains("\"PID\""))
    #expect(!dashboardView.contains("process.pid"))
}

@Test func samplerCollectsPublicHardwareInventory() {
    let snapshot = SystemSampler().sample()

    #expect(!snapshot.networkInterfaces.isEmpty)
    #expect(!snapshot.storageVolumes.isEmpty)
    #expect(snapshot.diskTotalBytes > 0)
}

@Test func cpuPageSurfacesPublicActiveProcessorCount() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var activeProcessorCount: Int"))
    #expect(sampler.contains("activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount"))
    #expect(dashboardView.contains("(PulseDockAppStrings.cpuActiveCoresLabel, snapshot.activeProcessorCountText)"))
    #expect(!dashboardView.contains("max(snapshot.activeProcessorCount, 1)"))
    #expect(dashboardView.contains("CoreUsageTile(index: index + 1, value: value, tint: DashboardColor.green)"))
    #expect(!dashboardView.contains("index < snapshot.physicalCoreCount"))
    #expect(!dashboardView.contains("Array(repeating: snapshot.cpuUsage"))
    #expect(!dashboardView.contains("private var coreValues"))
    #expect(dashboardView.contains("if snapshot.cpuCoreUsages.isEmpty"))
    #expect(dashboardView.contains("StatusSummaryRow(title: PulseDockAppStrings.cpuPerCoreSampleTitle, value: PulseDockAppStrings.systemDidNotReport"))
    #expect(audit.contains("active processor count"))
    #expect(audit.contains("Per-core CPU tiles use one color because public per-core samples do not identify physical-core topology"))
    #expect(audit.contains("The CPU page does not synthesize per-core tiles from aggregate CPU usage"))
    #expect(audit.contains("Source-level tests prevent per-core CPU tiles from being synthesized from aggregate CPU usage"))
}

@Test func processorCountTextUsesReportedStateInsteadOfZeroCoreLabels() throws {
    var missingCounts = MetricSnapshot.placeholder
    missingCounts.physicalCoreCount = 0
    missingCounts.logicalCoreCount = 0
    missingCounts.activeProcessorCount = 0

    var reportedCounts = missingCounts
    reportedCounts.physicalCoreCount = 8
    reportedCounts.logicalCoreCount = 10
    reportedCounts.activeProcessorCount = 6

    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingCounts.physicalCoreCountText == SharedMetricStrings.notReported)
    #expect(missingCounts.logicalCoreCountText == SharedMetricStrings.notReported)
    #expect(missingCounts.logicalCoreSummaryText == SharedMetricStrings.notReported)
    #expect(missingCounts.activeProcessorCountText == SharedMetricStrings.notReported)
    #expect(reportedCounts.physicalCoreCountText == "8")
    #expect(reportedCounts.logicalCoreCountText == "10")
    #expect(reportedCounts.logicalCoreSummaryText == SharedMetricStrings.logicalCoreSummary(count: 10))
    #expect(reportedCounts.activeProcessorCountText == "6")
    #expect(metricSnapshot.contains("private static func reportedCountText(_ value: Int) -> String"))
    #expect(metricSnapshot.contains("public var logicalCoreSummaryText: String"))
    #expect(dashboardView.contains("detail: snapshot.logicalCoreSummaryText"))
    #expect(dashboardView.contains("(PulseDockAppStrings.cpuPhysicalCoresLabel, snapshot.physicalCoreCountText)"))
    #expect(dashboardView.contains("(PulseDockAppStrings.cpuLogicalCoresLabel, snapshot.logicalCoreCountText)"))
    #expect(dashboardView.contains("(PulseDockAppStrings.cpuActiveCoresLabel, snapshot.activeProcessorCountText)"))
    #expect(widgetPanel.contains("detail: snapshot.logicalCoreSummaryText"))
    #expect(!dashboardView.contains("detail: \"\\(snapshot.logicalCoreCount) 逻辑核心\""))
    #expect(!dashboardView.contains("(\"物理核心\", \"\\(snapshot.physicalCoreCount)\")"))
    #expect(!dashboardView.contains("(\"逻辑核心\", \"\\(snapshot.logicalCoreCount)\")"))
    #expect(!dashboardView.contains("(\"活动核心\", \"\\(snapshot.activeProcessorCount)\")"))
    #expect(!widgetPanel.contains("detail: \"\\(snapshot.logicalCoreCount) 核心\""))
    #expect(audit.contains("CPU core-count surfaces use shared reported-state text, so placeholder or failed count samples do not appear as zero-core hardware."))
    #expect(audit.contains("Source-level tests require CPU page and menu bar core-count labels to use shared count text instead of interpolating raw integer fields."))
}

@Test func legacySnapshotsDoNotInventProcessorCountsDuringDecode() throws {
    let legacyData = """
    {
      "cpuUsage": 0.25,
      "hasCPUUsageReport": true,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 2048,
      "loadAverage": 0.5,
      "loadAverage5": 0.4,
      "loadAverage15": 0.3,
      "hasLoadAverageReport": true,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "diskFreeBytes": 1024,
      "diskTotalBytes": 2048,
      "timestamp": 0
    }
    """.data(using: .utf8)!
    let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: legacyData)
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.physicalCoreCount == 0)
    #expect(snapshot.logicalCoreCount == 0)
    #expect(snapshot.physicalCoreCountText == SharedMetricStrings.notReported)
    #expect(snapshot.logicalCoreCountText == SharedMetricStrings.notReported)
    #expect(snapshot.logicalCoreSummaryText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("physicalCoreCount = try values.decodeIfPresent(Int.self, forKey: .physicalCoreCount) ?? Self.placeholder.physicalCoreCount"))
    #expect(metricSnapshot.contains("logicalCoreCount = try values.decodeIfPresent(Int.self, forKey: .logicalCoreCount) ?? Self.placeholder.logicalCoreCount"))
    #expect(!metricSnapshot.contains("physicalCoreCount = try values.decodeIfPresent(Int.self, forKey: .physicalCoreCount) ?? ProcessInfo.processInfo.processorCount"))
    #expect(!metricSnapshot.contains("logicalCoreCount = try values.decodeIfPresent(Int.self, forKey: .logicalCoreCount) ?? ProcessInfo.processInfo.activeProcessorCount"))
    #expect(audit.contains("Legacy snapshots missing physical or logical CPU counts remain not-reported instead of borrowing the current machine counts during decode."))
    #expect(audit.contains("Source-level tests prevent legacy decoded snapshots without CPU count fields from inventing physical or logical core counts."))
}

@Test func metricSnapshotDefaultsDoNotInventPhysicalCoreCount() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(snapshot.physicalCoreCount == 0)
    #expect(snapshot.physicalCoreCountText == SharedMetricStrings.notReported)
}

@Test func cpuSamplerDoesNotReportSyntheticZeroCoreUsagesWhilePriming() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(sampler.contains("previousCPUInfo = info\n            return (0, [], isReported: false)"))
    #expect(!sampler.contains("return (0, Array(repeating: 0, count: Int(processorCount)))"))
    #expect(audit.contains("The CPU sampler returns no per-core usage list while it is only priming Mach CPU tick baselines"))
    #expect(audit.contains("Source-level tests prevent CPU baseline priming from reporting synthetic zero-valued per-core samples"))
}

@Test func samplerProducesCodableWidgetSnapshot() throws {
    let sampler = SystemSampler()
    _ = sampler.sample()
    let snapshot = sampler.sample()

    let data = try JSONEncoder().encode(snapshot)

    #expect(!data.isEmpty)
}

@Test func samplerKeepsPrivateHardwareDetailsDisabled() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(!sampler.localizedCaseInsensitiveContains("smc"))
    #expect(!sampler.contains("powermetrics"))
}

@Test func unsupportedSensorFieldsAreNotModeledAsPlaceholders() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let unsupportedPlaceholders = ["temperatureCelsius", "sampleTemperature"]

    for field in unsupportedPlaceholders {
        #expect(!metricSnapshot.contains(field))
        #expect(!sampler.contains(field))
        #expect(!metricsStore.contains(field))
    }
}

@Test func systemUptimeIsLiveDataWithRequiredReasonDeclarations() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let appPrivacyInfo = try String(
        contentsOf: root.appendingPathComponent("Resources/App/PrivacyInfo.xcprivacy"),
        encoding: .utf8
    )
    let widgetPrivacyInfo = try String(
        contentsOf: root.appendingPathComponent("Resources/Widget/PrivacyInfo.xcprivacy"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var uptimeSeconds: TimeInterval"))
    #expect(metricSnapshot.contains("public var uptimeText: String"))
    #expect(sampler.contains("ProcessInfo.processInfo.systemUptime"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricUptime"))
    #expect(dashboardView.contains("StatusSummaryRow(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, status: snapshot.hasUptimeReport ? .normal : .neutral)"))
    #expect(widget.contains("StatTile(title: PulseDockWidgetStrings.metricUptime, value: snapshot.uptimeText"))

    for manifest in [appPrivacyInfo, widgetPrivacyInfo] {
        #expect(manifest.contains("NSPrivacyAccessedAPICategorySystemBootTime"))
        #expect(manifest.contains("35F9.1"))
    }
}

@Test func missingUptimeUsesReportedStateInsteadOfZeroDurationAcrossSurfaces() throws {
    let missingSnapshot = MetricSnapshot.placeholder
    let reportedZeroSnapshot = try JSONDecoder().decode(MetricSnapshot.self, from: Data("""
    {
      "cpuUsage": 0.1,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 2048,
      "loadAverage": 0.1,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "diskFreeBytes": 1024,
      "uptimeSeconds": 0,
      "hasUptimeReport": true,
      "timestamp": 0
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingSnapshot.uptimeText == SharedMetricStrings.notReported)
    #expect(reportedZeroSnapshot.uptimeText == "<1m")
    #expect(metricSnapshot.contains("public var hasUptimeReport: Bool"))
    #expect(metricSnapshot.contains("guard hasUptimeReport else { return SharedMetricStrings.notReported }"))
    #expect(sampler.contains("hasUptimeReport: true"))
    #expect(metricsStore.contains("hasUptimeReport: snapshot.hasUptimeReport"))
    #expect(dashboardView.contains("value: snapshot.uptimeText, status: snapshot.hasUptimeReport ? .normal : .neutral"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, icon: \"timer\", status: snapshot.hasUptimeReport ? .normal : .neutral"))
    #expect(widget.contains("StatTile(title: PulseDockWidgetStrings.metricUptime, value: snapshot.uptimeText"))
    #expect(audit.contains("System uptime display text reports the system-not-reported state when no boot-time sample has been published"))
    #expect(audit.contains("Source-level tests prevent missing uptime from being formatted as 0m"))
}

@Test func systemStatusSurfacesPublicDarwinKernelReleaseWithoutDeviceIdentifiers() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var kernelRelease: String"))
    #expect(metricSnapshot.contains("public var kernelText: String"))
    #expect(sampler.contains("kernelRelease: systemInfo.kernelRelease"))
    #expect(sampler.contains("kernelRelease: sampleKernelRelease()"))
    #expect(sampler.contains("private static func sampleKernelRelease() -> String"))
    #expect(sampler.contains("uname(&systemInfo)"))
    #expect(sampler.contains("stringFromFixedCString(systemInfo.release)"))
    #expect(!sampler.contains("systemInfo.nodename"))
    #expect(!sampler.contains("systemInfo.machine"))
    var reportedKernel = MetricSnapshot.placeholder
    reportedKernel.kernelRelease = "23.0.0"
    #expect(reportedKernel.hasKernelReleaseReport == true)
    #expect(reportedKernel.kernelText == "Darwin 23.0.0")
    #expect(MetricSnapshot.placeholder.hasKernelReleaseReport == false)
    #expect(MetricSnapshot.placeholder.kernelText == SharedMetricStrings.notReported)
    #expect(!dashboardView.contains("private func reportedStatusLevel(valueText: String) -> StatusLevel"))
    #expect(!dashboardView.contains("guard valueText != \"未报告\" else { return .neutral }"))
    #expect(metricSnapshot.contains("public var hasKernelReleaseReport: Bool"))
    #expect(dashboardView.contains("StatusSummaryRow(title: PulseDockAppStrings.metricKernelVersion, value: snapshot.kernelText, status: snapshot.hasKernelReleaseReport ? .normal : .neutral)"))
    #expect(!dashboardView.contains("StatusSummaryRow(title: \"内核版本\", value: snapshot.kernelText, status: reportedStatusLevel(valueText: snapshot.kernelText))"))
    #expect(!dashboardView.contains("StatusSummaryRow(title: \"内核版本\", value: snapshot.kernelText, status: .normal)"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricSystemVersionUptimeKernel, snapshot.systemVersionSourceStatusText, PulseDockAppStrings.sourceSystemVersionBootTime]"))
    #expect(widget.contains("StatTile(title: PulseDockWidgetStrings.metricKernel, value: snapshot.kernelText"))
    #expect(audit.contains("Darwin kernel release"))
    #expect(audit.contains("Kernel version status rows report missing kernel release as not-reported instead of normal."))
    #expect(audit.contains("OS and kernel reported state is centralized on the shared snapshot model instead of being inferred from user-facing text."))
    #expect(audit.contains("Large widgets surface Darwin kernel release"))
    #expect(audit.contains("Source-level tests require kernel version status rows to stay neutral when Darwin release is missing."))
    #expect(audit.contains("Source-level tests require OS and kernel reported-state checks to use explicit snapshot flags instead of user-facing text comparisons."))
}

@Test func operatingSystemVersionSurfacesUseReportedStateInsteadOfGenericFallback() throws {
    let reportedVersion = "Version 14.6 (Build 23G80)"
    let reportedSnapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        osVersion: reportedVersion,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(reportedSnapshot.osVersionText == reportedVersion)
    #expect(reportedSnapshot.hasOSVersionReport == true)
    #expect(MetricSnapshot.placeholder.hasOSVersionReport == false)
    #expect(MetricSnapshot.placeholder.osVersionText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var osVersionText: String"))
    #expect(metricSnapshot.contains("public var hasOSVersionReport: Bool"))
    #expect(sampler.contains("osVersion: ProcessInfo.processInfo.operatingSystemVersionString"))
    #expect(dashboardView.contains("DashboardPanel(title: PulseDockAppStrings.overviewSystemStatusTitle, subtitle: snapshot.osVersionText"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricSystemVersion, value: snapshot.osVersionText, icon: \"desktopcomputer\", status: snapshot.hasOSVersionReport ? .normal : .neutral, source: PulseDockAppStrings.sourceOSVersion)"))
    #expect(!dashboardView.contains("SourceCapabilityCard(title: \"系统版本\", value: snapshot.osVersionText, icon: \"desktopcomputer\", status: reportedStatusLevel(valueText: snapshot.osVersionText), source: \"操作系统版本\")"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricSystemVersionUptimeKernel, snapshot.systemVersionSourceStatusText, PulseDockAppStrings.sourceSystemVersionBootTime]"))
    #expect(metricSnapshot.contains("hasAnyReport: hasOSVersionReport || hasUptimeReport || hasKernelReleaseReport"))
    #expect(!metricSnapshot.contains("let hasOSVersionReport = osVersionText != \"未报告\""))
    #expect(!metricSnapshot.contains("let hasKernelReport = !kernelRelease.isEmpty"))
    #expect(!dashboardView.contains("subtitle: snapshot.osVersion, icon: \"checkmark.seal\""))
    #expect(!dashboardView.contains("[\"系统版本\", snapshot.osVersion, \"操作系统版本\"]"))
    #expect(audit.contains("Operating system version display text reports the system-not-reported state when only a generic placeholder is available."))
    #expect(audit.contains("The Status page and Settings data-source row surface OS version alongside uptime and Darwin kernel release."))
    #expect(audit.contains("Source-level tests require OS version surfaces to use reported-state text instead of the generic macOS fallback."))
}

@Test func legacySnapshotsDoNotInventOperatingSystemVersionDuringDecode() throws {
    let legacyData = """
    {
      "cpuUsage": 0.25,
      "hasCPUUsageReport": true,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 2048,
      "loadAverage": 0.5,
      "loadAverage5": 0.4,
      "loadAverage15": 0.3,
      "hasLoadAverageReport": true,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "diskFreeBytes": 1024,
      "diskTotalBytes": 2048,
      "timestamp": 0
    }
    """.data(using: .utf8)!
    let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: legacyData)
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.hasOSVersionReport == false)
    #expect(snapshot.osVersionText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("osVersion = try values.decodeIfPresent(String.self, forKey: .osVersion) ?? Self.placeholder.osVersion"))
    #expect(!metricSnapshot.contains("osVersion = try values.decodeIfPresent(String.self, forKey: .osVersion) ?? ProcessInfo.processInfo.operatingSystemVersionString"))
    #expect(audit.contains("Legacy snapshots missing operating system version remain not-reported instead of borrowing the current machine OS version during decode."))
    #expect(audit.contains("Source-level tests prevent legacy decoded snapshots without OS version fields from inventing the current system version."))
}

@Test func gpuInventoryDoesNotStoreRawRegistryIdentifiers() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var id: Int { index }"))
    #expect(metricSnapshot.contains("public var index: Int"))
    #expect(!metricSnapshot.contains("registryID"))
    #expect(!sampler.contains("device.registryID"))
}

@Test func gpuInventorySurfacesPublicThreadgroupCapabilities() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var maxThreadgroupMemoryLength: Int"))
    #expect(metricSnapshot.contains("public var maxThreadsPerThreadgroupWidth: Int"))
    #expect(metricSnapshot.contains("public var maxThreadsPerThreadgroupHeight: Int"))
    #expect(metricSnapshot.contains("public var maxThreadsPerThreadgroupDepth: Int"))
    #expect(metricSnapshot.contains("public var threadgroupMemoryText: String"))
    #expect(metricSnapshot.contains("public var threadgroupSizeText: String"))
    #expect(sampler.contains("let maxThreadsPerThreadgroup = device.maxThreadsPerThreadgroup"))
    #expect(sampler.contains("maxThreadgroupMemoryLength: device.maxThreadgroupMemoryLength"))
    #expect(dashboardView.contains("device.threadgroupMemoryText"))
    #expect(dashboardView.contains("device.threadgroupSizeText"))
}

@Test func gpuPageUsesSharedDeviceCapabilityText() throws {
    let removableDevice = GPUDeviceMetric(
        index: 0,
        name: "External GPU",
        isLowPower: false,
        isRemovable: true,
        isHeadless: true,
        hasUnifiedMemory: false,
        recommendedMaxWorkingSetBytes: 0,
        hasDeviceKindReport: true,
        hasUnifiedMemoryReport: true,
        hasDisplayRoleReport: true
    )
    let lowPowerDevice = GPUDeviceMetric(
        index: 1,
        name: "Integrated GPU",
        isLowPower: true,
        isRemovable: false,
        isHeadless: false,
        hasUnifiedMemory: true,
        recommendedMaxWorkingSetBytes: 2_097_152,
        maxThreadgroupMemoryLength: 32_768,
        maxThreadsPerThreadgroupWidth: 32,
        maxThreadsPerThreadgroupHeight: 16,
        maxThreadsPerThreadgroupDepth: 4,
        hasDeviceKindReport: true,
        hasUnifiedMemoryReport: true,
        hasDisplayRoleReport: true
    )
    let highPerformanceDevice = GPUDeviceMetric(
        index: 2,
        name: "Discrete GPU",
        isLowPower: false,
        isRemovable: false,
        isHeadless: false,
        hasUnifiedMemory: false,
        recommendedMaxWorkingSetBytes: 0,
        hasDeviceKindReport: true,
        hasUnifiedMemoryReport: true,
        hasDisplayRoleReport: true
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sharedStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SharedMetricStrings.swift"),
        encoding: .utf8
    )
    let english = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )
    let chinese = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let expectedEntries = [
        (symbol: "gpuKindExternal", key: "shared_metrics.gpu.kind.external", english: "External", chinese: "外置"),
        (symbol: "gpuKindLowPower", key: "shared_metrics.gpu.kind.low_power", english: "Low Power", chinese: "低功耗"),
        (symbol: "gpuKindHighPerformance", key: "shared_metrics.gpu.kind.high_performance", english: "High Performance", chinese: "高性能"),
        (symbol: "booleanYes", key: "shared_metrics.boolean.yes", english: "Yes", chinese: "是"),
        (symbol: "booleanNo", key: "shared_metrics.boolean.no", english: "No", chinese: "否"),
        (symbol: "gpuRoleCompute", key: "shared_metrics.gpu.role.compute", english: "Compute", chinese: "计算"),
        (symbol: "gpuRoleDisplay", key: "shared_metrics.gpu.role.display", english: "Display", chinese: "显示")
    ]

    for entry in expectedEntries {
        #expect(sharedStrings.contains("static var \(entry.symbol): String"))
        #expect(sharedStrings.contains("localized(\"\(entry.key)\", defaultValue: \"\(entry.english)\")"))
        #expect(english.contains("\"\(entry.key)\" = \"\(entry.english)\";"))
        #expect(chinese.contains("\"\(entry.key)\" = \"\(entry.chinese)\";"))
        #expect(metricSnapshot.contains("SharedMetricStrings.\(entry.symbol)"))
    }

    #expect(removableDevice.kindText == SharedMetricStrings.gpuKindExternal)
    #expect(lowPowerDevice.kindText == SharedMetricStrings.gpuKindLowPower)
    #expect(highPerformanceDevice.kindText == SharedMetricStrings.gpuKindHighPerformance)
    #expect(lowPowerDevice.unifiedMemoryText == SharedMetricStrings.booleanYes)
    #expect(highPerformanceDevice.unifiedMemoryText == SharedMetricStrings.booleanNo)
    #expect(removableDevice.recommendedWorkingSetText == SharedMetricStrings.notReported)
    #expect(lowPowerDevice.recommendedWorkingSetText == "2.0 MB")
    #expect(removableDevice.threadgroupMemoryText == SharedMetricStrings.notReported)
    #expect(lowPowerDevice.threadgroupMemoryText == "32.0 KB")
    #expect(removableDevice.threadgroupSizeText == SharedMetricStrings.notReported)
    #expect(lowPowerDevice.threadgroupSizeText == "32x16x4")
    #expect(removableDevice.stateText == SharedMetricStrings.gpuRoleCompute)
    #expect(lowPowerDevice.stateText == SharedMetricStrings.gpuRoleDisplay)
    #expect(metricSnapshot.contains("public var isLowPower: Bool"))
    #expect(metricSnapshot.contains("public var isRemovable: Bool"))
    #expect(metricSnapshot.contains("public var kindText: String"))
    #expect(metricSnapshot.contains("public var unifiedMemoryText: String"))
    #expect(metricSnapshot.contains("public var recommendedWorkingSetText: String"))
    #expect(metricSnapshot.contains("public var threadgroupMemoryText: String"))
    #expect(metricSnapshot.contains("public var threadgroupSizeText: String"))
    #expect(metricSnapshot.contains("public var stateText: String"))
    #expect(sampler.contains("isLowPower: device.isLowPower"))
    #expect(sampler.contains("isRemovable: device.isRemovable"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.gpuDeviceTableColumns"))
    #expect(dashboardView.contains("device.kindText"))
    #expect(dashboardView.contains("device.unifiedMemoryText"))
    #expect(dashboardView.contains("device.recommendedWorkingSetText"))
    #expect(dashboardView.contains("device.threadgroupMemoryText"))
    #expect(dashboardView.contains("device.threadgroupSizeText"))
    #expect(dashboardView.contains("device.stateText"))
    #expect(!dashboardView.contains("gpuKindText(device)"))
    #expect(!dashboardView.contains("gpuThreadgroupMemoryText(device)"))
    #expect(!dashboardView.contains("gpuThreadgroupSizeText(device)"))
    #expect(!dashboardView.contains("private func gpuKindText(_ device: GPUDeviceMetric) -> String"))
    #expect(!dashboardView.contains("private func gpuThreadgroupMemoryText(_ device: GPUDeviceMetric) -> String"))
    #expect(!dashboardView.contains("private func gpuThreadgroupSizeText(_ device: GPUDeviceMetric) -> String"))
    #expect(!dashboardView.contains("device.hasUnifiedMemory ? \"是\" : \"否\""))
    #expect(!dashboardView.contains("device.recommendedMaxWorkingSetBytes > 0 ? MetricFormatting.bytes(device.recommendedMaxWorkingSetBytes) : \"未报告\""))
    #expect(!dashboardView.contains("device.isHeadless ? \"计算\" : \"显示\""))
    #expect(audit.contains("GPU device capability display text is centralized on the shared GPU model"))
    #expect(audit.contains("Source-level tests require GPU page capability labels to come from the shared model"))
    #expect(audit.contains("low-power/removable GPU capability"))
    #expect(audit.contains("public Metal threadgroup limits"))
}

@Test func legacyGPUDeviceMissingCapabilityFlagsDoesNotInventHighPerformanceDisplayState() throws {
    let decodedDevice = try JSONDecoder().decode(GPUDeviceMetric.self, from: Data("""
    {
      "index": 0,
      "name": "Apple GPU"
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(decodedDevice.kindText == SharedMetricStrings.notReported)
    #expect(decodedDevice.unifiedMemoryText == SharedMetricStrings.notReported)
    #expect(decodedDevice.stateText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasDeviceKindReport: Bool"))
    #expect(metricSnapshot.contains("public var hasUnifiedMemoryReport: Bool"))
    #expect(metricSnapshot.contains("public var hasDisplayRoleReport: Bool"))
    #expect(metricSnapshot.contains("guard hasDeviceKindReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("guard hasUnifiedMemoryReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("guard hasDisplayRoleReport else { return SharedMetricStrings.notReported }"))
    #expect(sampler.contains("hasDeviceKindReport: true"))
    #expect(sampler.contains("hasUnifiedMemoryReport: true"))
    #expect(sampler.contains("hasDisplayRoleReport: true"))
    #expect(audit.contains("Legacy GPU device snapshots missing capability flags remain not-reported instead of being displayed as high-performance, non-unified-memory display GPUs."))
    #expect(audit.contains("Source-level tests prevent legacy GPU capability flags from inventing high-performance display state."))
}

@Test func initializerGPUCapabilityOnlyDoesNotInventKindUnifiedMemoryOrDisplayRole() throws {
    let capabilityOnlyDevice = GPUDeviceMetric(
        index: 0,
        name: "Apple GPU",
        isLowPower: false,
        isRemovable: false,
        isHeadless: false,
        hasUnifiedMemory: false,
        recommendedMaxWorkingSetBytes: 1_024,
        maxThreadgroupMemoryLength: 32_768,
        maxThreadsPerThreadgroupWidth: 32,
        maxThreadsPerThreadgroupHeight: 16,
        maxThreadsPerThreadgroupDepth: 4
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(capabilityOnlyDevice.recommendedWorkingSetText == "1.0 KB")
    #expect(capabilityOnlyDevice.threadgroupMemoryText == "32.0 KB")
    #expect(capabilityOnlyDevice.threadgroupSizeText == "32x16x4")
    #expect(capabilityOnlyDevice.kindText == SharedMetricStrings.notReported)
    #expect(capabilityOnlyDevice.unifiedMemoryText == SharedMetricStrings.notReported)
    #expect(capabilityOnlyDevice.stateText == SharedMetricStrings.notReported)
    #expect(capabilityOnlyDevice.hasInventoryReport)
    #expect(metricSnapshot.contains("hasDeviceKindReport: Bool = false"))
    #expect(metricSnapshot.contains("hasUnifiedMemoryReport: Bool = false"))
    #expect(metricSnapshot.contains("hasDisplayRoleReport: Bool = false"))
    #expect(!metricSnapshot.contains("hasDeviceKindReport: Bool = true"))
    #expect(!metricSnapshot.contains("hasUnifiedMemoryReport: Bool = true"))
    #expect(!metricSnapshot.contains("hasDisplayRoleReport: Bool = true"))
    #expect(audit.contains("GPUDeviceMetric initializer defaults kind, unified-memory, and display-role state to not-reported when only public capability limits are provided."))
    #expect(audit.contains("Source-level tests prevent capability-only GPU snapshots from inventing high-performance, non-unified-memory display state."))
}

@Test func gpuPageUnifiedMemorySummaryDoesNotInventUnsupportedStateForLegacyDevices() throws {
    let legacyDevice = try JSONDecoder().decode(GPUDeviceMetric.self, from: Data("""
    {
      "index": 0,
      "name": "Apple GPU",
      "recommendedMaxWorkingSetBytes": 1024
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!legacyDevice.hasUnifiedMemoryReport)
    #expect(legacyDevice.unifiedMemoryText == SharedMetricStrings.notReported)
    #expect(dashboardView.contains("let reportedDevices = reportedUnifiedMemoryDevices"))
    #expect(dashboardView.contains("private var reportedUnifiedMemoryDevices: [GPUDeviceMetric]"))
    #expect(dashboardView.contains("snapshot.gpuDevices.filter(\\.hasUnifiedMemoryReport)"))
    #expect(dashboardView.contains("guard !reportedDevices.isEmpty else { return PulseDockAppStrings.notReported }"))
    #expect(dashboardView.contains("let unifiedCount = reportedDevices.filter(\\.hasUnifiedMemory).count"))
    #expect(dashboardView.contains("return unifiedCount == reportedDevices.count ? PulseDockAppStrings.statusSupported : \"\\(unifiedCount)/\\(reportedDevices.count)\""))
    #expect(!dashboardView.contains("let unifiedCount = snapshot.gpuDevices.filter(\\.hasUnifiedMemory).count"))
    #expect(audit.contains("GPU unified-memory summary ignores legacy devices whose unified-memory capability was not reported instead of counting them as unsupported."))
    #expect(audit.contains("Source-level tests prevent GPU unified-memory summary counts from treating missing unified-memory flags as unsupported GPUs."))
}

@Test func missingGPUInventoryUsesReportedStateInsteadOfUndetectedHardwareAcrossSurfaces() throws {
    let decodedMissingName = try JSONDecoder().decode(GPUDeviceMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    let blankName = GPUDeviceMetric(
        index: 1,
        name: "   ",
        isLowPower: false,
        isRemovable: false,
        isHeadless: false,
        hasUnifiedMemory: false,
        recommendedMaxWorkingSetBytes: 0
    )
    let legacyGenericName = GPUDeviceMetric(
        index: 2,
        name: "GPU",
        isLowPower: false,
        isRemovable: false,
        isHeadless: false,
        hasUnifiedMemory: false,
        recommendedMaxWorkingSetBytes: 0
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(decodedMissingName.name == SharedMetricStrings.notReported)
    #expect(blankName.name == SharedMetricStrings.notReported)
    #expect(legacyGenericName.name == SharedMetricStrings.notReported)
    #expect(MetricSnapshot.placeholder.primaryGPUName == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("private static func reportedGPUName(_ name: String?) -> String"))
    #expect(metricSnapshot.contains("name = Self.reportedGPUName(try values.decodeIfPresent(String.self, forKey: .name))"))
    #expect(!metricSnapshot.contains("name = try values.decodeIfPresent(String.self, forKey: .name) ?? \"GPU\""))
    #expect(metricSnapshot.contains("public var gpuSummaryText: String"))
    #expect(metricSnapshot.contains("public var hasGPUReport: Bool"))
    #expect(metricSnapshot.contains("public var gpuDisplaySummaryText: String"))
    #expect(metricSnapshot.contains("public var hasGPUDisplayReport: Bool"))
    #expect(metricSnapshot.contains("guard reportedGPUCount > 0 else { return SharedMetricStrings.notReported }"))
    #expect(!metricSnapshot.contains("\"未检测到 Metal GPU\""))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricGPU, value: snapshot.gpuSummaryText, icon: \"sparkles.rectangle.stack\", status: snapshot.hasGPUReport ? .normal : .neutral"))
    #expect(!dashboardView.contains("private func gpuDisplaySummaryText"))
    #expect(!dashboardView.contains("private func gpuDisplayStatus"))
    #expect(!dashboardView.contains("snapshot.gpuDevices.isEmpty ? \"未检测\""))
    #expect(!dashboardView.contains("snapshot.gpuDevices.isEmpty ? .warning"))
    #expect(audit.contains("GPU inventory display text reports the system-not-reported state when Metal does not return a device list"))
    #expect(audit.contains("GPU/display combined summary text is centralized on the shared snapshot model."))
    #expect(audit.contains("Missing or legacy generic GPU names are displayed as not-reported instead of a generic device label"))
    #expect(audit.contains("Source-level tests prevent missing GPU inventory from being displayed as undetected hardware or warning-state data"))
    #expect(audit.contains("Source-level tests require Overview GPU/display summary labels to come from the shared snapshot model."))
    #expect(audit.contains("Source-level tests prevent missing GPU device names from surfacing as a generic GPU label"))
}

@Test func legacyGPUInventoryWithoutReportedDeviceFieldsDoesNotInventDeviceCountsAcrossSurfaces() throws {
    let legacyDevice = try JSONDecoder().decode(GPUDeviceMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    var snapshot = MetricSnapshot.placeholder
    snapshot.gpuDevices = [legacyDevice]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.gpuSummaryText == SharedMetricStrings.notReported)
    #expect(snapshot.gpuDisplaySummaryText == SharedMetricStrings.gpuDisplaySummary(
        gpuText: SharedMetricStrings.gpuNotReportedSummary,
        displayText: SharedMetricStrings.displayNotReportedSummary
    ))
    #expect(!snapshot.hasGPUDisplayReport)
    #expect(metricSnapshot.contains("public var hasGPUReport: Bool"))
    #expect(metricSnapshot.contains("gpuDevices.contains(where: \\.hasInventoryReport)"))
    #expect(metricSnapshot.contains("let reportedGPUCount = gpuDevices.filter(\\.hasInventoryReport).count"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricGPU, value: snapshot.gpuSummaryText, icon: \"sparkles.rectangle.stack\", status: snapshot.hasGPUReport ? .normal : .neutral"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricGPU, value: snapshot.gpuSummaryText, icon: \"sparkles.rectangle.stack\", status: snapshot.hasGPUReport ? .normal : .neutral, source: PulseDockAppStrings.sourceGraphicsDevices)"))
    #expect(audit.contains("Legacy GPU inventory records with no reported device fields remain not-reported instead of being counted as live GPU devices."))
    #expect(audit.contains("Source-level tests prevent legacy GPU inventory records with only an index from inventing GPU device counts."))
}

@Test func gpuDisplayPageFiltersLegacyInventoryRowsWithoutReportedFields() throws {
    let legacyDevice = try JSONDecoder().decode(GPUDeviceMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    let legacyDisplay = try JSONDecoder().decode(DisplayMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    var snapshot = MetricSnapshot.placeholder
    snapshot.gpuDevices = [legacyDevice]
    snapshot.displays = [legacyDisplay]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!legacyDevice.hasInventoryReport)
    #expect(!legacyDisplay.hasInventoryReport)
    #expect(!snapshot.hasGPUReport)
    #expect(!snapshot.hasDisplayReport)
    #expect(dashboardView.contains("rows: snapshot.gpuDevices.filter(\\.hasInventoryReport).map { device in"))
    #expect(dashboardView.contains("rows: snapshot.displays.filter(\\.hasInventoryReport).map { display in"))
    #expect(!dashboardView.contains("ForEach(snapshot.gpuDevices) { device in"))
    #expect(!dashboardView.contains("ForEach(snapshot.displays) { display in"))
    #expect(audit.contains("GPU/Display detail tables filter legacy inventory rows without reported fields instead of rendering empty not-reported rows."))
    #expect(audit.contains("Source-level tests require GPU and display detail tables to filter by reported inventory state."))
}

@Test func settingsDataSourceRowsUseSnapshotReportedStateInsteadOfHardcodedAvailability() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    var partialCPUAndMemory = MetricSnapshot.placeholder
    partialCPUAndMemory.hasCPUUsageReport = true
    var fullCPUAndMemory = partialCPUAndMemory
    fullCPUAndMemory.logicalCoreCount = 8
    fullCPUAndMemory.memoryTotalBytes = 8_192

    var partialNetwork = MetricSnapshot.placeholder
    partialNetwork.networkPathStatus = "satisfied"
    var fullNetwork = partialNetwork
    fullNetwork.hasNetworkByteCounters = true

    var partialApps = MetricSnapshot.placeholder
    partialApps.runningApps = [ProcessMetric(index: 0, name: "Finder")]
    var fullApps = partialApps
    fullApps.processCount = 1
    fullApps.activeApplicationCount = 1
    fullApps.hiddenApplicationCount = 0
    fullApps.hasRunningAppCountReport = true

    var partialGPUDisplay = MetricSnapshot.placeholder
    partialGPUDisplay.gpuDevices = [GPUDeviceMetric(index: 0, name: "Apple GPU", isLowPower: false, isRemovable: false, isHeadless: false, hasUnifiedMemory: true, recommendedMaxWorkingSetBytes: 1024)]
    var fullGPUDisplay = partialGPUDisplay
    fullGPUDisplay.displays = [DisplayMetric(index: 0, name: "Built-in Display", pixelWidth: 1920, pixelHeight: 1200, modeWidth: 1920, modeHeight: 1200, refreshRate: 60, isBuiltin: true, isMain: true, isMirrored: false, rotationDegrees: 0)]

    var partialStorage = MetricSnapshot.placeholder
    partialStorage.diskTotalBytes = 4_096
    var fullStorage = partialStorage
    fullStorage.storageVolumes = [StorageVolumeMetric(index: 0, fileSystem: "apfs", totalBytes: 4_096, availableBytes: 2_048, importantAvailableBytes: nil, isInternal: true, isRemovable: false, isEjectable: false, isPrimary: true)]

    var partialPowerThermal = MetricSnapshot.placeholder
    partialPowerThermal.batteryPowerSource = "AC Power"
    var fullPowerThermal = partialPowerThermal
    fullPowerThermal.thermalState = "nominal"

    var partialSystemVersion = MetricSnapshot.placeholder
    partialSystemVersion.kernelRelease = "23.0.0"
    var fullSystemVersion = partialSystemVersion
    fullSystemVersion.osVersion = "macOS 15.0"
    fullSystemVersion.hasUptimeReport = true

    #expect(MetricSnapshot.placeholder.cpuMemorySourceStatusText == SharedMetricStrings.notReported)
    #expect(partialCPUAndMemory.cpuMemorySourceStatusText == SharedMetricStrings.sourceStatusPartial)
    #expect(fullCPUAndMemory.cpuMemorySourceStatusText == SharedMetricStrings.sourceStatusReported)
    #expect(MetricSnapshot.placeholder.networkSourceStatusText == SharedMetricStrings.notReported)
    #expect(partialNetwork.networkSourceStatusText == SharedMetricStrings.sourceStatusPartial)
    #expect(fullNetwork.networkSourceStatusText == SharedMetricStrings.sourceStatusReported)
    #expect(MetricSnapshot.placeholder.runningAppsSourceStatusText == SharedMetricStrings.notReported)
    #expect(partialApps.runningAppsSourceStatusText == SharedMetricStrings.sourceStatusPartial)
    #expect(fullApps.runningAppsSourceStatusText == SharedMetricStrings.sourceStatusReported)
    #expect(MetricSnapshot.placeholder.gpuDisplaySourceStatusText == SharedMetricStrings.notReported)
    #expect(partialGPUDisplay.gpuDisplaySourceStatusText == SharedMetricStrings.sourceStatusPartial)
    #expect(fullGPUDisplay.gpuDisplaySourceStatusText == SharedMetricStrings.sourceStatusReported)
    #expect(MetricSnapshot.placeholder.storageSourceStatusText == SharedMetricStrings.notReported)
    #expect(partialStorage.storageSourceStatusText == SharedMetricStrings.sourceStatusPartial)
    #expect(fullStorage.storageSourceStatusText == SharedMetricStrings.sourceStatusReported)
    #expect(MetricSnapshot.placeholder.powerThermalSourceStatusText == SharedMetricStrings.notReported)
    #expect(partialPowerThermal.powerThermalSourceStatusText == SharedMetricStrings.sourceStatusPartial)
    #expect(fullPowerThermal.powerThermalSourceStatusText == SharedMetricStrings.sourceStatusReported)
    #expect(MetricSnapshot.placeholder.systemVersionSourceStatusText == SharedMetricStrings.notReported)
    #expect(partialSystemVersion.systemVersionSourceStatusText == SharedMetricStrings.sourceStatusPartial)
    #expect(fullSystemVersion.systemVersionSourceStatusText == SharedMetricStrings.sourceStatusReported)
    #expect(metricSnapshot.contains("private func sourceStatusText(hasAnyReport: Bool, hasFullReport: Bool) -> String"))
    #expect(metricSnapshot.contains("public var cpuMemorySourceStatusText: String"))
    #expect(metricSnapshot.contains("hasAnyReport: hasCPUUsageReport || logicalCoreCount > 0 || hasMemoryUsageReport"))
    #expect(metricSnapshot.contains("hasFullReport: hasCPUUsageReport && logicalCoreCount > 0 && hasMemoryUsageReport"))
    #expect(metricSnapshot.contains("public var hasNetworkPathReport: Bool"))
    #expect(metricSnapshot.contains("public var networkSourceStatusText: String"))
    #expect(metricSnapshot.contains("let hasPathReport = hasNetworkPathReport"))
    #expect(!metricSnapshot.contains("networkPathText != \"未报告\""))
    #expect(metricSnapshot.contains("public var runningAppsSourceStatusText: String"))
    #expect(metricSnapshot.contains("public var gpuDisplaySourceStatusText: String"))
    #expect(metricSnapshot.contains("public var storageSourceStatusText: String"))
    #expect(metricSnapshot.contains("public var powerThermalSourceStatusText: String"))
    #expect(metricSnapshot.contains("public var systemVersionSourceStatusText: String"))
    #expect(metricSnapshot.contains("public var hasOSVersionReport: Bool"))
    #expect(metricSnapshot.contains("public var hasKernelReleaseReport: Bool"))
    #expect(metricSnapshot.contains("hasAnyReport: hasOSVersionReport || hasUptimeReport || hasKernelReleaseReport"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricCPUMemory, snapshot.cpuMemorySourceStatusText, PulseDockAppStrings.sourceSystemProcessorMemoryStats]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricNetworkConnection, snapshot.networkSourceStatusText, PulseDockAppStrings.sourceConnectionInterfaceTraffic]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricRunningApps, snapshot.runningAppsSourceStatusText, PulseDockAppStrings.sourceApplicationSessionList]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricGPUDisplays, snapshot.gpuDisplaySourceStatusText, PulseDockAppStrings.sourceGraphicsDisplayConfiguration]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricVolumeCapacity, snapshot.storageSourceStatusText, PulseDockAppStrings.sourceFileSystemCapacity]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricPowerThermalState, snapshot.powerThermalSourceStatusText, PulseDockAppStrings.sourcePowerThermalState]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricSystemVersionUptimeKernel, snapshot.systemVersionSourceStatusText, PulseDockAppStrings.sourceSystemVersionBootTime]"))
    #expect(!dashboardView.contains("private func sourceStatusText"))
    #expect(!dashboardView.contains("SourceStatus(snapshot)"))
    #expect(!dashboardView.contains("[\"GPU / 显示器\", \"可用\""))
    #expect(!dashboardView.contains("[\"卷容量\", \"可用\""))
    #expect(!dashboardView.contains("[\"运行时间 / 内核版本\", \"可用\""))
    #expect(audit.contains("Settings data-source rows use sampled reported-state text instead of hard-coded availability labels"))
    #expect(audit.contains("CPU and memory data-source status uses the shared memory reported-state flag instead of raw capacity checks."))
    #expect(audit.contains("Settings data-source display text is centralized on the shared snapshot model."))
    #expect(audit.contains("Network path reported state is centralized on the shared snapshot model instead of being inferred from user-facing text."))
    #expect(audit.contains("OS and kernel reported state is centralized on the shared snapshot model instead of being inferred from user-facing text."))
    #expect(audit.contains("Source-level tests prevent Settings data-source rows from hard-coding availability when snapshot fields are missing"))
    #expect(audit.contains("Source-level tests require Settings data-source labels to come from the shared snapshot model."))
    #expect(audit.contains("Source-level tests require network path reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons."))
    #expect(audit.contains("Source-level tests require OS and kernel reported-state checks to use explicit snapshot flags instead of user-facing text comparisons."))
}

@Test func settingsDataSourceRowsSurfaceLoadAverageReportedState() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let settingsStart = try #require(dashboardView.range(of: "private struct SettingsPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct DashboardPanel")?.lowerBound)
    let settingsPage = String(dashboardView[settingsStart..<nextStart])

    #expect(MetricSnapshot.placeholder.loadAverageSourceStatusText == SharedMetricStrings.notReported)
    #expect(settingsPage.contains("[PulseDockAppStrings.metricLoad, snapshot.loadAverageSourceStatusText, PulseDockAppStrings.sourceLoadAverages]"))
    #expect(!dashboardView.contains("private func loadAverageSourceStatus"))
    #expect(!dashboardView.contains("loadAverageSourceStatus(snapshot)"))
    #expect(audit.contains("Settings data-source rows include load-average reported state, matching the implemented Load surfaces."))
    #expect(audit.contains("Source-level tests require Settings data-source rows to surface load-average reported state."))
}

@Test func displayInventoryDoesNotStoreRawDisplayIdentifiers() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public struct DisplayMetric"))
    #expect(metricSnapshot.contains("public var id: Int { index }"))
    #expect(metricSnapshot.contains("public var index: Int"))
    #expect(!metricSnapshot.contains("displayID"))
    #expect(!sampler.contains("DisplayMetric(\n                displayID:"))
    #expect(!sampler.contains("Display \\(displayID)"))
}

@Test func displaySamplerFallsBackToNSScreenWhenCoreGraphicsListIsEmpty() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(sampler.contains("screenSnapshot.fallbackDisplays"))
    #expect(sampler.contains("NSScreen.screens"))
    #expect(sampler.contains("NSScreen.main"))
}

@Test func displaySamplerUsesNSScreenRefreshRateWhenCoreGraphicsOmitsIt() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(sampler.contains("let displayScreenSnapshot = screenDisplaySnapshot()"))
    #expect(sampler.contains("sampleDisplays(screenSnapshot: screenSnapshot)"))
    #expect(sampler.contains("modeRefreshRate > 0 ? modeRefreshRate : screenSnapshot.refreshRatesByDisplayID[displayID, default: 0]"))
    #expect(sampler.contains("private func screenDisplaySnapshotOnMainThread() -> ScreenDisplaySnapshot"))
    #expect(sampler.contains("NSScreenNumber"))
    #expect(sampler.contains("screen.maximumFramesPerSecond"))
    #expect(sampler.contains("refreshRate: screenRefreshRate(screen)"))
}

@Test func systemSamplerRoutesNSScreenMetadataThroughMainThreadInsteadOfDroppingIt() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(sampler.contains("private struct ScreenDisplaySnapshot"))
    #expect(sampler.contains("private func screenDisplaySnapshot() -> ScreenDisplaySnapshot"))
    #expect(sampler.contains("Thread.isMainThread"))
    #expect(sampler.contains("DispatchQueue.main.sync"))
    #expect(sampler.contains("private func screenDisplaySnapshotOnMainThread() -> ScreenDisplaySnapshot"))
    #expect(sampler.contains("public func invalidateDisplaysCache()"))
    #expect(!sampler.contains("guard Thread.isMainThread else { return [] }"))
    #expect(!sampler.contains("guard Thread.isMainThread else { return [:] }"))
    #expect(audit.contains("Display metadata that depends on NSScreen is collected through a main-thread snapshot"))
}

@Test func displayPageShowsSampledModeSizeAndRotation() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("columns: PulseDockAppStrings.displayTableColumns"))
    #expect(dashboardView.contains("display.modeSizeText"))
    #expect(dashboardView.contains("display.rotationText"))
    #expect(audit.contains("display mode size and rotation state"))
}

@Test func displayPageUsesSharedDisplayStateText() throws {
    let mainMirroredDisplay = DisplayMetric(
        index: 0,
        name: "Main",
        pixelWidth: 3024,
        pixelHeight: 1964,
        modeWidth: 1512,
        modeHeight: 982,
        refreshRate: 120,
        isBuiltin: true,
        isMain: true,
        isMirrored: true,
        rotationDegrees: 0,
        hasTopologyReport: true,
        hasRotationReport: true
    )
    let builtinExtendedDisplay = DisplayMetric(
        index: 1,
        name: "Built-in",
        pixelWidth: 2560,
        pixelHeight: 1600,
        modeWidth: 1280,
        modeHeight: 800,
        refreshRate: 60,
        isBuiltin: true,
        isMain: false,
        isMirrored: false,
        rotationDegrees: 0,
        hasTopologyReport: true,
        hasRotationReport: true
    )
    let externalExtendedDisplay = DisplayMetric(
        index: 2,
        name: "External",
        pixelWidth: 3840,
        pixelHeight: 2160,
        modeWidth: 1920,
        modeHeight: 1080,
        refreshRate: 60,
        isBuiltin: false,
        isMain: false,
        isMirrored: false,
        rotationDegrees: 0,
        hasTopologyReport: true,
        hasRotationReport: true
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sharedStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SharedMetricStrings.swift"),
        encoding: .utf8
    )
    let english = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )
    let chinese = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let expectedEntries = [
        (symbol: "displayTopologyMain", key: "shared_metrics.display.topology.main", english: "Main Display", chinese: "主屏幕"),
        (symbol: "displayTopologyBuiltIn", key: "shared_metrics.display.topology.built_in", english: "Built-in", chinese: "内建"),
        (symbol: "displayTopologyExternal", key: "shared_metrics.display.topology.external", english: "External", chinese: "外接"),
        (symbol: "displayTopologyMirrored", key: "shared_metrics.display.topology.mirrored", english: "Mirrored", chinese: "镜像"),
        (symbol: "displayTopologyExtended", key: "shared_metrics.display.topology.extended", english: "Extended", chinese: "扩展")
    ]

    for entry in expectedEntries {
        #expect(sharedStrings.contains("static var \(entry.symbol): String"))
        #expect(sharedStrings.contains("localized(\"\(entry.key)\", defaultValue: \"\(entry.english)\")"))
        #expect(english.contains("\"\(entry.key)\" = \"\(entry.english)\";"))
        #expect(chinese.contains("\"\(entry.key)\" = \"\(entry.chinese)\";"))
        #expect(metricSnapshot.contains("SharedMetricStrings.\(entry.symbol)"))
    }

    #expect(mainMirroredDisplay.stateText == "\(SharedMetricStrings.displayTopologyMain) · \(SharedMetricStrings.displayTopologyMirrored)")
    #expect(builtinExtendedDisplay.stateText == "\(SharedMetricStrings.displayTopologyBuiltIn) · \(SharedMetricStrings.displayTopologyExtended)")
    #expect(externalExtendedDisplay.stateText == "\(SharedMetricStrings.displayTopologyExternal) · \(SharedMetricStrings.displayTopologyExtended)")
    #expect(metricSnapshot.contains("public var stateText: String"))
    #expect(dashboardView.contains("display.stateText"))
    #expect(!dashboardView.contains("displayStateText(display)"))
    #expect(!dashboardView.contains("private func displayStateText(_ display: DisplayMetric) -> String"))
    #expect(audit.contains("Display topology state text is centralized on the shared display model"))
    #expect(audit.contains("Source-level tests require Display page topology labels to come from the shared model"))
}

@Test func legacyDisplayMissingTopologyAndRotationDoesNotInventExternalExtendedState() throws {
    let decodedDisplay = try JSONDecoder().decode(DisplayMetric.self, from: Data("""
    {
      "index": 0,
      "name": "Built-in Display",
      "pixelWidth": 3024,
      "pixelHeight": 1964,
      "modeWidth": 1512,
      "modeHeight": 982,
      "refreshRate": 120
    }
    """.utf8))
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(decodedDisplay.stateText == SharedMetricStrings.notReported)
    #expect(decodedDisplay.rotationText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasTopologyReport: Bool"))
    #expect(metricSnapshot.contains("public var hasRotationReport: Bool"))
    #expect(metricSnapshot.contains("guard hasRotationReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("guard hasTopologyReport else { return SharedMetricStrings.notReported }"))
    #expect(sampler.contains("hasTopologyReport: true"))
    #expect(sampler.contains("hasRotationReport: true"))
    #expect(audit.contains("Legacy display snapshots missing topology or rotation fields remain not-reported instead of being displayed as external extended displays or 0-degree rotation."))
    #expect(audit.contains("Source-level tests prevent legacy display topology and rotation fields from inventing external extended state."))
}

@Test func initializerDisplayCapabilityOnlyDoesNotInventTopologyOrRotation() throws {
    let capabilityOnlyDisplay = DisplayMetric(
        index: 0,
        name: "Built-in Display",
        pixelWidth: 3024,
        pixelHeight: 1964,
        modeWidth: 1512,
        modeHeight: 982,
        refreshRate: 120,
        backingScaleFactor: 2,
        colorSpaceModel: "RGB",
        colorComponentCount: 3,
        physicalWidthMillimeters: 344,
        physicalHeightMillimeters: 223,
        isBuiltin: false,
        isMain: false,
        isMirrored: false,
        rotationDegrees: 0
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(capabilityOnlyDisplay.pixelSizeText == "3024x1964")
    #expect(capabilityOnlyDisplay.modeSizeText == "1512x982")
    #expect(capabilityOnlyDisplay.refreshRateText == "120 Hz")
    #expect(capabilityOnlyDisplay.backingScaleText == "2x")
    #expect(capabilityOnlyDisplay.colorText == "RGB · 3")
    #expect(capabilityOnlyDisplay.physicalSizeText == "344x223 mm")
    #expect(capabilityOnlyDisplay.stateText == SharedMetricStrings.notReported)
    #expect(capabilityOnlyDisplay.rotationText == SharedMetricStrings.notReported)
    #expect(capabilityOnlyDisplay.hasInventoryReport)
    #expect(metricSnapshot.contains("hasTopologyReport: Bool = false"))
    #expect(metricSnapshot.contains("hasRotationReport: Bool = false"))
    #expect(!metricSnapshot.contains("hasTopologyReport: Bool = true"))
    #expect(!metricSnapshot.contains("hasRotationReport: Bool = true"))
    #expect(audit.contains("DisplayMetric initializer defaults topology and rotation state to not-reported when only public display capability fields are provided."))
    #expect(audit.contains("Source-level tests prevent capability-only display snapshots from inventing external extended topology or 0-degree rotation."))
}

@Test func missingDisplayMetricsUseReportedStateInsteadOfZeroOrAdaptiveText() throws {
    let decodedMissingName = try JSONDecoder().decode(DisplayMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    let display = DisplayMetric(
        index: 0,
        name: "显示器 1",
        pixelWidth: 0,
        pixelHeight: 0,
        modeWidth: 0,
        modeHeight: 0,
        refreshRate: 0,
        backingScaleFactor: 0,
        colorSpaceModel: nil,
        colorComponentCount: 0,
        physicalWidthMillimeters: 0,
        physicalHeightMillimeters: 0,
        isBuiltin: false,
        isMain: false,
        isMirrored: false,
        rotationDegrees: 0
    )
    let blankDisplayName = DisplayMetric(
        index: 1,
        name: "   ",
        pixelWidth: 0,
        pixelHeight: 0,
        modeWidth: 0,
        modeHeight: 0,
        refreshRate: 0,
        backingScaleFactor: 0,
        colorSpaceModel: nil,
        colorComponentCount: 0,
        physicalWidthMillimeters: 0,
        physicalHeightMillimeters: 0,
        isBuiltin: false,
        isMain: false,
        isMirrored: false,
        rotationDegrees: 0
    )
    let legacyGenericDisplayName = DisplayMetric(
        index: 2,
        name: "显示器",
        pixelWidth: 0,
        pixelHeight: 0,
        modeWidth: 0,
        modeHeight: 0,
        refreshRate: 0,
        backingScaleFactor: 0,
        colorSpaceModel: nil,
        colorComponentCount: 0,
        physicalWidthMillimeters: 0,
        physicalHeightMillimeters: 0,
        isBuiltin: false,
        isMain: false,
        isMirrored: false,
        rotationDegrees: 0
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(MetricSnapshot.placeholder.displaySummaryText == SharedMetricStrings.notReported)
    #expect(MetricSnapshot.placeholder.gpuDisplaySummaryText == SharedMetricStrings.gpuDisplaySummary(
        gpuText: SharedMetricStrings.gpuNotReportedSummary,
        displayText: SharedMetricStrings.displayNotReportedSummary
    ))
    #expect(MetricSnapshot.placeholder.hasGPUDisplayReport == false)
    #expect(MetricSnapshot.placeholder.hasDisplayReport == false)
    var gpuOnly = MetricSnapshot.placeholder
    gpuOnly.gpuDevices = [GPUDeviceMetric(index: 0, name: "Apple GPU", isLowPower: false, isRemovable: false, isHeadless: false, hasUnifiedMemory: true, recommendedMaxWorkingSetBytes: 1_024)]
    var displayOnly = MetricSnapshot.placeholder
    displayOnly.displays = [DisplayMetric(index: 0, name: "Built-in Display", pixelWidth: 1920, pixelHeight: 1200, modeWidth: 1920, modeHeight: 1200, refreshRate: 60, isBuiltin: true, isMain: true, isMirrored: false, rotationDegrees: 0)]
    var reportedInventory = gpuOnly
    reportedInventory.displays = displayOnly.displays
    #expect(gpuOnly.gpuDisplaySummaryText == SharedMetricStrings.gpuDisplaySummary(
        gpuText: SharedMetricStrings.gpuSummary(count: 1),
        displayText: SharedMetricStrings.displayNotReportedSummary
    ))
    #expect(displayOnly.gpuDisplaySummaryText == SharedMetricStrings.gpuDisplaySummary(
        gpuText: SharedMetricStrings.gpuNotReportedSummary,
        displayText: SharedMetricStrings.displaySummary(count: 1)
    ))
    #expect(reportedInventory.gpuDisplaySummaryText == "1 GPU / 1 display")
    #expect(gpuOnly.hasGPUDisplayReport)
    #expect(displayOnly.hasGPUDisplayReport)
    #expect(gpuOnly.hasDisplayReport == false)
    #expect(displayOnly.hasDisplayReport == true)
    #expect(decodedMissingName.name == SharedMetricStrings.notReported)
    #expect(blankDisplayName.name == SharedMetricStrings.notReported)
    #expect(legacyGenericDisplayName.name == SharedMetricStrings.notReported)
    #expect(display.pixelSizeText == SharedMetricStrings.notReported)
    #expect(display.modeSizeText == SharedMetricStrings.notReported)
    #expect(display.backingScaleText == SharedMetricStrings.notReported)
    #expect(display.colorText == SharedMetricStrings.notReported)
    #expect(display.refreshRateText == SharedMetricStrings.notReported)
    #expect(display.physicalSizeText == SharedMetricStrings.notReported)
    #expect(display.rotationText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var pixelSizeText: String"))
    #expect(metricSnapshot.contains("public var modeSizeText: String"))
    #expect(metricSnapshot.contains("public var backingScaleText: String"))
    #expect(metricSnapshot.contains("public var colorText: String"))
    #expect(metricSnapshot.contains("public var refreshRateText: String"))
    #expect(metricSnapshot.contains("public var physicalSizeText: String"))
    #expect(metricSnapshot.contains("public var rotationText: String"))
    #expect(metricSnapshot.contains("private static func reportedDisplayName(_ name: String?) -> String"))
    #expect(metricSnapshot.contains("name = Self.reportedDisplayName(try values.decodeIfPresent(String.self, forKey: .name))"))
    #expect(!metricSnapshot.contains("name = try values.decodeIfPresent(String.self, forKey: .name) ?? \"显示器\""))
    #expect(metricSnapshot.contains("public var hasDisplayReport: Bool"))
    #expect(metricSnapshot.contains("guard hasDisplayReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("public var gpuDisplaySummaryText: String"))
    #expect(metricSnapshot.contains("public var hasGPUDisplayReport: Bool"))
    #expect(dashboardView.contains("StatusSummaryRow(title: PulseDockAppStrings.metricGPUDisplays, value: snapshot.gpuDisplaySummaryText, status: snapshot.hasGPUDisplayReport ? .normal : .neutral)"))
    #expect(!dashboardView.contains("private func gpuDisplaySummaryText"))
    #expect(!dashboardView.contains("private func gpuDisplayStatus"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, icon: \"display\", status: snapshot.hasDisplayReport ? .normal : .neutral"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, icon: \"display\", status: snapshot.hasDisplayReport ? .normal : .neutral"))
    #expect(dashboardView.contains("display.pixelSizeText"))
    #expect(dashboardView.contains("display.modeSizeText"))
    #expect(dashboardView.contains("display.backingScaleText"))
    #expect(dashboardView.contains("display.colorText"))
    #expect(dashboardView.contains("display.refreshRateText"))
    #expect(dashboardView.contains("display.physicalSizeText"))
    #expect(dashboardView.contains("display.rotationText"))
    #expect(!dashboardView.contains("displayResolutionText(display)"))
    #expect(!dashboardView.contains("value: \"\\(snapshot.displays.count) 台\""))
    #expect(!dashboardView.contains("value: \"\\(snapshot.gpuDevices.count) / \\(snapshot.displays.count)\""))
    #expect(!dashboardView.contains("return \"\\(display.pixelWidth)x\\(display.pixelHeight)\""))
    #expect(!dashboardView.contains("return \"自适应\""))
    #expect(widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, tint: reportedTint(hasReport: snapshot.hasDisplayReport, fallback: Palette.amber(for: colorScheme)))"))
    #expect(!widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, tint: reportedTint(valueText: snapshot.displaySummaryText, fallback: Palette.amber))"))
    #expect(!widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricDisplays, value: \"\\(snapshot.displays.count)\""))
    #expect(audit.contains("Display metric text reports the system-not-reported state when display dimensions or capabilities are unavailable"))
    #expect(audit.contains("Missing or legacy generic display names are displayed as not-reported instead of a generic display label"))
    #expect(audit.contains("Display count surfaces use the shared display summary text so missing display inventory is not formatted as 0 displays"))
    #expect(audit.contains("GPU/display combined summary text is centralized on the shared snapshot model."))
    #expect(audit.contains("Source-level tests prevent missing display metrics from being formatted as 0x0 or adaptive text"))
    #expect(audit.contains("Source-level tests prevent missing display names from surfacing as a generic display label"))
    #expect(audit.contains("Source-level tests prevent missing display inventory from being formatted as 0 displays on dashboard and menu bar surfaces"))
    #expect(audit.contains("Source-level tests require Overview GPU/display summary labels to come from the shared snapshot model."))
}

@Test func legacyDisplayInventoryWithoutReportedFieldsDoesNotInventDisplayCountsAcrossSurfaces() throws {
    let legacyDisplay = try JSONDecoder().decode(DisplayMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    var snapshot = MetricSnapshot.placeholder
    snapshot.displays = [legacyDisplay]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.displaySummaryText == SharedMetricStrings.notReported)
    #expect(snapshot.gpuDisplaySummaryText == SharedMetricStrings.gpuDisplaySummary(
        gpuText: SharedMetricStrings.gpuNotReportedSummary,
        displayText: SharedMetricStrings.displayNotReportedSummary
    ))
    #expect(!snapshot.hasDisplayReport)
    #expect(!snapshot.hasGPUDisplayReport)
    #expect(metricSnapshot.contains("public var hasInventoryReport: Bool"))
    #expect(metricSnapshot.contains("displays.contains(where: \\.hasInventoryReport)"))
    #expect(metricSnapshot.contains("let reportedDisplayCount = displays.filter(\\.hasInventoryReport).count"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, icon: \"display\", status: snapshot.hasDisplayReport ? .normal : .neutral"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, icon: \"display\", status: snapshot.hasDisplayReport ? .normal : .neutral"))
    #expect(audit.contains("Legacy display inventory records with no reported display fields remain not-reported instead of being counted as live displays."))
    #expect(audit.contains("Source-level tests prevent legacy display inventory records with only an index from inventing display counts."))
}

@Test func displayPageSurfacesPublicPhysicalScreenSize() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var physicalWidthMillimeters: Int"))
    #expect(metricSnapshot.contains("public var physicalHeightMillimeters: Int"))
    #expect(sampler.contains("CGDisplayScreenSize(displayID)"))
    #expect(sampler.contains("physicalWidthMillimeters: Int(screenSize.width.rounded())"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.displayTableColumns"))
    #expect(metricSnapshot.contains("public var physicalSizeText: String"))
    #expect(dashboardView.contains("display.physicalSizeText"))
    #expect(audit.contains("physical screen size"))
}

@Test func displayPageSurfacesPublicBackingScaleFactor() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var backingScaleFactor: Double"))
    #expect(sampler.contains("screenSnapshot.scalesByDisplayID"))
    #expect(sampler.contains("backingScaleFactor: screenSnapshot.scalesByDisplayID[displayID, default: 0]"))
    #expect(sampler.contains("backingScaleFactor: scale"))
    #expect(sampler.contains("scales[displayID] = Double(scale)"))
    #expect(sampler.contains("screen.backingScaleFactor"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.displayTableColumns"))
    #expect(metricSnapshot.contains("public var backingScaleText: String"))
    #expect(dashboardView.contains("display.backingScaleText"))
    #expect(audit.contains("backing scale factor"))
}

@Test func displayPageSurfacesPublicColorSpaceModelWithoutProfileNames() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var colorSpaceModel: String?"))
    #expect(metricSnapshot.contains("public var colorComponentCount: Int"))
    #expect(sampler.contains("private struct DisplayColorSpaceSample"))
    #expect(sampler.contains("screenSnapshot.colorSpacesByDisplayID"))
    #expect(sampler.contains("colorSpaceModel: screenSnapshot.colorSpacesByDisplayID[displayID]?.model"))
    #expect(sampler.contains("colorComponentCount: screenSnapshot.colorSpacesByDisplayID[displayID]?.componentCount ?? 0"))
    #expect(sampler.contains("colorSpaceModel: colorSpaceModel(screen.colorSpace?.colorSpaceModel)"))
    #expect(sampler.contains("colorComponentCount: screen.colorSpace?.numberOfColorComponents ?? 0"))
    #expect(!sampler.contains("screen.colorSpace?.localizedName"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.displayTableColumns"))
    #expect(metricSnapshot.contains("public var colorText: String"))
    #expect(dashboardView.contains("display.colorText"))
    #expect(audit.contains("color space model and component count"))
    #expect(audit.contains("does not store color profile names"))
}

@Test func batterySamplerUsesPublicPowerSourceHealthKeys() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(sampler.contains("description[kIOBatteryCycleCountKey]"))
    #expect(sampler.contains("description[kIOPSBatteryHealthKey]"))
    #expect(sampler.contains("description[kIOPSDesignCapacityKey]"))
    #expect(sampler.contains("description[kIOPSVoltageKey]"))
    #expect(sampler.contains("description[kIOBatteryAmperageKey]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryCycleCountLabel, snapshot.batteryCycleText, PulseDockAppStrings.sourceBatteryHealth]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryHealthLabel, snapshot.batteryHealthText, PulseDockAppStrings.sourceBatteryHealth]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryDesignCapacityLabel, snapshot.batteryDesignCapacityText, PulseDockAppStrings.sourceBatterySpecifications]"))
    #expect(dashboardView.contains("snapshot.batteryVoltageText"))
    #expect(dashboardView.contains("snapshot.batteryAmperageText"))
}

@Test func powerPageUsesSharedBatteryDetailDisplayText() throws {
    var snapshot = MetricSnapshot.placeholder
    snapshot.batteryCurrentCapacity = 88
    snapshot.batteryMaxCapacity = 94
    snapshot.batteryDesignCapacity = 100
    snapshot.batteryVoltageMillivolts = 12_345
    snapshot.batteryAmperageMilliamps = -456
    snapshot.batteryHealth = "Check Battery"

    var missingSnapshot = MetricSnapshot.placeholder
    missingSnapshot.batteryHealth = "   "

    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.batteryCurrentCapacityText == "88")
    #expect(snapshot.batteryMaxCapacityText == "94")
    #expect(snapshot.batteryDesignCapacityText == "100")
    #expect(snapshot.batteryVoltageText == "12345 mV")
    #expect(snapshot.batteryAmperageText == "-456 mA")
    #expect(snapshot.batteryHealthText == SharedMetricStrings.batteryHealthCheck)
    #expect(missingSnapshot.batteryCurrentCapacityText == SharedMetricStrings.notReported)
    #expect(missingSnapshot.batteryVoltageText == SharedMetricStrings.notReported)
    #expect(missingSnapshot.batteryAmperageText == SharedMetricStrings.notReported)
    #expect(missingSnapshot.batteryHealthText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var batteryCurrentCapacityText: String"))
    #expect(metricSnapshot.contains("public var batteryMaxCapacityText: String"))
    #expect(metricSnapshot.contains("public var batteryDesignCapacityText: String"))
    #expect(metricSnapshot.contains("public var batteryVoltageText: String"))
    #expect(metricSnapshot.contains("public var batteryAmperageText: String"))
    #expect(metricSnapshot.contains("public var batteryHealthText: String"))
    #expect(!dashboardView.contains("(PulseDockAppStrings.batteryCurrentCapacityLabel, snapshot.batteryCurrentCapacityText)"))
    #expect(!dashboardView.contains("(PulseDockAppStrings.batteryMaxCapacityLabel, snapshot.batteryMaxCapacityText)"))
    #expect(!dashboardView.contains("(PulseDockAppStrings.batteryDesignCapacityLabel, snapshot.batteryDesignCapacityText)"))
    #expect(!dashboardView.contains("(PulseDockAppStrings.batteryHealthLabel, snapshot.batteryHealthText)"))
    #expect(!dashboardView.contains("(PulseDockAppStrings.batteryVoltageLabel, snapshot.batteryVoltageText)"))
    #expect(!dashboardView.contains("(PulseDockAppStrings.batteryCurrentLabel, snapshot.batteryAmperageText)"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryCurrentCapacityLabel, snapshot.batteryCurrentCapacityText, PulseDockAppStrings.sourcePowerStatus]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryMaxCapacityLabel, snapshot.batteryMaxCapacityText, PulseDockAppStrings.sourcePowerStatus]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryDesignCapacityLabel, snapshot.batteryDesignCapacityText, PulseDockAppStrings.sourceBatterySpecifications]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryHealthLabel, snapshot.batteryHealthText, PulseDockAppStrings.sourceBatteryHealth]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryVoltageLabel, snapshot.batteryVoltageText, PulseDockAppStrings.sourcePowerStatus]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryCurrentLabel, snapshot.batteryAmperageText, PulseDockAppStrings.sourcePowerStatus]"))
    #expect(!dashboardView.contains("optionalIntText(snapshot.batteryCurrentCapacity)"))
    #expect(!dashboardView.contains("optionalIntText(snapshot.batteryMaxCapacity)"))
    #expect(!dashboardView.contains("optionalIntText(snapshot.batteryDesignCapacity)"))
    #expect(!dashboardView.contains("electricText(snapshot.batteryVoltageMillivolts"))
    #expect(!dashboardView.contains("electricText(snapshot.batteryAmperageMilliamps"))
    #expect(!dashboardView.contains("batteryHealthText(snapshot.batteryHealth)"))
    #expect(!dashboardView.contains("private func optionalIntText(_ value: Int?) -> String"))
    #expect(!dashboardView.contains("private func electricText(_ value: Int?, unit: String) -> String"))
    #expect(!dashboardView.contains("private func batteryHealthText(_ value: String?) -> String"))
    #expect(audit.contains("Battery detail display text is centralized on the shared snapshot model."))
    #expect(audit.contains("Source-level tests require Power page battery detail labels to come from the shared snapshot model."))
}

@Test func powerPageSummarySurfacesVoltageAndAmperageReadings() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let detailsStart = try #require(dashboardView.range(of: "DashboardPanel(title: PulseDockAppStrings.batteryInformationTitle")?.lowerBound)
    let summaryStart = try #require(dashboardView.range(of: "DashboardPanel(title: PulseDockAppStrings.powerBatteryPanelTitle")?.lowerBound)
    let batteryDetails = String(dashboardView[detailsStart..<summaryStart])

    #expect(!dashboardView.contains("(PulseDockAppStrings.batteryVoltageLabel, snapshot.batteryVoltageText)"))
    #expect(!dashboardView.contains("(PulseDockAppStrings.batteryCurrentLabel, snapshot.batteryAmperageText)"))
    #expect(batteryDetails.contains("[PulseDockAppStrings.batteryVoltageLabel, snapshot.batteryVoltageText, PulseDockAppStrings.sourcePowerStatus]"))
    #expect(batteryDetails.contains("[PulseDockAppStrings.batteryCurrentLabel, snapshot.batteryAmperageText, PulseDockAppStrings.sourcePowerStatus]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryVoltageLabel, snapshot.batteryVoltageText, PulseDockAppStrings.sourcePowerStatus]"))
    #expect(dashboardView.contains("[PulseDockAppStrings.batteryCurrentLabel, snapshot.batteryAmperageText, PulseDockAppStrings.sourcePowerStatus]"))
    #expect(audit.contains("The Power page Battery Information table surfaces public voltage and amperage readings when macOS reports them."))
    #expect(audit.contains("Source-level tests require the Power page Battery Information table to surface sampled voltage and amperage readings."))
}

@Test func batterySamplerChoosesInternalBatteryBeforeOtherPowerSources() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(sampler.contains("let descriptions = powerSourceDescriptions(info: info, sources: sources)"))
    #expect(sampler.contains("guard let description = preferredBatteryDescription(from: descriptions)"))
    #expect(sampler.contains("private func powerSourceDescriptions(info: CFTypeRef, sources: [CFTypeRef]) -> [[String: Any]]"))
    #expect(sampler.contains("private func preferredBatteryDescription(from descriptions: [[String: Any]]) -> [String: Any]?"))
    #expect(sampler.contains("description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType"))
    #expect(sampler.contains("doubleValue(description[kIOPSCurrentCapacityKey]) != nil"))
    #expect(sampler.contains("doubleValue(description[kIOPSMaxCapacityKey]) != nil"))
    #expect(sampler.contains("return descriptions.first"))
    #expect(!sampler.contains("let source = sources.first"))
}

@Test func batterySamplerUsesProvidingPowerSourceWhenBatteryDetailsAreUnavailable() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(sampler.contains("let providingPowerSource = providingPowerSourceText(info)"))
    #expect(sampler.contains("powerSource: providingPowerSource"))
    #expect(sampler.contains("description[kIOPSPowerSourceStateKey] as? String ?? providingPowerSource"))
    #expect(sampler.contains("private func providingPowerSourceText(_ info: CFTypeRef) -> String?"))
    #expect(sampler.contains("IOPSGetProvidingPowerSourceType(info)"))
}

@Test func batterySamplerUsesSystemTimeRemainingEstimateAsDischargeFallback() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(sampler.contains("let estimatedDischargeMinutes = estimatedBatteryDischargeMinutes()"))
    #expect(sampler.contains("let timeRemaining = isCharging ? timeToFull : (timeToEmpty ?? estimatedDischargeMinutes)"))
    #expect(sampler.contains("private func estimatedBatteryDischargeMinutes() -> Int?"))
    #expect(sampler.contains("IOPSGetTimeRemainingEstimate()"))
    #expect(sampler.contains("kIOPSTimeRemainingUnknown"))
    #expect(sampler.contains("kIOPSTimeRemainingUnlimited"))
}

@Test func batterySamplerDoesNotInferChargingStateFromACPowerWhenChargingFlagIsMissing() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(sampler.contains("let reportedIsCharging = description[kIOPSIsChargingKey] as? Bool"))
    #expect(sampler.contains("let isCharging = reportedIsCharging ?? false"))
    #expect(!sampler.contains("?? (powerSource == kIOPSACPowerValue)"))
    #expect(audit.contains("Battery charging state is only displayed when the public power-source description reports `kIOPSIsChargingKey`; AC power alone is not treated as charging."))
    #expect(audit.contains("Source-level tests prevent missing battery charging flags from being inferred from AC power."))
}

@Test func snapshotsAvoidLocalDeviceNamesAndRawHardwareModels() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(!metricSnapshot.contains("hostName"))
    #expect(!metricSnapshot.contains("hardwareModel"))
    #expect(!metricSnapshot.contains("Host.current().localizedName"))
    #expect(!sampler.contains("Host.current().localizedName"))
    #expect(!sampler.contains("\"hw.model\""))
    #expect(!metricsStore.contains("hostName:"))
    #expect(!metricsStore.contains("hardwareModel:"))
    #expect(!dashboardView.contains("snapshot.hostName"))
    #expect(!dashboardView.contains("snapshot.hardwareModel"))
}

@Test func placeholderDoesNotPretendToContainLiveMetrics() {
    let snapshot = MetricSnapshot.placeholder

    #expect(snapshot.cpuUsage == 0)
    #expect(snapshot.cpuCoreUsages.isEmpty)
    #expect(snapshot.memoryUsedBytes == 0)
    #expect(snapshot.memoryTotalBytes == 0)
    #expect(snapshot.memorySwapUsedBytes == 0)
    #expect(snapshot.memorySwapTotalBytes == 0)
    #expect(snapshot.networkBytesPerSecond == 0)
    #expect(snapshot.networkPathStatus == "unknown")
    #expect(snapshot.networkPathInterfaceKinds.isEmpty)
    #expect(snapshot.networkInterfaces.isEmpty)
    #expect(snapshot.storageVolumes.isEmpty)
    #expect(snapshot.processCount == 0)
    #expect(snapshot.runningApps.isEmpty)
    #expect(snapshot.gpuDevices.isEmpty)
    #expect(snapshot.displays.isEmpty)
    #expect(snapshot.uptimeSeconds == 0)
}

@Test func widgetProviderUsesRepresentativePreviewAndCompactTimelineSampling() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let blockedPlaceholderCopy = ["等待首次同步", "系统会按时间线刷新"]

    #expect(widget.contains("SystemEntry(date: Date(), snapshot: Self.representativeSnapshot(), snapshotAge: 0, kind: .preview)"))
    #expect(widget.contains("DispatchQueue.global(qos: .utility).async"))
    #expect(widget.contains("Self.sampledSnapshotForTimeline(now: now)"))
    #expect(widget.contains("private final class WidgetSamplerCache: @unchecked Sendable"))
    #expect(widget.contains("private static let samplerCache = WidgetSamplerCache()"))
    #expect(widget.contains("Self.samplerCache.sampleCompact()"))
    #expect(widget.contains("func sampleCompact() -> MetricSnapshot"))
    #expect(widget.contains("return systemSampler.sampleWidgetCompact()"))
    #expect(sampler.contains("public func sampleWidgetCompact(now: Date = Date()) -> MetricSnapshot"))
    #expect(sampler.contains("sampleWidgetSnapshot(now: now).widgetCompactSnapshot()"))
    #expect(sampler.contains("private func sampleWidgetSnapshot(now: Date) -> MetricSnapshot"))
    #expect(!widget.contains("private var isPrimed"))
    #expect(!widget.contains("private var primedSnapshot"))
    #expect(!widget.contains("let sampler = SystemSampler()"))
    #expect(widget.contains("PlaceholderMetricSkeleton"))
    #expect(widget.contains("Text(PulseDockWidgetStrings.waitingData)"))
    for term in blockedPlaceholderCopy {
        #expect(!widget.contains(term))
    }
}

@Test func widgetSamplerCacheAvoidsImmediateSecondSampleAfterPrime() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(widget.contains("private final class WidgetSamplerCache: @unchecked Sendable"))
    #expect(widget.contains("return systemSampler.sampleWidgetCompact()"))
    #expect(!widget.contains("return systemSampler.sample()"))
    #expect(!widget.contains("private var isPrimed"))
    #expect(!widget.contains("private var primedSnapshot"))
    #expect(!widget.contains("_ = systemSampler.sample()\n            isPrimed = true\n            return systemSampler.sample()"))
    #expect(audit.contains("Widget sampler fallback uses compact in-extension sampling without dead priming state."))
}

@Test func systemSamplerCachesStaticInventoryBetweenLiveRefreshes() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(sampler.contains("private struct TimedSample<Value>"))
    #expect(sampler.contains("private let inventoryCacheInterval: TimeInterval"))
    #expect(sampler.contains("private var storageCache: TimedSample<StorageSample>?"))
    #expect(sampler.contains("private var gpuDevicesCache: TimedSample<[GPUDeviceMetric]>?"))
    #expect(sampler.contains("private var displaysCache: TimedSample<[DisplayMetric]>?"))
    #expect(sampler.contains("private var batteryCache: TimedSample<BatterySample>?"))
    #expect(sampler.contains("public convenience init(inventoryCacheInterval: TimeInterval = 15, batteryCacheInterval: TimeInterval = 5)"))
    #expect(sampler.contains("let storage = cachedStorage(now: now)"))
    #expect(sampler.contains("let gpuDevices = cachedGPUDevices(now: now)"))
    #expect(sampler.contains("let displays = cachedDisplays(now: now, screenSnapshot: displayScreenSnapshot)"))
    #expect(sampler.contains("let battery = cachedBattery(now: now)"))
    #expect(sampler.contains("private func cachedStorage(now: Date) -> StorageSample"))
    #expect(sampler.contains("private func cachedGPUDevices(now: Date) -> [GPUDeviceMetric]"))
    #expect(sampler.contains("private func cachedDisplays(now: Date, screenSnapshot: ScreenDisplaySnapshot) -> [DisplayMetric]"))
    #expect(sampler.contains("private func cachedBattery(now: Date) -> BatterySample"))
    #expect(sampler.contains("let memory = sampleMemory()"))
    #expect(sampler.contains("let networkInterfaces = sampleNetworkInterfaces(now: now)"))
    #expect(sampler.contains("let cpu = sampleCPUUsage()"))
    #expect(audit.contains("Static inventory sampling is cached for the main refresh loop"))
}

@Test func systemSamplerFiltersNonFiniteAndOverflowingPowerNumbersBeforeIntegerConversion() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(sampler.contains("currentCapacity: finiteInt(current)"))
    #expect(sampler.contains("maxCapacity: finiteInt(maximum)"))
    #expect(sampler.contains("if let value = value as? UInt64 { return Int(exactly: value) }"))
    #expect(sampler.contains("guard let converted, converted.isFinite else { return nil }"))
    #expect(sampler.contains("private func finiteInt(_ value: Double?) -> Int?"))
    #expect(sampler.contains("return validBatteryMinutes(finiteInt((estimate / 60).rounded()))"))
    #expect(!sampler.contains("current.map(Int.init)"))
    #expect(!sampler.contains("maximum.map(Int.init)"))
    #expect(!sampler.contains("if let value = value as? UInt64 { return Int(value) }"))
}

@Test func systemSamplerCachesStaticSystemInfoWithoutCachingActiveProcessorCount() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(sampler.contains("private struct SystemInfoSample"))
    #expect(sampler.contains("private let systemInfo: SystemInfoSample"))
    #expect(sampler.contains("self.systemInfo = Self.sampleSystemInfo()"))
    #expect(sampler.contains("private static func sampleSystemInfo() -> SystemInfoSample"))
    #expect(sampler.contains("physicalCoreCount: systemInfo.physicalCoreCount"))
    #expect(sampler.contains("logicalCoreCount: systemInfo.logicalCoreCount"))
    #expect(sampler.contains("cpuBrandName: systemInfo.cpuBrandName"))
    #expect(sampler.contains("osVersion: systemInfo.osVersion"))
    #expect(sampler.contains("kernelRelease: systemInfo.kernelRelease"))
    #expect(sampler.contains("activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount"))
    #expect(!sampler.contains("physicalCoreCount: sysctlInteger(\"hw.physicalcpu\")"))
    #expect(!sampler.contains("logicalCoreCount: sysctlInteger(\"hw.logicalcpu\")"))
    #expect(!sampler.contains("cpuBrandName: sysctlString(\"machdep.cpu.brand_string\")"))
    #expect(audit.contains("Static system information is sampled once per sampler instance"))
}

@Test func mainAppWarmsDeltaBasedSamplerBeforePublishingInitialSnapshot() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("private let initialSampleWarmUpDelayNanoseconds"))
    #expect(metricsStore.contains("private var initialRefreshTask"))
    #expect(metricsStore.contains("private var refreshTask"))
    #expect(metricsStore.contains("startInitialRefresh()"))
    #expect(metricsStore.contains("Task.detached(priority: .userInitiated)"))
    #expect(metricsStore.contains("sampler.sample()"))
    #expect(metricsStore.contains("let warmUpDelay = initialSampleWarmUpDelayNanoseconds"))
    #expect(metricsStore.contains("Task.sleep(nanoseconds: warmUpDelay)"))
    #expect(metricsStore.contains("initialRefreshTask?.cancel()"))
    #expect(metricsStore.contains("refreshTask?.cancel()"))
    #expect(metricsStore.contains("guard !Task.isCancelled"))
    #expect(metricsStore.contains("guard !isPaused else { return }"))
    #expect(metricsStore.contains("guard refreshTask == nil else"))
    #expect(metricsStore.contains("pendingRefreshAfterCurrent = true"))
    #expect(!metricsStore.contains("func start() {\n        guard timer == nil else { return }\n        refresh()\n        scheduleTimer()\n    }"))
}

@Test func metricsStoreQueuesOnePendingRefreshWhenSamplingIsInFlight() throws {
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(metricsStore.contains("private(set) var isRefreshing = false"))
    #expect(!metricsStore.contains("@Published private(set) var isRefreshing"))
    #expect(metricsStore.contains("private var pendingRefreshAfterCurrent = false"))
    #expect(metricsStore.contains("guard refreshTask == nil else"))
    #expect(metricsStore.contains("pendingRefreshAfterCurrent = true"))
    #expect(metricsStore.contains("let shouldRunPendingRefresh = pendingRefreshAfterCurrent && !isPaused && !Task.isCancelled"))
    #expect(metricsStore.contains("if shouldRunPendingRefresh"))
    #expect(metricsStore.contains("refresh()"))
    #expect(audit.contains("Refresh ticks that arrive while sampling is in flight queue one follow-up refresh instead of disappearing silently."))
}

@Test func resumeAfterPauseWarmsSamplerBeforePublishingSnapshot() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("if isPaused {\n            cancelInitialRefresh()"))
    #expect(metricsStore.contains("persistHistoryIfNeeded(at: Date(), force: true)"))
    #expect(metricsStore.contains("startInitialRefresh()"))
    #expect(metricsStore.contains("private func cancelInitialRefresh()"))
    #expect(!metricsStore.contains("func togglePause() {\n        isPaused.toggle()\n        if !isPaused {\n            refresh()\n        }\n    }"))
}

@Test func widgetDoesNotShowShortWindowNetworkThroughput() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )

    #expect(widget.contains("WidgetRow(title: PulseDockWidgetStrings.metricConnection"))
    #expect(widget.contains("snapshot.networkPathText"))
    #expect(widget.contains("snapshot.networkPathDetailText"))
    let widgetViewRange = try #require(widget.range(of: "struct SystemDashboardWidgetView"))
    let widgetBundleRange = try #require(widget.range(of: "#if !SWIFT_PACKAGE"))
    let widgetViews = String(widget[widgetViewRange.lowerBound..<widgetBundleRange.lowerBound])
    #expect(!widgetViews.contains("snapshot.networkText"))
    #expect(!widgetViews.contains("snapshot.networkInText"))
    #expect(!widgetViews.contains("snapshot.networkOutText"))
    #expect(!widgetViews.contains("networkBytesPerSecond"))
}

@Test func mediumWidgetSurfacesDeclaredCoreSignals() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let mediumRange = try #require(widget.range(of: "private struct MediumWidget"))
    let largeRange = try #require(widget.range(of: "private struct LargeWidget"))
    let mediumWidget = String(widget[mediumRange.lowerBound..<largeRange.lowerBound])

    #expect(widget.contains("private struct MediumWidget"))
    #expect(mediumWidget.contains("Text(snapshot.cpuText)"))
    #expect(!mediumWidget.contains("WidgetRow(title: \"CPU\", value: snapshot.cpuText"))
    #expect(mediumWidget.contains("WidgetRow(title: PulseDockWidgetStrings.metricMemory, value: snapshot.memoryUsageText"))
    #expect(mediumWidget.contains("WidgetRow(title: PulseDockWidgetStrings.metricConnection, value: snapshot.networkPathText"))
    #expect(mediumWidget.contains("WidgetRow(title: PulseDockWidgetStrings.metricDisk, value: snapshot.diskUsageText"))
    #expect(mediumWidget.contains("MiniStatus(title: PulseDockWidgetStrings.miniThermal, value: snapshot.thermalText"))
    #expect(mediumWidget.contains("MiniStatus(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText"))
    #expect(!mediumWidget.contains("WidgetRow(title: snapshot.powerStatusTitle"))
    #expect(mediumWidget.contains("VStack(spacing: 18)"))
    #expect(mediumWidget.contains(".frame(width: 166, alignment: .leading)"))
    #expect(mediumWidget.contains(".padding(.vertical, 18)"))
    #expect(audit.contains("Medium widgets keep the large CPU readout and use three supporting metric rows so the desktop layout stays breathable"))
    #expect(audit.contains("Source-level tests require medium widgets to avoid duplicating the CPU row and keep three supporting rows for memory, connection, and disk"))
    #expect(!audit.contains("medium widgets to surface CPU, memory, power, connection, disk, and thermal state"))
}

@Test func largeWidgetSurfacesLoadAverageSignal() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let largeStart = try #require(widget.range(of: "private struct LargeWidget")?.lowerBound)
    let nextStart = try #require(widget.range(of: "private struct EmptyDataWidget")?.lowerBound)
    let largeWidget = String(widget[largeStart..<nextStart])

    #expect(largeWidget.contains("RingMetric(title: PulseDockWidgetStrings.metricLoad, value: snapshot.loadText"))
    #expect(largeWidget.contains("progress: snapshot.loadAverageProgress"))
    #expect(!largeWidget.contains("max(snapshot.activeProcessorCount, 1)"))
    #expect(audit.contains("| Load | 1/5/15 minute load averages | System load average | Overview, CPU page, Status page, History page, Settings page, large widgets, menu bar popover |"))
    #expect(audit.contains("Large widgets surface load average with reported-state progress, normalized by active processor count."))
    #expect(audit.contains("Source-level tests require large widgets to surface load average with reported-state progress."))
}

@Test func largeWidgetSurfacesOperatingSystemVersionWithReportedState() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let largeStart = try #require(widget.range(of: "private struct LargeWidget")?.lowerBound)
    let nextStart = try #require(widget.range(of: "private struct EmptyDataWidget")?.lowerBound)
    let largeWidget = String(widget[largeStart..<nextStart])

    #expect(largeWidget.contains("StatTile(title: PulseDockWidgetStrings.metricUptime, value: snapshot.uptimeText, tint: reportedTint(hasReport: snapshot.hasUptimeReport, fallback: WidgetColor.amber(for: colorScheme), for: colorScheme))"))
    #expect(largeWidget.contains("StatTile(title: PulseDockWidgetStrings.metricSystem, value: snapshot.osVersionText, tint: reportedTint(hasReport: snapshot.hasOSVersionReport, fallback: WidgetColor.blue(for: colorScheme), for: colorScheme))"))
    #expect(largeWidget.contains("StatTile(title: PulseDockWidgetStrings.metricKernel, value: snapshot.kernelText, tint: reportedTint(hasReport: snapshot.hasKernelReleaseReport, fallback: WidgetColor.cyan(for: colorScheme), for: colorScheme))"))
    #expect(widget.contains("private func reportedTint(hasReport: Bool, fallback: Color, for colorScheme: ColorScheme) -> Color"))
    #expect(!largeWidget.contains("StatTile(title: PulseDockWidgetStrings.metricSystem, value: snapshot.osVersionText, tint: reportedTint(valueText: snapshot.osVersionText, fallback: WidgetColor.blue))"))
    #expect(!largeWidget.contains("StatTile(title: PulseDockWidgetStrings.metricKernel, value: snapshot.kernelText, tint: reportedTint(valueText: snapshot.kernelText, fallback: WidgetColor.cyan))"))
    #expect(!largeWidget.contains("StatTile(title: PulseDockWidgetStrings.metricKernel, value: snapshot.kernelText, tint: WidgetColor.cyan)"))
    #expect(audit.contains("Large widgets surface OS version, Darwin kernel release, and uptime with explicit snapshot reported-state tinting."))
    #expect(audit.contains("Source-level tests require large widgets to surface OS version with explicit snapshot reported-state tinting."))
}

@Test func largeWidgetUsesBreathableTwoColumnSections() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let largeStart = try #require(widget.range(of: "private struct LargeWidget")?.lowerBound)
    let nextStart = try #require(widget.range(of: "private struct EmptyDataWidget")?.lowerBound)
    let largeWidget = String(widget[largeStart..<nextStart])

    #expect(widget.contains("private let largeRingColumns"))
    #expect(largeWidget.contains("HStack(alignment: .top, spacing: 18)"))
    #expect(largeWidget.contains("LazyVGrid(columns: largeRingColumns, spacing: 12)"))
    #expect(largeWidget.contains("LargeWidgetSection"))
    #expect(largeWidget.contains("LargeInfoGrid(snapshot: snapshot)"))
    #expect(largeWidget.contains(".padding(18)"))
    #expect(widget.contains("private struct LargeWidgetSection<Content: View>: View"))
    #expect(widget.contains(".background(widgetPanelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))"))
    #expect(!largeWidget.contains("VStack(spacing: 9) {\n                WidgetRow"))
    #expect(audit.contains("Large widget layout uses two breathable columns with grouped rings and signal sections instead of stacking every row and tile vertically."))
    #expect(audit.contains("Source-level tests keep large widget ring spacing, grouped sections, and dynamic panel styling from regressing into a crowded vertical stack."))
}

@Test func mediumWidgetUsesRelaxedFirstVersionSpacingAndDarkModeText() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let widgetTokens = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/WidgetVisualTokens.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let mediumRange = try #require(widget.range(of: "private struct MediumWidget"))
    let largeRange = try #require(widget.range(of: "private struct LargeWidget"))
    let mediumWidget = String(widget[mediumRange.lowerBound..<largeRange.lowerBound])

    #expect(mediumWidget.contains("HStack(alignment: .center, spacing: 22)"))
    #expect(mediumWidget.contains("VStack(alignment: .leading, spacing: 9)"))
    #expect(mediumWidget.contains(".font(.system(size: 52, weight: .semibold).monospacedDigit())"))
    #expect(mediumWidget.contains(".foregroundStyle(widgetPrimaryText(for: colorScheme))"))
    #expect(widgetTokens.contains("func widgetPrimaryText(for colorScheme: ColorScheme) -> Color"))
    #expect(widgetTokens.contains("func widgetTrackFill(for colorScheme: ColorScheme) -> Color"))
    #expect(widget.contains("Capsule().fill(widgetTrackFill(for: colorScheme))"))
    #expect(!widget.contains("Capsule().fill(Color.secondary.opacity(0.14))"))
    #expect(audit.contains("Medium widget layout follows the roomier first-version composition with wider left content, larger CPU type, and relaxed supporting row spacing"))
    #expect(audit.contains("Source-level tests keep medium widget vertical padding, row spacing, and dark-mode text/track colors from regressing into a crowded layout"))
}

@Test func mediumWidgetUsesAirierFirstVersionStatusStrip() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let mediumRange = try #require(widget.range(of: "private struct MediumWidget"))
    let largeRange = try #require(widget.range(of: "private struct LargeWidget"))
    let mediumWidget = String(widget[mediumRange.lowerBound..<largeRange.lowerBound])

    #expect(mediumWidget.contains("HStack(alignment: .center, spacing: 22)"))
    #expect(mediumWidget.contains("VStack(alignment: .leading, spacing: 9)"))
    #expect(mediumWidget.contains(".font(.system(size: 52, weight: .semibold).monospacedDigit())"))
    #expect(mediumWidget.contains("Text(snapshot.logicalCoreSummaryText)"))
    #expect(mediumWidget.contains("MediumStatusStrip(snapshot: snapshot)"))
    #expect(mediumWidget.contains(".frame(width: 166, alignment: .leading)"))
    #expect(mediumWidget.contains("VStack(spacing: 18)"))
    #expect(!mediumWidget.contains("Text(\"\\(snapshot.networkPathText) · \\(snapshot.networkPathDetailText)\")"))
    #expect(widget.contains("private struct MediumStatusStrip: View"))
    #expect(widget.contains("MiniStatus(title: PulseDockWidgetStrings.miniThermal, value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState, for: colorScheme))"))
    #expect(widget.contains("MiniStatus(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: powerTint(snapshot, for: colorScheme))"))
    #expect(audit.contains("Medium widget left column uses a first-version-style CPU block with core summary and a compact status strip instead of stacking network detail text."))
    #expect(audit.contains("Source-level tests keep the medium widget from reintroducing crowded left-column network detail copy."))
}

@Test func widgetsOwnTheirContentMarginsInsteadOfUsingSystemDoubleInsets() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let configurationStart = try #require(widget.range(of: "StaticConfiguration(kind: kind, provider: SystemProvider())")?.lowerBound)
    let bundleStart = try #require(widget.range(of: "@main")?.lowerBound)
    let configuration = String(widget[configurationStart..<bundleStart])

    #expect(configuration.contains(".contentMarginsDisabled()"))
    #expect(widget.contains(".padding(.horizontal, 18)"))
    #expect(widget.contains(".padding(.vertical, 18)"))
    #expect(widget.contains(".padding(14)"))
    #expect(audit.contains("Widgets disable system content margins and own their family-specific padding, avoiding double-inset crowding while keeping the first-version composition."))
    #expect(audit.contains("Source-level tests require WidgetKit content margins to be disabled so medium widgets keep controlled breathing room."))
}

@Test func widgetHeadersAvoidTruncatedTitleAndVisibleTimeCrowding() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(widget.contains("CompactWidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName"))
    #expect(!widget.contains("CompactWidgetHeader(title: \"System\""))
    #expect(!widget.contains("WidgetHeader(title: \"System\", time: snapshot.timestamp)"))
    #expect(widget.contains("Spacer(minLength: 4)"))
    #expect(widget.contains(".accessibilityLabel(accessibilityLabel)"))
    #expect(widget.contains("private var accessibilityLabel: String"))
    #expect(!widget.contains(".accessibilityLabel(timeText == \"未报告\" ? title : \"\\(title), \\(timeText)\")"))
    #expect(dashboardView.contains("Text(\"Pulse Dock\")"))
    #expect(!dashboardView.contains("Text(\"System\")\n                    .font(.system(size: 14, weight: .semibold))"))
}

@Test func powerSourceTextUsesReportedPowerSourceBeforeChargingFlag() {
    let pluggedInFull = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: 1,
        batteryIsCharging: false,
        batteryPowerSource: "AC Power",
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    let battery = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: 0.7,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(pluggedInFull.powerSourceText == SharedMetricStrings.powerSourceAdapter)
    #expect(battery.powerSourceText == SharedMetricStrings.powerSourceBattery)
}

@Test func powerStatusTextUsesPowerSourceWhenBatteryPercentIsUnavailable() {
    let desktopPower = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "AC Power",
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    let portableBattery = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: 0.86,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(desktopPower.batteryPercentText == SharedMetricStrings.notReported)
    #expect(desktopPower.hasPowerStatusReport)
    #expect(desktopPower.powerSourceText == SharedMetricStrings.powerSourceAdapter)
    #expect(desktopPower.powerStatusText == SharedMetricStrings.powerSourceAdapter)
    #expect(portableBattery.hasPowerStatusReport)
    #expect(portableBattery.powerStatusText == "86%")
}

@Test func powerStatusProgressOnlyUsesMeasuredBatteryPercent() throws {
    let acPower = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "AC Power",
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let batteryPercent = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.1,
        thermalState: "Nominal",
        batteryPercent: 0.42,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    #expect(acPower.powerStatusProgress == nil)
    #expect(batteryPercent.powerStatusProgress == 0.42)
    #expect(MetricSnapshot.placeholder.powerStatusProgress == nil)
}

@Test func powerStatusToneUsesReportedPowerSourceWhenBatteryPercentIsUnavailable() throws {
    let acPower = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "AC Power",
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let batteryPower = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let upsPower = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "UPS Power",
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let unknownPower = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "External Power",
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let batteryPercent = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: 0.42,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        networkBytesPerSecond: 0,
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widgetView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let menuBarPopover = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(acPower.powerStatusTone == .normal)
    #expect(batteryPower.powerStatusTone == .warning)
    #expect(upsPower.powerStatusTone == .warning)
    #expect(unknownPower.powerStatusTone == .neutral)
    #expect(batteryPercent.powerStatusTone == .warning)
    #expect(MetricSnapshot.placeholder.powerStatusTone == .neutral)
    #expect(metricSnapshot.contains("public enum MetricStatusTone"))
    #expect(metricSnapshot.contains("public var powerStatusTone: MetricStatusTone"))
    #expect(dashboardView.contains("switch snapshot.powerStatusTone"))
    #expect(widgetView.contains("widgetToneColor(snapshot.powerStatusTone, for: colorScheme)"))
    #expect(menuBarPopover.contains("tint(for: snapshot.powerStatusTone)"))
    #expect(!dashboardView.contains("return snapshot.batteryPercent == nil ? DashboardColor.green : DashboardColor.amber"))
    #expect(!widgetView.contains("return snapshot.batteryPercent == nil ? WidgetColor.green : WidgetColor.amber"))
    #expect(!menuBarPopover.contains("return snapshot.batteryPercent == nil ? Palette.green : Palette.amber"))
    #expect(audit.contains("Power indicator tint uses the shared power-source tone mapping so high battery power remains normal, medium battery power is warning, low battery is critical, and source-only battery or UPS power without a percent remains warning-colored."))
    #expect(audit.contains("Source-level tests require app, widget, and menu bar power tints to use shared power-source tone mapping."))
}

@Test func missingPowerSourceUsesReportedStateInsteadOfNoBatteryAcrossSurfaces() throws {
    let snapshot = MetricSnapshot.placeholder
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(snapshot.batteryPercentText == SharedMetricStrings.notReported)
    #expect(snapshot.powerSourceText == SharedMetricStrings.notReported)
    #expect(snapshot.powerStatusText == SharedMetricStrings.notReported)
    #expect(!snapshot.hasPowerStatusReport)
    #expect(metricSnapshot.contains("return SharedMetricStrings.powerSourceExternal"))
    #expect(!metricSnapshot.contains("powerSourceNoBattery"))
    #expect(metricSnapshot.contains("public var batteryPercentText: String"))
    #expect(metricSnapshot.contains("public var hasPowerStatusReport: Bool"))
    #expect(metricSnapshot.contains("public var powerStatusProgress: Double?"))
    #expect(metricSnapshot.contains("public var powerStatusTone: MetricStatusTone"))
    #expect(!metricSnapshot.contains("public var batteryText: String"))
    #expect(metricSnapshot.contains("batteryPercent == nil ? powerSourceText : batteryPercentText"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, icon: \"battery.75percent\", status: powerStatusLevel(snapshot), source: snapshot.powerSourceText)"))
    #expect(dashboardView.contains("private func powerGaugeProgress(_ snapshot: MetricSnapshot) -> Double?"))
    #expect(dashboardView.contains("snapshot.powerStatusProgress"))
    #expect(dashboardView.contains("private func powerTint(_ snapshot: MetricSnapshot) -> Color"))
    #expect(dashboardView.contains("switch snapshot.powerStatusTone"))
    #expect(dashboardView.contains("private func powerStatusLevel(_ snapshot: MetricSnapshot) -> StatusLevel"))
    #expect(dashboardView.contains("RingGauge(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, progress: powerGaugeProgress(snapshot), tint: powerTint(snapshot))"))
    #expect(dashboardView.contains("let powerTrend = powerTrendValues(from: history)"))
    #expect(dashboardView.contains("TrendRow(title: powerTrendTitle(snapshot), value: snapshot.powerStatusText, tint: powerTint(snapshot), values: powerTrend)"))
    #expect(!dashboardView.contains("RingGauge(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, progress: powerGaugeProgress(snapshot), tint: DashboardColor.green)"))
    #expect(!dashboardView.contains("TrendRow(title: \"电量\", value: snapshot.batteryText, tint: DashboardColor.amber, values: history.compactMap(\\.batteryPercent))"))
    #expect(!dashboardView.contains("status: snapshot.batteryPercent == nil ? .neutral : .normal, source: snapshot.powerSourceText"))
    #expect(audit.contains("Missing power-source samples display as not-reported instead of being inferred as no battery"))
    #expect(audit.contains("Missing power-source indicators use neutral tint instead of healthy or warning colors"))
    #expect(audit.contains("History power trend uses the current power-status label and neutral tint when power-source data is missing"))
    #expect(audit.contains("Battery percentage text is separated from power status text so desktop and UPS power states are not mislabeled as battery readings."))
    #expect(audit.contains("Power reported state is centralized on the shared snapshot model instead of being inferred from user-facing text."))
    #expect(audit.contains("Source-level tests prevent absent power-source data from surfacing as a no-battery state"))
    #expect(audit.contains("Source-level tests prevent missing power-source state from using fixed healthy or warning tint"))
    #expect(audit.contains("Source-level tests prevent the shared snapshot model from exposing the old batteryText alias."))
    #expect(audit.contains("Source-level tests require power reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons."))
}

@Test func overviewPowerCardUsesCurrentPowerStatusText() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("MetricCard(title: PulseDockAppStrings.overviewPowerStatusTitle, value: snapshot.powerStatusText"))
    #expect(dashboardView.contains("progress: powerGaugeProgress(snapshot), values: powerTrend"))
    #expect(!dashboardView.contains("MetricCard(title: PulseDockAppStrings.overviewPowerStatusTitle, value: snapshot.batteryText"))
    #expect(!dashboardView.contains("progress: snapshot.batteryPercent ?? 0"))
}

@Test func powerTrendValuesUseMeasuredBatteryPercentOnly() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("private func powerTrendValues(from history: [MetricSnapshot]) -> [Double]"))
    #expect(dashboardView.contains("history.compactMap(\\.powerStatusProgress)"))
    #expect(!dashboardView.contains("private func powerTrendValue(_ snapshot: MetricSnapshot) -> Double?"))
    #expect(!dashboardView.contains("case \"battery power\":\n        return 0.45"))
    #expect(dashboardView.contains("let powerTrend = powerTrendValues(from: history)"))
    #expect(dashboardView.contains("MetricCard(title: PulseDockAppStrings.overviewPowerStatusTitle, value: snapshot.powerStatusText, detail: snapshot.powerSourceText, icon: \"battery.75percent\", tint: powerTint(snapshot), badgeText: snapshot.batteryPercent.map { MetricFormatting.percentage($0) }, progress: powerGaugeProgress(snapshot), values: powerTrend)"))
    #expect(dashboardView.contains("TrendRow(title: powerTrendTitle(snapshot), value: snapshot.powerStatusText, tint: powerTint(snapshot), values: powerTrend)"))
    #expect(!dashboardView.contains("values: history.compactMap(\\.batteryPercent)"))
    #expect(audit.contains("Power progress uses measured battery percent only; AC/UPS/source-only states are displayed as text without invented gauge fill."))
    #expect(audit.contains("Source-level tests require power trend charts and gauges to use measured battery percent only, leaving source-only AC/UPS states without invented fill."))
    #expect(!audit.contains("Power trend values use reported power-source state when battery percentage is unavailable, so desktop and UPS histories do not disappear."))
    #expect(!audit.contains("Power gauge progress uses the shared power-source state mapping instead of drawing every reported source without a battery percent as full."))
}

@Test func powerPageForegroundsCurrentPowerStatusWhenBatteryPercentIsUnavailable() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let powerStart = try #require(dashboardView.range(of: "private struct PowerPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct ProcessesPage")?.lowerBound)
    let powerPage = String(dashboardView[powerStart..<nextStart])

    #expect(powerPage.contains("RingGauge(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, progress: powerGaugeProgress(snapshot)"))
    #expect(!powerPage.contains("[snapshot.powerStatusTitle, snapshot.powerStatusText, snapshot.powerSourceText]"))
    #expect(powerPage.contains("[PulseDockAppStrings.batteryRemainingTimeLabel, snapshot.batteryTimeRemainingText, PulseDockAppStrings.sourceSystemEstimate]"))
    #expect(!powerPage.contains("RingGauge(title: \"电量\", value: snapshot.batteryText"))
    #expect(!powerPage.contains("[\"电量\", snapshot.batteryText, snapshot.powerSourceText]"))
}

@Test func statusSignalsUseCurrentPowerStatusWhenBatteryPercentIsUnavailable() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("SourceCapabilityCard(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, icon: \"battery.75percent\", status: powerStatusLevel(snapshot), source: snapshot.powerSourceText)"))
    #expect(!dashboardView.contains("[\"电池电量\", snapshot.batteryText, \"电源状态\"]"))
}

@Test func compactPowerSurfacesUseCurrentPowerStatusText() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widgetView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let menuBarPopover = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )

    #expect(widgetView.contains("MiniStatus(title: PulseDockWidgetStrings.miniPower, value: compactPowerStatusText(snapshot)"))
    #expect(widgetView.contains("MiniStatus(title: PulseDockWidgetStrings.miniPower, value: compactPowerStatusText(snapshot), tint: powerTint(snapshot, for: colorScheme))"))
    #expect(widgetView.contains("StatTile(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText"))
    #expect(widgetView.contains("StatTile(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: powerTint(snapshot, for: colorScheme))"))
    #expect(widgetView.contains("private func compactPowerStatusText(_ snapshot: MetricSnapshot) -> String"))
    #expect(widgetView.contains("private func powerTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color"))
    #expect(widgetView.contains("widgetToneColor(snapshot.powerStatusTone, for: colorScheme)"))
    #expect(!widgetView.contains("MiniStatus(title: PulseDockWidgetStrings.miniPower, value: snapshot.powerStatusText, tint: WidgetColor.amber)"))
    #expect(!widgetView.contains("StatTile(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: WidgetColor.green)"))
    #expect(!widgetView.contains("snapshot.batteryPowerSource == nil ? 0 : 1"))
    #expect(menuBarPopover.contains("PopoverSmallStat(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText"))
    #expect(menuBarPopover.contains("PopoverSmallStat(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: powerTint(snapshot))"))
    #expect(menuBarPopover.contains("private func powerTint(_ snapshot: MetricSnapshot) -> Color"))
    #expect(menuBarPopover.contains("tint(for: snapshot.powerStatusTone)"))
    #expect(!menuBarPopover.contains("PopoverSmallStat(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: Palette.green)"))
}

@Test func compactInventoryAndUptimeSurfacesUseNeutralTintWhenMissing() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widgetView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let menuBarPopover = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(menuBarPopover.contains("PopoverSmallStat(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, tint: reportedTint(hasReport: snapshot.hasDisplayReport, fallback: Palette.amber(for: colorScheme)))"))
    #expect(menuBarPopover.contains("PopoverSmallStat(title: PulseDockAppStrings.metricVolumes, value: snapshot.storageVolumeSummaryText, tint: reportedTint(hasReport: snapshot.hasStorageVolumeReport, fallback: Palette.blue(for: colorScheme)))"))
    #expect(!menuBarPopover.contains("PopoverSmallStat(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, tint: reportedTint(valueText: snapshot.displaySummaryText, fallback: Palette.amber))"))
    #expect(!menuBarPopover.contains("PopoverSmallStat(title: PulseDockAppStrings.metricVolumes, value: snapshot.storageVolumeSummaryText, tint: reportedTint(valueText: snapshot.storageVolumeSummaryText, fallback: Palette.blue))"))
    #expect(!menuBarPopover.contains("private func reportedTint(valueText: String, fallback: Color) -> Color"))
    #expect(!menuBarPopover.contains("guard valueText != \"未报告\" else { return Palette.cyan }"))
    #expect(!menuBarPopover.contains("PopoverSmallStat(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, tint: Palette.amber)"))
    #expect(!menuBarPopover.contains("PopoverSmallStat(title: PulseDockAppStrings.metricVolumes, value: snapshot.storageVolumeSummaryText, tint: Palette.blue)"))
    #expect(widgetView.contains("StatTile(title: PulseDockWidgetStrings.metricUptime, value: snapshot.uptimeText, tint: reportedTint(hasReport: snapshot.hasUptimeReport, fallback: WidgetColor.amber(for: colorScheme), for: colorScheme))"))
    #expect(widgetView.contains("private func reportedTint(hasReport: Bool, fallback: Color, for colorScheme: ColorScheme) -> Color"))
    #expect(!widgetView.contains("private func reportedTint(valueText: String, fallback: Color) -> Color"))
    #expect(!widgetView.contains("guard valueText != \"未报告\" else { return WidgetColor.cyan }"))
    #expect(!widgetView.contains("StatTile(title: PulseDockWidgetStrings.metricUptime, value: snapshot.uptimeText, tint: WidgetColor.amber)"))
    #expect(audit.contains("Compact inventory and uptime indicators use neutral tint when their sampled values are not reported"))
    #expect(audit.contains("Source-level tests prevent compact inventory and uptime indicators from showing healthy or warning tint when their values are missing"))
}

@Test func projectMetadataDoesNotExposeLegacyMonitorWidgetIdentity() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let package = try String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8)
    let resources = root.appendingPathComponent("Resources")
    let resourceNames = try FileManager.default.contentsOfDirectory(atPath: resources.path)

    #expect(package.contains("name: \"PulseDock\""))
    #expect(!package.contains("SystemMonitorWidget"))
    #expect(!resourceNames.contains("Info.plist"))
}

@Test func macOSAppIconIsDeclaredGeneratedAndPackaged() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appInfo = try String(contentsOf: root.appendingPathComponent("Resources/AppInfo.plist"), encoding: .utf8)
    let packageScript = try String(contentsOf: root.appendingPathComponent("scripts/package-app.sh"), encoding: .utf8)
    let generatorScript = try String(contentsOf: root.appendingPathComponent("scripts/generate-app-icon.swift"), encoding: .utf8)
    let xcodeProjectGenerator = try String(contentsOf: root.appendingPathComponent("scripts/generate-xcodeproj.rb"), encoding: .utf8)
    let iconPath = root.appendingPathComponent("Resources/AppIcon.icns")
    let largePNGPath = root.appendingPathComponent("Resources/AppIcon.iconset/icon_512x512@2x.png")

    #expect(appInfo.contains("<key>CFBundleIconFile</key>"))
    #expect(appInfo.contains("<string>AppIcon</string>"))
    #expect(generatorScript.contains("PulseGlyphIconRenderer"))
    #expect(generatorScript.contains("NSBitmapImageRep("))
    #expect(generatorScript.contains("pixelsWide: Int(pixelSize)"))
    #expect(generatorScript.contains("pixelsHigh: Int(pixelSize)"))
    #expect(generatorScript.contains("drawAquaRoundedBase()"))
    #expect(generatorScript.contains("drawDepthRim()"))
    #expect(generatorScript.contains("drawMonitorGlyph()"))
    #expect(generatorScript.contains("drawPulseWaveform()"))
    #expect(generatorScript.contains("drawDockShadow()"))
    #expect(packageScript.contains("scripts/generate-app-icon.swift"))
    #expect(xcodeProjectGenerator.contains("app_icon = resources_group.new_file(File.join(root, \"Resources/AppIcon.icns\"))"))
    #expect(xcodeProjectGenerator.contains("app_target.add_resources(shared_resource_files + app_resource_files + [app_privacy_manifest, app_icon])"))
    #expect(xcodeProjectGenerator.contains("widget_target.add_resources(shared_resource_files + widget_resource_files + [widget_privacy_manifest])"))
    #expect(!packageScript.contains("\"$APP_DIR/Contents/Resources/AppIcon.icns\""))
    #expect(FileManager.default.fileExists(atPath: iconPath.path))

    if let attributes = try? FileManager.default.attributesOfItem(atPath: iconPath.path),
       let size = attributes[.size] as? NSNumber {
        #expect(size.intValue > 10_000)
    } else {
        Issue.record("AppIcon.icns should be present as a non-empty generated icon resource")
    }

    let source = try #require(CGImageSourceCreateWithURL(largePNGPath as CFURL, nil))
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    #expect((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue == 1024)
    #expect((properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue == 1024)
}

@Test func widgetsAndMainWindowUseDynamicLightAndDarkAppearance() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(widget.contains("@Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("widgetBackgroundColors(for: colorScheme)"))
    #expect(widget.contains("widgetPanelFill(for: colorScheme)"))
    #expect(widget.contains("widgetPanelStroke(for: colorScheme)"))
    #expect(widget.contains("widgetPrimaryText(for: colorScheme)"))
    #expect(widget.contains("widgetSecondaryText(for: colorScheme)"))
    #expect(widget.contains("widgetTrackFill(for: colorScheme)"))
    #expect(widget.contains("colorScheme == .dark"))
    #expect(widgetPanel.contains("@Environment(\\.colorScheme) private var colorScheme"))
    #expect(widgetPanel.contains("popoverPanelFill(for: colorScheme)"))
    #expect(widgetPanel.contains("popoverPanelStroke(for: colorScheme)"))
    #expect(widgetPanel.contains("popoverPrimaryText(for: colorScheme)"))
    #expect(widgetPanel.contains("popoverSecondaryText(for: colorScheme)"))
    #expect(widgetPanel.contains("popoverTrackFill(for: colorScheme)"))
    #expect(widgetPanel.contains("colorScheme == .dark"))
    #expect(!widgetPanel.contains("Color.white.opacity(0.82)"))
    #expect(!widgetPanel.contains("Color.white.opacity(0.52)"))
    #expect(!widgetPanel.contains("Color.white.opacity(0.48)"))
    #expect(dashboardView.contains("@Environment(\\.colorScheme) private var colorScheme"))
    #expect(dashboardView.contains("windowBackdropColors(for: colorScheme)"))
    #expect(dashboardView.contains("colorScheme == .dark"))
    #expect(audit.contains("Menu bar popover adapts background, panel, track, and text colors for light and dark appearances."))
    #expect(audit.contains("Source-level tests require the menu bar popover to use dynamic light/dark appearance helpers instead of fixed light panel colors."))
}

@Test func dashboardWidgetPreviewUsesDynamicLightAndDarkAppearance() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let previewStart = try #require(dashboardView.range(of: "private struct WidgetMiniPreview")?.lowerBound)
    let ringStart = try #require(dashboardView.range(of: "private struct RingGauge")?.lowerBound)
    let widgetPreview = String(dashboardView[previewStart..<ringStart])

    #expect(widgetPreview.contains("@Environment(\\.colorScheme) private var colorScheme"))
    #expect(widgetPreview.contains("widgetPreviewBackgroundColors(for: colorScheme)"))
    #expect(widgetPreview.contains("widgetPreviewStroke(for: colorScheme)"))
    #expect(widgetPreview.contains("widgetPreviewShadow(for: colorScheme)"))
    #expect(widgetPreview.contains("widgetPreviewSecondaryText(for: colorScheme)"))
    #expect(dashboardView.contains("private func widgetPreviewBackgroundColors(for colorScheme: ColorScheme) -> [Color]"))
    #expect(dashboardView.contains("private func widgetPreviewStroke(for colorScheme: ColorScheme) -> Color"))
    #expect(dashboardView.contains("private func widgetPreviewShadow(for colorScheme: ColorScheme) -> Color"))
    #expect(dashboardView.contains("private func widgetPreviewSecondaryText(for colorScheme: ColorScheme) -> Color"))
    #expect(dashboardView.contains("colorScheme == .dark"))
    #expect(!widgetPreview.contains("Color.white.opacity(0.92)"))
    #expect(!widgetPreview.contains(".strokeBorder(.white.opacity(0.72), lineWidth: 1)"))
    #expect(!widgetPreview.contains(".foregroundStyle(.secondary)"))
    #expect(audit.contains("Dashboard widget preview adapts its background, stroke, shadow, and secondary text to light and dark appearances."))
    #expect(audit.contains("Source-level tests prevent the dashboard widget preview from using fixed light-only colors in dark mode."))
}

@Test func widgetMetricRingsAndTilesUseDynamicDarkModeColors() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let ringStart = widget.range(of: "private struct RingMetric")?.lowerBound ?? widget.startIndex
    let rowStart = widget.range(of: "private struct WidgetRow")?.lowerBound ?? widget.endIndex
    let ringMetric = String(widget[ringStart..<rowStart])
    let tileStart = widget.range(of: "private struct StatTile")?.lowerBound ?? widget.startIndex
    let backgroundStart = widget.range(of: "private struct WidgetBackground")?.lowerBound ?? widget.endIndex
    let statTile = String(widget[tileStart..<backgroundStart])

    #expect(ringMetric.contains(".stroke(widgetTrackFill(for: colorScheme), lineWidth: 6)"))
    #expect(!ringMetric.contains(".stroke(Color.secondary.opacity(0.15), lineWidth: 6)"))
    #expect(statTile.contains(".foregroundStyle(widgetSecondaryText(for: colorScheme))"))
    #expect(!statTile.contains(".foregroundStyle(.secondary)"))
    #expect(audit.contains("Widget metric rings and stat tiles use the shared light/dark track and secondary text helpers, so dark-mode contrast stays consistent across widget families."))
    #expect(audit.contains("Source-level tests require widget metric ring tracks and stat tile labels to use dynamic light/dark appearance helpers."))
}

@Test func widgetPlaceholderSkeletonUsesDynamicDarkModeColors() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let widgetTokens = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/WidgetVisualTokens.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let metricStart = try #require(widget.range(of: "private struct PlaceholderMetricSkeleton")?.lowerBound)
    let barStart = try #require(widget.range(of: "private struct PlaceholderBar")?.lowerBound)
    let metricSkeleton = String(widget[metricStart..<barStart])
    let dotStart = try #require(widget.range(of: "private struct PlaceholderDot")?.lowerBound)
    let headerStart = try #require(widget.range(of: "private struct WidgetHeader")?.lowerBound)
    let placeholderDot = String(widget[dotStart..<headerStart])

    #expect(metricSkeleton.contains("@Environment(\\.colorScheme) private var colorScheme"))
    #expect(metricSkeleton.contains(".stroke(widgetTrackFill(for: colorScheme), lineWidth: 6)"))
    #expect(metricSkeleton.contains(".fill(widgetPlaceholderFill(for: colorScheme))"))
    #expect(placeholderDot.contains("@Environment(\\.colorScheme) private var colorScheme"))
    #expect(placeholderDot.contains(".fill(widgetPlaceholderFill(for: colorScheme))"))
    #expect(widgetTokens.contains("func widgetPlaceholderFill(for colorScheme: ColorScheme) -> Color"))
    #expect(!metricSkeleton.contains(".stroke(Color.secondary.opacity(0.14), lineWidth: 6)"))
    #expect(!metricSkeleton.contains(".fill(Color.secondary.opacity(0.16))"))
    #expect(!placeholderDot.contains(".fill(Color.secondary.opacity(0.16))"))
    #expect(audit.contains("Widget placeholder skeletons use shared light/dark track and fill helpers so widget gallery previews do not retain fixed light-mode colors."))
    #expect(audit.contains("Source-level tests require WidgetKit placeholder skeleton tracks and fills to use dynamic light/dark helpers."))
}

@Test func appStoreMetadataAvoidsUnusedAppGroupConfiguration() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let paths = [
        "Resources/AppInfo.plist",
        "Resources/WidgetInfo.plist",
        "scripts/package-app.sh",
        "scripts/generate-xcodeproj.rb"
    ]

    for path in paths {
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        #expect(!text.contains("AppGroupIdentifier"))
        #expect(!text.contains("APP_GROUP_IDENTIFIER"))
    }
}

@Test func appStoreVersionMetadataUsesArchiveBuildSettings() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appInfo = try String(contentsOf: root.appendingPathComponent("Resources/AppInfo.plist"), encoding: .utf8)
    let widgetInfo = try String(contentsOf: root.appendingPathComponent("Resources/WidgetInfo.plist"), encoding: .utf8)
    let projectGenerator = try String(contentsOf: root.appendingPathComponent("scripts/generate-xcodeproj.rb"), encoding: .utf8)
    let xcodeProject = try String(contentsOf: root.appendingPathComponent("PulseDock.xcodeproj/project.pbxproj"), encoding: .utf8)
    let audit = try String(contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"), encoding: .utf8)

    for plist in [appInfo, widgetInfo] {
        #expect(plist.contains("<key>CFBundleShortVersionString</key>"))
        #expect(plist.contains("<string>$(MARKETING_VERSION)</string>"))
        #expect(plist.contains("<key>CFBundleVersion</key>"))
        #expect(plist.contains("<string>$(CURRENT_PROJECT_VERSION)</string>"))
    }

    #expect(projectGenerator.contains("marketing_version = ENV.fetch(\"MARKETING_VERSION\", \"1.0.0\")"))
    #expect(projectGenerator.contains("current_project_version = ENV.fetch(\"CURRENT_PROJECT_VERSION\", \"1\")"))
    #expect(projectGenerator.contains("settings[\"MARKETING_VERSION\"] = marketing_version"))
    #expect(projectGenerator.contains("settings[\"CURRENT_PROJECT_VERSION\"] = current_project_version"))
    #expect(xcodeProject.contains("MARKETING_VERSION = 1.0.0;"))
    #expect(xcodeProject.contains("CURRENT_PROJECT_VERSION = 1;"))
    #expect(audit.contains("App and Widget version metadata use shared Xcode build settings so App Store archives keep matching marketing and build versions."))
    #expect(audit.contains("Source-level tests require App Store version metadata to come from archive build settings instead of hard-coded plist literals."))
}

@Test func appStoreSigningCanReceiveDevelopmentTeamFromEnvironment() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let projectGenerator = try String(contentsOf: root.appendingPathComponent("scripts/generate-xcodeproj.rb"), encoding: .utf8)
    let packageScript = try String(contentsOf: root.appendingPathComponent("scripts/package-app.sh"), encoding: .utf8)
    let xcodeProject = try String(contentsOf: root.appendingPathComponent("PulseDock.xcodeproj/project.pbxproj"), encoding: .utf8)
    let audit = try String(contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"), encoding: .utf8)

    #expect(projectGenerator.contains("development_team = ENV.fetch(\"DEVELOPMENT_TEAM\", \"\")"))
    #expect(projectGenerator.contains("settings[\"DEVELOPMENT_TEAM\"] = development_team"))
    #expect(!projectGenerator.contains("settings[\"DEVELOPMENT_TEAM\"] = \"\""))
    #expect(packageScript.contains("DEVELOPMENT_TEAM=\"${DEVELOPMENT_TEAM:-}\""))
    #expect(packageScript.contains("if [[ -n \"$DEVELOPMENT_TEAM\" ]]; then"))
    #expect(packageScript.contains("BUILD_SETTINGS+=(DEVELOPMENT_TEAM=\"$DEVELOPMENT_TEAM\")"))
    #expect(xcodeProject.contains("DEVELOPMENT_TEAM = \"\";"))
    #expect(audit.contains("Generated Xcode projects and local packaging accept DEVELOPMENT_TEAM from the environment for Apple-managed signing while keeping the default unset for local unsigned builds."))
    #expect(audit.contains("Source-level tests require App Store signing metadata to be parameterized through DEVELOPMENT_TEAM instead of being fixed in scripts."))
}

@Test func packageScriptPassesArchiveMetadataToProjectGenerationAndBuild() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let packageScript = try String(contentsOf: root.appendingPathComponent("scripts/package-app.sh"), encoding: .utf8)
    let audit = try String(contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"), encoding: .utf8)

    #expect(packageScript.contains("MARKETING_VERSION=\"${MARKETING_VERSION:-1.0.0}\""))
    #expect(packageScript.contains("CURRENT_PROJECT_VERSION=\"${CURRENT_PROJECT_VERSION:-1}\""))
    #expect(packageScript.contains("APP_BUNDLE_IDENTIFIER=\"$APP_BUNDLE_IDENTIFIER\" \\"))
    #expect(packageScript.contains("WIDGET_BUNDLE_IDENTIFIER=\"$WIDGET_BUNDLE_IDENTIFIER\" \\"))
    #expect(packageScript.contains("MARKETING_VERSION=\"$MARKETING_VERSION\" \\"))
    #expect(packageScript.contains("CURRENT_PROJECT_VERSION=\"$CURRENT_PROJECT_VERSION\" \\"))
    #expect(packageScript.contains("DEVELOPMENT_TEAM=\"$DEVELOPMENT_TEAM\" \\"))
    #expect(packageScript.contains("scripts/generate-xcodeproj.rb"))
    #expect(packageScript.contains("restore_default_project()"))
    #expect(packageScript.contains("trap restore_default_project EXIT"))
    #expect(packageScript.contains("APP_BUNDLE_IDENTIFIER=\"com.ifonly3.pulsedock\" \\"))
    #expect(packageScript.contains("BUILD_SETTINGS+=(MARKETING_VERSION=\"$MARKETING_VERSION\")"))
    #expect(packageScript.contains("BUILD_SETTINGS+=(CURRENT_PROJECT_VERSION=\"$CURRENT_PROJECT_VERSION\")"))
    #expect(audit.contains("Local packaging forwards bundle identifiers, version metadata, and DEVELOPMENT_TEAM to both Xcode project generation and xcodebuild, keeping generated project files and archive build settings aligned."))
    #expect(audit.contains("Local packaging restores the tracked Xcode project to default production bundle identifiers after local bundle-id builds."))
    #expect(audit.contains("Source-level tests require local packaging to pass App Store archive metadata through both project generation and xcodebuild."))
}

@Test func appStoreArchiveScriptSeparatesSignedArchiveAndExportFlow() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let archiveScriptURL = root.appendingPathComponent("scripts/archive-app-store.sh")
    let archiveScript = try String(contentsOf: archiveScriptURL, encoding: .utf8)
    let audit = try String(contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"), encoding: .utf8)

    #expect(FileManager.default.fileExists(atPath: archiveScriptURL.path))
    #expect(archiveScript.contains("require_env APP_BUNDLE_IDENTIFIER"))
    #expect(archiveScript.contains("require_env DEVELOPMENT_TEAM"))
    #expect(archiveScript.contains("WIDGET_BUNDLE_IDENTIFIER=\"${WIDGET_BUNDLE_IDENTIFIER:-$APP_BUNDLE_IDENTIFIER.widget}\""))
    #expect(archiveScript.contains("MARKETING_VERSION=\"${MARKETING_VERSION:-1.0.0}\""))
    #expect(archiveScript.contains("CURRENT_PROJECT_VERSION=\"${CURRENT_PROJECT_VERSION:-1}\""))
    #expect(archiveScript.contains("ARCHIVE_PATH=\"${ARCHIVE_PATH:-$ROOT_DIR/dist/PulseDock.xcarchive}\""))
    #expect(archiveScript.contains("EXPORT_PATH=\"${EXPORT_PATH:-$ROOT_DIR/dist/AppStore}\""))
    #expect(archiveScript.contains("method"))
    #expect(archiveScript.contains("app-store-connect"))
    #expect(archiveScript.contains("teamID"))
    #expect(archiveScript.contains("<string>$DEVELOPMENT_TEAM</string>"))
    #expect(archiveScript.contains("xcodebuild \\"))
    #expect(archiveScript.contains("-project PulseDock.xcodeproj"))
    #expect(archiveScript.contains("-scheme PulseDock"))
    #expect(archiveScript.contains(" archive"))
    #expect(archiveScript.contains("-destination 'generic/platform=macOS'"))
    #expect(archiveScript.contains("-archivePath \"$ARCHIVE_PATH\""))
    #expect(archiveScript.contains("-exportArchive"))
    #expect(archiveScript.contains("-exportOptionsPlist \"$EXPORT_OPTIONS_PLIST\""))
    #expect(archiveScript.contains("ALLOW_PROVISIONING_UPDATES=\"${ALLOW_PROVISIONING_UPDATES:-YES}\""))
    #expect(audit.contains("App Store archive/export uses a dedicated script that requires production bundle identifiers and DEVELOPMENT_TEAM, then runs Xcode archive and export with App Store Connect export options."))
    #expect(audit.contains("Source-level tests require App Store archive/export to stay separate from local ad-hoc packaging."))
}

@Test func mainWindowCanBeRestoredAfterCloseOrDockReopen() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )

    #expect(appDelegate.contains("isReleasedWhenClosed = false"))
    #expect(appDelegate.contains("makeKeyAndOrderFront"))
    #expect(appDelegate.contains("applicationShouldHandleReopen"))
}

@Test func menuPopoverActionsAreInteractive() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )

    #expect(!widgetPanel.contains("ActionPill("))
    #expect(widgetPanel.contains("Button(action: openDashboard)"))
    #expect(widgetPanel.contains("Button(action: togglePause)"))
    #expect(widgetPanel.contains("Button(action: openSettings)"))
    #expect(widgetPanel.contains("PopoverActionLabel(icon: \"macwindow\", title: PulseDockAppStrings.menuOpenMainWindow)"))
    #expect(widgetPanel.contains("isPaused ? PulseDockAppStrings.menuResumeRefresh : PulseDockAppStrings.menuPauseRefresh"))
    #expect(widgetPanel.contains("PopoverActionLabel(icon: \"gearshape\", title: PulseDockAppStrings.menuSettings)"))
    #expect(metricsStore.contains("@Published private(set) var isPaused"))
    #expect(metricsStore.contains("func togglePause()"))
    #expect(metricsStore.contains("guard !isPaused else { return }"))
    #expect(metricsStore.contains("guard refreshTask == nil else"))
    #expect(metricsStore.contains("pendingRefreshAfterCurrent = true"))
    #expect(metricsStore.contains("refreshTask?.cancel()"))
}

@Test func menuPopoverSurfacesLoadAverageInsteadOfDuplicateSampleTile() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricLoad, value: snapshot.loadText, tint: reportedTint(hasReport: snapshot.hasLoadAverageReport, fallback: Palette.green(for: colorScheme)))"))
    #expect(!widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricLoad, value: snapshot.loadText, tint: reportedTint(valueText: snapshot.loadText, fallback: Palette.green))"))
    #expect(!widgetPanel.contains("PopoverSmallStat(title: \"采样\", value: snapshot.sampleTimeText"))
    #expect(audit.contains("Menu bar popover surfaces the sampled load average instead of duplicating the header sample timestamp."))
    #expect(audit.contains("Source-level tests require the menu bar popover to surface load average with reported-state tinting."))
}

@Test func menuPopoverSurfacesUptimeAndKernelVersionSignals() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, tint: reportedTint(hasReport: snapshot.hasUptimeReport, fallback: Palette.amber(for: colorScheme)))"))
    #expect(widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricKernel, value: snapshot.kernelText, tint: reportedTint(hasReport: snapshot.hasKernelReleaseReport, fallback: Palette.cyan(for: colorScheme)))"))
    #expect(widgetPanel.contains("private func reportedTint(hasReport: Bool, fallback: Color) -> Color"))
    #expect(!widgetPanel.contains("private func reportedTint(valueText: String, fallback: Color) -> Color"))
    #expect(!widgetPanel.contains("guard valueText != \"未报告\" else { return Palette.cyan }"))
    #expect(!widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricKernel, value: snapshot.kernelText, tint: reportedTint(valueText: snapshot.kernelText, fallback: Palette.cyan))"))
    #expect(!widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, tint: Palette.amber)"))
    #expect(!widgetPanel.contains("PopoverSmallStat(title: PulseDockAppStrings.metricKernel, value: snapshot.kernelText, tint: Palette.cyan)"))
    #expect(audit.contains("| System uptime and version | Time elapsed since system boot, OS version string, and Darwin kernel release, formatted on-device | System boot time via `ProcessInfo.systemUptime`, OS version via `ProcessInfo`, and Darwin kernel release via `uname.release` | Overview, Status page, History page, Settings page, widgets, menu bar popover |"))
    #expect(audit.contains("Menu bar popover surfaces uptime and Darwin kernel release with explicit snapshot reported-state tinting."))
    #expect(audit.contains("Source-level tests require the menu bar popover to surface uptime and Darwin kernel release with explicit snapshot reported-state tinting."))
}

@Test func menuPopoverUsesStableFixedSizeBeforeShowing() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(appDelegate.contains("private var menuPopoverSize: NSSize"))
    #expect(appDelegate.contains("NSSize(width: MenuPopoverLayout.width, height: MenuPopoverLayout.height)"))
    #expect(appDelegate.contains("popover.animates = true"))
    #expect(appDelegate.contains("hostingController.sizingOptions = []"))
    #expect(appDelegate.contains("hostingController.preferredContentSize = contentSize"))
    #expect(appDelegate.contains("popover.contentSize = menuPopoverSize"))
    #expect(appDelegate.contains("layoutSubtreeIfNeeded()"))
    #expect(appDelegate.contains("popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)"))
    #expect(appDelegate.contains("private func statusButtonAnchorRect("))
    #expect(appDelegate.contains("placement: MenuBarPopoverGeometry.Placement,"))
    #expect(appDelegate.contains("anchorFrame: NSRect?"))
    #expect(widgetPanel.contains("frame(width: popoverWidth, height: popoverHeight, alignment: .topLeading)"))
    #expect(widgetPanel.contains("enum MenuPopoverLayout"))
    #expect(widgetPanel.contains("static let width: CGFloat = 356"))
    #expect(widgetPanel.contains("static let height: CGFloat = 520"))
    #expect(audit.contains("Source-level tests require the menu bar popover to use a fixed content size, matching preferred content size, enabled AppKit animation, and a bounded status-button anchor"))
    #expect(audit.contains("Source-level tests require the menu bar popover to pin SwiftUI hosting size and layout before showing with a fresh hidden hosting controller"))
}

@Test func menuPopoverChoosesVisibleScreenEdgeAndScrollableContentBeforeShowing() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(appDelegate.contains("private func prepareStatusPopover(_ popover: NSPopover, for button: NSStatusBarButton) -> StatusPopoverPresentation"))
    #expect(appDelegate.contains("let presentation = prepareStatusPopover(popover, for: button)"))
    #expect(appDelegate.contains("popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)"))
    #expect(appDelegate.contains("private func statusPopoverPlacement(\n        for button: NSStatusBarButton,"))
    #expect(appDelegate.contains("visibleFrame: NSRect?"))
    #expect(appDelegate.contains("anchorFrame: NSRect?"))
    #expect(!appDelegate.contains("private func statusPopoverSize(for button: NSStatusBarButton) -> NSSize"))
    #expect(!appDelegate.contains("private func statusPopoverPreferredEdge(for button: NSStatusBarButton, contentSize: NSSize) -> NSRectEdge"))
    #expect(appDelegate.contains("button.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame"))
    #expect(appDelegate.contains("window.convertToScreen(button.convert(button.bounds, to: nil))"))
    #expect(appDelegate.contains("MenuPopoverLayout.minimumHeight"))
    #expect(appDelegate.contains("MenuPopoverLayout.screenMargin"))
    #expect(widgetPanel.contains("ScrollView(showsIndicators: false)"))
    #expect(widgetPanel.contains("frame(width: popoverWidth, height: popoverHeight, alignment: .topLeading)"))
    #expect(widgetPanel.contains("static let minimumHeight: CGFloat"))
    #expect(widgetPanel.contains("static let screenMargin: CGFloat"))
    #expect(audit.contains("Menu bar popover chooses a visible screen edge and clamps height before showing, with scrollable content for smaller visible areas."))
    #expect(audit.contains("Source-level tests require the menu bar popover to choose a visible screen edge, clamp content height, and keep smaller popovers scrollable before showing."))
}

@Test func menuPopoverGeometryClampsStatusBarPlacementFromAnchorFrame() throws {
    let placement = MenuBarPopoverGeometry.placement(
        preferredSize: CGSize(width: 356, height: 520),
        minimumHeight: 420,
        screenMargin: 12,
        visibleFrame: CGRect(x: 0, y: 48, width: 1440, height: 392),
        anchorFrame: CGRect(x: 1110, y: 424, width: 72, height: 24),
        anchorKind: .statusBar
    )
    let regularPlacement = MenuBarPopoverGeometry.placement(
        preferredSize: CGSize(width: 356, height: 520),
        minimumHeight: 420,
        screenMargin: 12,
        visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 500),
        anchorFrame: CGRect(x: 360, y: 80, width: 72, height: 24),
        anchorKind: .regular
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(placement.preferredEdge == .minY)
    #expect(placement.availableHeight == 336)
    #expect(placement.size == CGSize(width: 356, height: 336))
    #expect(regularPlacement.preferredEdge == .maxY)
    #expect(regularPlacement.availableHeight == 356)
    #expect(regularPlacement.size == CGSize(width: 356, height: 356))
    #expect(appDelegate.contains("private func statusPopoverPlacement(\n        for button: NSStatusBarButton,"))
    #expect(appDelegate.contains("MenuBarPopoverGeometry.placement("))
    #expect(appDelegate.contains("anchorFrame: anchorFrame"))
    #expect(appDelegate.contains("anchorKind: statusPopoverAnchorKind(for: button)"))
    #expect(audit.contains("Menu bar popover placement uses a tested geometry helper that clamps status-bar popovers from the actual anchor frame before showing."))
    #expect(audit.contains("Source-level tests execute menu bar popover geometry for top status-bar anchors and shorter visible screens."))
}

@Test func menuPopoverPassesClampedWidthIntoSwiftUIContent() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let widgetPanel = try fixture("Sources/PulseDockApp/WidgetPanelView.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(widgetPanel.contains("let popoverWidth: CGFloat"))
    #expect(widgetPanel.contains(".frame(width: popoverWidth, height: popoverHeight, alignment: .topLeading)"))
    #expect(!widgetPanel.contains(".frame(width: MenuPopoverLayout.width, height: popoverHeight, alignment: .topLeading)"))
    #expect(appDelegate.contains("makeWidgetPanelView(popoverWidth: CGFloat, popoverHeight: CGFloat)"))
    #expect(appDelegate.contains("makeStatusHostingController(contentSize: NSSize)"))
    #expect(appDelegate.contains("WidgetPanelView("))
    #expect(appDelegate.contains("popoverWidth: contentSize.width"))
    #expect(audit.contains("Menu bar popover passes geometry-clamped width and height into SwiftUI before showing."))
}

@Test func menuPopoverGeometryClampsNarrowVisibleWidth() {
    let placement = MenuBarPopoverGeometry.placement(
        preferredSize: CGSize(width: 356, height: 520),
        minimumHeight: 420,
        screenMargin: 12,
        visibleFrame: CGRect(x: 0, y: 48, width: 300, height: 860),
        anchorFrame: CGRect(x: 252, y: 884, width: 32, height: 24),
        anchorKind: .statusBar
    )

    #expect(placement.size.width == 276)
    #expect(placement.anchorScreenMidX == 150)
}

@Test func menuPopoverReservesChromeAndConstrainsActualWindowFrame() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let geometry = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MenuBarPopoverGeometry.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(geometry.contains("private static let popoverChromeHeightAllowance: CGFloat = 28"))
    #expect(geometry.contains("let availableHeightAfterChrome = rawAvailableHeight - popoverChromeHeightAllowance"))
    #expect(geometry.contains("public static func constrainedWindowFrame("))
    #expect(geometry.contains("let constrainedWidth = min(proposedFrame.width, availableFrame.width)"))
    #expect(geometry.contains("let constrainedHeight = min(proposedFrame.height, availableFrame.height)"))
    #expect(!appDelegate.contains("constrainStatusPopoverWindow(popover, for: button, presentation: presentation)"))
    #expect(!appDelegate.contains("private func constrainStatusPopoverWindow"))
    #expect(!appDelegate.contains("window.setFrame(constrainedFrame"))
    #expect(audit.contains("Menu bar popover reserves non-content popover chrome before sizing and does not move the AppKit popover window after showing."))
    #expect(audit.contains("Source-level tests require the menu bar popover to reserve popover chrome before showing without clamping the shown window frame."))
}

@Test func menuPopoverUsesPreparedPlacementForInitialShowAndFitsClampedContent() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let toggleStart = appDelegate.range(of: "@objc private func toggleStatusPopover")?.lowerBound ?? appDelegate.startIndex
    let prepareStart = appDelegate.range(of: "private func prepareStatusPopover")?.lowerBound ?? appDelegate.endIndex
    let toggleBody = String(appDelegate[toggleStart..<prepareStart])
    let showStart = appDelegate.range(of: "private func showPreparedStatusPopover")?.lowerBound ?? appDelegate.startIndex
    let showBody = String(appDelegate[showStart..<prepareStart])

    #expect(appDelegate.contains("private struct StatusPopoverPresentation"))
    #expect(appDelegate.contains("let presentation = prepareStatusPopover(popover, for: button)"))
    #expect(showBody.contains("popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)"))
    #expect(!showBody.contains("setFrame("))
    #expect(appDelegate.contains("private func statusButtonAnchorRect("))
    #expect(appDelegate.contains("anchorRect: statusButtonAnchorRect(button, placement: placement, anchorFrame: anchorFrame)"))
    #expect(!toggleBody.contains("statusButtonAnchorRect(button), of: button"))
    #expect(!appDelegate.contains("private func fitStatusPopoverContent"))
    #expect(audit.contains("Menu bar popover computes one placement before showing and reuses it for content size, preferred edge, and bounded anchor rect."))
    #expect(audit.contains("Source-level tests require menu bar popover content height to be finalized before `show` instead of shrinking after AppKit creates the popover window."))
}

@Test func menuPopoverRefitsWindowAfterClampedContentHeightChanges() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    #expect(!appDelegate.contains("private func constrainStatusPopoverWindow"))
    #expect(!appDelegate.contains("private func fitStatusPopoverContent"))
    #expect(!appDelegate.contains("window.setFrame(constrainedFrame"))
    #expect(!appDelegate.contains("heightDelta = max(0, window.frame.height - constrainedFrame.height)"))
    #expect(audit.contains("Menu bar popover relies on pre-show content sizing instead of post-show window fitting, keeping the AppKit arrow and status item anchor synchronized."))
    #expect(audit.contains("Source-level tests require the menu bar popover to avoid post-show window frame refits that desynchronize the arrow."))
}

@Test func menuPopoverGeometryHorizontallyClampsStatusBarAnchorBeforeShowing() throws {
    let placement = MenuBarPopoverGeometry.placement(
        preferredSize: CGSize(width: 356, height: 520),
        minimumHeight: 420,
        screenMargin: 12,
        visibleFrame: CGRect(x: 0, y: 48, width: 1440, height: 860),
        anchorFrame: CGRect(x: 1400, y: 884, width: 32, height: 24),
        anchorKind: .statusBar
    )
    let centeredPlacement = MenuBarPopoverGeometry.placement(
        preferredSize: CGSize(width: 356, height: 520),
        minimumHeight: 420,
        screenMargin: 12,
        visibleFrame: CGRect(x: 0, y: 48, width: 1440, height: 860),
        anchorFrame: CGRect(x: 684, y: 884, width: 72, height: 24),
        anchorKind: .statusBar
    )
    let narrowPlacement = MenuBarPopoverGeometry.placement(
        preferredSize: CGSize(width: 356, height: 520),
        minimumHeight: 420,
        screenMargin: 12,
        visibleFrame: CGRect(x: 0, y: 48, width: 300, height: 860),
        anchorFrame: CGRect(x: 252, y: 884, width: 32, height: 24),
        anchorKind: .statusBar
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(placement.anchorScreenMidX == 1250)
    #expect(centeredPlacement.anchorScreenMidX == 720)
    #expect(narrowPlacement.anchorScreenMidX == 150)
    #expect(narrowPlacement.size.width == 276)
    #expect(appDelegate.contains("placement.anchorScreenMidX"))
    #expect(appDelegate.contains("let proposedAnchorCenterX"))
    #expect(appDelegate.contains("min(max(proposedAnchorCenterX"))
    #expect(!appDelegate.contains("anchorCenterX += anchorScreenMidX - buttonFrame.midX"))
    #expect(audit.contains("Menu bar popover clamps the status-button positioning rect within button-local coordinates before showing, so edge-of-screen clamping cannot move the arrow onto neighboring menu extras."))
    #expect(audit.contains("Source-level tests require status popover geometry to clamp any screen-derived anchor adjustment back into button-local coordinates."))
}

@Test func menuPopoverTreatsStatusBarWindowAsTopAnchoredBeforeShowing() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(appDelegate.contains("private func statusPopoverAnchorKind(for button: NSStatusBarButton) -> MenuBarPopoverGeometry.AnchorKind"))
    #expect(appDelegate.contains("isStatusBarAnchorWindow(button.window) ? .statusBar : .regular"))
    #expect(appDelegate.contains("preferredEdge: placement.preferredEdge.nsRectEdge"))
    #expect(audit.contains("Menu bar popover treats the NSStatusBar window as a fixed top anchor, always opening downward while clamping height from the actual anchor frame and visible screen."))
    #expect(audit.contains("Source-level tests require the menu bar popover to bypass dynamic edge inference for NSStatusBar windows."))
}

@Test func menuPopoverTreatsStatusBarLevelOrHigherAnchorWindowsAsTopAnchored() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(appDelegate.contains("private func isStatusBarAnchorWindow(_ window: NSWindow?) -> Bool"))
    #expect(appDelegate.contains("window.level.rawValue >= NSWindow.Level.statusBar.rawValue"))
    #expect(appDelegate.contains("private func statusPopoverAnchorKind(for button: NSStatusBarButton) -> MenuBarPopoverGeometry.AnchorKind"))
    #expect(appDelegate.contains("isStatusBarAnchorWindow(button.window) ? .statusBar : .regular"))
    #expect(appDelegate.contains("preferredEdge: placement.preferredEdge.nsRectEdge"))
    #expect(!appDelegate.contains("if button.window?.level == .statusBar, let visibleFrame = statusPopoverVisibleFrame(for: button)"))
    #expect(!appDelegate.contains("guard button.window?.level != .statusBar else { return .minY }"))
    #expect(audit.contains("Menu bar popover treats status-bar-level or higher anchor windows as fixed top anchors, so menu extra window-level differences cannot trigger transient off-screen edge calculation."))
    #expect(audit.contains("Source-level tests require the menu bar popover to treat status-bar-level or higher anchor windows as top anchored."))
}

@Test func menuPopoverPinsRootViewHeightBeforeShowing() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(appDelegate.contains("private func makeWidgetPanelView(popoverWidth: CGFloat, popoverHeight: CGFloat) -> WidgetPanelView"))
    #expect(appDelegate.contains("private func makeStatusHostingController(contentSize: NSSize) -> NSHostingController<WidgetPanelView>"))
    #expect(!appDelegate.contains("let hostingController = makeStatusHostingController(popoverHeight: menuPopoverSize.height)"))
    #expect(appDelegate.contains("installFreshStatusHostingController(contentSize, in: popover)"))
    #expect(widgetPanel.contains("let popoverWidth: CGFloat"))
    #expect(widgetPanel.contains("let popoverHeight: CGFloat"))
    #expect(widgetPanel.contains("frame(width: popoverWidth, height: popoverHeight, alignment: .topLeading)"))
    #expect(appDelegate.contains("hostingController.view.frame = NSRect(origin: .zero, size: contentSize)"))
    #expect(audit.contains("Menu bar popover pins a fresh SwiftUI root view to the computed content height before showing."))
    #expect(audit.contains("Source-level tests require the menu bar popover root view height to match the computed content height before showing."))
}

@Test func menuPopoverRebuildsSizedHostingControllerBeforeEachShow() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let prepareStart = appDelegate.range(of: "private func prepareStatusPopover")?.lowerBound ?? appDelegate.startIndex
    let sizeStart = appDelegate.range(of: "private func statusPopoverSize")?.lowerBound ?? appDelegate.endIndex
    let prepareBody = String(appDelegate[prepareStart..<sizeStart])

    #expect(appDelegate.contains("private func makeStatusHostingController(contentSize: NSSize) -> NSHostingController<WidgetPanelView>"))
    #expect(prepareBody.contains("installFreshStatusHostingController(contentSize, in: popover)"))
    #expect(!prepareBody.contains("updateStatusHostingControllerSize(contentSize)"))
    #expect(appDelegate.contains("private func resetStatusPopoverContentHost()"))
    #expect(appDelegate.contains("popoverDidClose"))
    #expect(appDelegate.contains("resetStatusPopoverContentHost()"))
    #expect(audit.contains("Menu bar popover installs a fresh hosting controller before each show and releases it after close, avoiding stale second-open layout state without replacing content after `show`."))
    #expect(audit.contains("Source-level tests require the menu bar popover to rebuild its hidden hosting controller before showing and release it after close."))
}

@Test func menuPopoverUsesStableStatusItemLengthWhileCPUTitleRefreshes() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(appDelegate.contains("private enum MenuBarStatusItemLayout"))
    #expect(appDelegate.contains("static let compactLength = NSStatusItem.squareLength"))
    #expect(appDelegate.contains("static let cpuTitleLength: CGFloat"))
    #expect(appDelegate.contains("private var statusButtonCPUText: String?"))
    #expect(appDelegate.contains("guard store.snapshot.hasCPUUsageReport else { return nil }"))
    #expect(appDelegate.contains("guard let cpuText = statusButtonCPUText else"))
    #expect(appDelegate.contains("statusItem?.length = MenuBarStatusItemLayout.cpuTitleLength"))
    #expect(appDelegate.contains("statusItem?.button?.title = \" \\(cpuText)\""))
    #expect(appDelegate.contains("store.$snapshot.combineLatest(store.$showsMenuBarCPU)"))
    #expect(appDelegate.contains("self?.updateStatusButtonTitle()"))
    #expect(audit.contains("Menu bar status item uses stable fixed lengths so live CPU title refreshes do not move the popover anchor while it is shown."))
    #expect(audit.contains("Source-level tests require the menu bar status item to keep a stable length while the live CPU title refreshes."))
}

@Test func menuPopoverDoesNotActivateAppAfterShowingStatusPopover() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let toggleStart = appDelegate.range(of: "@objc private func toggleStatusPopover")?.lowerBound ?? appDelegate.startIndex
    let prepareStart = appDelegate.range(of: "private func prepareStatusPopover")?.lowerBound ?? appDelegate.endIndex
    let toggleBody = String(appDelegate[toggleStart..<prepareStart])

    #expect(toggleBody.contains("popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)"))
    #expect(!toggleBody.contains("NSApp.activate"))
    #expect(appDelegate.contains("private func showDashboardWindow(activating: Bool)"))
    #expect(appDelegate.contains("NSApp.activate()"))
    #expect(!appDelegate.contains("NSApp.activate(ignoringOtherApps: true)"))
    #expect(audit.contains("Menu bar popover shows without activating the main app, avoiding a second window-ordering pass after the popover is positioned."))
    #expect(audit.contains("Source-level tests prevent status popover opening from calling app activation after showing the popover."))
}

@Test func menuPopoverHidesWindowUntilFinalFrameIsConstrained() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let toggleStart = appDelegate.range(of: "@objc private func toggleStatusPopover")?.lowerBound ?? appDelegate.startIndex
    let prepareStart = appDelegate.range(of: "private func prepareStatusPopover")?.lowerBound ?? appDelegate.endIndex
    let toggleBody = String(appDelegate[toggleStart..<prepareStart])
    let showBody: String
    if let showStart = appDelegate.range(of: "private func showPreparedStatusPopover")?.lowerBound,
       showStart <= prepareStart {
        showBody = String(appDelegate[showStart..<prepareStart])
    } else {
        showBody = ""
    }

    #expect(toggleBody.contains("showPreparedStatusPopover(popover, for: button, presentation: presentation)"))
    #expect(!toggleBody.contains("popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)\n            constrainStatusPopoverWindow(popover, for: button, presentation: presentation)"))
    #expect(showBody.contains("popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)"))
    #expect(!showBody.contains("window.alphaValue = 0"))
    #expect(!showBody.contains("constrainStatusPopoverWindow(popover, for: button, presentation: presentation)"))
    #expect(showBody.contains("popover.contentViewController?.view.window?.contentView?.layoutSubtreeIfNeeded()"))
    #expect(!showBody.contains("window.displayIfNeeded()"))
    #expect(!showBody.contains("window.alphaValue = originalAlphaValue"))
    #expect(audit.contains("Menu bar popover prepares size and bounded button-local anchor before showing and never moves the AppKit popover window after `show`, keeping the arrow aligned."))
    #expect(audit.contains("Source-level tests require the menu bar popover to avoid hiding content as a workaround for post-show window movement."))
}

@Test func menuPopoverHidesContentBeforeInitialShowFrameIsRendered() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let showBody: String
    if let showStart = appDelegate.range(of: "private func showPreparedStatusPopover")?.lowerBound,
       let prepareStart = appDelegate.range(of: "private func prepareStatusPopover")?.lowerBound,
       showStart <= prepareStart {
        showBody = String(appDelegate[showStart..<prepareStart])
    } else {
        showBody = ""
    }

    let showRange = showBody.range(of: "popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)")

    #expect(!appDelegate.contains("private struct HiddenStatusPopoverContent"))
    #expect(!appDelegate.contains("private func hideStatusPopoverContentBeforeShowing"))
    #expect(!appDelegate.contains("private func restoreStatusPopoverContentAfterShowing"))
    #expect(!appDelegate.contains("view.alphaValue = 0"))
    #expect(!appDelegate.contains("hiddenContent.view.alphaValue = hiddenContent.alphaValue"))
    #expect(showRange != nil)
    #expect(audit.contains("Menu bar popover prepares size and bounded button-local anchor before showing and never moves the AppKit popover window after `show`, keeping the arrow aligned."))
    #expect(audit.contains("Source-level tests require the menu bar popover to avoid hiding content as a workaround for post-show window movement."))
}

@Test func statusPopoverClosesWithoutTransientToggleRace() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let audit = try fixture("docs/data-capability-audit.md")
    let toggleStart = appDelegate.range(of: "@objc private func toggleStatusPopover")?.lowerBound ?? appDelegate.startIndex
    let showStart = appDelegate.range(of: "private func showPreparedStatusPopover")?.lowerBound ?? appDelegate.endIndex
    let toggleBody = String(appDelegate[toggleStart..<showStart])

    #expect(appDelegate.contains("final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate"))
    #expect(appDelegate.contains("private var isStatusPopoverClosing = false"))
    #expect(appDelegate.contains("private var statusPopoverSuppressToggleUntil: Date?"))
    #expect(appDelegate.contains("private enum StatusPopoverTiming"))
    #expect(appDelegate.contains("static let closeToggleSuppressionInterval: TimeInterval = 0.25"))
    #expect(appDelegate.contains("StatusPopoverTiming.closeToggleSuppressionInterval"))
    #expect(appDelegate.contains("popover.delegate = self"))
    #expect(appDelegate.contains("popover.animates = true"))
    #expect(toggleBody.contains("shouldSuppressStatusPopoverToggle()"))
    #expect(toggleBody.contains("closeStatusPopover(popover)"))
    #expect(appDelegate.contains("private func closeStatusPopover(_ popover: NSPopover)"))
    #expect(appDelegate.contains("func popoverWillClose(_ notification: Notification)"))
    #expect(appDelegate.contains("func popoverDidClose(_ notification: Notification)"))
    #expect(!appDelegate.contains("private let statusPopoverToggleSuppressionInterval: TimeInterval = 0.25"))
    #expect(!appDelegate.contains("performClose"))
    #expect(audit.contains("Menu bar popover tracks transient close events and suppresses same-click reopen races when the status item is clicked to close."))
}

@Test func statusPopoverShowsFromPreparedAnchorWithoutMovingWindowAfterShow() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let audit = try fixture("docs/data-capability-audit.md")
    let showStart = appDelegate.range(of: "private func showPreparedStatusPopover")?.lowerBound ?? appDelegate.startIndex
    let prepareStart = appDelegate.range(of: "private func prepareStatusPopover")?.lowerBound ?? appDelegate.endIndex
    let showBody = String(appDelegate[showStart..<prepareStart])

    #expect(showBody.contains("popover.show(relativeTo: presentation.anchorRect, of: button, preferredEdge: presentation.preferredEdge)"))
    #expect(!appDelegate.contains("private func constrainStatusPopoverWindow"))
    #expect(!appDelegate.contains("private func fitStatusPopoverContent"))
    #expect(!appDelegate.contains("window.setFrame(constrainedFrame"))
    #expect(!showBody.contains("setFrame("))
    #expect(appDelegate.contains("let visibleFrame = statusPopoverVisibleFrame(for: button)"))
    #expect(appDelegate.contains("let anchorFrame = statusButtonScreenFrame(button)"))
    #expect(appDelegate.contains("statusPopoverPlacement(for: button, visibleFrame: visibleFrame, anchorFrame: anchorFrame)"))
    #expect(appDelegate.contains("let proposedAnchorCenterX"))
    #expect(appDelegate.contains("min(max(proposedAnchorCenterX"))
    #expect(!appDelegate.contains("anchorCenterX += anchorScreenMidX - buttonFrame.midX"))
    #expect(audit.contains("Menu bar popover prepares size and bounded button-local anchor before showing and never moves the AppKit popover window after `show`, keeping the arrow aligned."))
}

@Test func statusPopoverRebuildsHostAndAvoidsStatusWindowRelayoutForSecondOpen() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let audit = try fixture("docs/data-capability-audit.md")
    let prepareStart = appDelegate.range(of: "private func prepareStatusPopover")?.lowerBound ?? appDelegate.startIndex
    let placementStart = appDelegate.range(of: "private func statusPopoverPlacement")?.lowerBound ?? appDelegate.endIndex
    let prepareBody = String(appDelegate[prepareStart..<placementStart])

    #expect(appDelegate.contains("private func installFreshStatusHostingController(_ contentSize: NSSize, in popover: NSPopover)"))
    #expect(prepareBody.contains("installFreshStatusHostingController(contentSize, in: popover)"))
    #expect(appDelegate.contains("private func resetStatusPopoverContentHost()"))
    #expect(appDelegate.contains("statusPopover?.contentViewController = nil"))
    #expect(appDelegate.contains("statusHostingController = nil"))
    #expect(!appDelegate.contains("button.window?.layoutIfNeeded()"))
    #expect(audit.contains("Menu bar popover rebuilds its hidden hosting controller for each show cycle and avoids forcing layout on the system status-bar window before calculating the frame."))
}

@Test func popoverDarkModeUsesCoolMaterialPaletteWithoutBrownOverlay() throws {
    let widgetPanel = try fixture("Sources/PulseDockApp/WidgetPanelView.swift")
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let visualEffect = try fixture("Sources/PulseDockApp/VisualEffectView.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(!widgetPanel.contains("Color(red: 0.17, green: 0.13, blue: 0.07)"))
    #expect(!dashboard.contains("Color(red: 0.12, green: 0.09, blue: 0.06)"))
    #expect(widgetPanel.contains("static func green(for colorScheme: ColorScheme) -> Color"))
    #expect(widgetPanel.contains("Palette.green(for: colorScheme)"))
    #expect(!widgetPanel.contains("VisualEffectView(material: .popover"))
    #expect(!widgetPanel.contains("popoverBackgroundColors(for: colorScheme)"))
    #expect(visualEffect.contains("var appearanceName: NSAppearance.Name?"))
    #expect(visualEffect.contains("view.isEmphasized = isEmphasized"))
    #expect(visualEffect.contains("nsView.appearance = appearanceName.flatMap(NSAppearance.init(named:))"))
    #expect(audit.contains("Menu bar popover dark appearance uses cool dynamic card colors without drawing a second root material or brown overlay stops."))
}

@Test func appDelegateCoalescesStatusTitleUpdatesAndStartsStoreOnMainActor() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(!appDelegate.contains("DispatchQueue.main.async"))
    #expect(appDelegate.contains("store.start()"))
    #expect(appDelegate.contains("store.$snapshot.combineLatest(store.$showsMenuBarCPU)"))
    #expect(appDelegate.contains("private var statusButtonCPUText: String?"))
    #expect(appDelegate.contains("guard let cpuText = statusButtonCPUText else"))
    #expect(!appDelegate.contains("store.showsMenuBarCPU ? \" \\(store.snapshot.cpuText)\" : \"\""))
    #expect(audit.contains("Menu bar title updates are coalesced from snapshot and CPU-title preference changes, and missing CPU samples keep the status item icon-only."))
}

@Test func metricsStoreInvalidatesTimerOnDeinit() throws {
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(metricsStore.contains("deinit {"))
    #expect(metricsStore.contains("timer?.invalidate()"))
    #expect(metricsStore.contains("initialRefreshTask?.cancel()"))
    #expect(metricsStore.contains("refreshTask?.cancel()"))
    #expect(audit.contains("MetricsStore invalidates timers and cancels refresh tasks during deinitialization as a final lifecycle backstop."))
}

@Test func installScriptVerifiesWidgetRegistrationBeforeReturning() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let installScript = try String(
        contentsOf: root.appendingPathComponent("scripts/install-system-widget.sh"),
        encoding: .utf8
    )

    #expect(installScript.contains("wait_for_widget_registration()"))
    #expect(installScript.contains("pluginkit -m -A -D -v -i \"$WIDGET_BUNDLE_IDENTIFIER\""))
    #expect(installScript.contains("grep -F \"$WIDGET_EXTENSION\""))
}

@Test func packageScriptSeparatesReleaseBuildFromLocalAdhocSigning() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let packageScript = try String(
        contentsOf: root.appendingPathComponent("scripts/package-app.sh"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(packageScript.contains("PACKAGE_CONFIGURATION=\"${PACKAGE_CONFIGURATION:-Release}\""))
    #expect(packageScript.contains("PACKAGE_SIGNING_MODE=\"${PACKAGE_SIGNING_MODE:-adhoc}\""))
    #expect(packageScript.contains("case \"$PACKAGE_SIGNING_MODE\" in"))
    #expect(packageScript.contains("-configuration \"$PACKAGE_CONFIGURATION\""))
    #expect(packageScript.contains("BUILD_SETTINGS=("))
    #expect(packageScript.contains("BUILD_SETTINGS+=(CODE_SIGNING_ALLOWED=NO)"))
    #expect(packageScript.contains("Build/Products/$PACKAGE_CONFIGURATION/Pulse Dock.app"))
    #expect(packageScript.contains("if [[ \"$PACKAGE_SIGNING_MODE\" == \"adhoc\" ]]; then"))
    #expect(audit.contains("Local packaging uses a Release build with ad-hoc signing only for on-device testing"))
    #expect(audit.contains("App Store signing should use the generated Xcode project with Apple-managed signing"))
}

@Test func packageScriptUsesDeterministicDerivedDataPath() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let packageScript = try String(
        contentsOf: root.appendingPathComponent("scripts/package-app.sh"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(packageScript.contains("PACKAGE_DERIVED_DATA_PATH=\"${PACKAGE_DERIVED_DATA_PATH:-$ROOT_DIR/.build/package-derived-data}\""))
    #expect(packageScript.contains("-derivedDataPath \"$PACKAGE_DERIVED_DATA_PATH\""))
    #expect(packageScript.contains("BUILT_APP=\"$PACKAGE_DERIVED_DATA_PATH/Build/Products/$PACKAGE_CONFIGURATION/Pulse Dock.app\""))
    #expect(!packageScript.contains("SystemDashboard-dajnlerkpyejjkavcmyhiyskuhsc"))
    #expect(!packageScript.contains("find \"$HOME/Library/Developer/Xcode/DerivedData\""))
    #expect(audit.contains("Local packaging uses a deterministic derived-data directory so built app discovery does not depend on user-specific Xcode DerivedData hashes."))
    #expect(audit.contains("Source-level tests prevent local packaging from depending on user-specific DerivedData hash paths."))
}

@Test func storageSamplerUsesPublicImportantAvailableCapacityWhenReported() throws {
    let invalidImportantAvailableVolume = StorageVolumeMetric(
        index: 0,
        fileSystem: "apfs",
        totalBytes: 1_024,
        availableBytes: 512,
        importantAvailableBytes: 2_048,
        isInternal: true,
        isRemovable: false,
        isEjectable: false,
        isPrimary: true
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(invalidImportantAvailableVolume.availableText == "512 B")
    #expect(sampler.contains(".volumeAvailableCapacityForImportantUsageKey"))
    #expect(metricSnapshot.contains("public var reportedAvailableBytes: UInt64?"))
    #expect(sampler.contains("primary.reportedAvailableBytes.map { (free: $0, total: primary.totalBytes) }"))
    #expect(!sampler.contains("let disk = storage.primary.map { (free: $0.importantAvailableBytes ?? $0.availableBytes, total: $0.totalBytes) }"))
    #expect(sampler.contains("importantAvailableBytes: values.volumeAvailableCapacityForImportantUsage.map { UInt64(max($0, 0)) }"))
    #expect(dashboardView.contains("volume.availableText"))
    #expect(metricSnapshot.contains("let availableBytes = importantAvailableBytes ?? self.availableBytes"))
    #expect(audit.contains("important usage available capacity"))
    #expect(audit.contains("Primary disk sampling uses the same sanitized important-available capacity fallback as per-volume display"))
}

@Test func storageInventoryDoesNotStoreMountPaths() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public struct StorageVolumeMetric"))
    #expect(metricSnapshot.contains("public var id: Int { index }"))
    #expect(metricSnapshot.contains("public var index: Int"))
    #expect(!metricSnapshot.contains("mountPoint"))
    #expect(!sampler.contains("StorageVolumeMetric(\n                name:"))
}

@Test func storageInventoryAvoidsUserDefinedVolumeNames() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(!metricSnapshot.contains("primaryVolumeName"))
    #expect(!metricSnapshot.contains("public struct StorageVolumeMetric: Codable, Equatable, Sendable, Identifiable {\n    public var id: Int { index }\n    public var index: Int\n    public var name: String"))
    #expect(!metricSnapshot.contains("name = try values.decodeIfPresent(String.self, forKey: .name) ?? \"Volume\""))
    #expect(!sampler.contains(".volumeNameKey"))
    #expect(!sampler.contains(".volumeLocalizedNameKey"))
    #expect(!sampler.contains("volumeName"))
    #expect(!sampler.contains("volumeLocalizedName"))
    #expect(!sampler.contains("lastPathComponent"))
    #expect(metricSnapshot.contains("public var isPrimary: Bool"))
    #expect(sampler.contains("metric.isPrimary = metric.index == primaryIndex"))
    #expect(dashboardView.contains("volumeLabel(volume)"))
    #expect(!dashboardView.contains("snapshot.primaryVolumeName"))
    #expect(!dashboardView.contains("volume.name"))
}

@Test func storagePageShowsPerVolumeUsedBytesAndUsage() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var usedBytes: UInt64"))
    #expect(metricSnapshot.contains("public var usage: Double"))
    #expect(metricSnapshot.contains("public var totalBytes: UInt64"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.storageVolumeTableColumns"))
    #expect(dashboardView.contains("volume.totalText"))
    #expect(dashboardView.contains("volume.usedText"))
    #expect(dashboardView.contains("volume.availableText"))
    #expect(dashboardView.contains("volume.usageText"))
    #expect(audit.contains("per-volume total bytes, used bytes, and usage percentage"))
}

@Test func storagePageUsesSharedVolumeKindAndAccessTextWithoutVolumeNames() throws {
    let removableVolume = StorageVolumeMetric(
        index: 0,
        fileSystem: "apfs",
        totalBytes: 1024,
        availableBytes: 512,
        importantAvailableBytes: nil,
        isInternal: false,
        isRemovable: true,
        isEjectable: false,
        isReadOnly: true,
        hasKindReport: true,
        hasAccessReport: true
    )
    let ejectableVolume = StorageVolumeMetric(
        index: 1,
        fileSystem: "apfs",
        totalBytes: 1024,
        availableBytes: 512,
        importantAvailableBytes: nil,
        isInternal: false,
        isRemovable: false,
        isEjectable: true,
        hasKindReport: true,
        hasAccessReport: true
    )
    let internalVolume = StorageVolumeMetric(
        index: 2,
        fileSystem: "apfs",
        totalBytes: 1024,
        availableBytes: 512,
        importantAvailableBytes: nil,
        isInternal: true,
        isRemovable: false,
        isEjectable: false,
        hasKindReport: true,
        hasAccessReport: true
    )
    let externalVolume = StorageVolumeMetric(
        index: 3,
        fileSystem: "apfs",
        totalBytes: 1024,
        availableBytes: 512,
        importantAvailableBytes: nil,
        isInternal: false,
        isRemovable: false,
        isEjectable: false,
        hasKindReport: true,
        hasAccessReport: true
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let sharedStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SharedMetricStrings.swift"),
        encoding: .utf8
    )
    let english = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )
    let chinese = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )
    let expectedEntries = [
        (symbol: "storageKindRemovable", key: "shared_metrics.storage.kind.removable", english: "Removable", chinese: "可移除"),
        (symbol: "storageKindEjectable", key: "shared_metrics.storage.kind.ejectable", english: "Ejectable", chinese: "可弹出"),
        (symbol: "storageKindInternal", key: "shared_metrics.storage.kind.internal", english: "Internal", chinese: "内置"),
        (symbol: "storageKindExternal", key: "shared_metrics.storage.kind.external", english: "External", chinese: "外置"),
        (symbol: "storageAccessReadOnly", key: "shared_metrics.storage.access.read_only", english: "Read-only", chinese: "只读"),
        (symbol: "storageAccessWritable", key: "shared_metrics.storage.access.writable", english: "Writable", chinese: "可写")
    ]

    for entry in expectedEntries {
        #expect(sharedStrings.contains("static var \(entry.symbol): String"))
        #expect(sharedStrings.contains("localized(\"\(entry.key)\", defaultValue: \"\(entry.english)\")"))
        #expect(english.contains("\"\(entry.key)\" = \"\(entry.english)\";"))
        #expect(chinese.contains("\"\(entry.key)\" = \"\(entry.chinese)\";"))
        #expect(metricSnapshot.contains("SharedMetricStrings.\(entry.symbol)"))
    }

    #expect(removableVolume.kindText == SharedMetricStrings.localized("shared_metrics.storage.kind.removable", defaultValue: "Removable"))
    #expect(ejectableVolume.kindText == SharedMetricStrings.localized("shared_metrics.storage.kind.ejectable", defaultValue: "Ejectable"))
    #expect(internalVolume.kindText == SharedMetricStrings.localized("shared_metrics.storage.kind.internal", defaultValue: "Internal"))
    #expect(externalVolume.kindText == SharedMetricStrings.localized("shared_metrics.storage.kind.external", defaultValue: "External"))
    #expect(removableVolume.accessText == SharedMetricStrings.localized("shared_metrics.storage.access.read_only", defaultValue: "Read-only"))
    #expect(internalVolume.accessText == SharedMetricStrings.localized("shared_metrics.storage.access.writable", defaultValue: "Writable"))
    #expect(metricSnapshot.contains("public var isReadOnly: Bool"))
    #expect(metricSnapshot.contains("public var kindText: String"))
    #expect(metricSnapshot.contains("public var accessText: String"))
    #expect(sampler.contains(".volumeIsReadOnlyKey"))
    #expect(sampler.contains("isReadOnly: values.volumeIsReadOnly ?? false"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.storageVolumeTableColumns"))
    #expect(dashboardView.contains("volume.kindText"))
    #expect(dashboardView.contains("volume.accessText"))
    #expect(!dashboardView.contains("volumeKindText(volume)"))
    #expect(!dashboardView.contains("volumeAccessText(volume)"))
    #expect(!dashboardView.contains("private func volumeKindText(_ volume: StorageVolumeMetric) -> String"))
    #expect(!dashboardView.contains("private func volumeAccessText(_ volume: StorageVolumeMetric) -> String"))
    #expect(!dashboardView.contains("volume.name"))
    #expect(audit.contains("Storage volume kind and access display text is centralized on the shared volume model"))
    #expect(audit.contains("Source-level tests require Storage page volume kind and access labels to come from the shared model"))
    #expect(audit.contains("read-only state"))
    #expect(audit.contains("volumeIsReadOnly"))
}

@Test func legacyStorageVolumeMissingKindAndAccessDoesNotInventExternalWritableState() throws {
    let decodedVolume = try JSONDecoder().decode(StorageVolumeMetric.self, from: Data("""
    {
      "index": 0,
      "fileSystem": "apfs",
      "totalBytes": 1024,
      "availableBytes": 512
    }
    """.utf8))
    var snapshot = MetricSnapshot.placeholder
    snapshot.storageVolumes = [decodedVolume]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(decodedVolume.kindText == SharedMetricStrings.notReported)
    #expect(decodedVolume.accessText == SharedMetricStrings.notReported)
    #expect(!snapshot.hasExternalStorageVolumeSummaryReport)
    #expect(snapshot.externalStorageVolumeSummaryText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasKindReport: Bool"))
    #expect(metricSnapshot.contains("public var hasAccessReport: Bool"))
    #expect(metricSnapshot.contains("public var hasExternalStorageVolumeSummaryReport: Bool"))
    #expect(metricSnapshot.contains("guard hasKindReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("guard hasAccessReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("public var isExternalVolume: Bool"))
    #expect(metricSnapshot.contains("reportedVolumes.allSatisfy(\\.hasKindReport)"))
    #expect(metricSnapshot.contains("reportedVolumes.filter(\\.isExternalVolume).count"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.storageExternalVolumesTitle, value: snapshot.externalStorageVolumeSummaryText, icon: \"externaldrive.connected.to.line.below\", status: snapshot.hasExternalStorageVolumeSummaryReport ? .normal : .neutral"))
    #expect(sampler.contains("hasKindReport: values.volumeIsInternal != nil || values.volumeIsRemovable == true || values.volumeIsEjectable == true"))
    #expect(sampler.contains("hasAccessReport: values.volumeIsReadOnly != nil"))
    #expect(audit.contains("Legacy storage volume snapshots missing kind or access flags remain not-reported instead of being displayed as external writable volumes or zero external-volume counts."))
    #expect(audit.contains("Source-level tests prevent legacy storage volume kind and access flags from inventing external writable state."))
    #expect(audit.contains("Source-level tests prevent legacy storage volume kind fields from inventing zero external-volume summaries."))
}

@Test func initializerStorageVolumeCapacityOnlyDoesNotInventExternalWritableState() throws {
    let capacityOnlyVolume = StorageVolumeMetric(
        index: 0,
        fileSystem: "apfs",
        totalBytes: 4_096,
        availableBytes: 1_024,
        importantAvailableBytes: nil,
        isInternal: false,
        isRemovable: false,
        isEjectable: false
    )
    var snapshot = MetricSnapshot.placeholder
    snapshot.storageVolumes = [capacityOnlyVolume]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(capacityOnlyVolume.totalText == "4.0 KB")
    #expect(capacityOnlyVolume.availableText == "1.0 KB")
    #expect(capacityOnlyVolume.kindText == SharedMetricStrings.notReported)
    #expect(capacityOnlyVolume.accessText == SharedMetricStrings.notReported)
    #expect(!capacityOnlyVolume.isExternalVolume)
    #expect(!snapshot.hasExternalStorageVolumeSummaryReport)
    #expect(snapshot.externalStorageVolumeSummaryText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("hasKindReport: Bool = false"))
    #expect(metricSnapshot.contains("hasAccessReport: Bool = false"))
    #expect(!metricSnapshot.contains("hasKindReport: Bool = true"))
    #expect(!metricSnapshot.contains("hasAccessReport: Bool = true"))
    #expect(audit.contains("StorageVolumeMetric initializer defaults kind and access to not-reported when only volume capacity is provided."))
    #expect(audit.contains("Source-level tests prevent capacity-only storage volume snapshots from inventing external writable state."))
}

@Test func storageKindReportFalseSuppressesResidualRemovableFlags() throws {
    let residualFlagsVolume = StorageVolumeMetric(
        index: 0,
        fileSystem: "apfs",
        totalBytes: 4_096,
        availableBytes: 2_048,
        importantAvailableBytes: nil,
        isInternal: false,
        isRemovable: true,
        isEjectable: true,
        hasKindReport: false,
        hasAccessReport: true,
        isPrimary: false
    )
    var snapshot = MetricSnapshot.placeholder
    snapshot.storageVolumes = [residualFlagsVolume]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(residualFlagsVolume.kindText == SharedMetricStrings.notReported)
    #expect(!residualFlagsVolume.isExternalVolume)
    #expect(!snapshot.hasExternalStorageVolumeSummaryReport)
    #expect(snapshot.externalStorageVolumeSummaryText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var kindText: String {\n        guard hasKindReport else { return SharedMetricStrings.notReported }\n        if isRemovable"))
    #expect(metricSnapshot.contains("public var isExternalVolume: Bool {\n        guard hasKindReport else { return false }\n        if isRemovable"))
    #expect(audit.contains("Storage volume kind text and external-volume classification ignore residual removable/ejectable flags when kind state was not reported."))
    #expect(audit.contains("Source-level tests prevent explicit missing storage kind state from surfacing residual removable/ejectable flags."))
}

@Test func storageFileSystemUsesReportedStateInsteadOfUnknownFallback() throws {
    let missingFileSystem = try JSONDecoder().decode(StorageVolumeMetric.self, from: Data("""
    {
      "index": 0,
      "totalBytes": 1024,
      "availableBytes": 512,
      "isInternal": true,
      "isRemovable": false,
      "isEjectable": false
    }
    """.utf8))
    let blankFileSystem = StorageVolumeMetric(
        index: 1,
        fileSystem: "   ",
        totalBytes: 1024,
        availableBytes: 512,
        importantAvailableBytes: nil,
        isInternal: true,
        isRemovable: false,
        isEjectable: false
    )
    let legacyUnknownFileSystem = StorageVolumeMetric(
        index: 2,
        fileSystem: "unknown",
        totalBytes: 1024,
        availableBytes: 512,
        importantAvailableBytes: nil,
        isInternal: true,
        isRemovable: false,
        isEjectable: false
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingFileSystem.fileSystem == SharedMetricStrings.notReported)
    #expect(blankFileSystem.fileSystem == SharedMetricStrings.notReported)
    #expect(legacyUnknownFileSystem.fileSystem == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("private static func reportedFileSystemName(_ fileSystem: String?) -> String"))
    #expect(metricSnapshot.contains("fileSystem = Self.reportedFileSystemName(try values.decodeIfPresent(String.self, forKey: .fileSystem))"))
    #expect(metricSnapshot.contains("return SharedMetricStrings.reportedTextOrNotReported(trimmed == \"unknown\" ? nil : trimmed)"))
    #expect(!metricSnapshot.contains("fileSystem = try values.decodeIfPresent(String.self, forKey: .fileSystem) ?? \"unknown\""))
    #expect(sampler.contains("guard statfs(path, &stats) == 0 else { return SharedMetricStrings.notReported }"))
    #expect(!sampler.contains("guard statfs(path, &stats) == 0 else { return \"unknown\" }"))
    #expect(audit.contains("Storage file-system display text reports missing or legacy unknown values as not-reported"))
    #expect(audit.contains("Source-level tests prevent missing storage file-system names from surfacing as unknown"))
}

@Test func userFacingTextAvoidsInternalOrPlaceholderLanguage() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let paths = [
        "Sources/SharedMetrics/MetricSnapshot.swift",
        "Sources/PulseDockApp/DashboardView.swift",
        "Sources/PulseDockApp/WidgetPanelView.swift",
        "Sources/PulseDockWidget/SystemDashboardWidget.swift"
    ]
    let blockedTerms = ["N/A", "示例数据", "越权", "合规", "无公开", "未知", "等待下一次采样", "等待路径更新"]

    for path in paths {
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        for term in blockedTerms {
            #expect(!text.contains(term))
        }
    }
}

@Test func thermalDisplayTextUsesReportedStateInsteadOfRawUnknownAcrossSurfaces() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var thermalText: String"))
    #expect(metricSnapshot.contains("public var canonicalThermalState: ThermalState"))
    #expect(metricSnapshot.contains("case .nominal: return SharedMetricStrings.thermalStateNominal"))
    #expect(metricSnapshot.contains("case .unknown: return SharedMetricStrings.notReported"))
    #expect(dashboardView.contains("snapshot.thermalText"))
    #expect(!dashboardView.contains("localizedThermal(snapshot.thermalState)"))
    #expect(dashboardView.contains("statusLevel(for: ThermalState(raw: state).metricStatusTone)"))
    #expect(dashboardView.contains("snapshot.thermalLimitText"))
    #expect(dashboardView.contains("private var thermalColor: Color {\n        thermalStatus(snapshot.thermalState).color"))
    #expect(!dashboardView.contains("default: DashboardColor.green"))
    #expect(widgetPanel.contains("value: snapshot.thermalText"))
    #expect(widgetPanel.contains("tint(for: ThermalState(raw: state).metricStatusTone)"))
    #expect(!widgetPanel.contains("default: Palette.cyan"))
    #expect(!widgetPanel.contains("default: Palette.green"))
    #expect(!widgetPanel.contains("thermalText(snapshot.thermalState)"))
    #expect(widget.contains("value: snapshot.thermalText"))
    #expect(widget.contains("widgetToneColor(ThermalState(raw: state).metricStatusTone, for: colorScheme)"))
    #expect(!widget.contains("default: WidgetColor.cyan(for: colorScheme)"))
    #expect(!widget.contains("default: WidgetColor.green"))
    #expect(!widget.contains("thermalText(snapshot.thermalState)"))
    #expect(audit.contains("Thermal display text is centralized on the shared snapshot model"))
    #expect(audit.contains("Missing thermal-state indicators use neutral tint instead of green across dashboard, menu bar, and widget surfaces"))
    #expect(audit.contains("Source-level tests prevent raw thermal unknown states from reaching dashboard, menu bar, or widget surfaces"))
    #expect(audit.contains("Source-level tests prevent missing thermal state from using healthy green indicators"))
    var reportedThermal = MetricSnapshot.placeholder
    reportedThermal.thermalState = "Nominal"
    #expect(reportedThermal.hasThermalStateReport)
    #expect(!MetricSnapshot.placeholder.hasThermalStateReport)
    #expect(metricSnapshot.contains("public var hasThermalStateReport: Bool"))
    #expect(metricSnapshot.contains("let hasThermalReport = hasThermalStateReport"))
    #expect(!metricSnapshot.contains("let hasThermalReport = thermalText != \"未报告\""))
    #expect(audit.contains("Thermal reported state is centralized on the shared snapshot model instead of being inferred from user-facing text."))
    #expect(audit.contains("Source-level tests require thermal reported-state checks to use an explicit snapshot flag instead of user-facing text comparisons."))
}

@Test func thermalLimitDisplayTextUsesSharedSnapshotModel() throws {
    var criticalSnapshot = MetricSnapshot.placeholder
    criticalSnapshot.thermalState = "Critical"
    var hotSnapshot = MetricSnapshot.placeholder
    hotSnapshot.thermalState = "Hot"
    var warmSnapshot = MetricSnapshot.placeholder
    warmSnapshot.thermalState = "Warm"
    var nominalSnapshot = MetricSnapshot.placeholder
    nominalSnapshot.thermalState = "Nominal"
    var unknownSnapshot = MetricSnapshot.placeholder
    unknownSnapshot.thermalState = "Unknown"

    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(criticalSnapshot.thermalLimitText == SharedMetricStrings.thermalLimitCritical)
    #expect(hotSnapshot.thermalLimitText == SharedMetricStrings.thermalLimitHot)
    #expect(warmSnapshot.thermalLimitText == SharedMetricStrings.thermalLimitWarm)
    #expect(nominalSnapshot.thermalLimitText == SharedMetricStrings.thermalLimitNominal)
    #expect(unknownSnapshot.thermalLimitText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var thermalLimitText: String"))
    #expect(dashboardView.contains("StatusSummaryRow(title: PulseDockAppStrings.statusPerformanceLimitTitle, value: snapshot.thermalLimitText"))
    #expect(!dashboardView.contains("thermalLimitText(snapshot.thermalState)"))
    #expect(!dashboardView.contains("private func thermalLimitText(_ state: String) -> String"))
    #expect(audit.contains("Thermal limit display text is centralized on the shared snapshot model."))
    #expect(audit.contains("Source-level tests require thermal limit labels to come from the shared snapshot model."))
}

@Test func thermalGaugeSuppressesMissingThermalStateInsteadOfDrawingNominalProgress() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let metricStateContracts = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricStateContracts.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!dashboardView.contains("private func thermalProgress(_ state: String) -> Double?"))
    #expect(metricStateContracts.contains("case .unknown:\n            return nil"))
    #expect(!dashboardView.contains("default: nil"))
    #expect(dashboardView.contains("RingGauge(title: PulseDockAppStrings.statusThermalTitle, value: snapshot.thermalText, progress: ThermalState(raw: snapshot.thermalState).progress, tint: thermalStatus(snapshot.thermalState).color)"))
    #expect(!dashboardView.contains("private func thermalProgress(_ state: String) -> Double {"))
    #expect(!dashboardView.contains("default: 0.24"))
    #expect(audit.contains("Thermal gauge progress suppresses filled arcs when thermal state is not reported, instead of drawing missing thermal data as a nominal low-pressure value."))
    #expect(audit.contains("Source-level tests require the thermal gauge to hide filled progress when thermal state is not reported."))
}

@Test func networkUIOnlyNamesImplementedSignals() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let unimplementedNetworkTerms = ["质量", "测速", "延迟", "丢包"]

    for term in unimplementedNetworkTerms {
        #expect(!dashboardView.contains(term))
    }
}

@Test func networkMetricCardsDoNotShowBaselineProgressAsPercent() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    func metricCardLine(titleExpression: String) -> String {
        dashboardView
            .split(separator: "\n")
            .first { $0.contains("MetricCard(title: \(titleExpression)") }
            .map(String.init) ?? ""
    }

    #expect(dashboardView.contains("let badgeText: String?"))
    #expect(dashboardView.contains("if let badgeText"))
    #expect(!dashboardView.contains("Text(MetricFormatting.percentage(progress))"))

    for titleExpression in [
        "PulseDockAppStrings.overviewNetworkThroughputTitle",
        "PulseDockAppStrings.networkDownloadTitle",
        "PulseDockAppStrings.networkUploadTitle",
        "PulseDockAppStrings.networkTotalThroughputTitle",
        "PulseDockAppStrings.networkConnectionStatusTitle"
    ] {
        #expect(metricCardLine(titleExpression: titleExpression).contains("badgeText: nil"))
    }

    for titleExpression in [
        "PulseDockAppStrings.overviewCPUUsageTitle",
        "PulseDockAppStrings.overviewMemoryUsageTitle",
        "PulseDockAppStrings.overviewPowerStatusTitle"
    ] {
        let line = metricCardLine(titleExpression: titleExpression)
        #expect(line.contains("badgeText:"))
        #expect(!line.contains("badgeText: nil"))
    }
}

@Test func networkInterfaceSnapshotsAvoidLocalAddresses() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(!metricSnapshot.contains("public var address"))
    #expect(!metricSnapshot.contains("address: String?"))
    #expect(!sampler.contains("getnameinfo("))
    #expect(!sampler.contains("addressString(from:"))
    #expect(!dashboardView.contains("interface.address"))
    #expect(!dashboardView.contains("无地址"))
    #expect(!dashboardView.contains("\"地址\""))
}

@Test func networkInterfaceSnapshotsAvoidRawInterfaceNames() throws {
    let decodedMissingInterfaceText = try JSONDecoder().decode(NetworkInterfaceMetric.self, from: Data("""
    {
      "index": 0
    }
    """.utf8))
    let blankInterfaceText = NetworkInterfaceMetric(
        index: 1,
        displayName: "   ",
        kind: "   ",
        isUp: false,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let legacyGenericInterfaceText = NetworkInterfaceMetric(
        index: 2,
        displayName: "Interface",
        kind: "Other",
        isUp: false,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let package = try String(
        contentsOf: root.appendingPathComponent("Package.swift"),
        encoding: .utf8
    )
    let xcodeGenerator = try String(
        contentsOf: root.appendingPathComponent("scripts/generate-xcodeproj.rb"),
        encoding: .utf8
    )
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(decodedMissingInterfaceText.displayName == SharedMetricStrings.notReported)
    #expect(decodedMissingInterfaceText.kind == SharedMetricStrings.notReported)
    #expect(blankInterfaceText.displayName == SharedMetricStrings.notReported)
    #expect(blankInterfaceText.kind == SharedMetricStrings.notReported)
    #expect(legacyGenericInterfaceText.displayName == SharedMetricStrings.notReported)
    #expect(legacyGenericInterfaceText.kind == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public struct NetworkInterfaceMetric"))
    #expect(metricSnapshot.contains("public var id: Int { index }"))
    #expect(metricSnapshot.contains("public var index: Int"))
    #expect(metricSnapshot.contains("private static func reportedInterfaceDisplayName(_ displayName: String?) -> String"))
    #expect(metricSnapshot.contains("private static func reportedInterfaceKind(_ kind: String?) -> String"))
    #expect(metricSnapshot.contains("displayName = Self.reportedInterfaceDisplayName(try values.decodeIfPresent(String.self, forKey: .displayName))"))
    #expect(metricSnapshot.contains("kind = Self.reportedInterfaceKind(try values.decodeIfPresent(String.self, forKey: .kind))"))
    #expect(!metricSnapshot.contains("displayName = try values.decodeIfPresent(String.self, forKey: .displayName) ?? \"Interface\""))
    #expect(!metricSnapshot.contains("kind = try values.decodeIfPresent(String.self, forKey: .kind) ?? \"Other\""))
    #expect(package.contains(".linkedFramework(\"SystemConfiguration\")"))
    #expect(xcodeGenerator.contains("add_system_framework(\"SystemConfiguration\")"))
    #expect(sampler.contains("import SystemConfiguration"))
    #expect(sampler.contains("let descriptors = systemInterfaceDescriptorsByName()"))
    #expect(sampler.contains("SCNetworkInterfaceCopyAll()"))
    #expect(sampler.contains("SCNetworkInterfaceGetBSDName"))
    #expect(sampler.contains("SCNetworkInterfaceGetInterfaceType"))
    #expect(sampler.contains("SCNetworkInterfaceGetLocalizedDisplayName"))
    #expect(!metricSnapshot.contains("public var id: String { name }"))
    #expect(!metricSnapshot.contains("public struct NetworkInterfaceMetric: Codable, Equatable, Sendable, Identifiable {\n    public var id: String { name }\n    public var name: String"))
    #expect(!sampler.contains("NetworkInterfaceMetric(\n            name:"))
    #expect(!sampler.contains("default: return name"))
    #expect(sampler.contains("private func interfaceSortKind(_ name: String) -> String"))
    #expect(sampler.contains("private func interfaceKindDisplayName(sortKind: String) -> String"))
    #expect(sampler.contains("default: return SharedMetricStrings.networkInterface"))
    #expect(sampler.contains("return SharedMetricStrings.other"))
    #expect(sampler.contains("return \"Other\""))
    #expect(!sampler.contains("lhs.name.localizedStandardCompare(rhs.name)"))
    #expect(!dashboardView.contains("interface.name"))
    #expect(audit.contains("Missing or legacy generic network interface names and kinds are displayed as not-reported"))
    #expect(audit.contains("Source-level tests prevent missing network interface names or kinds from surfacing as Interface or Other"))
}

@Test func networkInterfaceDescriptorsUseShortCacheWhileCountersStayLive() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(sampler.contains("private var networkInterfaceDescriptorCache: TimedSample<[String: NetworkInterfaceDescriptor]>?"))
    #expect(sampler.contains("let networkInterfaces = sampleNetworkInterfaces(now: now)"))
    #expect(sampler.contains("let descriptors = cachedNetworkInterfaceDescriptors(now: now)"))
    #expect(sampler.contains("private func cachedNetworkInterfaceDescriptors(now: Date) -> [String: NetworkInterfaceDescriptor]"))
    #expect(sampler.contains("let descriptors = systemInterfaceDescriptorsByName()"))
    #expect(sampler.contains("networkInterfaceDescriptorCache = TimedSample(timestamp: now, value: descriptors)"))
    #expect(sampler.contains("let interfaceStats = networkInterfaceStatsByIndex()"))
    #expect(sampler.contains("data.assumingMemoryBound(to: if_data.self)"))
    #expect(audit.contains("Network interface classification metadata uses the short inventory TTL"))
}

@Test func networkInterfacePageSurfacesPublicMTUWithoutRawNames() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var mtu: Int?"))
    #expect(sampler.contains("var mtu: Int?"))
    #expect(sampler.contains("mtu: mtu"))
    #expect(sampler.contains("record.mtu = stats.mtu"))
    #expect(sampler.contains("record.mtu = interfaceData.ifi_mtu > 0 ? Int(interfaceData.ifi_mtu) : nil"))
    #expect(sampler.contains("mtu: data.ifi_mtu > 0 ? Int(data.ifi_mtu) : nil"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.networkInterfaceTableColumns"))
    #expect(dashboardView.contains("interface.mtuText"))
    #expect(!dashboardView.contains("mtuText(interface.mtu)"))
    #expect(!dashboardView.contains("interface.name"))
    #expect(audit.contains("MTU"))
    #expect(audit.contains("public route interface statistics"))
}

@Test func missingNetworkMTUUsesReportedStateInsteadOfZero() throws {
    let missingMTU = NetworkInterfaceMetric(
        index: 0,
        displayName: "Wi-Fi",
        kind: "Wi-Fi",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil,
        mtu: nil
    )
    let zeroMTU = NetworkInterfaceMetric(
        index: 1,
        displayName: "Ethernet",
        kind: "以太网",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil,
        mtu: 0
    )
    let reportedMTU = NetworkInterfaceMetric(
        index: 2,
        displayName: "Thunderbolt",
        kind: "以太网",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil,
        mtu: 1500
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingMTU.mtuText == SharedMetricStrings.notReported)
    #expect(zeroMTU.mtuText == SharedMetricStrings.notReported)
    #expect(reportedMTU.mtuText == "1500")
    #expect(metricSnapshot.contains("public var mtuText: String"))
    #expect(dashboardView.contains("interface.mtuText"))
    #expect(!dashboardView.contains("private func mtuText(_ mtu: Int?) -> String"))
    #expect(audit.contains("Network interface MTU display text reports the system-not-reported state when MTU is unavailable or zero."))
    #expect(audit.contains("Source-level tests prevent missing network MTU from being formatted as 0."))
}

@Test func networkInterfaceStateTextUsesSharedModelLabels() throws {
    let loopback = NetworkInterfaceMetric(
        index: 0,
        displayName: "Loopback",
        kind: "本机网络",
        isUp: false,
        isLoopback: true,
        hasInterfaceStateReport: true,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let online = NetworkInterfaceMetric(
        index: 1,
        displayName: "Wi-Fi",
        kind: "Wi-Fi",
        isUp: true,
        isLoopback: false,
        hasInterfaceStateReport: true,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let offline = NetworkInterfaceMetric(
        index: 2,
        displayName: "Ethernet",
        kind: "以太网",
        isUp: false,
        isLoopback: false,
        hasInterfaceStateReport: true,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(loopback.stateText == SharedMetricStrings.networkInterfaceStateLoopback)
    #expect(online.stateText == SharedMetricStrings.networkInterfaceStateOnline)
    #expect(offline.stateText == SharedMetricStrings.networkInterfaceStateOffline)
    #expect(metricSnapshot.contains("public var stateText: String"))
    #expect(dashboardView.contains("interface.stateText"))
    #expect(!dashboardView.contains("networkInterfaceStateText(interface)"))
    #expect(!dashboardView.contains("private func networkInterfaceStateText"))
    #expect(audit.contains("Network interface state display text is centralized on the shared interface model."))
    #expect(audit.contains("Source-level tests require Network page interface state labels to come from the shared model."))
}

@Test func initializerNetworkInterfaceCountersOnlyDoesNotInventOnlineOrOfflineState() throws {
    let countersOnlyInterface = NetworkInterfaceMetric(
        index: 0,
        displayName: "Wi-Fi",
        kind: "Wi-Fi",
        isUp: false,
        isLoopback: false,
        bytesReceived: 1_024,
        bytesSent: 2_048,
        hasByteCounters: true,
        packetsReceived: 10,
        packetsSent: 20,
        receiveErrors: 0,
        sendErrors: 0,
        linkSpeedBitsPerSecond: 1_000_000_000,
        mtu: 1500
    )
    var snapshot = MetricSnapshot.placeholder
    snapshot.networkInterfaces = [countersOnlyInterface]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(countersOnlyInterface.stateText == SharedMetricStrings.notReported)
    #expect(countersOnlyInterface.byteCountText == "1 KB / 2 KB")
    #expect(countersOnlyInterface.packetCountText == "10 / 20")
    #expect(countersOnlyInterface.packetErrorText == "0 / 0")
    #expect(countersOnlyInterface.linkSpeedText == "1.0 Gbps")
    #expect(countersOnlyInterface.mtuText == "1500")
    #expect(countersOnlyInterface.hasInventoryReport)
    #expect(snapshot.networkInterfaceSummary == SharedMetricStrings.notReported)
    #expect(!snapshot.hasNetworkInterfaceReport)
    #expect(metricSnapshot.contains("hasInterfaceStateReport: Bool = false"))
    #expect(!metricSnapshot.contains("hasInterfaceStateReport: Bool = true"))
    #expect(audit.contains("NetworkInterfaceMetric initializer defaults interface state to not-reported when only counters, MTU, link speed, or sanitized labels are provided."))
    #expect(audit.contains("Source-level tests prevent counter-only network interface snapshots from inventing online or offline state."))
}

@Test func legacyNetworkInterfaceMissingStateFieldsDoesNotInventOfflineState() throws {
    let decodedInterface = try JSONDecoder().decode(NetworkInterfaceMetric.self, from: Data("""
    {
      "index": 0,
      "displayName": "Wi-Fi",
      "kind": "Wi-Fi"
    }
    """.utf8))
    var snapshot = MetricSnapshot.placeholder
    snapshot.networkInterfaces = [decodedInterface]
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(decodedInterface.stateText == SharedMetricStrings.notReported)
    #expect(!snapshot.hasNetworkInterfaceReport)
    #expect(snapshot.networkInterfaceSummary == SharedMetricStrings.notReported)
    #expect(snapshot.networkSourceStatusText == SharedMetricStrings.notReported)
    #expect(metricSnapshot.contains("public var hasInterfaceStateReport: Bool"))
    #expect(metricSnapshot.contains("guard hasInterfaceStateReport else { return SharedMetricStrings.notReported }"))
    #expect(metricSnapshot.contains("networkInterfaces.contains(where: \\.hasInterfaceStateReport)"))
    #expect(metricSnapshot.contains("let hasInterfaceReport = hasNetworkInterfaceReport || hasNetworkByteCounters"))
    #expect(!metricSnapshot.contains("let hasInterfaceReport = !networkInterfaces.isEmpty || hasNetworkByteCounters"))
    #expect(metricSnapshot.contains("networkInterfaces.filter { $0.hasInterfaceStateReport && $0.isUp && !$0.isLoopback }.count"))
    #expect(sampler.contains("hasInterfaceStateReport: true"))
    #expect(audit.contains("Legacy network interface snapshots missing state flags remain not-reported instead of being displayed as offline or zero active interfaces."))
    #expect(audit.contains("Network data-source status ignores legacy interface rows without reported state, while still allowing byte counters to report interface traffic."))
    #expect(audit.contains("Source-level tests prevent legacy network interface state fields from inventing offline state."))
    #expect(audit.contains("Source-level tests require Network data-source status to use reported interface state instead of raw interface array presence."))
}

@Test func activeInterfaceProgressIgnoresLegacyInterfacesWithoutStateReports() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("let reportedInterfaces = snapshot.networkInterfaces.filter(\\.hasInterfaceStateReport)"))
    #expect(dashboardView.contains("let activeCount = reportedInterfaces.filter { $0.isUp && !$0.isLoopback }.count"))
    #expect(dashboardView.contains("Double(reportedInterfaces.count)"))
    #expect(!dashboardView.contains("Double(snapshot.networkInterfaces.count)"))
    #expect(!widget.contains("Double(snapshot.networkInterfaces.count)"))
    #expect(!widget.contains("private func activeInterfaceProgress(_ snapshot: MetricSnapshot) -> Double"))
    #expect(widget.contains("WidgetRow(title: PulseDockWidgetStrings.metricInterface, value: snapshot.networkPathDetailText"))
    #expect(audit.contains("Dashboard active-interface progress normalizes by reported interface state rows, so legacy interface records do not dilute live interface progress."))
    #expect(audit.contains("Widget interface rows use network path detail text so compact timeline snapshots do not need detailed interface inventory rows."))
    #expect(audit.contains("Source-level tests require active-interface progress to filter by reported interface state before normalizing."))
}

@Test func missingNetworkLinkSpeedUsesReportedStateInsteadOfZeroRate() throws {
    let missingLinkSpeed = NetworkInterfaceMetric(
        index: 0,
        displayName: "Wi-Fi",
        kind: "Wi-Fi",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let zeroLinkSpeed = NetworkInterfaceMetric(
        index: 1,
        displayName: "Ethernet",
        kind: "以太网",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: 0
    )
    let reportedLinkSpeed = NetworkInterfaceMetric(
        index: 2,
        displayName: "Thunderbolt",
        kind: "以太网",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: 1_000_000_000
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingLinkSpeed.linkSpeedText == SharedMetricStrings.notReported)
    #expect(zeroLinkSpeed.linkSpeedText == SharedMetricStrings.notReported)
    #expect(reportedLinkSpeed.linkSpeedText == "1.0 Gbps")
    #expect(metricSnapshot.contains("public var linkSpeedText: String"))
    #expect(dashboardView.contains("interface.linkSpeedText"))
    #expect(!dashboardView.contains("linkSpeedText(interface.linkSpeedBitsPerSecond)"))
    #expect(audit.contains("Network interface link-speed display text reports the system-not-reported state when link speed is unavailable or zero."))
    #expect(audit.contains("Source-level tests prevent missing network link speed from being formatted as 0 bps."))
}

@Test func networkInterfacePageSurfacesPublicPacketAndErrorCountersWithoutRawNames() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var packetsReceived: UInt64?"))
    #expect(metricSnapshot.contains("public var packetsSent: UInt64?"))
    #expect(metricSnapshot.contains("public var receiveErrors: UInt64?"))
    #expect(metricSnapshot.contains("public var sendErrors: UInt64?"))
    #expect(sampler.contains("record.packetsReceived = stats.packetsReceived"))
    #expect(sampler.contains("record.packetsSent = stats.packetsSent"))
    #expect(sampler.contains("record.receiveErrors = stats.receiveErrors"))
    #expect(sampler.contains("record.sendErrors = stats.sendErrors"))
    #expect(sampler.contains("packetsReceived: data.ifi_ipackets"))
    #expect(sampler.contains("receiveErrors: data.ifi_ierrors"))
    #expect(sampler.contains("record.packetsReceived = UInt64(interfaceData.ifi_ipackets)"))
    #expect(dashboardView.contains("columns: PulseDockAppStrings.networkInterfaceTableColumns"))
    #expect(dashboardView.contains("interface.packetCountText"))
    #expect(dashboardView.contains("interface.packetErrorText"))
    #expect(!dashboardView.contains("interface.name"))
    #expect(audit.contains("packet counters"))
    #expect(audit.contains("interface error counters"))
}

@Test func missingNetworkPacketCountersUseReportedStateInsteadOfZeroCounts() throws {
    let missingCounters = NetworkInterfaceMetric(
        index: 0,
        displayName: "Wi-Fi",
        kind: "Wi-Fi",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let reportedZeroCounters = NetworkInterfaceMetric(
        index: 1,
        displayName: "USB",
        kind: "以太网",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        packetsReceived: 0,
        packetsSent: 0,
        receiveErrors: 0,
        sendErrors: 0,
        linkSpeedBitsPerSecond: nil
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingCounters.packetCountText == SharedMetricStrings.notReported)
    #expect(missingCounters.packetErrorText == SharedMetricStrings.notReported)
    #expect(reportedZeroCounters.packetCountText == "0 / 0")
    #expect(reportedZeroCounters.packetErrorText == "0 / 0")
    #expect(metricSnapshot.contains("public var packetsReceived: UInt64?"))
    #expect(metricSnapshot.contains("public var packetCountText: String"))
    #expect(metricSnapshot.contains("public var packetErrorText: String"))
    #expect(sampler.contains("var packetsReceived: UInt64?"))
    #expect(sampler.contains("packetsReceived: packetsReceived"))
    #expect(dashboardView.contains("interface.packetCountText"))
    #expect(dashboardView.contains("interface.packetErrorText"))
    #expect(!dashboardView.contains("packetCountText(interface)"))
    #expect(!dashboardView.contains("packetErrorText(interface)"))
    #expect(audit.contains("Network interface packet and error count display text reports the system-not-reported state when counters are unavailable"))
    #expect(audit.contains("Source-level tests prevent missing network packet and error counters from being formatted as 0 / 0"))
}

@Test func missingNetworkByteCountersUseReportedStateInsteadOfZeroBytes() throws {
    let missingCounters = NetworkInterfaceMetric(
        index: 0,
        displayName: "Wi-Fi",
        kind: "Wi-Fi",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let reportedZeroCounters = NetworkInterfaceMetric(
        index: 1,
        displayName: "USB",
        kind: "以太网",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        hasByteCounters: true,
        linkSpeedBitsPerSecond: nil
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingCounters.byteCountText == SharedMetricStrings.notReported)
    #expect(reportedZeroCounters.byteCountText == "0 B / 0 B")
    #expect(metricSnapshot.contains("public var hasByteCounters: Bool"))
    #expect(metricSnapshot.contains("public var byteCountText: String"))
    #expect(sampler.contains("var hasByteCounters = false"))
    #expect(sampler.contains("record.hasByteCounters = true"))
    #expect(dashboardView.contains("interface.byteCountText"))
    #expect(!dashboardView.contains("MetricFormatting.compactBytes(interface.bytesReceived)"))
    #expect(!dashboardView.contains("MetricFormatting.compactBytes(interface.bytesSent)"))
    #expect(audit.contains("Network interface byte count display text reports the system-not-reported state when counters are unavailable"))
    #expect(audit.contains("Source-level tests prevent missing network byte counters from being formatted as 0 B / 0 B"))
}

@Test func missingNetworkRateUsesReportedStateInsteadOfZeroRateAcrossSurfaces() throws {
    let missingCounters = NetworkInterfaceMetric(
        index: 0,
        displayName: "Wi-Fi",
        kind: "Wi-Fi",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        linkSpeedBitsPerSecond: nil
    )
    let missingSnapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkInBytesPerSecond: 0,
        networkOutBytesPerSecond: 0,
        networkInterfaces: [missingCounters],
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let reportedZeroCounters = NetworkInterfaceMetric(
        index: 1,
        displayName: "USB",
        kind: "以太网",
        isUp: true,
        isLoopback: false,
        bytesReceived: 0,
        bytesSent: 0,
        hasByteCounters: true,
        linkSpeedBitsPerSecond: nil
    )
    let reportedZeroSnapshot = MetricSnapshot(
        cpuUsage: 0.1,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.2,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        networkBytesPerSecond: 0,
        networkInBytesPerSecond: 0,
        networkOutBytesPerSecond: 0,
        networkInterfaces: [reportedZeroCounters],
        diskFreeBytes: 1_024,
        timestamp: Date(timeIntervalSince1970: 0)
    )
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(missingSnapshot.networkText == SharedMetricStrings.notReported)
    #expect(missingSnapshot.networkInText == SharedMetricStrings.notReported)
    #expect(missingSnapshot.networkOutText == SharedMetricStrings.notReported)
    #expect(reportedZeroSnapshot.networkText == "0 Kbps")
    #expect(reportedZeroSnapshot.networkInText == "0 Kbps")
    #expect(reportedZeroSnapshot.networkOutText == "0 Kbps")
    #expect(metricSnapshot.contains("public var hasNetworkByteCounters: Bool"))
    #expect(metricSnapshot.contains("guard hasNetworkByteCounters else { return SharedMetricStrings.notReported }"))
    #expect(sampler.contains("let hasNetworkByteCounters = networkInterfaces.contains { $0.hasByteCounters }"))
    #expect(sampler.contains("sampleNetworkRate(totalBytes: networkTotal, hasByteCounters: hasNetworkByteCounters, now: now)"))
    #expect(sampler.contains("guard hasByteCounters else"))
    #expect(sampler.contains("previousNetworkDate = nil"))
    #expect(metricsStore.contains("hasNetworkByteCounters: snapshot.hasNetworkByteCounters"))
    #expect(audit.contains("Aggregate network rate display text reports the system-not-reported state when byte counters are unavailable"))
    #expect(audit.contains("Source-level tests prevent missing aggregate network counters from being formatted as 0 Kbps"))
}

@Test func memoryUICopyReflectsUsageNotPressure() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(!dashboardView.contains("内存压力"))
    #expect(dashboardView.contains("overviewMemoryUsageTitle"))
    #expect(dashboardView.contains("memoryUsageTrendTitle"))
}

@Test func memorySamplerExposesSwapUsageFromPublicSysctl() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricSnapshot.contains("public var memorySwapUsedBytes: UInt64"))
    #expect(metricSnapshot.contains("public var memorySwapTotalBytes: UInt64"))
    #expect(metricSnapshot.contains("public var memorySwapAvailableBytes: UInt64"))
    #expect(metricSnapshot.contains("public var hasMemorySwapReport: Bool"))
    #expect(metricSnapshot.contains("public var memorySwapText: String"))
    #expect(metricSnapshot.contains("public var memorySwapAvailableText: String"))
    #expect(metricSnapshot.contains("public var memorySwapTotalText: String"))
    #expect(sampler.contains("sysctlbyname(\"vm.swapusage\""))
    #expect(sampler.contains("xsw_usage"))
    #expect(metricsStore.contains("memorySwapUsedBytes: snapshot.memorySwapUsedBytes"))
    #expect(metricsStore.contains("memorySwapAvailableBytes: snapshot.memorySwapAvailableBytes"))
    #expect(dashboardView.contains("(PulseDockAppStrings.memorySwapLabel, snapshot.memorySwapText)"))
    #expect(dashboardView.contains("(PulseDockAppStrings.memorySwapAvailableLabel, snapshot.memorySwapAvailableText)"))
    #expect(dashboardView.contains("(PulseDockAppStrings.memorySwapTotalLabel, snapshot.memorySwapTotalText)"))
    #expect(dashboardView.contains("StatLine(label: PulseDockAppStrings.memorySwapLabel, value: snapshot.memorySwapText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemorySwapReport, progress: snapshot.memorySwapUsage), tint: DashboardColor.red)"))
    #expect(audit.contains("swap used/total/available"))
}

@Test func memorySamplerKeepsUsedCachedAndFreePagesDisjoint() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(sampler.contains("let usedPages = UInt64(stats.active_count + stats.wire_count + stats.compressor_page_count)"))
    #expect(!sampler.contains("let usedPages = UInt64(stats.active_count + stats.inactive_count + stats.wire_count + stats.compressor_page_count)"))
    #expect(sampler.contains("let cachedPages = UInt64(stats.inactive_count + stats.purgeable_count)"))
    #expect(sampler.contains("let reclaimableFreePages = UInt64(stats.free_count + stats.speculative_count)"))
    #expect(dashboardView.contains("segment(snapshot.memoryUsedBytes, color: DashboardColor.blue, in: availableWidth)"))
    #expect(dashboardView.contains("segment(snapshot.memoryCachedBytes, color: DashboardColor.cyan, in: availableWidth)"))
    #expect(audit.contains("used memory excludes inactive cache pages"))
}

@Test func widgetCopyDoesNotClaimRealtimeRefresh() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )

    #expect(!widget.contains("实时监控"))
    #expect(widget.contains("WidgetHeader(title: PulseDockWidgetStrings.headerSystemStatus"))
}

@Test func settingsPageControlsRefreshAndHistoryState() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let appStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/PulseDockAppStrings.swift"),
        encoding: .utf8
    )
    let appStringCatalog = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings"),
        encoding: .utf8
    )
    let appEnglishStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings"),
        encoding: .utf8
    )
    let appChineseStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("enum RefreshIntervalOption"))
    #expect(metricsStore.contains("enum HistoryDepthOption"))
    #expect(metricsStore.contains("@Published private(set) var refreshInterval"))
    #expect(metricsStore.contains("@Published private(set) var historyDepth"))
    #expect(metricsStore.contains("func updateRefreshInterval"))
    #expect(metricsStore.contains("func updateHistoryDepth"))
    #expect(metricsStore.contains("Timer.scheduledTimer(withTimeInterval: refreshInterval.seconds"))
    #expect(metricsStore.contains("historyDepth.sampleCount"))
    #expect(metricsStore.contains("PulseDockAppStrings.historySampleCount(rawValue)"))
    #expect(!metricsStore.contains("\"\\(rawValue) 次\""))
    #expect(appStrings.contains("app.history_depth.sample_count_format"))
    #expect(appStringCatalog.contains("\"value\": \"%d samples\""))
    #expect(appStringCatalog.contains("\"value\": \"%d 次\""))
    #expect(appEnglishStrings.contains("\"app.history_depth.sample_count_format\" = \"%d samples\";"))
    #expect(appChineseStrings.contains("\"app.history_depth.sample_count_format\" = \"%d 次\";"))
    #expect(dashboardView.contains("SettingsPage(store: store, isCompact: isCompact)"))
    #expect(dashboardView.contains("Picker(PulseDockAppStrings.settingsMainWindowRefreshTitle"))
    #expect(dashboardView.contains("Picker(PulseDockAppStrings.settingsLocalHistoryTitle"))
}

@Test func pulseDockAppStringsRuntimeLookupUsesSwiftPMResources() throws {
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let appBundleURL = try swiftPMBuiltResourceBundleURL(named: "PulseDock_PulseDockApp.bundle")
    let appBundle = try #require(Bundle(url: appBundleURL))

    let regular = appBundle.localizedString(
        forKey: "app.running_app.activation.regular",
        value: "__missing__",
        table: "PulseDockApp"
    )
    let historyFormat = appBundle.localizedString(
        forKey: "app.history_depth.sample_count_format",
        value: "__missing__",
        table: "PulseDockApp"
    )
    let network = appBundle.localizedString(
        forKey: "app.metric.network",
        value: "__missing__",
        table: "PulseDockApp"
    )
    let notReported = appBundle.localizedString(
        forKey: "app.not_reported",
        value: "__missing__",
        table: "PulseDockApp"
    )

    #expect(regular != "__missing__")
    #expect(historyFormat != "__missing__")
    #expect(network != "__missing__")
    #expect(notReported != "__missing__")
    #expect(historyFormat.contains("%d"))
    #expect(appStrings.contains("bundle.localizedString(forKey: key, value: defaultValue, table: \"PulseDockApp\")"))
    #expect(appStrings.contains("#if SWIFT_PACKAGE\n        .module\n        #else\n        .main\n        #endif"))
    #expect(FileManager.default.fileExists(atPath: appBundleURL.appendingPathComponent("en.lproj/PulseDockApp.strings").path))
    #expect(FileManager.default.fileExists(atPath: appBundleURL.appendingPathComponent("zh-hans.lproj/PulseDockApp.strings").path))
}

@Test func widgetPanelStringsUsePulseDockAppLocalizationResources() throws {
    let widgetPanel = try fixture("Sources/PulseDockApp/WidgetPanelView.swift")
    let appStrings = try fixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
    let appStringCatalog = try fixture("Sources/PulseDockApp/Resources/PulseDockApp.xcstrings")
    let appEnglishStrings = try fixture("Sources/PulseDockApp/Resources/en.lproj/PulseDockApp.strings")
    let appChineseStrings = try fixture("Sources/PulseDockApp/Resources/zh-Hans.lproj/PulseDockApp.strings")
    let expectedEntries = [
        (symbol: "metricMemory", key: "app.metric.memory", english: "Memory", chinese: "内存"),
        (symbol: "metricNetwork", key: "app.metric.network", english: "Network", chinese: "网络"),
        (symbol: "metricDisk", key: "app.metric.disk", english: "Disk", chinese: "磁盘"),
        (symbol: "metricThermalState", key: "app.metric.thermal_state", english: "Thermal", chinese: "热状态"),
        (symbol: "metricLoad", key: "app.metric.load", english: "Load", chinese: "负载"),
        (symbol: "metricDisplays", key: "app.metric.displays", english: "Displays", chinese: "显示器"),
        (symbol: "metricVolumes", key: "app.metric.volumes", english: "Volumes", chinese: "卷"),
        (symbol: "metricUptime", key: "app.metric.uptime", english: "Uptime", chinese: "运行"),
        (symbol: "metricKernel", key: "app.metric.kernel", english: "Kernel", chinese: "内核"),
        (symbol: "menuOpenMainWindow", key: "app.menu_popover.action.open_main_window", english: "Open Window", chinese: "打开主窗口"),
        (symbol: "menuResumeRefresh", key: "app.menu_popover.action.resume_refresh", english: "Resume", chinese: "恢复刷新"),
        (symbol: "menuPauseRefresh", key: "app.menu_popover.action.pause_refresh", english: "Pause", chinese: "暂停刷新"),
        (symbol: "menuSettings", key: "app.menu_popover.action.settings", english: "Settings", chinese: "设置"),
        (symbol: "menuStatusPaused", key: "app.menu_popover.status.paused", english: "Paused", chinese: "暂停"),
        (symbol: "menuStatusLive", key: "app.menu_popover.status.live", english: "Live", chinese: "实时")
    ]

    for entry in expectedEntries {
        #expect(appStrings.contains("static var \(entry.symbol): String"))
        #expect(appStrings.contains("localized(\"\(entry.key)\", defaultValue: \"\(entry.english)\")"))
        #expect(appStringCatalog.contains("\"\(entry.key)\""))
        #expect(appStringCatalog.contains("\"value\": \"\(entry.english)\""))
        #expect(appStringCatalog.contains("\"value\": \"\(entry.chinese)\""))
        #expect(appEnglishStrings.contains("\"\(entry.key)\" = \"\(entry.english)\";"))
        #expect(appChineseStrings.contains("\"\(entry.key)\" = \"\(entry.chinese)\";"))
        #expect(widgetPanel.contains("PulseDockAppStrings.\(entry.symbol)"))
    }

    #expect(appStrings.contains("static var notReported: String"))
    #expect(appStrings.contains("SharedMetricStrings.notReported"))
    #expect(appStringCatalog.contains("\"app.not_reported\""))
    #expect(appEnglishStrings.contains("\"app.not_reported\" = \"Not reported\";"))
    #expect(appChineseStrings.contains("\"app.not_reported\" = \"未报告\";"))
    #expect(widgetPanel.contains("PulseDockAppStrings.notReported"))

    #expect(!widgetPanel.contains("title: \"内存\""))
    #expect(!widgetPanel.contains("title: \"网络\""))
    #expect(!widgetPanel.contains("title: \"磁盘\""))
    #expect(!widgetPanel.contains("title: \"热状态\""))
    #expect(!widgetPanel.contains("title: \"负载\""))
    #expect(!widgetPanel.contains("title: \"显示器\""))
    #expect(!widgetPanel.contains("title: \"卷\""))
    #expect(!widgetPanel.contains("title: \"运行\""))
    #expect(!widgetPanel.contains("title: \"内核\""))
    #expect(!widgetPanel.contains("title: \"打开主窗口\""))
    #expect(!widgetPanel.contains("isPaused ? \"恢复刷新\" : \"暂停刷新\""))
    #expect(!widgetPanel.contains("title: \"设置\""))
    #expect(!widgetPanel.contains("Text(isPaused ? \"暂停\" : \"实时\")"))
    #expect(widgetPanel.contains(".accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockAppStrings.notReported)"))
}

@Test func widgetStringsUsePulseDockWidgetLocalizationResources() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let widgetStrings = try fixture("Sources/PulseDockWidget/PulseDockWidgetStrings.swift")
    let widgetStringCatalog = try fixture("Sources/PulseDockWidget/Resources/PulseDockWidget.xcstrings")
    let expectedEntries = [
        (symbol: "widgetDescription", key: "widget.description", english: "Show Mac CPU, memory, disk, connection, power, load, thermal, uptime, system, and kernel status on your desktop.", chinese: "在桌面显示 Mac 的 CPU、内存、磁盘、连接、电源、负载、热状态、运行时间、系统和内核状态。"),
        (symbol: "miniThermal", key: "widget.mini.thermal", english: "Thermal", chinese: "热状态"),
        (symbol: "miniNetwork", key: "widget.mini.network", english: "Net", chinese: "网"),
        (symbol: "miniPower", key: "widget.mini.power", english: "Pwr", chinese: "电"),
        (symbol: "metricMemory", key: "widget.metric.memory", english: "Memory", chinese: "内存"),
        (symbol: "metricConnection", key: "widget.metric.connection", english: "Connection", chinese: "连接"),
        (symbol: "metricDisk", key: "widget.metric.disk", english: "Disk", chinese: "磁盘"),
        (symbol: "metricLoad", key: "widget.metric.load", english: "Load", chinese: "负载"),
        (symbol: "metricThermalState", key: "widget.metric.thermal_state", english: "Thermal", chinese: "热状态"),
        (symbol: "metricPath", key: "widget.metric.path", english: "Path", chinese: "路径"),
        (symbol: "metricInterface", key: "widget.metric.interface", english: "Interface", chinese: "接口"),
        (symbol: "metricUptime", key: "widget.metric.uptime", english: "Uptime", chinese: "运行"),
        (symbol: "metricSystem", key: "widget.metric.system", english: "System", chinese: "系统"),
        (symbol: "metricKernel", key: "widget.metric.kernel", english: "Kernel", chinese: "内核"),
        (symbol: "headerSystemStatus", key: "widget.header.system_status", english: "System Status", chinese: "系统状态"),
        (symbol: "waitingSystemData", key: "widget.placeholder.accessibility.waiting_system_data", english: "Waiting for system monitor data", chinese: "等待系统监控数据"),
        (symbol: "waitingData", key: "widget.placeholder.waiting_data", english: "Waiting for data", chinese: "等待数据"),
        (symbol: "compactPowerCharging", key: "widget.power.compact.charging", english: "Charging", chinese: "充电"),
        (symbol: "compactPowerAdapter", key: "widget.power.compact.adapter", english: "Power", chinese: "电源"),
        (symbol: "compactPowerBattery", key: "widget.power.compact.battery", english: "Battery", chinese: "电池"),
        (symbol: "compactPowerExternal", key: "widget.power.compact.external", english: "External Power", chinese: "外部电源")
    ]

    #expect(widgetStrings.contains("bundle.localizedString(forKey: key, value: defaultValue, table: \"PulseDockWidget\")"))
    #expect(widgetStrings.contains("#if SWIFT_PACKAGE\n        .module\n        #else\n        .main\n        #endif"))

    for entry in expectedEntries {
        #expect(widgetStrings.contains("static var \(entry.symbol): String"))
        #expect(widgetStrings.contains("localized(\"\(entry.key)\", defaultValue: \"\(entry.english)\")"))
        #expect(widgetStringCatalog.contains("\"\(entry.key)\""))
        #expect(widgetStringCatalog.contains("\"value\" : \"\(entry.english)\""))
        #expect(widgetStringCatalog.contains("\"value\" : \"\(entry.chinese)\""))
        #expect(widget.contains("PulseDockWidgetStrings.\(entry.symbol)"))
    }

    #expect(widgetStrings.contains("static var notReported: String"))
    #expect(widgetStrings.contains("SharedMetricStrings.notReported"))
    #expect(widgetStringCatalog.contains("\"widget.not_reported\""))
    #expect(widgetStringCatalog.contains("\"value\" : \"Not reported\""))
    #expect(widgetStringCatalog.contains("\"value\" : \"未报告\""))
    #expect(widget.contains("PulseDockWidgetStrings.notReported"))

    #expect(!widget.contains(".description(\"在桌面显示"))
    #expect(!widget.contains("title: \"热\""))
    #expect(!widget.contains("title: \"网\""))
    #expect(!widget.contains("title: \"电\""))
    #expect(!widget.contains("title: \"内存\""))
    #expect(!widget.contains("title: \"连接\""))
    #expect(!widget.contains("title: \"磁盘\""))
    #expect(!widget.contains("title: \"负载\""))
    #expect(!widget.contains("title: \"热状态\""))
    #expect(!widget.contains("title: \"路径\""))
    #expect(!widget.contains("title: \"接口\""))
    #expect(!widget.contains("title: \"运行\""))
    #expect(!widget.contains("title: \"系统\""))
    #expect(!widget.contains("title: \"内核\""))
    #expect(!widget.contains("title: \"系统状态\""))
    #expect(!widget.contains("Text(\"等待数据\")"))
    #expect(!widget.contains(".accessibilityLabel(\"等待系统监控数据\")"))
    #expect(widget.contains(".accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockWidgetStrings.notReported)"))
}

@Test func settingsPageStacksPreviewPanelAtCompactWidth() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let settingsStart = try #require(dashboardView.range(of: "private struct SettingsPage")?.lowerBound)
    let dashboardPanelStart = try #require(dashboardView.range(of: "private struct DashboardPanel", range: settingsStart..<dashboardView.endIndex)?.lowerBound)
    let settingsPage = String(dashboardView[settingsStart..<dashboardPanelStart])

    #expect(dashboardView.contains("SettingsPage(store: store, isCompact: isCompact)"))
    #expect(settingsPage.contains("let isCompact: Bool"))
    #expect(settingsPage.contains("if isCompact {"))
    #expect(settingsPage.contains("VStack(alignment: .leading, spacing: 12)"))
    #expect(settingsPage.contains(".frame(width: 360)"))
}

@Test func privacyAndSupportLinksAreAccessibleInAppAndMetadata() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appInfo = try String(contentsOf: root.appendingPathComponent("Resources/AppInfo.plist"), encoding: .utf8)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let pulseDockLinks = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/PulseDockLinks.swift"),
        encoding: .utf8
    )
    let releaseChecklist = try String(contentsOf: root.appendingPathComponent("docs/app-store-release-checklist.md"), encoding: .utf8)
    let privacyURL = "https://ifonly3.github.io/pulsedock/privacy-policy/"
    let supportURL = "https://ifonly3.github.io/pulsedock/support/"

    #expect(appInfo.contains("<key>PulseDockPrivacyPolicyURL</key>"))
    #expect(appInfo.contains("<string>\(privacyURL)</string>"))
    #expect(appInfo.contains("<key>PulseDockSupportURL</key>"))
    #expect(appInfo.contains("<string>\(supportURL)</string>"))
    #expect(appDelegate.contains("NSMenuItem(title: PulseDockAppStrings.mainMenuPrivacyPolicy, action: #selector(openPrivacyPolicyFromMenu(_:)), keyEquivalent: \"\")"))
    #expect(appDelegate.contains("NSMenuItem(title: PulseDockAppStrings.mainMenuSupport, action: #selector(openSupportFromMenu(_:)), keyEquivalent: \"\")"))
    #expect(appDelegate.contains("@objc private func openPrivacyPolicyFromMenu"))
    #expect(appDelegate.contains("@objc private func openSupportFromMenu"))
    #expect(dashboardView.contains("DashboardPanel(title: PulseDockAppStrings.settingsSupportPrivacyTitle"))
    #expect(dashboardView.contains("SettingsLinkRow(title: PulseDockAppStrings.settingsPrivacyPolicyTitle"))
    #expect(dashboardView.contains("SettingsLinkRow(title: PulseDockAppStrings.settingsSupportTitle"))
    #expect(dashboardView.contains("PulseDockLinks.openPrivacyPolicy()"))
    #expect(dashboardView.contains("PulseDockLinks.openSupport()"))
    #expect(pulseDockLinks.contains("static let privacyPolicyInfoKey = \"PulseDockPrivacyPolicyURL\""))
    #expect(pulseDockLinks.contains("static let supportInfoKey = \"PulseDockSupportURL\""))
    #expect(pulseDockLinks.contains("NSWorkspace.shared.open(url)"))
    #expect(releaseChecklist.contains("- Support URL: `\(supportURL)`"))
    #expect(releaseChecklist.contains("- Privacy policy URL: `\(privacyURL)`"))
}

@Test func privacyAndSupportUrlsUseStablePublicPages() throws {
    let appInfo = try fixture("Resources/AppInfo.plist")
    let readme = try fixture("README.md")
    let releaseChecklist = try fixture("docs/app-store-release-checklist.md")
    let audit = try fixture("docs/data-capability-audit.md")
    let privacyPage = try fixture("docs/privacy-policy/index.html")
    let supportPage = try fixture("docs/support/index.html")
    let publicPageValidator = try fixture("scripts/validate-public-pages.sh")
    let releaseCriticalFiles = [appInfo, readme, releaseChecklist, audit]

    for file in releaseCriticalFiles {
        #expect(file.contains("https://ifonly3.github.io/pulsedock/privacy-policy/"))
        #expect(file.contains("https://ifonly3.github.io/pulsedock/support/"))
        #expect(!file.contains("github.com/ifonly3/pulsedock/blob/main/docs/app-store"))
    }

    #expect(privacyPage.contains("<h1>Pulse Dock Privacy Policy</h1>"))
    #expect(privacyPage.contains("Pulse Dock does not collect personal data from this app."))
    #expect(privacyPage.contains("https://ifonly3.github.io/pulsedock/support/"))
    #expect(supportPage.contains("<h1>Pulse Dock Support</h1>"))
    #expect(supportPage.contains("https://github.com/ifonly3/pulsedock/issues"))
    #expect(supportPage.contains("https://ifonly3.github.io/pulsedock/privacy-policy/"))
    #expect(publicPageValidator.contains("expected_privacy_url=\"https://ifonly3.github.io/pulsedock/privacy-policy/\""))
    #expect(publicPageValidator.contains("expected_support_url=\"https://ifonly3.github.io/pulsedock/support/\""))
    #expect(publicPageValidator.contains("CHECK_PUBLIC_URLS"))
}

@Test func pulseDockLinksOnlyAllowHTTPSURLs() throws {
    let links = try fixture("Sources/PulseDockApp/PulseDockLinks.swift")

    #expect(links.contains("components.scheme?.lowercased() == \"https\""))
    #expect(!links.contains("scheme == \"https\" || scheme == \"http\""))
}

@Test func defaultsUsageHasPrivacyReasonsForAppSettingsAndWidgetSharedSnapshot() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let appPrivacyInfo = try String(
        contentsOf: root.appendingPathComponent("Resources/App/PrivacyInfo.xcprivacy"),
        encoding: .utf8
    )
    let widgetPrivacyInfo = try String(
        contentsOf: root.appendingPathComponent("Resources/Widget/PrivacyInfo.xcprivacy"),
        encoding: .utf8
    )
    let xcodeProjectGenerator = try String(
        contentsOf: root.appendingPathComponent("scripts/generate-xcodeproj.rb"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("private enum DefaultsKeys"))
    #expect(metricsStore.contains("UserDefaults.standard"))
    #expect(metricsStore.contains("RefreshIntervalOption(rawValue: defaults.double"))
    #expect(metricsStore.contains("HistoryDepthOption(rawValue: defaults.integer"))
    #expect(metricsStore.contains("defaults.set(option.rawValue, forKey: DefaultsKeys.refreshInterval"))
    #expect(metricsStore.contains("defaults.set(option.rawValue, forKey: DefaultsKeys.historyDepth"))
    #expect(!metricsStore.contains("suiteName:"))
    #expect(appPrivacyInfo.contains("NSPrivacyAccessedAPICategoryDiskSpace"))
    #expect(appPrivacyInfo.contains("85F4.1"))
    #expect(appPrivacyInfo.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    #expect(appPrivacyInfo.contains("CA92.1"))
    #expect(appPrivacyInfo.contains("NSPrivacyAccessedAPICategorySystemBootTime"))
    #expect(appPrivacyInfo.contains("35F9.1"))
    #expect(widgetPrivacyInfo.contains("NSPrivacyAccessedAPICategoryDiskSpace"))
    #expect(widgetPrivacyInfo.contains("85F4.1"))
    #expect(widgetPrivacyInfo.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    #expect(widgetPrivacyInfo.contains("CA92.1"))
    #expect(widgetPrivacyInfo.contains("NSPrivacyAccessedAPICategorySystemBootTime"))
    #expect(widgetPrivacyInfo.contains("35F9.1"))
    #expect(xcodeProjectGenerator.contains("Resources/App/PrivacyInfo.xcprivacy"))
    #expect(xcodeProjectGenerator.contains("Resources/Widget/PrivacyInfo.xcprivacy"))
}

@Test func statusThresholdsAreConfigurableAndPersisted() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("@Published private(set) var cpuAlertThreshold"))
    #expect(metricsStore.contains("@Published private(set) var memoryAlertThreshold"))
    #expect(metricsStore.contains("@Published private(set) var diskAlertThreshold"))
    #expect(metricsStore.contains("func updateCPUAlertThreshold"))
    #expect(metricsStore.contains("func updateMemoryAlertThreshold"))
    #expect(metricsStore.contains("func updateDiskAlertThreshold"))
    #expect(metricsStore.contains("defaults.set(normalized, forKey: DefaultsKeys.cpuAlertThreshold"))
    #expect(metricsStore.contains("defaults.set(normalized, forKey: DefaultsKeys.memoryAlertThreshold"))
    #expect(metricsStore.contains("defaults.set(normalized, forKey: DefaultsKeys.diskAlertThreshold"))
    #expect(dashboardView.contains("HistoryAlertsPage(store: store, history: history)"))
    #expect(dashboardView.contains("ThresholdControlRow(title: \"CPU\""))
    #expect(dashboardView.contains("Slider(value: Binding("))
    #expect(dashboardView.contains("store.cpuAlertThreshold"))
    #expect(dashboardView.contains("MetricFormatting.percentage(store.cpuAlertThreshold)"))
    #expect(!dashboardView.contains("[\"CPU 超过\", \"90%\""))
    #expect(!dashboardView.contains("[\"内存压力高\", \"85%\""))
}

@Test func diskThresholdAppliesAcrossOverviewAndStoragePages() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("OverviewPage(store: store, history: history, metricColumns: metricColumns, isCompact: isCompact)"))
    #expect(dashboardView.contains("StoragePage(store: store, history: history, capabilityColumns: capabilityColumns)"))
    #expect(dashboardView.contains("usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold)"))
    #expect(dashboardView.contains("thresholdStatusText(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold"))
    #expect(!dashboardView.contains("snapshot.diskUsage > 0.9"))
}

@Test func overviewStatusUsesCPUAndMemoryThresholds() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("StatusSummaryRow(title: PulseDockAppStrings.overviewCPUStatusTitle"))
    #expect(dashboardView.contains("StatusSummaryRow(title: PulseDockAppStrings.overviewMemoryStatusTitle"))
    #expect(dashboardView.contains("usageStatusLevel(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold)"))
    #expect(dashboardView.contains("usageStatusLevel(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold)"))
    #expect(dashboardView.contains("MetricFormatting.percentage(store.cpuAlertThreshold)"))
    #expect(dashboardView.contains("MetricFormatting.percentage(store.memoryAlertThreshold)"))
}

@Test func overviewTrendSurfacesLoadAverageHistory() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let overviewStart = try #require(dashboardView.range(of: "private struct OverviewPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct CPUPage")?.lowerBound)
    let overviewPage = String(dashboardView[overviewStart..<nextStart])

    #expect(!overviewPage.contains("TrendRow(title: PulseDockAppStrings.metricLoad"))
    #expect(audit.contains("Overview metric cards surface compact CPU, memory, network, and power sparklines; the History page owns the expanded multi-signal trend view."))
    #expect(audit.contains("Source-level tests require the History page, not Overview, to own persisted load-average history."))
}

@Test func overviewRunningAppSummarySurfacesWorkspaceStateCounts() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let overviewStart = try #require(dashboardView.range(of: "private struct OverviewPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct CPUPage")?.lowerBound)
    let overviewPage = String(dashboardView[overviewStart..<nextStart])

    #expect(overviewPage.contains("StatusSummaryRow(title: PulseDockAppStrings.metricRunningApps, value: snapshot.runningAppSummaryText, status: snapshot.hasRunningAppReport ? .normal : .neutral)"))
    #expect(!dashboardView.contains("private func processThreadSummary"))
    #expect(!dashboardView.contains("processThreadSummary(snapshot)"))
    #expect(audit.contains("The Overview system status running-app row surfaces the full public Workspace state counts: total, active, and hidden apps."))
    #expect(audit.contains("Source-level tests require the Overview running-app summary to surface active and hidden Workspace counts."))
    #expect(audit.contains("Source-level tests require running-app summary labels to come from the shared snapshot model."))
}

@Test func statusPageUsesConfiguredThresholdRules() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("SensorsPage(store: store, isCompact: isCompact, capabilityColumns: capabilityColumns)"))
    #expect(dashboardView.contains("@ObservedObject var store: MetricsStore"))
    #expect(dashboardView.contains("private var snapshot: MetricSnapshot { store.snapshot }"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricCPU"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricMemory"))
    #expect(dashboardView.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricDisk"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricCPU, MetricFormatting.percentage(store.cpuAlertThreshold), snapshot.cpuText"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricMemory, MetricFormatting.percentage(store.memoryAlertThreshold), snapshot.memoryUsageText"))
    #expect(dashboardView.contains("[PulseDockAppStrings.metricDisk, MetricFormatting.percentage(store.diskAlertThreshold), snapshot.diskUsageText"))
}

@Test func statusPageSurfacesLoadAverageSignal() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let statusStart = try #require(dashboardView.range(of: "private struct SensorsPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct HistoryAlertsPage")?.lowerBound)
    let statusPage = String(dashboardView[statusStart..<nextStart])

    #expect(statusPage.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricLoad, value: snapshot.loadDetailText, icon: \"speedometer\", status: snapshot.hasLoadAverageReport ? .normal : .neutral, source: PulseDockAppStrings.sourceLoadAverages)"))
    #expect(!statusPage.contains("PulseDockAppStrings.statusSystemSignalsTitle"))
    #expect(!statusPage.contains("[\"\\(PulseDockAppStrings.metricLoad) 1/5/15\", snapshot.loadDetailText, PulseDockAppStrings.sourceLoadAverages]"))
    #expect(audit.contains("The Status page surfaces load-average detail as a current system signal instead of limiting it to the CPU and History pages."))
    #expect(audit.contains("Source-level tests require the Status page to surface load-average detail with reported-state handling."))
}

@Test func statusPageSurfacesGPUInventorySignal() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let statusStart = try #require(dashboardView.range(of: "private struct SensorsPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct HistoryAlertsPage")?.lowerBound)
    let statusPage = String(dashboardView[statusStart..<nextStart])

    #expect(statusPage.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricGPU, value: snapshot.gpuSummaryText, icon: \"sparkles.rectangle.stack\", status: snapshot.hasGPUReport ? .normal : .neutral, source: PulseDockAppStrings.sourceGraphicsDevices)"))
    #expect(!statusPage.contains("[PulseDockAppStrings.metricGPU, snapshot.gpuSummaryText, PulseDockAppStrings.sourceGraphicsDevices]"))
    #expect(audit.contains("The Status page surfaces GPU inventory summary as a current system signal, using the same public Metal device inventory as the GPU/Display page."))
    #expect(audit.contains("Source-level tests require the Status page to surface GPU inventory with reported-state handling."))
}

@Test func statusPageSurfacesStorageVolumeSignal() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let statusStart = try #require(dashboardView.range(of: "private struct SensorsPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct HistoryAlertsPage")?.lowerBound)
    let statusPage = String(dashboardView[statusStart..<nextStart])

    #expect(statusPage.contains("SourceCapabilityCard(title: PulseDockAppStrings.metricStorageVolumes, value: snapshot.storageVolumeSummaryText, icon: \"externaldrive\", status: snapshot.hasStorageVolumeReport ? .normal : .neutral, source: PulseDockAppStrings.sourceFileSystemCapacity)"))
    #expect(!statusPage.contains("[PulseDockAppStrings.metricStorageVolumes, snapshot.storageVolumeSummaryText, PulseDockAppStrings.sourceFileSystemCapacity]"))
    #expect(audit.contains("The Status page surfaces mounted storage volume summary as a current system signal, using the same sanitized volume inventory as the Storage page."))
    #expect(audit.contains("Source-level tests require the Status page to surface storage volume inventory with reported-state handling."))
}

@Test func menuBarCPUDisplayCanBeToggledAndPersisted() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("static let showsMenuBarCPU"))
    #expect(metricsStore.contains("@Published private(set) var showsMenuBarCPU"))
    #expect(metricsStore.contains("func updateShowsMenuBarCPU"))
    #expect(metricsStore.contains("defaults.set(isVisible, forKey: DefaultsKeys.showsMenuBarCPU"))
    #expect(dashboardView.contains("Toggle(PulseDockAppStrings.settingsMenuBarCPULabel, isOn: Binding("))
    #expect(dashboardView.contains("store.showsMenuBarCPU"))
    #expect(dashboardView.contains("store.updateShowsMenuBarCPU"))
    #expect(appDelegate.contains("store.$snapshot.combineLatest(store.$showsMenuBarCPU)"))
    #expect(appDelegate.contains("updateStatusButtonTitle()"))
    #expect(appDelegate.contains("private var statusButtonCPUText: String?"))
    #expect(appDelegate.contains("guard let cpuText = statusButtonCPUText else"))
}

@Test func historyPersistenceUsesSanitizedTrendSnapshots() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("static let historySnapshots"))
    #expect(metricsStore.contains("savedHistory(defaults"))
    #expect(metricsStore.contains("persistHistoryIfNeeded"))
    #expect(metricsStore.contains("sanitizedHistorySnapshot(from:"))
    #expect(metricsStore.contains("hasCPUUsageReport: snapshot.hasCPUUsageReport"))
    #expect(metricsStore.contains("JSONEncoder().encode"))
    #expect(metricsStore.contains("JSONDecoder().decode([MetricSnapshot].self"))
    #expect(metricsStore.contains("osVersion: MetricSnapshot.placeholder.osVersion"))
    #expect(metricsStore.contains("kernelRelease: MetricSnapshot.placeholder.kernelRelease"))
    #expect(!metricsStore.contains("osVersion: \"macOS\""))
    #expect(metricsStore.contains("processCount: 0"))
    #expect(metricsStore.contains("runningApps: []"))
    #expect(metricsStore.contains("storageVolumes: []"))
    #expect(metricsStore.contains("networkInterfaces: []"))
    #expect(!metricsStore.contains("defaults.set(recentSnapshots"))
    #expect(audit.contains("Sanitized trend history resets OS version and Darwin kernel release to shared not-reported placeholders instead of preserving system identity fields."))
    #expect(audit.contains("Persisted trend history preserves CPU reported-state flags so missing CPU samples do not reload as 0%"))
    #expect(audit.contains("Source-level tests require sanitized history snapshots to reset OS and kernel identity fields through shared not-reported placeholders."))
}

@Test func historyPersistencePreservesSampledActiveProcessorCountForLoadTrends() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("activeProcessorCount: snapshot.activeProcessorCount"))
    #expect(audit.contains("Persisted trend history preserves sampled active processor count so load-average charts keep the original normalization denominator."))
    #expect(audit.contains("Source-level tests require sanitized history snapshots to preserve sampled active processor count for load trend normalization."))
}

@Test func legacyHistoryWithoutActiveProcessorCountDoesNotInventLoadTrendDenominator() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )
    let legacyHistoryData = """
    [{
      "cpuUsage": 0.4,
      "hasCPUUsageReport": true,
      "physicalCoreCount": 8,
      "logicalCoreCount": 8,
      "memoryUsedBytes": 4096,
      "memoryTotalBytes": 8192,
      "loadAverage": 2.0,
      "loadAverage5": 1.5,
      "loadAverage15": 1.0,
      "hasLoadAverageReport": true,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "hasNetworkByteCounters": false,
      "networkPathStatus": "unknown",
      "diskFreeBytes": 4096,
      "diskTotalBytes": 8192,
      "uptimeSeconds": 120,
      "hasUptimeReport": true,
      "osVersion": "macOS",
      "timestamp": 3600
    }]
    """.data(using: .utf8)!
    let decodedLegacyHistory = try JSONDecoder().decode([MetricSnapshot].self, from: legacyHistoryData)

    #expect(decodedLegacyHistory.first?.activeProcessorCount == 0)
    #expect(metricSnapshot.contains("activeProcessorCount = try values.decodeIfPresent(Int.self, forKey: .activeProcessorCount) ?? Self.placeholder.activeProcessorCount"))
    #expect(dashboardView.contains("history.filter { $0.hasLoadAverageReport && $0.activeProcessorCount > 0 }.map { min($0.loadAverage / Double($0.activeProcessorCount), 1) }"))
    #expect(!dashboardView.contains("history.filter(\\.hasLoadAverageReport).map { min($0.loadAverage / Double(max($0.activeProcessorCount, 1)), 1) }"))
    #expect(audit.contains("Legacy persisted history without sampled active processor count is excluded from load-average trend normalization instead of borrowing the current machine count."))
    #expect(audit.contains("Source-level tests prevent legacy load history without active processor count from inventing a normalization denominator."))
}

@Test func sparklinesDoNotInventTrendSamples() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(!dashboardView.contains("seed *"))
    #expect(!dashboardView.contains("min(seed *"))
}

@Test func historyPageCopyReflectsPersistedHistory() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("DashboardPanel(title: PulseDockAppStrings.historyTrendsTitle, subtitle: reportedHistorySampleCountText(from: history), icon: \"chart.xyaxis.line\")"))
    #expect(!dashboardView.contains("本次启动后"))
}

@Test func historySampleCountLabelsOnlyCountReportedSamples() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(dashboardView.contains("private func reportedHistorySampleCountText(from history: [MetricSnapshot]) -> String"))
    #expect(dashboardView.contains("private func reportedHistorySampleChipText(from history: [MetricSnapshot]) -> String"))
    #expect(dashboardView.contains("let reportedSampleCount = history.filter(\\.hasSampleTimeReport).count"))
    #expect(!dashboardView.contains("DashboardPanel(title: PulseDockAppStrings.overviewRuntimeTrendsTitle"))
    #expect(dashboardView.contains("DataChip(icon: \"waveform.path.ecg\", text: reportedHistorySampleChipText(from: history))"))
    #expect(dashboardView.contains("DashboardPanel(title: PulseDockAppStrings.historyTrendsTitle, subtitle: reportedHistorySampleCountText(from: history), icon: \"chart.xyaxis.line\")"))
    #expect(!dashboardView.contains("subtitle: \"最近 \\(history.count) 次采样\""))
    #expect(!dashboardView.contains("text: \"最近 \\(history.count) 次\""))
    #expect(audit.contains("History sample-count labels count only snapshots with reported sample timestamps, so placeholder or legacy missing-time history is not displayed as sampled history."))
    #expect(audit.contains("Source-level tests prevent history count labels from counting placeholder snapshots as sampled history."))
}

@Test func historyPageSurfacesPersistedDiskTrend() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let historyStart = try #require(dashboardView.range(of: "private struct HistoryAlertsPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct SettingsPage")?.lowerBound)
    let historyPage = String(dashboardView[historyStart..<nextStart])

    #expect(historyPage.contains("TrendRow(title: PulseDockAppStrings.metricDisk, value: snapshot.diskUsageText, tint: DashboardColor.amber, values: diskTrendValues(from: history))"))
    #expect(audit.contains("The History page surfaces persisted disk usage trend alongside CPU, memory, network, and power history."))
    #expect(audit.contains("Source-level tests require the History page to surface persisted disk usage trend."))
}

@Test func historyPageSurfacesPersistedLoadTrend() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let historyStart = try #require(dashboardView.range(of: "private struct HistoryAlertsPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct SettingsPage")?.lowerBound)
    let historyPage = String(dashboardView[historyStart..<nextStart])

    #expect(dashboardView.contains("private func loadTrendValues(from history: [MetricSnapshot]) -> [Double]"))
    #expect(dashboardView.contains("history.filter { $0.hasLoadAverageReport && $0.activeProcessorCount > 0 }.map { min($0.loadAverage / Double($0.activeProcessorCount), 1) }"))
    #expect(historyPage.contains("TrendRow(title: PulseDockAppStrings.metricLoad, value: snapshot.loadText, tint: DashboardColor.purple, values: loadTrendValues(from: history))"))
    #expect(audit.contains("The History page surfaces persisted load-average trend while filtering samples whose load averages were not reported."))
    #expect(audit.contains("Source-level tests require the History page to surface persisted load-average trend."))
}

@Test func historyPageSurfacesPersistedThermalTrend() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let historyStart = try #require(dashboardView.range(of: "private struct HistoryAlertsPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct SettingsPage")?.lowerBound)
    let historyPage = String(dashboardView[historyStart..<nextStart])

    #expect(dashboardView.contains("private func thermalTrendValues(from history: [MetricSnapshot]) -> [Double]"))
    #expect(dashboardView.contains("history.filter(\\.hasThermalStateReport).compactMap { ThermalState(raw: $0.thermalState).progress }"))
    #expect(!dashboardView.contains("history.compactMap { ThermalState(raw: $0.thermalState).progress }"))
    #expect(historyPage.contains("TrendRow(title: PulseDockAppStrings.statusThermalTitle, value: snapshot.thermalText, tint: thermalStatus(snapshot.thermalState).color, values: thermalTrendValues(from: history))"))
    #expect(audit.contains("The History page surfaces persisted thermal-state trend while filtering samples whose thermal state was not reported."))
    #expect(audit.contains("Source-level tests require the History page to surface persisted thermal-state trend."))
}

@Test func historyPageSurfacesPersistedUptimeTrend() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    let historyStart = try #require(dashboardView.range(of: "private struct HistoryAlertsPage")?.lowerBound)
    let nextStart = try #require(dashboardView.range(of: "private struct SettingsPage")?.lowerBound)
    let historyPage = String(dashboardView[historyStart..<nextStart])

    #expect(dashboardView.contains("private func uptimeTrendValues(from history: [MetricSnapshot]) -> [Double]"))
    #expect(dashboardView.contains("let reportedUptime = history.filter(\\.hasUptimeReport).map(\\.uptimeSeconds)"))
    #expect(dashboardView.contains("return reportedUptime.map { min($0 / maxUptime, 1) }"))
    #expect(historyPage.contains("TrendRow(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, tint: DashboardColor.green, values: uptimeTrendValues(from: history))"))
    #expect(audit.contains("The History page surfaces persisted uptime trend while filtering samples whose uptime was not reported."))
    #expect(audit.contains("Source-level tests require the History page to surface persisted uptime trend."))
}

@Test func formattersGuardNonFiniteDoubleInputsBeforeIntegerConversion() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let formatting = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricFormatting.swift"),
        encoding: .utf8
    )

    #expect(formatting.contains("guard value.isFinite else { return SharedMetricStrings.notReported }"))
    #expect(formatting.contains("guard bitsPerSecond.isFinite else { return SharedMetricStrings.notReported }"))
    #expect(formatting.contains("guard seconds.isFinite else { return SharedMetricStrings.notReported }"))

    let notReported = SharedMetricStrings.notReported
    #expect(MetricFormatting.percentage(.nan) == notReported)
    #expect(MetricFormatting.bitRate(bitsPerSecond: .infinity) == notReported)
    #expect(MetricFormatting.load(-.infinity) == notReported)
    #expect(MetricFormatting.duration(.nan) == notReported)
}

@Test func sharedMetricStringsResourcesContainNotReportedLocalizations() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let english = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )
    let chinese = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )

    #expect(english.contains("\"shared_metrics.not_reported\" = \"Not reported\";"))
    #expect(chinese.contains("\"shared_metrics.not_reported\" = \"未报告\";"))
    #expect(english.contains("\"shared_metrics.other\" = \"Other\";"))
    #expect(chinese.contains("\"shared_metrics.other\" = \"其他\";"))
    #expect(english.contains("\"shared_metrics.network_interface\" = \"Network Interface\";"))
    #expect(chinese.contains("\"shared_metrics.network_interface\" = \"网络接口\";"))
    #expect(english.contains("\"shared_metrics.display.built_in\" = \"Built-in Display\";"))
    #expect(chinese.contains("\"shared_metrics.display.built_in\" = \"内建显示器\";"))
    #expect(english.contains("\"shared_metrics.display.main\" = \"Main Display\";"))
    #expect(chinese.contains("\"shared_metrics.display.main\" = \"主显示器\";"))
    #expect(english.contains("\"shared_metrics.display.generic_format\" = \"Display %d\";"))
    #expect(chinese.contains("\"shared_metrics.display.generic_format\" = \"显示器 %d\";"))
    #expect(english.contains("\"shared_metrics.display.external_format\" = \"External Display %d\";"))
    #expect(chinese.contains("\"shared_metrics.display.external_format\" = \"外接显示器 %d\";"))
}

@Test func networkDisplayStringsUseSharedMetricLocalizationResources() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sharedStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SharedMetricStrings.swift"),
        encoding: .utf8
    )
    let english = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )
    let chinese = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )

    let expectedEntries = [
        (symbol: "networkInterfaceStateLoopback", key: "shared_metrics.network.interface.state.loopback", english: "Loopback", chinese: "本机"),
        (symbol: "networkInterfaceStateOnline", key: "shared_metrics.network.interface.state.online", english: "Online", chinese: "在线"),
        (symbol: "networkInterfaceStateOffline", key: "shared_metrics.network.interface.state.offline", english: "Offline", chinese: "离线"),
        (symbol: "networkPathStatusOnline", key: "shared_metrics.network.path.status.online", english: "Online", chinese: "在线"),
        (symbol: "networkPathStatusOffline", key: "shared_metrics.network.path.status.offline", english: "Offline", chinese: "离线"),
        (symbol: "networkPathStatusRequiresConnection", key: "shared_metrics.network.path.status.requires_connection", english: "Requires Connection", chinese: "需连接"),
        (symbol: "networkPathLocalNetwork", key: "shared_metrics.network.path.local_network", english: "Local Network", chinese: "本机网络"),
        (symbol: "networkPathNoConnection", key: "shared_metrics.network.path.no_connection", english: "No Connection", chinese: "无可用连接"),
        (symbol: "networkPathLowDataMode", key: "shared_metrics.network.path.low_data_mode", english: "Low Data Mode", chinese: "低数据模式"),
        (symbol: "networkPathMeteredNetwork", key: "shared_metrics.network.path.metered_network", english: "Metered Network", chinese: "计量网络"),
        (symbol: "networkPathUnavailable", key: "shared_metrics.network.path.unavailable", english: "Unavailable", chinese: "不可用"),
        (symbol: "networkPathSupported", key: "shared_metrics.network.path.supported", english: "Supported", chinese: "支持"),
        (symbol: "networkPathUnsupported", key: "shared_metrics.network.path.unsupported", english: "Unsupported", chinese: "不支持"),
        (symbol: "networkPathEnabled", key: "shared_metrics.network.path.enabled", english: "On", chinese: "开启"),
        (symbol: "networkPathDisabled", key: "shared_metrics.network.path.disabled", english: "Off", chinese: "关闭"),
        (symbol: "networkRuleNormal", key: "shared_metrics.network.rule.normal", english: "Normal", chinese: "正常"),
        (symbol: "networkRuleAttention", key: "shared_metrics.network.rule.attention", english: "Attention", chinese: "注意")
    ]

    for entry in expectedEntries {
        #expect(sharedStrings.contains("static var \(entry.symbol): String"))
        #expect(sharedStrings.contains("localized(\"\(entry.key)\", defaultValue: \"\(entry.english)\")"))
        #expect(english.contains("\"\(entry.key)\" = \"\(entry.english)\";"))
        #expect(chinese.contains("\"\(entry.key)\" = \"\(entry.chinese)\";"))
        #expect(metricSnapshot.contains("SharedMetricStrings.\(entry.symbol)"))
    }

    let formatEntries = [
        (key: "shared_metrics.network.interface.active_singular_format", english: "%d active interface", chinese: "%d 个活动接口"),
        (key: "shared_metrics.network.interface.active_plural_format", english: "%d active interfaces", chinese: "%d 个活动接口")
    ]

    #expect(sharedStrings.contains("static func activeNetworkInterfaceSummary(activeCount: Int) -> String"))
    #expect(metricSnapshot.contains("SharedMetricStrings.activeNetworkInterfaceSummary(activeCount: activeCount)"))
    for entry in formatEntries {
        #expect(sharedStrings.contains("\"\(entry.key)\","))
        #expect(sharedStrings.contains("defaultValue: \"\(entry.english)\""))
        #expect(english.contains("\"\(entry.key)\" = \"\(entry.english)\";"))
        #expect(chinese.contains("\"\(entry.key)\" = \"\(entry.chinese)\";"))
    }

    let interfaceStart = try #require(metricSnapshot.range(of: "public struct NetworkInterfaceMetric")?.lowerBound)
    let snapshotStart = try #require(metricSnapshot.range(of: "public struct MetricSnapshot")?.lowerBound)
    let interfaceMetric = String(metricSnapshot[interfaceStart..<snapshotStart])
    let networkStart = try #require(metricSnapshot.range(of: "public var networkText: String")?.lowerBound)
    let diskStart = try #require(metricSnapshot.range(of: "public var diskText: String")?.lowerBound)
    let networkPathText = String(metricSnapshot[networkStart..<diskStart])
    let summaryStart = try #require(metricSnapshot.range(of: "public var networkInterfaceSummary: String")?.lowerBound)
    let summaryRemainder = metricSnapshot[summaryStart...]
    let codingKeysStart = try #require(summaryRemainder.range(of: "enum CodingKeys: String, CodingKey")?.lowerBound)
    let networkSummaryText = String(summaryRemainder[..<codingKeysStart])

    for rawLiteral in [
        "\"未报告\"",
        "\"本机\"",
        "\"在线\"",
        "\"离线\"",
        "\"需连接\"",
        "\"本机网络\"",
        "\"无可用连接\"",
        "\"低数据模式\"",
        "\"计量网络\"",
        "\"不可用\"",
        "\"不支持\"",
        "\"支持\"",
        "\"开启\"",
        "\"关闭\"",
        "\"正常\"",
        "\"注意\"",
        "\"\\(activeCount) 个活动接口\""
    ] {
        #expect(!interfaceMetric.contains(rawLiteral))
        #expect(!networkPathText.contains(rawLiteral))
        #expect(!networkSummaryText.contains(rawLiteral))
    }
}

@Test func processMetricDisplayStringsUseSharedMetricLocalizationResources() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricSnapshot = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricSnapshot.swift"),
        encoding: .utf8
    )
    let sharedStrings = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SharedMetricStrings.swift"),
        encoding: .utf8
    )
    let english = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )
    let chinese = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"),
        encoding: .utf8
    )

    let expectedEntries = [
        (symbol: "systemDidNotReport", key: "shared_metrics.system.did_not_report", english: "System did not report", chinese: "系统未报告"),
        (symbol: "processStateForeground", key: "shared_metrics.process.state.foreground", english: "Foreground", chinese: "前台"),
        (symbol: "processStateHidden", key: "shared_metrics.process.state.hidden", english: "Hidden", chinese: "已隐藏"),
        (symbol: "processStateRunning", key: "shared_metrics.process.state.running", english: "Running", chinese: "运行")
    ]

    for entry in expectedEntries {
        #expect(sharedStrings.contains("static var \(entry.symbol): String"))
        #expect(sharedStrings.contains("localized(\"\(entry.key)\", defaultValue: \"\(entry.english)\")"))
        #expect(english.contains("\"\(entry.key)\" = \"\(entry.english)\";"))
        #expect(chinese.contains("\"\(entry.key)\" = \"\(entry.chinese)\";"))
        #expect(metricSnapshot.contains("SharedMetricStrings.\(entry.symbol)"))
    }

    let decodedMissingName = try JSONDecoder().decode(ProcessMetric.self, from: Data("""
    {
      "index": 1,
      "name": "未报告",
      "isActive": false,
      "isHidden": false
    }
    """.utf8))
    let blankName = ProcessMetric(index: 2, name: "   ")
    let active = ProcessMetric(index: 3, name: "Finder", isActive: true, hasStateReport: true)
    let hidden = ProcessMetric(index: 4, name: "Finder", isHidden: true, hasStateReport: true)
    let running = ProcessMetric(index: 5, name: "Finder", hasStateReport: true)

    #expect(decodedMissingName.name == SharedMetricStrings.notReported)
    #expect(blankName.name == SharedMetricStrings.notReported)
    #expect(active.stateText == SharedMetricStrings.processStateForeground)
    #expect(hidden.stateText == SharedMetricStrings.processStateHidden)
    #expect(running.stateText == SharedMetricStrings.processStateRunning)
    #expect(ProcessMetric.listSubtitle(for: [], defaultSubtitle: "Foreground first") == SharedMetricStrings.notReported)
    #expect(ProcessMetric(index: 6, name: "Finder").architectureText == SharedMetricStrings.systemDidNotReport)
    #expect(ProcessMetric(index: 7, name: "Finder").launchText == SharedMetricStrings.systemDidNotReport)
    #expect(metricSnapshot.contains("SharedMetricStrings.reportedTextOrNotReported(name)"))
    #expect(!metricSnapshot.contains("return trimmed.isEmpty ? \"未报告\" : trimmed"))
    #expect(!metricSnapshot.contains("if isActive { return \"前台\" }"))
    #expect(!metricSnapshot.contains("if isHidden { return \"已隐藏\" }"))
    #expect(!metricSnapshot.contains("trimmedPolicy.isEmpty ? \"运行\""))
}

@Test func remainingMetricSnapshotDisplayStringsUseSharedMetricLocalizationResources() throws {
    let metricSnapshot = try fixture("Sources/SharedMetrics/MetricSnapshot.swift")
    let sharedStrings = try fixture("Sources/SharedMetrics/SharedMetricStrings.swift")
    let english = try fixture("Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings")
    let chinese = try fixture("Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings")

    let expectedEntries = [
        (symbol: "sourceStatusReported", key: "shared_metrics.source.status.reported", english: "Reported", chinese: "已报告"),
        (symbol: "sourceStatusPartial", key: "shared_metrics.source.status.partial", english: "Partial report", chinese: "部分报告"),
        (symbol: "thermalStateNominal", key: "shared_metrics.thermal.state.nominal", english: "Nominal", chinese: "正常"),
        (symbol: "thermalStateWarm", key: "shared_metrics.thermal.state.warm", english: "Warm", chinese: "偏热"),
        (symbol: "thermalStateHot", key: "shared_metrics.thermal.state.hot", english: "Hot", chinese: "较热"),
        (symbol: "thermalStateCritical", key: "shared_metrics.thermal.state.critical", english: "Critical", chinese: "严重"),
        (symbol: "thermalLimitCritical", key: "shared_metrics.thermal.limit.critical", english: "Likely heavy throttling", chinese: "可能强限制"),
        (symbol: "thermalLimitHot", key: "shared_metrics.thermal.limit.hot", english: "Likely throttling", chinese: "可能降频"),
        (symbol: "thermalLimitWarm", key: "shared_metrics.thermal.limit.warm", english: "Light pressure", chinese: "轻微压力"),
        (symbol: "thermalLimitNominal", key: "shared_metrics.thermal.limit.nominal", english: "No obvious limits", chinese: "无明显限制"),
        (symbol: "powerSourceAdapter", key: "shared_metrics.power.source.adapter", english: "Power Adapter", chinese: "电源适配器"),
        (symbol: "powerSourceAdapterCharging", key: "shared_metrics.power.source.adapter_charging", english: "Power Adapter · Charging", chinese: "电源适配器 · 充电中"),
        (symbol: "powerSourceBattery", key: "shared_metrics.power.source.battery", english: "Battery Power", chinese: "电池供电"),
        (symbol: "powerSourceUPS", key: "shared_metrics.power.source.ups", english: "UPS Power", chinese: "UPS 供电"),
        (symbol: "powerSourceExternal", key: "shared_metrics.power.source.external", english: "External Power", chinese: "外部电源"),
        (symbol: "powerSourceStateNotReported", key: "shared_metrics.power.source.state_not_reported", english: "Power state not reported", chinese: "电源状态未报告"),
        (symbol: "powerStatusTitlePower", key: "shared_metrics.power.status.title.power", english: "Power", chinese: "电源"),
        (symbol: "powerStatusTitleBattery", key: "shared_metrics.power.status.title.battery", english: "Battery", chinese: "电池"),
        (symbol: "batteryHealthGood", key: "shared_metrics.battery.health.good", english: "Good", chinese: "良好"),
        (symbol: "batteryHealthFair", key: "shared_metrics.battery.health.fair", english: "Fair", chinese: "一般"),
        (symbol: "batteryHealthPoor", key: "shared_metrics.battery.health.poor", english: "Poor", chinese: "较差"),
        (symbol: "batteryHealthCheck", key: "shared_metrics.battery.health.check", english: "Check Battery", chinese: "建议检查"),
        (symbol: "batteryHealthService", key: "shared_metrics.battery.health.service", english: "Service Battery", chinese: "需要维修"),
        (symbol: "gpuNotReportedSummary", key: "shared_metrics.gpu.summary.not_reported", english: "GPU not reported", chinese: "GPU 未报告"),
        (symbol: "displayNotReportedSummary", key: "shared_metrics.display.summary.not_reported", english: "Display not reported", chinese: "显示器未报告")
    ]

    for entry in expectedEntries {
        #expect(sharedStrings.contains("static var \(entry.symbol): String"))
        #expect(sharedStrings.contains("localized(\"\(entry.key)\", defaultValue: \"\(entry.english)\")"))
        #expect(english.contains("\"\(entry.key)\" = \"\(entry.english)\";"))
        #expect(chinese.contains("\"\(entry.key)\" = \"\(entry.chinese)\";"))
        #expect(metricSnapshot.contains("SharedMetricStrings.\(entry.symbol)"))
    }

    let expectedFormatEntries = [
        (symbol: "logicalCoreSummary", key: "shared_metrics.cpu.logical_core_summary_singular_format", english: "%d logical core", chinese: "%d 逻辑核心"),
        (symbol: "logicalCoreSummary", key: "shared_metrics.cpu.logical_core_summary_plural_format", english: "%d logical cores", chinese: "%d 逻辑核心"),
        (symbol: "diskAvailableSummary", key: "shared_metrics.disk.available_summary_format", english: "%@ available", chinese: "%@ 可用"),
        (symbol: "storageVolumeSummary", key: "shared_metrics.storage.volume.summary_singular_format", english: "%d volume", chinese: "%d 个卷"),
        (symbol: "storageVolumeSummary", key: "shared_metrics.storage.volume.summary_plural_format", english: "%d volumes", chinese: "%d 个卷"),
        (symbol: "externalStorageVolumeSummary", key: "shared_metrics.storage.volume.external_summary_format", english: "%d external", chinese: "%d 个"),
        (symbol: "gpuSummary", key: "shared_metrics.gpu.summary_singular_format", english: "%d GPU", chinese: "%d 个"),
        (symbol: "gpuSummary", key: "shared_metrics.gpu.summary_plural_format", english: "%d GPUs", chinese: "%d 个"),
        (symbol: "displaySummary", key: "shared_metrics.display.summary_singular_format", english: "%d display", chinese: "%d 台显示器"),
        (symbol: "displaySummary", key: "shared_metrics.display.summary_plural_format", english: "%d displays", chinese: "%d 台显示器"),
        (symbol: "gpuDisplaySummary", key: "shared_metrics.gpu_display.summary_format", english: "%@ / %@", chinese: "%@ / %@")
    ]

    for entry in expectedFormatEntries {
        #expect(sharedStrings.contains("static func \(entry.symbol)("))
        #expect(sharedStrings.contains("\"\(entry.key)\","))
        #expect(sharedStrings.contains("defaultValue: \"\(entry.english)\""))
        #expect(english.contains("\"\(entry.key)\" = \"\(entry.english)\";"))
        #expect(chinese.contains("\"\(entry.key)\" = \"\(entry.chinese)\";"))
        #expect(metricSnapshot.contains("SharedMetricStrings.\(entry.symbol)("))
    }
}

@Test func sharedMetricStringsNumberedDisplayHelpersFormatArguments() {
    let genericDisplay = SharedMetricStrings.display(number: 3)
    let externalDisplay = SharedMetricStrings.externalDisplay(number: 4)

    #expect(genericDisplay.contains("3"))
    #expect(externalDisplay.contains("4"))
    #expect(!genericDisplay.contains("%d"))
    #expect(!externalDisplay.contains("%d"))
}

@Test func metricFormattingUsesSharedMetricStringForNotReportedFallbacks() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let formatting = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/MetricFormatting.swift"),
        encoding: .utf8
    )

    #expect(formatting.contains("SharedMetricStrings.notReported"))
    #expect(!formatting.contains("未报告"))
}

@Test func aggregateNetworkDirectionsRequireDirectionFieldsInsteadOfBorrowingTotalCounterState() throws {
    let legacyTotalOnlyJSON = """
    {
      "cpuUsage": 0.1,
      "hasCPUUsageReport": true,
      "memoryUsedBytes": 1024,
      "memoryTotalBytes": 2048,
      "loadAverage": 0.2,
      "thermalState": "Nominal",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 2048,
      "hasNetworkByteCounters": true,
      "networkPathStatus": "satisfied",
      "diskFreeBytes": 1024,
      "diskTotalBytes": 2048,
      "timestamp": 1
    }
    """.data(using: .utf8)!

    let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: legacyTotalOnlyJSON)

    #expect(snapshot.networkText != SharedMetricStrings.notReported)
    #expect(snapshot.networkInText == SharedMetricStrings.notReported)
    #expect(snapshot.networkOutText == SharedMetricStrings.notReported)
}

@Test func interfaceByteCountTextRequiresActualReceivedAndSentFields() throws {
    let legacyFlagOnlyJSON = """
    {
      "index": 0,
      "displayName": "Wi-Fi",
      "kind": "Wi-Fi",
      "isUp": true,
      "hasInterfaceStateReport": true,
      "hasByteCounters": true
    }
    """.data(using: .utf8)!

    let interface = try JSONDecoder().decode(NetworkInterfaceMetric.self, from: legacyFlagOnlyJSON)

    #expect(interface.hasByteCounters)
    #expect(interface.byteCountText == SharedMetricStrings.notReported)
}

@Test func partialLegacyRunningAppCountsFollowInitializerReportInference() throws {
    let partialCountsJSON = """
    {
      "cpuUsage": 0,
      "memoryUsedBytes": 0,
      "memoryTotalBytes": 0,
      "loadAverage": 0,
      "thermalState": "Unknown",
      "batteryIsCharging": false,
      "networkBytesPerSecond": 0,
      "activeApplicationCount": 1,
      "diskFreeBytes": 0,
      "timestamp": 1
    }
    """.data(using: .utf8)!

    let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: partialCountsJSON)

    #expect(snapshot.hasRunningAppReport)
    #expect(snapshot.runningAppSummaryText == SharedMetricStrings.runningAppSummary(
        processCount: 0,
        activeApplicationCount: 1,
        hiddenApplicationCount: 0
    ))
    #expect(snapshot.activeApplicationCountText == "1")
    #expect(snapshot.hiddenApplicationCountText == "0")
}

@Test func blankBatteryPowerSourceDoesNotBecomeReportedNoBatteryState() throws {
    let snapshot = MetricSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        loadAverage: 0,
        thermalState: "Unknown",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: "   ",
        networkBytesPerSecond: 0,
        diskFreeBytes: 0,
        timestamp: Date(timeIntervalSince1970: 1)
    )

    #expect(!snapshot.hasPowerStatusReport)
    #expect(snapshot.powerSourceText == SharedMetricStrings.notReported)
    #expect(snapshot.powerStatusText == SharedMetricStrings.notReported)
}

@Test func samplerReleasesMachHostPortsAndDoesNotReportFailedMemoryStatsAsZeroUsage() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(
        contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"),
        encoding: .utf8
    )

    #expect(sampler.contains("let host = mach_host_self()"))
    #expect(sampler.contains("defer { mach_port_deallocate(mach_task_self_, host) }"))
    #expect(sampler.contains("guard host_page_size(host, &pageSize) == KERN_SUCCESS, pageSize > 0 else"))
    #expect(sampler.contains("return (0, 0, 0, 0, 0, 0, swap.used, swap.total, swap.available, false)"))
}

@Test func widgetTimelineUsesCompactSnapshotWithoutUnusedInventoryLists() throws {
    let compact = try fixture("Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift")
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")
    let audit = try String(
        contentsOf: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(widget.contains("Self.samplerCache.sampleCompact()"))
    #expect(widget.contains("Self.sampledSnapshotForTimeline(now: now)"))
    #expect(sampler.contains("public func sampleWidgetCompact(now: Date = Date()) -> MetricSnapshot"))
    #expect(!widget.contains("private func compactWidgetSnapshot"))
    #expect(!compact.contains("networkBytesPerSecond: networkBytesPerSecond"))
    #expect(!compact.contains("hasNetworkByteCounters: hasNetworkByteCounters"))
    #expect(!compact.contains("hasNetworkDirectionByteCounters: hasNetworkDirectionByteCounters"))
    #expect(!compact.contains("networkInBytesPerSecond: networkInBytesPerSecond"))
    #expect(!compact.contains("networkOutBytesPerSecond: networkOutBytesPerSecond"))
    #expect(compact.contains("networkInterfaces: []"))
    #expect(compact.contains("storageVolumes: []"))
    #expect(compact.contains("runningApps: []"))
    #expect(compact.contains("gpuDevices: []"))
    #expect(compact.contains("displays: []"))
    #expect(audit.contains("Widget timeline entries store compact snapshots that preserve visible network path signals while stripping short-window throughput and detailed process, network interface, storage, GPU, and display inventory lists."))
}

@Test func widgetProviderUsesCompactSamplerForSnapshotAndTimeline() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(widget.contains("func getSnapshot(in context: Context, completion: @escaping (SystemEntry) -> Void)"))
    #expect(widget.contains("representativeSnapshot()"))
    #expect(widget.contains("DispatchQueue.global(qos: .utility).async"))
    #expect(widget.contains("sampledSnapshotForTimeline(now: now)"))
    #expect(widget.contains("return systemSampler.sampleWidgetCompact()"))
    #expect(sampler.contains("public func sampleWidgetCompact(now: Date = Date()) -> MetricSnapshot"))
    #expect(sampler.contains("sampleWidgetSnapshot(now: now).widgetCompactSnapshot()"))
    #expect(!widget.contains("return systemSampler.sample()"))
    #expect(!widget.contains("completion(SystemEntry(date: Date(), snapshot: sampledSnapshot()))"))
    #expect(sampler.contains("public func sampleWidgetCompact(now: Date = Date()) -> MetricSnapshot {\n        sampleWidgetSnapshot(now: now).widgetCompactSnapshot()\n    }"))
    #expect(sampler.contains("private func sampleWidgetSnapshot(now: Date) -> MetricSnapshot"))
    #expect(!sampler.contains("public func sampleWidgetCompact(now: Date = Date()) -> MetricSnapshot {\n        sample(now: now).widgetCompactSnapshot()\n    }"))
}

@Test func widgetCompactSnapshotPreservesSummarySignalsAndDropsPrivateLists() {
    let snapshot = MetricSnapshot(
        cpuUsage: 0.42,
        hasCPUUsageReport: true,
        memoryUsedBytes: 4_096,
        memoryTotalBytes: 8_192,
        loadAverage: 1.2,
        hasLoadAverageReport: true,
        thermalState: "Nominal",
        batteryPercent: 0.8,
        batteryIsCharging: true,
        networkBytesPerSecond: 12_345,
        hasNetworkByteCounters: true,
        hasNetworkDirectionByteCounters: true,
        networkPathStatus: "satisfied",
        networkPathIsExpensive: true,
        networkPathIsConstrained: true,
        hasNetworkPathCostReport: true,
        networkPathSupportsDNS: true,
        networkPathSupportsIPv4: true,
        networkPathSupportsIPv6: false,
        hasNetworkPathSupportReport: true,
        networkPathInterfaceKinds: ["Wi-Fi"],
        networkInBytesPerSecond: 6_000,
        networkOutBytesPerSecond: 6_345,
        networkInterfaces: [
            NetworkInterfaceMetric(
                index: 0,
                displayName: "Private Interface",
                kind: "Wi-Fi",
                isUp: true,
                isLoopback: false,
                hasInterfaceStateReport: true,
                bytesReceived: 10_000,
                bytesSent: 8_000,
                hasByteCounters: true
            )
        ],
        diskFreeBytes: 2_048,
        diskTotalBytes: 4_096,
        processCount: 42,
        runningApps: [
            ProcessMetric(index: 0, name: "Private App", hasStateReport: true)
        ],
        timestamp: Date(timeIntervalSince1970: 1_000)
    )

    let compact = snapshot.widgetCompactSnapshot()

    #expect(compact.cpuUsage == snapshot.cpuUsage)
    #expect(compact.networkPathStatus == "satisfied")
    #expect(compact.networkPathIsExpensive)
    #expect(compact.networkPathIsConstrained)
    #expect(compact.hasNetworkPathCostReport)
    #expect(compact.networkPathSupportsDNS)
    #expect(compact.networkPathSupportsIPv4)
    #expect(!compact.networkPathSupportsIPv6)
    #expect(compact.hasNetworkPathSupportReport)
    #expect(compact.networkPathInterfaceKinds == ["Wi-Fi"])
    #expect(compact.networkBytesPerSecond == 0)
    #expect(!compact.hasNetworkByteCounters)
    #expect(!compact.hasNetworkDirectionByteCounters)
    #expect(compact.networkInBytesPerSecond == 0)
    #expect(compact.networkOutBytesPerSecond == 0)
    #expect(compact.networkInterfaces.isEmpty)
    #expect(compact.runningApps.isEmpty)
    #expect(compact.gpuDevices.isEmpty)
    #expect(compact.displays.isEmpty)
}

@Test func appGroupEntitlementsAreDeclaredForAppAndWidget() throws {
    let appEntitlements = try fixture("Resources/PulseDock.entitlements")
    let widgetEntitlements = try fixture("Resources/PulseDockWidgetExtension.entitlements")

    #expect(appEntitlements.contains("<key>com.apple.security.application-groups</key>"))
    #expect(widgetEntitlements.contains("<key>com.apple.security.application-groups</key>"))
    #expect(appEntitlements.contains("<string>group.com.ifonly3.pulsedock</string>"))
    #expect(widgetEntitlements.contains("<string>group.com.ifonly3.pulsedock</string>"))
}

@Test func sharedSnapshotUsesSingleWidgetCompactHelper() throws {
    let compact = try fixture("Sources/SharedMetrics/MetricSnapshot+WidgetCompact.swift")
    let sharedStore = try fixture("Sources/SharedMetrics/SharedSnapshotStore.swift")
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(compact.contains("public func widgetCompactSnapshot() -> MetricSnapshot"))
    #expect(sharedStore.contains("@discardableResult"))
    #expect(sharedStore.contains("public func saveLatestSnapshot(_ snapshot: MetricSnapshot) -> Bool"))
    #expect(sharedStore.contains("snapshot.widgetCompactSnapshot()"))
    #expect(sharedStore.contains("do {\n            let data = try JSONEncoder().encode(compact)"))
    #expect(sharedStore.contains("catch {\n#if DEBUG\n            print(\"Pulse Dock failed to encode shared snapshot: \\(error)\")"))
    #expect(widget.contains("Self.samplerCache.sampleCompact()"))
    #expect(!widget.contains("private func compactWidgetSnapshot"))
}

@Test func appWritesSharedSnapshotsWithThrottleAndWidgetReadsSharedDataFirst() throws {
    let appGroup = try fixture("Sources/SharedMetrics/PulseDockAppGroup.swift")
    let sharedStore = try fixture("Sources/SharedMetrics/SharedSnapshotStore.swift")
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(appGroup.contains("static let suiteName = \"group.com.ifonly3.pulsedock\""))
    #expect(appGroup.contains("static let appBundleIdentifier = \"com.ifonly3.pulsedock\""))
    #expect(appGroup.contains("static let widgetBundleIdentifier = \"com.ifonly3.pulsedock.widget\""))
    #expect(appGroup.contains("supportsAppGroup(bundleIdentifier: String?)"))
    #expect(sharedStore.contains("PulseDockAppGroup.supportsAppGroup(bundleIdentifier: bundleIdentifier)"))
    #expect(sharedStore.contains("containerURL(forSecurityApplicationGroupIdentifier: suiteName)"))
    #expect(sharedStore.contains("UserDefaults(suiteName: suiteName)"))
    #expect(!sharedStore.contains("public init(defaults: UserDefaults? = UserDefaults(suiteName: PulseDockAppGroup.suiteName))"))
    #expect(sharedStore.contains("func saveLatestSnapshot(_ snapshot: MetricSnapshot) -> Bool"))
    #expect(sharedStore.contains("func loadLatestSnapshot(maxAge: TimeInterval"))
    #expect(metricsStore.contains("private let sharedSnapshotWriteInterval: TimeInterval = 60"))
    #expect(metricsStore.contains("private var lastSharedSnapshotWriteDate: Date?"))
    #expect(metricsStore.contains("saveSharedSnapshotIfNeeded(nextSnapshot)"))
    #expect(metricsStore.contains("let elapsed = snapshot.timestamp.timeIntervalSince(lastSharedSnapshotWriteDate)"))
    #expect(metricsStore.contains("if elapsed >= 0 && elapsed < sharedSnapshotWriteInterval"))
    #expect(widget.contains("sharedSnapshotStore.loadLatestSnapshot(maxAge:"))
    #expect(widget.contains("?? Self.samplerCache.sampleCompact()"))
    #expect(audit.contains("Compact local timeline snapshot shared from the main app through App Group UserDefaults"))
    #expect(audit.contains("The main app writes a compact latest snapshot to App Group UserDefaults on a 60-second throttled cadence"))
    #expect(audit.contains("Shared widget snapshots tolerate small system clock skew while still rejecting stale or far-future data."))
    #expect(!audit.contains("The main app does not write App Group files for widget updates."))
}

@Test func sharedSnapshotStoreSkipsAppGroupDefaultsWhenContainerUnavailable() throws {
    let sharedStore = try fixture("Sources/SharedMetrics/SharedSnapshotStore.swift")
    let audit = try fixture("docs/data-capability-audit.md")
    let store = SharedSnapshotStore(defaults: nil)
    let snapshot = MetricSnapshot(
        cpuUsage: 0.2,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.4,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 1_000)
    )

    #expect(store.saveLatestSnapshot(snapshot) == false)

    #expect(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 1_010)) == nil)
    #expect(sharedStore.contains("guard fileManager.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil else"))
    #expect(sharedStore.contains("self.defaults = nil"))
    #expect(audit.contains("Shared widget snapshot storage checks the production bundle identifier and App Group container availability before creating suite UserDefaults, so local ad-hoc builds fall back without blocking on unavailable App Group preferences."))
}

@Test func sharedSnapshotStoreDoesNotUseAppGroupDefaultsForLocalBundleIdentifiers() throws {
    let store = SharedSnapshotStore(suiteName: PulseDockAppGroup.suiteName, bundleIdentifier: "local.pulsedock")
    let snapshot = MetricSnapshot(
        cpuUsage: 0.2,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.4,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 1_000)
    )

    #expect(store.saveLatestSnapshot(snapshot) == false)

    #expect(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 1_010)) == nil)
    #expect(PulseDockAppGroup.supportsAppGroup(bundleIdentifier: "local.pulsedock") == false)
    #expect(PulseDockAppGroup.supportsAppGroup(bundleIdentifier: "local.pulsedock.widget") == false)
    #expect(PulseDockAppGroup.supportsAppGroup(bundleIdentifier: "com.ifonly3.pulsedock") == true)
    #expect(PulseDockAppGroup.supportsAppGroup(bundleIdentifier: "com.ifonly3.pulsedock.widget") == true)
}

@Test func sharedSnapshotStoreRoundTripsCompactSnapshotThroughDefaults() throws {
    let suiteName = "SharedSnapshotStoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = SharedSnapshotStore(defaults: defaults)
    let snapshot = MetricSnapshot(
        cpuUsage: 0.42,
        hasCPUUsageReport: true,
        cpuBrandName: "Private CPU",
        memoryUsedBytes: 4_096,
        memoryTotalBytes: 8_192,
        loadAverage: 1.2,
        hasLoadAverageReport: true,
        thermalState: "Nominal",
        batteryPercent: 0.8,
        batteryIsCharging: true,
        networkBytesPerSecond: 12_345,
        hasNetworkByteCounters: true,
        networkInBytesPerSecond: 6_000,
        networkOutBytesPerSecond: 6_345,
        diskFreeBytes: 2_048,
        diskTotalBytes: 4_096,
        processCount: 42,
        runningApps: [
            ProcessMetric(index: 0, name: "Private App", hasStateReport: true)
        ],
        timestamp: Date(timeIntervalSince1970: 1_000)
    )

    #expect(store.saveLatestSnapshot(snapshot))
    let loaded = try #require(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 1_030)))

    #expect(loaded.cpuUsage == snapshot.cpuUsage)
    #expect(loaded.cpuBrandName == nil)
    #expect(loaded.networkBytesPerSecond == 0)
    #expect(!loaded.hasNetworkByteCounters)
    #expect(!loaded.hasNetworkDirectionByteCounters)
    #expect(loaded.networkInBytesPerSecond == 0)
    #expect(loaded.networkOutBytesPerSecond == 0)
    #expect(loaded.processCount == 0)
    #expect(loaded.runningApps.isEmpty)
    #expect(loaded.timestamp == snapshot.timestamp)
}

@Test func sharedSnapshotStoreAcceptsSmallFutureClockSkewButRejectsLargeFutureSnapshots() throws {
    let suiteName = "SharedSnapshotStoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = SharedSnapshotStore(defaults: defaults)
    let snapshot = MetricSnapshot(
        cpuUsage: 0.2,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.4,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 1_000)
    )

    #expect(store.saveLatestSnapshot(snapshot))

    #expect(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 995)) != nil)
    #expect(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 600)) == nil)
    #expect(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 1_060)) != nil)
    #expect(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 1_061)) == nil)
}

@Test func sharedSnapshotStoreReportsEncodingFailures() throws {
    let suiteName = "SharedSnapshotStoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = SharedSnapshotStore(defaults: defaults)
    let invalidSnapshot = MetricSnapshot(
        cpuUsage: .nan,
        hasCPUUsageReport: true,
        memoryUsedBytes: 1_024,
        memoryTotalBytes: 2_048,
        loadAverage: 0.4,
        thermalState: "Nominal",
        batteryPercent: nil,
        batteryIsCharging: false,
        diskFreeBytes: 1_024,
        diskTotalBytes: 2_048,
        timestamp: Date(timeIntervalSince1970: 1_000)
    )

    #expect(store.saveLatestSnapshot(invalidSnapshot) == false)
    #expect(store.loadLatestSnapshot(maxAge: 60, now: Date(timeIntervalSince1970: 1_010)) == nil)
}

@Test func xcodeProjectIncludesSharedSnapshotFoundationFiles() throws {
    let project = try fixture("PulseDock.xcodeproj/project.pbxproj")

    #expect(project.contains("PulseDockAppGroup.swift"))
    #expect(project.contains("MetricScales.swift"))
    #expect(project.contains("MetricSnapshot+WidgetCompact.swift"))
    #expect(project.contains("SharedSnapshotStore.swift"))
}

@Test func xcodeProjectGenerationUsesDeterministicUUIDs() throws {
    let generator = try fixture("scripts/generate-xcodeproj.rb")

    #expect(generator.contains("module DeterministicXcodeUUIDs"))
    #expect(generator.contains("Xcodeproj::Project.prepend(DeterministicXcodeUUIDs)"))
    #expect(generator.contains("format(\"%024X\", @deterministic_uuid_counter)"))
    #expect(generator.contains("project.sort"))
}

@Test func mainWindowSupportsThirteenInchFriendlyMinimumSize() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

    #expect(appDelegate.contains("DashboardLayout.minimumContentSize"))
    #expect(appDelegate.contains("window.minSize = window.frameRect(forContentRect: minimumContentRect).size"))
    #expect(!appDelegate.contains("window.minSize = NSSize(width: 1180, height: 760)"))
}

@Test func mainWindowInitialFrameFitsVisibleScreenArea() throws {
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

    #expect(appDelegate.contains("private func initialDashboardWindowFrame() -> NSRect"))
    #expect(appDelegate.contains("let visibleFrame = NSScreen.main?.visibleFrame"))
    #expect(appDelegate.contains("let width = min(DashboardLayout.idealContentSize.width, visibleFrame.width - 48)"))
    #expect(appDelegate.contains("let height = min(DashboardLayout.idealContentSize.height, visibleFrame.height - 48)"))
    #expect(appDelegate.contains("contentRect: initialDashboardWindowFrame()"))
    #expect(!appDelegate.contains("contentRect: NSRect(x: 0, y: 0, width: 1320, height: 860)"))
    #expect(!appDelegate.contains("window.center()"))
}

@Test func mainKeepsAppDelegateStrongForRunLoopLifetime() throws {
    let main = try fixture("Sources/PulseDockApp/main.swift")

    #expect(main.contains("final class PulseDockApplication"))
    #expect(main.contains("private let delegate = AppDelegate()"))
    #expect(main.contains("PulseDockApplication().run()"))
}

@Test func dashboardUsesAdaptiveColumnsForCompactWindows() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    #expect(dashboard.contains("private func adaptiveMetricColumns(for width: CGFloat) -> [GridItem]"))
    #expect(dashboard.contains("GeometryReader { proxy in"))
    #expect(dashboard.contains("adaptiveMetricColumns(for: proxy.size.width)"))
    #expect(dashboard.contains("let isCompact = proxy.size.width < DashboardLayout.compactBreakpoint"))
}

@Test func dashboardUsesStableTableColumnIDsAndNoDeadSettingRow() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    #expect(!dashboard.contains("ForEach(columns, id: \\.self)"))
    #expect(dashboard.contains("Array(columns.enumerated())"))
    #expect(!dashboard.contains("private struct SettingRow: View"))
}

@Test func dashboardAvoidsDuplicatedCompactRegularPageBranch() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    #expect(dashboard.contains("let isCompact = proxy.size.width < DashboardLayout.compactBreakpoint"))
    #expect(dashboard.contains("metricColumns: adaptiveMetricColumns(for: proxy.size.width)"))
    #expect(dashboard.contains("summaryColumns: adaptiveSummaryColumns(for: proxy.size.width)"))
    #expect(!dashboard.contains("if proxy.size.width < 1080 {\n                            pageContent("))
}

@Test func dashboardPanelModifierDoesNotApplyRepeatedHeavyShadows() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let panelStart = try #require(dashboard.range(of: "func panel(cornerRadius: CGFloat) -> some View")?.lowerBound)
    let panelEnd = dashboard.range(of: "private func minimumTableWidth", range: panelStart..<dashboard.endIndex)?.lowerBound ?? dashboard.endIndex
    let panelBody = String(dashboard[panelStart..<panelEnd])

    #expect(!panelBody.contains(".shadow(color: .black.opacity(0.035), radius: 16, x: 0, y: 8)"))
    #expect(!panelBody.contains(".shadow(color: .black.opacity"))
}

@Test func progressBarsDoNotDrawFilledMinimumForTrueZeroValues() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"),
        encoding: .utf8
    )
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )

    #expect(!dashboardView.contains("private func progressFillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat"))
    #expect(!widgetPanel.contains("private func progressFillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat"))
    #expect(!widget.contains("private func progressFillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat"))
    #expect(dashboardView.contains("MetricScales.fillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 6)"))
    #expect(widgetPanel.contains("MetricScales.fillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 7)"))
    #expect(widget.contains("MetricScales.fillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 6)"))
    #expect(!dashboardView.contains(".frame(width: max(6, proxy.size.width * min(max(progress, 0), 1)))"))
    #expect(!widgetPanel.contains(".frame(width: max(7, proxy.size.width * min(max(progress, 0), 1)))"))
    #expect(!widget.contains(".frame(width: max(6, proxy.size.width * min(max(progress, 0), 1)))"))
}

@Test func appStoreScriptsValidateProductionBundleIdsAndPackageIconBeforeSigning() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let generator = try String(
        contentsOf: root.appendingPathComponent("scripts/generate-xcodeproj.rb"),
        encoding: .utf8
    )
    let packageScript = try String(
        contentsOf: root.appendingPathComponent("scripts/package-app.sh"),
        encoding: .utf8
    )
    let archiveScript = try String(
        contentsOf: root.appendingPathComponent("scripts/archive-app-store.sh"),
        encoding: .utf8
    )
    let installScript = try String(
        contentsOf: root.appendingPathComponent("scripts/install-system-widget.sh"),
        encoding: .utf8
    )

    #expect(generator.contains("app_icon = resources_group.new_file(File.join(root, \"Resources/AppIcon.icns\"))"))
    #expect(generator.contains("app_target.add_resources(shared_resource_files + app_resource_files + [app_privacy_manifest, app_icon])"))
    #expect(generator.contains("widget_target.add_resources(shared_resource_files + widget_resource_files + [widget_privacy_manifest])"))
    #expect(!packageScript.contains("cp \"$ROOT_DIR/Resources/AppIcon.icns\" \"$APP_DIR/Contents/Resources/AppIcon.icns\""))
    #expect(archiveScript.contains("validate_bundle_identifier APP_BUNDLE_IDENTIFIER \"$APP_BUNDLE_IDENTIFIER\""))
    #expect(archiveScript.contains("validate_bundle_identifier WIDGET_BUNDLE_IDENTIFIER \"$WIDGET_BUNDLE_IDENTIFIER\""))
    #expect(archiveScript.contains("[[ \"$WIDGET_BUNDLE_IDENTIFIER\" == \"$APP_BUNDLE_IDENTIFIER\".* ]]"))
    #expect(installScript.contains("validate_bundle_identifier APP_BUNDLE_IDENTIFIER \"$APP_BUNDLE_IDENTIFIER\""))
    #expect(installScript.contains("osascript - \"$APP_BUNDLE_IDENTIFIER\" <<'APPLESCRIPT'"))
}

@Test func installScriptRemovesLegacySystemDashboardRegistrationBeforeInstallingPulseDock() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let installScript = try String(
        contentsOf: root.appendingPathComponent("scripts/install-system-widget.sh"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(installScript.contains("LEGACY_APP=\"$INSTALL_DIR/System Dashboard.app\""))
    #expect(installScript.contains("LEGACY_WIDGET_BUNDLE_IDENTIFIER=\"${LEGACY_WIDGET_BUNDLE_IDENTIFIER:-local.system-dashboard.widget}\""))
    #expect(installScript.contains("EXTRA_LEGACY_WIDGET_BUNDLE_IDENTIFIERS=(\"com.qiaoni.systemdashboard.widget\")"))
    #expect(installScript.contains("unregister_legacy_widget_registrations"))
    #expect(installScript.contains("uninstall_legacy_system_dashboard"))
    #expect(installScript.contains("read_bundle_identifier \"$LEGACY_APP\""))
    #expect(installScript.contains("if [[ \"$legacy_bundle_id\" == \"local.system-dashboard\" ]]; then"))
    #expect(installScript.contains("pluginkit -e ignore -i \"$LEGACY_WIDGET_BUNDLE_IDENTIFIER\""))
    #expect(installScript.contains("pluginkit -r \"$LEGACY_WIDGET_EXTENSION\""))
    #expect(installScript.contains("rm -rf \"$LEGACY_APP\""))
    #expect(audit.contains("Local install cleanup removes the legacy System Dashboard bundle only after confirming its old bundle identifier, and unregisters old System Dashboard widget extensions before installing Pulse Dock."))
}

@Test func menuPopoverLetsNativeNSPopoverOwnOuterChrome() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widgetPanel = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"),
        encoding: .utf8
    )
    let audit = try String(
        contentsOf: root.appendingPathComponent("docs/data-capability-audit.md"),
        encoding: .utf8
    )

    #expect(!widgetPanel.contains("VisualEffectView(material: .popover"))
    #expect(!widgetPanel.contains("LinearGradient(\n                    colors: popoverBackgroundColors(for: colorScheme)"))
    #expect(!widgetPanel.contains(".clipShape(RoundedRectangle(cornerRadius: 18"))
    #expect(!widgetPanel.contains(".shadow(color: popoverShadow(for: colorScheme)"))
    #expect(!widgetPanel.contains("private func popoverShadow"))
    #expect(!widgetPanel.contains("private func popoverBackgroundColors"))
    #expect(audit.contains("The menu bar popover leaves the outer background, rounded frame, arrow, and shadow to NSPopover instead of nesting a second custom chrome inside the system popover."))
}

@Test func appStoreReadinessChecklistTracksCompletedFixes() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let checklist = try String(
        contentsOf: root.appendingPathComponent("docs/app-store-readiness-checklist.md"),
        encoding: .utf8
    )

    #expect(checklist.contains("- [x] 统一产品名为 Pulse Dock"))
    #expect(checklist.contains("- [x] 补标准 AppKit 主菜单、About 和设置快捷键"))
    #expect(checklist.contains("- [x] 声明中文本地化与 Utilities 分类"))
    #expect(checklist.contains("- [x] Widget 只刷新自己的 timeline kind"))
    #expect(checklist.contains("- [x] 暂停时停止刷新定时器"))
    #expect(checklist.contains("- [x] 修正电源状态颜色与进程启动日期显示"))
    #expect(checklist.contains("- [x] 修正 lsregister 本地注册命令参数"))
    #expect(checklist.contains("- [x] 将 Widget timeline kind 统一为 PulseDockWidget 共享常量"))
    #expect(checklist.contains("- [x] 暂停恢复时重置网络速率基线并忽略陈旧 refresh 结果"))
    #expect(checklist.contains("- [x] About 版权改由 Info.plist 的 NSHumanReadableCopyright 提供"))
    #expect(checklist.contains("- [x] 统一 LICENSE 与 About 面板版权归属"))
    #expect(checklist.contains("- [x] 为主窗口启用 frame autosave 记住用户窗口位置"))
    #expect(checklist.contains("- [x] 将内存分段条从固定宽度改为自适应可用宽度"))
    #expect(checklist.contains("- [x] 为核心自绘仪表、趋势图和状态点补基础 accessibility 语义"))
    #expect(checklist.contains("- [x] 将内部 Xcode project/target/scheme/archive 统一为 PulseDock"))
    #expect(checklist.contains("- [x] 在应用菜单和设置页补隐私政策与支持入口"))
    #expect(checklist.contains("- [x] 为 Mac App Store 截图资产补校验脚本和固定目录"))
    #expect(checklist.contains("- [x] App Store screenshots prepared and validated"))
    #expect(checklist.contains("- [x] Core custom UI accessibility labels completed"))
    #expect(checklist.contains("- [x] Widget reads shared latest app snapshot through App Group with self-sampling fallback"))
    #expect(checklist.contains("- [x] App Group provisioning prerequisite documented for production signing"))
    #expect(checklist.contains("- [x] Window minimum size lowered and compact layouts verified"))
    #expect(checklist.contains("- [x] Disk fallback no longer uses NSHomeDirectory string path"))
    #expect(checklist.contains("- [x] Running app naming replaces top-process wording at user-facing boundaries"))
    #expect(checklist.contains("Source folders were renamed to `Sources/PulseDockApp` and `Sources/PulseDockWidget`."))
    #expect(checklist.contains("- [x] Repository-local GitHub Pages sources were added for the support and privacy policy URLs."))
    #expect(!checklist.contains("- [ ] 评估 App Group 共享最近一次样本"))
    #expect(checklist.contains("- [ ] External: publish GitHub Pages privacy/support URLs and run `CHECK_PUBLIC_URLS=1 scripts/validate-public-pages.sh` before App Store submission."))
    #expect(checklist.contains("- [ ] External: verify App Group sharing with production provisioning, TestFlight, or an App Store-signed archive."))
    #expect(!checklist.contains("- [ ] 评估是否将内部 Xcode target/scheme 从 SystemDashboard 迁移为 PulseDock"))
}

@Test func publicOpenSourceRepositoryIncludesReadmeAndMITLicense() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
    let license = try String(contentsOf: root.appendingPathComponent("LICENSE"), encoding: .utf8)

    #expect(readme.contains("# Pulse Dock"))
    #expect(readme.contains("native macOS system monitor"))
    #expect(readme.contains("scripts/archive-app-store.sh"))
    #expect(readme.contains("APP_BUNDLE_IDENTIFIER=com.ifonly3.pulsedock"))
    #expect(license.contains("MIT License"))
    #expect(license.contains("乔尼的铃角"))
}

@Test func appStoreIdentityUsesPulseDockAcrossBundlesScriptsAndSurfaces() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appInfo = try String(contentsOf: root.appendingPathComponent("Resources/AppInfo.plist"), encoding: .utf8)
    let widgetInfo = try String(contentsOf: root.appendingPathComponent("Resources/WidgetInfo.plist"), encoding: .utf8)
    let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"), encoding: .utf8)
    let dashboardView = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"), encoding: .utf8)
    let widgetPanel = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/WidgetPanelView.swift"), encoding: .utf8)
    let widget = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"), encoding: .utf8)
    let widgetStrings = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/PulseDockWidgetStrings.swift"), encoding: .utf8)
    let packageManifest = try String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8)
    let packageScript = try String(contentsOf: root.appendingPathComponent("scripts/package-app.sh"), encoding: .utf8)
    let archiveScript = try String(contentsOf: root.appendingPathComponent("scripts/archive-app-store.sh"), encoding: .utf8)
    let installScript = try String(contentsOf: root.appendingPathComponent("scripts/install-system-widget.sh"), encoding: .utf8)
    let projectGenerator = try String(contentsOf: root.appendingPathComponent("scripts/generate-xcodeproj.rb"), encoding: .utf8)
    let xcodeProject = try String(contentsOf: root.appendingPathComponent("PulseDock.xcodeproj/project.pbxproj"), encoding: .utf8)
    let sharedScheme = try String(contentsOf: root.appendingPathComponent("PulseDock.xcodeproj/xcshareddata/xcschemes/PulseDock.xcscheme"), encoding: .utf8)

    #expect(appInfo.contains("<string>Pulse Dock</string>"))
    #expect(widgetInfo.contains("<string>Pulse Dock</string>"))
    #expect(appDelegate.contains("window.title = \"Pulse Dock\""))
    #expect(appDelegate.contains("accessibilityDescription: \"Pulse Dock\""))
    #expect(dashboardView.contains("Text(\"Pulse Dock\")"))
    #expect(widgetPanel.contains("Text(\"Pulse Dock\")"))
    #expect(widgetStrings.contains("localized(\"widget.display_name\", defaultValue: \"Pulse Dock\")"))
    #expect(widget.contains(".configurationDisplayName(PulseDockWidgetStrings.widgetDisplayName)"))
    #expect(widget.contains("WidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName"))
    #expect(widget.contains("CompactWidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName"))
    #expect(widget.contains("Text(PulseDockWidgetStrings.widgetDisplayName)"))
    #expect(packageManifest.contains("name: \"PulseDock\""))
    #expect(packageManifest.contains(".executable(name: \"PulseDockApp\", targets: [\"PulseDockApp\"])"))
    #expect(packageManifest.contains("name: \"PulseDockApp\""))
    #expect(packageManifest.contains("path: \"Sources/PulseDockApp\""))
    #expect(packageScript.contains("APP_DIR=\"$ROOT_DIR/dist/Pulse Dock.app\""))
    #expect(packageScript.contains("APP_BUNDLE_IDENTIFIER=\"${APP_BUNDLE_IDENTIFIER:-local.pulsedock}\""))
    #expect(packageScript.contains("BUILT_APP=\"$PACKAGE_DERIVED_DATA_PATH/Build/Products/$PACKAGE_CONFIGURATION/Pulse Dock.app\""))
    #expect(packageScript.contains("-project PulseDock.xcodeproj"))
    #expect(packageScript.contains("-scheme PulseDock"))
    #expect(archiveScript.contains("ARCHIVE_PATH=\"${ARCHIVE_PATH:-$ROOT_DIR/dist/PulseDock.xcarchive}\""))
    #expect(archiveScript.contains("-project PulseDock.xcodeproj"))
    #expect(archiveScript.contains("-scheme PulseDock"))
    #expect(installScript.contains("SOURCE_APP=\"$ROOT_DIR/dist/Pulse Dock.app\""))
    #expect(installScript.contains("INSTALLED_APP=\"$INSTALL_DIR/Pulse Dock.app\""))
    #expect(installScript.contains("APP_BUNDLE_IDENTIFIER=\"${APP_BUNDLE_IDENTIFIER:-local.pulsedock}\""))
    #expect(projectGenerator.contains("project_path = File.join(root, \"PulseDock.xcodeproj\")"))
    #expect(projectGenerator.contains("legacy_project_path = File.join(root, \"SystemDashboard.xcodeproj\")"))
    #expect(projectGenerator.contains("app_bundle_identifier = ENV.fetch(\"APP_BUNDLE_IDENTIFIER\", \"com.ifonly3.pulsedock\")"))
    #expect(projectGenerator.contains("app_target = project.new_target(:application, \"PulseDock\""))
    #expect(projectGenerator.contains("widget_target = project.new_target(:app_extension, \"PulseDockWidgetExtension\""))
    #expect(projectGenerator.contains("app_target.product_reference.path = \"Pulse Dock.app\""))
    #expect(projectGenerator.contains("Resources/PulseDock.entitlements"))
    #expect(projectGenerator.contains("Resources/PulseDockWidgetExtension.entitlements"))
    #expect(projectGenerator.contains("settings[\"PRODUCT_NAME\"] = target == app_target ? \"Pulse Dock\" : \"PulseDockWidgetExtension\""))
    #expect(packageScript.contains("--entitlements \"$ROOT_DIR/Resources/PulseDock.entitlements\""))
    #expect(packageScript.contains("--entitlements \"$ROOT_DIR/Resources/PulseDockWidgetExtension.entitlements\""))
    #expect(projectGenerator.contains("scheme.save_as(project.path, \"PulseDock\", true)"))
    #expect(xcodeProject.contains("PRODUCT_NAME = \"Pulse Dock\";"))
    #expect(xcodeProject.contains("name = PulseDock;"))
    #expect(xcodeProject.contains("PulseDockWidgetExtension"))
    #expect(!xcodeProject.contains("name = SystemDashboard;"))
    #expect(!xcodeProject.contains("SystemDashboardWidgetExtension"))
    #expect(sharedScheme.contains("BuildableName = \"Pulse Dock.app\""))
    #expect(sharedScheme.contains("BlueprintName = \"PulseDock\""))
    #expect(sharedScheme.contains("ReferencedContainer = \"container:PulseDock.xcodeproj\""))
    #expect(![appInfo, widgetInfo, appDelegate, dashboardView, widgetPanel, widget, packageScript, projectGenerator].contains { text in
        text.contains("System Pulse") || text.contains("System Dashboard")
    })
    #expect(!installScript.contains("System Pulse"))
    #expect(installScript.contains("LEGACY_APP=\"$INSTALL_DIR/System Dashboard.app\""))
}

@Test func appDelegateInstallsStandardMainMenuAndRestorableStateHooks() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"),
        encoding: .utf8
    )

    #expect(appDelegate.contains("configureMainMenu()"))
    #expect(appDelegate.contains("NSApp.mainMenu = mainMenu"))
    #expect(appDelegate.contains("private func makeAppMenu() -> NSMenuItem"))
    #expect(appDelegate.contains("private func makeEditMenu() -> NSMenuItem"))
    #expect(appDelegate.contains("private func makeViewMenu() -> NSMenuItem"))
    #expect(appDelegate.contains("private func makeWindowMenu() -> NSMenuItem"))
    #expect(appDelegate.contains("@objc private func showAboutPanel"))
    #expect(appDelegate.contains("@objc private func openSettingsFromMenu"))
    #expect(appDelegate.contains("@objc private func openPrivacyPolicyFromMenu"))
    #expect(appDelegate.contains("@objc private func openSupportFromMenu"))
    #expect(appDelegate.contains("NSApp.orderFrontStandardAboutPanel"))
    #expect(appDelegate.contains("settingsItem.keyEquivalent = \",\""))
    #expect(appDelegate.contains("func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool"))
    #expect(appDelegate.contains("return true"))
    #expect(appDelegate.contains("NSApp.activate()"))
    #expect(!appDelegate.contains("activate(ignoringOtherApps: true)"))
}

@Test func appStoreMetadataDeclaresLocalizationCategoryAndAvoidsDeadAssetCatalogSettings() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appInfo = try String(contentsOf: root.appendingPathComponent("Resources/AppInfo.plist"), encoding: .utf8)
    let widgetInfo = try String(contentsOf: root.appendingPathComponent("Resources/WidgetInfo.plist"), encoding: .utf8)
    let projectGenerator = try String(contentsOf: root.appendingPathComponent("scripts/generate-xcodeproj.rb"), encoding: .utf8)
    let xcodeProject = try String(contentsOf: root.appendingPathComponent("PulseDock.xcodeproj/project.pbxproj"), encoding: .utf8)

    for plist in [appInfo, widgetInfo] {
        #expect(plist.contains("<key>CFBundleDevelopmentRegion</key>"))
        #expect(plist.contains("<string>zh-Hans</string>"))
        #expect(plist.contains("<key>CFBundleLocalizations</key>"))
    }

    #expect(appInfo.contains("<key>LSApplicationCategoryType</key>"))
    #expect(appInfo.contains("<string>public.app-category.utilities</string>"))
    #expect(appInfo.contains("<key>ITSAppUsesNonExemptEncryption</key>"))
    #expect(appInfo.contains("<false/>"))
    #expect(!projectGenerator.contains("ASSETCATALOG_COMPILER_APPICON_NAME"))
    #expect(!projectGenerator.contains("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"))
    #expect(!xcodeProject.contains("ASSETCATALOG_COMPILER_APPICON_NAME"))
    #expect(!xcodeProject.contains("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"))
}

@Test func appRefreshAndWidgetTimelineAvoidUnnecessaryWakeups() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let metricsStore = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"),
        encoding: .utf8
    )
    let widget = try String(
        contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"),
        encoding: .utf8
    )

    #expect(metricsStore.contains("timer?.invalidate()\n            timer = nil"))
    #expect(metricsStore.contains("} else {\n            sampler.resetNetworkBaselines()\n            sampler.resetCPUBaselines()\n            scheduleTimer()\n            startInitialRefresh()"))
    #expect(metricsStore.contains("WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKind.pulseDock)"))
    #expect(!metricsStore.contains("WidgetCenter.shared.reloadAllTimelines()"))
    #expect(!widget.contains("Thread.sleep"))
}

@Test func powerToneDistinguishesChargingBatteryAndLowPowerStates() {
    let chargingHigh = MetricSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.82,
        batteryIsCharging: true,
        batteryPowerSource: "AC Power",
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let batteryHigh = MetricSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.82,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let batteryMedium = MetricSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.32,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 1)
    )
    let batteryLow = MetricSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 1,
        memoryTotalBytes: 2,
        loadAverage: 0,
        thermalState: "Nominal",
        batteryPercent: 0.12,
        batteryIsCharging: false,
        batteryPowerSource: "Battery Power",
        diskFreeBytes: 1,
        timestamp: Date(timeIntervalSince1970: 1)
    )

    #expect(chargingHigh.powerStatusTone == .normal)
    #expect(batteryHigh.powerStatusTone == .normal)
    #expect(batteryMedium.powerStatusTone == .warning)
    #expect(batteryLow.powerStatusTone == .critical)
}

@Test func releaseScriptsRegisterAppBundlesWithoutInvalidLsregisterOptions() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let packageScript = try String(contentsOf: root.appendingPathComponent("scripts/package-app.sh"), encoding: .utf8)
    let installScript = try String(contentsOf: root.appendingPathComponent("scripts/install-system-widget.sh"), encoding: .utf8)

    for script in [packageScript, installScript] {
        #expect(!script.contains("-trusted"))
        #expect(!script.contains("-f -R"))
    }

    #expect(packageScript.contains("lsregister \\\n  -f \"$APP_DIR\""))
    #expect(installScript.contains("lsregister \\\n  -f \"$INSTALLED_APP\""))
}

@Test func widgetTimelineKindUsesPulseDockSharedConstant() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widgetKind = (try? String(contentsOf: root.appendingPathComponent("Sources/SharedMetrics/WidgetTimelineKind.swift"), encoding: .utf8)) ?? ""
    let metricsStore = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"), encoding: .utf8)
    let widget = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockWidget/SystemDashboardWidget.swift"), encoding: .utf8)

    #expect(widgetKind.contains("public enum WidgetTimelineKind"))
    #expect(widgetKind.contains("public static let pulseDock = \"PulseDockWidget\""))
    #expect(metricsStore.contains("WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKind.pulseDock)"))
    #expect(widget.contains("let kind = WidgetTimelineKind.pulseDock"))
    #expect(!metricsStore.contains("\"SystemDashboardWidget\""))
    #expect(!widget.contains("let kind = \"SystemDashboardWidget\""))
}

@Test func widgetSourceCompilesUnderSwiftPMWithoutBundleEntryPoint() throws {
    let package = try fixture("Package.swift")
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(package.contains(".target(\n            name: \"PulseDockWidget\",\n            dependencies: [\"SharedMetrics\"],\n            path: \"Sources/PulseDockWidget\""))
    #expect(package.contains("resources: [\n                .process(\"Resources\")\n            ],\n            linkerSettings: [\n                .linkedFramework(\"SwiftUI\"),\n                .linkedFramework(\"WidgetKit\")\n            ]"))
    #expect(package.contains(".testTarget(\n            name: \"SharedMetricsTests\",\n            dependencies: [\"SharedMetrics\", \"PulseDockWidget\"]"))
    #expect(widget.contains("#if !SWIFT_PACKAGE\n@main\nstruct SystemDashboardWidgetBundle: WidgetBundle"))
    #expect(widget.contains("case .systemLarge:\n                LargeWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone, entryKind: entry.kind)"))
    #expect(widget.contains("default:\n                SmallWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone, entryKind: entry.kind)"))
    #expect(widget.contains("return systemSampler.sampleWidgetCompact()"))
    #expect(!widget.contains("return systemSampler.sample()"))
}

@Test func pauseResumeResetsNetworkBaselinesAndRejectsStaleRefreshResults() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let sampler = try String(contentsOf: root.appendingPathComponent("Sources/SharedMetrics/SystemSampler.swift"), encoding: .utf8)
    let metricsStore = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/MetricsStore.swift"), encoding: .utf8)

    #expect(sampler.contains("public func resetNetworkBaselines()"))
    #expect(sampler.contains("previousNetworkInBytes = nil"))
    #expect(sampler.contains("previousNetworkOutBytes = nil"))
    #expect(sampler.contains("previousNetworkDate = nil"))
    #expect(sampler.contains("public func resetCPUBaselines()"))
    #expect(sampler.contains("previousCPUInfo = []"))
    #expect(metricsStore.contains("sampler.resetNetworkBaselines()"))
    #expect(metricsStore.contains("sampler.resetCPUBaselines()"))
    #expect(metricsStore.contains("private var refreshGeneration = 0"))
    #expect(metricsStore.contains("refreshGeneration += 1"))
    #expect(metricsStore.contains("let generation = refreshGeneration"))
    #expect(metricsStore.contains("guard generation == refreshGeneration else { return }"))
}

@Test func appKitPolishCoversAboutStatusItemAndReadOnlyWidgetRefreshSetting() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"), encoding: .utf8)
    let dashboardView = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"), encoding: .utf8)

    #expect(!appDelegate.contains("NSApplication.AboutPanelOptionKey(rawValue: \"Copyright\")"))
    #expect(appDelegate.contains("if let statusItem {"))
    #expect(appDelegate.contains("NSStatusBar.system.removeStatusItem(statusItem)"))
    #expect(appDelegate.contains("self.statusItem = nil"))
    #expect(!appDelegate.contains("private func statusPopoverSize(for button: NSStatusBarButton) -> NSSize"))
    #expect(!appDelegate.contains("private func statusPopoverPreferredEdge(for button: NSStatusBarButton, contentSize: NSSize) -> NSRectEdge"))
    #expect(dashboardView.contains("SettingReadOnlyRow("))
    #expect(dashboardView.contains("title: PulseDockAppStrings.settingsWidgetRefreshTitle"))
    #expect(dashboardView.contains("control: PulseDockAppStrings.settingsWidgetRefreshValue"))
    #expect(!dashboardView.contains("control: \"5m\""))
    #expect(dashboardView.contains("private struct SettingReadOnlyRow: View"))
    #expect(dashboardView.contains(".opacity(0.78)"))
}

@Test func widgetExtensionDeclaresAttributesForGeneratedBundleMetadata() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let widgetInfo = try String(contentsOf: root.appendingPathComponent("Resources/WidgetInfo.plist"), encoding: .utf8)

    #expect(widgetInfo.contains("<key>NSExtensionAttributes</key>"))
    #expect(widgetInfo.contains("<dict/>"))
}

@Test func aboutPanelUsesInfoPlistCopyrightAndLicenseMatchesOwner() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appInfo = try String(contentsOf: root.appendingPathComponent("Resources/AppInfo.plist"), encoding: .utf8)
    let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"), encoding: .utf8)
    let license = try String(contentsOf: root.appendingPathComponent("LICENSE"), encoding: .utf8)

    #expect(appInfo.contains("<key>NSHumanReadableCopyright</key>"))
    #expect(appInfo.contains("<string>© 2026 乔尼的铃角</string>"))
    #expect(!appDelegate.contains("NSApplication.AboutPanelOptionKey(rawValue: \"Copyright\")"))
    #expect(license.contains("Copyright (c) 2026 乔尼的铃角"))
    #expect(!license.contains("Copyright (c) 2026 Pulse Dock contributors"))
}

@Test func mainWindowPersistsUserFrameAcrossLaunches() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/AppDelegate.swift"), encoding: .utf8)
    let autosavePosition = appDelegate.range(of: "window.setFrameAutosaveName(\"PulseDockMainWindow\")")?.lowerBound
    let contentPosition = appDelegate.range(of: "window.contentView = NSHostingView")?.lowerBound

    #expect(appDelegate.contains("window.setFrameAutosaveName(\"PulseDockMainWindow\")"))
    #expect(autosavePosition != nil)
    #expect(contentPosition != nil)
    if let autosavePosition, let contentPosition {
        #expect(autosavePosition < contentPosition)
    }
    #expect(!appDelegate.contains("window.center()"))
}

@Test func memorySegmentBarUsesAvailableWidthInsteadOfMagicConstant() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"), encoding: .utf8)
    let start = try #require(dashboardView.range(of: "private struct MemorySegmentBar")?.lowerBound)
    let end = dashboardView.range(of: "private struct CapacitySegment")?.lowerBound ?? dashboardView.endIndex
    let memorySegmentBar = String(dashboardView[start..<end])

    #expect(memorySegmentBar.contains("GeometryReader { proxy in"))
    #expect(memorySegmentBar.contains("proxy.size.width"))
    #expect(memorySegmentBar.contains("private func segmentWidth(_ bytes: UInt64, in totalWidth: CGFloat) -> CGFloat"))
    #expect(!memorySegmentBar.contains("* 420"))
}

@Test func customDashboardVisualControlsExposeAccessibilitySemantics() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let dashboardView = try String(contentsOf: root.appendingPathComponent("Sources/PulseDockApp/DashboardView.swift"), encoding: .utf8)

    #expect(dashboardView.contains(".accessibilityElement(children: .combine)"))
    #expect(dashboardView.contains(".accessibilityLabel(\"\\(title), \\(value)\""))
    #expect(dashboardView.contains(".accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockAppStrings.notReported)"))
    #expect(dashboardView.contains(".accessibilityLabel(PulseDockAppStrings.accessibilityTrendChart"))
    #expect(dashboardView.contains(".accessibilityValue(sparklineAccessibilityValue)"))
    #expect(dashboardView.contains(".accessibilityHidden(true)"))
}

@Test func dashboardRowsAndCardsExposeAccessibilitySemantics() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

    #expect(componentBody(named: "SummaryCard", in: dashboard).contains(".accessibilityElement(children: .combine)"))
    #expect(componentBody(named: "SummaryCard", in: dashboard).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "StatusSummaryRow", in: dashboard).contains(".accessibilityLabel(\"\\(title), \\(value), \\(status.text)\")"))
    #expect(componentBody(named: "SourceCapabilityCard", in: dashboard).contains(".accessibilityLabel(\"\\(title), \\(value), \\(source)\")"))
    #expect(componentBody(named: "TableRow", in: dashboard).contains(".accessibilityLabel(values.joined(separator: \", \"))"))
    #expect(componentBody(named: "StatLine", in: dashboard).contains(".accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockAppStrings.notReported)"))
    #expect(componentBody(named: "CoreUsageTile", in: dashboard).contains(".accessibilityLabel(\"Core \\(index), \\(MetricFormatting.percentage(value))\")"))
}

@Test func dashboardStatusRowsKeepLongValuesReadableOnOneLine() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let statusRow = componentBody(named: "StatusSummaryRow", in: dashboard)

    #expect(statusRow.contains(".lineLimit(1)"))
    #expect(statusRow.contains(".minimumScaleFactor(0.78)"))
    #expect(statusRow.contains(".layoutPriority(1)"))
    #expect(statusRow.contains("Spacer(minLength: 8)"))
}

@Test func popoverAndWidgetMetricsExposeAccessibilitySemantics() throws {
    let popover = try fixture("Sources/PulseDockApp/WidgetPanelView.swift")
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(componentBody(named: "PopoverMetricRow", in: popover).contains(".accessibilityLabel(\"\\(title), \\(value), \\(detail)\")"))
    #expect(componentBody(named: "PopoverSmallStat", in: popover).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "RingMetric", in: widget).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "WidgetRow", in: widget).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "MiniStatus", in: widget).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
    #expect(componentBody(named: "StatTile", in: widget).contains(".accessibilityLabel(\"\\(title), \\(value)\")"))
}

@Test func thresholdFeatureUsesJudgmentCopyAndDoesNotAddNotificationPermissionInV1() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let appPrivacy = try fixture("Resources/App/PrivacyInfo.xcprivacy")
    let audit = try fixture("docs/data-capability-audit.md")
    let readinessChecklist = try fixture("docs/app-store-readiness-checklist.md")
    let releaseChecklist = try fixture("docs/app-store-release-checklist.md")

    #expect(dashboard.contains("PulseDockAppStrings.dashboardPageHistorySubtitle"))
    #expect(dashboard.contains("DashboardPanel(title: PulseDockAppStrings.localRuleTableTitle, subtitle: PulseDockAppStrings.localRuleTableSubtitle"))
    #expect(!dashboard.contains("本地采样历史与告警"))
    #expect(!dashboard.contains("Toggle(\"系统通知\""))
    #expect(!appDelegate.contains("UNUserNotificationCenter"))
    #expect(!metricsStore.contains("AlertNotificationController"))
    #expect(!appPrivacy.contains("UserNotifications"))
    #expect(audit.contains("Status thresholds are dashboard-only for v1."))
    #expect(readinessChecklist.contains("Local notifications are deferred to a future opt-in feature."))
    #expect(releaseChecklist.contains("Local notifications are deferred to a future opt-in feature."))
}

@Test func appAndWidgetInfoPlistsContainStoreMetadata() throws {
    let appInfo = try fixture("Resources/AppInfo.plist")
    let widgetInfo = try fixture("Resources/WidgetInfo.plist")

    #expect(appInfo.contains("<key>CFBundleDisplayName</key>"))
    #expect(appInfo.contains("<string>Pulse Dock</string>"))
    #expect(appInfo.contains("<key>ITSAppUsesNonExemptEncryption</key>"))
    #expect(widgetInfo.contains("<key>ITSAppUsesNonExemptEncryption</key>"))
    #expect(widgetInfo.contains("<false/>"))
}

@Test func sourceLayoutUsesPulseDockNamesInsteadOfSystemDashboardResidue() throws {
    let package = try fixture("Package.swift")
    let generator = try fixture("scripts/generate-xcodeproj.rb")

    #expect(directoryExists("Sources/PulseDockApp"))
    #expect(directoryExists("Sources/PulseDockWidget"))
    #expect(!directoryExists("Sources/SystemDashboardApp"))
    #expect(!directoryExists("Sources/SystemDashboardWidget"))
    #expect(package.contains("path: \"Sources/PulseDockApp\""))
    #expect(generator.contains("\"Sources/PulseDockApp/*.swift\""))
    #expect(generator.contains("\"Sources/PulseDockWidget/*.swift\""))
}

@Test func widgetDarkPaletteAvoidsBrownBackgroundStops() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let widgetTokens = try fixture("Sources/PulseDockWidget/WidgetVisualTokens.swift")
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(widgetTokens.contains("func widgetBackgroundColors(for colorScheme: ColorScheme) -> [Color]"))
    #expect(!widget.contains("Color(red: 0.17, green: 0.13, blue: 0.08).opacity(0.82)"))
    #expect(!widgetTokens.contains("Color(red: 0.17, green: 0.13, blue: 0.08).opacity(0.82)"))
    #expect(widgetTokens.contains("Color(red: 0.06, green: 0.09, blue: 0.11).opacity(0.82)"))
    #expect(widgetTokens.contains("enum WidgetColor"))
    #expect(widgetTokens.contains("static func green(for colorScheme: ColorScheme) -> Color"))
    #expect(audit.contains("Widget dark-mode palette uses cool neutral stops and color-scheme-aware accents."))
}

@Test func emptyWidgetStateHasAccessibleLoadingLabel() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(widget.contains("private struct EmptyDataWidget: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("Text(PulseDockWidgetStrings.waitingData)"))
    #expect(widget.contains(".accessibilityLabel(PulseDockWidgetStrings.waitingSystemData)"))
    #expect(widget.contains("private var shouldInlineLoadingLabel: Bool { family == .systemSmall }"))
    #expect(widget.contains("if shouldInlineLoadingLabel {"))
    #expect(widget.contains("compactLoadingHeader"))
    #expect(widget.contains("} else {\n                normalHeader"))
    #expect(widget.contains("if !shouldInlineLoadingLabel {"))
    #expect(widget.contains("if family != .systemSmall {"))
    #expect(widget.contains(".lineLimit(1)"))
    #expect(widget.contains(".minimumScaleFactor(0.75)"))
}

@Test func widgetColorHelpersReceiveColorSchemeExplicitly() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(widget.contains("private struct SmallWidget: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("private struct LargeWidget: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("private struct MediumStatusStrip: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("private struct LargeInfoGrid: View {\n    @Environment(\\.colorScheme) private var colorScheme"))
    #expect(widget.contains("private func thermalTint(_ state: String, for colorScheme: ColorScheme) -> Color"))
    #expect(widget.contains("private func networkTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color"))
    #expect(widget.contains("private func reportedTint(hasReport: Bool, fallback: Color, for colorScheme: ColorScheme) -> Color"))
    #expect(widget.contains("private func powerTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color"))
    #expect(!widget.contains("WidgetColor.green)"))
    #expect(!widget.contains("WidgetColor.blue)"))
    #expect(!widget.contains("WidgetColor.amber)"))
    #expect(!widget.contains("WidgetColor.cyan)"))
    #expect(!widget.contains("WidgetColor.red)"))
}

@Test func metricsStoreUsesExplicitLifecycleCleanupInsteadOfAssumeIsolatedDeinit() throws {
    let store = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let delegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

    #expect(store.contains("func stopForTermination()"))
    #expect(!store.contains("MainActor.assumeIsolated"))
    #expect(delegate.contains("store.stopForTermination()"))
    #expect(delegate.contains("statusPopover?.close()"))
    #expect(delegate.contains("NSStatusBar.system.removeStatusItem"))
}

@Test func appRegistersWakeAndScreenChangeRefreshHooks() throws {
    let store = try fixture("Sources/PulseDockApp/MetricsStore.swift")
    let delegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")

    #expect(delegate.contains("NSWorkspace.didWakeNotification"))
    #expect(delegate.contains("NSApplication.didChangeScreenParametersNotification"))
    #expect(store.contains("func handleSystemWake()"))
    #expect(store.contains("func handleScreenConfigurationChange()"))
    #expect(sampler.contains("public func invalidateDisplaysCache()"))
}

@Test func sharedSnapshotLoadLogsDecodeFailuresInDebugBuilds() throws {
    let sharedStore = try fixture("Sources/SharedMetrics/SharedSnapshotStore.swift")
    let metricsStore = try fixture("Sources/PulseDockApp/MetricsStore.swift")

    #expect(sharedStore.contains("do {"))
    #expect(sharedStore.contains("catch {"))
    #expect(sharedStore.contains("SharedSnapshotStore failed to decode latest snapshot"))
    #expect(metricsStore.contains("MetricsStore failed to decode history"))
    #expect(metricsStore.contains("MetricsStore failed to encode history"))
}

@Test func dashboardAvoidsRepeatedTrendExtractionAndHighFrequencySliderPublishing() throws {
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let store = try fixture("Sources/PulseDockApp/MetricsStore.swift")

    #expect(dashboard.contains("let cpuTrend = cpuTrendValues(from: history)"))
    #expect(dashboard.contains("let memoryTrend = memoryTrendValues(from: history)"))
    #expect(dashboard.contains("let networkTrend = networkTrendValues(from: history)"))
    #expect(dashboard.contains("@State private var draftRefreshInterval"))
    #expect(dashboard.contains("onEditingChanged"))
    #expect(store.contains("private(set) var isRefreshing"))
    #expect(!store.contains("@Published private(set) var isRefreshing"))
}

@Test func metricScalesRejectsNanProgressBeforeSwiftUITrimAndFrame() {
    #expect(MetricScales.clampedProgress(Double.nan) == nil)
    #expect(MetricScales.clampedProgress(Double.infinity) == nil)
    #expect(MetricScales.clampedProgress(-0.25) == 0)
    #expect(MetricScales.clampedProgress(1.25) == 1)
}

@Test func appAndWidgetProgressRenderingUsesFiniteClampHelper() throws {
    let scales = try fixture("Sources/SharedMetrics/MetricScales.swift")
    let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
    let popover = try fixture("Sources/PulseDockApp/WidgetPanelView.swift")
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(scales.contains("guard let normalizedProgress = clampedProgress(progress), normalizedProgress > 0 else"))
    #expect(dashboard.contains("progress.flatMap(MetricScales.clampedProgress)"))
    #expect(dashboard.contains("MetricScales.fillWidth(progress, in: proxy.size.width"))
    #expect(popover.contains("MetricScales.fillWidth(progress, in: proxy.size.width"))
    #expect(widget.contains("MetricScales.clampedProgress(progress)"))
    #expect(widget.contains("MetricScales.fillWidth(progress, in: proxy.size.width"))
    #expect(!dashboard.contains("min(max(progress, 0), 1)"))
    #expect(!popover.contains("min(max(progress, 0), 1)"))
    #expect(!widget.contains("min(max(progress, 0), 1)"))
}

@Test func widgetHeaderAndDecorativeMarksHaveAccessibleSemantics() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

    #expect(widget.contains("private struct WidgetHeader"))
    #expect(widget.contains(".accessibilityElement(children: .combine)"))
    #expect(widget.contains(".accessibilityLabel(accessibilityLabel)"))
    #expect(widget.contains("private var accessibilityLabel: String"))
    #expect(widget.contains(".accessibilityHidden(true)"))
}

@Test func widgetUserFacingShortLabelsAreLocalized() throws {
    let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
    let strings = try fixture("Sources/PulseDockWidget/PulseDockWidgetStrings.swift")

    #expect(widget.contains(".configurationDisplayName(PulseDockWidgetStrings.widgetDisplayName)"))
    #expect(widget.contains("PulseDockWidgetStrings.metricCPU"))
    #expect(widget.contains("PulseDockWidgetStrings.metricMemoryCompact"))
    #expect(widget.contains("PulseDockWidgetStrings.powerUPS"))
    #expect(strings.contains("widget.display_name"))
    #expect(strings.contains("widget.metric.cpu"))
    #expect(strings.contains("widget.metric.memory_compact"))
    #expect(strings.contains("widget.power.ups"))
}

@Test func metricSnapshotHasExplicitSchemaVersionAndDecodesCurrentSchema() throws {
    let snapshot = MetricSnapshot.placeholder
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(MetricSnapshot.self, from: data)

    #expect(decoded.schemaVersion == MetricSnapshot.currentSchemaVersion)
    #expect(MetricSnapshot.currentSchemaVersion == 1)
}

@Test func metricSnapshotDecoderKeepsInitReportInferenceSymmetric() throws {
    let metricSnapshot = try fixture("Sources/SharedMetrics/MetricSnapshot.swift")

    #expect(metricSnapshot.contains("public static let currentSchemaVersion = 1"))
    #expect(metricSnapshot.contains("schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion"))
    #expect(metricSnapshot.contains("hasLoadAverageReport = try values.decodeIfPresent(Bool.self, forKey: .hasLoadAverageReport) ?? (loadAverage > 0 || loadAverage5 > 0 || loadAverage15 > 0)"))
    #expect(metricSnapshot.contains("hasRunningAppCountReport = try values.decodeIfPresent(Bool.self, forKey: .hasRunningAppCountReport) ?? (processCount > 0 || activeApplicationCount > 0 || hiddenApplicationCount > 0)"))
    #expect(metricSnapshot.contains("hasUptimeReport = try values.decodeIfPresent(Bool.self, forKey: .hasUptimeReport) ?? (uptimeSeconds > 0)"))
}

private func fixture(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

private func swiftPMBuiltResourceBundleURL(named bundleName: String) throws -> URL {
    let roots = [Bundle.main.bundleURL, URL(fileURLWithPath: CommandLine.arguments[0])]
        + Bundle.allBundles.map(\.bundleURL)
        + loadedImageURLs()
    var visited = Set<String>()
    var candidates: [URL] = []

    for root in roots {
        var current = root.hasDirectoryPath ? root : root.deletingLastPathComponent()
        for _ in 0..<10 {
            let standardized = current.standardizedFileURL
            if visited.insert(standardized.path).inserted {
                candidates.append(standardized)
            }

            let parent = standardized.deletingLastPathComponent()
            if parent.path == standardized.path { break }
            current = parent
        }
    }

    let found = candidates.lazy.compactMap { candidate -> URL? in
        if candidate.lastPathComponent == bundleName, directoryExists(candidate) {
            return candidate
        }

        let sibling = candidate.appendingPathComponent(bundleName)
        return directoryExists(sibling) ? sibling : nil
    }.first

    return try #require(found, "Expected SwiftPM to build \(bundleName) next to the current test binary.")
}

private func loadedImageURLs() -> [URL] {
    (0..<_dyld_image_count()).compactMap { index in
        guard let name = _dyld_get_image_name(index) else { return nil }
        return URL(fileURLWithPath: String(cString: name))
    }
}

private func directoryExists(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
}

private func fileExists(_ relativePath: String) -> Bool {
    FileManager.default.fileExists(atPath: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
        .path)
}

private func directoryExists(_ relativePath: String) -> Bool {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
        .path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
}

private func componentBody(named name: String, in source: String) -> String {
    guard let start = source.range(of: "private struct \(name)")?.lowerBound else { return "" }
    let remainder = source[start...]
    if let next = remainder.dropFirst().range(of: "\nprivate struct ")?.lowerBound {
        return String(remainder[..<next])
    }
    return String(remainder)
}
