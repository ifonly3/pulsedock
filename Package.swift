// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SystemDashboard",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SharedMetrics", targets: ["SharedMetrics"]),
        .executable(name: "SystemDashboardApp", targets: ["SystemDashboardApp"])
    ],
    targets: [
        .target(
            name: "SharedMetrics",
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("Metal"),
                .linkedFramework("Network"),
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .executableTarget(
            name: "SystemDashboardApp",
            dependencies: ["SharedMetrics"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("WidgetKit")
            ]
        ),
        .testTarget(
            name: "SharedMetricsTests",
            dependencies: ["SharedMetrics"]
        )
    ]
)
