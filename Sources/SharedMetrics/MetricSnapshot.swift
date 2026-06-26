import Foundation

public enum MetricStatusTone: String, Codable, Equatable, Sendable {
    case neutral
    case normal
    case warning
    case critical
}

public struct ProcessMetric: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { index }
    public var index: Int
    public var name: String
    public var activationPolicy: String?
    public var isActive: Bool
    public var isHidden: Bool
    public var hasStateReport: Bool
    public var launchDate: Date?
    public var architecture: String?

    public init(
        index: Int,
        name: String,
        activationPolicy: String? = nil,
        isActive: Bool = false,
        isHidden: Bool = false,
        hasStateReport: Bool = false,
        launchDate: Date? = nil,
        architecture: String? = nil
    ) {
        self.index = index
        self.name = Self.reportedName(name)
        self.activationPolicy = activationPolicy
        self.isActive = isActive
        self.isHidden = isHidden
        self.hasStateReport = hasStateReport
        self.launchDate = launchDate
        self.architecture = architecture
    }

    enum CodingKeys: String, CodingKey {
        case index
        case name
        case activationPolicy
        case isActive
        case isHidden
        case hasStateReport
        case launchDate
        case architecture
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let hasActivationPolicyKey = values.contains(.activationPolicy)
        let hasActiveKey = values.contains(.isActive)
        let hasHiddenKey = values.contains(.isHidden)
        index = try values.decodeIfPresent(Int.self, forKey: .index) ?? 0
        name = Self.reportedName(try values.decodeIfPresent(String.self, forKey: .name))
        activationPolicy = try values.decodeIfPresent(String.self, forKey: .activationPolicy)
        isActive = try values.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        isHidden = try values.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        hasStateReport = try values.decodeIfPresent(Bool.self, forKey: .hasStateReport)
            ?? (hasActivationPolicyKey || hasActiveKey || hasHiddenKey)
        launchDate = try values.decodeIfPresent(Date.self, forKey: .launchDate)
        architecture = try values.decodeIfPresent(String.self, forKey: .architecture)
    }

    private static func reportedName(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "未报告" : trimmed
    }

    public var stateText: String {
        guard hasStateReport else { return "未报告" }
        if isActive { return "前台" }
        if isHidden { return "已隐藏" }

        let trimmedPolicy = activationPolicy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedPolicy.isEmpty ? "运行" : trimmedPolicy
    }

    public var architectureText: String {
        let trimmedArchitecture = architecture?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedArchitecture.isEmpty ? "系统未报告" : trimmedArchitecture
    }

    public var launchText: String {
        guard let launchDate else { return "系统未报告" }
        return launchDate.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
    }

    public var hasInventoryReport: Bool {
        let trimmedPolicy = activationPolicy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedArchitecture = architecture?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name != "未报告"
            || hasStateReport
            || launchDate != nil
            || !trimmedPolicy.isEmpty
            || !trimmedArchitecture.isEmpty
    }

    public static func listSubtitle(for processes: [ProcessMetric], defaultSubtitle: String) -> String {
        processes.contains(where: \.hasInventoryReport) ? defaultSubtitle : "未报告"
    }
}

public struct GPUDeviceMetric: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { index }
    public var index: Int
    public var name: String
    public var isLowPower: Bool
    public var isRemovable: Bool
    public var isHeadless: Bool
    public var hasUnifiedMemory: Bool
    public var recommendedMaxWorkingSetBytes: UInt64
    public var maxThreadgroupMemoryLength: Int
    public var maxThreadsPerThreadgroupWidth: Int
    public var maxThreadsPerThreadgroupHeight: Int
    public var maxThreadsPerThreadgroupDepth: Int
    public var hasDeviceKindReport: Bool
    public var hasUnifiedMemoryReport: Bool
    public var hasDisplayRoleReport: Bool

    public init(
        index: Int,
        name: String,
        isLowPower: Bool,
        isRemovable: Bool,
        isHeadless: Bool,
        hasUnifiedMemory: Bool,
        recommendedMaxWorkingSetBytes: UInt64,
        maxThreadgroupMemoryLength: Int = 0,
        maxThreadsPerThreadgroupWidth: Int = 0,
        maxThreadsPerThreadgroupHeight: Int = 0,
        maxThreadsPerThreadgroupDepth: Int = 0,
        hasDeviceKindReport: Bool = false,
        hasUnifiedMemoryReport: Bool = false,
        hasDisplayRoleReport: Bool = false
    ) {
        self.index = index
        self.name = Self.reportedGPUName(name)
        self.isLowPower = isLowPower
        self.isRemovable = isRemovable
        self.isHeadless = isHeadless
        self.hasUnifiedMemory = hasUnifiedMemory
        self.recommendedMaxWorkingSetBytes = recommendedMaxWorkingSetBytes
        self.maxThreadgroupMemoryLength = maxThreadgroupMemoryLength
        self.maxThreadsPerThreadgroupWidth = maxThreadsPerThreadgroupWidth
        self.maxThreadsPerThreadgroupHeight = maxThreadsPerThreadgroupHeight
        self.maxThreadsPerThreadgroupDepth = maxThreadsPerThreadgroupDepth
        self.hasDeviceKindReport = hasDeviceKindReport
        self.hasUnifiedMemoryReport = hasUnifiedMemoryReport
        self.hasDisplayRoleReport = hasDisplayRoleReport
    }

    enum CodingKeys: String, CodingKey {
        case index
        case name
        case isLowPower
        case isRemovable
        case isHeadless
        case hasUnifiedMemory
        case recommendedMaxWorkingSetBytes
        case maxThreadgroupMemoryLength
        case maxThreadsPerThreadgroupWidth
        case maxThreadsPerThreadgroupHeight
        case maxThreadsPerThreadgroupDepth
        case hasDeviceKindReport
        case hasUnifiedMemoryReport
        case hasDisplayRoleReport
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let hasLowPowerKey = values.contains(.isLowPower)
        let hasRemovableKey = values.contains(.isRemovable)
        let hasHeadlessKey = values.contains(.isHeadless)
        let hasUnifiedMemoryKey = values.contains(.hasUnifiedMemory)
        index = try values.decodeIfPresent(Int.self, forKey: .index) ?? 0
        name = Self.reportedGPUName(try values.decodeIfPresent(String.self, forKey: .name))
        isLowPower = try values.decodeIfPresent(Bool.self, forKey: .isLowPower) ?? false
        isRemovable = try values.decodeIfPresent(Bool.self, forKey: .isRemovable) ?? false
        isHeadless = try values.decodeIfPresent(Bool.self, forKey: .isHeadless) ?? false
        hasUnifiedMemory = try values.decodeIfPresent(Bool.self, forKey: .hasUnifiedMemory) ?? false
        recommendedMaxWorkingSetBytes = try values.decodeIfPresent(UInt64.self, forKey: .recommendedMaxWorkingSetBytes) ?? 0
        maxThreadgroupMemoryLength = try values.decodeIfPresent(Int.self, forKey: .maxThreadgroupMemoryLength) ?? 0
        maxThreadsPerThreadgroupWidth = try values.decodeIfPresent(Int.self, forKey: .maxThreadsPerThreadgroupWidth) ?? 0
        maxThreadsPerThreadgroupHeight = try values.decodeIfPresent(Int.self, forKey: .maxThreadsPerThreadgroupHeight) ?? 0
        maxThreadsPerThreadgroupDepth = try values.decodeIfPresent(Int.self, forKey: .maxThreadsPerThreadgroupDepth) ?? 0
        hasDeviceKindReport = try values.decodeIfPresent(Bool.self, forKey: .hasDeviceKindReport)
            ?? ((hasLowPowerKey && isLowPower) || (hasRemovableKey && isRemovable) || (hasLowPowerKey && hasRemovableKey))
        hasUnifiedMemoryReport = try values.decodeIfPresent(Bool.self, forKey: .hasUnifiedMemoryReport) ?? hasUnifiedMemoryKey
        hasDisplayRoleReport = try values.decodeIfPresent(Bool.self, forKey: .hasDisplayRoleReport) ?? hasHeadlessKey
    }

    private static func reportedGPUName(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty || trimmed == "GPU" ? "未报告" : trimmed
    }

    public var kindText: String {
        guard hasDeviceKindReport else { return "未报告" }
        if isRemovable { return "外置" }
        return isLowPower ? "低功耗" : "高性能"
    }

    public var unifiedMemoryText: String {
        guard hasUnifiedMemoryReport else { return "未报告" }
        return hasUnifiedMemory ? "是" : "否"
    }

    public var recommendedWorkingSetText: String {
        guard recommendedMaxWorkingSetBytes > 0 else { return "未报告" }
        return MetricFormatting.bytes(recommendedMaxWorkingSetBytes)
    }

    public var threadgroupMemoryText: String {
        guard maxThreadgroupMemoryLength > 0 else { return "未报告" }
        return MetricFormatting.bytes(UInt64(maxThreadgroupMemoryLength))
    }

    public var threadgroupSizeText: String {
        guard maxThreadsPerThreadgroupWidth > 0,
              maxThreadsPerThreadgroupHeight > 0,
              maxThreadsPerThreadgroupDepth > 0
        else { return "未报告" }
        return "\(maxThreadsPerThreadgroupWidth)x\(maxThreadsPerThreadgroupHeight)x\(maxThreadsPerThreadgroupDepth)"
    }

    public var stateText: String {
        guard hasDisplayRoleReport else { return "未报告" }
        return isHeadless ? "计算" : "显示"
    }

    public var hasInventoryReport: Bool {
        name != "未报告"
            || hasDeviceKindReport
            || hasUnifiedMemoryReport
            || hasDisplayRoleReport
            || recommendedMaxWorkingSetBytes > 0
            || maxThreadgroupMemoryLength > 0
            || maxThreadsPerThreadgroupWidth > 0
            || maxThreadsPerThreadgroupHeight > 0
            || maxThreadsPerThreadgroupDepth > 0
    }
}

public struct DisplayMetric: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { index }
    public var index: Int
    public var name: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var modeWidth: Int
    public var modeHeight: Int
    public var refreshRate: Double
    public var backingScaleFactor: Double
    public var colorSpaceModel: String?
    public var colorComponentCount: Int
    public var physicalWidthMillimeters: Int
    public var physicalHeightMillimeters: Int
    public var isBuiltin: Bool
    public var isMain: Bool
    public var isMirrored: Bool
    public var rotationDegrees: Double
    public var hasTopologyReport: Bool
    public var hasRotationReport: Bool

    public init(
        index: Int,
        name: String,
        pixelWidth: Int,
        pixelHeight: Int,
        modeWidth: Int,
        modeHeight: Int,
        refreshRate: Double,
        backingScaleFactor: Double = 0,
        colorSpaceModel: String? = nil,
        colorComponentCount: Int = 0,
        physicalWidthMillimeters: Int = 0,
        physicalHeightMillimeters: Int = 0,
        isBuiltin: Bool,
        isMain: Bool,
        isMirrored: Bool,
        rotationDegrees: Double,
        hasTopologyReport: Bool = false,
        hasRotationReport: Bool = false
    ) {
        self.index = index
        self.name = Self.reportedDisplayName(name)
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.modeWidth = modeWidth
        self.modeHeight = modeHeight
        self.refreshRate = refreshRate
        self.backingScaleFactor = backingScaleFactor
        self.colorSpaceModel = colorSpaceModel
        self.colorComponentCount = colorComponentCount
        self.physicalWidthMillimeters = physicalWidthMillimeters
        self.physicalHeightMillimeters = physicalHeightMillimeters
        self.isBuiltin = isBuiltin
        self.isMain = isMain
        self.isMirrored = isMirrored
        self.rotationDegrees = rotationDegrees
        self.hasTopologyReport = hasTopologyReport
        self.hasRotationReport = hasRotationReport
    }

    enum CodingKeys: String, CodingKey {
        case index
        case name
        case pixelWidth
        case pixelHeight
        case modeWidth
        case modeHeight
        case refreshRate
        case backingScaleFactor
        case colorSpaceModel
        case colorComponentCount
        case physicalWidthMillimeters
        case physicalHeightMillimeters
        case isBuiltin
        case isMain
        case isMirrored
        case rotationDegrees
        case hasTopologyReport
        case hasRotationReport
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let hasBuiltinKey = values.contains(.isBuiltin)
        let hasMainKey = values.contains(.isMain)
        let hasMirroredKey = values.contains(.isMirrored)
        let hasRotationKey = values.contains(.rotationDegrees)
        index = try values.decodeIfPresent(Int.self, forKey: .index) ?? 0
        name = Self.reportedDisplayName(try values.decodeIfPresent(String.self, forKey: .name))
        pixelWidth = try values.decodeIfPresent(Int.self, forKey: .pixelWidth) ?? 0
        pixelHeight = try values.decodeIfPresent(Int.self, forKey: .pixelHeight) ?? 0
        modeWidth = try values.decodeIfPresent(Int.self, forKey: .modeWidth) ?? 0
        modeHeight = try values.decodeIfPresent(Int.self, forKey: .modeHeight) ?? 0
        refreshRate = try values.decodeIfPresent(Double.self, forKey: .refreshRate) ?? 0
        backingScaleFactor = try values.decodeIfPresent(Double.self, forKey: .backingScaleFactor) ?? 0
        colorSpaceModel = try values.decodeIfPresent(String.self, forKey: .colorSpaceModel)
        colorComponentCount = try values.decodeIfPresent(Int.self, forKey: .colorComponentCount) ?? 0
        physicalWidthMillimeters = try values.decodeIfPresent(Int.self, forKey: .physicalWidthMillimeters) ?? 0
        physicalHeightMillimeters = try values.decodeIfPresent(Int.self, forKey: .physicalHeightMillimeters) ?? 0
        isBuiltin = try values.decodeIfPresent(Bool.self, forKey: .isBuiltin) ?? false
        isMain = try values.decodeIfPresent(Bool.self, forKey: .isMain) ?? false
        isMirrored = try values.decodeIfPresent(Bool.self, forKey: .isMirrored) ?? false
        rotationDegrees = try values.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        hasTopologyReport = try values.decodeIfPresent(Bool.self, forKey: .hasTopologyReport)
            ?? (hasBuiltinKey && hasMainKey && hasMirroredKey)
        hasRotationReport = try values.decodeIfPresent(Bool.self, forKey: .hasRotationReport) ?? hasRotationKey
    }

    private static func reportedDisplayName(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty || trimmed == "显示器" ? "未报告" : trimmed
    }

    public var pixelSizeText: String {
        guard pixelWidth > 0, pixelHeight > 0 else { return "未报告" }
        return "\(pixelWidth)x\(pixelHeight)"
    }

    public var modeSizeText: String {
        guard modeWidth > 0, modeHeight > 0 else { return "未报告" }
        return "\(modeWidth)x\(modeHeight)"
    }

    public var backingScaleText: String {
        guard backingScaleFactor > 0 else { return "未报告" }
        let roundedScale = (backingScaleFactor * 10).rounded() / 10
        if roundedScale.rounded() == roundedScale {
            return String(format: "%.0fx", roundedScale)
        }
        return String(format: "%.1fx", roundedScale)
    }

    public var colorText: String {
        guard let model = colorSpaceModel, !model.isEmpty else { return "未报告" }
        guard colorComponentCount > 0 else { return model }
        return "\(model) · \(colorComponentCount)"
    }

    public var refreshRateText: String {
        guard refreshRate > 0 else { return "未报告" }
        return String(format: "%.0f Hz", refreshRate)
    }

    public var physicalSizeText: String {
        guard physicalWidthMillimeters > 0, physicalHeightMillimeters > 0 else { return "未报告" }
        return "\(physicalWidthMillimeters)x\(physicalHeightMillimeters) mm"
    }

    public var rotationText: String {
        guard hasRotationReport else { return "未报告" }
        let normalized = rotationDegrees.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        return String(format: "%.0f°", positive)
    }

    public var stateText: String {
        guard hasTopologyReport else { return "未报告" }
        let role = isMain ? "主屏幕" : (isBuiltin ? "内建" : "外接")
        let mode = isMirrored ? "镜像" : "扩展"
        return "\(role) · \(mode)"
    }

    public var hasInventoryReport: Bool {
        name != "未报告"
            || pixelWidth > 0
            || pixelHeight > 0
            || modeWidth > 0
            || modeHeight > 0
            || refreshRate > 0
            || backingScaleFactor > 0
            || !(colorSpaceModel?.isEmpty ?? true)
            || colorComponentCount > 0
            || physicalWidthMillimeters > 0
            || physicalHeightMillimeters > 0
            || hasTopologyReport
            || hasRotationReport
    }
}

public struct StorageVolumeMetric: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { index }
    public var index: Int
    public var fileSystem: String
    public var totalBytes: UInt64
    public var availableBytes: UInt64
    public var importantAvailableBytes: UInt64?
    public var isInternal: Bool
    public var isRemovable: Bool
    public var isEjectable: Bool
    public var isReadOnly: Bool
    public var hasKindReport: Bool
    public var hasAccessReport: Bool
    public var isPrimary: Bool

    public init(
        index: Int,
        fileSystem: String,
        totalBytes: UInt64,
        availableBytes: UInt64,
        importantAvailableBytes: UInt64?,
        isInternal: Bool,
        isRemovable: Bool,
        isEjectable: Bool,
        isReadOnly: Bool = false,
        hasKindReport: Bool = false,
        hasAccessReport: Bool = false,
        isPrimary: Bool = false
    ) {
        self.index = index
        self.fileSystem = Self.reportedFileSystemName(fileSystem)
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.importantAvailableBytes = importantAvailableBytes
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.isReadOnly = isReadOnly
        self.hasKindReport = hasKindReport
        self.hasAccessReport = hasAccessReport
        self.isPrimary = isPrimary
    }

    enum CodingKeys: String, CodingKey {
        case index
        case fileSystem
        case totalBytes
        case availableBytes
        case importantAvailableBytes
        case isInternal
        case isRemovable
        case isEjectable
        case isReadOnly
        case hasKindReport
        case hasAccessReport
        case isPrimary
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let hasInternalKey = values.contains(.isInternal)
        let hasRemovableKey = values.contains(.isRemovable)
        let hasEjectableKey = values.contains(.isEjectable)
        let hasReadOnlyKey = values.contains(.isReadOnly)
        index = try values.decodeIfPresent(Int.self, forKey: .index) ?? 0
        fileSystem = Self.reportedFileSystemName(try values.decodeIfPresent(String.self, forKey: .fileSystem))
        totalBytes = try values.decodeIfPresent(UInt64.self, forKey: .totalBytes) ?? 0
        availableBytes = try values.decodeIfPresent(UInt64.self, forKey: .availableBytes) ?? 0
        importantAvailableBytes = try values.decodeIfPresent(UInt64.self, forKey: .importantAvailableBytes)
        isInternal = try values.decodeIfPresent(Bool.self, forKey: .isInternal) ?? false
        isRemovable = try values.decodeIfPresent(Bool.self, forKey: .isRemovable) ?? false
        isEjectable = try values.decodeIfPresent(Bool.self, forKey: .isEjectable) ?? false
        isReadOnly = try values.decodeIfPresent(Bool.self, forKey: .isReadOnly) ?? false
        hasKindReport = try values.decodeIfPresent(Bool.self, forKey: .hasKindReport)
            ?? (hasInternalKey || (hasRemovableKey && isRemovable) || (hasEjectableKey && isEjectable))
        hasAccessReport = try values.decodeIfPresent(Bool.self, forKey: .hasAccessReport) ?? hasReadOnlyKey
        isPrimary = try values.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
    }

    private static func reportedFileSystemName(_ fileSystem: String?) -> String {
        let trimmed = fileSystem?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty || trimmed == "unknown" ? "未报告" : trimmed
    }

    public var usedBytes: UInt64 {
        guard hasCapacityReport else { return 0 }
        return totalBytes - availableBytes
    }

    public var usage: Double {
        guard hasCapacityReport else { return 0 }
        return min(Double(usedBytes) / Double(totalBytes), 1)
    }

    private var hasCapacityReport: Bool {
        totalBytes > 0 && availableBytes <= totalBytes
    }

    public var reportedAvailableBytes: UInt64? {
        guard hasCapacityReport else { return nil }
        let availableBytes = importantAvailableBytes ?? self.availableBytes
        return availableBytes <= totalBytes ? availableBytes : self.availableBytes
    }

    public var totalText: String {
        guard hasCapacityReport else { return "未报告" }
        return MetricFormatting.bytes(totalBytes)
    }

    public var usedText: String {
        guard hasCapacityReport else { return "未报告" }
        return MetricFormatting.bytes(usedBytes)
    }

    public var availableText: String {
        guard let reportedAvailableBytes else { return "未报告" }
        return MetricFormatting.bytes(reportedAvailableBytes)
    }

    public var usageText: String {
        guard hasCapacityReport else { return "未报告" }
        return MetricFormatting.percentage(usage)
    }

    public var kindText: String {
        guard hasKindReport else { return "未报告" }
        if isRemovable { return "可移除" }
        if isEjectable { return "可弹出" }
        return isInternal ? "内置" : "外置"
    }

    public var accessText: String {
        guard hasAccessReport else { return "未报告" }
        return isReadOnly ? "只读" : "可写"
    }

    public var isExternalVolume: Bool {
        guard hasKindReport else { return false }
        if isRemovable || isEjectable { return true }
        return !isInternal
    }

    public var hasInventoryReport: Bool {
        fileSystem != "未报告"
            || hasCapacityReport
            || hasKindReport
            || hasAccessReport
            || isPrimary
    }
}

public struct NetworkInterfaceMetric: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { index }
    public var index: Int
    public var displayName: String
    public var kind: String
    public var isUp: Bool
    public var isLoopback: Bool
    public var hasInterfaceStateReport: Bool
    public var bytesReceived: UInt64
    public var bytesSent: UInt64
    public var hasByteCounters: Bool
    public var hasByteCounterValues: Bool
    public var packetsReceived: UInt64?
    public var packetsSent: UInt64?
    public var receiveErrors: UInt64?
    public var sendErrors: UInt64?
    public var linkSpeedBitsPerSecond: UInt64?
    public var mtu: Int?

    public init(
        index: Int,
        displayName: String,
        kind: String,
        isUp: Bool,
        isLoopback: Bool,
        hasInterfaceStateReport: Bool = false,
        bytesReceived: UInt64,
        bytesSent: UInt64,
        hasByteCounters: Bool = false,
        hasByteCounterValues: Bool? = nil,
        packetsReceived: UInt64? = nil,
        packetsSent: UInt64? = nil,
        receiveErrors: UInt64? = nil,
        sendErrors: UInt64? = nil,
        linkSpeedBitsPerSecond: UInt64? = nil,
        mtu: Int? = nil
    ) {
        self.index = index
        self.displayName = Self.reportedInterfaceDisplayName(displayName)
        self.kind = Self.reportedInterfaceKind(kind)
        self.isUp = isUp
        self.isLoopback = isLoopback
        self.hasInterfaceStateReport = hasInterfaceStateReport
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.hasByteCounters = hasByteCounters
        self.hasByteCounterValues = hasByteCounterValues ?? hasByteCounters
        self.packetsReceived = packetsReceived
        self.packetsSent = packetsSent
        self.receiveErrors = receiveErrors
        self.sendErrors = sendErrors
        self.linkSpeedBitsPerSecond = linkSpeedBitsPerSecond
        self.mtu = mtu
    }

    enum CodingKeys: String, CodingKey {
        case index
        case displayName
        case kind
        case isUp
        case isLoopback
        case hasInterfaceStateReport
        case bytesReceived
        case bytesSent
        case hasByteCounters
        case hasByteCounterValues
        case packetsReceived
        case packetsSent
        case receiveErrors
        case sendErrors
        case linkSpeedBitsPerSecond
        case mtu
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let hasUpKey = values.contains(.isUp)
        let hasLoopbackKey = values.contains(.isLoopback)
        let hasBytesReceivedKey = values.contains(.bytesReceived)
        let hasBytesSentKey = values.contains(.bytesSent)
        index = try values.decodeIfPresent(Int.self, forKey: .index) ?? 0
        displayName = Self.reportedInterfaceDisplayName(try values.decodeIfPresent(String.self, forKey: .displayName))
        kind = Self.reportedInterfaceKind(try values.decodeIfPresent(String.self, forKey: .kind))
        isUp = try values.decodeIfPresent(Bool.self, forKey: .isUp) ?? false
        isLoopback = try values.decodeIfPresent(Bool.self, forKey: .isLoopback) ?? false
        hasInterfaceStateReport = try values.decodeIfPresent(Bool.self, forKey: .hasInterfaceStateReport)
            ?? (hasUpKey || hasLoopbackKey)
        bytesReceived = try values.decodeIfPresent(UInt64.self, forKey: .bytesReceived) ?? 0
        bytesSent = try values.decodeIfPresent(UInt64.self, forKey: .bytesSent) ?? 0
        hasByteCounters = try values.decodeIfPresent(Bool.self, forKey: .hasByteCounters)
            ?? (hasBytesReceivedKey && hasBytesSentKey)
        hasByteCounterValues = try values.decodeIfPresent(Bool.self, forKey: .hasByteCounterValues)
            ?? (hasBytesReceivedKey && hasBytesSentKey)
        packetsReceived = try values.decodeIfPresent(UInt64.self, forKey: .packetsReceived)
        packetsSent = try values.decodeIfPresent(UInt64.self, forKey: .packetsSent)
        receiveErrors = try values.decodeIfPresent(UInt64.self, forKey: .receiveErrors)
        sendErrors = try values.decodeIfPresent(UInt64.self, forKey: .sendErrors)
        linkSpeedBitsPerSecond = try values.decodeIfPresent(UInt64.self, forKey: .linkSpeedBitsPerSecond)
        mtu = try values.decodeIfPresent(Int.self, forKey: .mtu)
    }

    private static func reportedInterfaceDisplayName(_ displayName: String?) -> String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty || trimmed == "Interface" ? "未报告" : trimmed
    }

    private static func reportedInterfaceKind(_ kind: String?) -> String {
        let trimmed = kind?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty || trimmed == "Other" ? "未报告" : trimmed
    }

    public var byteCountText: String {
        guard hasByteCounters, hasByteCounterValues else { return "未报告" }
        return "\(MetricFormatting.compactBytes(bytesReceived)) / \(MetricFormatting.compactBytes(bytesSent))"
    }

    public var packetCountText: String {
        guard let packetsReceived, let packetsSent else { return "未报告" }
        return "\(Self.compactCount(packetsReceived)) / \(Self.compactCount(packetsSent))"
    }

    public var packetErrorText: String {
        guard let receiveErrors, let sendErrors else { return "未报告" }
        return "\(Self.compactCount(receiveErrors)) / \(Self.compactCount(sendErrors))"
    }

    public var linkSpeedText: String {
        guard let linkSpeedBitsPerSecond, linkSpeedBitsPerSecond > 0 else { return "未报告" }
        return MetricFormatting.bitRate(bitsPerSecond: Double(linkSpeedBitsPerSecond))
    }

    public var mtuText: String {
        guard let mtu, mtu > 0 else { return "未报告" }
        return "\(mtu)"
    }

    public var stateText: String {
        guard hasInterfaceStateReport else { return "未报告" }
        if isLoopback { return "本机" }
        return isUp ? "在线" : "离线"
    }

    public var hasInventoryReport: Bool {
        displayName != "未报告"
            || kind != "未报告"
            || hasInterfaceStateReport
            || (hasByteCounters && hasByteCounterValues)
            || packetsReceived != nil
            || packetsSent != nil
            || receiveErrors != nil
            || sendErrors != nil
            || (linkSpeedBitsPerSecond ?? 0) > 0
            || (mtu ?? 0) > 0
    }

    private static func compactCount(_ value: UInt64) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

public struct MetricSnapshot: Codable, Equatable, Sendable {
    public var cpuUsage: Double
    public var cpuCoreUsages: [Double]
    public var hasCPUUsageReport: Bool
    public var physicalCoreCount: Int
    public var logicalCoreCount: Int
    public var activeProcessorCount: Int
    public var cpuBrandName: String?
    public var memoryUsedBytes: UInt64
    public var memoryTotalBytes: UInt64
    public var memoryFreeBytes: UInt64
    public var memoryWiredBytes: UInt64
    public var memoryCompressedBytes: UInt64
    public var memoryCachedBytes: UInt64
    public var memorySwapUsedBytes: UInt64
    public var memorySwapTotalBytes: UInt64
    public var memorySwapAvailableBytes: UInt64
    public var hasMemoryCompositionReport: Bool
    public var loadAverage: Double
    public var loadAverage5: Double
    public var loadAverage15: Double
    public var hasLoadAverageReport: Bool
    public var thermalState: String
    public var batteryPercent: Double?
    public var batteryIsCharging: Bool
    public var batteryPowerSource: String?
    public var batteryTimeRemainingMinutes: Int?
    public var batteryCycleCount: Int?
    public var batteryHealth: String?
    public var batteryCurrentCapacity: Int?
    public var batteryMaxCapacity: Int?
    public var batteryDesignCapacity: Int?
    public var batteryVoltageMillivolts: Int?
    public var batteryAmperageMilliamps: Int?
    public var networkBytesPerSecond: UInt64
    public var hasNetworkByteCounters: Bool
    public var hasNetworkDirectionByteCounters: Bool
    public var networkPathStatus: String
    public var networkPathIsExpensive: Bool
    public var networkPathIsConstrained: Bool
    public var hasNetworkPathCostReport: Bool
    public var networkPathSupportsDNS: Bool
    public var networkPathSupportsIPv4: Bool
    public var networkPathSupportsIPv6: Bool
    public var hasNetworkPathSupportReport: Bool
    public var networkPathInterfaceKinds: [String]
    public var networkInBytesPerSecond: UInt64
    public var networkOutBytesPerSecond: UInt64
    public var networkInterfaces: [NetworkInterfaceMetric]
    public var diskFreeBytes: UInt64
    public var diskTotalBytes: UInt64
    public var storageVolumes: [StorageVolumeMetric]
    public var processCount: Int
    public var activeApplicationCount: Int
    public var hiddenApplicationCount: Int
    public var hasRunningAppCountReport: Bool
    public var runningApps: [ProcessMetric]
    public var gpuDevices: [GPUDeviceMetric]
    public var displays: [DisplayMetric]
    public var uptimeSeconds: TimeInterval
    public var hasUptimeReport: Bool
    public var osVersion: String
    public var kernelRelease: String
    public var timestamp: Date

    public init(
        cpuUsage: Double,
        cpuCoreUsages: [Double] = [],
        hasCPUUsageReport: Bool = false,
        physicalCoreCount: Int = 0,
        logicalCoreCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        activeProcessorCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        cpuBrandName: String? = nil,
        memoryUsedBytes: UInt64,
        memoryTotalBytes: UInt64,
        memoryFreeBytes: UInt64 = 0,
        memoryWiredBytes: UInt64 = 0,
        memoryCompressedBytes: UInt64 = 0,
        memoryCachedBytes: UInt64 = 0,
        memorySwapUsedBytes: UInt64 = 0,
        memorySwapTotalBytes: UInt64 = 0,
        memorySwapAvailableBytes: UInt64 = 0,
        hasMemoryCompositionReport: Bool = false,
        loadAverage: Double,
        loadAverage5: Double = 0,
        loadAverage15: Double = 0,
        hasLoadAverageReport: Bool = false,
        thermalState: String,
        batteryPercent: Double?,
        batteryIsCharging: Bool,
        batteryPowerSource: String? = nil,
        batteryTimeRemainingMinutes: Int? = nil,
        batteryCycleCount: Int? = nil,
        batteryHealth: String? = nil,
        batteryCurrentCapacity: Int? = nil,
        batteryMaxCapacity: Int? = nil,
        batteryDesignCapacity: Int? = nil,
        batteryVoltageMillivolts: Int? = nil,
        batteryAmperageMilliamps: Int? = nil,
        networkBytesPerSecond: UInt64 = 0,
        hasNetworkByteCounters: Bool = false,
        hasNetworkDirectionByteCounters: Bool? = nil,
        networkPathStatus: String = "unknown",
        networkPathIsExpensive: Bool = false,
        networkPathIsConstrained: Bool = false,
        hasNetworkPathCostReport: Bool = false,
        networkPathSupportsDNS: Bool = false,
        networkPathSupportsIPv4: Bool = false,
        networkPathSupportsIPv6: Bool = false,
        hasNetworkPathSupportReport: Bool = false,
        networkPathInterfaceKinds: [String] = [],
        networkInBytesPerSecond: UInt64 = 0,
        networkOutBytesPerSecond: UInt64 = 0,
        networkInterfaces: [NetworkInterfaceMetric] = [],
        diskFreeBytes: UInt64,
        diskTotalBytes: UInt64 = 0,
        storageVolumes: [StorageVolumeMetric] = [],
        processCount: Int = 0,
        activeApplicationCount: Int = 0,
        hiddenApplicationCount: Int = 0,
        hasRunningAppCountReport: Bool = false,
        runningApps: [ProcessMetric] = [],
        gpuDevices: [GPUDeviceMetric] = [],
        displays: [DisplayMetric] = [],
        uptimeSeconds: TimeInterval = 0,
        hasUptimeReport: Bool = false,
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        kernelRelease: String = "",
        timestamp: Date
    ) {
        self.cpuUsage = cpuUsage
        self.cpuCoreUsages = cpuCoreUsages
        self.hasCPUUsageReport = hasCPUUsageReport
        self.physicalCoreCount = physicalCoreCount
        self.logicalCoreCount = logicalCoreCount
        self.activeProcessorCount = activeProcessorCount
        self.cpuBrandName = cpuBrandName
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.memoryFreeBytes = memoryFreeBytes
        self.memoryWiredBytes = memoryWiredBytes
        self.memoryCompressedBytes = memoryCompressedBytes
        self.memoryCachedBytes = memoryCachedBytes
        self.memorySwapUsedBytes = memorySwapUsedBytes
        self.memorySwapTotalBytes = memorySwapTotalBytes
        self.memorySwapAvailableBytes = memorySwapAvailableBytes
        self.hasMemoryCompositionReport = hasMemoryCompositionReport
        self.loadAverage = loadAverage
        self.loadAverage5 = loadAverage5
        self.loadAverage15 = loadAverage15
        self.hasLoadAverageReport = hasLoadAverageReport
            || loadAverage > 0
            || loadAverage5 > 0
            || loadAverage15 > 0
        self.thermalState = thermalState
        self.batteryPercent = batteryPercent
        self.batteryIsCharging = batteryIsCharging
        self.batteryPowerSource = Self.reportedPowerSource(batteryPowerSource)
        self.batteryTimeRemainingMinutes = batteryTimeRemainingMinutes
        self.batteryCycleCount = batteryCycleCount
        self.batteryHealth = batteryHealth
        self.batteryCurrentCapacity = batteryCurrentCapacity
        self.batteryMaxCapacity = batteryMaxCapacity
        self.batteryDesignCapacity = batteryDesignCapacity
        self.batteryVoltageMillivolts = batteryVoltageMillivolts
        self.batteryAmperageMilliamps = batteryAmperageMilliamps
        self.networkBytesPerSecond = networkBytesPerSecond
        self.hasNetworkDirectionByteCounters = hasNetworkDirectionByteCounters
            ?? (hasNetworkByteCounters
                || networkInBytesPerSecond > 0
                || networkOutBytesPerSecond > 0
                || networkInterfaces.contains { $0.hasByteCounters })
        self.hasNetworkByteCounters = hasNetworkByteCounters
            || networkBytesPerSecond > 0
            || self.hasNetworkDirectionByteCounters
            || networkInBytesPerSecond > 0
            || networkOutBytesPerSecond > 0
            || networkInterfaces.contains { $0.hasByteCounters }
        self.networkPathStatus = networkPathStatus
        self.networkPathIsExpensive = networkPathIsExpensive
        self.networkPathIsConstrained = networkPathIsConstrained
        self.hasNetworkPathCostReport = hasNetworkPathCostReport
        self.networkPathSupportsDNS = networkPathSupportsDNS
        self.networkPathSupportsIPv4 = networkPathSupportsIPv4
        self.networkPathSupportsIPv6 = networkPathSupportsIPv6
        self.hasNetworkPathSupportReport = hasNetworkPathSupportReport
        self.networkPathInterfaceKinds = networkPathInterfaceKinds
        self.networkInBytesPerSecond = networkInBytesPerSecond
        self.networkOutBytesPerSecond = networkOutBytesPerSecond
        self.networkInterfaces = networkInterfaces
        self.diskFreeBytes = diskFreeBytes
        self.diskTotalBytes = diskTotalBytes
        self.storageVolumes = storageVolumes
        self.processCount = processCount
        self.activeApplicationCount = activeApplicationCount
        self.hiddenApplicationCount = hiddenApplicationCount
        self.hasRunningAppCountReport = hasRunningAppCountReport
            || processCount > 0
            || activeApplicationCount > 0
            || hiddenApplicationCount > 0
        self.runningApps = runningApps
        self.gpuDevices = gpuDevices
        self.displays = displays
        self.uptimeSeconds = uptimeSeconds
        self.hasUptimeReport = hasUptimeReport || uptimeSeconds > 0
        self.osVersion = osVersion
        self.kernelRelease = kernelRelease
        self.timestamp = timestamp
    }

    private static func reportedPowerSource(_ source: String?) -> String? {
        let trimmed = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    public static let placeholder = MetricSnapshot(
        cpuUsage: 0,
        cpuCoreUsages: [],
        hasCPUUsageReport: false,
        physicalCoreCount: 0,
        logicalCoreCount: 0,
        activeProcessorCount: 0,
        cpuBrandName: nil,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        memoryFreeBytes: 0,
        memoryWiredBytes: 0,
        memoryCompressedBytes: 0,
        memoryCachedBytes: 0,
        memorySwapUsedBytes: 0,
        memorySwapTotalBytes: 0,
        memorySwapAvailableBytes: 0,
        loadAverage: 0,
        loadAverage5: 0,
        loadAverage15: 0,
        thermalState: "Unknown",
        batteryPercent: nil,
        batteryIsCharging: false,
        batteryPowerSource: nil,
        batteryTimeRemainingMinutes: nil,
        batteryCycleCount: nil,
        batteryHealth: nil,
        batteryCurrentCapacity: nil,
        batteryMaxCapacity: nil,
        batteryDesignCapacity: nil,
        batteryVoltageMillivolts: nil,
        batteryAmperageMilliamps: nil,
        networkBytesPerSecond: 0,
        networkPathStatus: "unknown",
        networkPathInterfaceKinds: [],
        networkInBytesPerSecond: 0,
        networkOutBytesPerSecond: 0,
        networkInterfaces: [],
        diskFreeBytes: 0,
        diskTotalBytes: 0,
        storageVolumes: [],
        processCount: 0,
        activeApplicationCount: 0,
        hiddenApplicationCount: 0,
        runningApps: [],
        gpuDevices: [],
        displays: [],
        uptimeSeconds: 0,
        osVersion: "macOS",
        kernelRelease: "",
        timestamp: Date(timeIntervalSince1970: 0)
    )

    public var memoryUsage: Double {
        guard hasMemoryUsageReport else { return 0 }
        return min(Double(memoryUsedBytes) / Double(memoryTotalBytes), 1)
    }

    public var memorySwapUsage: Double {
        guard hasMemorySwapReport else { return 0 }
        return min(Double(memorySwapUsedBytes) / Double(memorySwapTotalBytes), 1)
    }

    public var diskUsage: Double {
        guard hasDiskUsageReport else { return 0 }
        return min(Double(diskUsedBytes) / Double(diskTotalBytes), 1)
    }

    public var diskUsedBytes: UInt64 {
        guard diskTotalBytes >= diskFreeBytes else { return 0 }
        return diskTotalBytes - diskFreeBytes
    }

    private var hasMemoryCapacityReport: Bool {
        memoryTotalBytes > 0
    }
    public var hasMemoryUsageReport: Bool {
        hasMemoryCapacityReport
    }
    public var hasMemorySwapReport: Bool {
        memorySwapTotalBytes > 0
    }
    public var hasDiskUsageReport: Bool {
        diskTotalBytes > 0 && diskFreeBytes <= diskTotalBytes
    }

    public var memoryActiveBytes: UInt64 {
        guard hasMemoryCompositionReport else { return 0 }
        guard memoryUsedBytes >= memoryWiredBytes else { return 0 }
        let remainingAfterWired = memoryUsedBytes - memoryWiredBytes
        guard remainingAfterWired >= memoryCompressedBytes else { return 0 }
        return remainingAfterWired - memoryCompressedBytes
    }

    private func reportedMemoryText(_ bytes: UInt64) -> String {
        guard hasMemoryCapacityReport else { return "未报告" }
        return MetricFormatting.bytes(bytes)
    }

    private func reportedMemoryCompositionText(_ bytes: UInt64) -> String {
        guard hasMemoryCapacityReport else { return "未报告" }
        guard hasMemoryCompositionReport else { return "未报告" }
        return MetricFormatting.bytes(bytes)
    }

    private func reportedSwapText(_ bytes: UInt64) -> String {
        guard hasMemorySwapReport else { return "未报告" }
        return MetricFormatting.bytes(bytes)
    }

    public var cpuText: String {
        guard hasCPUUsageReport else { return "未报告" }
        return MetricFormatting.percentage(cpuUsage)
    }
    public var cpuBrandText: String {
        guard let cpuBrandName, !cpuBrandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "未报告" }
        return cpuBrandName
    }
    private static func reportedCountText(_ value: Int) -> String {
        value > 0 ? "\(value)" : "未报告"
    }

    public var physicalCoreCountText: String { Self.reportedCountText(physicalCoreCount) }
    public var logicalCoreCountText: String { Self.reportedCountText(logicalCoreCount) }
    public var activeProcessorCountText: String { Self.reportedCountText(activeProcessorCount) }
    public var logicalCoreSummaryText: String {
        logicalCoreCount > 0 ? "\(logicalCoreCount) 逻辑核心" : "未报告"
    }

    public var memoryUsageText: String {
        guard hasMemoryCapacityReport else { return "未报告" }
        return MetricFormatting.percentage(memoryUsage)
    }
    public var memoryText: String { reportedMemoryText(memoryUsedBytes) }
    public var memoryDetailText: String { reportedMemoryText(memoryTotalBytes) }
    public var memoryFreeText: String { reportedMemoryCompositionText(memoryFreeBytes) }
    public var memoryWiredText: String { reportedMemoryCompositionText(memoryWiredBytes) }
    public var memoryCompressedText: String { reportedMemoryCompositionText(memoryCompressedBytes) }
    public var memoryCachedText: String { reportedMemoryCompositionText(memoryCachedBytes) }
    public var memoryActiveText: String { reportedMemoryCompositionText(memoryActiveBytes) }
    public var memorySwapText: String { reportedSwapText(memorySwapUsedBytes) }
    public var memorySwapAvailableText: String { reportedSwapText(memorySwapAvailableBytes) }
    public var memorySwapTotalText: String { reportedSwapText(memorySwapTotalBytes) }
    private func reportedLoadText(_ value: Double) -> String {
        guard hasLoadAverageReport else { return "未报告" }
        return MetricFormatting.load(value)
    }

    public var loadText: String { loadAverageText }
    public var loadAverageText: String { reportedLoadText(loadAverage) }
    public var loadAverage5Text: String { reportedLoadText(loadAverage5) }
    public var loadAverage15Text: String { reportedLoadText(loadAverage15) }
    private func reportedLoadProgress(_ value: Double) -> Double? {
        guard hasLoadAverageReport, activeProcessorCount > 0 else { return nil }
        return min(max(value / Double(activeProcessorCount), 0), 1)
    }

    public var loadAverageProgress: Double? { reportedLoadProgress(loadAverage) }
    public var loadAverage5Progress: Double? { reportedLoadProgress(loadAverage5) }
    public var loadAverage15Progress: Double? { reportedLoadProgress(loadAverage15) }
    public var loadDetailText: String {
        guard hasLoadAverageReport else { return "未报告" }
        return "\(loadAverageText) / \(loadAverage5Text) / \(loadAverage15Text)"
    }
    private func sourceStatusText(hasAnyReport: Bool, hasFullReport: Bool) -> String {
        hasAnyReport ? (hasFullReport ? "已报告" : "部分报告") : "未报告"
    }
    public var cpuMemorySourceStatusText: String {
        sourceStatusText(
            hasAnyReport: hasCPUUsageReport || logicalCoreCount > 0 || hasMemoryUsageReport,
            hasFullReport: hasCPUUsageReport && logicalCoreCount > 0 && hasMemoryUsageReport
        )
    }
    public var loadAverageSourceStatusText: String {
        sourceStatusText(
            hasAnyReport: hasLoadAverageReport,
            hasFullReport: hasLoadAverageReport
        )
    }
    public var networkSourceStatusText: String {
        let hasPathReport = hasNetworkPathReport
        let hasInterfaceReport = hasNetworkInterfaceReport || hasNetworkByteCounters
        return sourceStatusText(
            hasAnyReport: hasPathReport || hasInterfaceReport,
            hasFullReport: hasPathReport && hasInterfaceReport
        )
    }
    public var runningAppsSourceStatusText: String {
        sourceStatusText(
            hasAnyReport: hasReportedRunningAppCounts || runningApps.contains(where: \.hasInventoryReport),
            hasFullReport: hasReportedRunningAppCounts && runningApps.contains(where: \.hasInventoryReport)
        )
    }
    public var hasRunningAppReport: Bool {
        hasReportedRunningAppCounts || runningApps.contains(where: \.hasInventoryReport)
    }
    private var hasReportedRunningAppCounts: Bool {
        hasRunningAppCountReport
    }
    public var runningAppSummaryText: String {
        guard hasRunningAppReport else { return "未报告" }
        guard hasReportedRunningAppCounts else {
            let reportedListCount = runningApps.filter(\.hasInventoryReport).count
            return "列表 \(reportedListCount) · 总数未报告"
        }
        return "\(processCount) 个 · 前台 \(activeApplicationCount) · 隐藏 \(hiddenApplicationCount)"
    }
    public var runningAppCountText: String {
        runningAppCountText(processCount)
    }
    public var runningAppListCountText: String {
        let reportedListCount = runningApps.filter(\.hasInventoryReport).count
        return runningAppListCountText(reportedListCount)
    }
    public var activeApplicationCountText: String {
        runningAppCountText(activeApplicationCount)
    }
    public var hiddenApplicationCountText: String {
        runningAppCountText(hiddenApplicationCount)
    }

    private func runningAppCountText(_ count: Int) -> String {
        guard hasReportedRunningAppCounts else { return "未报告" }
        return "\(count)"
    }
    private func runningAppListCountText(_ count: Int) -> String {
        guard count > 0 else { return "未报告" }
        return "\(count)"
    }
    public var gpuDisplaySourceStatusText: String {
        return sourceStatusText(
            hasAnyReport: hasGPUReport || hasDisplayReport,
            hasFullReport: hasGPUReport && hasDisplayReport
        )
    }
    public var storageSourceStatusText: String {
        let hasPrimaryDiskReport = hasDiskUsageReport
        return sourceStatusText(
            hasAnyReport: hasPrimaryDiskReport || hasStorageVolumeReport,
            hasFullReport: hasPrimaryDiskReport && hasStorageVolumeReport
        )
    }
    public var powerThermalSourceStatusText: String {
        let hasPowerReport = hasPowerStatusReport
        let hasThermalReport = hasThermalStateReport
        return sourceStatusText(
            hasAnyReport: hasPowerReport || hasThermalReport,
            hasFullReport: hasPowerReport && hasThermalReport
        )
    }
    public var systemVersionSourceStatusText: String {
        return sourceStatusText(
            hasAnyReport: hasOSVersionReport || hasUptimeReport || hasKernelReleaseReport,
            hasFullReport: hasOSVersionReport && hasUptimeReport && hasKernelReleaseReport
        )
    }
    public var thermalText: String {
        switch thermalState.lowercased() {
        case "nominal": return "正常"
        case "warm", "fair": return "偏热"
        case "hot", "serious": return "较热"
        case "critical": return "严重"
        default: return "未报告"
        }
    }
    public var hasThermalStateReport: Bool {
        switch thermalState.lowercased() {
        case "nominal", "warm", "fair", "hot", "serious", "critical":
            return true
        default:
            return false
        }
    }
    public var thermalLimitText: String {
        switch thermalState.lowercased() {
        case "critical": return "可能强限制"
        case "hot", "serious": return "可能降频"
        case "warm", "fair": return "轻微压力"
        case "nominal": return "无明显限制"
        default: return "未报告"
        }
    }
    public var batteryPercentText: String {
        guard let batteryPercent else { return "未报告" }
        return MetricFormatting.percentage(batteryPercent)
    }
    public var powerSourceText: String {
        switch batteryPowerSource?.lowercased() {
        case "ac power":
            return batteryIsCharging ? "电源适配器 · 充电中" : "电源适配器"
        case "battery power":
            return "电池供电"
        case "ups power":
            return "UPS 供电"
        case .some(let value) where !value.isEmpty:
            return value
        default:
            if batteryPercent == nil {
                guard batteryPowerSource != nil else { return "未报告" }
                return "无电池"
            }
            return batteryIsCharging ? "电源适配器 · 充电中" : "电源状态未报告"
        }
    }
    public var powerStatusText: String {
        batteryPercent == nil ? powerSourceText : batteryPercentText
    }
    public var hasPowerStatusReport: Bool {
        batteryPercent != nil || batteryPowerSource != nil
    }
    public var powerStatusProgress: Double? {
        batteryPercent
    }
    public var powerStatusTone: MetricStatusTone {
        if let batteryPercent {
            if batteryPercent < 0.2 {
                return .critical
            }

            if batteryIsCharging {
                return .normal
            }

            switch batteryPowerSource?.lowercased() {
            case "ac power":
                return .normal
            case "battery power", "ups power":
                return .warning
            case .some(let value) where !value.isEmpty:
                return .neutral
            default:
                return .warning
            }
        }

        switch batteryPowerSource?.lowercased() {
        case "ac power":
            return .normal
        case "battery power", "ups power":
            return .warning
        case .some(let value) where !value.isEmpty:
            return .neutral
        default:
            return .neutral
        }
    }
    public var powerStatusTitle: String {
        batteryPercent == nil ? "电源" : "电池"
    }
    public var networkText: String {
        guard hasNetworkByteCounters else { return "未报告" }
        return MetricFormatting.networkRate(bytesPerSecond: networkBytesPerSecond)
    }
    public var hasNetworkPathReport: Bool {
        switch networkPathStatus.lowercased() {
        case "satisfied", "unsatisfied", "requiresconnection", "requires_connection", "requires connection":
            return true
        default:
            return false
        }
    }
    private var isNetworkPathOffline: Bool {
        networkPathStatus.lowercased() == "unsatisfied"
    }
    public var networkPathText: String {
        switch networkPathStatus.lowercased() {
        case "satisfied":
            return "在线"
        case "unsatisfied":
            return "离线"
        case "requiresconnection", "requires_connection", "requires connection":
            return "需连接"
        default:
            return "未报告"
        }
    }
    public var networkPathDetailText: String {
        guard hasNetworkPathReport else { return "未报告" }

        var parts: [String] = []

        switch networkPathStatus.lowercased() {
        case "satisfied", "requiresconnection", "requires_connection", "requires connection":
            if networkPathInterfaceKinds.isEmpty {
                parts.append("本机网络")
            } else {
                parts.append(networkPathInterfaceKinds.joined(separator: " / "))
            }
        case "unsatisfied":
            parts.append("无可用连接")
        default:
            parts.append("未报告")
        }

        if hasNetworkPathCostReport && networkPathIsConstrained {
            parts.append("低数据模式")
        }

        if hasNetworkPathCostReport && networkPathIsExpensive {
            parts.append("计量网络")
        }

        return parts.joined(separator: " · ")
    }
    public var networkPathCapabilityText: String {
        guard hasNetworkPathReport else { return "未报告" }

        if isNetworkPathOffline {
            return "不可用"
        }

        guard hasNetworkPathSupportReport else { return "未报告" }

        var parts: [String] = []
        if networkPathSupportsDNS { parts.append("DNS") }
        if networkPathSupportsIPv4 { parts.append("IPv4") }
        if networkPathSupportsIPv6 { parts.append("IPv6") }
        return parts.isEmpty ? "不支持" : parts.joined(separator: " / ")
    }
    public var networkRuleStatusText: String {
        guard hasNetworkPathReport else { return "未报告" }
        return networkPathStatus.lowercased() == "satisfied" ? "正常" : "注意"
    }
    public var networkDNSCapabilityText: String {
        networkPathSupportText(networkPathSupportsDNS)
    }
    public var networkIPv4CapabilityText: String {
        networkPathSupportText(networkPathSupportsIPv4)
    }
    public var networkIPv6CapabilityText: String {
        networkPathSupportText(networkPathSupportsIPv6)
    }
    public var networkLowDataModeText: String {
        networkPathFlagText(networkPathIsConstrained)
    }
    public var networkMeteredText: String {
        networkPathFlagText(networkPathIsExpensive)
    }

    private func networkPathSupportText(_ isSupported: Bool) -> String {
        guard hasNetworkPathReport else { return "未报告" }
        guard !isNetworkPathOffline else { return "不可用" }
        guard hasNetworkPathSupportReport else { return "未报告" }
        return isSupported ? "支持" : "不支持"
    }

    private func networkPathFlagText(_ isEnabled: Bool) -> String {
        guard hasNetworkPathReport else { return "未报告" }
        guard !isNetworkPathOffline else { return "不可用" }
        guard hasNetworkPathCostReport else { return "未报告" }
        return isEnabled ? "开启" : "关闭"
    }
    public var networkInText: String {
        guard hasNetworkDirectionByteCounters else { return "未报告" }
        return MetricFormatting.byteRate(bytesPerSecond: networkInBytesPerSecond)
    }
    public var networkOutText: String {
        guard hasNetworkDirectionByteCounters else { return "未报告" }
        return MetricFormatting.byteRate(bytesPerSecond: networkOutBytesPerSecond)
    }
    public var diskText: String {
        guard hasDiskUsageReport else { return "未报告" }
        return "\(MetricFormatting.compactBytes(diskFreeBytes)) 可用"
    }
    public var diskUsageText: String {
        guard hasDiskUsageReport else { return "未报告" }
        return MetricFormatting.percentage(diskUsage)
    }
    public var diskUsedText: String {
        guard hasDiskUsageReport else { return "未报告" }
        return MetricFormatting.bytes(diskUsedBytes)
    }
    public var diskTotalText: String {
        guard hasDiskUsageReport else { return "未报告" }
        return MetricFormatting.bytes(diskTotalBytes)
    }
    public var diskAvailableText: String {
        guard hasDiskUsageReport else { return "未报告" }
        return MetricFormatting.compactBytes(diskFreeBytes)
    }
    public var hasStorageVolumeReport: Bool {
        storageVolumes.contains(where: \.hasInventoryReport)
    }
    public var storageVolumeSummaryText: String {
        guard hasStorageVolumeReport else { return "未报告" }
        let reportedVolumeCount = storageVolumes.filter(\.hasInventoryReport).count
        return "\(reportedVolumeCount) 个卷"
    }
    public var hasExternalStorageVolumeSummaryReport: Bool {
        let reportedVolumes = storageVolumes.filter(\.hasInventoryReport)
        return !reportedVolumes.isEmpty && reportedVolumes.allSatisfy(\.hasKindReport)
    }
    public var externalStorageVolumeSummaryText: String {
        guard hasExternalStorageVolumeSummaryReport else { return "未报告" }
        let reportedVolumes = storageVolumes.filter(\.hasInventoryReport)
        let externalCount = reportedVolumes.filter(\.isExternalVolume).count
        return "\(externalCount) 个"
    }
    public var hasSampleTimeReport: Bool {
        timestamp.timeIntervalSince1970 > 0
    }
    public var sampleTimeText: String {
        guard hasSampleTimeReport else { return "未报告" }
        return timestamp.formatted(.dateTime.hour().minute().second())
    }
    public var sampleClockText: String {
        guard hasSampleTimeReport else { return "未报告" }
        return timestamp.formatted(.dateTime.hour().minute())
    }
    public var hasOSVersionReport: Bool {
        let trimmedVersion = osVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedVersion.isEmpty && trimmedVersion != "macOS"
    }
    public var osVersionText: String {
        guard hasOSVersionReport else { return "未报告" }
        return osVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public var uptimeText: String {
        guard hasUptimeReport else { return "未报告" }
        return MetricFormatting.duration(uptimeSeconds)
    }
    public var hasKernelReleaseReport: Bool {
        !kernelRelease.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    public var kernelText: String {
        guard hasKernelReleaseReport else { return "未报告" }
        return "Darwin \(kernelRelease.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
    public var batteryTimeRemainingText: String {
        guard let batteryTimeRemainingMinutes else { return "未报告" }
        return MetricFormatting.minutes(batteryTimeRemainingMinutes)
    }
    public var batteryCycleText: String {
        guard let batteryCycleCount else { return "未报告" }
        return "\(batteryCycleCount)"
    }
    public var batteryCurrentCapacityText: String {
        reportedBatteryIntegerText(batteryCurrentCapacity)
    }
    public var batteryMaxCapacityText: String {
        reportedBatteryIntegerText(batteryMaxCapacity)
    }
    public var batteryDesignCapacityText: String {
        reportedBatteryIntegerText(batteryDesignCapacity)
    }
    public var batteryVoltageText: String {
        reportedBatteryElectricalText(batteryVoltageMillivolts, unit: "mV")
    }
    public var batteryAmperageText: String {
        reportedBatteryElectricalText(batteryAmperageMilliamps, unit: "mA")
    }
    public var batteryHealthText: String {
        let trimmedHealth = batteryHealth?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedHealth.isEmpty else { return "未报告" }

        switch trimmedHealth.lowercased() {
        case "good":
            return "良好"
        case "fair":
            return "一般"
        case "poor":
            return "较差"
        case "check battery":
            return "建议检查"
        case "permanent battery failure":
            return "需要维修"
        default:
            return trimmedHealth
        }
    }

    private func reportedBatteryIntegerText(_ value: Int?) -> String {
        guard let value else { return "未报告" }
        return "\(value)"
    }

    private func reportedBatteryElectricalText(_ value: Int?, unit: String) -> String {
        guard let value else { return "未报告" }
        return "\(value) \(unit)"
    }
    public var gpuSummaryText: String {
        let reportedGPUCount = gpuDevices.filter(\.hasInventoryReport).count
        guard reportedGPUCount > 0 else { return "未报告" }
        return "\(reportedGPUCount) 个"
    }
    public var primaryGPUName: String {
        gpuDevices.first { $0.name != "未报告" }?.name ?? "未报告"
    }
    public var hasGPUReport: Bool {
        gpuDevices.contains(where: \.hasInventoryReport)
    }
    public var hasDisplayReport: Bool {
        displays.contains(where: \.hasInventoryReport)
    }
    public var hasGPUDisplayReport: Bool {
        hasGPUReport || hasDisplayReport
    }
    public var gpuDisplaySummaryText: String {
        let reportedGPUCount = gpuDevices.filter(\.hasInventoryReport).count
        let reportedDisplayCount = displays.filter(\.hasInventoryReport).count
        let gpuText = reportedGPUCount == 0 ? "GPU 未报告" : "\(reportedGPUCount) GPU"
        let displayText = reportedDisplayCount == 0 ? "显示器未报告" : "\(reportedDisplayCount) 显示器"
        return "\(gpuText) / \(displayText)"
    }
    public var displaySummaryText: String {
        let reportedDisplayCount = displays.filter(\.hasInventoryReport).count
        guard hasDisplayReport else { return "未报告" }
        return "\(reportedDisplayCount) 台显示器"
    }
    public var networkInterfaceSummary: String {
        guard hasNetworkInterfaceReport else { return "未报告" }
        guard networkInterfaces.contains(where: \.hasInterfaceStateReport) else { return "未报告" }
        let activeCount = networkInterfaces.filter { $0.hasInterfaceStateReport && $0.isUp && !$0.isLoopback }.count
        return "\(activeCount) 个活动接口"
    }
    public var hasNetworkInterfaceReport: Bool {
        networkInterfaces.contains(where: \.hasInterfaceStateReport)
    }

    enum CodingKeys: String, CodingKey {
        case cpuUsage
        case cpuCoreUsages
        case hasCPUUsageReport
        case physicalCoreCount
        case logicalCoreCount
        case activeProcessorCount
        case cpuBrandName
        case memoryUsedBytes
        case memoryTotalBytes
        case memoryFreeBytes
        case memoryWiredBytes
        case memoryCompressedBytes
        case memoryCachedBytes
        case memorySwapUsedBytes
        case memorySwapTotalBytes
        case memorySwapAvailableBytes
        case hasMemoryCompositionReport
        case loadAverage
        case loadAverage5
        case loadAverage15
        case hasLoadAverageReport
        case thermalState
        case batteryPercent
        case batteryIsCharging
        case batteryPowerSource
        case batteryTimeRemainingMinutes
        case batteryCycleCount
        case batteryHealth
        case batteryCurrentCapacity
        case batteryMaxCapacity
        case batteryDesignCapacity
        case batteryVoltageMillivolts
        case batteryAmperageMilliamps
        case networkBytesPerSecond
        case hasNetworkByteCounters
        case hasNetworkDirectionByteCounters
        case networkPathStatus
        case networkPathIsExpensive
        case networkPathIsConstrained
        case hasNetworkPathCostReport
        case networkPathSupportsDNS
        case networkPathSupportsIPv4
        case networkPathSupportsIPv6
        case hasNetworkPathSupportReport
        case networkPathInterfaceKinds
        case networkInBytesPerSecond
        case networkOutBytesPerSecond
        case networkInterfaces
        case diskFreeBytes
        case diskTotalBytes
        case storageVolumes
        case processCount
        case activeApplicationCount
        case hiddenApplicationCount
        case hasRunningAppCountReport
        case runningApps = "topProcesses"
        case gpuDevices
        case displays
        case uptimeSeconds
        case hasUptimeReport
        case osVersion
        case kernelRelease
        case timestamp
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cpuUsage = try values.decodeIfPresent(Double.self, forKey: .cpuUsage) ?? Self.placeholder.cpuUsage
        cpuCoreUsages = try values.decodeIfPresent([Double].self, forKey: .cpuCoreUsages) ?? []
        hasCPUUsageReport = try values.decodeIfPresent(Bool.self, forKey: .hasCPUUsageReport)
            ?? (cpuUsage > 0 || !cpuCoreUsages.isEmpty)
        physicalCoreCount = try values.decodeIfPresent(Int.self, forKey: .physicalCoreCount) ?? Self.placeholder.physicalCoreCount
        logicalCoreCount = try values.decodeIfPresent(Int.self, forKey: .logicalCoreCount) ?? Self.placeholder.logicalCoreCount
        activeProcessorCount = try values.decodeIfPresent(Int.self, forKey: .activeProcessorCount) ?? Self.placeholder.activeProcessorCount
        cpuBrandName = try values.decodeIfPresent(String.self, forKey: .cpuBrandName)
        memoryUsedBytes = try values.decodeIfPresent(UInt64.self, forKey: .memoryUsedBytes) ?? Self.placeholder.memoryUsedBytes
        memoryTotalBytes = try values.decodeIfPresent(UInt64.self, forKey: .memoryTotalBytes) ?? Self.placeholder.memoryTotalBytes
        memoryFreeBytes = try values.decodeIfPresent(UInt64.self, forKey: .memoryFreeBytes) ?? 0
        memoryWiredBytes = try values.decodeIfPresent(UInt64.self, forKey: .memoryWiredBytes) ?? 0
        memoryCompressedBytes = try values.decodeIfPresent(UInt64.self, forKey: .memoryCompressedBytes) ?? 0
        memoryCachedBytes = try values.decodeIfPresent(UInt64.self, forKey: .memoryCachedBytes) ?? 0
        memorySwapUsedBytes = try values.decodeIfPresent(UInt64.self, forKey: .memorySwapUsedBytes) ?? 0
        memorySwapTotalBytes = try values.decodeIfPresent(UInt64.self, forKey: .memorySwapTotalBytes) ?? 0
        memorySwapAvailableBytes = try values.decodeIfPresent(UInt64.self, forKey: .memorySwapAvailableBytes) ?? 0
        hasMemoryCompositionReport = try values.decodeIfPresent(Bool.self, forKey: .hasMemoryCompositionReport)
            ?? (values.contains(.memoryFreeBytes)
                && values.contains(.memoryWiredBytes)
                && values.contains(.memoryCompressedBytes)
                && values.contains(.memoryCachedBytes))
        loadAverage = try values.decodeIfPresent(Double.self, forKey: .loadAverage) ?? Self.placeholder.loadAverage
        loadAverage5 = try values.decodeIfPresent(Double.self, forKey: .loadAverage5) ?? 0
        loadAverage15 = try values.decodeIfPresent(Double.self, forKey: .loadAverage15) ?? 0
        hasLoadAverageReport = try values.decodeIfPresent(Bool.self, forKey: .hasLoadAverageReport)
            ?? (loadAverage > 0 || loadAverage5 > 0 || loadAverage15 > 0)
        thermalState = try values.decodeIfPresent(String.self, forKey: .thermalState) ?? "Unknown"
        batteryPercent = try values.decodeIfPresent(Double.self, forKey: .batteryPercent)
        batteryIsCharging = try values.decodeIfPresent(Bool.self, forKey: .batteryIsCharging) ?? false
        batteryPowerSource = Self.reportedPowerSource(try values.decodeIfPresent(String.self, forKey: .batteryPowerSource))
        batteryTimeRemainingMinutes = try values.decodeIfPresent(Int.self, forKey: .batteryTimeRemainingMinutes)
        batteryCycleCount = try values.decodeIfPresent(Int.self, forKey: .batteryCycleCount)
        batteryHealth = try values.decodeIfPresent(String.self, forKey: .batteryHealth)
        batteryCurrentCapacity = try values.decodeIfPresent(Int.self, forKey: .batteryCurrentCapacity)
        batteryMaxCapacity = try values.decodeIfPresent(Int.self, forKey: .batteryMaxCapacity)
        batteryDesignCapacity = try values.decodeIfPresent(Int.self, forKey: .batteryDesignCapacity)
        batteryVoltageMillivolts = try values.decodeIfPresent(Int.self, forKey: .batteryVoltageMillivolts)
        batteryAmperageMilliamps = try values.decodeIfPresent(Int.self, forKey: .batteryAmperageMilliamps)
        networkBytesPerSecond = try values.decodeIfPresent(UInt64.self, forKey: .networkBytesPerSecond) ?? 0
        let decodedHasNetworkByteCounters = try values.decodeIfPresent(Bool.self, forKey: .hasNetworkByteCounters)
        let decodedHasNetworkDirectionByteCounters = try values.decodeIfPresent(Bool.self, forKey: .hasNetworkDirectionByteCounters)
        networkPathStatus = try values.decodeIfPresent(String.self, forKey: .networkPathStatus) ?? "unknown"
        let hasNetworkPathExpensiveKey = values.contains(.networkPathIsExpensive)
        let hasNetworkPathConstrainedKey = values.contains(.networkPathIsConstrained)
        networkPathIsExpensive = try values.decodeIfPresent(Bool.self, forKey: .networkPathIsExpensive) ?? false
        networkPathIsConstrained = try values.decodeIfPresent(Bool.self, forKey: .networkPathIsConstrained) ?? false
        hasNetworkPathCostReport = try values.decodeIfPresent(Bool.self, forKey: .hasNetworkPathCostReport)
            ?? (hasNetworkPathExpensiveKey && hasNetworkPathConstrainedKey)
        let hasNetworkPathDNSKey = values.contains(.networkPathSupportsDNS)
        let hasNetworkPathIPv4Key = values.contains(.networkPathSupportsIPv4)
        let hasNetworkPathIPv6Key = values.contains(.networkPathSupportsIPv6)
        networkPathSupportsDNS = try values.decodeIfPresent(Bool.self, forKey: .networkPathSupportsDNS) ?? false
        networkPathSupportsIPv4 = try values.decodeIfPresent(Bool.self, forKey: .networkPathSupportsIPv4) ?? false
        networkPathSupportsIPv6 = try values.decodeIfPresent(Bool.self, forKey: .networkPathSupportsIPv6) ?? false
        hasNetworkPathSupportReport = try values.decodeIfPresent(Bool.self, forKey: .hasNetworkPathSupportReport)
            ?? (hasNetworkPathDNSKey && hasNetworkPathIPv4Key && hasNetworkPathIPv6Key)
        networkPathInterfaceKinds = try values.decodeIfPresent([String].self, forKey: .networkPathInterfaceKinds) ?? []
        let hasNetworkInBytesKey = values.contains(.networkInBytesPerSecond)
        let hasNetworkOutBytesKey = values.contains(.networkOutBytesPerSecond)
        networkInBytesPerSecond = try values.decodeIfPresent(UInt64.self, forKey: .networkInBytesPerSecond) ?? 0
        networkOutBytesPerSecond = try values.decodeIfPresent(UInt64.self, forKey: .networkOutBytesPerSecond) ?? 0
        networkInterfaces = try values.decodeIfPresent([NetworkInterfaceMetric].self, forKey: .networkInterfaces) ?? []
        hasNetworkDirectionByteCounters = decodedHasNetworkDirectionByteCounters
            ?? (hasNetworkInBytesKey && hasNetworkOutBytesKey)
        hasNetworkByteCounters = decodedHasNetworkByteCounters
            ?? (networkBytesPerSecond > 0
                || hasNetworkDirectionByteCounters
                || networkInterfaces.contains { $0.hasByteCounters })
        diskFreeBytes = try values.decodeIfPresent(UInt64.self, forKey: .diskFreeBytes) ?? 0
        diskTotalBytes = try values.decodeIfPresent(UInt64.self, forKey: .diskTotalBytes) ?? 0
        storageVolumes = try values.decodeIfPresent([StorageVolumeMetric].self, forKey: .storageVolumes) ?? []
        let hasProcessCountKey = values.contains(.processCount)
        let hasActiveApplicationCountKey = values.contains(.activeApplicationCount)
        let hasHiddenApplicationCountKey = values.contains(.hiddenApplicationCount)
        processCount = try values.decodeIfPresent(Int.self, forKey: .processCount) ?? 0
        activeApplicationCount = try values.decodeIfPresent(Int.self, forKey: .activeApplicationCount) ?? 0
        hiddenApplicationCount = try values.decodeIfPresent(Int.self, forKey: .hiddenApplicationCount) ?? 0
        hasRunningAppCountReport = try values.decodeIfPresent(Bool.self, forKey: .hasRunningAppCountReport)
            ?? (hasProcessCountKey && hasActiveApplicationCountKey && hasHiddenApplicationCountKey)
        runningApps = try values.decodeIfPresent([ProcessMetric].self, forKey: .runningApps) ?? []
        gpuDevices = try values.decodeIfPresent([GPUDeviceMetric].self, forKey: .gpuDevices) ?? []
        displays = try values.decodeIfPresent([DisplayMetric].self, forKey: .displays) ?? []
        uptimeSeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .uptimeSeconds) ?? 0
        hasUptimeReport = try values.decodeIfPresent(Bool.self, forKey: .hasUptimeReport) ?? (uptimeSeconds > 0)
        osVersion = try values.decodeIfPresent(String.self, forKey: .osVersion) ?? Self.placeholder.osVersion
        kernelRelease = try values.decodeIfPresent(String.self, forKey: .kernelRelease) ?? ""
        timestamp = try values.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date(timeIntervalSince1970: 0)
    }
}
