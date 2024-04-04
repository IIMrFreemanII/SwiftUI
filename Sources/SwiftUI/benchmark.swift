import CppUtils

func benchmark(title: String, operation: () -> Void) {
  CppUtils.startTime()
  operation()
  let result = CppUtils.endTime()
  print("\(title): \(String(format: "%.3f", result)) us")
}
