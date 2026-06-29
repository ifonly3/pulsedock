import Foundation
import Testing

private func frontendRedundancyFixture(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

@Suite("FrontendRedundancyGateTests")
struct FrontendRedundancyGateTests {
    @Test func reviewedFrontendRedundancyDocsUseCorrectCountsAndDecisions() throws {
        let final = try frontendRedundancyFixture("docs/review/top/frontend-redundancy-final.md")

        #expect(!final.contains("去重后共 **21 条独特发现**"))
        #expect(final.contains("去重后共 **25 条独特发现**"))
        #expect(final.contains("FR-2 是本轮前端审查新增发现"))
        #expect(!final.contains("R1-4 (Power 页 Battery/KVGrid)"))
        #expect(final.contains("FR-18 | 保留"))
        #expect(final.contains("FR-19 | 保留"))
        #expect(final.contains("FR-23 | 保留"))
    }

    @Test func chromeAndPageLevelSampleTimeDuplicationIsRemoved() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let sidebar = componentBody(named: "DashboardSidebar", in: dashboard)
        let topBar = componentBody(named: "DashboardTopBar", in: dashboard)
        let cpuPage = componentBody(named: "CPUPage", in: dashboard)
        let powerPage = componentBody(named: "PowerPage", in: dashboard)

        #expect(!dashboard.contains("private struct SidebarHealthCard"))
        #expect(!sidebar.contains("SidebarHealthCard(snapshot:"))
        #expect(topBar.contains("dashboardSampleChip(snapshot.sampleTimeText)"))
        #expect(!cpuPage.contains("(PulseDockAppStrings.cpuRecentSampleLabel, snapshot.sampleTimeText)"))
        #expect(!powerPage.contains("StatusSummaryRow(title: PulseDockAppStrings.cpuRecentSampleLabel"))
        #expect(!powerPage.contains("StatusSummaryRow(title: PulseDockAppStrings.metricUptime"))
    }

    @Test func overviewAndNetworkDuplicateTrendPanelsAreRemoved() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let overviewPage = componentBody(named: "OverviewPage", in: dashboard)
        let networkPage = componentBody(named: "NetworkPage", in: dashboard)
        let historyPage = componentBody(named: "HistoryAlertsPage", in: dashboard)

        #expect(!overviewPage.contains("overviewTrendPanel"))
        #expect(overviewPage.contains("MetricCard(title: PulseDockAppStrings.overviewCPUUsageTitle"))
        #expect(overviewPage.contains("overviewStatusPanel"))
        #expect(!networkPage.contains("PulseDockAppStrings.networkTrendTitle"))
        #expect(!networkPage.contains("[PulseDockAppStrings.networkPathLabel, snapshot.networkPathText, snapshot.networkPathDetailText]"))
        #expect(historyPage.contains("PulseDockAppStrings.historyTrendsTitle"))
    }

    @Test func powerBatteryDetailsHaveOneDetailedSourceOfTruth() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let powerPage = componentBody(named: "PowerPage", in: dashboard)
        let powerDetails = functionBody(containing: "private func powerDetails(powerTrend: [Double])", in: powerPage)

        #expect(powerPage.contains("PulseDockAppStrings.batteryInformationTitle"))
        #expect(powerDetails.contains("snapshot.powerSourceText"))
        #expect(!powerDetails.contains("snapshot.batteryTimeRemainingText"))
        #expect(!powerDetails.contains("snapshot.batteryCurrentCapacityText"))
        #expect(!powerDetails.contains("snapshot.batteryMaxCapacityText"))
        #expect(!powerDetails.contains("snapshot.batteryCycleText"))
        #expect(!powerDetails.contains("snapshot.batteryHealthText"))
        #expect(!powerDetails.contains("snapshot.batteryDesignCapacityText"))
        #expect(!powerDetails.contains("snapshot.batteryVoltageText"))
        #expect(!powerDetails.contains("snapshot.batteryAmperageText"))
    }

    @Test func processListsAreConsolidatedToOverviewAndProcessesPages() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let overviewPage = componentBody(named: "OverviewPage", in: dashboard)
        let cpuPage = componentBody(named: "CPUPage", in: dashboard)
        let memoryPage = componentBody(named: "MemoryPage", in: dashboard)
        let processesPage = componentBody(named: "ProcessesPage", in: dashboard)

        #expect(overviewPage.contains("ProcessListPanel(processes: snapshot.runningApps)"))
        #expect(!cpuPage.contains("ProcessListPanel(processes: snapshot.runningApps"))
        #expect(!memoryPage.contains("ProcessListPanel(processes: snapshot.runningApps"))
        #expect(processesPage.contains("ResponsiveTable("))
        #expect(processesPage.contains("snapshot.runningApps.filter(\\.hasInventoryReport)"))
    }

    @Test func memoryOverviewSensorsAndProcessesAvoidAcceptedDuplicateRows() throws {
        let dashboard = try frontendRedundancyFixture("Sources/PulseDockApp/DashboardView.swift")
        let appStrings = try frontendRedundancyFixture("Sources/PulseDockApp/PulseDockAppStrings.swift")
        let overviewStatusPanel = functionBody(containing: "private var overviewStatusPanel", in: dashboard)
        let memoryDetails = functionBody(containing: "private func memoryDetails(memoryTrend: [Double])", in: dashboard)
        let sensorsPage = componentBody(named: "SensorsPage", in: dashboard)
        let processesPage = componentBody(named: "ProcessesPage", in: dashboard)

        #expect(!overviewStatusPanel.contains("overviewCPUStatusTitle"))
        #expect(!overviewStatusPanel.contains("overviewMemoryStatusTitle"))
        #expect(!overviewStatusPanel.contains("metricNetworkConnection"))
        #expect(!memoryDetails.contains("snapshot.memoryCachedText"))
        #expect(!memoryDetails.contains("snapshot.memoryCompressedText"))
        #expect(!memoryDetails.contains("snapshot.memorySwapText"))
        #expect(!sensorsPage.contains("snapshot.displaySummaryText"))
        #expect(!sensorsPage.contains("snapshot.gpuSummaryText"))
        #expect(!sensorsPage.contains("snapshot.storageVolumeSummaryText"))
        #expect(!sensorsPage.contains("snapshot.loadDetailText"))
        #expect(!sensorsPage.contains("snapshot.osVersionText"))
        #expect(!sensorsPage.contains("snapshot.uptimeText"))
        #expect(!processesPage.contains("processesDisplayedAppsTitle"))
        #expect(appStrings.contains("static var statusRuleTableColumns: [String]"))
        #expect(!appStrings.contains("app.dashboard.rule_table.column.current"))
    }
}

private func componentBody(named name: String, in source: String) -> String {
    guard let start = source.range(of: "private struct \(name)")?.lowerBound else { return "" }
    let remainder = source[start...]
    if let next = remainder.dropFirst().range(of: "\nprivate struct ")?.lowerBound {
        return String(remainder[..<next])
    }
    return String(remainder)
}

private func functionBody(containing marker: String, in source: String) -> String {
    guard let start = source.range(of: marker)?.lowerBound else { return "" }
    let remainder = source[start...]
    if let nextPrivate = remainder.dropFirst().range(of: "\n    private ")?.lowerBound {
        return String(remainder[..<nextPrivate])
    }
    if let nextStruct = remainder.dropFirst().range(of: "\nprivate struct ")?.lowerBound {
        return String(remainder[..<nextStruct])
    }
    return String(remainder)
}
