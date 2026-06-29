import Foundation
import Testing

private func fixture(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

@Suite("VisualFrontendGateTests")
struct VisualFrontendGateTests {
    @Test func dashboardMotionIsViewScopedAndReduceMotionAware() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")
        let store = try fixture("Sources/PulseDockApp/MetricsStore.swift")

        #expect(tokens.contains("enum DashboardMotion"))
        #expect(dashboard.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(dashboard.contains(".transition("))
        #expect(dashboard.contains(".animation(DashboardMotion.page"))
        #expect(dashboard.contains(".animation(DashboardMotion.metric"))
        #expect(!store.contains("withAnimation"))
        #expect(!store.contains(".animation("))
    }

    @Test func visualTokensCentralizeDashboardTypographySpacingAndColors() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")

        #expect(tokens.contains("enum DashboardTypography"))
        #expect(tokens.contains("enum DashboardSpacing"))
        #expect(tokens.contains("enum DashboardColor"))
        #expect(tokens.contains("enum DashboardLayout"))
        #expect(tokens.contains("Font.system(.title2"))
        #expect(dashboard.contains("DashboardTypography.metricValue"))
        #expect(dashboard.contains("DashboardSpacing.md"))
        #expect(!dashboard.contains("private enum DashboardColor"))
    }

    @Test func widgetFreshnessIsVisibleAndMediumHeaderShowsTime() throws {
        let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")
        let tokens = try fixture("Sources/PulseDockWidget/WidgetVisualTokens.swift")

        #expect(widget.contains("let snapshotAge: TimeInterval?"))
        #expect(widget.contains("WidgetFreshnessTone"))
        #expect(widget.contains("CompactWidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName"))
        #expect(widget.contains("if hasTimeReport"))
        #expect(tokens.contains("enum WidgetFreshnessTone"))
        #expect(tokens.contains("PulseDockWidgetStrings.staleData"))
    }

    @Test func memorySegmentBarCannotForceOverflowWithTinySegments() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

        #expect(dashboard.contains("private let memorySegmentCount: CGFloat = 3"))
        #expect(dashboard.contains("let minimumVisibleWidth = min(8, totalWidth / memorySegmentCount)"))
        #expect(!dashboard.contains("return max(width, 8)"))
    }

    @Test func continuousAnimationPatternsStayOutOfThisPass() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let widget = try fixture("Sources/PulseDockWidget/SystemDashboardWidget.swift")

        #expect(!dashboard.contains("TimelineView(.animation"))
        #expect(!widget.contains("TimelineView(.animation"))
        #expect(!dashboard.contains("options: .repeating"))
        #expect(!widget.contains("options: .repeating"))
    }

    @Test func dashboardCompactLayoutCoversHighRiskPages() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

        #expect(dashboard.contains("CPUPage(snapshot: snapshot, history: history, isCompact: isCompact)"))
        #expect(dashboard.contains("MemoryPage(snapshot: snapshot, history: history, isCompact: isCompact)"))
        #expect(dashboard.contains("PowerPage(snapshot: snapshot, history: history, isCompact: isCompact)"))
        #expect(dashboard.contains("SensorsPage(store: store, isCompact: isCompact, capabilityColumns: capabilityColumns)"))
        #expect(dashboard.contains("StoragePage(store: store, history: history, capabilityColumns: capabilityColumns)"))
        #expect(dashboard.contains("GPUDisplayPage(snapshot: snapshot, capabilityColumns: capabilityColumns)"))
        #expect(dashboard.contains("ResponsivePanelPair(isCompact: isCompact"))
    }

    @Test func dashboardSidebarAndTopBarAreCompactSafe() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let sidebar = componentBody(named: "DashboardSidebar", in: dashboard)
        let topBar = componentBody(named: "DashboardTopBar", in: dashboard)

        #expect(sidebar.contains("ScrollView"))
        #expect(!sidebar.contains("SidebarHealthCard"))
        #expect(sidebar.contains("DashboardLayout.sidebarWidth"))
        #expect(topBar.contains("ViewThatFits(in: .horizontal)"))
        #expect(topBar.contains(".frame(minHeight: 82)"))
        #expect(topBar.contains("compactContent"))
    }

    @Test func dashboardWindowMinimumSizeMatchesContentArea() throws {
        let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

        #expect(appDelegate.contains("DashboardLayout.minimumContentSize"))
        #expect(appDelegate.contains("frameRect(forContentRect:"))
        #expect(appDelegate.contains("window.titlebarAppearsTransparent = false"))
        #expect(!appDelegate.contains("window.minSize = NSSize(width: 960, height: 640)"))
    }

    @Test func dashboardDenseTablesUseResponsiveTableWrapper() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

        #expect(dashboard.contains("private struct ResponsiveTable"))
        #expect(dashboard.contains("ScrollView(.horizontal"))
        #expect(dashboard.contains("minimumTableWidth(columnCount:"))
        #expect(dashboard.contains("columns: PulseDockAppStrings.storageVolumeTableColumns"))
        #expect(dashboard.contains("columns: PulseDockAppStrings.networkInterfaceTableColumns"))
        #expect(dashboard.contains("columns: PulseDockAppStrings.displayTableColumns"))
        #expect(!dashboard.contains("TableHeader(columns: PulseDockAppStrings.storageVolumeTableColumns)"))
        #expect(!dashboard.contains("TableHeader(columns: PulseDockAppStrings.networkInterfaceTableColumns)"))
        #expect(!dashboard.contains("TableHeader(columns: PulseDockAppStrings.displayTableColumns)"))
    }

    @Test func dashboardFixedGridsUseAdaptiveColumns() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

        #expect(dashboard.contains("private func adaptiveCapabilityColumns(for width: CGFloat) -> [GridItem]"))
        #expect(dashboard.contains("private func adaptiveCoreColumns() -> [GridItem]"))
        #expect(dashboard.contains("GridItem(.adaptive(minimum:"))
        #expect(!dashboard.contains("Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)"))
        #expect(!dashboard.contains("Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)"))
    }

    @Test func compactMetricComponentsAvoidHardCompression() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let keyValueGrid = componentBody(named: "KeyValueGrid", in: dashboard)
        let trendRow = componentBody(named: "TrendRow", in: dashboard)

        #expect(keyValueGrid.contains("GridItem(.adaptive(minimum: minimumColumnWidth)"))
        #expect(keyValueGrid.contains("var minimumColumnWidth: CGFloat = 132"))
        #expect(!keyValueGrid.contains("GridItem(.flexible()), GridItem(.flexible())"))
        #expect(trendRow.contains("ViewThatFits(in: .horizontal)"))
        #expect(trendRow.contains("trendSparkline"))
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
