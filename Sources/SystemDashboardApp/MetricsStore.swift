import Foundation
import AppKit
import Combine
import MachO
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(SharedMetrics)
import SharedMetrics
#endif

enum RefreshIntervalOption: Double, CaseIterable, Identifiable {
    case quick = 1
    case balanced = 2
    case relaxed = 5

    var id: Double { rawValue }
    var seconds: TimeInterval { rawValue }
    var label: String { "\(Int(rawValue))s" }
}

enum HistoryDepthOption: Int, CaseIterable, Identifiable {
    case compact = 90
    case standard = 180
    case extended = 360

    var id: Int { rawValue }
    var sampleCount: Int { rawValue }
    var label: String { "\(rawValue) 次" }
}

private enum DefaultsKeys {
    static let refreshInterval = "dashboard.refreshInterval"
    static let historyDepth = "dashboard.historyDepth"
    static let cpuAlertThreshold = "dashboard.alertThreshold.cpu"
    static let memoryAlertThreshold = "dashboard.alertThreshold.memory"
    static let diskAlertThreshold = "dashboard.alertThreshold.disk"
    static let showsMenuBarCPU = "dashboard.menuBar.showsCPU"
    static let historySnapshots = "dashboard.historySnapshots"
}

@MainActor
final class MetricsStore: ObservableObject {
    @Published private(set) var snapshot = MetricSnapshot.placeholder
    @Published private(set) var recentSnapshots: [MetricSnapshot] = [.placeholder]
    @Published private(set) var isPaused = false
    @Published private(set) var refreshInterval: RefreshIntervalOption
    @Published private(set) var historyDepth: HistoryDepthOption
    @Published private(set) var cpuAlertThreshold: Double
    @Published private(set) var memoryAlertThreshold: Double
    @Published private(set) var diskAlertThreshold: Double
    @Published private(set) var showsMenuBarCPU: Bool

    private let sampler: SystemSampler
    private let defaults: UserDefaults
    private var timer: Timer?
    private var initialRefreshTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var lastWidgetReloadDate: Date?
    private var lastHistoryPersistenceDate: Date?
    private let initialSampleWarmUpDelayNanoseconds: UInt64 = 150_000_000
    private let widgetReloadInterval: TimeInterval = 60
    private let historyPersistenceInterval: TimeInterval = 15

    init(
        sampler: SystemSampler = SystemSampler(),
        defaults: UserDefaults = UserDefaults.standard
    ) {
        self.sampler = sampler
        self.defaults = defaults
        self.refreshInterval = RefreshIntervalOption(rawValue: defaults.double(forKey: DefaultsKeys.refreshInterval)) ?? .balanced
        self.historyDepth = HistoryDepthOption(rawValue: defaults.integer(forKey: DefaultsKeys.historyDepth)) ?? .standard
        self.cpuAlertThreshold = Self.savedThreshold(defaults, key: DefaultsKeys.cpuAlertThreshold, defaultValue: 0.9)
        self.memoryAlertThreshold = Self.savedThreshold(defaults, key: DefaultsKeys.memoryAlertThreshold, defaultValue: 0.85)
        self.diskAlertThreshold = Self.savedThreshold(defaults, key: DefaultsKeys.diskAlertThreshold, defaultValue: 0.9)
        self.showsMenuBarCPU = defaults.object(forKey: DefaultsKeys.showsMenuBarCPU) == nil
            ? true
            : defaults.bool(forKey: DefaultsKeys.showsMenuBarCPU)

        let savedSnapshots = Self.savedHistory(defaults, limit: historyDepth.sampleCount)
        if !savedSnapshots.isEmpty {
            recentSnapshots = savedSnapshots
        }
    }

    func start() {
        guard timer == nil else { return }
        scheduleTimer()
        startInitialRefresh()
    }

    func stop() {
        cancelInitialRefresh()
        cancelRefreshTask()
        persistHistoryIfNeeded(at: Date(), force: true)
        timer?.invalidate()
        timer = nil
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            cancelInitialRefresh()
            cancelRefreshTask()
            persistHistoryIfNeeded(at: Date(), force: true)
        } else {
            startInitialRefresh()
        }
    }

    func updateRefreshInterval(_ option: RefreshIntervalOption) {
        guard refreshInterval != option else { return }

        refreshInterval = option
        defaults.set(option.rawValue, forKey: DefaultsKeys.refreshInterval)
        if timer != nil {
            scheduleTimer()
        }
    }

    func updateHistoryDepth(_ option: HistoryDepthOption) {
        guard historyDepth != option else { return }

        historyDepth = option
        defaults.set(option.rawValue, forKey: DefaultsKeys.historyDepth)
        trimHistoryIfNeeded()
        persistHistoryIfNeeded(at: Date(), force: true)
    }

    func updateCPUAlertThreshold(_ value: Double) {
        let normalized = Self.normalizedThreshold(value)
        guard cpuAlertThreshold != normalized else { return }

        cpuAlertThreshold = normalized
        defaults.set(normalized, forKey: DefaultsKeys.cpuAlertThreshold)
    }

    func updateMemoryAlertThreshold(_ value: Double) {
        let normalized = Self.normalizedThreshold(value)
        guard memoryAlertThreshold != normalized else { return }

        memoryAlertThreshold = normalized
        defaults.set(normalized, forKey: DefaultsKeys.memoryAlertThreshold)
    }

    func updateDiskAlertThreshold(_ value: Double) {
        let normalized = Self.normalizedThreshold(value)
        guard diskAlertThreshold != normalized else { return }

        diskAlertThreshold = normalized
        defaults.set(normalized, forKey: DefaultsKeys.diskAlertThreshold)
    }

    func updateShowsMenuBarCPU(_ isVisible: Bool) {
        guard showsMenuBarCPU != isVisible else { return }

        showsMenuBarCPU = isVisible
        defaults.set(isVisible, forKey: DefaultsKeys.showsMenuBarCPU)
    }

    var historyDurationText: String {
        MetricFormatting.duration(TimeInterval(historyDepth.sampleCount) * refreshInterval.seconds)
    }

    private static func savedThreshold(_ defaults: UserDefaults, key: String, defaultValue: Double) -> Double {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return normalizedThreshold(defaults.double(forKey: key))
    }

    private static func normalizedThreshold(_ value: Double) -> Double {
        min(max(value, 0.5), 0.98)
    }

    private static func savedHistory(_ defaults: UserDefaults, limit: Int) -> [MetricSnapshot] {
        guard let data = defaults.data(forKey: DefaultsKeys.historySnapshots),
              let snapshots = try? JSONDecoder().decode([MetricSnapshot].self, from: data) else {
            return []
        }

        return snapshots
            .suffix(limit)
            .map(Self.sanitizedHistorySnapshot)
    }

    private static func sanitizedHistorySnapshot(from snapshot: MetricSnapshot) -> MetricSnapshot {
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
            memoryFreeBytes: snapshot.memoryFreeBytes,
            memoryWiredBytes: snapshot.memoryWiredBytes,
            memoryCompressedBytes: snapshot.memoryCompressedBytes,
            memoryCachedBytes: snapshot.memoryCachedBytes,
            memorySwapUsedBytes: snapshot.memorySwapUsedBytes,
            memorySwapTotalBytes: snapshot.memorySwapTotalBytes,
            memorySwapAvailableBytes: snapshot.memorySwapAvailableBytes,
            hasMemoryCompositionReport: snapshot.hasMemoryCompositionReport,
            loadAverage: snapshot.loadAverage,
            loadAverage5: snapshot.loadAverage5,
            loadAverage15: snapshot.loadAverage15,
            hasLoadAverageReport: snapshot.hasLoadAverageReport,
            thermalState: snapshot.thermalState,
            batteryPercent: snapshot.batteryPercent,
            batteryIsCharging: snapshot.batteryIsCharging,
            batteryPowerSource: snapshot.batteryPowerSource,
            batteryTimeRemainingMinutes: snapshot.batteryTimeRemainingMinutes,
            batteryCycleCount: nil,
            batteryHealth: nil,
            batteryCurrentCapacity: snapshot.batteryCurrentCapacity,
            batteryMaxCapacity: snapshot.batteryMaxCapacity,
            batteryDesignCapacity: nil,
            batteryVoltageMillivolts: nil,
            batteryAmperageMilliamps: nil,
            networkBytesPerSecond: snapshot.networkBytesPerSecond,
            hasNetworkByteCounters: snapshot.hasNetworkByteCounters,
            hasNetworkDirectionByteCounters: snapshot.hasNetworkDirectionByteCounters,
            networkPathStatus: snapshot.networkPathStatus,
            networkPathIsExpensive: snapshot.networkPathIsExpensive,
            networkPathIsConstrained: snapshot.networkPathIsConstrained,
            hasNetworkPathCostReport: snapshot.hasNetworkPathCostReport,
            networkPathSupportsDNS: snapshot.networkPathSupportsDNS,
            networkPathSupportsIPv4: snapshot.networkPathSupportsIPv4,
            networkPathSupportsIPv6: snapshot.networkPathSupportsIPv6,
            hasNetworkPathSupportReport: snapshot.hasNetworkPathSupportReport,
            networkPathInterfaceKinds: snapshot.networkPathInterfaceKinds,
            networkInBytesPerSecond: snapshot.networkInBytesPerSecond,
            networkOutBytesPerSecond: snapshot.networkOutBytesPerSecond,
            networkInterfaces: [],
            diskFreeBytes: snapshot.diskFreeBytes,
            diskTotalBytes: snapshot.diskTotalBytes,
            storageVolumes: [],
            processCount: 0,
            activeApplicationCount: 0,
            hiddenApplicationCount: 0,
            topProcesses: [],
            gpuDevices: [],
            displays: [],
            uptimeSeconds: snapshot.uptimeSeconds,
            hasUptimeReport: snapshot.hasUptimeReport,
            osVersion: MetricSnapshot.placeholder.osVersion,
            kernelRelease: MetricSnapshot.placeholder.kernelRelease,
            timestamp: snapshot.timestamp
        )
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval.seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        timer?.tolerance = min(refreshInterval.seconds * 0.18, 0.5)
    }

    private func startInitialRefresh() {
        cancelInitialRefresh()
        let warmUpDelay = initialSampleWarmUpDelayNanoseconds
        let sampler = self.sampler
        initialRefreshTask = Task { @MainActor [weak self] in
            _ = await Task.detached(priority: .userInitiated) {
                sampler.sample()
            }.value
            try? await Task.sleep(nanoseconds: warmUpDelay)
            guard !Task.isCancelled, let self, timer != nil else { return }
            initialRefreshTask = nil
            refresh()
        }
    }

    private func cancelInitialRefresh() {
        initialRefreshTask?.cancel()
        initialRefreshTask = nil
    }

    private func cancelRefreshTask() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func refresh() {
        guard !isPaused, refreshTask == nil else { return }

        let sampler = self.sampler
        refreshTask = Task { @MainActor [weak self] in
            let sampledSnapshot = await Task.detached(priority: .userInitiated) {
                sampler.sample()
            }.value

            guard let self else { return }
            refreshTask = nil
            guard !Task.isCancelled, !isPaused else { return }

            var nextSnapshot = sampledSnapshot
            applyVisibleApplicationSummary(to: &nextSnapshot)
            snapshot = nextSnapshot
            appendHistorySnapshot(nextSnapshot)
            trimHistoryIfNeeded()
            persistHistoryIfNeeded(at: nextSnapshot.timestamp)
            reloadWidgetsIfNeeded(at: nextSnapshot.timestamp)
        }
    }

    private func appendHistorySnapshot(_ snapshot: MetricSnapshot) {
        if recentSnapshots.count == 1,
           let first = recentSnapshots.first,
           Self.isPlaceholderHistorySnapshot(first) {
            recentSnapshots.removeAll()
        }

        recentSnapshots.append(Self.sanitizedHistorySnapshot(from: snapshot))
    }

    private func trimHistoryIfNeeded() {
        if recentSnapshots.count > historyDepth.sampleCount {
            recentSnapshots.removeFirst(recentSnapshots.count - historyDepth.sampleCount)
        }
    }

    private func persistHistoryIfNeeded(at date: Date, force: Bool = false) {
        if !force,
           let lastHistoryPersistenceDate,
           date.timeIntervalSince(lastHistoryPersistenceDate) < historyPersistenceInterval {
            return
        }

        lastHistoryPersistenceDate = date
        let snapshots = recentSnapshots
            .map(Self.sanitizedHistorySnapshot)
            .filter { !Self.isPlaceholderHistorySnapshot($0) }
            .suffix(historyDepth.sampleCount)

        guard !snapshots.isEmpty else {
            defaults.removeObject(forKey: DefaultsKeys.historySnapshots)
            return
        }

        if let data = try? JSONEncoder().encode(Array(snapshots)) {
            defaults.set(data, forKey: DefaultsKeys.historySnapshots)
        }
    }

    private static func isPlaceholderHistorySnapshot(_ snapshot: MetricSnapshot) -> Bool {
        snapshot.memoryTotalBytes == 0
            && snapshot.diskTotalBytes == 0
            && snapshot.networkBytesPerSecond == 0
            && snapshot.cpuCoreUsages.isEmpty
            && snapshot.storageVolumes.isEmpty
            && snapshot.networkInterfaces.isEmpty
            && snapshot.topProcesses.isEmpty
    }

    private func reloadWidgetsIfNeeded(at date: Date) {
        if let lastWidgetReloadDate,
           date.timeIntervalSince(lastWidgetReloadDate) < widgetReloadInterval {
            return
        }

        lastWidgetReloadDate = date

#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }

    private func applyVisibleApplicationSummary(to snapshot: inout MetricSnapshot) {
        guard snapshot.processCount == 0, snapshot.topProcesses.isEmpty else { return }

        let applications = NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated }

        snapshot.processCount = applications.count
        snapshot.activeApplicationCount = applications.filter(\.isActive).count
        snapshot.hiddenApplicationCount = applications.filter(\.isHidden).count
        snapshot.hasRunningAppCountReport = true

        let visibleApplications = applications.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive
            }

            if lhs.isHidden != rhs.isHidden {
                return !lhs.isHidden
            }

            return reportedApplicationName(lhs.localizedName)
                .localizedStandardCompare(reportedApplicationName(rhs.localizedName)) == .orderedAscending
        }

        snapshot.topProcesses = visibleApplications.prefix(8).enumerated().map { index, application in
            ProcessMetric(
                index: index,
                name: reportedApplicationName(application.localizedName),
                activationPolicy: activationPolicyText(application.activationPolicy),
                isActive: application.isActive,
                isHidden: application.isHidden,
                hasStateReport: true,
                launchDate: application.launchDate,
                architecture: processArchitectureText(application.executableArchitecture)
            )
        }
    }

    private func reportedApplicationName(_ localizedName: String?) -> String {
        let trimmed = localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "未报告" : trimmed
    }

    private func activationPolicyText(_ policy: NSApplication.ActivationPolicy) -> String {
        switch policy {
        case .regular:
            return "普通"
        case .accessory:
            return "辅助"
        case .prohibited:
            return "后台"
        @unknown default:
            return "系统未报告"
        }
    }

    private func processArchitectureText(_ architecture: Int) -> String? {
        switch cpu_type_t(architecture) {
        case CPU_TYPE_ARM64:
            return "Apple Silicon"
        case CPU_TYPE_X86_64:
            return "Intel"
        case CPU_TYPE_I386:
            return "Intel 32-bit"
        default:
            return nil
        }
    }
}
