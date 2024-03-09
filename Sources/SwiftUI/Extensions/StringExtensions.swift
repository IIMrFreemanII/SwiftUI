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
