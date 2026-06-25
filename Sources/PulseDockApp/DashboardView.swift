import SwiftUI
#if canImport(SharedMetrics)
import SharedMetrics
#endif

@MainActor
final class DashboardRouter: ObservableObject {
    @Published var selectedPage: DashboardPage = .overview

    func openSettings() {
        selectedPage = .settings
    }
}

struct DashboardView: View {
    @ObservedObject var store: MetricsStore
    @ObservedObject var router: DashboardRouter

    var body: some View {
        HStack(spacing: 0) {
            DashboardSidebar(selection: $router.selectedPage, snapshot: store.snapshot)

            Divider()
                .overlay(DashboardColor.border)

            VStack(spacing: 0) {
                DashboardTopBar(page: router.selectedPage, snapshot: store.snapshot, refreshInterval: store.refreshInterval)

                GeometryReader { proxy in
                    ScrollView {
                        if proxy.size.width < 1080 {
                            pageContent(
                                metricColumns: adaptiveMetricColumns(for: proxy.size.width),
                                summaryColumns: adaptiveSummaryColumns(for: proxy.size.width),
                                isCompact: true
                            )
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 28)
                        } else {
                            pageContent(
                                metricColumns: adaptiveMetricColumns(for: proxy.size.width),
                                summaryColumns: adaptiveSummaryColumns(for: proxy.size.width),
                                isCompact: false
                            )
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 28)
                        }
                    }
                    .background(DashboardColor.canvas)
                }
            }
        }
        .frame(minWidth: 960, idealWidth: 1320, minHeight: 640, idealHeight: 860)
        .background(WindowBackdrop())
    }

    @ViewBuilder
    private func pageContent(metricColumns: [GridItem], summaryColumns: [GridItem], isCompact: Bool) -> some View {
        let snapshot = store.snapshot
        let history = store.recentSnapshots

        switch router.selectedPage {
        case .overview:
            OverviewPage(store: store, history: history, metricColumns: metricColumns, isCompact: isCompact)
        case .cpu:
            CPUPage(snapshot: snapshot, history: history)
        case .gpu:
            GPUDisplayPage(snapshot: snapshot)
        case .memory:
            MemoryPage(snapshot: snapshot, history: history)
        case .storage:
            StoragePage(store: store, history: history)
        case .network:
            NetworkPage(snapshot: snapshot, history: history, metricColumns: metricColumns)
        case .power:
            PowerPage(snapshot: snapshot, history: history)
        case .processes:
            ProcessesPage(snapshot: snapshot, summaryColumns: summaryColumns)
        case .sensors:
            SensorsPage(store: store)
        case .history:
            HistoryAlertsPage(store: store, history: history)
        case .settings:
            SettingsPage(store: store, isCompact: isCompact)
        }
    }
}

enum DashboardPage: String, CaseIterable, Identifiable {
    case overview
    case cpu
    case gpu
    case memory
    case storage
    case network
    case power
    case processes
    case sensors
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "总览"
        case .cpu: "CPU"
        case .gpu: "GPU / 显示"
        case .memory: "内存"
        case .storage: "存储"
        case .network: "网络"
        case .power: "电源"
        case .processes: "App"
        case .sensors: "状态"
        case .history: "历史"
        case .settings: "设置"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: "运行总览"
        case .cpu: "处理器负载与核心"
        case .gpu: "图形设备与屏幕"
        case .memory: "占用、缓存与压缩"
        case .storage: "容量与磁盘状态"
        case .network: "接口、吞吐与连接状态"
        case .power: "电池、电源与热状态"
        case .processes: "运行中的应用"
        case .sensors: "热状态与系统信号"
        case .history: "本地采样历史与阈值判断"
        case .settings: "显示、刷新与小组件"
        }
    }

    var icon: String {
        switch self {
        case .overview: "gauge.with.dots.needle.bottom.50percent"
        case .cpu: "cpu"
        case .gpu: "display"
        case .memory: "memorychip"
        case .storage: "internaldrive"
        case .network: "network"
        case .power: "battery.75percent"
        case .processes: "list.bullet.rectangle"
        case .sensors: "thermometer.medium"
        case .history: "chart.xyaxis.line"
        case .settings: "slider.horizontal.3"
        }
    }
}

private enum DashboardColor {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .controlBackgroundColor).opacity(0.74)
    static let panel = Color(nsColor: .textBackgroundColor).opacity(0.78)
    static let panelAlt = Color(nsColor: .controlBackgroundColor).opacity(0.86)
    static let border = Color(nsColor: .separatorColor).opacity(0.52)
    static let muted = Color.secondary.opacity(0.74)
    static let blue = Color(red: 0.14, green: 0.43, blue: 0.95)
    static let green = Color(red: 0.04, green: 0.62, blue: 0.39)
    static let amber = Color(red: 0.93, green: 0.54, blue: 0.10)
    static let red = Color(red: 0.84, green: 0.16, blue: 0.16)
    static let purple = Color(red: 0.48, green: 0.34, blue: 0.88)
    static let cyan = Color(red: 0.04, green: 0.56, blue: 0.70)
}

private struct WindowBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            VisualEffectView(material: .windowBackground)
            LinearGradient(
                colors: windowBackdropColors(for: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private func windowBackdropColors(for colorScheme: ColorScheme) -> [Color] {
    if colorScheme == .dark {
        return [
            Color(nsColor: .windowBackgroundColor).opacity(0.98),
            Color(red: 0.08, green: 0.11, blue: 0.10).opacity(0.64),
            Color(red: 0.12, green: 0.09, blue: 0.06).opacity(0.42)
        ]
    }

    return [
        Color(nsColor: .windowBackgroundColor).opacity(0.96),
        Color(red: 0.92, green: 0.95, blue: 0.94).opacity(0.48),
        Color(red: 0.96, green: 0.94, blue: 0.90).opacity(0.34)
    ]
}

private func adaptiveMetricColumns(for width: CGFloat) -> [GridItem] {
    let count = width < 1080 ? 2 : 4
    return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
}

private func adaptiveSummaryColumns(for width: CGFloat) -> [GridItem] {
    let count = width < 1080 ? 2 : 4
    return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
}

private struct DashboardSidebar: View {
    @Binding var selection: DashboardPage
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DashboardColor.green)
                    Text("Pulse Dock")
                        .font(.system(size: 19, weight: .semibold, design: .default))
                }

                Text("本机状态")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)

            VStack(spacing: 4) {
                ForEach(DashboardPage.allCases) { page in
                    SidebarRow(page: page, isSelected: page == selection) {
                        selection = page
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 16)

            SidebarHealthCard(snapshot: snapshot)
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
        }
        .frame(width: 224)
        .background {
            ZStack {
                VisualEffectView(material: .sidebar)
                DashboardColor.sidebar
            }
        }
    }
}

private struct SidebarRow: View {
    let page: DashboardPage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)
                Text(page.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary.opacity(0.58))
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(DashboardColor.blue)
                        .frame(width: 3, height: 18)
                        .offset(x: -2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarHealthCard: View {
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusDot(color: thermalColor)
                Text("实时采样")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(snapshot.sampleTimeText)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(DashboardColor.muted)
            }

            CompactMetricLine(title: "CPU", value: snapshot.cpuText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: DashboardColor.green)
            CompactMetricLine(title: "内存", value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: DashboardColor.blue)
            CompactMetricLine(title: "磁盘", value: snapshot.diskUsageText, progress: reportedProgress(hasReport: snapshot.hasDiskUsageReport, progress: snapshot.diskUsage), tint: DashboardColor.amber)
        }
        .padding(13)
        .panel(cornerRadius: 8)
    }

    private var thermalColor: Color {
        thermalStatus(snapshot.thermalState).color
    }
}

private struct DashboardTopBar: View {
    let page: DashboardPage
    let snapshot: MetricSnapshot
    let refreshInterval: RefreshIntervalOption

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(page.subtitle)
                    .font(.system(size: 28, weight: .semibold, design: .default))
                Text("实时采样本机状态，专注清晰可读的系统概览")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
            }

            Spacer()

            HStack(spacing: 8) {
                DataChip(icon: "desktopcomputer", text: "本机")
                DataChip(icon: "clock", text: "采样 \(snapshot.sampleTimeText)")
                DataChip(icon: "arrow.clockwise", text: refreshInterval.label)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 82)
        .background {
            ZStack {
                VisualEffectView(material: .headerView)
                Color(nsColor: .windowBackgroundColor).opacity(0.72)
            }
        }
        .overlay(alignment: .bottom) {
            Divider().overlay(DashboardColor.border)
        }
    }
}

private struct OverviewPage: View {
    @ObservedObject var store: MetricsStore
    let history: [MetricSnapshot]
    let metricColumns: [GridItem]
    let isCompact: Bool

    private var snapshot: MetricSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: metricColumns, spacing: 12) {
                MetricCard(title: "CPU 使用率", value: snapshot.cpuText, detail: snapshot.logicalCoreSummaryText, icon: "cpu", tint: DashboardColor.green, badgeText: snapshot.cpuText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), values: cpuTrendValues(from: history))
                MetricCard(title: "内存占用", value: snapshot.memoryUsageText, detail: snapshot.memoryText, icon: "memorychip", tint: DashboardColor.blue, badgeText: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), values: memoryTrendValues(from: history))
                MetricCard(title: "网络吞吐", value: snapshot.networkText, detail: "\(snapshot.networkPathText) · ↓ \(snapshot.networkInText)  ↑ \(snapshot.networkOutText)", icon: "arrow.up.arrow.down", tint: DashboardColor.cyan, badgeText: nil, progress: reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: normalizedRate(snapshot.networkBytesPerSecond, baseline: 40_000_000)), values: networkTrendValues(from: history, keyPath: \.networkBytesPerSecond, baseline: 40_000_000))
                MetricCard(title: "电源状态", value: snapshot.powerStatusText, detail: snapshot.powerSourceText, icon: "battery.75percent", tint: powerTint(snapshot), badgeText: snapshot.batteryPercent.map { MetricFormatting.percentage($0) }, progress: powerGaugeProgress(snapshot), values: powerTrendValues(from: history))
            }

            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    overviewTrendPanel
                    overviewStatusPanel
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    overviewTrendPanel
                    overviewStatusPanel
                        .frame(width: 330)
                }
            }

            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    ProcessListPanel(processes: snapshot.runningApps)
                    WidgetPreviewPanel(snapshot: snapshot)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ProcessListPanel(processes: snapshot.runningApps)
                    WidgetPreviewPanel(snapshot: snapshot)
                        .frame(width: 360)
                }
            }
        }
    }

    private var overviewTrendPanel: some View {
        DashboardPanel(title: "运行趋势", subtitle: reportedHistorySampleCountText(from: history), icon: "chart.xyaxis.line") {
            VStack(spacing: 14) {
                TrendRow(title: "CPU", value: snapshot.cpuText, tint: DashboardColor.green, values: cpuTrendValues(from: history))
                TrendRow(title: "负载", value: snapshot.loadText, tint: DashboardColor.purple, values: loadTrendValues(from: history))
                TrendRow(title: "内存", value: snapshot.memoryUsageText, tint: DashboardColor.blue, values: memoryTrendValues(from: history))
                TrendRow(title: "网络", value: snapshot.networkText, tint: DashboardColor.cyan, values: networkTrendValues(from: history, keyPath: \.networkBytesPerSecond, baseline: 40_000_000))
                TrendRow(title: "磁盘", value: snapshot.diskUsageText, tint: DashboardColor.amber, values: diskTrendValues(from: history))
            }
        }
    }

    private var overviewStatusPanel: some View {
        DashboardPanel(title: "系统状态", subtitle: snapshot.osVersionText, icon: "checkmark.seal") {
            VStack(spacing: 10) {
                StatusSummaryRow(title: "热状态", value: snapshot.thermalText, status: thermalStatus(snapshot.thermalState))
                StatusSummaryRow(title: "运行时间", value: snapshot.uptimeText, status: snapshot.hasUptimeReport ? .normal : .neutral)
                StatusSummaryRow(title: "内核版本", value: snapshot.kernelText, status: snapshot.hasKernelReleaseReport ? .normal : .neutral)
                StatusSummaryRow(title: "CPU 状态", value: "\(snapshot.cpuText) / \(MetricFormatting.percentage(store.cpuAlertThreshold))", status: usageStatusLevel(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold))
                StatusSummaryRow(title: "内存状态", value: "\(snapshot.memoryUsageText) / \(MetricFormatting.percentage(store.memoryAlertThreshold))", status: usageStatusLevel(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold))
                StatusSummaryRow(title: "负载 1/5/15", value: snapshot.loadDetailText, status: snapshot.hasLoadAverageReport ? .normal : .neutral)
                StatusSummaryRow(title: "运行中 App", value: snapshot.runningAppSummaryText, status: snapshot.hasRunningAppReport ? .normal : .neutral)
                StatusSummaryRow(title: "网络连接", value: snapshot.networkPathText, status: networkStatusLevel(snapshot))
                StatusSummaryRow(title: "GPU / 显示器", value: snapshot.gpuDisplaySummaryText, status: snapshot.hasGPUDisplayReport ? .normal : .neutral)
                StatusSummaryRow(title: "磁盘可用", value: snapshot.diskText, status: usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold))
            }
        }
    }
}

private struct CPUPage: View {
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                DashboardPanel(title: "CPU 处理器", subtitle: "处理器核心统计", icon: "cpu") {
                    VStack(spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(snapshot.cpuText)
                                .font(.system(size: 54, weight: .semibold, design: .default).monospacedDigit())
                            Text("当前总占用")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DashboardColor.muted)
                            Spacer()
                            DataChip(icon: "waveform.path.ecg", text: reportedHistorySampleChipText(from: history))
                        }

                        Sparkline(values: cpuTrendValues(from: history), tint: DashboardColor.green, fill: true)
                            .frame(height: 170)
                    }
                }

                DashboardPanel(title: "负载", subtitle: "系统负载趋势", icon: "speedometer") {
                    VStack(spacing: 12) {
                        StatLine(label: "1 分钟", value: snapshot.loadText, progress: snapshot.loadAverageProgress, tint: DashboardColor.green)
                        StatLine(label: "5 分钟", value: snapshot.loadAverage5Text, progress: snapshot.loadAverage5Progress, tint: DashboardColor.blue)
                        StatLine(label: "15 分钟", value: snapshot.loadAverage15Text, progress: snapshot.loadAverage15Progress, tint: DashboardColor.amber)
                        Divider()
                        KeyValueGrid(items: [
                            ("处理器", snapshot.cpuBrandText),
                            ("物理核心", snapshot.physicalCoreCountText),
                            ("逻辑核心", snapshot.logicalCoreCountText),
                            ("活动核心", snapshot.activeProcessorCountText),
                            ("运行中 App", snapshot.runningAppCountText),
                            ("最近采样", snapshot.sampleTimeText)
                        ])
                    }
                }
                .frame(width: 320)
            }

            DashboardPanel(title: "每核心使用率", subtitle: "按系统报告的逻辑核心显示", icon: "square.grid.3x3") {
                if snapshot.cpuCoreUsages.isEmpty {
                    StatusSummaryRow(title: "每核心采样", value: "系统未报告", status: .neutral)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(Array(snapshot.cpuCoreUsages.enumerated()), id: \.offset) { index, value in
                            CoreUsageTile(index: index + 1, value: value, tint: DashboardColor.green)
                        }
                    }
                }
            }

            ProcessListPanel(processes: snapshot.runningApps, title: "运行中 App", subtitle: "前台优先 · 按名称排序")
        }
    }
}

private struct MemoryPage: View {
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                DashboardPanel(title: "内存占用", subtitle: "实时内存统计", icon: "memorychip") {
                    HStack(spacing: 24) {
                        RingGauge(title: "已用", value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: DashboardColor.blue)
                            .frame(width: 148, height: 148)

                        VStack(spacing: 14) {
                            MemorySegmentBar(snapshot: snapshot)
                            TrendRow(title: "占用趋势", value: snapshot.memoryText, tint: DashboardColor.blue, values: memoryTrendValues(from: history))
                            KeyValueGrid(items: [
                                ("总内存", snapshot.memoryDetailText),
                                ("空闲", snapshot.memoryFreeText),
                                ("缓存", snapshot.memoryCachedText),
                                ("压缩", snapshot.memoryCompressedText),
                                ("交换", snapshot.memorySwapText),
                                ("交换可用", snapshot.memorySwapAvailableText),
                                ("交换总量", snapshot.memorySwapTotalText)
                            ])
                        }
                    }
                }

                DashboardPanel(title: "组成", subtitle: "统一内存友好展示", icon: "rectangle.3.group") {
                    VStack(spacing: 12) {
                        StatLine(label: "App / 活跃", value: snapshot.memoryActiveText, progress: reportedProgress(hasReport: snapshot.hasMemoryCompositionReport, progress: normalizedBytes(snapshot.memoryActiveBytes, total: snapshot.memoryTotalBytes)), tint: DashboardColor.green)
                        StatLine(label: "有线", value: snapshot.memoryWiredText, progress: reportedProgress(hasReport: snapshot.hasMemoryCompositionReport, progress: normalizedBytes(snapshot.memoryWiredBytes, total: snapshot.memoryTotalBytes)), tint: DashboardColor.amber)
                        StatLine(label: "压缩", value: snapshot.memoryCompressedText, progress: reportedProgress(hasReport: snapshot.hasMemoryCompositionReport, progress: normalizedBytes(snapshot.memoryCompressedBytes, total: snapshot.memoryTotalBytes)), tint: DashboardColor.purple)
                        StatLine(label: "缓存文件", value: snapshot.memoryCachedText, progress: reportedProgress(hasReport: snapshot.hasMemoryCompositionReport, progress: normalizedBytes(snapshot.memoryCachedBytes, total: snapshot.memoryTotalBytes)), tint: DashboardColor.cyan)
                        StatLine(label: "交换", value: snapshot.memorySwapText, progress: reportedProgress(hasReport: snapshot.hasMemorySwapReport, progress: snapshot.memorySwapUsage), tint: DashboardColor.red)
                    }
                }
                .frame(width: 360)
            }

            ProcessListPanel(processes: snapshot.runningApps, title: "运行中 App", subtitle: "当前会话中的应用列表")
        }
    }

}

private struct StoragePage: View {
    @ObservedObject var store: MetricsStore
    let history: [MetricSnapshot]

    private var snapshot: MetricSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardPanel(title: "存储空间", subtitle: "本机卷容量", icon: "internaldrive") {
                VStack(spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(snapshot.diskUsedText)
                            .font(.system(size: 44, weight: .semibold).monospacedDigit())
                        Text("已用 / \(snapshot.diskTotalText)")
                            .foregroundStyle(DashboardColor.muted)
                        Spacer()
                        DataChip(icon: "externaldrive", text: "主卷")
                    }

                    CapacityBar(segments: diskCapacitySegments(snapshot))

                    TrendRow(title: "容量使用", value: snapshot.diskUsageText, tint: DashboardColor.amber, values: diskTrendValues(from: history))
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                SourceCapabilityCard(title: "容量统计", value: snapshot.storageVolumeSummaryText, icon: "checkmark.circle", status: snapshot.hasStorageVolumeReport ? .normal : .neutral, source: "系统卷信息")
                SourceCapabilityCard(title: "主卷可用", value: snapshot.diskAvailableText, icon: "externaldrive.badge.checkmark", status: usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold), source: "主卷")
                SourceCapabilityCard(title: "外接卷", value: snapshot.externalStorageVolumeSummaryText, icon: "externaldrive.connected.to.line.below", status: snapshot.hasExternalStorageVolumeSummaryReport ? .normal : .neutral, source: "已挂载卷")
            }

            DashboardPanel(title: "卷列表", subtitle: "已挂载的存储卷", icon: "list.bullet.rectangle") {
                VStack(spacing: 0) {
                    TableHeader(columns: ["卷", "文件系统", "总量", "已用", "可用", "使用率", "类型", "访问"])
                    ForEach(snapshot.storageVolumes.filter(\.hasInventoryReport).prefix(8)) { volume in
                        TableRow(values: [
                            volumeLabel(volume),
                            volume.fileSystem,
                            volume.totalText,
                            volume.usedText,
                            volume.availableText,
                            volume.usageText,
                            volume.kindText,
                            volume.accessText
                        ])
                    }
                }
            }
        }
    }

}

private struct NetworkPage: View {
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]
    let metricColumns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: metricColumns, spacing: 12) {
                MetricCard(title: "下载", value: snapshot.networkInText, detail: "实时速率", icon: "arrow.down", tint: DashboardColor.blue, badgeText: nil, progress: reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: normalizedRate(snapshot.networkInBytesPerSecond, baseline: 20_000_000)), values: networkTrendValues(from: history, keyPath: \.networkInBytesPerSecond, baseline: 20_000_000))
                MetricCard(title: "上传", value: snapshot.networkOutText, detail: "实时速率", icon: "arrow.up", tint: DashboardColor.green, badgeText: nil, progress: reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: normalizedRate(snapshot.networkOutBytesPerSecond, baseline: 20_000_000)), values: networkTrendValues(from: history, keyPath: \.networkOutBytesPerSecond, baseline: 20_000_000))
                MetricCard(title: "总吞吐", value: snapshot.networkText, detail: "合并上下行", icon: "network", tint: DashboardColor.cyan, badgeText: nil, progress: reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: normalizedRate(snapshot.networkBytesPerSecond, baseline: 40_000_000)), values: networkTrendValues(from: history, keyPath: \.networkBytesPerSecond, baseline: 40_000_000))
                MetricCard(title: "连接状态", value: snapshot.networkPathText, detail: snapshot.networkPathDetailText, icon: "checkmark.seal", tint: networkStatusColor(snapshot), badgeText: nil, progress: reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: networkPathProgress(snapshot)), values: networkPathTrendValues(from: history))
                MetricCard(title: "接口", value: snapshot.networkInterfaceSummary, detail: "活动接口", icon: "wifi", tint: DashboardColor.purple, badgeText: nil, progress: reportedProgress(hasReport: snapshot.hasNetworkInterfaceReport, progress: activeInterfaceProgress(snapshot)), values: [])
            }

            DashboardPanel(title: "连接能力", subtitle: "系统网络路径", icon: "point.3.connected.trianglepath.dotted") {
                VStack(spacing: 0) {
                    TableHeader(columns: ["项目", "当前值", "来源"])
                    TableRow(values: ["路径", snapshot.networkPathText, snapshot.networkPathDetailText])
                    TableRow(values: ["能力", snapshot.networkPathCapabilityText, "系统路径"])
                    TableRow(values: ["DNS", snapshot.networkDNSCapabilityText, "名称解析"])
                    TableRow(values: ["IPv4", snapshot.networkIPv4CapabilityText, "网络路径"])
                    TableRow(values: ["IPv6", snapshot.networkIPv6CapabilityText, "网络路径"])
                    TableRow(values: ["低数据模式", snapshot.networkLowDataModeText, "系统路径"])
                    TableRow(values: ["计量网络", snapshot.networkMeteredText, "系统路径"])
                }
            }

            DashboardPanel(title: "网络趋势", subtitle: "最近实时采样", icon: "chart.line.uptrend.xyaxis") {
                VStack(spacing: 14) {
                    TrendRow(title: "总计", value: snapshot.networkText, tint: DashboardColor.cyan, values: networkTrendValues(from: history, keyPath: \.networkBytesPerSecond, baseline: 40_000_000))
                    TrendRow(title: "连接", value: snapshot.networkPathText, tint: networkStatusColor(snapshot), values: networkPathTrendValues(from: history))
                    TrendRow(title: "下载", value: snapshot.networkInText, tint: DashboardColor.blue, values: networkTrendValues(from: history, keyPath: \.networkInBytesPerSecond, baseline: 20_000_000))
                    TrendRow(title: "上传", value: snapshot.networkOutText, tint: DashboardColor.green, values: networkTrendValues(from: history, keyPath: \.networkOutBytesPerSecond, baseline: 20_000_000))
                }
            }

            DashboardPanel(title: "接口", subtitle: "网络接口与链路", icon: "wifi") {
                VStack(spacing: 0) {
                    let reportedInterfaces = snapshot.networkInterfaces.filter(\.hasInventoryReport)
                    TableHeader(columns: ["接口", "类型", "状态", "MTU", "链路", "流量", "包", "错误"])
                    if reportedInterfaces.isEmpty {
                        TableEmptyRow(text: "系统未报告")
                    } else {
                        ForEach(reportedInterfaces.prefix(10)) { interface in
                            TableRow(values: [
                                interface.displayName,
                                interface.kind,
                                interface.stateText,
                                interface.mtuText,
                                interface.linkSpeedText,
                                interface.byteCountText,
                                interface.packetCountText,
                                interface.packetErrorText
                            ])
                        }
                    }
                }
            }
        }
    }
}

private struct PowerPage: View {
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                DashboardPanel(title: "电源与电池", subtitle: "电量与供电方式", icon: "battery.75percent") {
                    HStack(spacing: 24) {
                        RingGauge(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, progress: powerGaugeProgress(snapshot), tint: powerTint(snapshot))
                            .frame(width: 152, height: 152)
                        VStack(spacing: 14) {
                            TrendRow(title: powerTrendTitle(snapshot), value: snapshot.powerStatusText, tint: powerTint(snapshot), values: powerTrendValues(from: history))
                            KeyValueGrid(items: [
                                ("电源", snapshot.powerSourceText),
                                ("剩余时间", snapshot.batteryTimeRemainingText),
                                ("当前容量", snapshot.batteryCurrentCapacityText),
                                ("最大容量", snapshot.batteryMaxCapacityText),
                                ("循环次数", snapshot.batteryCycleText),
                                ("健康", snapshot.batteryHealthText),
                                ("设计容量", snapshot.batteryDesignCapacityText),
                                ("电压", snapshot.batteryVoltageText),
                                ("电流", snapshot.batteryAmperageText)
                            ])
                        }
                    }
                }

                DashboardPanel(title: "热状态", subtitle: "系统温控状态", icon: "thermometer.medium") {
                    VStack(spacing: 12) {
                        StatusSummaryRow(title: "当前状态", value: snapshot.thermalText, status: thermalStatus(snapshot.thermalState))
                        StatusSummaryRow(title: "性能限制", value: snapshot.thermalLimitText, status: thermalStatus(snapshot.thermalState))
                        StatusSummaryRow(title: "运行时间", value: snapshot.uptimeText, status: snapshot.hasUptimeReport ? .normal : .neutral)
                        StatusSummaryRow(title: "最近采样", value: snapshot.sampleTimeText, status: snapshot.hasSampleTimeReport ? .normal : .neutral)
                    }
                }
                .frame(width: 340)
            }

            DashboardPanel(title: "电池信息", subtitle: "电量、供电方式与预计时间", icon: "bolt") {
                VStack(spacing: 0) {
                    TableHeader(columns: ["项目", "当前值", "说明"])
                    TableRow(values: [snapshot.powerStatusTitle, snapshot.powerStatusText, snapshot.powerSourceText])
                    TableRow(values: ["剩余时间", snapshot.batteryTimeRemainingText, "系统估算"])
                    TableRow(values: ["当前容量", snapshot.batteryCurrentCapacityText, "电源状态"])
                    TableRow(values: ["最大容量", snapshot.batteryMaxCapacityText, "电源状态"])
                    TableRow(values: ["设计容量", snapshot.batteryDesignCapacityText, "电池规格"])
                    TableRow(values: ["循环次数", snapshot.batteryCycleText, "电池健康"])
                    TableRow(values: ["健康", snapshot.batteryHealthText, "电池健康"])
                    TableRow(values: ["电压", snapshot.batteryVoltageText, "电源状态"])
                    TableRow(values: ["电流", snapshot.batteryAmperageText, "电源状态"])
                }
            }
        }
    }
}

private struct GPUDisplayPage: View {
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                SourceCapabilityCard(title: "图形设备", value: snapshot.gpuSummaryText, icon: "sparkles.rectangle.stack", status: snapshot.hasGPUReport ? .normal : .neutral, source: "设备能力")
                SourceCapabilityCard(title: "显示器信息", value: snapshot.displaySummaryText, icon: "display", status: snapshot.hasDisplayReport ? .normal : .neutral, source: "显示配置")
                SourceCapabilityCard(title: "统一内存", value: unifiedMemorySummary, icon: "memorychip", status: hasUnifiedMemorySummary ? .normal : .neutral, source: "GPU 能力")
            }

            DashboardPanel(title: "GPU 与统一内存", subtitle: "Apple Silicon 优先显示可靠能力", icon: "display") {
                VStack(spacing: 12) {
                    TableHeader(columns: ["设备", "类型", "统一内存", "建议工作集", "线程组内存", "线程组", "状态"])
                    ForEach(snapshot.gpuDevices.filter(\.hasInventoryReport)) { device in
                        TableRow(values: [
                            device.name,
                            device.kindText,
                            device.unifiedMemoryText,
                            device.recommendedWorkingSetText,
                            device.threadgroupMemoryText,
                            device.threadgroupSizeText,
                            device.stateText
                        ])
                    }
                }
            }

            DashboardPanel(title: "显示器", subtitle: "连接的显示设备", icon: "rectangle.on.rectangle") {
                VStack(spacing: 0) {
                    TableHeader(columns: ["屏幕", "像素", "模式", "缩放", "色彩", "刷新率", "尺寸", "方向", "状态"])
                    ForEach(snapshot.displays.filter(\.hasInventoryReport)) { display in
                        TableRow(values: [
                            display.name,
                            display.pixelSizeText,
                            display.modeSizeText,
                            display.backingScaleText,
                            display.colorText,
                            display.refreshRateText,
                            display.physicalSizeText,
                            display.rotationText,
                            display.stateText
                        ])
                    }
                }
            }
        }
    }

    private var unifiedMemorySummary: String {
        let reportedDevices = reportedUnifiedMemoryDevices
        guard !reportedDevices.isEmpty else { return "未报告" }
        let unifiedCount = reportedDevices.filter(\.hasUnifiedMemory).count
        return unifiedCount == reportedDevices.count ? "支持" : "\(unifiedCount)/\(reportedDevices.count)"
    }

    private var hasUnifiedMemorySummary: Bool {
        !reportedUnifiedMemoryDevices.isEmpty
    }

    private var reportedUnifiedMemoryDevices: [GPUDeviceMetric] {
        snapshot.gpuDevices.filter(\.hasUnifiedMemoryReport)
    }
}

private struct ProcessesPage: View {
    let snapshot: MetricSnapshot
    let summaryColumns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: summaryColumns, spacing: 12) {
                SummaryCard(title: "运行中 App", value: snapshot.runningAppCountText, icon: "app.badge", tint: DashboardColor.blue)
                SummaryCard(title: "列表项", value: snapshot.runningAppListCountText, icon: "list.bullet.rectangle", tint: DashboardColor.green)
                SummaryCard(title: "前台 App", value: snapshot.activeApplicationCountText, icon: "cursorarrow.click", tint: DashboardColor.amber)
                SummaryCard(title: "隐藏 App", value: snapshot.hiddenApplicationCountText, icon: "eye.slash", tint: DashboardColor.purple)
            }

            DashboardPanel(title: "运行中 App", subtitle: ProcessMetric.listSubtitle(for: snapshot.runningApps, defaultSubtitle: "前台优先 · 按名称排序"), icon: "list.bullet.rectangle") {
                VStack(spacing: 0) {
                    TableHeader(columns: ["名称", "状态", "架构", "启动"])
                    ForEach(snapshot.runningApps.filter(\.hasInventoryReport)) { process in
                        TableRow(values: [
                            process.name,
                            process.stateText,
                            process.architectureText,
                            process.launchText
                        ])
                    }
                }
            }
        }
    }
}

private struct SensorsPage: View {
    @ObservedObject var store: MetricsStore

    private var snapshot: MetricSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                DashboardPanel(title: "热状态", subtitle: "系统温控状态", icon: "thermometer.medium") {
                    VStack(spacing: 14) {
                        RingGauge(title: "热状态", value: snapshot.thermalText, progress: thermalProgress(snapshot.thermalState), tint: thermalStatus(snapshot.thermalState).color)
                            .frame(width: 160, height: 160)
                        StatusSummaryRow(title: "系统状态", value: snapshot.thermalLimitText, status: thermalStatus(snapshot.thermalState))
                    }
                }
                .frame(width: 360)

                DashboardPanel(title: "实时信号", subtitle: "最近一次采样", icon: "waveform.path.ecg.rectangle") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        SourceCapabilityCard(title: "CPU", value: snapshot.cpuText, icon: "cpu", status: usageStatusLevel(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold), source: "阈值 \(MetricFormatting.percentage(store.cpuAlertThreshold))")
                        SourceCapabilityCard(title: "内存", value: snapshot.memoryUsageText, icon: "memorychip", status: usageStatusLevel(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold), source: "阈值 \(MetricFormatting.percentage(store.memoryAlertThreshold))")
                        SourceCapabilityCard(title: "磁盘", value: snapshot.diskUsageText, icon: "internaldrive", status: usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold), source: "阈值 \(MetricFormatting.percentage(store.diskAlertThreshold))")
                        SourceCapabilityCard(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, icon: "battery.75percent", status: powerStatusLevel(snapshot), source: snapshot.powerSourceText)
                        SourceCapabilityCard(title: "网络连接", value: snapshot.networkPathText, icon: "network", status: networkStatusLevel(snapshot), source: snapshot.networkPathDetailText)
                        SourceCapabilityCard(title: "显示器", value: snapshot.displaySummaryText, icon: "display", status: snapshot.hasDisplayReport ? .normal : .neutral, source: snapshot.sampleTimeText)
                        SourceCapabilityCard(title: "GPU", value: snapshot.gpuSummaryText, icon: "sparkles.rectangle.stack", status: snapshot.hasGPUReport ? .normal : .neutral, source: "图形设备")
                        SourceCapabilityCard(title: "存储卷", value: snapshot.storageVolumeSummaryText, icon: "externaldrive", status: snapshot.hasStorageVolumeReport ? .normal : .neutral, source: "文件系统容量")
                        SourceCapabilityCard(title: "负载", value: snapshot.loadDetailText, icon: "speedometer", status: snapshot.hasLoadAverageReport ? .normal : .neutral, source: "1 / 5 / 15 分钟")
                        SourceCapabilityCard(title: "系统版本", value: snapshot.osVersionText, icon: "desktopcomputer", status: snapshot.hasOSVersionReport ? .normal : .neutral, source: "操作系统版本")
                        SourceCapabilityCard(title: "运行时间", value: snapshot.uptimeText, icon: "timer", status: snapshot.hasUptimeReport ? .normal : .neutral, source: "系统启动时间")
                    }
                }
            }

            DashboardPanel(title: "状态判断", subtitle: "当前采样的本地结果", icon: "checkmark.shield") {
                VStack(spacing: 0) {
                    TableHeader(columns: ["规则", "阈值", "当前", "状态"])
                    TableRow(values: ["CPU", MetricFormatting.percentage(store.cpuAlertThreshold), snapshot.cpuText, thresholdStatusText(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold, warningText: "注意")])
                    TableRow(values: ["内存", MetricFormatting.percentage(store.memoryAlertThreshold), snapshot.memoryUsageText, thresholdStatusText(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold, warningText: "注意")])
                    TableRow(values: ["磁盘", MetricFormatting.percentage(store.diskAlertThreshold), snapshot.diskUsageText, thresholdStatusText(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold, warningText: "注意")])
                    TableRow(values: ["网络连接", "在线", snapshot.networkPathText, snapshot.networkRuleStatusText])
                }
            }

            DashboardPanel(title: "系统信号", subtitle: "当前显示的数据项", icon: "list.clipboard") {
                VStack(spacing: 0) {
                    TableHeader(columns: ["名称", "当前值", "来源"])
                    TableRow(values: ["系统热状态", snapshot.thermalText, "温控状态"])
                    TableRow(values: ["系统版本", snapshot.osVersionText, "操作系统版本"])
                    TableRow(values: ["运行时间", snapshot.uptimeText, "系统启动时间"])
                    TableRow(values: ["内核版本", snapshot.kernelText, "系统版本"])
                    TableRow(values: ["负载 1/5/15", snapshot.loadDetailText, "系统负载平均值"])
                    TableRow(values: [snapshot.powerStatusTitle, snapshot.powerStatusText, snapshot.powerSourceText])
                    TableRow(values: ["网络连接", snapshot.networkPathText, snapshot.networkPathDetailText])
                    TableRow(values: ["显示器", snapshot.displaySummaryText, "显示配置"])
                    TableRow(values: ["GPU", snapshot.gpuSummaryText, "图形设备"])
                    TableRow(values: ["存储卷", snapshot.storageVolumeSummaryText, "文件系统容量"])
                }
            }
        }
    }
}

private struct HistoryAlertsPage: View {
    @ObservedObject var store: MetricsStore
    let history: [MetricSnapshot]

    private var snapshot: MetricSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardPanel(title: "历史趋势", subtitle: reportedHistorySampleCountText(from: history), icon: "chart.xyaxis.line") {
                VStack(spacing: 16) {
                    Sparkline(values: cpuTrendValues(from: history), tint: DashboardColor.green, fill: true)
                        .frame(height: 92)
                    TrendRow(title: "CPU", value: snapshot.cpuText, tint: DashboardColor.green, values: cpuTrendValues(from: history))
                    TrendRow(title: "负载", value: snapshot.loadText, tint: DashboardColor.purple, values: loadTrendValues(from: history))
                    TrendRow(title: "内存", value: snapshot.memoryUsageText, tint: DashboardColor.blue, values: memoryTrendValues(from: history))
                    TrendRow(title: "网络", value: snapshot.networkText, tint: DashboardColor.cyan, values: networkTrendValues(from: history, keyPath: \.networkBytesPerSecond, baseline: 40_000_000))
                    TrendRow(title: "磁盘", value: snapshot.diskUsageText, tint: DashboardColor.amber, values: diskTrendValues(from: history))
                    TrendRow(title: "热状态", value: snapshot.thermalText, tint: thermalStatus(snapshot.thermalState).color, values: thermalTrendValues(from: history))
                    TrendRow(title: "运行时间", value: snapshot.uptimeText, tint: DashboardColor.green, values: uptimeTrendValues(from: history))
                    TrendRow(title: powerTrendTitle(snapshot), value: snapshot.powerStatusText, tint: powerTint(snapshot), values: powerTrendValues(from: history))
                }
            }

            DashboardPanel(title: "阈值设置", subtitle: "本地判断规则", icon: "slider.horizontal.3") {
                VStack(spacing: 12) {
                    ThresholdControlRow(title: "CPU", value: store.cpuAlertThreshold, update: store.updateCPUAlertThreshold, tint: DashboardColor.green)
                    ThresholdControlRow(title: "内存", value: store.memoryAlertThreshold, update: store.updateMemoryAlertThreshold, tint: DashboardColor.blue)
                    ThresholdControlRow(title: "磁盘", value: store.diskAlertThreshold, update: store.updateDiskAlertThreshold, tint: DashboardColor.amber)
                }
            }

            DashboardPanel(title: "状态判断", subtitle: "当前采样的本地结果", icon: "checkmark.shield") {
                VStack(spacing: 0) {
                    TableHeader(columns: ["规则", "阈值", "当前", "状态"])
                    TableRow(values: ["CPU 超过", MetricFormatting.percentage(store.cpuAlertThreshold), snapshot.cpuText, thresholdStatusText(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold, warningText: "触发")])
                    TableRow(values: ["内存使用高", MetricFormatting.percentage(store.memoryAlertThreshold), snapshot.memoryUsageText, thresholdStatusText(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold, warningText: "触发")])
                    TableRow(values: ["磁盘使用高", MetricFormatting.percentage(store.diskAlertThreshold), snapshot.diskUsageText, thresholdStatusText(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold, warningText: "触发")])
                    TableRow(values: ["网络连接", "在线", snapshot.networkPathText, snapshot.networkRuleStatusText])
                }
            }
        }
    }
}

private struct SettingsPage: View {
    @ObservedObject var store: MetricsStore
    let isCompact: Bool

    private var snapshot: MetricSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    refreshDisplayPanel
                    widgetPreviewPanel
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    refreshDisplayPanel
                    widgetPreviewPanel
                        .frame(width: 360)
                }
            }

            DashboardPanel(title: "支持与隐私", subtitle: "审核信息与公开入口", icon: "hand.raised") {
                VStack(spacing: 12) {
                    SettingsLinkRow(title: "隐私政策", detail: "本地采样、无账号、无追踪") {
                        PulseDockLinks.openPrivacyPolicy()
                    }
                    SettingsLinkRow(title: "支持", detail: "联系渠道与版本支持信息") {
                        PulseDockLinks.openSupport()
                    }
                }
            }

            DashboardPanel(title: "数据来源", subtitle: "当前页面使用的系统信号", icon: "checklist") {
                VStack(spacing: 0) {
                    TableHeader(columns: ["功能", "状态", "来源"])
                    TableRow(values: ["CPU / 内存", snapshot.cpuMemorySourceStatusText, "系统处理器与内存统计"])
                    TableRow(values: ["负载", snapshot.loadAverageSourceStatusText, "系统负载平均值"])
                    TableRow(values: ["网络连接", snapshot.networkSourceStatusText, "连接状态与接口流量"])
                    TableRow(values: ["运行中 App", snapshot.runningAppsSourceStatusText, "应用会话列表"])
                    TableRow(values: ["GPU / 显示器", snapshot.gpuDisplaySourceStatusText, "图形设备与显示配置"])
                    TableRow(values: ["卷容量", snapshot.storageSourceStatusText, "文件系统容量"])
                    TableRow(values: ["电源 / 热状态", snapshot.powerThermalSourceStatusText, "电源与温控状态"])
                    TableRow(values: ["系统版本 / 运行时间 / 内核版本", snapshot.systemVersionSourceStatusText, "系统版本与启动时间"])
                }
            }
        }
    }

    private var refreshDisplayPanel: some View {
        DashboardPanel(title: "刷新与显示", subtitle: "低唤醒、可读性优先", icon: "slider.horizontal.3") {
            VStack(spacing: 14) {
                SettingControlRow(title: "主窗口刷新", detail: "实时趋势与状态卡片") {
                    Picker("主窗口刷新", selection: Binding(
                        get: { store.refreshInterval },
                        set: { store.updateRefreshInterval($0) }
                    )) {
                        ForEach(RefreshIntervalOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 164)
                }
                SettingControlRow(title: "菜单栏状态", detail: "显示当前 CPU 占用") {
                    Toggle("菜单栏 CPU", isOn: Binding(
                        get: { store.showsMenuBarCPU },
                        set: { store.updateShowsMenuBarCPU($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                SettingReadOnlyRow(title: "小组件刷新", detail: "由系统按时间线调度", control: "5m")
                SettingControlRow(title: "本地历史", detail: "保留最近 \(store.historyDepth.sampleCount) 次采样") {
                    Picker("本地历史", selection: Binding(
                        get: { store.historyDepth },
                        set: { store.updateHistoryDepth($0) }
                    )) {
                        ForEach(HistoryDepthOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 214)
                }
            }
        }
    }

    private var widgetPreviewPanel: some View {
        DashboardPanel(title: "小组件", subtitle: "桌面状态预览", icon: "rectangle.grid.2x2") {
            VStack(spacing: 12) {
                WidgetMiniPreview(snapshot: snapshot)
                KeyValueGrid(items: [
                    ("尺寸", "小 / 中 / 大"),
                    ("数据源", "系统采样"),
                    ("刷新", "系统调度"),
                    ("采样", snapshot.sampleTimeText),
                    ("历史", store.historyDurationText),
                    ("主窗口", store.refreshInterval.label)
                ])
            }
        }
    }
}

private struct DashboardPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardColor.blue)
                    .frame(width: 26, height: 26)
                    .background(DashboardColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DashboardColor.muted)
                }

                Spacer()
            }

            content
        }
        .padding(16)
        .panel(cornerRadius: 8)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color
    let badgeText: String?
    let progress: Double?
    let values: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
                if let badgeText = badgeText {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(tint)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
                Text(value)
                    .font(.system(size: 29, weight: .semibold, design: .default).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            StatProgress(progress: progress, tint: tint)
            Sparkline(values: values, tint: tint)
                .frame(height: 34)
        }
        .padding(15)
        .frame(minHeight: 184, alignment: .topLeading)
        .panel(cornerRadius: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? "未报告")
        .accessibilityHint(detail)
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
                Text(value)
                    .font(.system(size: 24, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer()
        }
        .padding(15)
        .panel(cornerRadius: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

private struct ProcessListPanel: View {
    let processes: [ProcessMetric]
    var title: String = "运行中 App"
    var subtitle: String = "前台优先 · 按名称排序"

    var body: some View {
        DashboardPanel(title: title, subtitle: ProcessMetric.listSubtitle(for: processes, defaultSubtitle: subtitle), icon: "list.bullet.rectangle") {
            VStack(spacing: 0) {
                TableHeader(columns: ["名称", "状态", "架构", "启动"])
                ForEach(processes.filter(\.hasInventoryReport).prefix(6)) { process in
                    TableRow(values: [
                        process.name,
                        process.stateText,
                        process.architectureText,
                        process.launchText
                    ])
                }
            }
        }
    }
}

private struct WidgetPreviewPanel: View {
    let snapshot: MetricSnapshot

    var body: some View {
        DashboardPanel(title: "桌面小组件", subtitle: "核心状态预览", icon: "rectangle.grid.2x2") {
            HStack(alignment: .top, spacing: 12) {
                WidgetMiniPreview(snapshot: snapshot)
                VStack(alignment: .leading, spacing: 10) {
                    DataChip(icon: "square.stack.3d.up", text: "小 / 中 / 大")
                    DataChip(icon: "waveform.path.ecg", text: "系统采样")
                    DataChip(icon: "timer", text: "系统刷新")
                    Text("小组件按系统时间线刷新核心状态，适合快速查看本机运行情况。")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DashboardColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct WidgetMiniPreview: View {
    let snapshot: MetricSnapshot
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pulse Dock")
                    .font(.system(size: 14, weight: .semibold))
                StatusDot(color: DashboardColor.green)
                Spacer()
                Text(snapshot.sampleClockText)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(widgetPreviewSecondaryText(for: colorScheme))
            }

            HStack(spacing: 12) {
                RingGauge(title: "CPU", value: snapshot.cpuText, progress: reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: DashboardColor.green)
                RingGauge(title: "MEM", value: snapshot.memoryUsageText, progress: reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: DashboardColor.blue)
            }
        }
        .padding(14)
        .frame(width: 160, height: 150)
        .background {
            LinearGradient(
                colors: widgetPreviewBackgroundColors(for: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(widgetPreviewStroke(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: widgetPreviewShadow(for: colorScheme), radius: 18, x: 0, y: 10)
    }
}

private func widgetPreviewBackgroundColors(for colorScheme: ColorScheme) -> [Color] {
    if colorScheme == .dark {
        return [
            Color(nsColor: .controlBackgroundColor).opacity(0.92),
            Color(red: 0.08, green: 0.12, blue: 0.14).opacity(0.84)
        ]
    }

    return [
        Color(nsColor: .textBackgroundColor).opacity(0.92),
        Color(red: 0.91, green: 0.95, blue: 0.96).opacity(0.82)
    ]
}

private func widgetPreviewStroke(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
        ? Color(nsColor: .separatorColor).opacity(0.60)
        : Color(nsColor: .textBackgroundColor).opacity(0.72)
}

private func widgetPreviewShadow(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
        ? Color.black.opacity(0.28)
        : Color.black.opacity(0.10)
}

private func widgetPreviewSecondaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
        ? Color.white.opacity(0.68)
        : Color.secondary.opacity(0.82)
}

private struct RingGauge: View {
    let title: String
    let value: String
    let progress: Double?
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.14), lineWidth: 8)
            if let progress {
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? "未报告")
    }
}

private struct TrendRow: View {
    let title: String
    let value: String
    let tint: Color
    let values: [Double]

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
                Text(value)
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
            }
            .frame(width: 96, alignment: .leading)

            Sparkline(values: values, tint: tint, fill: true)
                .frame(height: 46)
        }
    }
}

private struct Sparkline: View {
    let values: [Double]
    let tint: Color
    var fill = false

    var body: some View {
        Canvas { context, size in
            let normalized = preparedValues
            guard normalized.count > 1 else { return }

            var line = Path()
            var fillPath = Path()

            for index in normalized.indices {
                let x = size.width * CGFloat(index) / CGFloat(normalized.count - 1)
                let y = size.height * (1 - CGFloat(min(max(normalized[index], 0), 1)))
                let point = CGPoint(x: x, y: y)

                if index == normalized.startIndex {
                    line.move(to: point)
                    fillPath.move(to: CGPoint(x: x, y: size.height))
                    fillPath.addLine(to: point)
                } else {
                    line.addLine(to: point)
                    fillPath.addLine(to: point)
                }
            }

            if fill {
                fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                fillPath.closeSubpath()
                context.fill(fillPath, with: .linearGradient(
                    Gradient(colors: [tint.opacity(0.22), tint.opacity(0.02)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
            }

            context.stroke(line, with: .color(tint), lineWidth: 2)
        }
        .background(tint.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("趋势图")
        .accessibilityValue(sparklineAccessibilityValue)
    }

    private var preparedValues: [Double] {
        if values.count > 1 {
            return values.suffix(80)
        }

        if let value = values.first {
            return [value, value]
        }

        return []
    }

    private var sparklineAccessibilityValue: String {
        guard let lastValue = preparedValues.last else { return "未报告" }
        return MetricFormatting.percentage(lastValue)
    }
}

private struct CompactMetricLine: View {
    let title: String
    let value: String
    let progress: Double?
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            StatProgress(progress: progress, tint: tint)
        }
    }
}

private struct StatProgress: View {
    let progress: Double?
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                if let progress {
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: progressFillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 6))
                }
            }
        }
        .frame(height: 6)
    }
}

private struct StatLine: View {
    let label: String
    let value: String
    let progress: Double?
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
            StatProgress(progress: progress, tint: tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? "未报告")
    }
}

private struct CoreUsageTile: View {
    let index: Int
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Core \(index)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(MetricFormatting.percentage(value))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tint)
            }

            StatProgress(progress: value, tint: tint)
        }
        .padding(12)
        .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(DashboardColor.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Core \(index), \(MetricFormatting.percentage(value))")
    }
}

private struct MemorySegmentBar: View {
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if snapshot.hasMemoryUsageReport && snapshot.hasMemoryCompositionReport {
                GeometryReader { proxy in
                    let availableWidth = max(proxy.size.width - 4, 0)
                    HStack(spacing: 2) {
                        segment(snapshot.memoryUsedBytes, color: DashboardColor.blue, in: availableWidth)
                        segment(snapshot.memoryCachedBytes, color: DashboardColor.cyan, in: availableWidth)
                        segment(snapshot.memoryFreeBytes, color: Color.secondary.opacity(0.20), in: availableWidth)
                    }
                }
                .frame(height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 16)
            }

            HStack(spacing: 10) {
                LegendDot(title: "已用", color: DashboardColor.blue)
                LegendDot(title: "缓存", color: DashboardColor.cyan)
                LegendDot(title: "空闲", color: Color.secondary.opacity(0.38))
            }
        }
    }

    private func segment(_ bytes: UInt64, color: Color, in totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: segmentWidth(bytes, in: totalWidth))
    }

    private func segmentWidth(_ bytes: UInt64, in totalWidth: CGFloat) -> CGFloat {
        let width = CGFloat(normalizedBytes(bytes, total: snapshot.memoryTotalBytes)) * totalWidth
        return max(width, 8)
    }
}

private struct CapacitySegment {
    let title: String
    let value: Double
    let color: Color
}

private struct CapacityBar: View {
    let segments: [CapacitySegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                    if !segments.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                                Rectangle()
                                    .fill(segment.color)
                                    .frame(width: max(8, proxy.size.width * CGFloat(max(segment.value, 0))))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            .frame(height: 20)

            HStack(spacing: 12) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    LegendDot(title: segment.title, color: segment.color)
                }
            }
        }
    }
}

private struct LegendDot: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DashboardColor.muted)
        }
    }
}

private enum StatusLevel {
    case normal
    case warning
    case critical
    case neutral

    var color: Color {
        switch self {
        case .normal: DashboardColor.green
        case .warning: DashboardColor.amber
        case .critical: DashboardColor.red
        case .neutral: DashboardColor.blue
        }
    }

    var text: String {
        switch self {
        case .normal: "正常"
        case .warning: "注意"
        case .critical: "严重"
        case .neutral: "未报告"
        }
    }
}

private struct StatusSummaryRow: View {
    let title: String
    let value: String
    let status: StatusLevel

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(color: status.color)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardColor.muted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
            Text(status.text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(status.color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(status.color.opacity(0.11), in: Capsule())
        }
        .padding(10)
        .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(status.text)")
    }
}

private struct SourceCapabilityCard: View {
    let title: String
    let value: String
    let icon: String
    let status: StatusLevel
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(status.color)
                    .accessibilityHidden(true)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(status.color.opacity(0.12), in: Capsule())
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(source)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DashboardColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .panel(cornerRadius: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(source)")
    }
}

private struct KeyValueGrid: View {
    let items: [(String, String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DashboardColor.muted)
                    Text(item.1)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct DataChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.62), in: Capsule())
    }
}

private struct SettingRow: View {
    let title: String
    let detail: String
    let control: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
            }
            Spacer()
            Text(control)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.72), in: Capsule())
        }
        .padding(12)
        .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SettingReadOnlyRow: View {
    let title: String
    let detail: String
    let control: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
            }
            Spacer()
            Text(control)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardColor.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.40), in: Capsule())
        }
        .padding(12)
        .background(DashboardColor.panelAlt.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(0.78)
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
            }
            Spacer()
            Button(action: action) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("打开\(title)")
            .accessibilityLabel("打开\(title)")
        }
        .padding(12)
        .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SettingControlRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardColor.muted)
            }
            Spacer()
            control
        }
        .padding(12)
        .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ThresholdControlRow: View {
    let title: String
    let value: Double
    let update: (Double) -> Void
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 56, alignment: .leading)
            Slider(value: Binding(
                get: { value },
                set: { update($0) }
            ), in: 0.5...0.98, step: 0.01)
                .tint(tint)
            Text(MetricFormatting.percentage(value))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(12)
        .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TableHeader: View {
    let columns: [String]

    var body: some View {
        HStack {
            ForEach(columns, id: \.self) { column in
                Text(column)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DashboardColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct TableRow: View {
    let values: [String]

    var body: some View {
        HStack {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .font(.system(size: 12, weight: index == 0 ? .semibold : .medium).monospacedDigit())
                    .foregroundStyle(index == 0 ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .overlay(alignment: .bottom) {
            Divider().overlay(DashboardColor.border.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(values.joined(separator: ", "))
    }
}

private struct TableEmptyRow: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardColor.muted)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .overlay(alignment: .bottom) {
            Divider().overlay(DashboardColor.border.opacity(0.7))
        }
    }
}

private struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.32), radius: 4)
            .accessibilityHidden(true)
    }
}

private extension View {
    func panel(cornerRadius: CGFloat) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DashboardColor.panel)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DashboardColor.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 16, x: 0, y: 8)
    }
}

private func normalizedRate(_ bytesPerSecond: UInt64, baseline: UInt64) -> Double {
    guard baseline > 0 else { return 0 }
    return min(Double(bytesPerSecond) / Double(baseline), 1)
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

private func reportedHistorySampleCountText(from history: [MetricSnapshot]) -> String {
    let reportedSampleCount = history.filter(\.hasSampleTimeReport).count
    guard reportedSampleCount > 0 else { return "未报告" }
    return "最近 \(reportedSampleCount) 次采样"
}

private func reportedHistorySampleChipText(from history: [MetricSnapshot]) -> String {
    let reportedSampleCount = history.filter(\.hasSampleTimeReport).count
    guard reportedSampleCount > 0 else { return "未报告" }
    return "最近 \(reportedSampleCount) 次"
}

private func cpuTrendValues(from history: [MetricSnapshot]) -> [Double] {
    history.filter(\.hasCPUUsageReport).map(\.cpuUsage)
}

private func loadTrendValues(from history: [MetricSnapshot]) -> [Double] {
    history.filter { $0.hasLoadAverageReport && $0.activeProcessorCount > 0 }.map { min($0.loadAverage / Double($0.activeProcessorCount), 1) }
}

private func memoryTrendValues(from history: [MetricSnapshot]) -> [Double] {
    history.filter(\.hasMemoryUsageReport).map(\.memoryUsage)
}

private func diskTrendValues(from history: [MetricSnapshot]) -> [Double] {
    history.filter(\.hasDiskUsageReport).map(\.diskUsage)
}

private func networkTrendValues(from history: [MetricSnapshot], keyPath: KeyPath<MetricSnapshot, UInt64>, baseline: UInt64) -> [Double] {
    history.filter(\.hasNetworkByteCounters).map { normalizedRate($0[keyPath: keyPath], baseline: baseline) }
}

private func networkPathTrendValues(from history: [MetricSnapshot]) -> [Double] {
    history.filter(\.hasNetworkPathReport).map(networkPathProgress)
}

private func thermalTrendValues(from history: [MetricSnapshot]) -> [Double] {
    history.filter(\.hasThermalStateReport).compactMap { thermalProgress($0.thermalState) }
}

private func uptimeTrendValues(from history: [MetricSnapshot]) -> [Double] {
    let reportedUptime = history.filter(\.hasUptimeReport).map(\.uptimeSeconds)
    guard let maxUptime = reportedUptime.max(), maxUptime > 0 else { return [] }
    return reportedUptime.map { min($0 / maxUptime, 1) }
}

private func powerTrendValues(from history: [MetricSnapshot]) -> [Double] {
    history.compactMap(\.powerStatusProgress)
}

private func normalizedBytes(_ bytes: UInt64, total: UInt64) -> Double {
    guard total > 0 else { return 0 }
    return min(Double(bytes) / Double(total), 1)
}

private func diskCapacitySegments(_ snapshot: MetricSnapshot) -> [CapacitySegment] {
    guard snapshot.hasDiskUsageReport else { return [] }
    return [
        CapacitySegment(title: "已用", value: snapshot.diskUsage, color: DashboardColor.amber),
        CapacitySegment(title: "空闲", value: max(1 - snapshot.diskUsage, 0), color: Color.secondary.opacity(0.24))
    ]
}

private func networkStatusLevel(_ snapshot: MetricSnapshot) -> StatusLevel {
    switch snapshot.networkPathStatus.lowercased() {
    case "satisfied":
        .normal
    case "unsatisfied":
        .critical
    case "requiresconnection", "requires_connection", "requires connection":
        .warning
    default:
        .neutral
    }
}

private func networkStatusColor(_ snapshot: MetricSnapshot) -> Color {
    networkStatusLevel(snapshot).color
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

private func activeInterfaceProgress(_ snapshot: MetricSnapshot) -> Double {
    let reportedInterfaces = snapshot.networkInterfaces.filter(\.hasInterfaceStateReport)
    guard !reportedInterfaces.isEmpty else { return 0 }
    let activeCount = reportedInterfaces.filter { $0.isUp && !$0.isLoopback }.count
    return min(Double(activeCount) / Double(reportedInterfaces.count), 1)
}

private func powerGaugeProgress(_ snapshot: MetricSnapshot) -> Double? {
    snapshot.powerStatusProgress
}

private func powerTint(_ snapshot: MetricSnapshot) -> Color {
    switch snapshot.powerStatusTone {
    case .normal:
        return DashboardColor.green
    case .warning:
        return DashboardColor.amber
    case .critical:
        return DashboardColor.red
    case .neutral:
        return DashboardColor.cyan
    }
}

private func powerStatusLevel(_ snapshot: MetricSnapshot) -> StatusLevel {
    switch snapshot.powerStatusTone {
    case .normal:
        return .normal
    case .warning:
        return .warning
    case .critical:
        return .critical
    case .neutral:
        return .neutral
    }
}

private func powerTrendTitle(_ snapshot: MetricSnapshot) -> String {
    snapshot.batteryPercent == nil ? "供电状态" : "电量历史"
}

private func volumeLabel(_ volume: StorageVolumeMetric) -> String {
    if volume.isPrimary { return "主卷" }
    return "卷 \(volume.index + 1)"
}

private func usageStatusLevel(hasReport: Bool, usage: Double, threshold: Double) -> StatusLevel {
    guard hasReport else { return .neutral }
    return usage > threshold ? .warning : .normal
}

private func thresholdStatusText(hasReport: Bool, usage: Double, threshold: Double, warningText: String) -> String {
    guard hasReport else { return "未报告" }
    return usage > threshold ? warningText : "正常"
}

private func thermalStatus(_ state: String) -> StatusLevel {
    switch state.lowercased() {
    case "critical": .critical
    case "hot", "serious", "warm", "fair": .warning
    case "nominal": .normal
    case "unknown": .neutral
    default: .neutral
    }
}

private func thermalProgress(_ state: String) -> Double? {
    switch state.lowercased() {
    case "critical": 1
    case "hot", "serious": 0.78
    case "warm", "fair": 0.52
    case "nominal": 0.24
    case "unknown": nil
    default: nil
    }
}
