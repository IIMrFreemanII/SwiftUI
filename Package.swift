// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUI",
    products: [
        .executable(name: "SwiftUI", targets: ["SwiftUI"])
    ],
    dependencies: [
      .package(url: "https://github.com/IIMrFreemanII/CVulkan", branch: "main"),
      .package(url: "https://github.com/IIMrFreemanII/CGLFW3", branch: "main"),
      .package(url: "https://github.com/IIMrFreemanII/SwiftGLM", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SwiftUI",
            dependencies: [
                "CGLFW3", 
                "SwiftGLM",
                "CVulkan"
            ] 
        ),
    ]
)
