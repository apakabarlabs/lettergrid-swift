public struct Ramp: Decodable, Equatable, Sendable {
  public let first: Int
  public let step: Int
  public let every: Int
  public let last: Int

  public init(first: Int, step: Int = 0, every: Int = 1, last: Int? = nil) {
    self.first = first
    self.step = step
    self.every = every
    self.last = last ?? first
  }

  public func value(at level: Int) -> Int {
    let grown = first + (level - 1) / every * step
    return step >= 0 ? min(grown, last) : max(grown, last)
  }

  var isValid: Bool {
    every > 0 && (step >= 0 ? last >= first : last <= first)
  }
}
