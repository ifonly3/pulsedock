// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PulseDock",
    defaultLocalization: "en",
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
            resources: [
                .process("Resources")
            ],
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
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("WidgetKit")
            ]
        ),
        .target(
            name: "PulseDockWidget",
            dependencies: ["SharedMetrics"],
            path: "Sources/PulseDockWidget",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("WidgetKit")
            ]
        ),
        .testTarget(
            name: "SharedMetricsTests",
            dependencies: ["SharedMetrics", "PulseDockWidget"]
        )
    ]
)
