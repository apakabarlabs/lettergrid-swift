public struct LabelScale: Equatable, Sendable {
  public let longest: Int

  public init(longest: Int) {
    self.longest = longest
  }

  public var fontToCell: Double { 0.5 * min(1, 2 / Double(max(longest, 1))) }
}
