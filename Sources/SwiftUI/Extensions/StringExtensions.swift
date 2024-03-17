extension String {
  var cString: UnsafePointer<CChar> {
    self.withCString { $0 }
  }
}

extension UnsafePointer<CChar> {
  var string: String {
    String(cString: self)
  }
}

extension ContiguousArray<CChar> {
  var cString: UnsafePointer<CChar> {
    self.withUnsafeBufferPointer { $0.baseAddress! }
  }
}