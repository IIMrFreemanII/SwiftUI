extension Sendable {  // Apply to any type conforming to Sendable
    func unsafePointer() -> UnsafePointer<Self> {
        return withUnsafePointer(to: self) {
            return $0
        }
    }
}
