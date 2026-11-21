// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "IlhaDinamica",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "IlhaDinamica", targets: ["IlhaDinamica"])
    ],
    targets: [
        .executableTarget(
            name: "IlhaDinamica",
            path: "Sources/IlhaDinamica",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ImageIO"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("EventKit")
            ]
        )
    ]
)
