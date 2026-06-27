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
}
