extension Comparable {
  func clamp(_ lowerBound: Self, _ upperBound: Self) -> Self {
    return max(lowerBound, min(upperBound, self))
  }

  func clamped(to range: ClosedRange<Self>) -> Self {
    return max(range.lowerBound, min(range.upperBound, self))
  }
}
