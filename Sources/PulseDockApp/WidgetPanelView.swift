import SwiftUI
#if canImport(SharedMetrics)
import SharedMetrics
#endif

enum MenuPopoverLayout {
    static let width: CGFloat = 356
    static let height: CGFloat = 520
    static let minimumHeight: CGFloat = 420
    static let screenMargin: CGFloat = 12
}

struct WidgetPanelView: View {
    @ObservedObject var store: MetricsStore
    let popoverWidth: CGFloat
    let popoverHeight: CGFloat
    let openDashboard: () -> Void
    let togglePause: () -> Void
    let openSettings: () -> Void

    var body: some View {
        MenuPopoverPreview(
            snapshot: store.snapshot,
            isPaused: store.isPaused,
            popoverWidth: popoverWidth,
            popoverHeight: popoverHeight,
            openDashboard: openDashboard,
            togglePause: togglePause,
            openSettings: openSettings
        )
    }
}

private struct MenuPopoverPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: MetricSnapshot
    let isPaused: Bool
    let popoverWidth: CGFloat
    let popoverHeight: CGFloat
    let openDashboard: () -> Void
    let togglePause: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 11) {
                    VStack(spacing: 7) {
                        PopoverMetricRow(title: "CPU", value: snapshot.cpuText, detail: snapshot.logicalCoreSummaryText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: Palette.green(for: colorScheme))
                        PopoverMetricRow(title: PulseDockAppStrings.metricMemory, value: snapshot.memoryUsageText, detail: snapshot.memoryText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: Palette.blue(for: colorScheme))
                        PopoverMetricRow(title: PulseDockAppStrings.metricNetwork, value: snapshot.networkText, detail: "\(snapshot.networkPathText) · ↓ \(snapshot.networkInText)  ↑ \(snapshot.networkOutText)", progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkBytesPerSecond)), tint: Palette.cyan(for: colorScheme))
                        PopoverMetricRow(title: PulseDockAppStrings.metricDisk, value: snapshot.diskUsageText, detail: snapshot.diskText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: Palette.amber(for: colorScheme))
                    }

                    HStack(spacing: 8) {
                        PopoverSmallStat(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: powerTint(snapshot))
                        PopoverSmallStat(title: PulseDockAppStrings.metricThermalState, value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState))
                        PopoverSmallStat(title: PulseDockAppStrings.metricLoad, value: snapshot.loadText, tint: reportedTint(hasReport: snapshot.hasLoadAverageReport, fallback: Palette.green(for: colorScheme)))
                    }

                    HStack(spacing: 8) {
                        PopoverSmallStat(title: PulseDockAppStrings.metricNetwork, value: snapshot.networkPathText, tint: networkTint(snapshot))
                        PopoverSmallStat(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, tint: reportedTint(hasReport: snapshot.hasDisplayReport, fallback: Palette.amber(for: colorScheme)))
                        PopoverSmallStat(title: PulseDockAppStrings.metricVolumes, value: snapshot.storageVolumeSummaryText, tint: reportedTint(hasReport: snapshot.hasStorageVolumeReport, fallback: Palette.blue(for: colorScheme)))
                    }

                    HStack(spacing: 8) {
                        PopoverSmallStat(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, tint: reportedTint(hasReport: snapshot.hasUptimeReport, fallback: Palette.amber(for: colorScheme)))
                        PopoverSmallStat(title: PulseDockAppStrings.metricKernel, value: snapshot.kernelText, tint: reportedTint(hasReport: snapshot.hasKernelReleaseReport, fallback: Palette.cyan(for: colorScheme)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            HStack(spacing: 8) {
                Button(action: openDashboard) {
                    PopoverActionLabel(icon: "macwindow", title: PulseDockAppStrings.menuOpenMainWindow)
                }
                Button(action: togglePause) {
                    PopoverActionLabel(icon: isPaused ? "play" : "pause", title: isPaused ? PulseDockAppStrings.menuResumeRefresh : PulseDockAppStrings.menuPauseRefresh)
                }
                Button(action: openSettings) {
                    PopoverActionLabel(icon: "gearshape", title: PulseDockAppStrings.menuSettings)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: popoverWidth, height: popoverHeight, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.green(for: colorScheme))
                .frame(width: 34, height: 34)
                .background(Palette.green(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Pulse Dock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(popoverPrimaryText(for: colorScheme))
                Text(snapshot.sampleTimeText)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(popoverSecondaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()

            let statusTint = isPaused ? Palette.amber(for: colorScheme) : Palette.green(for: colorScheme)
            HStack(spacing: 5) {
                PopoverStatusDot(color: statusTint)
                Text(isPaused ? PulseDockAppStrings.menuStatusPaused : PulseDockAppStrings.menuStatusLive)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusTint)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(popoverTintFill(statusTint, for: colorScheme), in: Capsule())
        }
    }

    private func reportedTint(hasReport: Bool, fallback: Color) -> Color {
        guard hasReport else { return Palette.cyan(for: colorScheme) }
        return fallback
    }

    private func tint(for tone: MetricStatusTone) -> Color {
        switch tone {
        case .normal:
            return Palette.green(for: colorScheme)
        case .warning:
            return Palette.amber(for: colorScheme)
        case .critical:
            return Palette.red(for: colorScheme)
        case .neutral:
            return Palette.cyan(for: colorScheme)
        }
    }

    private func powerTint(_ snapshot: MetricSnapshot) -> Color {
        tint(for: snapshot.powerStatusTone)
    }

    private func thermalTint(_ state: String) -> Color {
        tint(for: ThermalState(raw: state).metricStatusTone)
    }

    private func networkTint(_ snapshot: MetricSnapshot) -> Color {
        tint(for: snapshot.canonicalNetworkPathState.metricStatusTone)
    }
}

private struct PopoverMetricRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let detail: String
    let progress: Double?
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(popoverPrimaryText(for: colorScheme))
                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(popoverSecondaryText(for: colorScheme))
                        .lineLimit(1)
                }
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(popoverPrimaryText(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(popoverTrackFill(for: colorScheme))
                    if let progress {
                        Capsule()
                            .fill(tint.gradient)
                            .frame(width: MetricScales.fillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 7))
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(9)
        .frame(minHeight: 52)
        .background(popoverPanelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(popoverPanelStroke(for: colorScheme), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(detail)")
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockAppStrings.notReported)
    }
}

private struct PopoverSmallStat: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            PopoverStatusDot(color: tint)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(popoverSecondaryText(for: colorScheme))
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(popoverPrimaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(popoverPanelFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(popoverPanelStroke(for: colorScheme), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

private struct PopoverStatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }
}

private struct PopoverActionLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(popoverSecondaryText(for: colorScheme))
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(popoverPanelFill(for: colorScheme), in: Capsule())
        .overlay {
            Capsule().strokeBorder(popoverPanelStroke(for: colorScheme), lineWidth: 0.7)
        }
    }
}

private func popoverPanelFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(red: 0.10, green: 0.13, blue: 0.15).opacity(0.58) : Color(red: 1, green: 1, blue: 1).opacity(0.50)
}

private func popoverPanelStroke(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.11) : Color.black.opacity(0.06)
}

private func popoverPrimaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary
}

private func popoverSecondaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.62) : Color.secondary
}

private func popoverTrackFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.11) : Color.secondary.opacity(0.13)
}

private func popoverTintFill(_ tint: Color, for colorScheme: ColorScheme) -> Color {
    tint.opacity(colorScheme == .dark ? 0.18 : 0.11)
}

private enum Palette {
    static func blue(for colorScheme: ColorScheme) -> Color {
        color(.blue, for: colorScheme)
    }

    static func green(for colorScheme: ColorScheme) -> Color {
        color(.green, for: colorScheme)
    }

    static func amber(for colorScheme: ColorScheme) -> Color {
        color(.amber, for: colorScheme)
    }

    static func cyan(for colorScheme: ColorScheme) -> Color {
        color(.cyan, for: colorScheme)
    }

    static func red(for colorScheme: ColorScheme) -> Color {
        color(.red, for: colorScheme)
    }

    private static func color(_ accent: MetricAccent, for colorScheme: ColorScheme) -> Color {
        let appearance: MetricAccentAppearance = colorScheme == .dark ? .dark : .light
        let components = MetricAccentComponents.components(for: accent, appearance: appearance)
        return Color(red: components.red, green: components.green, blue: components.blue)
    }
}
