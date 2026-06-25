import Foundation

public struct SharedSnapshotStore: @unchecked Sendable {
    private enum Keys {
        static let latestSnapshot = "shared.latestMetricSnapshot"
    }

    private let defaults: UserDefaults?

    public init(defaults: UserDefaults? = UserDefaults(suiteName: PulseDockAppGroup.suiteName)) {
        self.defaults = defaults
    }

    public func saveLatestSnapshot(_ snapshot: MetricSnapshot) {
        guard let defaults else { return }
        let compact = snapshot.widgetCompactSnapshot()
        guard let data = try? JSONEncoder().encode(compact) else { return }
        defaults.set(data, forKey: Keys.latestSnapshot)
    }

    public func loadLatestSnapshot(maxAge: TimeInterval, now: Date = Date()) -> MetricSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: Keys.latestSnapshot),
              let snapshot = try? JSONDecoder().decode(MetricSnapshot.self, from: data),
              now.timeIntervalSince(snapshot.timestamp) >= 0,
              now.timeIntervalSince(snapshot.timestamp) <= maxAge else {
            return nil
        }
        return snapshot
    }
}
