import Foundation

func benchmark(title: String, operation: () -> Void) {
  var timebaseInfo = mach_timebase_info_data_t()
  mach_timebase_info(&timebaseInfo)

  let startTime = mach_absolute_time()
  operation()
  let timeElapsed = mach_absolute_time()

  let elapsedNanoseconds =
    (timeElapsed - startTime) * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
  let macro_seconds = Double(elapsedNanoseconds) / 1_000.0  // Convert to macro seconds
  print("\(title): \(String(format: "%.3f", macro_seconds)) us")
}
