import Foundation

private let shadersPath = "Sources/SwiftUI/Resources/Shaders"

enum ShaderUtils {
  // path is relative to Sources/SwiftUI/Resources/Shaders path
  @discardableResult
  static func compile(_ path: String) -> Data? {
    do {
      let output = try shell(to: "glslc", arguments: ["\(path) -o \(path).spv"], at: shadersPath)
      print("Compiled \(path), output: \"\(output)\"")
    } catch {
      print("Failed to compile: \(path)")
      print(error)
    }

    let compiledShaderPath = URL(fileURLWithPath: "\(shadersPath)/\(path).spv")
    return try? Data(contentsOf: compiledShaderPath)
  }
}
