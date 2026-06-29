import CoreGraphics
import Foundation

public enum MetricScales {
    public static let networkRateReferenceBytesPerSecond = 12_500_000_000.0

    public static func networkRateProgress(bytesPerSecond: UInt64) -> Double {
        guard bytesPerSecond > 0 else { return 0 }
        let value = min(Double(bytesPerSecond), networkRateReferenceBytesPerSecond)
        return min(log10(value + 1) / log10(networkRateReferenceBytesPerSecond + 1), 1)
    }

    public static func reportedProgress(hasReport: Bool, progress: Double) -> Double? {
        guard hasReport else { return nil }
        return progress
    }

    public static func fillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat {
        guard let normalizedProgress = clampedProgress(progress), normalizedProgress > 0 else {
            return 0
        }
        return max(minimumVisibleWidth, totalWidth * normalizedProgress)
    }

    public static func clampedProgress(_ progress: Double) -> Double? {
        guard progress.isFinite else { return nil }
        return min(max(progress, 0), 1)
    }
}
