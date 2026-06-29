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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        let isCompact = proxy.size.width < DashboardLayout.compactBreakpoint
                        pageContent(
                            metricColumns: adaptiveMetricColumns(for: proxy.size.width),
                            summaryColumns: adaptiveSummaryColumns(for: proxy.size.width),
                            capabilityColumns: adaptiveCapabilityColumns(for: proxy.size.width),
                            isCompact: isCompact
                        )
                        .id(router.selectedPage)
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .trailing)))
                        .animation(DashboardMotion.page(reduceMotion: reduceMotion), value: router.selectedPage)
                        .padding(.horizontal, DashboardLayout.contentHorizontalPadding)
                        .padding(.top, DashboardLayout.contentTopPadding)
                        .padding(.bottom, DashboardLayout.contentBottomPadding)
                    }
                    .background(DashboardColor.canvas)
                }
            }
        }
        .frame(
            minWidth: DashboardLayout.minimumContentSize.width,
            idealWidth: DashboardLayout.idealContentSize.width,
            minHeight: DashboardLayout.minimumContentSize.height,
            idealHeight: DashboardLayout.idealContentSize.height
        )
        .background(WindowBackdrop())
    }

    @ViewBuilder
    private func pageContent(metricColumns: [GridItem], summaryColumns: [GridItem], capabilityColumns: [GridItem], isCompact: Bool) -> some View {
        let snapshot = store.snapshot
        let history = store.recentSnapshots

        switch router.selectedPage {
        case .overview:
            OverviewPage(store: store, history: history, metricColumns: metricColumns, isCompact: isCompact)
        case .cpu:
            CPUPage(snapshot: snapshot, history: history, isCompact: isCompact)
        case .gpu:
            GPUDisplayPage(snapshot: snapshot, capabilityColumns: capabilityColumns)
        case .memory:
            MemoryPage(snapshot: snapshot, history: history, isCompact: isCompact)
        case .storage:
            StoragePage(store: store, history: history, capabilityColumns: capabilityColumns)
        case .network:
            NetworkPage(snapshot: snapshot, history: history, metricColumns: metricColumns)
        case .power:
            PowerPage(snapshot: snapshot, history: history, isCompact: isCompact)
        case .processes:
            ProcessesPage(snapshot: snapshot, summaryColumns: summaryColumns)
        case .sensors:
            SensorsPage(store: store, isCompact: isCompact, capabilityColumns: capabilityColumns)
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
        case .overview: PulseDockAppStrings.dashboardPageOverviewTitle
        case .cpu: PulseDockAppStrings.dashboardPageCPUTitle
        case .gpu: PulseDockAppStrings.dashboardPageGPUTitle
        case .memory: PulseDockAppStrings.dashboardPageMemoryTitle
        case .storage: PulseDockAppStrings.dashboardPageStorageTitle
        case .network: PulseDockAppStrings.dashboardPageNetworkTitle
        case .power: PulseDockAppStrings.dashboardPagePowerTitle
        case .processes: PulseDockAppStrings.dashboardPageProcessesTitle
        case .sensors: PulseDockAppStrings.dashboardPageSensorsTitle
        case .history: PulseDockAppStrings.dashboardPageHistoryTitle
        case .settings: PulseDockAppStrings.dashboardPageSettingsTitle
        }
    }

    var subtitle: String {
        switch self {
        case .overview: PulseDockAppStrings.dashboardPageOverviewSubtitle
        case .cpu: PulseDockAppStrings.dashboardPageCPUSubtitle
        case .gpu: PulseDockAppStrings.dashboardPageGPUSubtitle
        case .memory: PulseDockAppStrings.dashboardPageMemorySubtitle
        case .storage: PulseDockAppStrings.dashboardPageStorageSubtitle
        case .network: PulseDockAppStrings.dashboardPageNetworkSubtitle
        case .power: PulseDockAppStrings.dashboardPagePowerSubtitle
        case .processes: PulseDockAppStrings.dashboardPageProcessesSubtitle
        case .sensors: PulseDockAppStrings.dashboardPageSensorsSubtitle
        case .history: PulseDockAppStrings.dashboardPageHistorySubtitle
        case .settings: PulseDockAppStrings.dashboardPageSettingsSubtitle
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
            Color(red: 0.07, green: 0.11, blue: 0.12).opacity(0.54),
            Color(red: 0.06, green: 0.09, blue: 0.11).opacity(0.34)
        ]
    }

    return [
        Color(nsColor: .windowBackgroundColor).opacity(0.96),
        Color(red: 0.92, green: 0.95, blue: 0.94).opacity(0.48),
        Color(red: 0.96, green: 0.94, blue: 0.90).opacity(0.34)
    ]
}

private func adaptiveMetricColumns(for width: CGFloat) -> [GridItem] {
    let count = width < DashboardLayout.compactBreakpoint ? 2 : 4
    return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
}

private func adaptiveSummaryColumns(for width: CGFloat) -> [GridItem] {
    let count = width < DashboardLayout.compactBreakpoint ? 2 : 4
    return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
}

private func adaptiveCapabilityColumns(for width: CGFloat) -> [GridItem] {
    let minimum = width < DashboardLayout.compactBreakpoint ? CGFloat(170) : CGFloat(190)
    return [GridItem(.adaptive(minimum: minimum), spacing: 12)]
}

private func adaptiveCoreColumns() -> [GridItem] {
    [GridItem(.adaptive(minimum: 118), spacing: 10)]
}

private let sparklineVisibleSampleLimit = 80

@ViewBuilder
private func ResponsivePanelPair<Primary: View, Secondary: View>(
    isCompact: Bool,
    secondaryWidth: CGFloat = DashboardLayout.regularAsideWidth,
    @ViewBuilder primary: () -> Primary,
    @ViewBuilder secondary: () -> Secondary
) -> some View {
    if isCompact {
        VStack(alignment: .leading, spacing: DashboardLayout.compactPanelSpacing) {
            primary()
            secondary()
        }
    } else {
        HStack(alignment: .top, spacing: DashboardLayout.compactPanelSpacing) {
            primary()
            secondary()
                .frame(width: secondaryWidth)
        }
    }
}

private struct DashboardSidebar: View {
    @Binding var selection: DashboardPage
    let snapshot: MetricSnapshot

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: DashboardSpacing.sm) {
                        HStack(spacing: DashboardSpacing.sm) {
                            Image(systemName: "waveform.path.ecg.rectangle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(DashboardColor.green)
                            Text("Pulse Dock")
                                .font(DashboardTypography.appTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        Text(PulseDockAppStrings.dashboardSidebarLocalStatus)
                            .font(DashboardTypography.caption)
                            .foregroundStyle(DashboardColor.muted)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 22)

                    VStack(spacing: DashboardSpacing.xs) {
                        ForEach(DashboardPage.allCases) { page in
                            SidebarRow(page: page, isSelected: page == selection) {
                                selection = page
                            }
                        }
                    }
                    .padding(.horizontal, 10)

                    Spacer(minLength: 16)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        .frame(width: DashboardLayout.sidebarWidth)
        .background {
            ZStack {
                VisualEffectView(material: .sidebar)
                DashboardColor.sidebar
            }
        }
    }
}

private struct SidebarRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    .font(DashboardTypography.body.weight(isSelected ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary.opacity(0.58))
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(DashboardColor.blue)
                        .frame(width: 3, height: 18)
                        .offset(x: -2)
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(DashboardMotion.selection(reduceMotion: reduceMotion), value: isSelected)
    }
}

private struct DashboardTopBar: View {
    let page: DashboardPage
    let snapshot: MetricSnapshot
    let refreshInterval: RefreshIntervalOption

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularContent
            compactContent
        }
        .padding(.horizontal, DashboardLayout.contentHorizontalPadding)
        .padding(.vertical, 12)
        .frame(minHeight: 82)
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

    private var regularContent: some View {
        HStack(spacing: 18) {
            titleBlock

            Spacer()

            chips
        }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: DashboardSpacing.sm) {
            titleBlock
            chips
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DashboardSpacing.xs) {
            Text(page.subtitle)
                .font(DashboardTypography.pageTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(PulseDockAppStrings.dashboardTopBarTagline)
                .font(DashboardTypography.body)
                .foregroundStyle(DashboardColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            DataChip(icon: "desktopcomputer", text: PulseDockAppStrings.dashboardTopBarLocalMachine)
            DataChip(icon: "clock", text: PulseDockAppStrings.dashboardSampleChip(snapshot.sampleTimeText))
            DataChip(icon: "arrow.clockwise", text: refreshInterval.label)
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
        let cpuTrend = cpuTrendValues(from: history)
        let memoryTrend = memoryTrendValues(from: history)
        let networkTrend = networkTrendValues(from: history)
        let powerTrend = powerTrendValues(from: history)

        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: metricColumns, spacing: 12) {
                MetricCard(title: PulseDockAppStrings.overviewCPUUsageTitle, value: snapshot.cpuText, detail: snapshot.logicalCoreSummaryText, icon: "cpu", tint: DashboardColor.green, badgeText: snapshot.cpuText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), values: cpuTrend)
                MetricCard(title: PulseDockAppStrings.overviewMemoryUsageTitle, value: snapshot.memoryUsageText, detail: snapshot.memoryText, icon: "memorychip", tint: DashboardColor.blue, badgeText: snapshot.memoryUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), values: memoryTrend)
                MetricCard(title: PulseDockAppStrings.overviewNetworkThroughputTitle, value: snapshot.networkText, detail: "\(snapshot.networkPathText) · ↓ \(snapshot.networkInText)  ↑ \(snapshot.networkOutText)", icon: "arrow.up.arrow.down", tint: DashboardColor.cyan, badgeText: nil, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkBytesPerSecond)), values: networkTrend)
                MetricCard(title: PulseDockAppStrings.overviewPowerStatusTitle, value: snapshot.powerStatusText, detail: snapshot.powerSourceText, icon: "battery.75percent", tint: powerTint(snapshot), badgeText: snapshot.batteryPercent.map { MetricFormatting.percentage($0) }, progress: powerGaugeProgress(snapshot), values: powerTrend)
            }

            overviewStatusPanel

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

    private var overviewStatusPanel: some View {
        DashboardPanel(title: PulseDockAppStrings.overviewSystemStatusTitle, subtitle: snapshot.osVersionText, icon: "checkmark.seal") {
            VStack(spacing: 10) {
                StatusSummaryRow(title: PulseDockAppStrings.statusThermalTitle, value: snapshot.thermalText, status: thermalStatus(snapshot.thermalState))
                StatusSummaryRow(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, status: snapshot.hasUptimeReport ? .normal : .neutral)
                StatusSummaryRow(title: PulseDockAppStrings.metricKernelVersion, value: snapshot.kernelText, status: snapshot.hasKernelReleaseReport ? .normal : .neutral)
                StatusSummaryRow(title: PulseDockAppStrings.overviewCPUStatusTitle, value: "\(snapshot.cpuText) / \(MetricFormatting.percentage(store.cpuAlertThreshold))", status: usageStatusLevel(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold))
                StatusSummaryRow(title: PulseDockAppStrings.overviewMemoryStatusTitle, value: "\(snapshot.memoryUsageText) / \(MetricFormatting.percentage(store.memoryAlertThreshold))", status: usageStatusLevel(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold))
                StatusSummaryRow(title: "\(PulseDockAppStrings.metricLoad) 1/5/15", value: snapshot.loadDetailText, status: snapshot.hasLoadAverageReport ? .normal : .neutral)
                StatusSummaryRow(title: PulseDockAppStrings.metricRunningApps, value: snapshot.runningAppSummaryText, status: snapshot.hasRunningAppReport ? .normal : .neutral)
                StatusSummaryRow(title: PulseDockAppStrings.metricNetworkConnection, value: snapshot.networkPathText, status: networkStatusLevel(snapshot))
                StatusSummaryRow(title: PulseDockAppStrings.metricGPUDisplays, value: snapshot.gpuDisplaySummaryText, status: snapshot.hasGPUDisplayReport ? .normal : .neutral)
                StatusSummaryRow(title: PulseDockAppStrings.overviewDiskAvailableTitle, value: snapshot.diskText, status: usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold))
            }
        }
    }
}

private struct CPUPage: View {
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]
    let isCompact: Bool

    var body: some View {
        let cpuTrend = cpuTrendValues(from: history)

        VStack(alignment: .leading, spacing: 16) {
            ResponsivePanelPair(isCompact: isCompact, secondaryWidth: 320) {
                processorPanel(cpuTrend: cpuTrend)
            } secondary: {
                loadPanel
            }

            DashboardPanel(title: PulseDockAppStrings.cpuPerCoreUsageTitle, subtitle: PulseDockAppStrings.cpuPerCoreUsageSubtitle, icon: "square.grid.3x3") {
                if snapshot.cpuCoreUsages.isEmpty {
                    StatusSummaryRow(title: PulseDockAppStrings.cpuPerCoreSampleTitle, value: PulseDockAppStrings.systemDidNotReport, status: .neutral)
                } else {
                    LazyVGrid(columns: adaptiveCoreColumns(), spacing: 10) {
                        ForEach(Array(snapshot.cpuCoreUsages.enumerated()), id: \.offset) { index, value in
                            CoreUsageTile(index: index + 1, value: value, tint: DashboardColor.green)
                        }
                    }
                }
            }
        }
    }

    private func processorPanel(cpuTrend: [Double]) -> some View {
        DashboardPanel(title: PulseDockAppStrings.cpuProcessorTitle, subtitle: PulseDockAppStrings.cpuProcessorSubtitle, icon: "cpu") {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(snapshot.cpuText)
                        .font(.system(size: 54, weight: .semibold, design: .default).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(PulseDockAppStrings.cpuCurrentTotalUsageTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DashboardColor.muted)
                    Spacer()
                    DataChip(icon: "waveform.path.ecg", text: reportedHistorySampleChipText(from: history))
                }

                Sparkline(values: cpuTrend, tint: DashboardColor.green, fill: true)
                    .frame(height: isCompact ? 132 : 170)
            }
        }
    }

    private var loadPanel: some View {
        DashboardPanel(title: PulseDockAppStrings.metricLoad, subtitle: PulseDockAppStrings.cpuLoadTrendSubtitle, icon: "speedometer") {
            VStack(spacing: 12) {
                StatLine(label: PulseDockAppStrings.cpuOneMinuteLabel, value: snapshot.loadText, progress: snapshot.loadAverageProgress, tint: DashboardColor.green)
                StatLine(label: PulseDockAppStrings.cpuFiveMinuteLabel, value: snapshot.loadAverage5Text, progress: snapshot.loadAverage5Progress, tint: DashboardColor.blue)
                StatLine(label: PulseDockAppStrings.cpuFifteenMinuteLabel, value: snapshot.loadAverage15Text, progress: snapshot.loadAverage15Progress, tint: DashboardColor.amber)
                Divider()
                KeyValueGrid(items: [
                    (PulseDockAppStrings.cpuProcessorLabel, snapshot.cpuBrandText),
                    (PulseDockAppStrings.cpuPhysicalCoresLabel, snapshot.physicalCoreCountText),
                    (PulseDockAppStrings.cpuLogicalCoresLabel, snapshot.logicalCoreCountText),
                    (PulseDockAppStrings.cpuActiveCoresLabel, snapshot.activeProcessorCountText),
                    (PulseDockAppStrings.metricRunningApps, snapshot.runningAppCountText)
                ])
            }
        }
    }
}

private struct MemoryPage: View {
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]
    let isCompact: Bool

    var body: some View {
        let memoryTrend = memoryTrendValues(from: history)

        VStack(alignment: .leading, spacing: 16) {
            ResponsivePanelPair(isCompact: isCompact) {
                memoryUsagePanel(memoryTrend: memoryTrend)
            } secondary: {
                compositionPanel
            }
        }
    }

    private func memoryUsagePanel(memoryTrend: [Double]) -> some View {
        DashboardPanel(title: PulseDockAppStrings.overviewMemoryUsageTitle, subtitle: PulseDockAppStrings.memoryRealtimeStatsSubtitle, icon: "memorychip") {
            if isCompact {
                VStack(spacing: 14) {
                    memoryGauge
                        .frame(width: 132, height: 132)
                    memoryDetails(memoryTrend: memoryTrend)
                }
            } else {
                HStack(spacing: 24) {
                    memoryGauge
                        .frame(width: 148, height: 148)
                    memoryDetails(memoryTrend: memoryTrend)
                }
            }
        }
    }

    private var memoryGauge: some View {
        RingGauge(title: PulseDockAppStrings.memoryUsedTitle, value: snapshot.memoryUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: DashboardColor.blue)
    }

    private func memoryDetails(memoryTrend: [Double]) -> some View {
        VStack(spacing: 14) {
            MemorySegmentBar(snapshot: snapshot)
            TrendRow(title: PulseDockAppStrings.memoryUsageTrendTitle, value: snapshot.memoryText, tint: DashboardColor.blue, values: memoryTrend)
            KeyValueGrid(items: [
                (PulseDockAppStrings.memoryTotalLabel, snapshot.memoryDetailText),
                (PulseDockAppStrings.memoryFreeLabel, snapshot.memoryFreeText),
                (PulseDockAppStrings.memorySwapAvailableLabel, snapshot.memorySwapAvailableText),
                (PulseDockAppStrings.memorySwapTotalLabel, snapshot.memorySwapTotalText)
            ])
        }
    }

    private var compositionPanel: some View {
        DashboardPanel(title: PulseDockAppStrings.memoryCompositionTitle, subtitle: PulseDockAppStrings.memoryCompositionSubtitle, icon: "rectangle.3.group") {
            VStack(spacing: 12) {
                StatLine(label: PulseDockAppStrings.memoryAppActiveLabel, value: snapshot.memoryActiveText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryCompositionReport, progress: normalizedBytes(snapshot.memoryActiveBytes, total: snapshot.memoryTotalBytes)), tint: DashboardColor.green)
                StatLine(label: PulseDockAppStrings.memoryWiredLabel, value: snapshot.memoryWiredText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryCompositionReport, progress: normalizedBytes(snapshot.memoryWiredBytes, total: snapshot.memoryTotalBytes)), tint: DashboardColor.amber)
                StatLine(label: PulseDockAppStrings.memoryCompressedLabel, value: snapshot.memoryCompressedText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryCompositionReport, progress: normalizedBytes(snapshot.memoryCompressedBytes, total: snapshot.memoryTotalBytes)), tint: DashboardColor.purple)
                StatLine(label: PulseDockAppStrings.memoryCachedFilesLabel, value: snapshot.memoryCachedText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryCompositionReport, progress: normalizedBytes(snapshot.memoryCachedBytes, total: snapshot.memoryTotalBytes)), tint: DashboardColor.cyan)
                StatLine(label: PulseDockAppStrings.memorySwapLabel, value: snapshot.memorySwapText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemorySwapReport, progress: snapshot.memorySwapUsage), tint: DashboardColor.red)
            }
        }
    }
}

private struct StoragePage: View {
    @ObservedObject var store: MetricsStore
    let history: [MetricSnapshot]
    let capabilityColumns: [GridItem]

    private var snapshot: MetricSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardPanel(title: PulseDockAppStrings.storageSpaceTitle, subtitle: PulseDockAppStrings.storageLocalVolumeCapacitySubtitle, icon: "internaldrive") {
                VStack(spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(snapshot.diskUsedText)
                            .font(.system(size: 44, weight: .semibold).monospacedDigit())
                        Text(PulseDockAppStrings.storageUsedOfTotal(snapshot.diskTotalText))
                            .foregroundStyle(DashboardColor.muted)
                        Spacer()
                        DataChip(icon: "externaldrive", text: PulseDockAppStrings.storagePrimaryVolumeLabel)
                    }

                    CapacityBar(segments: diskCapacitySegments(snapshot))

                    TrendRow(title: PulseDockAppStrings.storageCapacityUsageTitle, value: snapshot.diskUsageText, tint: DashboardColor.amber, values: diskTrendValues(from: history))
                }
            }

            LazyVGrid(columns: capabilityColumns, spacing: 12) {
                SourceCapabilityCard(title: PulseDockAppStrings.storageCapacityStatsTitle, value: snapshot.storageVolumeSummaryText, icon: "checkmark.circle", status: snapshot.hasStorageVolumeReport ? .normal : .neutral, source: PulseDockAppStrings.storageSystemVolumeInfoSource)
                SourceCapabilityCard(title: PulseDockAppStrings.storagePrimaryAvailableTitle, value: snapshot.diskAvailableText, icon: "externaldrive.badge.checkmark", status: usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold), source: PulseDockAppStrings.storagePrimaryVolumeLabel)
                SourceCapabilityCard(title: PulseDockAppStrings.storageExternalVolumesTitle, value: snapshot.externalStorageVolumeSummaryText, icon: "externaldrive.connected.to.line.below", status: snapshot.hasExternalStorageVolumeSummaryReport ? .normal : .neutral, source: PulseDockAppStrings.storageMountedVolumesSource)
            }

            DashboardPanel(title: PulseDockAppStrings.storageVolumeListTitle, subtitle: PulseDockAppStrings.storageVolumeListSubtitle, icon: "list.bullet.rectangle") {
                ResponsiveTable(
                    columns: PulseDockAppStrings.storageVolumeTableColumns,
                    rows: snapshot.storageVolumes.filter(\.hasInventoryReport).prefix(8).map { volume in
                        [
                            volumeLabel(volume),
                            volume.fileSystem,
                            volume.totalText,
                            volume.usedText,
                            volume.availableText,
                            volume.usageText,
                            volume.kindText,
                            volume.accessText
                        ]
                    },
                    preferredColumnWidth: DashboardLayout.wideTableColumnWidth
                )
            }
        }
    }

}

private struct NetworkPage: View {
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]
    let metricColumns: [GridItem]

    var body: some View {
        let networkDownloadTrend = networkTrendValues(from: history, keyPath: \.networkInBytesPerSecond)
        let networkUploadTrend = networkTrendValues(from: history, keyPath: \.networkOutBytesPerSecond)
        let networkTrend = networkTrendValues(from: history)
        let networkPathTrend = networkPathTrendValues(from: history)

        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: metricColumns, spacing: 12) {
                MetricCard(title: PulseDockAppStrings.networkDownloadTitle, value: snapshot.networkInText, detail: PulseDockAppStrings.networkRealtimeRateDetail, icon: "arrow.down", tint: DashboardColor.blue, badgeText: nil, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkInBytesPerSecond)), values: networkDownloadTrend)
                MetricCard(title: PulseDockAppStrings.networkUploadTitle, value: snapshot.networkOutText, detail: PulseDockAppStrings.networkRealtimeRateDetail, icon: "arrow.up", tint: DashboardColor.green, badgeText: nil, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkOutBytesPerSecond)), values: networkUploadTrend)
                MetricCard(title: PulseDockAppStrings.networkTotalThroughputTitle, value: snapshot.networkText, detail: PulseDockAppStrings.networkCombinedTrafficDetail, icon: "network", tint: DashboardColor.cyan, badgeText: nil, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkByteCounters, progress: MetricScales.networkRateProgress(bytesPerSecond: snapshot.networkBytesPerSecond)), values: networkTrend)
                MetricCard(title: PulseDockAppStrings.networkConnectionStatusTitle, value: snapshot.networkPathText, detail: snapshot.networkPathDetailText, icon: "checkmark.seal", tint: networkStatusColor(snapshot), badgeText: nil, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkPathReport, progress: snapshot.canonicalNetworkPathState.progress), values: networkPathTrend)
                MetricCard(title: PulseDockAppStrings.networkInterfaceTitle, value: snapshot.networkInterfaceSummary, detail: PulseDockAppStrings.networkActiveInterfacesDetail, icon: "wifi", tint: DashboardColor.purple, badgeText: nil, progress: MetricScales.reportedProgress(hasReport: snapshot.hasNetworkInterfaceReport, progress: activeInterfaceProgress(snapshot)), values: [])
            }

            DashboardPanel(title: PulseDockAppStrings.networkConnectivityTitle, subtitle: PulseDockAppStrings.networkSystemPathSubtitle, icon: "point.3.connected.trianglepath.dotted") {
                ResponsiveTable(
                    columns: PulseDockAppStrings.networkCapabilityTableColumns,
                    rows: [
                        [PulseDockAppStrings.networkCapabilityLabel, snapshot.networkPathCapabilityText, PulseDockAppStrings.networkSystemPathSubtitle],
                        ["DNS", snapshot.networkDNSCapabilityText, PulseDockAppStrings.networkNameResolutionSource],
                        ["IPv4", snapshot.networkIPv4CapabilityText, PulseDockAppStrings.networkSystemPathSubtitle],
                        ["IPv6", snapshot.networkIPv6CapabilityText, PulseDockAppStrings.networkSystemPathSubtitle],
                        [PulseDockAppStrings.networkLowDataModeLabel, snapshot.networkLowDataModeText, PulseDockAppStrings.networkSystemPathSubtitle],
                        [PulseDockAppStrings.networkMeteredLabel, snapshot.networkMeteredText, PulseDockAppStrings.networkSystemPathSubtitle]
                    ],
                    preferredColumnWidth: DashboardLayout.minimumTableColumnWidth
                )
            }

            DashboardPanel(title: PulseDockAppStrings.networkInterfaceTitle, subtitle: PulseDockAppStrings.networkInterfacesSubtitle, icon: "wifi") {
                let reportedInterfaces = snapshot.networkInterfaces.filter(\.hasInventoryReport)
                ResponsiveTable(
                    columns: PulseDockAppStrings.networkInterfaceTableColumns,
                    rows: reportedInterfaces.prefix(10).map { interface in
                        [
                            interface.displayName,
                            interface.kind,
                            interface.stateText,
                            interface.mtuText,
                            interface.linkSpeedText,
                            interface.byteCountText,
                            interface.packetCountText,
                            interface.packetErrorText
                        ]
                    },
                    emptyText: reportedInterfaces.isEmpty ? PulseDockAppStrings.systemDidNotReport : nil,
                    preferredColumnWidth: DashboardLayout.wideTableColumnWidth
                )
            }
        }
    }
}

private struct PowerPage: View {
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]
    let isCompact: Bool

    var body: some View {
        let powerTrend = powerTrendValues(from: history)

        VStack(alignment: .leading, spacing: 16) {
            ResponsivePanelPair(isCompact: isCompact, secondaryWidth: 340) {
                batteryPanel(powerTrend: powerTrend)
            } secondary: {
                thermalPanel
            }

            DashboardPanel(title: PulseDockAppStrings.batteryInformationTitle, subtitle: PulseDockAppStrings.batteryInformationSubtitle, icon: "bolt") {
                ResponsiveTable(
                    columns: PulseDockAppStrings.itemCurrentDescriptionTableColumns,
                    rows: [
                        [PulseDockAppStrings.batteryRemainingTimeLabel, snapshot.batteryTimeRemainingText, PulseDockAppStrings.sourceSystemEstimate],
                        [PulseDockAppStrings.batteryCurrentCapacityLabel, snapshot.batteryCurrentCapacityText, PulseDockAppStrings.sourcePowerStatus],
                        [PulseDockAppStrings.batteryMaxCapacityLabel, snapshot.batteryMaxCapacityText, PulseDockAppStrings.sourcePowerStatus],
                        [PulseDockAppStrings.batteryDesignCapacityLabel, snapshot.batteryDesignCapacityText, PulseDockAppStrings.sourceBatterySpecifications],
                        [PulseDockAppStrings.batteryCycleCountLabel, snapshot.batteryCycleText, PulseDockAppStrings.sourceBatteryHealth],
                        [PulseDockAppStrings.batteryHealthLabel, snapshot.batteryHealthText, PulseDockAppStrings.sourceBatteryHealth],
                        [PulseDockAppStrings.batteryVoltageLabel, snapshot.batteryVoltageText, PulseDockAppStrings.sourcePowerStatus],
                        [PulseDockAppStrings.batteryCurrentLabel, snapshot.batteryAmperageText, PulseDockAppStrings.sourcePowerStatus]
                    ],
                    preferredColumnWidth: DashboardLayout.minimumTableColumnWidth
                )
            }
        }
    }

    private func batteryPanel(powerTrend: [Double]) -> some View {
        DashboardPanel(title: PulseDockAppStrings.powerBatteryPanelTitle, subtitle: PulseDockAppStrings.powerBatteryPanelSubtitle, icon: "battery.75percent") {
            if isCompact {
                VStack(spacing: 14) {
                    powerGauge
                        .frame(width: 132, height: 132)
                    powerDetails(powerTrend: powerTrend)
                }
            } else {
                HStack(spacing: 24) {
                    powerGauge
                        .frame(width: 152, height: 152)
                    powerDetails(powerTrend: powerTrend)
                }
            }
        }
    }

    private var powerGauge: some View {
        RingGauge(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, progress: powerGaugeProgress(snapshot), tint: powerTint(snapshot))
    }

    private func powerDetails(powerTrend: [Double]) -> some View {
        VStack(spacing: 14) {
            TrendRow(title: powerTrendTitle(snapshot), value: snapshot.powerStatusText, tint: powerTint(snapshot), values: powerTrend)
            KeyValueGrid(items: [
                (PulseDockAppStrings.powerSourceLabel, snapshot.powerSourceText)
            ])
        }
    }

    private var thermalPanel: some View {
        DashboardPanel(title: PulseDockAppStrings.statusThermalTitle, subtitle: PulseDockAppStrings.statusThermalSubtitle, icon: "thermometer.medium") {
            VStack(spacing: 12) {
                StatusSummaryRow(title: PulseDockAppStrings.statusCurrentStateTitle, value: snapshot.thermalText, status: thermalStatus(snapshot.thermalState))
                StatusSummaryRow(title: PulseDockAppStrings.statusPerformanceLimitTitle, value: snapshot.thermalLimitText, status: thermalStatus(snapshot.thermalState))
            }
        }
    }
}

private struct GPUDisplayPage: View {
    let snapshot: MetricSnapshot
    let capabilityColumns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: capabilityColumns, spacing: 12) {
                SourceCapabilityCard(title: PulseDockAppStrings.metricGPU, value: snapshot.gpuSummaryText, icon: "sparkles.rectangle.stack", status: snapshot.hasGPUReport ? .normal : .neutral, source: PulseDockAppStrings.sourceDeviceCapabilities)
                SourceCapabilityCard(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, icon: "display", status: snapshot.hasDisplayReport ? .normal : .neutral, source: PulseDockAppStrings.sourceDisplayConfiguration)
                SourceCapabilityCard(title: PulseDockAppStrings.gpuUnifiedMemoryTitle, value: unifiedMemorySummary, icon: "memorychip", status: hasUnifiedMemorySummary ? .normal : .neutral, source: PulseDockAppStrings.sourceGPUCapabilities)
            }

            DashboardPanel(title: PulseDockAppStrings.gpuUnifiedMemoryPanelTitle, subtitle: PulseDockAppStrings.gpuUnifiedMemoryPanelSubtitle, icon: "display") {
                ResponsiveTable(
                    columns: PulseDockAppStrings.gpuDeviceTableColumns,
                    rows: snapshot.gpuDevices.filter(\.hasInventoryReport).map { device in
                        [
                            device.name,
                            device.kindText,
                            device.unifiedMemoryText,
                            device.recommendedWorkingSetText,
                            device.threadgroupMemoryText,
                            device.threadgroupSizeText,
                            device.stateText
                        ]
                    },
                    preferredColumnWidth: DashboardLayout.wideTableColumnWidth
                )
            }

            DashboardPanel(title: PulseDockAppStrings.metricDisplays, subtitle: PulseDockAppStrings.displayPanelSubtitle, icon: "rectangle.on.rectangle") {
                ResponsiveTable(
                    columns: PulseDockAppStrings.displayTableColumns,
                    rows: snapshot.displays.filter(\.hasInventoryReport).map { display in
                        [
                            display.name,
                            display.pixelSizeText,
                            display.modeSizeText,
                            display.backingScaleText,
                            display.colorText,
                            display.refreshRateText,
                            display.physicalSizeText,
                            display.rotationText,
                            display.stateText
                        ]
                    },
                    preferredColumnWidth: DashboardLayout.wideTableColumnWidth
                )
            }
        }
    }

    private var unifiedMemorySummary: String {
        let reportedDevices = reportedUnifiedMemoryDevices
        guard !reportedDevices.isEmpty else { return PulseDockAppStrings.notReported }
        let unifiedCount = reportedDevices.filter(\.hasUnifiedMemory).count
        return unifiedCount == reportedDevices.count ? PulseDockAppStrings.statusSupported : "\(unifiedCount)/\(reportedDevices.count)"
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
                SummaryCard(title: PulseDockAppStrings.processesRunningAppsTitle, value: snapshot.runningAppCountText, icon: "app.badge", tint: DashboardColor.blue)
                SummaryCard(title: PulseDockAppStrings.processesDisplayedAppsTitle, value: snapshot.runningAppListCountText, icon: "list.bullet.rectangle", tint: DashboardColor.green)
                SummaryCard(title: PulseDockAppStrings.processesForegroundAppsTitle, value: snapshot.activeApplicationCountText, icon: "cursorarrow.click", tint: DashboardColor.amber)
                SummaryCard(title: PulseDockAppStrings.processesHiddenAppsTitle, value: snapshot.hiddenApplicationCountText, icon: "eye.slash", tint: DashboardColor.purple)
            }

            DashboardPanel(title: PulseDockAppStrings.processesRunningAppsTitle, subtitle: ProcessMetric.listSubtitle(for: snapshot.runningApps, defaultSubtitle: PulseDockAppStrings.processesDefaultSubtitle), icon: "list.bullet.rectangle") {
                ResponsiveTable(
                    columns: PulseDockAppStrings.processesTableColumns,
                    rows: snapshot.runningApps.filter(\.hasInventoryReport).map { process in
                        [
                            process.name,
                            process.stateText,
                            process.architectureText,
                            process.launchText
                        ]
                    },
                    preferredColumnWidth: DashboardLayout.minimumTableColumnWidth
                )
            }
        }
    }
}

private struct SensorsPage: View {
    @ObservedObject var store: MetricsStore
    let isCompact: Bool
    let capabilityColumns: [GridItem]

    private var snapshot: MetricSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isCompact {
                VStack(alignment: .leading, spacing: DashboardLayout.compactPanelSpacing) {
                    thermalPanel
                    realtimeSignalsPanel
                }
            } else {
                HStack(alignment: .top, spacing: DashboardLayout.compactPanelSpacing) {
                    thermalPanel
                        .frame(width: DashboardLayout.regularAsideWidth)
                    realtimeSignalsPanel
                }
            }

            DashboardPanel(title: PulseDockAppStrings.localRuleTableTitle, subtitle: PulseDockAppStrings.localRuleTableSubtitle, icon: "checkmark.shield") {
                ResponsiveTable(
                    columns: PulseDockAppStrings.statusRuleTableColumns,
                    rows: [
                        [PulseDockAppStrings.metricCPU, MetricFormatting.percentage(store.cpuAlertThreshold), snapshot.cpuText, thresholdStatusText(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold, warningText: PulseDockAppStrings.statusWarning)],
                        [PulseDockAppStrings.metricMemory, MetricFormatting.percentage(store.memoryAlertThreshold), snapshot.memoryUsageText, thresholdStatusText(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold, warningText: PulseDockAppStrings.statusWarning)],
                        [PulseDockAppStrings.metricDisk, MetricFormatting.percentage(store.diskAlertThreshold), snapshot.diskUsageText, thresholdStatusText(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold, warningText: PulseDockAppStrings.statusWarning)],
                        [PulseDockAppStrings.metricNetworkConnection, PulseDockAppStrings.statusOnline, snapshot.networkPathText, snapshot.networkRuleStatusText]
                    ],
                    preferredColumnWidth: DashboardLayout.minimumTableColumnWidth
                )
            }
        }
    }

    private var thermalPanel: some View {
        DashboardPanel(title: PulseDockAppStrings.statusThermalTitle, subtitle: PulseDockAppStrings.statusThermalSubtitle, icon: "thermometer.medium") {
            VStack(spacing: 14) {
                RingGauge(title: PulseDockAppStrings.statusThermalTitle, value: snapshot.thermalText, progress: ThermalState(raw: snapshot.thermalState).progress, tint: thermalStatus(snapshot.thermalState).color)
                    .frame(width: isCompact ? 132 : 160, height: isCompact ? 132 : 160)
                StatusSummaryRow(title: PulseDockAppStrings.statusPerformanceLimitTitle, value: snapshot.thermalLimitText, status: thermalStatus(snapshot.thermalState))
            }
        }
    }

    private var realtimeSignalsPanel: some View {
        DashboardPanel(title: PulseDockAppStrings.statusRealtimeSignalsTitle, subtitle: PulseDockAppStrings.statusRealtimeSignalsSubtitle, icon: "waveform.path.ecg.rectangle") {
            LazyVGrid(columns: capabilityColumns, spacing: 12) {
                SourceCapabilityCard(title: PulseDockAppStrings.metricCPU, value: snapshot.cpuText, icon: "cpu", status: usageStatusLevel(hasReport: snapshot.hasCPUUsageReport, usage: snapshot.cpuUsage, threshold: store.cpuAlertThreshold), source: PulseDockAppStrings.sourceThreshold(MetricFormatting.percentage(store.cpuAlertThreshold)))
                SourceCapabilityCard(title: PulseDockAppStrings.metricMemory, value: snapshot.memoryUsageText, icon: "memorychip", status: usageStatusLevel(hasReport: snapshot.hasMemoryUsageReport, usage: snapshot.memoryUsage, threshold: store.memoryAlertThreshold), source: PulseDockAppStrings.sourceThreshold(MetricFormatting.percentage(store.memoryAlertThreshold)))
                SourceCapabilityCard(title: PulseDockAppStrings.metricDisk, value: snapshot.diskUsageText, icon: "internaldrive", status: usageStatusLevel(hasReport: snapshot.hasDiskUsageReport, usage: snapshot.diskUsage, threshold: store.diskAlertThreshold), source: PulseDockAppStrings.sourceThreshold(MetricFormatting.percentage(store.diskAlertThreshold)))
                SourceCapabilityCard(title: snapshot.powerStatusTitle, value: snapshot.powerStatusText, icon: "battery.75percent", status: powerStatusLevel(snapshot), source: snapshot.powerSourceText)
                SourceCapabilityCard(title: PulseDockAppStrings.metricNetworkConnection, value: snapshot.networkPathText, icon: "network", status: networkStatusLevel(snapshot), source: snapshot.networkPathDetailText)
                SourceCapabilityCard(title: PulseDockAppStrings.metricDisplays, value: snapshot.displaySummaryText, icon: "display", status: snapshot.hasDisplayReport ? .normal : .neutral, source: snapshot.sampleTimeText)
                SourceCapabilityCard(title: PulseDockAppStrings.metricGPU, value: snapshot.gpuSummaryText, icon: "sparkles.rectangle.stack", status: snapshot.hasGPUReport ? .normal : .neutral, source: PulseDockAppStrings.sourceGraphicsDevices)
                SourceCapabilityCard(title: PulseDockAppStrings.metricStorageVolumes, value: snapshot.storageVolumeSummaryText, icon: "externaldrive", status: snapshot.hasStorageVolumeReport ? .normal : .neutral, source: PulseDockAppStrings.sourceFileSystemCapacity)
                SourceCapabilityCard(title: PulseDockAppStrings.metricLoad, value: snapshot.loadDetailText, icon: "speedometer", status: snapshot.hasLoadAverageReport ? .normal : .neutral, source: PulseDockAppStrings.sourceLoadAverages)
                SourceCapabilityCard(title: PulseDockAppStrings.metricSystemVersion, value: snapshot.osVersionText, icon: "desktopcomputer", status: snapshot.hasOSVersionReport ? .normal : .neutral, source: PulseDockAppStrings.sourceOSVersion)
                SourceCapabilityCard(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, icon: "timer", status: snapshot.hasUptimeReport ? .normal : .neutral, source: PulseDockAppStrings.sourceSystemBootTime)
            }
        }
    }
}

private struct HistoryAlertsPage: View {
    @ObservedObject var store: MetricsStore
    let history: [MetricSnapshot]
    @State private var draftCPUThreshold: Double?
    @State private var draftMemoryThreshold: Double?
    @State private var draftDiskThreshold: Double?

    private var snapshot: MetricSnapshot { store.snapshot }

    var body: some View {
        let cpuTrend = cpuTrendValues(from: history)
        let memoryTrend = memoryTrendValues(from: history)
        let networkTrend = networkTrendValues(from: history)
        let powerTrend = powerTrendValues(from: history)

        VStack(alignment: .leading, spacing: 16) {
            DashboardPanel(title: PulseDockAppStrings.historyTrendsTitle, subtitle: reportedHistorySampleCountText(from: history), icon: "chart.xyaxis.line") {
                VStack(spacing: 16) {
                    Sparkline(values: cpuTrend, tint: DashboardColor.green, fill: true)
                        .frame(height: 92)
                    TrendRow(title: "CPU", value: snapshot.cpuText, tint: DashboardColor.green, values: cpuTrend)
                    TrendRow(title: PulseDockAppStrings.metricLoad, value: snapshot.loadText, tint: DashboardColor.purple, values: loadTrendValues(from: history))
                    TrendRow(title: PulseDockAppStrings.metricMemory, value: snapshot.memoryUsageText, tint: DashboardColor.blue, values: memoryTrend)
                    TrendRow(title: PulseDockAppStrings.metricNetwork, value: snapshot.networkText, tint: DashboardColor.cyan, values: networkTrend)
                    TrendRow(title: PulseDockAppStrings.metricDisk, value: snapshot.diskUsageText, tint: DashboardColor.amber, values: diskTrendValues(from: history))
                    TrendRow(title: PulseDockAppStrings.statusThermalTitle, value: snapshot.thermalText, tint: thermalStatus(snapshot.thermalState).color, values: thermalTrendValues(from: history))
                    TrendRow(title: PulseDockAppStrings.metricUptime, value: snapshot.uptimeText, tint: DashboardColor.green, values: uptimeTrendValues(from: history))
                    TrendRow(title: powerTrendTitle(snapshot), value: snapshot.powerStatusText, tint: powerTint(snapshot), values: powerTrend)
                }
            }

            DashboardPanel(title: PulseDockAppStrings.historyThresholdSettingsTitle, subtitle: PulseDockAppStrings.historyThresholdSettingsSubtitle, icon: "slider.horizontal.3") {
                VStack(spacing: 12) {
                    ThresholdControlRow(title: "CPU", value: store.cpuAlertThreshold, draftValue: $draftCPUThreshold, update: store.updateCPUAlertThreshold, tint: DashboardColor.green)
                    ThresholdControlRow(title: PulseDockAppStrings.metricMemory, value: store.memoryAlertThreshold, draftValue: $draftMemoryThreshold, update: store.updateMemoryAlertThreshold, tint: DashboardColor.blue)
                    ThresholdControlRow(title: PulseDockAppStrings.metricDisk, value: store.diskAlertThreshold, draftValue: $draftDiskThreshold, update: store.updateDiskAlertThreshold, tint: DashboardColor.amber)
                }
            }
        }
    }
}

private struct SettingsPage: View {
    @ObservedObject var store: MetricsStore
    let isCompact: Bool
    @State private var draftRefreshInterval: RefreshIntervalOption?

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

            DashboardPanel(title: PulseDockAppStrings.settingsSupportPrivacyTitle, subtitle: PulseDockAppStrings.settingsSupportPrivacySubtitle, icon: "hand.raised") {
                VStack(spacing: 12) {
                    SettingsLinkRow(title: PulseDockAppStrings.settingsPrivacyPolicyTitle, detail: PulseDockAppStrings.settingsPrivacyPolicyDetail) {
                        PulseDockLinks.openPrivacyPolicy()
                    }
                    SettingsLinkRow(title: PulseDockAppStrings.settingsSupportTitle, detail: PulseDockAppStrings.settingsSupportDetail) {
                        PulseDockLinks.openSupport()
                    }
                }
            }

            DashboardPanel(title: PulseDockAppStrings.settingsDataSourcesTitle, subtitle: PulseDockAppStrings.settingsDataSourcesSubtitle, icon: "checklist") {
                ResponsiveTable(
                    columns: PulseDockAppStrings.settingsDataSourceTableColumns,
                    rows: [
                        [PulseDockAppStrings.metricCPUMemory, snapshot.cpuMemorySourceStatusText, PulseDockAppStrings.sourceSystemProcessorMemoryStats],
                        [PulseDockAppStrings.metricLoad, snapshot.loadAverageSourceStatusText, PulseDockAppStrings.sourceLoadAverages],
                        [PulseDockAppStrings.metricNetworkConnection, snapshot.networkSourceStatusText, PulseDockAppStrings.sourceConnectionInterfaceTraffic],
                        [PulseDockAppStrings.metricRunningApps, snapshot.runningAppsSourceStatusText, PulseDockAppStrings.sourceApplicationSessionList],
                        [PulseDockAppStrings.metricGPUDisplays, snapshot.gpuDisplaySourceStatusText, PulseDockAppStrings.sourceGraphicsDisplayConfiguration],
                        [PulseDockAppStrings.metricVolumeCapacity, snapshot.storageSourceStatusText, PulseDockAppStrings.sourceFileSystemCapacity],
                        [PulseDockAppStrings.metricPowerThermalState, snapshot.powerThermalSourceStatusText, PulseDockAppStrings.sourcePowerThermalState],
                        [PulseDockAppStrings.metricSystemVersionUptimeKernel, snapshot.systemVersionSourceStatusText, PulseDockAppStrings.sourceSystemVersionBootTime]
                    ],
                    preferredColumnWidth: DashboardLayout.minimumTableColumnWidth
                )
            }
        }
    }

    private var refreshDisplayPanel: some View {
        DashboardPanel(title: PulseDockAppStrings.settingsRefreshDisplayTitle, subtitle: PulseDockAppStrings.settingsRefreshDisplaySubtitle, icon: "slider.horizontal.3") {
            VStack(spacing: 14) {
                SettingControlRow(title: PulseDockAppStrings.settingsMainWindowRefreshTitle, detail: PulseDockAppStrings.settingsMainWindowRefreshDetail) {
                    Picker(PulseDockAppStrings.settingsMainWindowRefreshTitle, selection: Binding(
                        get: { draftRefreshInterval ?? store.refreshInterval },
                        set: { draftRefreshInterval = $0 }
                    )) {
                        ForEach(RefreshIntervalOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .onChange(of: draftRefreshInterval) { _, value in
                        guard let value else { return }
                        store.updateRefreshInterval(value)
                        draftRefreshInterval = nil
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 164)
                }
                SettingControlRow(title: PulseDockAppStrings.settingsMenuBarStatusTitle, detail: PulseDockAppStrings.settingsMenuBarStatusDetail) {
                    Toggle(PulseDockAppStrings.settingsMenuBarCPULabel, isOn: Binding(
                        get: { store.showsMenuBarCPU },
                        set: { store.updateShowsMenuBarCPU($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                SettingReadOnlyRow(
                    title: PulseDockAppStrings.settingsWidgetRefreshTitle,
                    detail: PulseDockAppStrings.settingsWidgetRefreshDetail,
                    control: PulseDockAppStrings.settingsWidgetRefreshValue
                )
                SettingControlRow(title: PulseDockAppStrings.settingsLocalHistoryTitle, detail: PulseDockAppStrings.settingsLocalHistoryDetail(sampleCount: store.historyDepth.sampleCount)) {
                    Picker(PulseDockAppStrings.settingsLocalHistoryTitle, selection: Binding(
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
        DashboardPanel(title: PulseDockAppStrings.settingsWidgetTitle, subtitle: PulseDockAppStrings.settingsWidgetSubtitle, icon: "rectangle.grid.2x2") {
            VStack(spacing: 12) {
                WidgetMiniPreview(snapshot: snapshot)
                KeyValueGrid(items: [
                    (PulseDockAppStrings.settingsWidgetSizeLabel, PulseDockAppStrings.settingsWidgetSizesValue),
                    (PulseDockAppStrings.settingsWidgetDataSourceLabel, PulseDockAppStrings.settingsWidgetDataSourceValue),
                    (PulseDockAppStrings.settingsWidgetSampleLabel, snapshot.sampleTimeText),
                    (PulseDockAppStrings.settingsWidgetHistoryLabel, store.historyDurationText)
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
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockAppStrings.notReported)
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
    var title: String = PulseDockAppStrings.processesRunningAppsTitle
    var subtitle: String = PulseDockAppStrings.processesDefaultSubtitle

    var body: some View {
        DashboardPanel(title: title, subtitle: ProcessMetric.listSubtitle(for: processes, defaultSubtitle: subtitle), icon: "list.bullet.rectangle") {
            ResponsiveTable(
                columns: PulseDockAppStrings.processesTableColumns,
                rows: processes.filter(\.hasInventoryReport).prefix(6).map { process in
                    [
                        process.name,
                        process.stateText,
                        process.architectureText,
                        process.launchText
                    ]
                },
                preferredColumnWidth: DashboardLayout.minimumTableColumnWidth
            )
        }
    }
}

private struct WidgetPreviewPanel: View {
    let snapshot: MetricSnapshot

    var body: some View {
        DashboardPanel(title: PulseDockAppStrings.settingsWidgetTitle, subtitle: PulseDockAppStrings.settingsWidgetSubtitle, icon: "rectangle.grid.2x2") {
            HStack(alignment: .top, spacing: 12) {
                WidgetMiniPreview(snapshot: snapshot)
                VStack(alignment: .leading, spacing: 10) {
                    DataChip(icon: "square.stack.3d.up", text: PulseDockAppStrings.settingsWidgetSizesValue)
                    DataChip(icon: "waveform.path.ecg", text: PulseDockAppStrings.settingsWidgetDataSourceValue)
                    DataChip(icon: "timer", text: PulseDockAppStrings.settingsWidgetRefreshValue)
                    Text(PulseDockAppStrings.widgetPreviewDescription)
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
                RingGauge(title: "CPU", value: snapshot.cpuText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasCPUUsageReport, progress: snapshot.cpuUsage), tint: DashboardColor.green)
                RingGauge(title: "MEM", value: snapshot.memoryUsageText, progress: MetricScales.reportedProgress(hasReport: snapshot.hasMemoryUsageReport, progress: snapshot.memoryUsage), tint: DashboardColor.blue)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let value: String
    let progress: Double?
    let tint: Color

    private var clampedProgress: Double? {
        progress.flatMap(MetricScales.clampedProgress)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.14), lineWidth: 8)
            if let clampedProgress {
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(DashboardMotion.metric(reduceMotion: reduceMotion), value: clampedProgress)
            }
            VStack(spacing: DashboardSpacing.xxs) {
                Text(value)
                    .font(DashboardTypography.metricValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(title)
                    .font(DashboardTypography.caption)
                    .foregroundStyle(DashboardColor.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockAppStrings.notReported)
    }
}

private struct TrendRow: View {
    let title: String
    let value: String
    let tint: Color
    let values: [Double]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DashboardSpacing.md) {
                trendLabel
                    .frame(width: 96, alignment: .leading)
                trendSparkline
            }

            VStack(alignment: .leading, spacing: DashboardSpacing.sm) {
                trendLabel
                trendSparkline
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private var trendLabel: some View {
        VStack(alignment: .leading, spacing: DashboardSpacing.xxs) {
            Text(title)
                .font(DashboardTypography.caption)
                .foregroundStyle(DashboardColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(DashboardTypography.metricValue)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
    }

    private var trendSparkline: some View {
        Sparkline(values: values, tint: tint, fill: true)
            .frame(height: 46)
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
        .accessibilityLabel(PulseDockAppStrings.accessibilityTrendChart)
        .accessibilityValue(sparklineAccessibilityValue)
    }

    private var preparedValues: [Double] {
        if values.count > 1 {
            return values.suffix(sparklineVisibleSampleLimit)
        }

        if let value = values.first {
            return [value, value]
        }

        return []
    }

    private var sparklineAccessibilityValue: String {
        guard let lastValue = preparedValues.last else { return PulseDockAppStrings.notReported }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        .frame(width: MetricScales.fillWidth(progress, in: proxy.size.width, minimumVisibleWidth: 6))
                        .animation(DashboardMotion.metric(reduceMotion: reduceMotion), value: progress)
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
        .accessibilityValue(progress.map(MetricFormatting.percentage) ?? PulseDockAppStrings.notReported)
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
    private let memorySegmentCount: CGFloat = 3
    let snapshot: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardSpacing.sm) {
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
                LegendDot(title: PulseDockAppStrings.memoryUsedTitle, color: DashboardColor.blue)
                LegendDot(title: PulseDockAppStrings.memoryCachedLabel, color: DashboardColor.cyan)
                LegendDot(title: PulseDockAppStrings.memoryFreeLabel, color: Color.secondary.opacity(0.38))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(PulseDockAppStrings.metricMemory), \(snapshot.memoryUsageText)")
    }

    private func segment(_ bytes: UInt64, color: Color, in totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: segmentWidth(bytes, in: totalWidth))
    }

    private func segmentWidth(_ bytes: UInt64, in totalWidth: CGFloat) -> CGFloat {
        guard totalWidth > 0 else { return 0 }
        let width = CGFloat(normalizedBytes(bytes, total: snapshot.memoryTotalBytes)) * totalWidth
        let minimumVisibleWidth = min(8, totalWidth / memorySegmentCount)
        return min(max(width, minimumVisibleWidth), totalWidth)
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
                .lineLimit(1)
                .minimumScaleFactor(0.72)
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
        case .neutral: DashboardColor.cyan
        }
    }

    var text: String {
        switch self {
        case .normal: PulseDockAppStrings.statusNormal
        case .warning: PulseDockAppStrings.statusWarning
        case .critical: PulseDockAppStrings.statusCritical
        case .neutral: PulseDockAppStrings.notReported
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
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .layoutPriority(1)
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
    var minimumColumnWidth: CGFloat = 132

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumColumnWidth), spacing: 10)], spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DashboardColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
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
            .help(PulseDockAppStrings.openTitle(title))
            .accessibilityLabel(PulseDockAppStrings.openTitle(title))
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
    @Binding var draftValue: Double?
    let update: (Double) -> Void
    let tint: Color

    private var displayedValue: Double {
        draftValue ?? value
    }

    var body: some View {
        HStack(spacing: DashboardSpacing.md) {
            Text(title)
                .font(DashboardTypography.body.weight(.semibold))
                .frame(width: 56, alignment: .leading)
            Slider(value: Binding(
                get: { displayedValue },
                set: { draftValue = $0 }
            ), in: 0.5...0.98, step: 0.01, onEditingChanged: { editing in
                guard !editing, let draftValue else { return }
                update(draftValue)
                self.draftValue = nil
            })
                .tint(tint)
            Text(MetricFormatting.percentage(displayedValue))
                .font(DashboardTypography.smallMetricValue)
                .foregroundStyle(tint)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(12)
        .background(DashboardColor.panelAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(MetricFormatting.percentage(displayedValue))")
    }
}

private struct ResponsiveTable: View {
    let columns: [String]
    let rows: [[String]]
    var emptyText: String?
    var preferredColumnWidth: CGFloat = DashboardLayout.minimumTableColumnWidth

    private var resolvedMinimumTableWidth: CGFloat {
        minimumTableWidth(columnCount: columns.count, preferredColumnWidth: preferredColumnWidth)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                TableHeader(columns: columns)
                if rows.isEmpty, let emptyText {
                    TableEmptyRow(text: emptyText)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        TableRow(values: row)
                    }
                }
            }
            .frame(minWidth: resolvedMinimumTableWidth)
        }
    }
}

private struct TableHeader: View {
    let columns: [String]

    var body: some View {
        HStack {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
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
    }
}

private func minimumTableWidth(columnCount: Int, preferredColumnWidth: CGFloat = DashboardLayout.minimumTableColumnWidth) -> CGFloat {
    max(CGFloat(columnCount) * preferredColumnWidth, 360)
}

private func reportedHistorySampleCountText(from history: [MetricSnapshot]) -> String {
    let reportedSampleCount = history.filter(\.hasSampleTimeReport).count
    guard reportedSampleCount > 0 else { return PulseDockAppStrings.notReported }
    return PulseDockAppStrings.recentSampleCount(min(reportedSampleCount, sparklineVisibleSampleLimit))
}

private func reportedHistorySampleChipText(from history: [MetricSnapshot]) -> String {
    let reportedSampleCount = history.filter(\.hasSampleTimeReport).count
    guard reportedSampleCount > 0 else { return PulseDockAppStrings.notReported }
    return PulseDockAppStrings.recentSampleChipCount(min(reportedSampleCount, sparklineVisibleSampleLimit))
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

private func networkTrendValues(from history: [MetricSnapshot]) -> [Double] {
    networkTrendValues(from: history, keyPath: \.networkBytesPerSecond)
}

private func networkTrendValues(from history: [MetricSnapshot], keyPath: KeyPath<MetricSnapshot, UInt64>) -> [Double] {
    history.filter(\.hasNetworkByteCounters).map { MetricScales.networkRateProgress(bytesPerSecond: $0[keyPath: keyPath]) }
}

private func networkPathTrendValues(from history: [MetricSnapshot]) -> [Double] {
    history.filter(\.hasNetworkPathReport).map { $0.canonicalNetworkPathState.progress }
}

private func thermalTrendValues(from history: [MetricSnapshot]) -> [Double] {
    history.filter(\.hasThermalStateReport).compactMap { ThermalState(raw: $0.thermalState).progress }
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
        CapacitySegment(title: PulseDockAppStrings.storageColumnUsed, value: snapshot.diskUsage, color: DashboardColor.amber),
        CapacitySegment(title: PulseDockAppStrings.memoryFreeLabel, value: max(1 - snapshot.diskUsage, 0), color: Color.secondary.opacity(0.24))
    ]
}

private func statusLevel(for tone: MetricStatusTone) -> StatusLevel {
    switch tone {
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

private func networkStatusLevel(_ snapshot: MetricSnapshot) -> StatusLevel {
    statusLevel(for: snapshot.canonicalNetworkPathState.metricStatusTone)
}

private func networkStatusColor(_ snapshot: MetricSnapshot) -> Color {
    networkStatusLevel(snapshot).color
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
    snapshot.batteryPercent == nil ? PulseDockAppStrings.powerSupplyTrendTitle : PulseDockAppStrings.powerBatteryHistoryTitle
}

private func volumeLabel(_ volume: StorageVolumeMetric) -> String {
    if volume.isPrimary { return PulseDockAppStrings.storagePrimaryVolumeLabel }
    return PulseDockAppStrings.storageVolumeNumber(volume.index + 1)
}

private func usageStatusLevel(hasReport: Bool, usage: Double, threshold: Double) -> StatusLevel {
    guard hasReport else { return .neutral }
    return usage > threshold ? .warning : .normal
}

private func thresholdStatusText(hasReport: Bool, usage: Double, threshold: Double, warningText: String) -> String {
    guard hasReport else { return PulseDockAppStrings.notReported }
    return usage > threshold ? warningText : PulseDockAppStrings.statusNormal
}

private func thermalStatus(_ state: String) -> StatusLevel {
    statusLevel(for: ThermalState(raw: state).metricStatusTone)
}
