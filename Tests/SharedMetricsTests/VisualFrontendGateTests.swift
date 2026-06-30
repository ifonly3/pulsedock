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
        #expect(topBar.contains(".frame(maxWidth: .infinity, minHeight: DashboardLayout.topBarMinHeight, alignment: .leading)"))
        #expect(topBar.contains("compactContent"))
    }

    @Test func responsiveFrontendReviewCoversDashboardChromeAndWidgets() throws {
        let review = try fixture("docs/review/frontend-responsive-design-review.md")

        for required in [
            "Dashboard Overview",
            "Dashboard CPU",
            "Dashboard GPU / Displays",
            "Dashboard Memory",
            "Dashboard Storage",
            "Dashboard Network",
            "Dashboard Power",
            "Dashboard Apps",
            "Dashboard Status",
            "Dashboard History",
            "Dashboard Settings",
            "Menu Bar Status",
            "Menu Bar Popover",
            "Small Widget",
            "Medium Widget",
            "RF-1"
        ] {
            #expect(review.contains(required))
        }
    }

    @Test func dashboardTopBarOwnsFullWidthHeaderBand() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")
        let topBar = componentBody(named: "DashboardTopBar", in: dashboard)

        #expect(tokens.contains("static let topBarMinHeight: CGFloat = 82"))
        #expect(topBar.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(topBar.contains(".frame(maxWidth: .infinity, minHeight: DashboardLayout.topBarMinHeight, alignment: .leading)"))
        #expect(topBar.contains("regularContent"))
        #expect(topBar.contains("compactContent"))
        #expect(!topBar.contains(".frame(minHeight: 82)"))
    }

    @Test func settingsRowsUseResponsiveControlFallbacks() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")
        let controlRow = componentBody(named: "SettingControlRow", in: dashboard)
        let readOnlyRow = componentBody(named: "SettingReadOnlyRow", in: dashboard)

        #expect(tokens.contains("static let settingsControlMaxWidth: CGFloat = 180"))
        #expect(controlRow.contains("ViewThatFits(in: .horizontal)"))
        #expect(controlRow.contains("layoutPriority(1)"))
        #expect(readOnlyRow.contains("ViewThatFits(in: .horizontal)"))
        #expect(readOnlyRow.contains("controlChip"))
    }

    @Test func dashboardWindowMinimumSizeMatchesContentArea() throws {
        let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

        #expect(appDelegate.contains("DashboardLayout.minimumContentSize"))
        #expect(appDelegate.contains("frameRect(forContentRect:"))
        #expect(appDelegate.contains("window.titlebarAppearsTransparent = false"))
        #expect(!appDelegate.contains("window.minSize = NSSize(width: 960, height: 640)"))
    }

    @Test func menuBarSelectedMetricUsesMeasuredCompactStatusLength() throws {
        let appDelegate = try fixture("Sources/PulseDockApp/AppDelegate.swift")

        #expect(appDelegate.contains("static let metricMinLength: CGFloat = 46"))
        #expect(appDelegate.contains("static let metricMaxLength: CGFloat = 104"))
        #expect(appDelegate.contains("static let metricHorizontalPadding: CGFloat = 7"))
        #expect(appDelegate.contains("static let iconAllowance: CGFloat = 20"))
        #expect(appDelegate.contains("static func titleLength(for text: String, font: NSFont) -> CGFloat"))
        #expect(appDelegate.contains("static func titleLength(for option: MenuBarMetricOption, font: NSFont) -> CGFloat"))
        #expect(appDelegate.contains("case .network: \"999 Mbps\""))
        #expect(appDelegate.contains("let measuredTextWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)"))
        #expect(appDelegate.contains("return min(metricMaxLength, max(metricMinLength, measuredTextWidth + metricHorizontalPadding * 2 + iconAllowance))"))
        #expect(appDelegate.contains("private var statusItemLengthMode: MenuBarMetricOption?"))
        #expect(appDelegate.contains("guard statusPopover?.isShown != true else { return }"))
        #expect(appDelegate.contains("let statusFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)"))
        #expect(appDelegate.contains("button.font = statusFont"))
        #expect(appDelegate.contains("button.title = metricText"))
        #expect(appDelegate.contains("let statusLength = MenuBarStatusItemLayout.titleLength(for: selectedMetric, font: statusFont)"))
        #expect(appDelegate.contains("applyStatusItemLength(statusLength, mode: selectedMetric)"))
        #expect(!appDelegate.contains("metricTitleLength"))
        #expect(!appDelegate.contains("button?.title = \" \\(metricText)\""))
    }

    @Test func dashboardDynamicTextUsesStableDigitComponents() throws {
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")
        let tokens = try fixture("Sources/PulseDockApp/DashboardVisualTokens.swift")

        #expect(tokens.contains("static let sampleChipMinWidth: CGFloat = 156"))
        #expect(tokens.contains("static let shortTimeChipMinWidth: CGFloat = 96"))
        #expect(tokens.contains("static let metricValueMinWidth: CGFloat = 96"))
        #expect(tokens.contains("static let statValueMinWidth: CGFloat = 56"))
        #expect(tokens.contains("static let badgeValueMinWidth: CGFloat = 42"))
        #expect(dashboard.contains("private struct StableMetricText: View"))
        #expect(dashboard.contains("@Environment(\\.accessibilityReduceMotion) private var reduceMotion"))
        #expect(dashboard.contains(".contentTransition(reduceMotion ? .identity : .numericText())"))
        #expect(dashboard.contains(".animation(DashboardMotion.metric(reduceMotion: reduceMotion), value: text)"))
        #expect(dashboard.contains("DataChip(icon: \"clock\", text: PulseDockAppStrings.dashboardSampleChip(snapshot.sampleTimeText), minWidth: DashboardLayout.sampleChipMinWidth, monospacedDigits: true)"))
        #expect(dashboard.contains("DataChip(icon: \"clock\", text: snapshot.sampleTimeText, minWidth: DashboardLayout.shortTimeChipMinWidth, monospacedDigits: true)"))
        #expect(dashboard.contains("StableMetricText(text: value, font: .system(size: 29, weight: .semibold, design: .default), minWidth: DashboardLayout.metricValueMinWidth, alignment: .leading, minimumScaleFactor: 0.68)"))
        #expect(dashboard.contains("StableMetricText(text: value, font: .system(size: 13, weight: .semibold), minWidth: DashboardLayout.statValueMinWidth, alignment: .trailing, minimumScaleFactor: 0.70)"))
        #expect(componentBody(named: "KeyValueGrid", in: dashboard).contains("StableMetricText(text: item.1, font: .system(size: 13, weight: .semibold), minWidth: DashboardLayout.statValueMinWidth, alignment: .leading, minimumScaleFactor: 0.68)"))
    }

    @Test func dynamicWidthAndMotionReviewDocumentCoversKnownSurfaces() throws {
        let review = try fixture("docs/review/frontend-dynamic-width-motion-review.md")

        #expect(review.contains("macOS menu bar status item"))
        #expect(review.contains("Dashboard top bar chips"))
        #expect(review.contains("Metric cards and badges"))
        #expect(review.contains("Settings controls"))
        #expect(review.contains("Popover widget panel"))
        #expect(review.contains("Desktop widgets"))
        #expect(review.contains("Reduce Motion"))
        #expect(review.contains("DW-1"))
        #expect(review.contains("DW-6"))
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

    @Test func responsiveReviewTracksRemainingFixedWidths() throws {
        let review = try fixture("docs/review/frontend-responsive-design-review.md")
        let dashboard = try fixture("Sources/PulseDockApp/DashboardView.swift")

        for fixedWidth in [
            ".frame(width: 360)",
            ".frame(width: 340)",
            ".frame(width: 320)",
            ".frame(width: 214)"
        ] {
            if dashboard.contains(fixedWidth) {
                #expect(review.contains(fixedWidth))
            }
        }
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
