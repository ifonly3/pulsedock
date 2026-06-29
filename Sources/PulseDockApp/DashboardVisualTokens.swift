import AppKit
import SwiftUI
import SharedMetrics

enum DashboardSpacing {
    static let xxs: CGFloat = 3
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum DashboardTypography {
    static let appTitle = Font.system(.title3, design: .default, weight: .semibold)
    static let pageTitle = Font.system(.title, design: .default, weight: .semibold)
    static let sectionTitle = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.system(.body, design: .default, weight: .medium)
    static let caption = Font.system(.caption, design: .default, weight: .medium)
    static let captionStrong = Font.system(.caption, design: .default, weight: .semibold)
    static let metricValue = Font.system(.title2, design: .default, weight: .semibold).monospacedDigit()
    static let compactMetricValue = Font.system(.callout, design: .default, weight: .semibold).monospacedDigit()
    static let smallMetricValue = Font.system(.caption, design: .default, weight: .semibold).monospacedDigit()
}

enum DashboardMotion {
    static func page(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    static func selection(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.16)
    }

    static func metric(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)
    }
}

enum DashboardLayout {
    static let minimumContentSize = CGSize(width: 960, height: 640)
    static let idealContentSize = CGSize(width: 1320, height: 860)
    static let sidebarWidth: CGFloat = 224
    static let compactBreakpoint: CGFloat = 1080
    static let narrowContentBreakpoint: CGFloat = 760
    static let contentHorizontalPadding: CGFloat = 24
    static let contentTopPadding: CGFloat = 18
    static let contentBottomPadding: CGFloat = 28
    static let regularAsideWidth: CGFloat = 360
    static let compactPanelSpacing: CGFloat = 12
    static let minimumTableColumnWidth: CGFloat = 96
    static let wideTableColumnWidth: CGFloat = 112
}

enum DashboardColor {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .controlBackgroundColor).opacity(0.74)
    static let panel = Color(nsColor: .textBackgroundColor).opacity(0.78)
    static let panelAlt = Color(nsColor: .controlBackgroundColor).opacity(0.86)
    static let border = Color(nsColor: .separatorColor).opacity(0.52)
    static let muted = Color.secondary.opacity(0.74)
    static let blue = adaptiveAccent(.blue)
    static let green = adaptiveAccent(.green)
    static let amber = adaptiveAccent(.amber)
    static let red = adaptiveAccent(.red)
    static let purple = Color(red: 0.48, green: 0.34, blue: 0.88)
    static let cyan = adaptiveAccent(.cyan)

    private static func adaptiveAccent(_ accent: MetricAccent) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let components = MetricAccentComponents.components(for: accent, appearance: isDark ? .dark : .light)
            return NSColor(
                calibratedRed: CGFloat(components.red),
                green: CGFloat(components.green),
                blue: CGFloat(components.blue),
                alpha: 1
            )
        })
    }
}
