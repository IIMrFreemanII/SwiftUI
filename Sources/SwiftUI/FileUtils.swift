import Foundation
private let relativePath = "Sources/SwiftUI/Resources"
enum FileUtils {
  @discardableResult
  static func loadFile(_ path: String) -> Data? {
    let filePath = URL(fileURLWithPath: "\(relativePath)/\(path)")

    do {
      return try Data(contentsOf: filePath)
    } catch {
      print("Failed to read file: \(filePath)")
      print(error)
    }

    return nil
  }
}
