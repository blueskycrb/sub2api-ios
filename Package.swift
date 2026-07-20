// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sub2API",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "Sub2APICore", targets: ["Sub2APICore"])
    ],
    targets: [
        .target(
            name: "Sub2APICore",
            path: "Sub2API",
            exclude: [
                "Sub2APIApp.swift",
                "Info.plist",
                "Resources"
            ]
        )
    ]
)
