import Foundation

public enum BoardGenerationVersion: String, Codable, Sendable {
  case v0p9 = "0.9"
  case v0p12 = "0.12"

  public static let current = Self.v0p12
}

public struct BoardRequest: Equatable, Sendable {
  public let words: [String]
  public let firstDirection: Direction?
  public let firstRule: WordRule?
  fileprivate let pathLayout: Layout?
  private let generator: BoardGenerator

  fileprivate init(
    words: [String], firstDirection: Direction?, generator: BoardGenerator,
    firstRule: WordRule? = nil, pathLayout: Layout? = nil
  ) {
    self.words = words
    self.firstDirection = firstDirection
    self.generator = generator
    self.firstRule = firstRule
    self.pathLayout = pathLayout
  }

  public func board(seed: UInt64, dictionary: Set<String>? = nil) -> Board {
    generator.board(for: self, seed: seed, dictionary: dictionary)
  }
}

public struct BoardGenerator: Equatable, Sendable {
  public enum Failure: LocalizedError, Equatable {
    case noRoom(words: [String], columns: Int, rows: Int)
    case invalidConfiguration

    public var errorDescription: String? {
      switch self {
      case .noRoom(let words, let columns, let rows):
        "No grid \(columns) wide and at least \(rows) high can hold "
          + words.joined(separator: ", ")
      case .invalidConfiguration:
        "Grid dimensions must be positive, directions nonempty, the vertical minimum "
          + "nonnegative, and search limits nonnegative with at least one layout per attempt."
      }
    }
  }

  public let columns: Int
  public let rows: Int
  public let directions: [Direction]
  public let filler: LetterWeights
  public let dictionary: Set<String>
  public let downWords: ClosedRange<Int>
  public let layoutsPerAttempt: Int
  public let attempts: Int
  public let fillsPerAttempt: Int
  public private(set) var rules: [WordRule]
  public let generationVersion: BoardGenerationVersion
  private var usesPathRules = false
  private let wordIndex: WordIndex

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.columns == rhs.columns && lhs.rows == rhs.rows && lhs.directions == rhs.directions
      && lhs.filler == rhs.filler && lhs.dictionary == rhs.dictionary
      && lhs.downWords == rhs.downWords && lhs.layoutsPerAttempt == rhs.layoutsPerAttempt
      && lhs.attempts == rhs.attempts && lhs.fillsPerAttempt == rhs.fillsPerAttempt
      && lhs.rules == rhs.rules && lhs.usesPathRules == rhs.usesPathRules
      && lhs.generationVersion == rhs.generationVersion
  }

  public init(
    columns: Int, rows: Int, directions: [Direction], filler: LetterWeights,
    dictionary: Set<String> = [], downWords: ClosedRange<Int> = 0...Int.max,
    layoutsPerAttempt: Int = 40, attempts: Int = 200, fillsPerAttempt: Int = 20,
    generationVersion: BoardGenerationVersion = .current
  ) {
    self.columns = columns
    self.rows = rows
    self.directions = directions
    self.filler = filler
    self.dictionary = Set(dictionary.map(\.cellUppercased))
    self.wordIndex = WordIndex(self.dictionary)
    self.downWords = downWords
    self.layoutsPerAttempt = layoutsPerAttempt
    self.attempts = attempts
    self.fillsPerAttempt = fillsPerAttempt
    self.rules = [WordRule(startDirections: directions)]
    self.generationVersion = generationVersion
  }

  public init(
    columns: Int, rows: Int, rules: [WordRule], filler: LetterWeights,
    dictionary: Set<String> = [], downWords: ClosedRange<Int> = 0...Int.max,
    layoutsPerAttempt: Int = 40, attempts: Int = 200, fillsPerAttempt: Int = 20,
    generationVersion: BoardGenerationVersion = .current
  ) {
    self.init(
      columns: columns, rows: rows,
      directions: Direction.allCases.filter { way in
        rules.contains { $0.startDirections.contains(way) }
      },
      filler: filler, dictionary: dictionary, downWords: downWords,
      layoutsPerAttempt: layoutsPerAttempt, attempts: attempts, fillsPerAttempt: fillsPerAttempt,
      generationVersion: generationVersion)
    self.rules = rules
    self.usesPathRules = true
  }

  public func request(
    for words: [String], firstDirection: Direction? = nil, firstRule: WordRule? = nil
  ) throws -> BoardRequest {
    guard columns > 0, rows > 0, !directions.isEmpty, downWords.lowerBound >= 0,
      layoutsPerAttempt > 0, attempts >= 0, fillsPerAttempt >= 0
    else { throw Failure.invalidConfiguration }
    let words = words.map(\.cellUppercased)
    if usesPathRules {
      guard generationVersion == .v0p12 else { throw Failure.invalidConfiguration }
      guard rules.allSatisfy(\.isValid), firstDirection == nil,
        firstRule.map({ rules.contains($0) }) ?? true
      else { throw Failure.invalidConfiguration }
      if rules.allSatisfy({ $0.turns == 0 }) {
        return try straightRequest(for: words, firstRule: firstRule)
      }
      guard
        let layout = PathBoardBuilder(
          columns: columns, minimumRows: rows, rules: rules, downWords: downWords
        )
        .preparedLayout(for: words, firstRule: firstRule, filler: filler)
      else { throw Failure.noRoom(words: words, columns: columns, rows: rows) }
      return BoardRequest(
        words: words, firstDirection: nil, generator: self,
        firstRule: firstRule, pathLayout: layout)
    }
    guard firstRule == nil else { throw Failure.invalidConfiguration }
    var probe = SeededRandom(seed: 0)
    guard !words.isEmpty, Set(words).count == words.count, words.allSatisfy({ $0.count > 1 }),
      !words.contains(where: { word in words.contains { $0 != word && $0.contains(word) } }),
      !readsBackwardsInside(words),
      filler.letters(excluding: Set(words.joined())) != nil,
      directionBuilder(firstDirection).assignments(for: words, using: &probe) != nil
    else {
      throw Failure.noRoom(words: words, columns: columns, rows: rows)
    }
    return BoardRequest(words: words, firstDirection: firstDirection, generator: self)
  }

  private func straightRequest(for words: [String], firstRule: WordRule?) throws -> BoardRequest {
    let generator = BoardGenerator(
      columns: columns, rows: rows, directions: directions, filler: filler, dictionary: dictionary,
      downWords: downWords, layoutsPerAttempt: layoutsPerAttempt, attempts: attempts,
      fillsPerAttempt: fillsPerAttempt, generationVersion: generationVersion)
    var probe = SeededRandom(seed: 0)
    let constrained = firstRule.map { Set($0.startDirections) != Set(directions) } ?? false
    let required = firstRule?.startDirections.first {
      generator.directionBuilder($0).assignments(for: words, using: &probe) != nil
    }
    if constrained && required == nil {
      throw Failure.noRoom(words: words, columns: columns, rows: rows)
    }
    let request = try generator.request(for: words, firstDirection: constrained ? required : nil)
    return BoardRequest(
      words: request.words, firstDirection: request.firstDirection,
      generator: generator, firstRule: firstRule)
  }

  fileprivate func board(
    for request: BoardRequest, seed: UInt64, dictionary: Set<String>?
  ) -> Board {
    let dictionary = dictionary.map { Set($0.map(\.cellUppercased)) } ?? self.dictionary
    let index = dictionary == self.dictionary ? wordIndex : WordIndex(dictionary)
    if let layout = request.pathLayout {
      return PathBoardBuilder(columns: columns, minimumRows: rows, rules: rules)
        .board(
          layout: layout, filler: filler, dictionary: index, seed: seed,
          limits: PathFillLimits(
            attempts: attempts, fillsPerAttempt: fillsPerAttempt,
            layoutsPerAttempt: layoutsPerAttempt))
    }
    let words = request.words
    let builder = LayoutBuilder(
      columns: columns, minimumRows: rows, directions: directions, downWords: downWords,
      firstDirection: request.firstDirection)
    var random = SeededRandom(seed: seed)
    let targets = WordIndex(Set(words))
    for _ in 0..<attempts {
      guard
        let layout = builder.lowestLayout(
          for: words, tries: layoutsPerAttempt, using: &random)
      else { break }
      let filler = BoardFiller(
        layout: layout, columns: columns, directions: directions,
        dictionary: index, targets: targets)
      guard
        let board = filler.fill(with: self.filler, attempts: fillsPerAttempt, using: &random)
      else { continue }
      if isClean(board, hiding: words, dictionary: index) { return board }
    }
    return bandedBoard(for: request, using: &random)
  }

  public func board(
    for words: [String], seed: UInt64, firstDirection: Direction? = nil
  ) throws -> Board {
    try request(for: words, firstDirection: firstDirection).board(seed: seed)
  }

  private func bandedBoard(for request: BoardRequest, using random: inout SeededRandom) -> Board {
    guard
      let assigned = directionBuilder(request.firstDirection).assignments(
        for: request.words, using: &random),
      let free = filler.letters(excluding: Set(request.words.joined()))
    else {
      fatalError("A board request is checked for directions and a free filler letter")
    }
    return BandLayout(columns: columns, minimumRows: rows, generationVersion: generationVersion)
      .board(for: request.words, directions: assigned, filler: free, using: &random)
  }

  private func readsBackwardsInside(_ words: [String]) -> Bool {
    guard directions.contains(where: { directions.contains($0.opposite) }) else { return false }
    return words.contains { word in
      words.contains { $0 != word && word.contains(String($0.reversed())) }
    }
  }

  private func directionBuilder(_ firstDirection: Direction?) -> DiagonalLayoutBuilder {
    DiagonalLayoutBuilder(
      columns: columns, minimumRows: rows, directions: directions, downWords: downWords,
      firstDirection: firstDirection)
  }

  private func isClean(_ board: Board, hiding words: [String], dictionary: WordIndex) -> Bool {
    words.allSatisfy { board.occurrences(of: $0, along: directions) == 1 }
      && board.strayWords(in: dictionary, along: directions).isEmpty
  }
}
