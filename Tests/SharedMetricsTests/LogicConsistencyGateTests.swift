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
