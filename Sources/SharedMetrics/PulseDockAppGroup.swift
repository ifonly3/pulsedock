import Foundation

public enum PulseDockAppGroup {
    public static let suiteName = "group.com.ifonly3.pulsedock"
    public static let appBundleIdentifier = "com.ifonly3.pulsedock"
    public static let widgetBundleIdentifier = "com.ifonly3.pulsedock.widget"

    public static func supportsAppGroup(bundleIdentifier: String?) -> Bool {
        bundleIdentifier == appBundleIdentifier || bundleIdentifier == widgetBundleIdentifier
    }
}
