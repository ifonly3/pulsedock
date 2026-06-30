import Foundation
import WidgetKit
import SwiftUI
#if canImport(SharedMetrics)
import SharedMetrics
#endif

enum SystemEntryKind {
    case preview
    case live
    case empty
}

struct SystemEntry: TimelineEntry {
    let date: Date
    let snapshot: MetricSnapshot?
    let snapshotAge: TimeInterval?
    let kind: SystemEntryKind

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
        SystemEntry(date: Date(), snapshot: Self.representativeSnapshot(), snapshotAge: 0, kind: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SystemEntry) -> Void) {
        completion(SystemEntry(date: Date(), snapshot: Self.representativeSnapshot(), snapshotAge: 0, kind: .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemEntry>) -> Void) {
        let timelineCompletion = TimelineCompletion(completion: completion)
        DispatchQueue.global(qos: .utility).async {
            let now = Date()
            let snapshot = Self.sampledSnapshotForTimeline(now: now)
            let entry: SystemEntry
            if let snapshot {
                entry = SystemEntry(date: now, snapshot: snapshot, snapshotAge: now.timeIntervalSince(snapshot.timestamp), kind: .live)
            } else {
                entry = SystemEntry(date: now, snapshot: nil, snapshotAge: nil, kind: .empty)
            }
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
                SmallWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone, entryKind: entry.kind)
            case .systemMedium:
                MediumWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone, entryKind: entry.kind)
            case .systemLarge:
                LargeWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone, entryKind: entry.kind)
            default:
                SmallWidget(snapshot: snapshot, freshnessTone: entry.freshnessTone, entryKind: entry.kind)
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
    let entryKind: SystemEntryKind

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport, freshnessTone: freshnessTone, entryKind: entryKind)

            Spacer(minLength: 4)

            HStack(spacing: 12) {
                RingMetric(title: PulseDockWidgetStrings.metricCPU, value: snapshot.cpuText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: WidgetColor.green(for: colorScheme))
                RingMetric(title: PulseDockWidgetStrings.metricMemoryCompact, value: snapshot.memoryUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue(for: colorScheme))
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
    let entryKind: SystemEntryKind

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                CompactWidgetHeader(title: PulseDockWidgetStrings.widgetDisplayName, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport, freshnessTone: freshnessTone, entryKind: entryKind)
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
                WidgetRow(title: PulseDockWidgetStrings.metricMemory, value: snapshot.memoryUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue(for: colorScheme))
                WidgetRow(title: PulseDockWidgetStrings.metricConnection, value: snapshot.networkPathText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress), tint: networkTint(snapshot, for: colorScheme))
                WidgetRow(title: PulseDockWidgetStrings.metricDisk, value: snapshot.diskUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: WidgetColor.amber(for: colorScheme))
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
        HStack(spacing: 8) {
            MiniStatus(title: PulseDockWidgetStrings.miniThermal, value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState, for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            MiniStatus(title: PulseDockWidgetStrings.miniPower, value: snapshot.powerStatusText, tint: powerTint(snapshot, for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LargeWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot
    let freshnessTone: WidgetFreshnessTone
    let entryKind: SystemEntryKind

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WidgetHeader(title: PulseDockWidgetStrings.headerSystemStatus, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport, freshnessTone: freshnessTone, entryKind: entryKind)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: largeRingColumns, spacing: 12) {
                        RingMetric(title: PulseDockWidgetStrings.metricCPU, value: snapshot.cpuText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: WidgetColor.green(for: colorScheme))
                        RingMetric(title: PulseDockWidgetStrings.metricMemory, value: snapshot.memoryUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue(for: colorScheme))
                        RingMetric(title: PulseDockWidgetStrings.metricDisk, value: snapshot.diskUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: WidgetColor.amber(for: colorScheme))
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
                        WidgetRow(title: PulseDockWidgetStrings.metricConnection, value: snapshot.networkPathText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress), tint: networkTint(snapshot, for: colorScheme))
                        WidgetRow(title: PulseDockWidgetStrings.metricPath, value: snapshot.networkPathCapabilityText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress), tint: WidgetColor.cyan(for: colorScheme))
                        WidgetRow(title: PulseDockWidgetStrings.metricInterface, value: snapshot.networkPathDetailText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress), tint: WidgetColor.cyan(for: colorScheme))
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
            WidgetStatusDot(color: WidgetColor.amber(for: colorScheme))
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
    let entryKind: SystemEntryKind

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
            if entryKind == .preview {
                previewLabel
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var previewLabel: some View {
        Text(PulseDockWidgetStrings.previewData)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(widgetSecondaryText(for: colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private var accessibilityLabel: String {
        var parts = [title]
        if hasTimeReport {
            parts.append(timeText)
        }
        if entryKind == .preview {
            parts.append(PulseDockWidgetStrings.previewData)
        }
        parts.append(freshnessTone.accessibilityText)
        return parts.joined(separator: ", ")
    }
}

private struct CompactWidgetHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let timeText: String
    let hasTimeReport: Bool
    let freshnessTone: WidgetFreshnessTone
    let entryKind: SystemEntryKind

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
            WidgetStatusDot(color: freshnessTone.color(for: colorScheme))
            Spacer(minLength: 4)
            if hasTimeReport {
                Text(timeText)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(widgetSecondaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if entryKind == .preview {
                previewLabel
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var previewLabel: some View {
        Text(PulseDockWidgetStrings.previewData)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(widgetSecondaryText(for: colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private var accessibilityLabel: String {
        var parts = [title]
        if hasTimeReport {
            parts.append(timeText)
        }
        if entryKind == .preview {
            parts.append(PulseDockWidgetStrings.previewData)
        }
        parts.append(freshnessTone.accessibilityText)
        return parts.joined(separator: ", ")
    }
}

private struct WidgetStatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .accessibilityHidden(true)
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
                            .frame(width: MetricScales.fillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 6))
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
            WidgetStatusDot(color: tint)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(widgetSecondaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .truncationMode(.tail)
                .layoutPriority(1)
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .truncationMode(.tail)
                .layoutPriority(1)
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
            WidgetStatusDot(color: tint)
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
    widgetToneColor(ThermalState(raw: state).metricStatusTone, for: colorScheme)
}

private func networkTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color {
    widgetToneColor(snapshot.canonicalNetworkPathState.metricStatusTone, for: colorScheme)
}

private func reportedTint(hasReport: Bool, fallback: Color, for colorScheme: ColorScheme) -> Color {
    guard hasReport else { return WidgetColor.cyan(for: colorScheme) }
    return fallback
}

private func powerTint(_ snapshot: MetricSnapshot, for colorScheme: ColorScheme) -> Color {
    widgetToneColor(snapshot.powerStatusTone, for: colorScheme)
}

private func widgetToneColor(_ tone: MetricStatusTone, for colorScheme: ColorScheme) -> Color {
    switch tone {
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
