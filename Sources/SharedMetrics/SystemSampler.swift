import Foundation
import Darwin
import CoreGraphics
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
#if canImport(AppKit)
import AppKit
#endif
#if canImport(Network)
import Network
#endif
#if canImport(Metal)
import Metal
#endif
#if canImport(SystemConfiguration)
import SystemConfiguration
#endif

private struct BatterySample {
    var percent: Double? = nil
    var isCharging = false
    var powerSource: String? = nil
    var timeRemainingMinutes: Int? = nil
    var cycleCount: Int? = nil
    var health: String? = nil
    var currentCapacity: Int? = nil
    var maxCapacity: Int? = nil
    var designCapacity: Int? = nil
    var voltageMillivolts: Int? = nil
    var amperageMilliamps: Int? = nil
}

private struct StorageSample {
    var primary: StorageVolumeMetric?
    var volumes: [StorageVolumeMetric]
}

private struct SystemInfoSample {
    var physicalCoreCount: Int
    var logicalCoreCount: Int
    var cpuBrandName: String?
    var osVersion: String
    var kernelRelease: String
}

private struct TimedSample<Value> {
    var timestamp: Date
    var value: Value
}

private struct DisplayColorSpaceSample {
    var model: String
    var componentCount: Int
}

private struct StorageVolumeCandidate {
    var mountPath: String
    var metric: StorageVolumeMetric
}

private struct NetworkInterfaceAccumulator {
    var name: String
    var displayName: String
    var kind: String
    var sortKind: String
    var isUp = false
    var isLoopback = false
    var bytesReceived: UInt64 = 0
    var bytesSent: UInt64 = 0
    var hasByteCounters = false
    var packetsReceived: UInt64?
    var packetsSent: UInt64?
    var receiveErrors: UInt64?
    var sendErrors: UInt64?
    var linkSpeedBitsPerSecond: UInt64?
    var mtu: Int?

    func metric(index: Int) -> NetworkInterfaceMetric {
        NetworkInterfaceMetric(
            index: index,
            displayName: displayName,
            kind: kind,
            isUp: isUp,
            isLoopback: isLoopback,
            hasInterfaceStateReport: true,
            bytesReceived: bytesReceived,
            bytesSent: bytesSent,
            hasByteCounters: hasByteCounters,
            packetsReceived: packetsReceived,
            packetsSent: packetsSent,
            receiveErrors: receiveErrors,
            sendErrors: sendErrors,
            linkSpeedBitsPerSecond: linkSpeedBitsPerSecond,
            mtu: mtu
        )
    }
}

private struct NetworkInterfaceDescriptor {
    var displayName: String
    var kind: String
    var sortKind: String
}

private struct NetworkInterfaceStats64 {
    var bytesReceived: UInt64
    var bytesSent: UInt64
    var packetsReceived: UInt64
    var packetsSent: UInt64
    var receiveErrors: UInt64
    var sendErrors: UInt64
    var linkSpeedBitsPerSecond: UInt64?
    var mtu: Int?
}

struct NetworkPathSample: Sendable {
    var status = "unknown"
    var isExpensive = false
    var isConstrained = false
    var hasCostReport = false
    var supportsDNS = false
    var supportsIPv4 = false
    var supportsIPv6 = false
    var hasSupportReport = false
    var interfaceKinds: [String] = []
}

protocol NetworkPathObserving: Sendable {
    var current: NetworkPathSample { get }
}

#if canImport(Network)
private final class NetworkPathObserver: NetworkPathObserving, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "local.pulsedock.network-path", qos: .utility)
    private let lock = NSLock()
    private var latest = NetworkPathSample()

    init() {
        latest = Self.sample(from: monitor.currentPath)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.store(Self.sample(from: path))
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    var current: NetworkPathSample {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }

    private func store(_ sample: NetworkPathSample) {
        lock.lock()
        latest = sample
        lock.unlock()
    }

    private static func sample(from path: NWPath) -> NetworkPathSample {
        NetworkPathSample(
            status: statusText(path.status),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            hasCostReport: true,
            supportsDNS: path.supportsDNS,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6,
            hasSupportReport: true,
            interfaceKinds: interfaceKinds(from: path)
        )
    }

    private static func statusText(_ status: NWPath.Status) -> String {
        switch status {
        case .satisfied:
            return "satisfied"
        case .unsatisfied:
            return "unsatisfied"
        case .requiresConnection:
            return "requiresConnection"
        @unknown default:
            return "unknown"
        }
    }

    private static func interfaceKinds(from path: NWPath) -> [String] {
        var kinds: [String] = []
        if path.usesInterfaceType(.wifi) { kinds.append("Wi-Fi") }
        if path.usesInterfaceType(.wiredEthernet) { kinds.append("Ethernet") }
        if path.usesInterfaceType(.cellular) { kinds.append("Cellular") }
        if path.usesInterfaceType(.loopback) { kinds.append("Loopback") }
        if path.usesInterfaceType(.other) { kinds.append(SharedMetricStrings.other) }
        return kinds
    }
}
#else
private final class NetworkPathObserver: NetworkPathObserving {
    var current: NetworkPathSample { NetworkPathSample() }
}
#endif

public final class SystemSampler: @unchecked Sendable {
    private let sampleLock = NSLock()
    private var previousCPUInfo: [processor_cpu_load_info] = []
    private var previousNetworkInBytes: UInt64?
    private var previousNetworkOutBytes: UInt64?
    private var previousNetworkDate: Date?
    private let inventoryCacheInterval: TimeInterval
    private let batteryCacheInterval: TimeInterval
    private let systemInfo: SystemInfoSample
    private var storageCache: TimedSample<StorageSample>?
    private var batteryCache: TimedSample<BatterySample>?
    private var gpuDevicesCache: TimedSample<[GPUDeviceMetric]>?
    private var displaysCache: TimedSample<[DisplayMetric]>?
    private var networkInterfaceDescriptorCache: TimedSample<[String: NetworkInterfaceDescriptor]>?
    private let networkPathObserver: any NetworkPathObserving

    public convenience init(inventoryCacheInterval: TimeInterval = 15, batteryCacheInterval: TimeInterval = 5) {
        self.init(
            inventoryCacheInterval: inventoryCacheInterval,
            batteryCacheInterval: batteryCacheInterval,
            networkPathObserver: NetworkPathObserver()
        )
    }

    init(
        inventoryCacheInterval: TimeInterval = 15,
        batteryCacheInterval: TimeInterval = 5,
        networkPathObserver: any NetworkPathObserving
    ) {
        self.inventoryCacheInterval = max(0, inventoryCacheInterval)
        self.batteryCacheInterval = max(0, batteryCacheInterval)
        self.networkPathObserver = networkPathObserver
        self.systemInfo = Self.sampleSystemInfo()
    }

    public func resetNetworkBaselines() {
        sampleLock.lock()
        defer { sampleLock.unlock() }

        previousNetworkInBytes = nil
        previousNetworkOutBytes = nil
        previousNetworkDate = nil
    }

    public func resetCPUBaselines() {
        sampleLock.lock()
        defer { sampleLock.unlock() }

        previousCPUInfo = []
    }

    public func sample(now: Date = Date()) -> MetricSnapshot {
        sampleLock.lock()
        defer { sampleLock.unlock() }

        let memory = sampleMemory()
        let networkInterfaces = sampleNetworkInterfaces(now: now)
        let hasNetworkByteCounters = networkInterfaces.contains { $0.hasByteCounters }
        let networkTotal = networkTotals(from: networkInterfaces)
        let networkRate = sampleNetworkRate(totalBytes: networkTotal, hasByteCounters: hasNetworkByteCounters, now: now)
        let networkPath = networkPathObserver.current
        let battery = cachedBattery(now: now)
        let cpu = sampleCPUUsage()
        let loads = sampleLoadAverages()
        let storage = cachedStorage(now: now)
        let disk = storage.primary.flatMap { primary in
            primary.reportedAvailableBytes.map { (free: $0, total: primary.totalBytes) }
        } ?? sampleDiskSpace()
        let gpuDevices = cachedGPUDevices(now: now)
        let displays = cachedDisplays(now: now)
        let uptimeSeconds = ProcessInfo.processInfo.systemUptime

        return MetricSnapshot(
            cpuUsage: cpu.total,
            cpuCoreUsages: cpu.cores,
            hasCPUUsageReport: cpu.isReported,
            physicalCoreCount: systemInfo.physicalCoreCount,
            logicalCoreCount: systemInfo.logicalCoreCount,
            activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
            cpuBrandName: systemInfo.cpuBrandName,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            memoryFreeBytes: memory.free,
            memoryWiredBytes: memory.wired,
            memoryCompressedBytes: memory.compressed,
            memoryCachedBytes: memory.cached,
            memorySwapUsedBytes: memory.swapUsed,
            memorySwapTotalBytes: memory.swapTotal,
            memorySwapAvailableBytes: memory.swapAvailable,
            hasMemoryCompositionReport: memory.hasCompositionReport,
            loadAverage: loads.one,
            loadAverage5: loads.five,
            loadAverage15: loads.fifteen,
            hasLoadAverageReport: loads.isReported,
            thermalState: sampleThermalState(),
            batteryPercent: battery.percent,
            batteryIsCharging: battery.isCharging,
            batteryPowerSource: battery.powerSource,
            batteryTimeRemainingMinutes: battery.timeRemainingMinutes,
            batteryCycleCount: battery.cycleCount,
            batteryHealth: battery.health,
            batteryCurrentCapacity: battery.currentCapacity,
            batteryMaxCapacity: battery.maxCapacity,
            batteryDesignCapacity: battery.designCapacity,
            batteryVoltageMillivolts: battery.voltageMillivolts,
            batteryAmperageMilliamps: battery.amperageMilliamps,
            networkBytesPerSecond: networkRate.total,
            hasNetworkByteCounters: hasNetworkByteCounters,
            hasNetworkDirectionByteCounters: hasNetworkByteCounters,
            networkPathStatus: networkPath.status,
            networkPathIsExpensive: networkPath.isExpensive,
            networkPathIsConstrained: networkPath.isConstrained,
            hasNetworkPathCostReport: networkPath.hasCostReport,
            networkPathSupportsDNS: networkPath.supportsDNS,
            networkPathSupportsIPv4: networkPath.supportsIPv4,
            networkPathSupportsIPv6: networkPath.supportsIPv6,
            hasNetworkPathSupportReport: networkPath.hasSupportReport,
            networkPathInterfaceKinds: networkPath.interfaceKinds,
            networkInBytesPerSecond: networkRate.input,
            networkOutBytesPerSecond: networkRate.output,
            networkInterfaces: networkInterfaces,
            diskFreeBytes: disk.free,
            diskTotalBytes: disk.total,
            storageVolumes: storage.volumes,
            gpuDevices: gpuDevices,
            displays: displays,
            uptimeSeconds: uptimeSeconds,
            hasUptimeReport: true,
            osVersion: systemInfo.osVersion,
            kernelRelease: systemInfo.kernelRelease,
            timestamp: now
        )
    }

    private func sampleCPUUsage() -> (total: Double, cores: [Double], isReported: Bool) {
        var processorInfo: processor_info_array_t?
        var processorMsgCount = mach_msg_type_number_t(0)
        var processorCount = natural_t(0)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        let result = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorMsgCount
        )

        guard result == KERN_SUCCESS, let processorInfo else { return (0, [], isReported: false) }

        defer {
            let size = vm_size_t(processorMsgCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: processorInfo)), size)
        }

        let info = processorInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(processorCount)) {
            Array(UnsafeBufferPointer(start: $0, count: Int(processorCount)))
        }

        guard previousCPUInfo.count == info.count else {
            previousCPUInfo = info
            return (0, [], isReported: false)
        }

        var totalTicks: UInt64 = 0
        var idleTicks: UInt64 = 0
        var coreUsages: [Double] = []

        for index in info.indices {
            let current = tickArray(info[index].cpu_ticks)
            let previous = tickArray(previousCPUInfo[index].cpu_ticks)
            var coreTotalTicks: UInt64 = 0
            var coreIdleTicks: UInt64 = 0

            for tickIndex in 0..<Int(CPU_STATE_MAX) {
                let delta = current[tickIndex] >= previous[tickIndex] ? UInt64(current[tickIndex] - previous[tickIndex]) : 0
                totalTicks += delta
                coreTotalTicks += delta

                if tickIndex == Int(CPU_STATE_IDLE) {
                    idleTicks += delta
                    coreIdleTicks += delta
                }
            }

            if coreTotalTicks > 0 {
                coreUsages.append(1 - (Double(coreIdleTicks) / Double(coreTotalTicks)))
            } else {
                coreUsages.append(0)
            }
        }

        previousCPUInfo = info

        guard totalTicks > 0 else { return (0, coreUsages, isReported: false) }
        return (1 - (Double(idleTicks) / Double(totalTicks)), coreUsages, isReported: totalTicks > 0)
    }

    private func sampleMemory() -> (
        used: UInt64,
        total: UInt64,
        free: UInt64,
        wired: UInt64,
        compressed: UInt64,
        cached: UInt64,
        swapUsed: UInt64,
        swapTotal: UInt64,
        swapAvailable: UInt64,
        hasCompositionReport: Bool
    ) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory
        let swap = sampleSwapUsage()
        guard result == KERN_SUCCESS else {
            return (0, 0, 0, 0, 0, 0, swap.used, swap.total, swap.available, false)
        }

        var pageSize = vm_size_t(0)
        guard host_page_size(host, &pageSize) == KERN_SUCCESS, pageSize > 0 else {
            return (0, 0, 0, 0, 0, 0, swap.used, swap.total, swap.available, false)
        }
        let pageBytes = UInt64(pageSize)
        let usedPages = UInt64(stats.active_count + stats.wire_count + stats.compressor_page_count)
        let cachedPages = UInt64(stats.inactive_count + stats.purgeable_count)
        let reclaimableFreePages = UInt64(stats.free_count + stats.speculative_count)

        return (
            usedPages * pageBytes,
            total,
            reclaimableFreePages * pageBytes,
            UInt64(stats.wire_count) * pageBytes,
            UInt64(stats.compressor_page_count) * pageBytes,
            cachedPages * pageBytes,
            swap.used,
            swap.total,
            swap.available,
            true
        )
    }

    private func sampleSwapUsage() -> (used: UInt64, total: UInt64, available: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else {
            return (0, 0, 0)
        }

        return (
            UInt64(usage.xsu_used),
            UInt64(usage.xsu_total),
            UInt64(usage.xsu_avail)
        )
    }

    private func sampleLoadAverages() -> (one: Double, five: Double, fifteen: Double, isReported: Bool) {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) == 3 else { return (0, 0, 0, false) }
        return (loads[0], loads[1], loads[2], true)
    }

    private static func sampleSystemInfo() -> SystemInfoSample {
        SystemInfoSample(
            physicalCoreCount: Self.sysctlInteger("hw.physicalcpu") ?? ProcessInfo.processInfo.processorCount,
            logicalCoreCount: Self.sysctlInteger("hw.logicalcpu") ?? ProcessInfo.processInfo.activeProcessorCount,
            cpuBrandName: Self.sysctlString("machdep.cpu.brand_string"),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            kernelRelease: sampleKernelRelease()
        )
    }

    private static func sampleKernelRelease() -> String {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return "" }
        return Self.stringFromFixedCString(systemInfo.release)
    }

    private func sampleThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Warm"
        case .serious:
            return "Hot"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }

    private func sampleBattery() -> BatterySample {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatterySample(
                percent: nil,
                isCharging: false,
                powerSource: nil,
                timeRemainingMinutes: nil
            )
        }

        let providingPowerSource = providingPowerSourceText(info)
        guard let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return BatterySample(
                percent: nil,
                isCharging: false,
                powerSource: providingPowerSource,
                timeRemainingMinutes: nil
            )
        }

        let descriptions = powerSourceDescriptions(info: info, sources: sources)
        guard let description = preferredBatteryDescription(from: descriptions) else {
            return BatterySample(
                percent: nil,
                isCharging: false,
                powerSource: providingPowerSource,
                timeRemainingMinutes: nil
            )
        }

        let current = doubleValue(description[kIOPSCurrentCapacityKey])
        let maximum = doubleValue(description[kIOPSMaxCapacityKey])
        let powerSource = description[kIOPSPowerSourceStateKey] as? String ?? providingPowerSource
        let reportedIsCharging = description[kIOPSIsChargingKey] as? Bool
        let isCharging = reportedIsCharging ?? false
        let timeToEmpty = validBatteryMinutes(intValue(description[kIOPSTimeToEmptyKey]))
        let timeToFull = validBatteryMinutes(intValue(description[kIOPSTimeToFullChargeKey]))
        let estimatedDischargeMinutes = estimatedBatteryDischargeMinutes()
        let timeRemaining = isCharging ? timeToFull : (timeToEmpty ?? estimatedDischargeMinutes)
        let health = description[kIOPSBatteryHealthKey] as? String
            ?? description[kIOPSBatteryHealthConditionKey] as? String
        let percent = maximum.flatMap { maxValue -> Double? in
            guard let current, maxValue > 0 else { return nil }
            return current / maxValue
        }

        return BatterySample(
            percent: percent,
            isCharging: isCharging,
            powerSource: powerSource,
            timeRemainingMinutes: timeRemaining,
            cycleCount: intValue(description[kIOBatteryCycleCountKey]),
            health: health,
            currentCapacity: finiteInt(current),
            maxCapacity: finiteInt(maximum),
            designCapacity: intValue(description[kIOPSDesignCapacityKey]),
            voltageMillivolts: intValue(description[kIOPSVoltageKey]) ?? intValue(description[kIOBatteryVoltageKey]),
            amperageMilliamps: intValue(description[kIOBatteryAmperageKey])
        )
    }

    private func providingPowerSourceText(_ info: CFTypeRef) -> String? {
        IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
    }

    private func powerSourceDescriptions(info: CFTypeRef, sources: [CFTypeRef]) -> [[String: Any]] {
        sources.compactMap { source in
            IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        }
    }

    private func preferredBatteryDescription(from descriptions: [[String: Any]]) -> [String: Any]? {
        if let internalBattery = descriptions.first(where: { description in
            description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }) {
            return internalBattery
        }

        if let capacityBearingPowerSource = descriptions.first(where: { description in
            doubleValue(description[kIOPSCurrentCapacityKey]) != nil &&
                doubleValue(description[kIOPSMaxCapacityKey]) != nil
        }) {
            return capacityBearingPowerSource
        }

        return descriptions.first
    }

    private func sampleNetworkInterfaces(now: Date) -> [NetworkInterfaceMetric] {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let interfaces else { return [] }
        defer { freeifaddrs(interfaces) }

        let descriptors = cachedNetworkInterfaceDescriptors(now: now)
        let interfaceStats = networkInterfaceStatsByIndex()
        var records: [String: NetworkInterfaceAccumulator] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = interfaces

        while let current = cursor {
            let name = String(cString: current.pointee.ifa_name)
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            let fallbackSortKind = interfaceSortKind(name)
            let fallbackKind = interfaceKindDisplayName(sortKind: fallbackSortKind)
            let descriptor = descriptors[name]
            var record = records[name] ?? NetworkInterfaceAccumulator(
                name: name,
                displayName: descriptor?.displayName ?? interfaceDisplayName(forKind: fallbackSortKind),
                kind: descriptor?.kind ?? fallbackKind,
                sortKind: descriptor?.sortKind ?? fallbackSortKind
            )

            record.isUp = record.isUp || isUp
            record.isLoopback = record.isLoopback || isLoopback

            if let address = current.pointee.ifa_addr,
               address.pointee.sa_family == UInt8(AF_LINK),
               let data = current.pointee.ifa_data {
                let interfaceIndex = name.withCString { if_nametoindex($0) }
                if let stats = interfaceStats[interfaceIndex] {
                    record.bytesReceived = stats.bytesReceived
                    record.bytesSent = stats.bytesSent
                    record.hasByteCounters = true
                    record.packetsReceived = stats.packetsReceived
                    record.packetsSent = stats.packetsSent
                    record.receiveErrors = stats.receiveErrors
                    record.sendErrors = stats.sendErrors
                    record.linkSpeedBitsPerSecond = stats.linkSpeedBitsPerSecond
                    record.mtu = stats.mtu
                } else {
                    let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
                    record.hasByteCounters = false
                    record.packetsReceived = UInt64(interfaceData.ifi_ipackets)
                    record.packetsSent = UInt64(interfaceData.ifi_opackets)
                    record.receiveErrors = UInt64(interfaceData.ifi_ierrors)
                    record.sendErrors = UInt64(interfaceData.ifi_oerrors)
                    if interfaceData.ifi_baudrate > 0 {
                        record.linkSpeedBitsPerSecond = UInt64(interfaceData.ifi_baudrate)
                    }
                    record.mtu = interfaceData.ifi_mtu > 0 ? Int(interfaceData.ifi_mtu) : nil
                }
            }

            records[name] = record
            cursor = current.pointee.ifa_next
        }

        return records.values
            .filter { $0.isUp || $0.bytesReceived > 0 || $0.bytesSent > 0 }
            .sorted { lhs, rhs in
                if lhs.isLoopback != rhs.isLoopback {
                    return !lhs.isLoopback
                }
                if lhs.isUp != rhs.isUp {
                    return lhs.isUp
                }
                if lhs.sortKind != rhs.sortKind {
                    return lhs.sortKind.localizedStandardCompare(rhs.sortKind) == .orderedAscending
                }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            .enumerated()
            .map { index, record in record.metric(index: index) }
    }

    private func cachedNetworkInterfaceDescriptors(now: Date) -> [String: NetworkInterfaceDescriptor] {
        if let networkInterfaceDescriptorCache,
           isCacheFresh(networkInterfaceDescriptorCache, now: now) {
            return networkInterfaceDescriptorCache.value
        }

        let descriptors = systemInterfaceDescriptorsByName()
        networkInterfaceDescriptorCache = TimedSample(timestamp: now, value: descriptors)
        return descriptors
    }

    private func systemInterfaceDescriptorsByName() -> [String: NetworkInterfaceDescriptor] {
#if canImport(SystemConfiguration)
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [:] }

        var descriptors: [String: NetworkInterfaceDescriptor] = [:]
        for interface in interfaces {
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String? else { continue }
            let systemType = SCNetworkInterfaceGetInterfaceType(interface) as String?
            let systemName = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?
            let sortKind = interfaceSortKind(systemType: systemType, fallbackName: name)
            let kind = interfaceKindDisplayName(sortKind: sortKind)
            descriptors[name] = NetworkInterfaceDescriptor(
                displayName: interfaceDisplayName(systemName: systemName, kind: sortKind),
                kind: kind,
                sortKind: sortKind
            )
        }

        return descriptors
#else
        return [:]
#endif
    }

    private func networkInterfaceStatsByIndex() -> [UInt32: NetworkInterfaceStats64] {
        var mib = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var byteCount = 0
        guard sysctl(&mib, u_int(mib.count), nil, &byteCount, nil, 0) == 0, byteCount > 0 else {
            return [:]
        }

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: byteCount,
            alignment: MemoryLayout<if_msghdr2>.alignment
        )
        defer { buffer.deallocate() }

        guard sysctl(&mib, u_int(mib.count), buffer, &byteCount, nil, 0) == 0 else {
            return [:]
        }

        var offset = 0
        var stats: [UInt32: NetworkInterfaceStats64] = [:]

        while offset + MemoryLayout<if_msghdr2>.size <= byteCount {
            let header = buffer.advanced(by: offset).assumingMemoryBound(to: if_msghdr2.self).pointee
            let messageLength = Int(header.ifm_msglen)
            guard messageLength > 0 else { break }

            if header.ifm_type == UInt8(RTM_IFINFO2) {
                let data = header.ifm_data
                stats[UInt32(header.ifm_index)] = NetworkInterfaceStats64(
                    bytesReceived: data.ifi_ibytes,
                    bytesSent: data.ifi_obytes,
                    packetsReceived: data.ifi_ipackets,
                    packetsSent: data.ifi_opackets,
                    receiveErrors: data.ifi_ierrors,
                    sendErrors: data.ifi_oerrors,
                    linkSpeedBitsPerSecond: data.ifi_baudrate > 0 ? data.ifi_baudrate : nil,
                    mtu: data.ifi_mtu > 0 ? Int(data.ifi_mtu) : nil
                )
            }

            offset += messageLength
        }

        return stats
    }

    private func networkTotals(from interfaces: [NetworkInterfaceMetric]) -> (input: UInt64, output: UInt64) {
        interfaces
            .filter { $0.isUp && !$0.isLoopback }
            .reduce((input: UInt64(0), output: UInt64(0))) { partial, interface in
                (
                    partial.input + (interface.hasByteCounters ? interface.bytesReceived : 0),
                    partial.output + (interface.hasByteCounters ? interface.bytesSent : 0)
                )
            }
    }

    private func sampleNetworkRate(
        totalBytes: (input: UInt64, output: UInt64),
        hasByteCounters: Bool,
        now: Date
    ) -> (input: UInt64, output: UInt64, total: UInt64) {
        guard hasByteCounters else {
            previousNetworkInBytes = nil
            previousNetworkOutBytes = nil
            previousNetworkDate = nil
            return (0, 0, 0)
        }

        defer {
            previousNetworkInBytes = totalBytes.input
            previousNetworkOutBytes = totalBytes.output
            previousNetworkDate = now
        }

        guard let previousNetworkInBytes, let previousNetworkOutBytes, let previousNetworkDate else { return (0, 0, 0) }
        let elapsed = now.timeIntervalSince(previousNetworkDate)
        guard elapsed > 0,
              totalBytes.input >= previousNetworkInBytes,
              totalBytes.output >= previousNetworkOutBytes else {
            return (0, 0, 0)
        }

        let inputRate = UInt64(Double(totalBytes.input - previousNetworkInBytes) / elapsed)
        let outputRate = UInt64(Double(totalBytes.output - previousNetworkOutBytes) / elapsed)
        return (inputRate, outputRate, inputRate + outputRate)
    }

    private func sampleDiskSpace() -> (free: UInt64, total: UInt64) {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: homePath),
              let freeSize = attributes[.systemFreeSize] as? NSNumber,
              let totalSize = attributes[.systemSize] as? NSNumber else {
            return (0, 0)
        }

        return (freeSize.uint64Value, totalSize.uint64Value)
    }

    private func path(_ path: String, isInsideMountPath mountPath: String) -> Bool {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        var normalizedMountPath = URL(fileURLWithPath: mountPath).standardizedFileURL.path
        if normalizedMountPath != "/", normalizedMountPath.hasSuffix("/") {
            normalizedMountPath.removeLast()
        }

        if normalizedMountPath == "/" {
            return normalizedPath.hasPrefix("/")
        }

        return normalizedPath == normalizedMountPath || normalizedPath.hasPrefix(normalizedMountPath + "/")
    }

    private func cachedStorage(now: Date) -> StorageSample {
        if let storageCache, isCacheFresh(storageCache, now: now) {
            return storageCache.value
        }

        let sample = sampleStorage()
        storageCache = TimedSample(timestamp: now, value: sample)
        return sample
    }

    private func cachedBattery(now: Date) -> BatterySample {
        if let batteryCache,
           isCacheFresh(batteryCache, now: now, interval: batteryCacheInterval) {
            return batteryCache.value
        }

        let sample = sampleBattery()
        batteryCache = TimedSample(timestamp: now, value: sample)
        return sample
    }

    private func cachedGPUDevices(now: Date) -> [GPUDeviceMetric] {
        if let gpuDevicesCache, isCacheFresh(gpuDevicesCache, now: now) {
            return gpuDevicesCache.value
        }

        let devices = sampleGPUDevices()
        gpuDevicesCache = TimedSample(timestamp: now, value: devices)
        return devices
    }

    private func cachedDisplays(now: Date) -> [DisplayMetric] {
        if let displaysCache, isCacheFresh(displaysCache, now: now) {
            return displaysCache.value
        }

        let displays = sampleDisplays()
        displaysCache = TimedSample(timestamp: now, value: displays)
        return displays
    }

    private func isCacheFresh<Value>(_ cached: TimedSample<Value>, now: Date, interval: TimeInterval? = nil) -> Bool {
        let cacheInterval = interval ?? inventoryCacheInterval
        guard cacheInterval > 0 else { return false }
        let age = now.timeIntervalSince(cached.timestamp)
        return age >= 0 && age < cacheInterval
    }

    private func sampleStorage() -> StorageSample {
        let keys: [URLResourceKey] = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsReadOnlyKey
        ]

        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        let volumeCandidates = urls.enumerated().compactMap { index, url -> StorageVolumeCandidate? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let total = values.volumeTotalCapacity,
                  let available = values.volumeAvailableCapacity,
                  total > 0 else {
                return nil
            }

            let metric = StorageVolumeMetric(
                index: index,
                fileSystem: fileSystemName(forPath: url.path),
                totalBytes: UInt64(total),
                availableBytes: UInt64(max(available, 0)),
                importantAvailableBytes: values.volumeAvailableCapacityForImportantUsage.map { UInt64(max($0, 0)) },
                isInternal: values.volumeIsInternal ?? false,
                isRemovable: values.volumeIsRemovable ?? false,
                isEjectable: values.volumeIsEjectable ?? false,
                isReadOnly: values.volumeIsReadOnly ?? false,
                hasKindReport: values.volumeIsInternal != nil || values.volumeIsRemovable == true || values.volumeIsEjectable == true,
                hasAccessReport: values.volumeIsReadOnly != nil
            )

            return StorageVolumeCandidate(mountPath: url.path, metric: metric)
        }

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let primaryIndex = volumeCandidates
            .filter { path(homePath, isInsideMountPath: $0.mountPath) }
            .sorted { $0.mountPath.count > $1.mountPath.count }
            .first?.metric.index ?? volumeCandidates.first?.metric.index
        let volumes = volumeCandidates.map { candidate -> StorageVolumeMetric in
            var metric = candidate.metric
            metric.isPrimary = metric.index == primaryIndex
            return metric
        }
        let primary = volumes.first { $0.isPrimary }

        return StorageSample(primary: primary, volumes: volumes)
    }

    private func sampleGPUDevices() -> [GPUDeviceMetric] {
#if canImport(Metal)
        let devices = MTLCopyAllDevices()
        return devices.enumerated().map { index, device in
            let maxThreadsPerThreadgroup = device.maxThreadsPerThreadgroup
            return GPUDeviceMetric(
                index: index,
                name: device.name,
                isLowPower: device.isLowPower,
                isRemovable: device.isRemovable,
                isHeadless: device.isHeadless,
                hasUnifiedMemory: device.hasUnifiedMemory,
                recommendedMaxWorkingSetBytes: device.recommendedMaxWorkingSetSize,
                maxThreadgroupMemoryLength: device.maxThreadgroupMemoryLength,
                maxThreadsPerThreadgroupWidth: maxThreadsPerThreadgroup.width,
                maxThreadsPerThreadgroupHeight: maxThreadsPerThreadgroup.height,
                maxThreadsPerThreadgroupDepth: maxThreadsPerThreadgroup.depth,
                hasDeviceKindReport: true,
                hasUnifiedMemoryReport: true,
                hasDisplayRoleReport: true
            )
        }
#else
        return []
#endif
    }

    private func sampleDisplays() -> [DisplayMetric] {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return fallbackDisplaysFromScreens()
        }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            return fallbackDisplaysFromScreens()
        }

        let screenRefreshRates = screenRefreshRatesByDisplayID()
        let screenScales = screenScalesByDisplayID()
        let screenColorSpaces = screenColorSpacesByDisplayID()
        let displays = displayIDs.prefix(Int(displayCount)).enumerated().map { index, displayID in
            let mode = CGDisplayCopyDisplayMode(displayID)
            let modeRefreshRate = mode?.refreshRate ?? 0
            let refreshRate = modeRefreshRate > 0 ? modeRefreshRate : screenRefreshRates[displayID, default: 0]
            let modeWidth = mode.map { Int($0.width) } ?? Int(CGDisplayPixelsWide(displayID))
            let modeHeight = mode.map { Int($0.height) } ?? Int(CGDisplayPixelsHigh(displayID))
            let screenSize = CGDisplayScreenSize(displayID)

            return DisplayMetric(
                index: index,
                name: displayName(for: displayID, index: index),
                pixelWidth: Int(CGDisplayPixelsWide(displayID)),
                pixelHeight: Int(CGDisplayPixelsHigh(displayID)),
                modeWidth: modeWidth,
                modeHeight: modeHeight,
                refreshRate: refreshRate,
                backingScaleFactor: screenScales[displayID, default: 0],
                colorSpaceModel: screenColorSpaces[displayID]?.model,
                colorComponentCount: screenColorSpaces[displayID]?.componentCount ?? 0,
                physicalWidthMillimeters: Int(screenSize.width.rounded()),
                physicalHeightMillimeters: Int(screenSize.height.rounded()),
                isBuiltin: CGDisplayIsBuiltin(displayID) != 0,
                isMain: displayID == CGMainDisplayID(),
                isMirrored: CGDisplayIsInMirrorSet(displayID) != 0,
                rotationDegrees: CGDisplayRotation(displayID),
                hasTopologyReport: true,
                hasRotationReport: true
            )
        }
        return displays.isEmpty ? fallbackDisplaysFromScreens() : displays
    }

    private func fallbackDisplaysFromScreens() -> [DisplayMetric] {
#if canImport(AppKit)
        guard Thread.isMainThread else { return [] }
        let mainScreen = NSScreen.main
        return NSScreen.screens.enumerated().map { index, screen in
            let scale = screen.backingScaleFactor
            let pointWidth = max(0, Int(screen.frame.width.rounded()))
            let pointHeight = max(0, Int(screen.frame.height.rounded()))
            let pixelWidth = max(0, Int((screen.frame.width * scale).rounded()))
            let pixelHeight = max(0, Int((screen.frame.height * scale).rounded()))
            let isMain = mainScreen.map { screen === $0 } ?? (index == 0)
            let screenSize = physicalScreenSize(screen)

            return DisplayMetric(
                index: index,
                name: isMain ? SharedMetricStrings.mainDisplay : SharedMetricStrings.display(number: index + 1),
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                modeWidth: pointWidth,
                modeHeight: pointHeight,
                refreshRate: screenRefreshRate(screen),
                backingScaleFactor: scale,
                colorSpaceModel: colorSpaceModel(screen.colorSpace?.colorSpaceModel),
                colorComponentCount: screen.colorSpace?.numberOfColorComponents ?? 0,
                physicalWidthMillimeters: screenSize.width,
                physicalHeightMillimeters: screenSize.height,
                isBuiltin: false,
                isMain: isMain,
                isMirrored: false,
                rotationDegrees: 0,
                hasTopologyReport: false,
                hasRotationReport: false
            )
        }
#else
        return []
#endif
    }

    private func screenRefreshRatesByDisplayID() -> [CGDirectDisplayID: Double] {
#if canImport(AppKit)
        guard Thread.isMainThread else { return [:] }
        var rates: [CGDirectDisplayID: Double] = [:]
        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }

            let refreshRate = screenRefreshRate(screen)
            guard refreshRate > 0 else { continue }
            rates[CGDirectDisplayID(screenNumber.uint32Value)] = refreshRate
        }

        return rates
#else
        return [:]
#endif
    }

    private func screenScalesByDisplayID() -> [CGDirectDisplayID: Double] {
#if canImport(AppKit)
        guard Thread.isMainThread else { return [:] }
        var scales: [CGDirectDisplayID: Double] = [:]
        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }

            scales[CGDirectDisplayID(screenNumber.uint32Value)] = Double(screen.backingScaleFactor)
        }

        return scales
#else
        return [:]
#endif
    }

    private func screenColorSpacesByDisplayID() -> [CGDirectDisplayID: DisplayColorSpaceSample] {
#if canImport(AppKit)
        guard Thread.isMainThread else { return [:] }
        var colorSpaces: [CGDirectDisplayID: DisplayColorSpaceSample] = [:]
        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let model = colorSpaceModel(screen.colorSpace?.colorSpaceModel) else {
                continue
            }

            colorSpaces[CGDirectDisplayID(screenNumber.uint32Value)] = DisplayColorSpaceSample(
                model: model,
                componentCount: screen.colorSpace?.numberOfColorComponents ?? 0
            )
        }

        return colorSpaces
#else
        return [:]
#endif
    }

#if canImport(AppKit)
    private func screenRefreshRate(_ screen: NSScreen) -> Double {
        let framesPerSecond = screen.maximumFramesPerSecond
        return framesPerSecond > 0 ? Double(framesPerSecond) : 0
    }

    private func physicalScreenSize(_ screen: NSScreen) -> (width: Int, height: Int) {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return (0, 0)
        }

        let screenSize = CGDisplayScreenSize(CGDirectDisplayID(screenNumber.uint32Value))
        return (Int(screenSize.width.rounded()), Int(screenSize.height.rounded()))
    }

    private func colorSpaceModel(_ model: NSColorSpace.Model?) -> String? {
        guard let model else { return nil }

        switch model {
        case .gray:
            return "Gray"
        case .rgb:
            return "RGB"
        case .cmyk:
            return "CMYK"
        case .lab:
            return "Lab"
        case .deviceN:
            return "DeviceN"
        case .indexed:
            return "Indexed"
        case .patterned:
            return "Patterned"
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }
#endif

    private func validBatteryMinutes(_ value: Int?) -> Int? {
        guard let value, value >= 0, value < 65_535 else { return nil }
        return value
    }

    private func estimatedBatteryDischargeMinutes() -> Int? {
        let estimate = IOPSGetTimeRemainingEstimate()
        guard estimate != kIOPSTimeRemainingUnknown,
              estimate != kIOPSTimeRemainingUnlimited,
              estimate.isFinite,
              estimate >= 0 else {
            return nil
        }
        return validBatteryMinutes(finiteInt((estimate / 60).rounded()))
    }

    private func interfaceDisplayName(systemName: String?, kind: String) -> String {
        guard let systemName, !systemName.isEmpty else {
            return interfaceDisplayName(forKind: kind)
        }

        if systemName.localizedCaseInsensitiveContains("wi-fi") ||
            systemName.localizedCaseInsensitiveContains("wifi") {
            return "Wi-Fi"
        }

        if systemName.localizedCaseInsensitiveContains("ethernet") {
            return "Ethernet"
        }

        if systemName.localizedCaseInsensitiveContains("vpn") {
            return "VPN"
        }

        if systemName.localizedCaseInsensitiveContains("bridge") {
            return "Bridge"
        }

        if systemName.localizedCaseInsensitiveContains("thunderbolt") {
            return "Thunderbolt"
        }

        return interfaceDisplayName(forKind: kind)
    }

    private func interfaceDisplayName(forKind kind: String) -> String {
        switch kind {
        case "Wi-Fi": return "Wi-Fi"
        case "Ethernet": return "Ethernet"
        case "VPN": return "VPN"
        case "Loopback": return "Loopback"
        case "Bridge": return "Bridge"
        case "Thunderbolt": return "Thunderbolt"
        case "AWDL": return "Apple Wireless Direct"
        case "Bluetooth": return "Bluetooth"
        case "Cellular": return "Cellular"
        case "Other": return SharedMetricStrings.other
        case "Network": return SharedMetricStrings.networkInterface
        default: return SharedMetricStrings.networkInterface
        }
    }

    private func interfaceSortKind(systemType: String?, fallbackName name: String) -> String {
#if canImport(SystemConfiguration)
        switch systemType {
        case String(kSCNetworkInterfaceTypeIEEE80211):
            return "Wi-Fi"
        case String(kSCNetworkInterfaceTypeEthernet),
             String(kSCNetworkInterfaceTypeBond),
             String(kSCNetworkInterfaceTypeVLAN):
            return "Ethernet"
        case String(kSCNetworkInterfaceTypePPP),
             String(kSCNetworkInterfaceTypeIPSec),
             String(kSCNetworkInterfaceTypeL2TP):
            return "VPN"
        case String(kSCNetworkInterfaceTypeBluetooth):
            return "Bluetooth"
        case String(kSCNetworkInterfaceTypeWWAN):
            return "Cellular"
        default:
            return interfaceSortKind(name)
        }
#else
        return interfaceSortKind(name)
#endif
    }

    private func interfaceSortKind(_ name: String) -> String {
        if name == "lo0" { return "Loopback" }
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") { return "VPN" }
        if name.hasPrefix("bridge") { return "Bridge" }
        if name.hasPrefix("awdl") || name.hasPrefix("llw") { return "AWDL" }
        if name.hasPrefix("en") { return "Network" }
        if name.hasPrefix("thunderbolt") { return "Thunderbolt" }
        return "Other"
    }

    private func interfaceKindDisplayName(sortKind: String) -> String {
        switch sortKind {
        case "Wi-Fi": return "Wi-Fi"
        case "Ethernet": return "Ethernet"
        case "VPN": return "VPN"
        case "Loopback": return "Loopback"
        case "Bridge": return "Bridge"
        case "Thunderbolt": return "Thunderbolt"
        case "AWDL": return "Apple Wireless Direct"
        case "Bluetooth": return "Bluetooth"
        case "Cellular": return "Cellular"
        case "Other": return SharedMetricStrings.other
        default: return SharedMetricStrings.networkInterface
        }
    }

    private func fileSystemName(forPath path: String) -> String {
        var stats = statfs()
        guard statfs(path, &stats) == 0 else { return SharedMetricStrings.notReported }
        return Self.stringFromFixedCString(stats.f_fstypename)
    }

    private func displayName(for displayID: CGDirectDisplayID, index: Int) -> String {
        if CGDisplayIsBuiltin(displayID) != 0 {
            return SharedMetricStrings.builtInDisplay
        }

        if displayID == CGMainDisplayID() {
            return SharedMetricStrings.mainDisplay
        }

        return SharedMetricStrings.externalDisplay(number: index + 1)
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(exactly: value) }
        if let value = value as? UInt64 { return Int(exactly: value) }
        if let value = value as? NSNumber { return finiteInt(value.doubleValue) }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        let converted: Double?
        if let value = value as? Double {
            converted = value
        } else if let value = value as? NSNumber {
            converted = value.doubleValue
        } else if let value = value as? String {
            converted = Double(value)
        } else {
            converted = nil
        }

        guard let converted, converted.isFinite else { return nil }
        return converted
    }

    private func finiteInt(_ value: Double?) -> Int? {
        guard let value, value.isFinite else { return nil }
        return Int(exactly: value)
    }

    private static func sysctlInteger(_ name: String) -> Int? {
        var value = 0
        var size = MemoryLayout<Int>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return Self.stringFromNullTerminatedBuffer(buffer)
    }

    private static func stringFromNullTerminatedBuffer(_ buffer: [CChar]) -> String {
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func stringFromFixedCString<T>(_ value: T) -> String {
        var mutableValue = value
        return withUnsafeBytes(of: &mutableValue) { buffer in
            let bytes = buffer.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
    }

    private func tickArray(_ ticks: (UInt32, UInt32, UInt32, UInt32)) -> [UInt32] {
        [ticks.0, ticks.1, ticks.2, ticks.3]
    }
}
