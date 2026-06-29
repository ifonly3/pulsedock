import Foundation

public enum ThermalState: Equatable, Sendable {
    case nominal
    case warm
    case hot
    case critical
    case unknown

    public init(raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "nominal":
            self = .nominal
        case "warm", "fair":
            self = .warm
        case "hot", "serious":
            self = .hot
        case "critical":
            self = .critical
        default:
            self = .unknown
        }
    }

    public var isReported: Bool {
        self != .unknown
    }

    public var metricStatusTone: MetricStatusTone {
        switch self {
        case .critical, .hot:
            return .critical
        case .warm:
            return .warning
        case .nominal:
            return .normal
        case .unknown:
            return .neutral
        }
    }

    public var progress: Double? {
        switch self {
        case .critical:
            return 1
        case .hot:
            return 0.78
        case .warm:
            return 0.52
        case .nominal:
            return 0.24
        case .unknown:
            return nil
        }
    }
}

public enum NetworkPathState: Equatable, Sendable {
    case satisfied
    case unsatisfied
    case requiresConnection
    case unknown

    public init(raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "satisfied":
            self = .satisfied
        case "unsatisfied":
            self = .unsatisfied
        case "requiresconnection", "requires_connection", "requires connection":
            self = .requiresConnection
        default:
            self = .unknown
        }
    }

    public var isReported: Bool {
        self != .unknown
    }

    public var metricStatusTone: MetricStatusTone {
        switch self {
        case .satisfied:
            return .normal
        case .requiresConnection:
            return .warning
        case .unsatisfied:
            return .critical
        case .unknown:
            return .neutral
        }
    }

    public var progress: Double {
        switch self {
        case .satisfied:
            return 1
        case .requiresConnection:
            return 0.45
        case .unsatisfied, .unknown:
            return 0
        }
    }
}
