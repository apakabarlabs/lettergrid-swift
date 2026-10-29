public struct SeededRandom: RandomNumberGenerator, Sendable {
  private var state: UInt64

  public init(seed: UInt64) {
    state = seed
  }

  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }

  public mutating func nextInt(below bound: Int) -> Int {
    precondition(bound > 0, "A bound must be positive")
    let upper = UInt64(bound)
    var product = next().multipliedFullWidth(by: upper)
    if product.low < upper {
      let threshold = (0 &- upper) % upper
      while product.low < threshold {
        product = next().multipliedFullWidth(by: upper)
      }
    }
    return Int(product.high)
  }

  public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
    range.lowerBound + nextInt(below: range.count)
  }

  public mutating func nextDouble(below upper: Double) -> Double {
    precondition(upper > 0 && upper.isFinite, "An upper bound must be positive and finite")
    while true {
      let unit = Double(next() & (1 << 53 - 1)) * (Double.ulpOfOne / 2)
      let value = upper * unit
      if value != upper { return value }
    }
  }

  public mutating func shuffled<Element>(_ elements: [Element]) -> [Element] {
    var result = elements
    var remaining = result.count
    var index = 0
    while remaining > 1 {
      let offset = nextInt(below: remaining)
      remaining -= 1
      result.swapAt(index, index + offset)
      index += 1
    }
    return result
  }

  public mutating func pick<Element>(_ elements: [Element]) -> Element? {
    elements.isEmpty ? nil : elements[nextInt(below: elements.count)]
  }
}
