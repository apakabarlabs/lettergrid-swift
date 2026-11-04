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
  private(set) var weights: LetterWeights
  private(set) var requiresRunFreeTargets = false

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

  private func placementRequest(for words: [String], firstRule: WordRule?) throws -> BoardRequest {
    try validateConfiguration()
    guard firstRule.map(enables) ?? true else { throw Failure.invalidConfiguration }
    return try checkedTargets(for: words, leadingRules: firstRule.map { [$0] } ?? [])
  }

  public func request(for words: [String], leadingRules: [WordRule]) throws -> BoardRequest {
    try finishPreparation(placementRequest(for: words, leadingRules: leadingRules))
  }

  package func placementRequest(
    for words: [String], leadingRules: [WordRule]
  ) throws -> BoardRequest {
    try validateConfiguration()
    guard leadingRules.allSatisfy(enables) else { throw Failure.invalidConfiguration }
    return try checkedTargets(for: words, leadingRules: leadingRules)
  }

  func enables(_ rule: WordRule) -> Bool {
    rule.isValid
      && rules.contains {
        $0.turns == rule.turns && Set(rule.startDirections).isSubset(of: $0.startDirections)
      }
  }

  private func checkedTargets(
    for words: [String], leadingRules: [WordRule]
  ) throws -> BoardRequest {
    let words = words.map(\.cellUppercased)
    var targets = self
    targets.requiresRunFreeTargets = true
    let request: BoardRequest
    do {
      request = try targets.targetRequest(for: words, leadingRules: leadingRules)
    } catch Failure.noRoom {
      targets.requiresRunFreeTargets = false
      _ = try targets.targetRequest(for: words, leadingRules: leadingRules)
      throw Failure.unsettled(words: words, columns: columns, rows: maxRows ?? rows)
    }
    return request
  }

  package func finishPreparation(
    _ request: BoardRequest, observing: ((Duration, Duration) -> Void)? = nil
  ) throws -> BoardRequest {
    for seed in UInt64(0)..<UInt64(Generation.settings.fill.seeds) {
      let start = observing.map { _ in ContinuousClock.now }
      let targets = request.targets(seed: seed)
      let repacking = start?.duration(to: .now)
      let fillStart = observing.map { _ in ContinuousClock.now }
      let fallback = RunFreeFill(
        board: targets, weights: weights, rules: rules,
        conditionalCharacters: conditionalCharacters
      ).filled(seed: seed)
      if let repacking, let fillStart {
        observing?(repacking, fillStart.duration(to: .now))
      }
      if let fallback {
        return request.avoidingRuns(
          fallback: fallback, weights: weights, symbols: conditionalCharacters)
      }
    }
    throw Failure.unsettled(words: request.words, columns: columns, rows: maxRows ?? rows)
  }

  private func targetRequest(
    for words: [String], leadingRules: [WordRule]
  ) throws -> BoardRequest {
    let symbols = conditionalCharacters.union(words.joined().filter { !$0.isLetter })
    var generator = self
    if !symbols.isEmpty {
      guard let ordinary = weights.letters(excluding: symbols) else {
        throw Failure.noRoom(words: words, columns: columns, rows: rows)
      }
      generator.weights = ordinary
    }
    return try generator.packedRequest(
      for: words, leadingRules: leadingRules,
      maxRows: maxRows ?? rows + words.map(\.count).reduce(0, +))
  }

  private func validateConfiguration() throws {
    guard columns > 0, rows > 0, !directions.isEmpty, downWords.lowerBound >= 0,
      rules.allSatisfy(\.isValid), maxRows.map({ $0 >= rows }) ?? true, hasValidDirectionLimit
    else { throw Failure.invalidConfiguration }
  }

  var hasValidDirectionLimit: Bool { maxWordsPerDirection.map { $0 > 0 } ?? true }
}

extension BoardGenerator {
  func targets(for request: BoardRequest, seed: UInt64) -> Board {
    Board(targets: packedLayout(for: request, seed: seed), columns: columns)
  }

  public func board(
    for words: [String], seed: UInt64, firstRule: WordRule? = nil
  ) throws -> Board {
    try request(for: words, firstRule: firstRule).board(seed: seed)
  }
}
