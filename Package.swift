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
    .target(name: "CppUtils"),
    .executableTarget(
      name: "SwiftUI",
      dependencies: [
        "CGLFW3",
        "SwiftGLM",
        "CVulkan",
        "CppUtils"
      ],
      resources: [.copy("Resources")],
      cSettings: [
        .unsafeFlags(["-I", "C:\\VulkanSDK\\1.3.275.0\\Include"], .when(platforms: [.windows])),
        .define("GLFW_INCLUDE_VULKAN"),
      ],
      linkerSettings: [
        .unsafeFlags(
          ["-Xlinker", "-rpath", "-Xlinker", "/usr/local/lib", "-lvulkan"],
          .when(platforms: [.macOS])),
        .unsafeFlags(
          ["-L", "C:\\VulkanSDK\\1.3.275.0\\Lib", "-lvulkan-1"], .when(platforms: [.windows])),
      ]
    )
  ]
)
