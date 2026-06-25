import Foundation

extension MetricSnapshot {
    public func widgetCompactSnapshot() -> MetricSnapshot {
        MetricSnapshot(
            cpuUsage: cpuUsage,
            cpuCoreUsages: cpuCoreUsages,
            hasCPUUsageReport: hasCPUUsageReport,
            physicalCoreCount: physicalCoreCount,
            logicalCoreCount: logicalCoreCount,
            activeProcessorCount: activeProcessorCount,
            cpuBrandName: nil,
            memoryUsedBytes: memoryUsedBytes,
            memoryTotalBytes: memoryTotalBytes,
            memorySwapUsedBytes: memorySwapUsedBytes,
            memorySwapTotalBytes: memorySwapTotalBytes,
            memorySwapAvailableBytes: memorySwapAvailableBytes,
            loadAverage: loadAverage,
            loadAverage5: loadAverage5,
            loadAverage15: loadAverage15,
            hasLoadAverageReport: hasLoadAverageReport,
            thermalState: thermalState,
            batteryPercent: batteryPercent,
            batteryIsCharging: batteryIsCharging,
            batteryPowerSource: batteryPowerSource,
            batteryTimeRemainingMinutes: batteryTimeRemainingMinutes,
            batteryCurrentCapacity: batteryCurrentCapacity,
            batteryMaxCapacity: batteryMaxCapacity,
            hasNetworkByteCounters: false,
            hasNetworkDirectionByteCounters: false,
            networkPathStatus: networkPathStatus,
            networkPathIsExpensive: networkPathIsExpensive,
            networkPathIsConstrained: networkPathIsConstrained,
            hasNetworkPathCostReport: hasNetworkPathCostReport,
            networkPathSupportsDNS: networkPathSupportsDNS,
            networkPathSupportsIPv4: networkPathSupportsIPv4,
            networkPathSupportsIPv6: networkPathSupportsIPv6,
            hasNetworkPathSupportReport: hasNetworkPathSupportReport,
            networkPathInterfaceKinds: networkPathInterfaceKinds,
            networkInBytesPerSecond: 0,
            networkOutBytesPerSecond: 0,
            networkInterfaces: compactWidgetInterfaces(),
            diskFreeBytes: diskFreeBytes,
            diskTotalBytes: diskTotalBytes,
            storageVolumes: [],
            processCount: 0,
            activeApplicationCount: 0,
            hiddenApplicationCount: 0,
            hasRunningAppCountReport: false,
            runningApps: [],
            gpuDevices: [],
            displays: [],
            uptimeSeconds: uptimeSeconds,
            hasUptimeReport: hasUptimeReport,
            osVersion: osVersion,
            kernelRelease: kernelRelease,
            timestamp: timestamp
        )
    }

    private func compactWidgetInterfaces() -> [NetworkInterfaceMetric] {
        networkInterfaces
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
}
