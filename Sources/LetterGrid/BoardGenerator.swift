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
    let words = words.map(\.cellUppercased)
    var targets = self
    targets.requiresRunFreeTargets = true
    let request: BoardRequest
    do {
      request = try targets.targetRequest(
        for: words, firstDirection: firstDirection, firstRule: firstRule)
    } catch Failure.noRoom {
      targets.requiresRunFreeTargets = false
      _ = try targets.targetRequest(
        for: words, firstDirection: firstDirection, firstRule: firstRule)
      throw Failure.unsettled(words: words, columns: columns, rows: maxRows ?? rows)
    }
    let dictionary = preparedDictionary
    for seed in UInt64(0)..<UInt64(Generation.settings.fill.seeds) {
      if let fallback = RunFreeFill(
        board: request.targets(seed: seed), weights: filler, rules: rules,
        conditionalCharacters: conditionalCharacters, dictionary: dictionary.index
      ).filled(seed: seed) {
        return request.avoidingRuns(
          fallback: fallback, weights: filler, symbols: conditionalCharacters)
      }
    }
    throw Failure.unsettled(words: words, columns: columns, rows: maxRows ?? rows)
  }

  private func targetRequest(
    for words: [String], firstDirection: Direction?, firstRule: WordRule?
  ) throws -> BoardRequest {
    let symbols = conditionalCharacters.union(words.joined().filter { !$0.isLetter })
    guard !symbols.isEmpty else {
      return try checkedRequest(for: words, firstDirection: firstDirection, firstRule: firstRule)
    }
    guard let ordinary = filler.letters(excluding: symbols) else {
      throw Failure.noRoom(words: words, columns: columns, rows: rows)
    }
    var generator = self
    generator.filler = ordinary
    return try generator.checkedRequest(
      for: words, firstDirection: firstDirection, firstRule: firstRule)
  }

  private func checkedRequest(
    for words: [String], firstDirection: Direction?, firstRule: WordRule?
  ) throws -> BoardRequest {
    guard columns > 0, rows > 0, !directions.isEmpty, downWords.lowerBound >= 0,
      rules.allSatisfy(\.isValid), maxRows.map({ $0 >= rows }) ?? true
    else { throw Failure.invalidConfiguration }
    let words = words.map(\.cellUppercased)
    let first: WordRule?
    if usesPathRules {
      guard firstDirection == nil, firstRule.map({ rules.contains($0) }) ?? true
      else { throw Failure.invalidConfiguration }
      first = firstRule
    } else {
      guard firstRule == nil else { throw Failure.invalidConfiguration }
      guard firstDirection.map({ directions.contains($0) }) ?? true else {
        throw Failure.noRoom(words: words, columns: columns, rows: rows)
      }
      first = firstDirection.map { WordRule(startDirections: [$0]) }
    }
    return try packedRequest(
      for: words, firstDirection: firstDirection, firstRule: first,
      maxRows: maxRows ?? rows + words.map(\.count).reduce(0, +))
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
