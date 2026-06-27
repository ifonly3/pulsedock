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
    private var primedSnapshot: MetricSnapshot?

    func sample() -> MetricSnapshot {
        lock.lock()
        defer { lock.unlock() }

        if !isPrimed {
            let snapshot = systemSampler.sample()
            primedSnapshot = snapshot
            isPrimed = true
            return snapshot
        }

        let snapshot = systemSampler.sample()
        primedSnapshot = snapshot
        return snapshot
    }
}

struct SystemProvider: TimelineProvider {
    private static let samplerCache = WidgetSamplerCache()
    private static let sharedSnapshotStore = SharedSnapshotStore()
    private let sharedSnapshotMaxAge: TimeInterval = 600

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
        Self.sharedSnapshotStore.loadLatestSnapshot(maxAge: sharedSnapshotMaxAge)
            ?? Self.samplerCache.sample().widgetCompactSnapshot()
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
        .description(PulseDockWidgetStrings.widgetDescription)
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
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: "Pulse Dock", timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport)

            Spacer(minLength: 4)

            HStack(spacing: 12) {
                RingMetric(title: "CPU", value: snapshot.cpuText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: WidgetColor.green(for: colorScheme))
                RingMetric(title: "MEM", value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: WidgetColor.blue(for: colorScheme))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WidgetHeader(title: PulseDockWidgetStrings.headerSystemStatus, timeText: snapshot.sampleClockText, hasTimeReport: snapshot.hasSampleTimeReport)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: largeRingColumns, spacing: 12) {
                        RingMetric(title: "CPU", value: snapshot.cpuText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: WidgetColor.green(for: colorScheme))
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
            Text("Pulse Dock")
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

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetColor.green(for: colorScheme))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
                .lineLimit(1)
            Circle()
                .fill(WidgetColor.green(for: colorScheme))
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
                .foregroundStyle(WidgetColor.green(for: colorScheme))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(widgetPrimaryText(for: colorScheme))
            Circle()
                .fill(WidgetColor.green(for: colorScheme))
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

private func widgetBackgroundColors(for colorScheme: ColorScheme) -> [Color] {
    if colorScheme == .dark {
        return [
            Color(red: 0.09, green: 0.11, blue: 0.12).opacity(0.96),
            Color(red: 0.07, green: 0.16, blue: 0.16).opacity(0.90),
            Color(red: 0.06, green: 0.09, blue: 0.11).opacity(0.82)
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
    static func blue(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.36, green: 0.62, blue: 1.00) : Color(red: 0.14, green: 0.43, blue: 0.95)
    }

    static func green(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.24, green: 0.82, blue: 0.62) : Color(red: 0.04, green: 0.62, blue: 0.39)
    }

    static func amber(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 1.00, green: 0.68, blue: 0.28) : Color(red: 0.93, green: 0.54, blue: 0.10)
    }

    static func cyan(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.29, green: 0.78, blue: 0.88) : Color(red: 0.04, green: 0.56, blue: 0.70)
    }

    static func red(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 1.00, green: 0.42, blue: 0.42) : Color(red: 0.84, green: 0.16, blue: 0.16)
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
    let normalizedProgress = min(max(progress, 0), 1)
    guard normalizedProgress > 0 else { return 0 }
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
        return "UPS"
    case .some:
        return PulseDockWidgetStrings.compactPowerExternal
    default:
        return PulseDockWidgetStrings.notReported
    }
}
