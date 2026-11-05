import Foundation

public struct BoardGenerator: Equatable, Sendable {
  public enum Failure: LocalizedError, Equatable {
    case noRoom(words: [String], columns: Int, rows: Int)
    case unsettled(words: [String], columns: Int, rows: Int)
    case invalidConfiguration

    public var errorDescription: String? {
      switch self {
      case .noRoom(let words, let columns, let rows):
        "Could not prepare a checked grid \(columns) wide with minimum height \(rows) for "
          + words.joined(separator: ", ")
      case .unsettled(let words, let columns, let rows):
        "No grid \(columns) wide and up to \(rows) high was settled for "
          + words.joined(separator: ", ")
          + ": the search ran out, or every layout found leaves three equal letters in a line."
      case .invalidConfiguration:
        "Grid dimensions must be positive, rules nonempty and valid, and the vertical "
          + "minimum nonnegative. A maximum height must be at least the minimum. "
          + "A per-direction word limit must be positive. Leading rules must be enabled."
      }
    }
  }

  public let size: BoardSize
  public let rules: [WordRule]
  public let filler: Filler
  public let limits: PlacementLimits
  var weights: LetterWeights
  var requiresRunFreeTargets = false

  var columns: Int { size.columns }
  var rows: Int { size.rows }
  var maxRows: Int? { size.maxRows }
  var directions: [Direction] { rules.startDirections }
  var conditionalCharacters: Set<Character> { filler.conditionalCharacters }
  var downWords: ClosedRange<Int> { limits.downWords }
  var maxWordsPerDirection: Int? { limits.maxWordsPerDirection }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.size == rhs.size && lhs.rules == rhs.rules && lhs.filler == rhs.filler
      && lhs.limits == rhs.limits && lhs.weights == rhs.weights
      && lhs.requiresRunFreeTargets == rhs.requiresRunFreeTargets
  }

  public init(
    size: BoardSize, rules: [WordRule], filler: Filler, limits: PlacementLimits = PlacementLimits()
  ) {
    self.size = size
    self.rules = rules
    self.filler = filler
    self.limits = limits
    self.weights = filler.weights
  }

  public func request(for words: [String], firstRule: WordRule? = nil) throws -> BoardRequest {
    try finishPreparation(placementRequest(for: words, firstRule: firstRule))
  }

  public func checkPlacement(for words: [String], firstRule: WordRule? = nil) throws {
    _ = try placementRequest(for: words, firstRule: firstRule)
  }

  public func checkPlacement(for words: [String], leadingRules: [WordRule]) throws {
    _ = try placementRequest(for: words, leadingRules: leadingRules)
  }

  public func request(for words: [String], leadingRules: [WordRule]) throws -> BoardRequest {
    try finishPreparation(placementRequest(for: words, leadingRules: leadingRules))
  }

  func enables(_ rule: WordRule) -> Bool {
    rule.isValid
      && rules.contains {
        $0.turns == rule.turns && Set(rule.startDirections).isSubset(of: $0.startDirections)
      }
  }

  var hasValidDirectionLimit: Bool { maxWordsPerDirection.map { $0 > 0 } ?? true }
}

extension BoardGenerator {
  public func board(
    for words: [String], seed: UInt64, firstRule: WordRule? = nil
  ) throws -> Board {
    try request(for: words, firstRule: firstRule).board(seed: seed)
  }
}
