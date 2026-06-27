import Foundation

public enum MetricScales {
    private static let tenGigabitBytesPerSecond = 1_250_000_000.0

    public static func networkRateProgress(bytesPerSecond: UInt64) -> Double {
        guard bytesPerSecond > 0 else { return 0 }
        let value = min(Double(bytesPerSecond), tenGigabitBytesPerSecond)
        return min(log10(value + 1) / log10(tenGigabitBytesPerSecond + 1), 1)
    }
}
