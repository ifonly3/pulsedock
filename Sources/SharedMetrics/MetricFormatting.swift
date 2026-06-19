import Foundation

public enum MetricFormatting {
    public static func percentage(_ value: Double) -> String {
        guard value.isFinite else { return "未报告" }
        let clamped = min(max(value, 0), 1)
        return "\(Int((clamped * 100).rounded()))%"
    }

    public static func bytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(value)) \(units[unitIndex])"
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }

    public static func compactBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(value)) \(units[unitIndex])"
        }

        return String(format: "%.0f %@", value, units[unitIndex])
    }

    public static func networkRate(bytesPerSecond: UInt64) -> String {
        let bitsPerSecond = Double(bytesPerSecond) * 8
        return bitRate(bitsPerSecond: bitsPerSecond)
    }

    public static func bitRate(bitsPerSecond: Double) -> String {
        guard bitsPerSecond.isFinite else { return "未报告" }
        let bitsPerSecond = max(bitsPerSecond, 0)
        if bitsPerSecond >= 1_000_000_000 {
            return String(format: "%.1f Gbps", bitsPerSecond / 1_000_000_000)
        }

        if bitsPerSecond >= 1_000_000 {
            return "\(Int((bitsPerSecond / 1_000_000).rounded())) Mbps"
        }

        return "\(Int((bitsPerSecond / 1_000).rounded())) Kbps"
    }

    public static func byteRate(bytesPerSecond: UInt64) -> String {
        "\(compactBytes(bytesPerSecond))/s"
    }

    public static func load(_ value: Double) -> String {
        guard value.isFinite else { return "未报告" }
        return String(format: "%.1f", value)
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "未报告" }
        let totalMinutes = max(Int(seconds / 60), 0)
        return minutes(totalMinutes)
    }

    public static func minutes(_ value: Int) -> String {
        let totalMinutes = max(value, 0)
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minuteRemainder = totalMinutes % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        if hours > 0 {
            return "\(hours)h \(minuteRemainder)m"
        }

        return "\(minuteRemainder)m"
    }
}
