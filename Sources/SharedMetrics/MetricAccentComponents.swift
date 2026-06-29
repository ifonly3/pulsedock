import Foundation

public struct MetricColorComponents: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum MetricAccent: Sendable {
    case green
    case blue
    case amber
    case cyan
    case red
}

public enum MetricAccentAppearance: Sendable {
    case light
    case dark
}

public enum MetricAccentComponents {
    public static func components(for accent: MetricAccent, appearance: MetricAccentAppearance) -> MetricColorComponents {
        switch (accent, appearance) {
        case (.green, .light):
            return MetricColorComponents(red: 0.04, green: 0.62, blue: 0.39)
        case (.green, .dark):
            return MetricColorComponents(red: 0.24, green: 0.82, blue: 0.62)
        case (.blue, .light):
            return MetricColorComponents(red: 0.14, green: 0.43, blue: 0.95)
        case (.blue, .dark):
            return MetricColorComponents(red: 0.36, green: 0.62, blue: 1.00)
        case (.amber, .light):
            return MetricColorComponents(red: 0.93, green: 0.54, blue: 0.10)
        case (.amber, .dark):
            return MetricColorComponents(red: 1.00, green: 0.68, blue: 0.28)
        case (.cyan, .light):
            return MetricColorComponents(red: 0.04, green: 0.56, blue: 0.70)
        case (.cyan, .dark):
            return MetricColorComponents(red: 0.29, green: 0.78, blue: 0.88)
        case (.red, .light):
            return MetricColorComponents(red: 0.84, green: 0.16, blue: 0.16)
        case (.red, .dark):
            return MetricColorComponents(red: 1.00, green: 0.42, blue: 0.42)
        }
    }
}
