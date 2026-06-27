import SwiftUI

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

enum DashboardColor {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .controlBackgroundColor).opacity(0.74)
    static let panel = Color(nsColor: .textBackgroundColor).opacity(0.78)
    static let panelAlt = Color(nsColor: .controlBackgroundColor).opacity(0.86)
    static let border = Color(nsColor: .separatorColor).opacity(0.52)
    static let muted = Color.secondary.opacity(0.74)
    static let blue = Color(red: 0.14, green: 0.43, blue: 0.95)
    static let green = Color(red: 0.04, green: 0.62, blue: 0.39)
    static let amber = Color(red: 0.93, green: 0.54, blue: 0.10)
    static let red = Color(red: 0.84, green: 0.16, blue: 0.16)
    static let purple = Color(red: 0.48, green: 0.34, blue: 0.88)
    static let cyan = Color(red: 0.04, green: 0.56, blue: 0.70)
}
