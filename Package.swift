// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PulseDock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SharedMetrics", targets: ["SharedMetrics"]),
        .executable(name: "PulseDockApp", targets: ["PulseDockApp"])
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
            name: "PulseDockApp",
            dependencies: ["SharedMetrics"],
            path: "Sources/PulseDockApp",
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
