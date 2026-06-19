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
    let popoverHeight: CGFloat
    let openDashboard: () -> Void
    let togglePause: () -> Void
    let openSettings: () -> Void

    var body: some View {
        MenuPopoverPreview(
            snapshot: store.snapshot,
            isPaused: store.isPaused,
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
                        PopoverMetricRow(title: "CPU", value: snapshot.cpuText, detail: snapshot.logicalCoreSummaryText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: Palette.green)
                        PopoverMetricRow(title: "内存", value: snapshot.memoryUsageText, detail: snapshot.memoryText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: Palette.blue)
                        PopoverMetricRow(title: "网络", value: snapshot.networkText, detail: "\(snapshot.networkPathText) · ↓ \(snapshot.networkInText)  ↑ \(snapshot.networkOutText)", progress: reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: normalizedRate(snapshot.networkBytesPerSecond)), tint: Palette.cyan)
                        PopoverMetricRow(title: "磁盘", value: snapshot.diskUsageText, detail: snapshot.diskText, progress: reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: Palette.amber)
                    }

                    HStack(spacing: 8) {
                        PopoverSmallStat(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, tint: powerTint(snapshot))
                        PopoverSmallStat(title: "热状态", value: snapshot.thermalText, tint: thermalTint(snapshot.thermalState))
                        PopoverSmallStat(title: "负载", value: snapshot.loadText, tint: reportedTint(hasReport: snapshot.hasLoadAverageReport, fallback: Palette.green))
                    }

                    HStack(spacing: 8) {
                        PopoverSmallStat(title: "网络", value: snapshot.networkPathText, tint: networkTint(snapshot))
                        PopoverSmallStat(title: "显示器", value: snapshot.displaySummaryText, tint: reportedTint(hasReport: snapshot.hasDisplayReport, fallback: Palette.amber))
                        PopoverSmallStat(title: "卷", value: snapshot.storageVolumeSummaryText, tint: reportedTint(hasReport: snapshot.hasStorageVolumeReport, fallback: Palette.blue))
                    }

                    HStack(spacing: 8) {
                        PopoverSmallStat(title: "运行", value: snapshot.uptimeText, tint: reportedTint(hasReport: snapshot.hasUptimeReport, fallback: Palette.amber))
                        PopoverSmallStat(title: "内核", value: snapshot.kernelText, tint: reportedTint(hasReport: snapshot.hasKernelReleaseReport, fallback: Palette.cyan))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            HStack(spacing: 8) {
                Button(action: openDashboard) {
                    PopoverActionLabel(icon: "macwindow", title: "打开主窗口")
                }
                Button(action: togglePause) {
                    PopoverActionLabel(icon: isPaused ? "play" : "pause", title: isPaused ? "恢复刷新" : "暂停刷新")
                }
                Button(action: openSettings) {
                    PopoverActionLabel(icon: "gearshape", title: "设置")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: MenuPopoverLayout.width, height: popoverHeight, alignment: .topLeading)
        .background {
            ZStack {
                VisualEffectView(material: .popover)
                LinearGradient(
                    colors: popoverBackgroundColors(for: colorScheme),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(popoverPanelStroke(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: popoverShadow(for: colorScheme), radius: 30, x: 0, y: 16)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.green)
                .frame(width: 34, height: 34)
                .background(Palette.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Pulse Dock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(popoverPrimaryText(for: colorScheme))
                Text(snapshot.sampleTimeText)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(popoverSecondaryText(for: colorScheme))
            }

            Spacer()

            HStack(spacing: 5) {
                Circle().fill(isPaused ? Palette.amber : Palette.green).frame(width: 7, height: 7)
                Text(isPaused ? "暂停" : "实时")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isPaused ? Palette.amber : Palette.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(popoverTintFill(isPaused ? Palette.amber : Palette.green, for: colorScheme), in: Capsule())
        }
    }

    private func normalizedRate(_ bytesPerSecond: UInt64) -> Double {
        min(Double(bytesPerSecond) / 40_000_000, 1)
    }

    private func reportedProgress(hasReport: Bool, progress: Double) -> Double? {
        guard hasReport else { return nil }
        return progress
    }

    private func reportedTint(hasReport: Bool, fallback: Color) -> Color {
        guard hasReport else { return Palette.cyan }
        return fallback
    }

    private func powerTint(_ snapshot: MetricSnapshot) -> Color {
        switch snapshot.powerStatusTone {
        case .normal:
            return Palette.green
        case .warning:
            return Palette.amber
        case .critical:
            return Palette.red
        case .neutral:
            return Palette.cyan
        }
    }

    private func thermalTint(_ state: String) -> Color {
        switch state.lowercased() {
        case "critical", "hot", "serious": Palette.red
        case "warm", "fair": Palette.amber
        case "nominal": Palette.green
        case "unknown": Palette.cyan
        default: Palette.cyan
        }
    }

    private func networkTint(_ snapshot: MetricSnapshot) -> Color {
        switch snapshot.networkPathStatus.lowercased() {
        case "satisfied":
            Palette.green
        case "requiresconnection", "requires_connection", "requires connection":
            Palette.amber
        case "unsatisfied":
            Palette.red
        default:
            Palette.cyan
        }
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
                            .frame(width: progressFillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 7))
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
    }
}

private struct PopoverSmallStat: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Circle().fill(tint).frame(width: 7, height: 7)
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

private func popoverBackgroundColors(for colorScheme: ColorScheme) -> [Color] {
    if colorScheme == .dark {
        return [
            Color(red: 0.08, green: 0.10, blue: 0.11).opacity(0.96),
            Color(red: 0.06, green: 0.18, blue: 0.17).opacity(0.90),
            Color(red: 0.17, green: 0.13, blue: 0.07).opacity(0.78)
        ]
    }

    return [
        Color(red: 1, green: 1, blue: 1).opacity(0.80),
        Color(red: 0.90, green: 0.95, blue: 0.94).opacity(0.72),
        Color(red: 0.98, green: 0.94, blue: 0.86).opacity(0.42)
    ]
}

private func popoverPanelFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.08) : Color(red: 1, green: 1, blue: 1).opacity(0.50)
}

private func popoverPanelStroke(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.06)
}

private func popoverPrimaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary
}

private func popoverSecondaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.62) : Color.secondary
}

private func popoverTrackFill(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.14) : Color.secondary.opacity(0.13)
}

private func popoverTintFill(_ tint: Color, for colorScheme: ColorScheme) -> Color {
    tint.opacity(colorScheme == .dark ? 0.18 : 0.11)
}

private func popoverShadow(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.black.opacity(0.36) : Color.black.opacity(0.16)
}

private func progressFillWidth(_ progress: Double, in totalWidth: CGFloat, minimumVisibleWidth: CGFloat) -> CGFloat {
    let normalizedProgress = min(max(progress, 0), 1)
    guard normalizedProgress > 0 else { return 0 }
    return max(minimumVisibleWidth, totalWidth * normalizedProgress)
}

private enum Palette {
    static let blue = Color(red: 0.14, green: 0.43, blue: 0.95)
    static let green = Color(red: 0.04, green: 0.62, blue: 0.39)
    static let amber = Color(red: 0.93, green: 0.54, blue: 0.10)
    static let cyan = Color(red: 0.04, green: 0.56, blue: 0.70)
    static let red = Color(red: 0.84, green: 0.16, blue: 0.16)
}
