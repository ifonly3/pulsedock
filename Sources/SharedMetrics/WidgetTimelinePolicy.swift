import Foundation

public enum WidgetTimelinePolicy {
    public static let requestedRefreshInterval: TimeInterval = 300
    public static let appReloadThrottle: TimeInterval = requestedRefreshInterval
    public static let sharedSnapshotMaxAge: TimeInterval = 540
    public static let agingThreshold: TimeInterval = 360
    public static let staleThreshold: TimeInterval = 600
}
