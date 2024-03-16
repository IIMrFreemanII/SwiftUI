import Foundation

struct ShellError: Error {
    /// The error message as a UTF8 string, as returned through `STDERR`
    var message: String
    /// The output of the command as a UTF8 string, as returned through `STDOUT`
    var output: String
    /// The termination status of the command that was run
    var terminationStatus: Int32
}

extension ShellError: CustomStringConvertible {
  var description: String {
    return """
    Shell encountered an error:
      Status code: \(terminationStatus)
      Message: \(message)
      Output: \(output)
    """
  }
}

@discardableResult
func shell(to command: String, arguments: [String] = [], at path: String = ".") throws -> String {
  let command = "cd \(path) && \(command) \(arguments.joined(separator: " "))"
  let process = Process()

  #if os(Windows)
  process.executableURL = URL(fileURLWithPath: "C:\\Program Files\\Git\\bin\\bash.exe")
  #else
  process.executableURL = URL(fileURLWithPath: "/bin/bash")
  #endif

  process.arguments = ["-c", command]

  var outputData = Data()
  var outputError = Data()

  let outputPipe = Pipe()
  process.standardOutput = outputPipe
  outputPipe.fileHandleForReading.readabilityHandler = { handler in
    outputData.append(handler.availableData)
  }

  let errorPipe = Pipe()
  process.standardError = errorPipe
  errorPipe.fileHandleForReading.readabilityHandler = { handler in
    outputError.append(handler.availableData)
  }

  try process.run()
  process.waitUntilExit()

  let output = String(data: outputData, encoding: .utf8)!

  let error = String(data: outputError, encoding: .utf8)!

  if !error.isEmpty {
    throw ShellError(message: error, output: output, terminationStatus: process.terminationStatus)
  }

  return output
}