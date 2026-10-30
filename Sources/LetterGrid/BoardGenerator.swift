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
        "Grid dimensions must be positive, directions nonempty, rules valid and the vertical "
          + "minimum nonnegative. A maximum height must be at least the minimum."
      }
    }
  }

  public let columns: Int
  public let rows: Int
  public let maxRows: Int?
  public let directions: [Direction]
  public private(set) var filler: LetterWeights
  public let conditionalCharacters: Set<Character>
  public let dictionary: Set<String>
  public let downWords: ClosedRange<Int>
  public private(set) var rules: [WordRule]
  private(set) var usesPathRules = false
  private(set) var requiresRunFreeTargets = false
  let preparedDictionary: BoardDictionary

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.columns == rhs.columns && lhs.rows == rhs.rows && lhs.maxRows == rhs.maxRows
      && lhs.directions == rhs.directions
      && lhs.filler == rhs.filler && lhs.dictionary == rhs.dictionary
      && lhs.downWords == rhs.downWords && lhs.rules == rhs.rules
      && lhs.usesPathRules == rhs.usesPathRules
      && lhs.conditionalCharacters == rhs.conditionalCharacters
      && lhs.requiresRunFreeTargets == rhs.requiresRunFreeTargets
  }

  public init(
    columns: Int, rows: Int, maxRows: Int? = nil, directions: [Direction], filler: LetterWeights,
    dictionary: Set<String> = [], downWords: ClosedRange<Int> = 0...Int.max,
    conditionalCharacters: Set<Character> = []
  ) {
    self.columns = columns
    self.rows = rows
    self.maxRows = maxRows
    self.directions = directions
    self.filler = filler
    self.dictionary = Set(dictionary.map(\.cellUppercased))
    self.preparedDictionary = BoardDictionary(self.dictionary)
    self.downWords = downWords
    self.rules = [WordRule(startDirections: directions)]
    self.conditionalCharacters = Set(conditionalCharacters.map(\.cellUppercased))
  }

  public init(
    columns: Int, rows: Int, maxRows: Int? = nil, rules: [WordRule], filler: LetterWeights,
    dictionary: Set<String> = [], downWords: ClosedRange<Int> = 0...Int.max,
    conditionalCharacters: Set<Character> = []
  ) {
    self.init(
      columns: columns, rows: rows, maxRows: maxRows,
      directions: Direction.allCases.filter { way in
        rules.contains { $0.startDirections.contains(way) }
      },
      filler: filler, dictionary: dictionary, downWords: downWords,
      conditionalCharacters: conditionalCharacters)
    self.rules = rules
    self.usesPathRules = true
  }

  public func request(
    for words: [String], firstDirection: Direction? = nil, firstRule: WordRule? = nil
  ) throws -> BoardRequest {
    try finishPreparation(
      placementRequest(for: words, firstDirection: firstDirection, firstRule: firstRule))
  }

  public func checkPlacement(
    for words: [String], firstDirection: Direction? = nil, firstRule: WordRule? = nil
  ) throws {
    _ = try placementRequest(for: words, firstDirection: firstDirection, firstRule: firstRule)
  }

  public func checkPlacement(for words: [String], leadingRules: [WordRule]) throws {
    _ = try placementRequest(for: words, leadingRules: leadingRules)
  }

  private func placementRequest(
    for words: [String], firstDirection: Direction?, firstRule: WordRule?
  ) throws -> BoardRequest {
    try validateConfiguration()
    let leading: [WordRule]
    if usesPathRules {
      guard firstDirection == nil, firstRule.map({ rules.contains($0) }) ?? true
      else { throw Failure.invalidConfiguration }
      leading = firstRule.map { [$0] } ?? []
    } else {
      guard firstRule == nil else { throw Failure.invalidConfiguration }
      guard firstDirection.map({ directions.contains($0) }) ?? true else {
        throw Failure.noRoom(words: words.map(\.cellUppercased), columns: columns, rows: rows)
      }
      leading = firstDirection.map { [WordRule(startDirections: [$0])] } ?? []
    }
    return try checkedTargets(for: words, firstDirection: firstDirection, leadingRules: leading)
  }

  public func request(for words: [String], leadingRules: [WordRule]) throws -> BoardRequest {
    try finishPreparation(placementRequest(for: words, leadingRules: leadingRules))
  }

  package func placementRequest(
    for words: [String], leadingRules: [WordRule]
  ) throws -> BoardRequest {
    try validateConfiguration()
    guard usesPathRules, leadingRules.allSatisfy(enables) else {
      throw Failure.invalidConfiguration
    }
    return try checkedTargets(for: words, firstDirection: nil, leadingRules: leadingRules)
  }

  func enables(_ rule: WordRule) -> Bool {
    rule.isValid
      && rules.contains {
        $0.turns == rule.turns && Set(rule.startDirections).isSubset(of: $0.startDirections)
      }
  }

  private func checkedTargets(
    for words: [String], firstDirection: Direction?, leadingRules: [WordRule]
  ) throws -> BoardRequest {
    let words = words.map(\.cellUppercased)
    var targets = self
    targets.requiresRunFreeTargets = true
    let request: BoardRequest
    do {
      request = try targets.targetRequest(
        for: words, firstDirection: firstDirection, leadingRules: leadingRules)
    } catch Failure.noRoom {
      targets.requiresRunFreeTargets = false
      _ = try targets.targetRequest(
        for: words, firstDirection: firstDirection, leadingRules: leadingRules)
      throw Failure.unsettled(words: words, columns: columns, rows: maxRows ?? rows)
    }
    return request
  }

  package func finishPreparation(
    _ request: BoardRequest, observing: ((Duration, Duration) -> Void)? = nil
  ) throws -> BoardRequest {
    let dictionary = preparedDictionary
    for seed in UInt64(0)..<UInt64(Generation.settings.fill.seeds) {
      let start = observing.map { _ in ContinuousClock.now }
      let targets = request.targets(seed: seed)
      let repacking = start?.duration(to: .now)
      let fillStart = observing.map { _ in ContinuousClock.now }
      let fallback = RunFreeFill(
        board: targets, weights: filler, rules: rules,
        conditionalCharacters: conditionalCharacters, dictionary: dictionary.index
      ).filled(seed: seed)
      if let repacking, let fillStart {
        observing?(repacking, fillStart.duration(to: .now))
      }
      if let fallback {
        return request.avoidingRuns(
          fallback: fallback, weights: filler, symbols: conditionalCharacters)
      }
    }
    throw Failure.unsettled(words: request.words, columns: columns, rows: maxRows ?? rows)
  }

  private func targetRequest(
    for words: [String], firstDirection: Direction?, leadingRules: [WordRule]
  ) throws -> BoardRequest {
    let symbols = conditionalCharacters.union(words.joined().filter { !$0.isLetter })
    var generator = self
    if !symbols.isEmpty {
      guard let ordinary = filler.letters(excluding: symbols) else {
        throw Failure.noRoom(words: words, columns: columns, rows: rows)
      }
      generator.filler = ordinary
    }
    return try generator.packedRequest(
      for: words, firstDirection: firstDirection, leadingRules: leadingRules,
      maxRows: maxRows ?? rows + words.map(\.count).reduce(0, +))
  }

  private func validateConfiguration() throws {
    guard columns > 0, rows > 0, !directions.isEmpty, downWords.lowerBound >= 0,
      rules.allSatisfy(\.isValid), maxRows.map({ $0 >= rows }) ?? true
    else { throw Failure.invalidConfiguration }
  }
}

extension BoardGenerator {
  func targets(for request: BoardRequest, seed: UInt64) -> Board {
    Board(targets: packedLayout(for: request, seed: seed), columns: columns)
  }

  public func board(
    for words: [String], seed: UInt64, firstDirection: Direction? = nil
  ) throws -> Board {
    try request(for: words, firstDirection: firstDirection).board(seed: seed)
  }
}
