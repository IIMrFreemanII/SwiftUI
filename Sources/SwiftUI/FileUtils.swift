import Foundation

enum FileUtils {
  @discardableResult
  static func loadFile(_ path: String) -> Data? {
    var temp = path.split(separator: ".")
    let extensionName = String(temp.removeLast())
    let resource = temp.joined(separator: ".")
    print("resource: \(resource)")
    print("extensionName: \(extensionName)")

    let resourceURL = Bundle.module.url(forResource: resource, withExtension: extensionName)
    guard let resourceURL = resourceURL else {
      print("File not found: \(path)")
      return nil
    }

    print("resourceURL: \(resourceURL)")

    do {
      return try Data(contentsOf: resourceURL)
    } catch {
      print("Error reading file: \(error)")
    }

    return nil
  }
}
