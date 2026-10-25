public struct PathReveal: Equatable, Sendable {
  public static let frameSeconds = 0.12
  public let cells: [Cell]

  public init(cells: [Cell], elapsed: Double, duration: Double, reduceMotion: Bool = false) {
    precondition(
      elapsed.isFinite && duration.isFinite && duration >= 0,
      "Path reveal timing must be finite and its duration nonnegative")
    let fraction = duration > 0 ? max(0, min(1, elapsed / (duration * 0.7))) : 1
    let shown =
      reduceMotion ? cells.count : min(cells.count, Int(fraction * Double(cells.count)) + 1)
    self.cells = Array(cells.prefix(shown))
  }
}
