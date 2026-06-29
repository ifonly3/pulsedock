import Foundation
import SharedMetrics

enum PulseDockAppStrings {
    static var dashboardPageOverviewTitle: String {
        localized("app.dashboard.page.overview.title", defaultValue: "Overview")
    }

    static var dashboardPageCPUTitle: String {
        localized("app.dashboard.page.cpu.title", defaultValue: "CPU")
    }

    static var dashboardPageGPUTitle: String {
        localized("app.dashboard.page.gpu.title", defaultValue: "GPU / Displays")
    }

    static var dashboardPageMemoryTitle: String {
        localized("app.dashboard.page.memory.title", defaultValue: "Memory")
    }

    static var dashboardPageStorageTitle: String {
        localized("app.dashboard.page.storage.title", defaultValue: "Storage")
    }

    static var dashboardPageNetworkTitle: String {
        localized("app.dashboard.page.network.title", defaultValue: "Network")
    }

    static var dashboardPagePowerTitle: String {
        localized("app.dashboard.page.power.title", defaultValue: "Power")
    }

    static var dashboardPageProcessesTitle: String {
        localized("app.dashboard.page.processes.title", defaultValue: "Apps")
    }

    static var dashboardPageSensorsTitle: String {
        localized("app.dashboard.page.sensors.title", defaultValue: "Status")
    }

    static var dashboardPageHistoryTitle: String {
        localized("app.dashboard.page.history.title", defaultValue: "History")
    }

    static var dashboardPageSettingsTitle: String {
        localized("app.dashboard.page.settings.title", defaultValue: "Settings")
    }

    static var dashboardPageOverviewSubtitle: String {
        localized("app.dashboard.page.overview.subtitle", defaultValue: "Runtime Overview")
    }

    static var dashboardPageCPUSubtitle: String {
        localized("app.dashboard.page.cpu.subtitle", defaultValue: "Processor load and cores")
    }

    static var dashboardPageGPUSubtitle: String {
        localized("app.dashboard.page.gpu.subtitle", defaultValue: "Graphics devices and displays")
    }

    static var dashboardPageMemorySubtitle: String {
        localized("app.dashboard.page.memory.subtitle", defaultValue: "Usage, cache, and compression")
    }

    static var dashboardPageStorageSubtitle: String {
        localized("app.dashboard.page.storage.subtitle", defaultValue: "Capacity and disk status")
    }

    static var dashboardPageNetworkSubtitle: String {
        localized("app.dashboard.page.network.subtitle", defaultValue: "Interfaces, throughput, and connectivity")
    }

    static var dashboardPagePowerSubtitle: String {
        localized("app.dashboard.page.power.subtitle", defaultValue: "Battery, power, and thermal state")
    }

    static var dashboardPageProcessesSubtitle: String {
        localized("app.dashboard.page.processes.subtitle", defaultValue: "Running applications")
    }

    static var dashboardPageSensorsSubtitle: String {
        localized("app.dashboard.page.sensors.subtitle", defaultValue: "Thermal state and system signals")
    }

    static var dashboardPageHistorySubtitle: String {
        localized("app.dashboard.page.history.subtitle", defaultValue: "Local sample history and thresholds")
    }

    static var dashboardPageSettingsSubtitle: String {
        localized("app.dashboard.page.settings.subtitle", defaultValue: "Display, refresh, and widgets")
    }

    static var dashboardSidebarLocalStatus: String {
        localized("app.dashboard.sidebar.local_status", defaultValue: "Local Status")
    }

    static var dashboardTopBarTagline: String {
        localized("app.dashboard.top_bar.tagline", defaultValue: "Live local system sampling with a clear, readable overview")
    }

    static var dashboardTopBarLocalMachine: String {
        localized("app.dashboard.top_bar.local_machine", defaultValue: "This Mac")
    }

    static func dashboardSampleChip(_ sampleTimeText: String) -> String {
        localizedFormat("app.dashboard.top_bar.sample_format", defaultValue: "Sample %@", sampleTimeText)
    }

    static var overviewCPUUsageTitle: String {
        localized("app.dashboard.overview.cpu_usage.title", defaultValue: "CPU Usage")
    }

    static var overviewMemoryUsageTitle: String {
        localized("app.dashboard.overview.memory_usage.title", defaultValue: "Memory Usage")
    }

    static var overviewNetworkThroughputTitle: String {
        localized("app.dashboard.overview.network_throughput.title", defaultValue: "Network Throughput")
    }

    static var overviewPowerStatusTitle: String {
        localized("app.dashboard.overview.power_status.title", defaultValue: "Power Status")
    }

    static var overviewSystemStatusTitle: String {
        localized("app.dashboard.overview.system_status.title", defaultValue: "System Status")
    }

    static var overviewDiskAvailableTitle: String {
        localized("app.dashboard.overview.disk_available.title", defaultValue: "Disk Available")
    }

    static var cpuProcessorTitle: String {
        localized("app.dashboard.cpu.processor.title", defaultValue: "CPU Processor")
    }

    static var cpuProcessorSubtitle: String {
        localized("app.dashboard.cpu.processor.subtitle", defaultValue: "Processor core statistics")
    }

    static var cpuCurrentTotalUsageTitle: String {
        localized("app.dashboard.cpu.current_total_usage", defaultValue: "Current Total Usage")
    }

    static var cpuLoadTrendSubtitle: String {
        localized("app.dashboard.cpu.load_trend.subtitle", defaultValue: "System load trend")
    }

    static var cpuOneMinuteLabel: String {
        localized("app.dashboard.cpu.load.one_minute", defaultValue: "1 Minute")
    }

    static var cpuFiveMinuteLabel: String {
        localized("app.dashboard.cpu.load.five_minutes", defaultValue: "5 Minutes")
    }

    static var cpuFifteenMinuteLabel: String {
        localized("app.dashboard.cpu.load.fifteen_minutes", defaultValue: "15 Minutes")
    }

    static var cpuProcessorLabel: String {
        localized("app.dashboard.cpu.processor.label", defaultValue: "Processor")
    }

    static var cpuPhysicalCoresLabel: String {
        localized("app.dashboard.cpu.physical_cores.label", defaultValue: "Physical Cores")
    }

    static var cpuLogicalCoresLabel: String {
        localized("app.dashboard.cpu.logical_cores.label", defaultValue: "Logical Cores")
    }

    static var cpuActiveCoresLabel: String {
        localized("app.dashboard.cpu.active_cores.label", defaultValue: "Active Cores")
    }

    static var cpuPerCoreUsageTitle: String {
        localized("app.dashboard.cpu.per_core_usage.title", defaultValue: "Per-Core Usage")
    }

    static var cpuPerCoreUsageSubtitle: String {
        localized("app.dashboard.cpu.per_core_usage.subtitle", defaultValue: "Shown by logical cores reported by the system")
    }

    static var cpuPerCoreSampleTitle: String {
        localized("app.dashboard.cpu.per_core_sample.title", defaultValue: "Per-Core Sample")
    }

    static var memoryRealtimeStatsSubtitle: String {
        localized("app.dashboard.memory.realtime_stats.subtitle", defaultValue: "Live memory statistics")
    }

    static var memoryUsedTitle: String {
        localized("app.dashboard.memory.used.title", defaultValue: "Used")
    }

    static var memoryUsageTrendTitle: String {
        localized("app.dashboard.memory.usage_trend.title", defaultValue: "Usage Trend")
    }

    static var memoryTotalLabel: String {
        localized("app.dashboard.memory.total.label", defaultValue: "Total Memory")
    }

    static var memoryFreeLabel: String {
        localized("app.dashboard.memory.free.label", defaultValue: "Free")
    }

    static var memoryCachedLabel: String {
        localized("app.dashboard.memory.cached.label", defaultValue: "Cached")
    }

    static var memoryCompressedLabel: String {
        localized("app.dashboard.memory.compressed.label", defaultValue: "Compressed")
    }

    static var memorySwapLabel: String {
        localized("app.dashboard.memory.swap.label", defaultValue: "Swap")
    }

    static var memorySwapAvailableLabel: String {
        localized("app.dashboard.memory.swap_available.label", defaultValue: "Swap Available")
    }

    static var memorySwapTotalLabel: String {
        localized("app.dashboard.memory.swap_total.label", defaultValue: "Swap Total")
    }

    static var memoryCompositionTitle: String {
        localized("app.dashboard.memory.composition.title", defaultValue: "Composition")
    }

    static var memoryCompositionSubtitle: String {
        localized("app.dashboard.memory.composition.subtitle", defaultValue: "Unified memory friendly view")
    }

    static var memoryAppActiveLabel: String {
        localized("app.dashboard.memory.app_active.label", defaultValue: "App / Active")
    }

    static var memoryWiredLabel: String {
        localized("app.dashboard.memory.wired.label", defaultValue: "Wired")
    }

    static var memoryCachedFilesLabel: String {
        localized("app.dashboard.memory.cached_files.label", defaultValue: "Cached Files")
    }

    static var storageSpaceTitle: String {
        localized("app.dashboard.storage.space.title", defaultValue: "Storage Space")
    }

    static var storageLocalVolumeCapacitySubtitle: String {
        localized("app.dashboard.storage.local_volume_capacity.subtitle", defaultValue: "Local volume capacity")
    }

    static func storageUsedOfTotal(_ totalText: String) -> String {
        localizedFormat("app.dashboard.storage.used_of_total_format", defaultValue: "Used / %@", totalText)
    }

    static var storagePrimaryVolumeLabel: String {
        localized("app.dashboard.storage.primary_volume.label", defaultValue: "Primary Volume")
    }

    static var storageCapacityUsageTitle: String {
        localized("app.dashboard.storage.capacity_usage.title", defaultValue: "Capacity Usage")
    }

    static var storageCapacityStatsTitle: String {
        localized("app.dashboard.storage.capacity_stats.title", defaultValue: "Capacity Stats")
    }

    static var storageSystemVolumeInfoSource: String {
        localized("app.dashboard.storage.system_volume_info.source", defaultValue: "System volume information")
    }

    static var storagePrimaryAvailableTitle: String {
        localized("app.dashboard.storage.primary_available.title", defaultValue: "Primary Volume Available")
    }

    static var storageExternalVolumesTitle: String {
        localized("app.dashboard.storage.external_volumes.title", defaultValue: "External Volumes")
    }

    static var storageMountedVolumesSource: String {
        localized("app.dashboard.storage.mounted_volumes.source", defaultValue: "Mounted volumes")
    }

    static var storageVolumeListTitle: String {
        localized("app.dashboard.storage.volume_list.title", defaultValue: "Volume List")
    }

    static var storageVolumeListSubtitle: String {
        localized("app.dashboard.storage.volume_list.subtitle", defaultValue: "Mounted storage volumes")
    }

    static var storageColumnVolume: String {
        localized("app.dashboard.storage.column.volume", defaultValue: "Volume")
    }

    static var storageColumnFileSystem: String {
        localized("app.dashboard.storage.column.file_system", defaultValue: "File System")
    }

    static var storageColumnTotal: String {
        localized("app.dashboard.storage.column.total", defaultValue: "Total")
    }

    static var storageColumnUsed: String {
        localized("app.dashboard.storage.column.used", defaultValue: "Used")
    }

    static var storageColumnAvailable: String {
        localized("app.dashboard.storage.column.available", defaultValue: "Available")
    }

    static var storageColumnUsage: String {
        localized("app.dashboard.storage.column.usage", defaultValue: "Usage")
    }

    static var storageColumnKind: String {
        localized("app.dashboard.storage.column.kind", defaultValue: "Kind")
    }

    static var storageColumnAccess: String {
        localized("app.dashboard.storage.column.access", defaultValue: "Access")
    }

    static var storageVolumeTableColumns: [String] {
        [
            storageColumnVolume,
            storageColumnFileSystem,
            storageColumnTotal,
            storageColumnUsed,
            storageColumnAvailable,
            storageColumnUsage,
            storageColumnKind,
            storageColumnAccess
        ]
    }

    static var networkDownloadTitle: String {
        localized("app.dashboard.network.download.title", defaultValue: "Download")
    }

    static var networkUploadTitle: String {
        localized("app.dashboard.network.upload.title", defaultValue: "Upload")
    }

    static var networkTotalThroughputTitle: String {
        localized("app.dashboard.network.total_throughput.title", defaultValue: "Total Throughput")
    }

    static var networkConnectionStatusTitle: String {
        localized("app.dashboard.network.connection_status.title", defaultValue: "Connection Status")
    }

    static var networkInterfaceTitle: String {
        localized("app.dashboard.network.interface.title", defaultValue: "Interface")
    }

    static var networkRealtimeRateDetail: String {
        localized("app.dashboard.network.realtime_rate.detail", defaultValue: "Live Rate")
    }

    static var networkCombinedTrafficDetail: String {
        localized("app.dashboard.network.combined_traffic.detail", defaultValue: "Combined upload and download")
    }

    static var networkActiveInterfacesDetail: String {
        localized("app.dashboard.network.active_interfaces.detail", defaultValue: "Active Interfaces")
    }

    static var networkConnectivityTitle: String {
        localized("app.dashboard.network.connectivity.title", defaultValue: "Connectivity")
    }

    static var networkSystemPathSubtitle: String {
        localized("app.dashboard.network.system_path.subtitle", defaultValue: "System network path")
    }

    static var networkCapabilityLabel: String {
        localized("app.dashboard.network.capability.label", defaultValue: "Capability")
    }

    static var networkNameResolutionSource: String {
        localized("app.dashboard.network.name_resolution.source", defaultValue: "Name resolution")
    }

    static var networkLowDataModeLabel: String {
        localized("app.dashboard.network.low_data_mode.label", defaultValue: "Low Data Mode")
    }

    static var networkMeteredLabel: String {
        localized("app.dashboard.network.metered.label", defaultValue: "Metered Network")
    }

    static var networkInterfacesSubtitle: String {
        localized("app.dashboard.network.interfaces.subtitle", defaultValue: "Network interfaces and links")
    }

    static var networkColumnItem: String {
        localized("app.dashboard.network.column.item", defaultValue: "Item")
    }

    static var networkColumnCurrentValue: String {
        localized("app.dashboard.network.column.current_value", defaultValue: "Current Value")
    }

    static var networkColumnSource: String {
        localized("app.dashboard.network.column.source", defaultValue: "Source")
    }

    static var networkColumnInterface: String {
        localized("app.dashboard.network.column.interface", defaultValue: "Interface")
    }

    static var networkColumnType: String {
        localized("app.dashboard.network.column.type", defaultValue: "Type")
    }

    static var networkColumnStatus: String {
        localized("app.dashboard.network.column.status", defaultValue: "Status")
    }

    static var networkColumnLink: String {
        localized("app.dashboard.network.column.link", defaultValue: "Link")
    }

    static var networkColumnTraffic: String {
        localized("app.dashboard.network.column.traffic", defaultValue: "Traffic")
    }

    static var networkColumnPackets: String {
        localized("app.dashboard.network.column.packets", defaultValue: "Packets")
    }

    static var networkColumnErrors: String {
        localized("app.dashboard.network.column.errors", defaultValue: "Errors")
    }

    static var networkCapabilityTableColumns: [String] {
        [
            networkColumnItem,
            networkColumnCurrentValue,
            networkColumnSource
        ]
    }

    static var networkInterfaceTableColumns: [String] {
        [
            networkColumnInterface,
            networkColumnType,
            networkColumnStatus,
            "MTU",
            networkColumnLink,
            networkColumnTraffic,
            networkColumnPackets,
            networkColumnErrors
        ]
    }

    static var powerBatteryPanelTitle: String {
        localized("app.dashboard.power.battery_panel.title", defaultValue: "Power & Battery")
    }

    static var powerBatteryPanelSubtitle: String {
        localized("app.dashboard.power.battery_panel.subtitle", defaultValue: "Battery level and power source")
    }

    static var powerSourceLabel: String {
        localized("app.dashboard.power.source.label", defaultValue: "Power")
    }

    static var batteryRemainingTimeLabel: String {
        localized("app.dashboard.battery.remaining_time.label", defaultValue: "Time Remaining")
    }

    static var batteryCurrentCapacityLabel: String {
        localized("app.dashboard.battery.current_capacity.label", defaultValue: "Current Capacity")
    }

    static var batteryMaxCapacityLabel: String {
        localized("app.dashboard.battery.max_capacity.label", defaultValue: "Maximum Capacity")
    }

    static var batteryCycleCountLabel: String {
        localized("app.dashboard.battery.cycle_count.label", defaultValue: "Cycle Count")
    }

    static var batteryHealthLabel: String {
        localized("app.dashboard.battery.health.label", defaultValue: "Health")
    }

    static var batteryDesignCapacityLabel: String {
        localized("app.dashboard.battery.design_capacity.label", defaultValue: "Design Capacity")
    }

    static var batteryVoltageLabel: String {
        localized("app.dashboard.battery.voltage.label", defaultValue: "Voltage")
    }

    static var batteryCurrentLabel: String {
        localized("app.dashboard.battery.current.label", defaultValue: "Current")
    }

    static var statusCurrentStateTitle: String {
        localized("app.dashboard.status.current_state.title", defaultValue: "Current State")
    }

    static var statusPerformanceLimitTitle: String {
        localized("app.dashboard.status.performance_limit.title", defaultValue: "Performance Limit")
    }

    static var batteryInformationTitle: String {
        localized("app.dashboard.battery.information.title", defaultValue: "Battery Information")
    }

    static var batteryInformationSubtitle: String {
        localized("app.dashboard.battery.information.subtitle", defaultValue: "Battery level, power source, and estimated time")
    }

    static var tableColumnItem: String {
        localized("app.table.column.item", defaultValue: "Item")
    }

    static var tableColumnCurrentValue: String {
        localized("app.table.column.current_value", defaultValue: "Current Value")
    }

    static var tableColumnDescription: String {
        localized("app.table.column.description", defaultValue: "Description")
    }

    static var itemCurrentDescriptionTableColumns: [String] {
        [
            tableColumnItem,
            tableColumnCurrentValue,
            tableColumnDescription
        ]
    }

    static var sourceSystemEstimate: String {
        localized("app.source.system_estimate", defaultValue: "System estimate")
    }

    static var sourcePowerStatus: String {
        localized("app.source.power_status", defaultValue: "Power status")
    }

    static var sourceBatterySpecifications: String {
        localized("app.source.battery_specifications", defaultValue: "Battery specifications")
    }

    static var sourceBatteryHealth: String {
        localized("app.source.battery_health", defaultValue: "Battery health")
    }

    static var gpuUnifiedMemoryTitle: String {
        localized("app.dashboard.gpu.unified_memory.title", defaultValue: "Unified Memory")
    }

    static var sourceDeviceCapabilities: String {
        localized("app.source.device_capabilities", defaultValue: "Device capabilities")
    }

    static var sourceGPUCapabilities: String {
        localized("app.source.gpu_capabilities", defaultValue: "GPU capabilities")
    }

    static var gpuUnifiedMemoryPanelTitle: String {
        localized("app.dashboard.gpu.unified_memory.panel.title", defaultValue: "GPU & Unified Memory")
    }

    static var gpuUnifiedMemoryPanelSubtitle: String {
        localized("app.dashboard.gpu.unified_memory.panel.subtitle", defaultValue: "Reliable capability reporting for Apple Silicon first")
    }

    static var gpuColumnDevice: String {
        localized("app.dashboard.gpu.column.device", defaultValue: "Device")
    }

    static var gpuColumnKind: String {
        localized("app.dashboard.gpu.column.kind", defaultValue: "Kind")
    }

    static var gpuColumnUnifiedMemory: String {
        localized("app.dashboard.gpu.column.unified_memory", defaultValue: "Unified Memory")
    }

    static var gpuColumnRecommendedWorkingSet: String {
        localized("app.dashboard.gpu.column.recommended_working_set", defaultValue: "Recommended Working Set")
    }

    static var gpuColumnThreadgroupMemory: String {
        localized("app.dashboard.gpu.column.threadgroup_memory", defaultValue: "Threadgroup Memory")
    }

    static var gpuColumnThreadgroup: String {
        localized("app.dashboard.gpu.column.threadgroup", defaultValue: "Threadgroup")
    }

    static var gpuDeviceTableColumns: [String] {
        [
            gpuColumnDevice,
            gpuColumnKind,
            gpuColumnUnifiedMemory,
            gpuColumnRecommendedWorkingSet,
            gpuColumnThreadgroupMemory,
            gpuColumnThreadgroup,
            networkColumnStatus
        ]
    }

    static var displayPanelSubtitle: String {
        localized("app.dashboard.display.panel.subtitle", defaultValue: "Connected displays")
    }

    static var displayColumnScreen: String {
        localized("app.dashboard.display.column.screen", defaultValue: "Screen")
    }

    static var displayColumnPixels: String {
        localized("app.dashboard.display.column.pixels", defaultValue: "Pixels")
    }

    static var displayColumnMode: String {
        localized("app.dashboard.display.column.mode", defaultValue: "Mode")
    }

    static var displayColumnScale: String {
        localized("app.dashboard.display.column.scale", defaultValue: "Scale")
    }

    static var displayColumnColor: String {
        localized("app.dashboard.display.column.color", defaultValue: "Color")
    }

    static var displayColumnRefreshRate: String {
        localized("app.dashboard.display.column.refresh_rate", defaultValue: "Refresh Rate")
    }

    static var displayColumnSize: String {
        localized("app.dashboard.display.column.size", defaultValue: "Size")
    }

    static var displayColumnRotation: String {
        localized("app.dashboard.display.column.rotation", defaultValue: "Rotation")
    }

    static var displayTableColumns: [String] {
        [
            displayColumnScreen,
            displayColumnPixels,
            displayColumnMode,
            displayColumnScale,
            displayColumnColor,
            displayColumnRefreshRate,
            displayColumnSize,
            displayColumnRotation,
            networkColumnStatus
        ]
    }

    static var statusSupported: String {
        localized("app.status.supported", defaultValue: "Supported")
    }

    static var historyTrendsTitle: String {
        localized("app.dashboard.history.trends.title", defaultValue: "History Trends")
    }

    static var historyThresholdSettingsTitle: String {
        localized("app.dashboard.history.threshold_settings.title", defaultValue: "Threshold Settings")
    }

    static var historyThresholdSettingsSubtitle: String {
        localized("app.dashboard.history.threshold_settings.subtitle", defaultValue: "Local evaluation rules")
    }

    static var historyRuleCPUOver: String {
        localized("app.dashboard.history.rule.cpu_over", defaultValue: "CPU Over")
    }

    static var historyRuleMemoryHigh: String {
        localized("app.dashboard.history.rule.memory_high", defaultValue: "Memory High")
    }

    static var historyRuleDiskHigh: String {
        localized("app.dashboard.history.rule.disk_high", defaultValue: "Disk High")
    }

    static var widgetPreviewDescription: String {
        localized("app.dashboard.widget_preview.description", defaultValue: "The widget refreshes core status on the system timeline for quick local status checks.")
    }

    static var accessibilityTrendChart: String {
        localized("app.accessibility.trend_chart", defaultValue: "Trend Chart")
    }

    static var powerSupplyTrendTitle: String {
        localized("app.dashboard.power.trend.power_supply", defaultValue: "Power Supply")
    }

    static var powerBatteryHistoryTitle: String {
        localized("app.dashboard.power.trend.battery_history", defaultValue: "Battery History")
    }

    static func recentSampleCount(_ count: Int) -> String {
        localizedFormat("app.dashboard.history.recent_samples_format", defaultValue: "Recent %d samples", count)
    }

    static func recentSampleChipCount(_ count: Int) -> String {
        localizedFormat("app.dashboard.history.recent_samples_short_format", defaultValue: "Recent %d", count)
    }

    static func storageVolumeNumber(_ number: Int) -> String {
        localizedFormat("app.dashboard.storage.volume_number_format", defaultValue: "Volume %d", number)
    }

    static func openTitle(_ title: String) -> String {
        localizedFormat("app.action.open_title_format", defaultValue: "Open %@", title)
    }

    static func historySampleCount(_ count: Int) -> String {
        localizedFormat("app.history_depth.sample_count_format", defaultValue: "%d samples", count)
    }

    static func sourceThreshold(_ threshold: String) -> String {
        localizedFormat("app.dashboard.source.threshold_format", defaultValue: "Threshold %@", threshold)
    }

    static func settingsLocalHistoryDetail(sampleCount: Int) -> String {
        localizedFormat("app.settings.local_history.detail_format", defaultValue: "Keep the most recent %d samples", sampleCount)
    }

    static var processesRunningAppsTitle: String {
        localized("app.dashboard.processes.running_apps", defaultValue: "Running Apps")
    }

    static var processesForegroundAppsTitle: String {
        localized("app.dashboard.processes.foreground_apps", defaultValue: "Foreground Apps")
    }

    static var processesHiddenAppsTitle: String {
        localized("app.dashboard.processes.hidden_apps", defaultValue: "Hidden Apps")
    }

    static var processesDefaultSubtitle: String {
        localized("app.dashboard.processes.default_subtitle", defaultValue: "Foreground first, sorted by name")
    }

    static var processesColumnName: String {
        localized("app.dashboard.processes.column.name", defaultValue: "Name")
    }

    static var processesColumnState: String {
        localized("app.dashboard.processes.column.state", defaultValue: "State")
    }

    static var processesColumnArchitecture: String {
        localized("app.dashboard.processes.column.architecture", defaultValue: "Architecture")
    }

    static var processesColumnLaunch: String {
        localized("app.dashboard.processes.column.launch", defaultValue: "Launch")
    }

    static var processesTableColumns: [String] {
        [
            processesColumnName,
            processesColumnState,
            processesColumnArchitecture,
            processesColumnLaunch
        ]
    }

    static var statusThermalTitle: String {
        localized("app.dashboard.status.thermal.title", defaultValue: "Thermal State")
    }

    static var statusThermalSubtitle: String {
        localized("app.dashboard.status.thermal.subtitle", defaultValue: "System thermal control state")
    }

    static var statusRealtimeSignalsTitle: String {
        localized("app.dashboard.status.realtime_signals.title", defaultValue: "Live Signals")
    }

    static var statusRealtimeSignalsSubtitle: String {
        localized("app.dashboard.status.realtime_signals.subtitle", defaultValue: "Latest sample")
    }

    static var localRuleTableTitle: String {
        localized("app.dashboard.local_rules.title", defaultValue: "Local Rules")
    }

    static var localRuleTableSubtitle: String {
        localized("app.dashboard.local_rules.subtitle", defaultValue: "Current sample evaluated against local thresholds")
    }

    static var statusRuleColumnRule: String {
        localized("app.dashboard.status.rules.column.rule", defaultValue: "Rule")
    }

    static var statusRuleColumnThreshold: String {
        localized("app.dashboard.status.rules.column.threshold", defaultValue: "Threshold")
    }

    static var statusRuleColumnStatus: String {
        localized("app.dashboard.status.rules.column.status", defaultValue: "Status")
    }

    static var statusRuleTableColumns: [String] {
        [
            statusRuleColumnRule,
            statusRuleColumnThreshold,
            statusRuleColumnStatus
        ]
    }

    static var statusSystemSignalsTitle: String {
        localized("app.dashboard.status.system_signals.title", defaultValue: "System Signals")
    }

    static var statusSystemSignalsSubtitle: String {
        localized("app.dashboard.status.system_signals.subtitle", defaultValue: "Reported data in this view")
    }

    static var statusSignalColumnName: String {
        localized("app.dashboard.status.signals.column.name", defaultValue: "Name")
    }

    static var statusSignalColumnCurrentValue: String {
        localized("app.dashboard.status.signals.column.current_value", defaultValue: "Current Value")
    }

    static var statusSignalColumnSource: String {
        localized("app.dashboard.status.signals.column.source", defaultValue: "Source")
    }

    static var statusSignalTableColumns: [String] {
        [
            statusSignalColumnName,
            statusSignalColumnCurrentValue,
            statusSignalColumnSource
        ]
    }

    static var statusNormal: String {
        localized("app.status.normal", defaultValue: "Normal")
    }

    static var statusWarning: String {
        localized("app.status.warning", defaultValue: "Warning")
    }

    static var statusCritical: String {
        localized("app.status.critical", defaultValue: "Critical")
    }

    static var statusOnline: String {
        localized("app.status.online", defaultValue: "Online")
    }

    static var settingsSupportPrivacyTitle: String {
        localized("app.settings.support_privacy.title", defaultValue: "Support & Privacy")
    }

    static var settingsSupportPrivacySubtitle: String {
        localized("app.settings.support_privacy.subtitle", defaultValue: "Review information and public links")
    }

    static var settingsPrivacyPolicyTitle: String {
        localized("app.settings.privacy_policy.title", defaultValue: "Privacy Policy")
    }

    static var settingsPrivacyPolicyDetail: String {
        localized("app.settings.privacy_policy.detail", defaultValue: "Local sampling, no account, no tracking, no analytics, no remote probes")
    }

    static var settingsSupportTitle: String {
        localized("app.settings.support.title", defaultValue: "Support")
    }

    static var settingsSupportDetail: String {
        localized("app.settings.support.detail", defaultValue: "Contact channels and version support information")
    }

    static var settingsDataSourcesTitle: String {
        localized("app.settings.data_sources.title", defaultValue: "Data Sources")
    }

    static var settingsDataSourcesSubtitle: String {
        localized("app.settings.data_sources.subtitle", defaultValue: "System signals used on this page")
    }

    static var settingsDataSourceColumnFeature: String {
        localized("app.settings.data_sources.column.feature", defaultValue: "Feature")
    }

    static var settingsDataSourceColumnStatus: String {
        localized("app.settings.data_sources.column.status", defaultValue: "Status")
    }

    static var settingsDataSourceColumnSource: String {
        localized("app.settings.data_sources.column.source", defaultValue: "Source")
    }

    static var settingsDataSourceTableColumns: [String] {
        [
            settingsDataSourceColumnFeature,
            settingsDataSourceColumnStatus,
            settingsDataSourceColumnSource
        ]
    }

    static var settingsRefreshDisplayTitle: String {
        localized("app.settings.refresh_display.title", defaultValue: "Refresh & Display")
    }

    static var settingsRefreshDisplaySubtitle: String {
        localized("app.settings.refresh_display.subtitle", defaultValue: "Low wakeups, readability first")
    }

    static var settingsMainWindowRefreshTitle: String {
        localized("app.settings.main_window_refresh.title", defaultValue: "Main Window Refresh")
    }

    static var settingsMainWindowRefreshDetail: String {
        localized("app.settings.main_window_refresh.detail", defaultValue: "Live trends and status cards")
    }

    static var settingsMenuBarStatusTitle: String {
        localized("app.settings.menu_bar_status.title", defaultValue: "Menu Bar Status")
    }

    static var settingsMenuBarStatusDetail: String {
        localized("app.settings.menu_bar_status.detail", defaultValue: "Show current CPU usage")
    }

    static var settingsMenuBarCPULabel: String {
        localized("app.settings.menu_bar_cpu.label", defaultValue: "Menu Bar CPU")
    }

    static var settingsWidgetRefreshTitle: String {
        localized("app.settings.widget_refresh.title", defaultValue: "Widget Refresh")
    }

    static var settingsWidgetRefreshDetail: String {
        localized("app.settings.widget_refresh.detail", defaultValue: "Requested about every 5 minutes by the system timeline")
    }

    static var settingsLocalHistoryTitle: String {
        localized("app.settings.local_history.title", defaultValue: "Local History")
    }

    static var settingsWidgetTitle: String {
        localized("app.settings.widget.title", defaultValue: "Widget")
    }

    static var settingsWidgetSubtitle: String {
        localized("app.settings.widget.subtitle", defaultValue: "Desktop status preview")
    }

    static var settingsWidgetSizeLabel: String {
        localized("app.settings.widget.size.label", defaultValue: "Size")
    }

    static var settingsWidgetSizesValue: String {
        localized("app.settings.widget.size.value", defaultValue: "Small / Medium / Large")
    }

    static var settingsWidgetDataSourceLabel: String {
        localized("app.settings.widget.data_source.label", defaultValue: "Data Source")
    }

    static var settingsWidgetDataSourceValue: String {
        localized("app.settings.widget.data_source.value", defaultValue: "System Sampling")
    }

    static var settingsWidgetRefreshLabel: String {
        localized("app.settings.widget.refresh.label", defaultValue: "Refresh")
    }

    static var settingsWidgetRefreshValue: String {
        localized("app.settings.widget.refresh.value", defaultValue: "System Scheduled")
    }

    static var settingsWidgetSampleLabel: String {
        localized("app.settings.widget.sample.label", defaultValue: "Sample")
    }

    static var settingsWidgetHistoryLabel: String {
        localized("app.settings.widget.history.label", defaultValue: "History")
    }

    static var settingsWidgetMainWindowLabel: String {
        localized("app.settings.widget.main_window.label", defaultValue: "Main Window")
    }

    static var activationPolicyRegular: String {
        localized("app.running_app.activation.regular", defaultValue: "Regular")
    }

    static var activationPolicyAccessory: String {
        localized("app.running_app.activation.accessory", defaultValue: "Accessory")
    }

    static var activationPolicyBackground: String {
        localized("app.running_app.activation.background", defaultValue: "Background")
    }

    static var systemDidNotReport: String {
        localized("app.system.did_not_report", defaultValue: "System did not report")
    }

    static var notReported: String {
        SharedMetricStrings.notReported
    }

    static var metricMemory: String {
        localized("app.metric.memory", defaultValue: "Memory")
    }

    static var metricCPU: String {
        localized("app.metric.cpu", defaultValue: "CPU")
    }

    static var metricNetwork: String {
        localized("app.metric.network", defaultValue: "Network")
    }

    static var metricNetworkConnection: String {
        localized("app.metric.network_connection", defaultValue: "Network Connection")
    }

    static var metricDisk: String {
        localized("app.metric.disk", defaultValue: "Disk")
    }

    static var metricGPU: String {
        localized("app.metric.gpu", defaultValue: "GPU")
    }

    static var metricThermalState: String {
        localized("app.metric.thermal_state", defaultValue: "Thermal")
    }

    static var metricSystemThermalState: String {
        localized("app.metric.system_thermal_state", defaultValue: "System Thermal State")
    }

    static var metricLoad: String {
        localized("app.metric.load", defaultValue: "Load")
    }

    static var metricDisplays: String {
        localized("app.metric.displays", defaultValue: "Displays")
    }

    static var metricVolumes: String {
        localized("app.metric.volumes", defaultValue: "Volumes")
    }

    static var metricUptime: String {
        localized("app.metric.uptime", defaultValue: "Uptime")
    }

    static var metricKernel: String {
        localized("app.metric.kernel", defaultValue: "Kernel")
    }

    static var metricKernelVersion: String {
        localized("app.metric.kernel_version", defaultValue: "Kernel Version")
    }

    static var metricCPUMemory: String {
        localized("app.metric.cpu_memory", defaultValue: "CPU / Memory")
    }

    static var metricRunningApps: String {
        localized("app.metric.running_apps", defaultValue: "Running Apps")
    }

    static var metricGPUDisplays: String {
        localized("app.metric.gpu_displays", defaultValue: "GPU / Displays")
    }

    static var metricVolumeCapacity: String {
        localized("app.metric.volume_capacity", defaultValue: "Volume Capacity")
    }

    static var metricPowerThermalState: String {
        localized("app.metric.power_thermal_state", defaultValue: "Power / Thermal State")
    }

    static var metricSystemVersionUptimeKernel: String {
        localized("app.metric.system_version_uptime_kernel", defaultValue: "System Version / Uptime / Kernel Version")
    }

    static var sourceFileSystemCapacity: String {
        localized("app.source.file_system_capacity", defaultValue: "File system capacity")
    }

    static var sourceLoadAverages: String {
        localized("app.source.load_averages", defaultValue: "1 / 5 / 15 minutes")
    }

    static var sourceThermalState: String {
        localized("app.source.thermal_state", defaultValue: "Thermal control state")
    }

    static var sourceSystemVersion: String {
        localized("app.source.system_version", defaultValue: "System version")
    }

    static var sourceDisplayConfiguration: String {
        localized("app.source.display_configuration", defaultValue: "Display configuration")
    }

    static var sourceSystemProcessorMemoryStats: String {
        localized("app.source.system_processor_memory_stats", defaultValue: "System processor and memory statistics")
    }

    static var sourceConnectionInterfaceTraffic: String {
        localized("app.source.connection_interface_traffic", defaultValue: "Connection status and interface traffic")
    }

    static var sourceApplicationSessionList: String {
        localized("app.source.application_session_list", defaultValue: "Application session list")
    }

    static var sourceGraphicsDisplayConfiguration: String {
        localized("app.source.graphics_display_configuration", defaultValue: "Graphics devices and display configuration")
    }

    static var sourcePowerThermalState: String {
        localized("app.source.power_thermal_state", defaultValue: "Power and thermal control state")
    }

    static var sourceSystemVersionBootTime: String {
        localized("app.source.system_version_boot_time", defaultValue: "System version and boot time")
    }

    static var menuOpenMainWindow: String {
        localized("app.menu_popover.action.open_main_window", defaultValue: "Open Window")
    }

    static var menuResumeRefresh: String {
        localized("app.menu_popover.action.resume_refresh", defaultValue: "Resume")
    }

    static var menuPauseRefresh: String {
        localized("app.menu_popover.action.pause_refresh", defaultValue: "Pause")
    }

    static var menuSettings: String {
        localized("app.menu_popover.action.settings", defaultValue: "Settings")
    }

    static var menuStatusPaused: String {
        localized("app.menu_popover.status.paused", defaultValue: "Paused")
    }

    static var menuStatusLive: String {
        localized("app.menu_popover.status.live", defaultValue: "Live")
    }

    static var mainMenuAbout: String {
        localized("app.main_menu.about", defaultValue: "About Pulse Dock")
    }

    static var mainMenuSettings: String {
        localized("app.main_menu.settings", defaultValue: "Settings...")
    }

    static var mainMenuPrivacyPolicy: String {
        localized("app.main_menu.privacy_policy", defaultValue: "Privacy Policy")
    }

    static var mainMenuSupport: String {
        localized("app.main_menu.support", defaultValue: "Support")
    }

    static var mainMenuServices: String {
        localized("app.main_menu.services", defaultValue: "Services")
    }

    static var mainMenuHideApp: String {
        localized("app.main_menu.hide_app", defaultValue: "Hide Pulse Dock")
    }

    static var mainMenuHideOthers: String {
        localized("app.main_menu.hide_others", defaultValue: "Hide Others")
    }

    static var mainMenuShowAll: String {
        localized("app.main_menu.show_all", defaultValue: "Show All")
    }

    static var mainMenuQuitApp: String {
        localized("app.main_menu.quit_app", defaultValue: "Quit Pulse Dock")
    }

    static var mainMenuEdit: String {
        localized("app.main_menu.edit", defaultValue: "Edit")
    }

    static var mainMenuUndo: String {
        localized("app.main_menu.undo", defaultValue: "Undo")
    }

    static var mainMenuRedo: String {
        localized("app.main_menu.redo", defaultValue: "Redo")
    }

    static var mainMenuCut: String {
        localized("app.main_menu.cut", defaultValue: "Cut")
    }

    static var mainMenuCopy: String {
        localized("app.main_menu.copy", defaultValue: "Copy")
    }

    static var mainMenuPaste: String {
        localized("app.main_menu.paste", defaultValue: "Paste")
    }

    static var mainMenuDelete: String {
        localized("app.main_menu.delete", defaultValue: "Delete")
    }

    static var mainMenuSelectAll: String {
        localized("app.main_menu.select_all", defaultValue: "Select All")
    }

    static var mainMenuView: String {
        localized("app.main_menu.view", defaultValue: "View")
    }

    static var mainMenuShowOverview: String {
        localized("app.main_menu.show_overview", defaultValue: "Show Overview")
    }

    static var mainMenuOpenSettings: String {
        localized("app.main_menu.open_settings", defaultValue: "Open Settings")
    }

    static var mainMenuWindow: String {
        localized("app.main_menu.window", defaultValue: "Window")
    }

    static var mainMenuMinimize: String {
        localized("app.main_menu.minimize", defaultValue: "Minimize")
    }

    static var mainMenuZoom: String {
        localized("app.main_menu.zoom", defaultValue: "Zoom")
    }

    static var mainMenuBringAllToFront: String {
        localized("app.main_menu.bring_all_to_front", defaultValue: "Bring All to Front")
    }

    static func localized(
        _ key: String,
        defaultValue: String,
        bundle: Bundle = .pulseDockAppLocalization
    ) -> String {
        bundle.localizedString(forKey: key, value: defaultValue, table: "PulseDockApp")
    }

    private static func localizedFormat(
        _ key: String,
        defaultValue: String,
        _ arguments: CVarArg...
    ) -> String {
        String(format: localized(key, defaultValue: defaultValue), locale: Locale.current, arguments: arguments)
    }
}

private extension Bundle {
    static var pulseDockAppLocalization: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
}
