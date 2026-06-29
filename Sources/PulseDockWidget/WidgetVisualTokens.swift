import SwiftUI
#if canImport(SharedMetrics)
import SharedMetrics
#endif

enum WidgetFreshnessTone {
    case fresh
    case aging
    case stale

    static func resolve(age: TimeInterval?) -> WidgetFreshnessTone {
        guard let age, age >= 0 else { return .fresh }
        if age >= WidgetTimelinePolicy.staleThreshold { return .stale }
        if age >= WidgetTimelinePolicy.agingThreshold { return .aging }
        return .fresh
    }

    func color(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .fresh:
            WidgetColor.green(for: colorScheme)
        case .aging:
            WidgetColor.amber(for: colorScheme)
        case .stale:
            WidgetColor.red(for: colorScheme)
        }
    }

    var accessibilityText: String {
        switch self {
        case .fresh:
            return PulseDockWidgetStrings.widgetDisplayName
        case .aging, .stale:
            return PulseDockWidgetStrings.staleData
        }
    }
}

enum WidgetColor {
    static func blue(for colorScheme: ColorScheme) -> Color {
        color(.blue, for: colorScheme)
    }

    static func green(for colorScheme: ColorScheme) -> Color {
        color(.green, for: colorScheme)
    }

    static func amber(for colorScheme: ColorScheme) -> Color {
        color(.amber, for: colorScheme)
    }

    static func cyan(for colorScheme: ColorScheme) -> Color {
        color(.cyan, for: colorScheme)
    }

    static func red(for colorScheme: ColorScheme) -> Color {
        color(.red, for: colorScheme)
    }

    private static func color(_ accent: MetricAccent, for colorScheme: ColorScheme) -> Color {
        let appearance: MetricAccentAppearance = colorScheme == .dark ? .dark : .light
        let components = MetricAccentComponents.components(for: accent, appearance: appearance)
        return Color(red: components.red, green: components.green, blue: components.blue)
    }
}

func widgetBackgroundColors(for colorScheme: ColorScheme) -> [Color] {
    if colorScheme == .dark {
        return [
            Color(red: 0.09, green: 0.11, blue: 0.12).opacity(0.96),
            Color(red: 0.07, green: 0.16, blue: 0.16).opacity(0.90),
            Color(red: 0.06, green: 0.09, blue: 0.11).opacity(0.82)
        ]
    }

    return [
        Color.white.opacity(0.92),
        Color(red: 0.89, green: 0.95, blue: 0.94).opacity(0.88),
        Color(red: 0.98, green: 0.93, blue: 0.84).opacity(0.72)
    ]
}

func widgetPanelFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.40)
}

func widgetPanelStroke(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.58)
}

func widgetPrimaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary
}

func widgetSecondaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.62) : Color.secondary
}

func widgetTrackFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.14) : Color.secondary.opacity(0.14)
}

func widgetPlaceholderFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.16) : Color.secondary.opacity(0.16)
}
