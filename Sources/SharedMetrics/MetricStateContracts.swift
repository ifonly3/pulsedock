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
}
