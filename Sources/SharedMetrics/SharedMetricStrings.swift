import Foundation

enum SharedMetricStrings {
    static var notReported: String {
        localized("shared_metrics.not_reported", defaultValue: "Not reported")
    }

    static var other: String {
        localized("shared_metrics.other", defaultValue: "Other")
    }

    static var networkInterface: String {
        localized("shared_metrics.network_interface", defaultValue: "Network Interface")
    }

    static var networkInterfaceStateLoopback: String {
        localized("shared_metrics.network.interface.state.loopback", defaultValue: "Loopback")
    }

    static var networkInterfaceStateOnline: String {
        localized("shared_metrics.network.interface.state.online", defaultValue: "Online")
    }

    static var networkInterfaceStateOffline: String {
        localized("shared_metrics.network.interface.state.offline", defaultValue: "Offline")
    }

    static var networkPathStatusOnline: String {
        localized("shared_metrics.network.path.status.online", defaultValue: "Online")
    }

    static var networkPathStatusOffline: String {
        localized("shared_metrics.network.path.status.offline", defaultValue: "Offline")
    }

    static var networkPathStatusRequiresConnection: String {
        localized("shared_metrics.network.path.status.requires_connection", defaultValue: "Requires Connection")
    }

    static var networkPathLocalNetwork: String {
        localized("shared_metrics.network.path.local_network", defaultValue: "Local Network")
    }

    static var networkPathNoConnection: String {
        localized("shared_metrics.network.path.no_connection", defaultValue: "No Connection")
    }

    static var networkPathLowDataMode: String {
        localized("shared_metrics.network.path.low_data_mode", defaultValue: "Low Data Mode")
    }

    static var networkPathMeteredNetwork: String {
        localized("shared_metrics.network.path.metered_network", defaultValue: "Metered Network")
    }

    static var networkPathUnavailable: String {
        localized("shared_metrics.network.path.unavailable", defaultValue: "Unavailable")
    }

    static var networkPathSupported: String {
        localized("shared_metrics.network.path.supported", defaultValue: "Supported")
    }

    static var networkPathUnsupported: String {
        localized("shared_metrics.network.path.unsupported", defaultValue: "Unsupported")
    }

    static var networkPathEnabled: String {
        localized("shared_metrics.network.path.enabled", defaultValue: "On")
    }

    static var networkPathDisabled: String {
        localized("shared_metrics.network.path.disabled", defaultValue: "Off")
    }

    static var networkRuleNormal: String {
        localized("shared_metrics.network.rule.normal", defaultValue: "Normal")
    }

    static var networkRuleAttention: String {
        localized("shared_metrics.network.rule.attention", defaultValue: "Attention")
    }

    static var systemDidNotReport: String {
        localized("shared_metrics.system.did_not_report", defaultValue: "System did not report")
    }

    static var processStateForeground: String {
        localized("shared_metrics.process.state.foreground", defaultValue: "Foreground")
    }

    static var processStateHidden: String {
        localized("shared_metrics.process.state.hidden", defaultValue: "Hidden")
    }

    static var processStateRunning: String {
        localized("shared_metrics.process.state.running", defaultValue: "Running")
    }

    static var gpuKindExternal: String {
        localized("shared_metrics.gpu.kind.external", defaultValue: "External")
    }

    static var gpuKindLowPower: String {
        localized("shared_metrics.gpu.kind.low_power", defaultValue: "Low Power")
    }

    static var gpuKindHighPerformance: String {
        localized("shared_metrics.gpu.kind.high_performance", defaultValue: "High Performance")
    }

    static var booleanYes: String {
        localized("shared_metrics.boolean.yes", defaultValue: "Yes")
    }

    static var booleanNo: String {
        localized("shared_metrics.boolean.no", defaultValue: "No")
    }

    static var gpuRoleCompute: String {
        localized("shared_metrics.gpu.role.compute", defaultValue: "Compute")
    }

    static var gpuRoleDisplay: String {
        localized("shared_metrics.gpu.role.display", defaultValue: "Display")
    }

    static var builtInDisplay: String {
        localized("shared_metrics.display.built_in", defaultValue: "Built-in Display")
    }

    static var mainDisplay: String {
        localized("shared_metrics.display.main", defaultValue: "Main Display")
    }

    static var displayTopologyMain: String {
        localized("shared_metrics.display.topology.main", defaultValue: "Main Display")
    }

    static var displayTopologyBuiltIn: String {
        localized("shared_metrics.display.topology.built_in", defaultValue: "Built-in")
    }

    static var displayTopologyExternal: String {
        localized("shared_metrics.display.topology.external", defaultValue: "External")
    }

    static var displayTopologyMirrored: String {
        localized("shared_metrics.display.topology.mirrored", defaultValue: "Mirrored")
    }

    static var displayTopologyExtended: String {
        localized("shared_metrics.display.topology.extended", defaultValue: "Extended")
    }

    static func display(number: Int) -> String {
        localizedFormat("shared_metrics.display.generic_format", defaultValue: "Display %d", number)
    }

    static func externalDisplay(number: Int) -> String {
        localizedFormat("shared_metrics.display.external_format", defaultValue: "External Display %d", number)
    }

    static func activeNetworkInterfaceSummary(activeCount: Int) -> String {
        if activeCount == 1 {
            return localizedFormat(
                "shared_metrics.network.interface.active_singular_format",
                defaultValue: "%d active interface",
                activeCount
            )
        }
        return localizedFormat(
            "shared_metrics.network.interface.active_plural_format",
            defaultValue: "%d active interfaces",
            activeCount
        )
    }

    static var storageKindRemovable: String {
        localized("shared_metrics.storage.kind.removable", defaultValue: "Removable")
    }

    static var storageKindEjectable: String {
        localized("shared_metrics.storage.kind.ejectable", defaultValue: "Ejectable")
    }

    static var storageKindInternal: String {
        localized("shared_metrics.storage.kind.internal", defaultValue: "Internal")
    }

    static var storageKindExternal: String {
        localized("shared_metrics.storage.kind.external", defaultValue: "External")
    }

    static var storageAccessReadOnly: String {
        localized("shared_metrics.storage.access.read_only", defaultValue: "Read-only")
    }

    static var storageAccessWritable: String {
        localized("shared_metrics.storage.access.writable", defaultValue: "Writable")
    }

    static func runningAppListOnly(reportedListCount: Int) -> String {
        localizedFormat(
            "shared_metrics.running_apps.list_only_format",
            defaultValue: "List %d · total not reported",
            reportedListCount
        )
    }

    static func runningAppSummary(processCount: Int, activeApplicationCount: Int, hiddenApplicationCount: Int) -> String {
        localizedFormat(
            "shared_metrics.running_apps.summary_format",
            defaultValue: "%d apps · foreground %d · hidden %d",
            processCount,
            activeApplicationCount,
            hiddenApplicationCount
        )
    }

    static var sourceStatusReported: String {
        localized("shared_metrics.source.status.reported", defaultValue: "Reported")
    }

    static var sourceStatusPartial: String {
        localized("shared_metrics.source.status.partial", defaultValue: "Partial report")
    }

    static var thermalStateNominal: String {
        localized("shared_metrics.thermal.state.nominal", defaultValue: "Nominal")
    }

    static var thermalStateWarm: String {
        localized("shared_metrics.thermal.state.warm", defaultValue: "Warm")
    }

    static var thermalStateHot: String {
        localized("shared_metrics.thermal.state.hot", defaultValue: "Hot")
    }

    static var thermalStateCritical: String {
        localized("shared_metrics.thermal.state.critical", defaultValue: "Critical")
    }

    static var thermalLimitCritical: String {
        localized("shared_metrics.thermal.limit.critical", defaultValue: "Likely heavy throttling")
    }

    static var thermalLimitHot: String {
        localized("shared_metrics.thermal.limit.hot", defaultValue: "Likely throttling")
    }

    static var thermalLimitWarm: String {
        localized("shared_metrics.thermal.limit.warm", defaultValue: "Light pressure")
    }

    static var thermalLimitNominal: String {
        localized("shared_metrics.thermal.limit.nominal", defaultValue: "No obvious limits")
    }

    static var powerSourceAdapter: String {
        localized("shared_metrics.power.source.adapter", defaultValue: "Power Adapter")
    }

    static var powerSourceAdapterCharging: String {
        localized("shared_metrics.power.source.adapter_charging", defaultValue: "Power Adapter · Charging")
    }

    static var powerSourceBattery: String {
        localized("shared_metrics.power.source.battery", defaultValue: "Battery Power")
    }

    static var powerSourceUPS: String {
        localized("shared_metrics.power.source.ups", defaultValue: "UPS Power")
    }

    static var powerSourceExternal: String {
        localized("shared_metrics.power.source.external", defaultValue: "External Power")
    }

    static var powerSourceStateNotReported: String {
        localized("shared_metrics.power.source.state_not_reported", defaultValue: "Power state not reported")
    }

    static var powerStatusTitlePower: String {
        localized("shared_metrics.power.status.title.power", defaultValue: "Power")
    }

    static var powerStatusTitleBattery: String {
        localized("shared_metrics.power.status.title.battery", defaultValue: "Battery")
    }

    static var batteryHealthGood: String {
        localized("shared_metrics.battery.health.good", defaultValue: "Good")
    }

    static var batteryHealthFair: String {
        localized("shared_metrics.battery.health.fair", defaultValue: "Fair")
    }

    static var batteryHealthPoor: String {
        localized("shared_metrics.battery.health.poor", defaultValue: "Poor")
    }

    static var batteryHealthCheck: String {
        localized("shared_metrics.battery.health.check", defaultValue: "Check Battery")
    }

    static var batteryHealthService: String {
        localized("shared_metrics.battery.health.service", defaultValue: "Service Battery")
    }

    static var gpuNotReportedSummary: String {
        localized("shared_metrics.gpu.summary.not_reported", defaultValue: "GPU not reported")
    }

    static var displayNotReportedSummary: String {
        localized("shared_metrics.display.summary.not_reported", defaultValue: "Display not reported")
    }

    static func logicalCoreSummary(count: Int) -> String {
        if count == 1 {
            return localizedFormat("shared_metrics.cpu.logical_core_summary_singular_format", defaultValue: "%d logical core", count)
        }
        return localizedFormat("shared_metrics.cpu.logical_core_summary_plural_format", defaultValue: "%d logical cores", count)
    }

    static func diskAvailableSummary(availableText: String) -> String {
        localizedFormat("shared_metrics.disk.available_summary_format", defaultValue: "%@ available", availableText)
    }

    static func storageVolumeSummary(count: Int) -> String {
        if count == 1 {
            return localizedFormat("shared_metrics.storage.volume.summary_singular_format", defaultValue: "%d volume", count)
        }
        return localizedFormat("shared_metrics.storage.volume.summary_plural_format", defaultValue: "%d volumes", count)
    }

    static func externalStorageVolumeSummary(count: Int) -> String {
        localizedFormat("shared_metrics.storage.volume.external_summary_format", defaultValue: "%d external", count)
    }

    static func gpuSummary(count: Int) -> String {
        if count == 1 {
            return localizedFormat("shared_metrics.gpu.summary_singular_format", defaultValue: "%d GPU", count)
        }
        return localizedFormat("shared_metrics.gpu.summary_plural_format", defaultValue: "%d GPUs", count)
    }

    static func displaySummary(count: Int) -> String {
        if count == 1 {
            return localizedFormat("shared_metrics.display.summary_singular_format", defaultValue: "%d display", count)
        }
        return localizedFormat("shared_metrics.display.summary_plural_format", defaultValue: "%d displays", count)
    }

    static func gpuDisplaySummary(gpuText: String, displayText: String) -> String {
        localizedFormat("shared_metrics.gpu_display.summary_format", defaultValue: "%@ / %@", gpuText, displayText)
    }

    static func reportedGPUName(_ text: String?) -> String {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return isNotReportedText(trimmed) || trimmed == genericGPUName ? notReported : trimmed
    }

    static func reportedDisplayName(_ text: String?) -> String {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return isNotReportedText(trimmed) || trimmed == legacyChineseGenericDisplayName ? notReported : trimmed
    }

    static func reportedTextOrNotReported(_ text: String?) -> String {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return isNotReportedText(trimmed) ? notReported : trimmed
    }

    static func isNotReportedText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            || trimmed == notReported
            || trimmed == legacyEnglishNotReported
            || trimmed == legacyChineseNotReported
    }

    static func isOtherText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == other
            || trimmed == legacyEnglishOther
            || trimmed == legacyChineseOther
    }

    static func localized(
        _ key: String,
        defaultValue: String,
        bundle: Bundle = .sharedMetricsLocalization
    ) -> String {
        bundle.localizedString(forKey: key, value: defaultValue, table: "SharedMetrics")
    }

    private static func localizedFormat(
        _ key: String,
        defaultValue: String,
        _ arguments: CVarArg...
    ) -> String {
        String(format: localized(key, defaultValue: defaultValue), locale: Locale.current, arguments: arguments)
    }

    private static let legacyEnglishNotReported = "Not reported"
    private static let legacyChineseNotReported = "\u{672A}\u{62A5}\u{544A}"
    private static let legacyEnglishOther = "Other"
    private static let legacyChineseOther = "\u{5176}\u{4ED6}"
    private static let genericGPUName = "GPU"
    private static let legacyChineseGenericDisplayName = "\u{663E}\u{793A}\u{5668}"
}

private extension Bundle {
    static var sharedMetricsLocalization: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
}
