// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GlassOS",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GlassOS",
            path: "Sources/GlassOS",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Carbon"),
                .linkedFramework("QuartzCore"),
            ]
        )
    ]
)
