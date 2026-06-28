import Foundation
import WidgetKit
import SwiftUI
#if canImport(SharedMetrics)
import SharedMetrics
#endif

struct SystemEntry: TimelineEntry {
    let date: Date
    let snapshot: MetricSnapshot?
    let snapshotAge: TimeInterval?

    var freshnessTone: WidgetFreshnessTone {
        WidgetFreshnessTone.resolve(age: snapshotAge)
    }
}

private final class WidgetSamplerCache: @unchecked Sendable {
    private let systemSampler = SystemSampler()
    private let lock = NSLock()

    func sampleCompact() -> MetricSnapshot {
        lock.lock()
        defer { lock.unlock() }

        return systemSampler.sampleWidgetCompact()
    }
}

private struct TimelineCompletion: @unchecked Sendable {
    let completion: (Timeline<SystemEntry>) -> Void

    func callAsFunction(_ timeline: Timeline<SystemEntry>) {
        completion(timeline)
    }
}

struct SystemProvider: TimelineProvider {
    private static let samplerCache = WidgetSamplerCache()
    private static let sharedSnapshotStore = SharedSnapshotStore()
    private static let sharedSnapshotMaxAge: TimeInterval = WidgetTimelinePolicy.sharedSnapshotMaxAge

    func placeholder(in context: Context) -> SystemEntry {
        SystemEntry(date: Date(), snapshot: Self.representativeSnapshot(), snapshotAge: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SystemEntry) -> Void) {
        completion(SystemEntry(date: Date(), snapshot: Self.representativeSnapshot(), snapshotAge: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemEntry>) -> Void) {
        let timelineCompletion = TimelineCompletion(completion: completion)
        DispatchQueue.global(qos: .utility).async {
            let now = Date()
            let snapshot = Self.sampledSnapshotForTimeline(now: now)
            let age = snapshot.map { now.timeIntervalSince($0.timestamp) }
            let entry = SystemEntry(date: now, snapshot: snapshot, snapshotAge: age)
            let nextRefresh = now.addingTimeInterval(WidgetTimelinePolicy.requestedRefreshInterval)
            timelineCompletion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private static func sampledSnapshotForTimeline(now: Date) -> MetricSnapshot? {
        Self.sharedSnapshotStore.loadLatestSnapshot(maxAge: Self.sharedSnapshotMaxAge, now: now)
            ?? Self.samplerCache.sampleCompact()
    }

    private static func representativeSnapshot() -> MetricSnapshot {
        MetricSnapshot(
            cpuUsage: 0.37,
            cpuCoreUsages: [0.31, 0.42, 0.28, 0.47],
            hasCPUUsageReport: true,
            physicalCoreCount: 8,
            logicalCoreCount: 8,
            activeProcessorCount: 8,
            cpuBrandName: "Apple Silicon",
            memoryUsedBytes: 8_600_000_000,
            memoryTotalBytes: 17_179_869_184,
            memoryFreeBytes: 3_200_000_000,
            memoryWiredBytes: 2_100_000_000,
            memoryCompressedBytes: 820_000_000,
            memoryCachedBytes: 4_100_000_000,
            hasMemoryCompositionReport: true,
            loadAverage: 1.42,
            loadAverage5: 1.20,
            loadAverage15: 1.05,
            hasLoadAverageReport: true,
            thermalState: "Nominal",
            batteryPercent: 0.86,
            batteryIsCharging: false,
            batteryPowerSource: "Battery Power",
            networkBytesPerSecond: 1_200_000,
            hasNetworkByteCounters: true,
            hasNetworkDirectionByteCounters: true,
            networkPathStatus: "satisfied",
            networkPathSupportsDNS: true,
            networkPathSupportsIPv4: true,
            networkPathSupportsIPv6: true,
            hasNetworkPathSupportReport: true,
            networkPathInterfaceKinds: ["Wi-Fi"],
            networkInBytesPerSecond: 900_000,
            networkOutBytesPerSecond: 300_000,
            diskFreeBytes: 180_000_000_000,
            diskTotalBytes: 494_000_000_000,
            uptimeSeconds: 86_400,
            hasUptimeReport: true,
            osVersion: "macOS",
            kernelRelease: "Darwin",
            timestamp: Date()
        ).widgetCompactSnapshot()
    }
}

struct SystemDashboardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SystemEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall:
                SmallWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone)
            case .systemMedium:
                MediumWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone)
            case .systemLarge:
                LargeWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone)
            default:
                SmallWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone)
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
        .configurationDisplayName(PulseDockWidgetStrings.widgetDisplayName)
        .description(PulseDockWidgetStrings.widgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#if !SWIFT_PACKAGE
@main
struct SystemDashboardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SystemDashboardWidget()
    }
}
#endif

private let largeRingColumns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
]

private struct SmallWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot
    let freshnessTone: WidgetFreshnessTone

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport, freshnessTone: freshnessTone)

            Spacer(minLength: 4)

            HStack(spacing: 12) {
                RingMetric(title: PulseDockWidgetStrings.metricCPU, value: snapshot.cpuText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: WidgetColor.green(for: colorScheme))
                RingMetric(title: PulseDockWidgetStrings.metricMemoryCompact, value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue(for: colorScheme))
            }

            HStack(spacing: 8) {
                MiniStatus(title: PulseDockWidgetStrings.miniThermal, value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState, for: colorScheme))
                Spacer()
                MiniStatus(title: PulseDockWidgetStrings.miniNetwork, value: snapshot.networkPathText, tint: networkTint(snapshot, for: colorScheme))
                Spacer()
                MiniStatus(title: PulseDockWidgetStrings.miniPower, value: compactPowerStatusText(snapshot), tint: powerTint(snapshot, for: colorScheme))
            }
        }
        .padding(14)
    }
}

private struct MediumWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot
    let freshnessTone: WidgetFreshnessTone

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                CompactWidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport, freshnessTone: freshnessTone)
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
                WidgetRow(title: PulseDockWidgetStrings.metricMemory, value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue(for: colorScheme))
                WidgetRow(title: PulseDockWidgetStrings.metricConnection, value: snapshot.networkPathText, progress: reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: networkPathProgress(snapshot)), tint: networkTint(snapshot, for: colorScheme))
                WidgetRow(title: PulseDockWidgetStrings.metricDisk, value: snapshot.diskUsageText, progress: reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: WidgetColor.amber(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

private struct MediumStatusStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot

    var body: some View {
        HStack(spacing: 10) {
            MiniStatus(title: PulseDockWidgetStrings.miniThermal, value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState, for: colorScheme))
            MiniStatus(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: powerTint(snapshot, for: colorScheme))
        }
    }
}

private struct LargeWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot
    let freshnessTone: WidgetFreshnessTone

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WidgetHeader(title: PulseDockWidgetStrings.headerSystemStatus, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport, freshnessTone: freshnessTone)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: largeRingColumns, spacing: 12) {
                        RingMetric(title: PulseDockWidgetStrings.metricCPU, value: snapshot.cpuText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: WidgetColor.green(for: colorScheme))
                        RingMetric(title: PulseDockWidgetStrings.metricMemory, value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue(for: colorScheme))
                        RingMetric(title: PulseDockWidgetStrings.metricDisk, value: snapshot.diskUsageText, progress: reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: WidgetColor.amber(for: colorScheme))
                        RingMetric(title: PulseDockWidgetStrings.metricLoad, value: snapshot.loadText, progress: snapshot.loadAverageProgress, tint: WidgetColor.green(for: colorScheme))
                    }

                    HStack(spacing: 10) {
                        StatTile(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: powerTint(snapshot, for: colorScheme))
                        StatTile(title: PulseDockWidgetStrings.metricThermalState, value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState, for: colorScheme))
                    }
                }
                .frame(width: 148, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    LargeWidgetSection {
                        WidgetRow(title: PulseDockWidgetStrings.metricConnection, value: snapshot.networkPathText, progress: reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: networkPathProgress(snapshot)), tint: networkTint(snapshot, for: colorScheme))
                        WidgetRow(title: PulseDockWidgetStrings.metricPath, value: snapshot.networkPathCapabilityText, progress: reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: networkPathProgress(snapshot)), tint: WidgetColor.cyan(for: colorScheme))
                        WidgetRow(title: PulseDockWidgetStrings.metricInterface, value: snapshot.networkPathDetailText, progress: reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: networkPathProgress(snapshot)), tint: WidgetColor.cyan(for: colorScheme))
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
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatTile(title: PulseDockWidgetStrings.metricUptime, value: snapshot.uptimeText, tint: reportedTint(hasReport: snapshot.hasUptimeReport, fallback: WidgetColor.amber(for: colorScheme), for: colorScheme))
                StatTile(title: PulseDockWidgetStrings.metricSystem, value: snapshot.osVersionText, tint: reportedTint(hasReport: snapshot.hasOSVersionReport, fallback: WidgetColor.blue(for: colorScheme), for: colorScheme))
            }

            StatTile(title: PulseDockWidgetStrings.metricKernel, value: snapshot.kernelText, tint: reportedTint(hasReport: snapshot.hasKernelReleaseReport, fallback: WidgetColor.cyan(for: colorScheme), for: colorScheme))
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
    @Environment(\.colorScheme) private var colorScheme
    let family: WidgetFamily

    private var shouldInlineLoadingLabel: Bool { family == .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 12 : 14) {
            if shouldInlineLoadingLabel {
                compactLoadingHeader
            } else {
                normalHeader
            }
            if !shouldInlineLoadingLabel {
                loadingLabel
            }

            if family == .systemSmall {
                HStack(spacing: 12) {
                    PlaceholderMetricSkeleton(tint: WidgetColor.green(for: colorScheme))
                    PlaceholderMetricSkeleton(tint: WidgetColor.blue(for: colorScheme))
                }
                Spacer(minLength: 0)
            } else {
                HStack(spacing: 14) {
                    PlaceholderMetricSkeleton(tint: WidgetColor.green(for: colorScheme))
                    PlaceholderMetricSkeleton(tint: WidgetColor.blue(for: colorScheme))
                    if family == .systemLarge {
                        PlaceholderMetricSkeleton(tint: WidgetColor.amber(for: colorScheme))
                    }
                }
                VStack(spacing: 10) {
                    PlaceholderBar(tint: WidgetColor.blue(for: colorScheme), widthRatio: 0.74)
                    PlaceholderBar(tint: WidgetColor.green(for: colorScheme), widthRatio: 0.46)
                    PlaceholderBar(tint: WidgetColor.cyan(for: colorScheme), widthRatio: 0.58)
                }
            }
            if family != .systemSmall {
                HStack(spacing: 8) {
                    PlaceholderDot(tint: WidgetColor.green(for: colorScheme))
                    PlaceholderDot(tint: WidgetColor.cyan(for: colorScheme))
                    PlaceholderDot(tint: WidgetColor.amber(for: colorScheme))
                }
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PulseDockWidgetStrings.waitingSystemData)
    }

    private var loadingLabel: some View {
        Text(PulseDockWidgetStrings.waitingData)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(widgetSecondaryText(for: colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private var compactLoadingHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetColor.green(for: colorScheme))
            loadingLabel
            Spacer(minLength: 0)
        }
    }

    private var normalHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetColor.green(for: colorScheme))
            Text(PulseDockWidgetStrings.widgetDisplayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
            Circle()
                .fill(WidgetColor.amber(for: colorScheme))
                .frame(width: 6, height: 6)
            Spacer()
        }
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
    let freshnessTone: WidgetFreshnessTone

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetColor.green(for: colorScheme))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
                .lineLimit(1)
            Circle()
                .fill(freshnessTone.color(for: colorScheme))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Spacer()
            if hasTimeReport {
                Text(timeText)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(widgetSecondaryText(for: colorScheme))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasTimeReport ? "\(title), \(timeText), \(freshnessTone.accessibilityText)" : "\(title), \(freshnessTone.accessibilityText)")
    }
}

private struct CompactWidgetHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let timeText: String
    let hasTimeReport: Bool
    let freshnessTone: WidgetFreshnessTone

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetColor.green(for: colorScheme))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
            Circle()
                .fill(freshnessTone.color(for: colorScheme))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Spacer(minLength: 4)
            if hasTimeReport {
                Text(timeText)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(widgetSecondaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasTimeReport ? "\(title), \(timeText), \(freshnessTone.accessibilityText)" : "\(title), \(freshnessTone.accessibilityText)")
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
                if let progress, let clampedProgress = MetricScales.clampedProgress(progress) {
                    Circle()
                        .trim(from: 0, to: clampedProgress)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockWidgetStrings.notReported)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockWidgetStrings.notReported)
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
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(widgetSecondaryText(for: colorScheme))
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
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
                .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
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

private func thermalTint(_ state: String, for colorScheme: ColorScheme) -> Color {
    switch state.lowercased() {
    case "critical", "hot", "serious": WidgetColor.red(for: colorScheme)
    case "warm", "fair": WidgetColor.amber(for: colorScheme)
    case "nominal": WidgetColor.green(for: colorScheme)
    case "unknown": WidgetColor.cyan(for: colorScheme)
    default: WidgetColor.cyan(for: colorScheme)
    }
}

private func networkTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color {
    switch snapshot.networkPathStatus.lowercased() {
    case "satisfied":
        WidgetColor.green(for: colorScheme)
    case "requiresconnection", "requires_connection", "requires connection":
        WidgetColor.amber(for: colorScheme)
    case "unsatisfied":
        WidgetColor.red(for: colorScheme)
    default:
        WidgetColor.cyan(for: colorScheme)
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
    guard let normalizedProgress = MetricScales.clampedProgress(progress), normalizedProgress > 0 else {
        return 0
    }
    return max(minimumVisibleWidth, totalWidth * normalizedProgress)
}

private func reportedTint(hasReport: Bool, fallback: Color, for colorScheme: ColorScheme) -> Color {
    guard hasReport else { return WidgetColor.cyan(for: colorScheme) }
    return fallback
}

private func powerTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color {
    switch snapshot.powerStatusTone {
    case .normal:
        return WidgetColor.green(for: colorScheme)
    case .warning:
        return WidgetColor.amber(for: colorScheme)
    case .critical:
        return WidgetColor.red(for: colorScheme)
    case .neutral:
        return WidgetColor.cyan(for: colorScheme)
    }
}

private func compactPowerStatusText(_ snapshot: MetricSnapshot) -> String {
    if let batteryPercent = snapshot.batteryPercent {
        return MetricFormatting.percentage(batteryPercent)
    }

    switch snapshot.batteryPowerSource?.lowercased() {
    case "ac power":
        return snapshot.batteryIsCharging ? PulseDockWidgetStrings.compactPowerCharging : PulseDockWidgetStrings.compactPowerAdapter
    case "battery power":
        return PulseDockWidgetStrings.compactPowerBattery
    case "ups power":
        return PulseDockWidgetStrings.powerUPS
    case .some:
        return PulseDockWidgetStrings.compactPowerExternal
    default:
        return PulseDockWidgetStrings.notReported
    }
}
