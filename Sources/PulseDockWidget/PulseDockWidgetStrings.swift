import Foundation

enum PulseDockWidgetStrings {
    static var widgetDisplayName: String {
        localized("widget.display_name", defaultValue: "Pulse Dock")
    }

    static var widgetDescription: String {
        localized("widget.description", defaultValue: "Show Mac CPU, memory, disk, connection, power, load, thermal, uptime, system, and kernel status on your desktop.")
    }

    static var miniThermal: String {
        localized("widget.mini.thermal", defaultValue: "Thermal")
    }

    static var miniNetwork: String {
        localized("widget.mini.network", defaultValue: "Net")
    }

    static var miniPower: String {
        localized("widget.mini.power", defaultValue: "Pwr")
    }

    static var metricMemory: String {
        localized("widget.metric.memory", defaultValue: "Memory")
    }

    static var metricCPU: String {
        localized("widget.metric.cpu", defaultValue: "CPU")
    }

    static var metricMemoryCompact: String {
        localized("widget.metric.memory_compact", defaultValue: "MEM")
    }

    static var metricConnection: String {
        localized("widget.metric.connection", defaultValue: "Connection")
    }

    static var metricDisk: String {
        localized("widget.metric.disk", defaultValue: "Disk")
    }

    static var metricLoad: String {
        localized("widget.metric.load", defaultValue: "Load")
    }

    static var metricThermalState: String {
        localized("widget.metric.thermal_state", defaultValue: "Thermal")
    }

    static var metricPath: String {
        localized("widget.metric.path", defaultValue: "Path")
    }

    static var metricInterface: String {
        localized("widget.metric.interface", defaultValue: "Interface")
    }

    static var metricUptime: String {
        localized("widget.metric.uptime", defaultValue: "Uptime")
    }

    static var metricSystem: String {
        localized("widget.metric.system", defaultValue: "System")
    }

    static var metricKernel: String {
        localized("widget.metric.kernel", defaultValue: "Kernel")
    }

    static var headerSystemStatus: String {
        localized("widget.header.system_status", defaultValue: "System Status")
    }

    static var waitingSystemData: String {
        localized("widget.placeholder.accessibility.waiting_system_data", defaultValue: "Waiting for system monitor data")
    }

    static var waitingData: String {
        localized("widget.placeholder.waiting_data", defaultValue: "Waiting for data")
    }

    static var notReported: String {
        localized("widget.not_reported", defaultValue: "Not reported")
    }

    static var compactPowerCharging: String {
        localized("widget.power.compact.charging", defaultValue: "Charging")
    }

    static var compactPowerAdapter: String {
        localized("widget.power.compact.adapter", defaultValue: "Power")
    }

    static var compactPowerBattery: String {
        localized("widget.power.compact.battery", defaultValue: "Battery")
    }

    static var compactPowerExternal: String {
        localized("widget.power.compact.external", defaultValue: "External Power")
    }

    static var powerUPS: String {
        localized("widget.power.ups", defaultValue: "UPS")
    }

    static var staleData: String {
        localized("widget.status.stale_data", defaultValue: "Stale data")
    }

    static func localized(
        _ key: String,
        defaultValue: String,
        bundle: Bundle = .pulseDockWidgetLocalization
    ) -> String {
        bundle.localizedString(forKey: key, value: defaultValue, table: "PulseDockWidget")
    }
}

private extension Bundle {
    static var pulseDockWidgetLocalization: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
}
