import CppUtils

func benchmark(title: String, operation: () -> Void) {
  // let start = glfwGetTime()
  CppUtils.startTime()
  operation()
  let result = CppUtils.endTime()
  print("\(title): \(String(format: "%.3f", result)) us")
  // let end = glfwGetTime()
  // let seconds = end - start
  // let microSeconds = seconds * 1_000_000
  // let elapsedTime = microSeconds

  // print("\(title): \(String(format: "%.3f", elapsedTime)) us")
}
