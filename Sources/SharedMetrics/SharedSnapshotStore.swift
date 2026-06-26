import Foundation

public struct SharedSnapshotStore: @unchecked Sendable {
    private enum Keys {
        static let latestSnapshot = "shared.latestMetricSnapshot"
    }

    private let defaults: UserDefaults?
    private let acceptedFutureSkew: TimeInterval

    public init(defaults: UserDefaults?, acceptedFutureSkew: TimeInterval = 300) {
        self.defaults = defaults
        self.acceptedFutureSkew = acceptedFutureSkew
    }

    public init(
        suiteName: String = PulseDockAppGroup.suiteName,
        fileManager: FileManager = .default,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        acceptedFutureSkew: TimeInterval = 300
    ) {
        self.acceptedFutureSkew = acceptedFutureSkew

        guard PulseDockAppGroup.supportsAppGroup(bundleIdentifier: bundleIdentifier) else {
            self.defaults = nil
            return
        }

        guard fileManager.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil else {
            self.defaults = nil
            return
        }

        self.defaults = UserDefaults(suiteName: suiteName)
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
              let snapshot = try? JSONDecoder().decode(MetricSnapshot.self, from: data) else {
            return nil
        }

        let age = now.timeIntervalSince(snapshot.timestamp)
        guard age <= maxAge, age >= -acceptedFutureSkew else {
            return nil
        }
        return snapshot
    }
}
