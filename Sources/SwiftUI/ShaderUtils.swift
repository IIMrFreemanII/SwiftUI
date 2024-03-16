import ShellOut
import Foundation

enum ShaderUtils {
  // path is relative to Sources/SwiftUI/Resources/Shaders path
  static func compile(_ path: String) {
    print("currentDirectoryPath: \(FileManager.default.currentDirectoryPath)")
    do {
      let output = try shellOut(to: "glslc", arguments: ["shader.vert -o vert.spv"], at: "Sources/SwiftUI/Resources/Shaders")
      print("output: \(output)")

    } catch {
      let error = error as! ShellOutError
      print(error.message)  // Prints STDERR
      print(error.output)  // Prints STDOUT
    }
  }
}
