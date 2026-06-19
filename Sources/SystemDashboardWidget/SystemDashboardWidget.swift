import Foundation
import WidgetKit
import SwiftUI
#if canImport(SharedMetrics)
import SharedMetrics
#endif

struct SystemEntry: TimelineEntry {
    let date: Date
    let snapshot: MetricSnapshot?
}

private final class WidgetSamplerCache: @unchecked Sendable {
    private let systemSampler = SystemSampler()
    private let lock = NSLock()
    private var isPrimed = false

    func sample() -> MetricSnapshot {
        lock.lock()
        defer { lock.unlock() }

        if !isPrimed {
            _ = systemSampler.sample()
            isPrimed = true
        }

        return systemSampler.sample()
    }
}

struct SystemProvider: TimelineProvider {
    private static let samplerCache = WidgetSamplerCache()

    func placeholder(in context: Context) -> SystemEntry {
        SystemEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SystemEntry) -> Void) {
        completion(SystemEntry(date: Date(), snapshot: sampledSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemEntry>) -> Void) {
        let now = Date()
        let entry = SystemEntry(date: now, snapshot: sampledSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func sampledSnapshot() -> MetricSnapshot {
        compactWidgetSnapshot(from: Self.samplerCache.sample())
    }
}

private func compactWidgetSnapshot(from snapshot: MetricSnapshot) -> MetricSnapshot {
    MetricSnapshot(
        cpuUsage: snapshot.cpuUsage,
        cpuCoreUsages: snapshot.cpuCoreUsages,
        hasCPUUsageReport: snapshot.hasCPUUsageReport,
        physicalCoreCount: snapshot.physicalCoreCount,
        logicalCoreCount: snapshot.logicalCoreCount,
        activeProcessorCount: snapshot.activeProcessorCount,
        cpuBrandName: nil,
        memoryUsedBytes: snapshot.memoryUsedBytes,
        memoryTotalBytes: snapshot.memoryTotalBytes,
        memorySwapUsedBytes: snapshot.memorySwapUsedBytes,
        memorySwapTotalBytes: snapshot.memorySwapTotalBytes,
        memorySwapAvailableBytes: snapshot.memorySwapAvailableBytes,
        loadAverage: snapshot.loadAverage,
        loadAverage5: snapshot.loadAverage5,
        loadAverage15: snapshot.loadAverage15,
        hasLoadAverageReport: snapshot.hasLoadAverageReport,
        thermalState: snapshot.thermalState,
        batteryPercent: snapshot.batteryPercent,
        batteryIsCharging: snapshot.batteryIsCharging,
        batteryPowerSource: snapshot.batteryPowerSource,
        batteryTimeRemainingMinutes: snapshot.batteryTimeRemainingMinutes,
        batteryCurrentCapacity: snapshot.batteryCurrentCapacity,
        batteryMaxCapacity: snapshot.batteryMaxCapacity,
        hasNetworkByteCounters: false,
        hasNetworkDirectionByteCounters: false,
        networkPathStatus: snapshot.networkPathStatus,
        networkPathIsExpensive: snapshot.networkPathIsExpensive,
        networkPathIsConstrained: snapshot.networkPathIsConstrained,
        hasNetworkPathCostReport: snapshot.hasNetworkPathCostReport,
        networkPathSupportsDNS: snapshot.networkPathSupportsDNS,
        networkPathSupportsIPv4: snapshot.networkPathSupportsIPv4,
        networkPathSupportsIPv6: snapshot.networkPathSupportsIPv6,
        hasNetworkPathSupportReport: snapshot.hasNetworkPathSupportReport,
        networkPathInterfaceKinds: snapshot.networkPathInterfaceKinds,
        networkInBytesPerSecond: 0,
        networkOutBytesPerSecond: 0,
        networkInterfaces: compactWidgetInterfaces(from: snapshot.networkInterfaces),
        diskFreeBytes: snapshot.diskFreeBytes,
        diskTotalBytes: snapshot.diskTotalBytes,
        storageVolumes: [],
        processCount: 0,
        activeApplicationCount: 0,
        hiddenApplicationCount: 0,
        hasRunningAppCountReport: false,
        topProcesses: [],
        gpuDevices: [],
        displays: [],
        uptimeSeconds: snapshot.uptimeSeconds,
        hasUptimeReport: snapshot.hasUptimeReport,
        osVersion: snapshot.osVersion,
        kernelRelease: snapshot.kernelRelease,
        timestamp: snapshot.timestamp
    )
}

private func compactWidgetInterfaces(from interfaces: [NetworkInterfaceMetric]) -> [NetworkInterfaceMetric] {
    interfaces
        .filter(\.hasInterfaceStateReport)
        .enumerated()
        .map { index, interface in
            NetworkInterfaceMetric(
                index: index,
                displayName: "未报告",
                kind: "未报告",
                isUp: interface.isUp,
                isLoopback: interface.isLoopback,
                hasInterfaceStateReport: true,
                bytesReceived: 0,
                bytesSent: 0,
                hasByteCounters: false
            )
        }
}

struct SystemDashboardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SystemEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall:
                SmallWidget(snapshot: snapshot)
            case .systemMedium:
                MediumWidget(snapshot: snapshot)
            default:
                LargeWidget(snapshot: snapshot)
            }
        } else {
            EmptyDataWidget(family: family)
        }
    }
}

struct SystemDashboardWidget: Widget {
    let kind = WidgetTimelineKind.pulseDock

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemProvider()) { entry in
            SystemDashboardWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Pulse Dock")
        .description("在桌面显示 Mac 的 CPU、内存、连接、电池和热状态。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct SystemDashboardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SystemDashboardWidget()
    }
}

private let largeRingColumns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
]

private struct SmallWidget: View {
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: "Pulse Dock", timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport)

            Spacer(minLength: 4)

            HStack(spacing: 12) {
                RingMetric(title: "CPU", value: snapshot.cpuText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: WidgetColor.green)
                RingMetric(title: "MEM", value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue)
            }

            HStack(spacing: 8) {
                MiniStatus(title: "热", value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState))
                Spacer()
                MiniStatus(title: "网", value: snapshot.networkPathText, tint: networkTint(snapshot))
                Spacer()
                MiniStatus(title: "电", value: compactPowerStatusText(snapshot), tint: powerTint(snapshot))
            }
        }
        .padding(14)
    }
}

private struct MediumWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                CompactWidgetHeader(title: "Pulse Dock", timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport)
                Text(snapshot.cpuText)
                    .font(.system(size: 52, weight: .semibold).monospacedDigit())
                    .foregroundStyle(widgetPrimaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.60)
                Text(snapshot.logicalCoreSummaryText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(widgetSecondaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 4)
                MediumStatusStrip(snapshot: snapshot)
            }
            .frame(width: 166, alignment: .leading)

            VStack(spacing: 18) {
                WidgetRow(title: "内存", value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue)
                WidgetRow(title: "连接", value: snapshot.networkPathText, progress: reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: networkPathProgress(snapshot)), tint: networkTint(snapshot))
                WidgetRow(title: "磁盘", value: snapshot.diskUsageText, progress: reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: WidgetColor.amber)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

private struct MediumStatusStrip: View {
    let snapshot: MetricSnapshot

    var body: some View {
        HStack(spacing: 10) {
            MiniStatus(title: "热", value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState))
            MiniStatus(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: powerTint(snapshot))
        }
    }
}

private struct LargeWidget: View {
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WidgetHeader(title: "系统状态", timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: largeRingColumns, spacing: 12) {
                        RingMetric(title: "CPU", value: snapshot.cpuText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: WidgetColor.green)
                        RingMetric(title: "内存", value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue)
                        RingMetric(title: "磁盘", value: snapshot.diskUsageText, progress: reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: WidgetColor.amber)
                        RingMetric(title: "负载", value: snapshot.loadText, progress: snapshot.loadAverageProgress, tint: WidgetColor.green)
                    }

                    HStack(spacing: 10) {
                        StatTile(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: powerTint(snapshot))
                        StatTile(title: "热状态", value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState))
                    }
                }
                .frame(width: 148, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    LargeWidgetSection {
                        WidgetRow(title: "连接", value: snapshot.networkPathText, progress: reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: networkPathProgress(snapshot)), tint: networkTint(snapshot))
                        WidgetRow(title: "路径", value: snapshot.networkPathCapabilityText, progress: reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: networkPathProgress(snapshot)), tint: WidgetColor.cyan)
                        WidgetRow(title: "接口", value: snapshot.networkInterfaceSummary, progress: reportedProgress(hasReport: snapshot.hasNetworkInterfaceReport, progress: activeInterfaceProgress(snapshot)), tint: WidgetColor.cyan)
                    }

                    LargeInfoGrid(snapshot: snapshot)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(18)
    }
}

private struct LargeInfoGrid: View {
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatTile(title: "运行", value: snapshot.uptimeText, tint: reportedTint(hasReport: snapshot.hasUptimeReport, fallback: WidgetColor.amber))
                StatTile(title: "系统", value: snapshot.osVersionText, tint: reportedTint(hasReport: snapshot.hasOSVersionReport, fallback: WidgetColor.blue))
            }

            StatTile(title: "内核", value: snapshot.kernelText, tint: reportedTint(hasReport: snapshot.hasKernelReleaseReport, fallback: WidgetColor.cyan))
        }
    }
}

private struct LargeWidgetSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(10)
        .background(widgetPanelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(widgetPanelStroke(for: colorScheme), lineWidth: 0.6)
        }
    }
}

private struct EmptyDataWidget: View {
    let family: WidgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 12 : 14) {
            HStack(spacing: 7) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetColor.green)
                Text("Pulse Dock")
                    .font(.system(size: 14, weight: .semibold))
                Circle()
                    .fill(WidgetColor.amber)
                    .frame(width: 6, height: 6)
                Spacer()
            }

            if family == .systemSmall {
                HStack(spacing: 12) {
                    PlaceholderMetricSkeleton(tint: WidgetColor.green)
                    PlaceholderMetricSkeleton(tint: WidgetColor.blue)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    PlaceholderDot(tint: WidgetColor.green)
                    PlaceholderDot(tint: WidgetColor.cyan)
                    PlaceholderDot(tint: WidgetColor.amber)
                }
            } else {
                HStack(spacing: 14) {
                    PlaceholderMetricSkeleton(tint: WidgetColor.green)
                    PlaceholderMetricSkeleton(tint: WidgetColor.blue)
                    if family == .systemLarge {
                        PlaceholderMetricSkeleton(tint: WidgetColor.amber)
                    }
                }
                VStack(spacing: 10) {
                    PlaceholderBar(tint: WidgetColor.blue, widthRatio: 0.74)
                    PlaceholderBar(tint: WidgetColor.green, widthRatio: 0.46)
                    PlaceholderBar(tint: WidgetColor.cyan, widthRatio: 0.58)
                }
            }
        }
        .padding(16)
    }
}

private struct PlaceholderMetricSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(widgetTrackFill(for: colorScheme), lineWidth: 6)
            Circle()
                .trim(from: 0, to: 0.62)
                .stroke(tint.opacity(0.42), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(widgetPlaceholderFill(for: colorScheme))
                .frame(width: 28, height: 8)
        }
        .frame(width: 54, height: 54)
        .frame(maxWidth: .infinity)
    }
}

private struct PlaceholderBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color
    let widthRatio: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(widgetTrackFill(for: colorScheme))
                Capsule()
                    .fill(tint.opacity(0.42))
                    .frame(width: max(18, proxy.size.width * min(max(widthRatio, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}

private struct PlaceholderDot: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint.opacity(0.56)).frame(width: 6, height: 6)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(widgetPlaceholderFill(for: colorScheme))
                .frame(width: 24, height: 7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WidgetHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let timeText: String
    let hasTimeReport: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetColor.green)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
                .lineLimit(1)
            Circle()
                .fill(WidgetColor.green)
                .frame(width: 6, height: 6)
            Spacer()
            if hasTimeReport {
                Text(timeText)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(widgetSecondaryText(for: colorScheme))
            }
        }
    }
}

private struct CompactWidgetHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let timeText: String
    let hasTimeReport: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetColor.green)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
            Circle()
                .fill(WidgetColor.green)
                .frame(width: 6, height: 6)
        }
        .accessibilityLabel(hasTimeReport ? "\(title), \(timeText)" : title)
    }
}

private struct RingMetric: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let progress: Double?
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(widgetTrackFill(for: colorScheme), lineWidth: 6)
                if let progress {
                    Circle()
                        .trim(from: 0, to: min(max(progress, 0), 1))
                        .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text(value)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(widgetPrimaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 54, height: 54)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(widgetSecondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WidgetRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let progress: Double?
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(widgetSecondaryText(for: colorScheme))
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(widgetTrackFill(for: colorScheme))
                    if let progress {
                        Capsule()
                            .fill(tint.gradient)
                            .frame(width: progressFillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 6))
                    }
                }
            }
            .frame(height: 5)
        }
    }
}

private struct MiniStatus: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(widgetSecondaryText(for: colorScheme))
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        }
    }
}

private struct StatTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(widgetSecondaryText(for: colorScheme))
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(widgetPanelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(widgetPanelStroke(for: colorScheme), lineWidth: 0.6)
        }
    }
}

private struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: widgetBackgroundColors(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.24))
        }
    }
}

private func widgetBackgroundColors(for colorScheme: ColorScheme) -> [Color] {
    if colorScheme == .dark {
        return [
            Color(red: 0.10, green: 0.12, blue: 0.12).opacity(0.96),
            Color(red: 0.08, green: 0.18, blue: 0.17).opacity(0.90),
            Color(red: 0.17, green: 0.13, blue: 0.08).opacity(0.82)
        ]
    }

    return [
        Color.white.opacity(0.92),
        Color(red: 0.89, green: 0.95, blue: 0.94).opacity(0.88),
        Color(red: 0.98, green: 0.93, blue: 0.84).opacity(0.72)
    ]
}

private func widgetPanelFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.40)
}

private func widgetPanelStroke(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.58)
}

private func widgetPrimaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary
}

private func widgetSecondaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.62) : Color.secondary
}

private func widgetTrackFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.14) : Color.secondary.opacity(0.14)
}

private func widgetPlaceholderFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.16) : Color.secondary.opacity(0.16)
}

private enum WidgetColor {
    static let blue = Color(red: 0.14, green: 0.43, blue: 0.95)
    static let green = Color(red: 0.04, green: 0.62, blue: 0.39)
    static let amber = Color(red: 0.93, green: 0.54, blue: 0.10)
    static let cyan = Color(red: 0.04, green: 0.56, blue: 0.70)
    static let red = Color(red: 0.84, green: 0.16, blue: 0.16)
}

private func thermalTint(_ state: String) -> Color {
    switch state.lowercased() {
    case "critical", "hot", "serious": WidgetColor.red
    case "warm", "fair": WidgetColor.amber
    case "nominal": WidgetColor.green
    case "unknown": WidgetColor.cyan
    default: WidgetColor.cyan
    }
}

private func networkTint(_ snapshot: MetricSnapshot) -> Color {
    switch snapshot.networkPathStatus.lowercased() {
    case "satisfied":
        WidgetColor.green
    case "requiresconnection", "requires_connection", "requires connection":
        WidgetColor.amber
    case "unsatisfied":
        WidgetColor.red
    default:
        WidgetColor.cyan
    }
}

private func networkPathProgress(_ snapshot: MetricSnapshot) -> Double {
    switch snapshot.networkPathStatus.lowercased() {
    case "satisfied":
        1
    case "requiresconnection", "requires_connection", "requires connection":
        0.45
    case "unsatisfied":
        0
    default:
        0
    }
}

private func reportedProgress(hasReport: Bool, progress: Double) -> Double? {
    guard hasReport else { return nil }
    return progress
}

private func progressFillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat {
    let normalizedProgress = min(max(progress, 0), 1)
    guard normalizedProgress > 0 else { return 0 }
    return max(minimumVisibleWidth, totalWidth * normalizedProgress)
}

private func reportedTint(hasReport: Bool, fallback: Color) -> Color {
    guard hasReport else { return WidgetColor.cyan }
    return fallback
}

private func powerTint(_ snapshot: MetricSnapshot) -> Color {
    switch snapshot.powerStatusTone {
    case .normal:
        return WidgetColor.green
    case .warning:
        return WidgetColor.amber
    case .critical:
        return WidgetColor.red
    case .neutral:
        return WidgetColor.cyan
    }
}

private func activeInterfaceProgress(_ snapshot: MetricSnapshot) -> Double {
    let reportedInterfaces = snapshot.networkInterfaces.filter(\.hasInterfaceStateReport)
    guard !reportedInterfaces.isEmpty else { return 0 }
    let activeCount = reportedInterfaces.filter { $0.isUp && !$0.isLoopback }.count
    return min(Double(activeCount) / Double(reportedInterfaces.count), 1)
}

private func compactPowerStatusText(_ snapshot: MetricSnapshot) -> String {
    if let batteryPercent = snapshot.batteryPercent {
        return MetricFormatting.percentage(batteryPercent)
    }

    switch snapshot.batteryPowerSource?.lowercased() {
    case "ac power":
        return snapshot.batteryIsCharging ? "充电" : "电源"
    case "battery power":
        return "电池"
    case "ups power":
        return "UPS"
    case .some:
        return "外接"
    default:
        return "未报告"
    }
}
