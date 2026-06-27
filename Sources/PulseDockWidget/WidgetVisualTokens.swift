import SwiftUI

enum WidgetFreshnessTone {
    case fresh
    case aging
    case stale

    static func resolve(age: TimeInterval?) -> WidgetFreshnessTone {
        guard let age, age >= 0 else { return .fresh }
        if age >= 600 { return .stale }
        if age >= 300 { return .aging }
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
        colorScheme == .dark ? Color(red: 0.36, green: 0.62, blue: 1.00) : Color(red: 0.14, green: 0.43, blue: 0.95)
    }

    static func green(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.24, green: 0.82, blue: 0.62) : Color(red: 0.04, green: 0.62, blue: 0.39)
    }

    static func amber(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 1.00, green: 0.68, blue: 0.28) : Color(red: 0.93, green: 0.54, blue: 0.10)
    }

    static func cyan(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.29, green: 0.78, blue: 0.88) : Color(red: 0.04, green: 0.56, blue: 0.70)
    }

    static func red(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 1.00, green: 0.42, blue: 0.42) : Color(red: 0.84, green: 0.16, blue: 0.16)
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
