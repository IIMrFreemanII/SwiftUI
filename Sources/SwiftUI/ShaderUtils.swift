import Foundation

enum ShaderUtils {
  // path is relative to Sources/SwiftUI/Resources/Shaders path
  static func compile(_ path: String) {
    do {
      let output = try shell(to: "glslc", arguments: ["shader.vert -o vert.spv"], at: "Sources/SwiftUI/Resources/Shaders")
      print("output: \(output)")
    } catch {
      print(error)
    }
  }
}
