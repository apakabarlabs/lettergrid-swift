import Testing

@testable import LetterGrid

struct BoundedHeightTests {
  @Test func repeatedCompactionDoesNotLockAnAlreadyShiftedPathToTheRight() throws {
    let cells = [
      Cell(row: 0, column: 0), Cell(row: 0, column: 1),
      Cell(row: 1, column: 1), Cell(row: 1, column: 2),
    ]
    let shifted = cells.map { Cell(row: $0.row + 2, column: $0.column + 2) }
    let rule = WordRule(startDirections: [.right], turns: 2)
    let builder = PathBoardBuilder(
      columns: 5, minimumRows: 5, rules: [rule])
    let weights = try filler()
    let limits = BoardGenerationLimits(attempts: 1, fillsPerAttempt: 1, layoutsPerAttempt: 1)
    func board(_ path: [Cell], seed: UInt64) -> Board {
      builder.board(
        layout: Layout(rows: 5, placements: [Placement(word: "ABCD", cells: path)]),
        filler: weights, dictionary: WordIndex([]), seed: seed, limits: limits)
    }
    for seed in UInt64(0)..<12 {
      #expect(board(cells, seed: seed) == board(shifted, seed: seed))
    }
  }

  @Test(arguments: [-1, 0, 4])
  func aMaximumBelowTheMinimumIsRejected(maximum: Int) throws {
    let generator = BoardGenerator(
      columns: 5, rows: 5, maxRows: maximum, directions: [.right], filler: try filler())
    #expect(throws: BoardGenerator.Failure.invalidConfiguration) {
      try generator.request(for: ["CAT"])
    }
  }

  @Test func impossiblePackingFailsBeforeAPlayableRequestExists() throws {
    let generator = BoardGenerator(
      columns: 3, rows: 1, maxRows: 1, directions: [.right], filler: try filler(), attempts: 0)
    #expect(throws: BoardGenerator.Failure.noRoom(words: ["CAT", "DOG"], columns: 3, rows: 1)) {
      try generator.request(for: ["CAT", "DOG"])
    }
    let unrestricted = BoardGenerator(
      columns: 3, rows: 1, directions: [.right], filler: try filler(), attempts: 0)
    #expect(try unrestricted.request(for: ["CAT", "DOG"]).board(seed: 1).rows > 1)
  }

  @Test func aHeightRangeCanFitAWordTallerThanItsMinimum() throws {
    let request = try BoardGenerator(
      columns: 3, rows: 2, maxRows: 5, directions: [.down], filler: filler(),
      downWords: 1...1, attempts: 0
    ).request(for: ["CAT"])
    for seed in UInt64(0)..<12 {
      let board = request.board(seed: seed)
      #expect((2...5).contains(board.rows))
      #expect(board.columns == 3)
      #expect(board.occurrences(of: "CAT", along: [.down]) == 1)
    }
  }

  @Test func anIntroductionTriesItsOtherAllowedDirectionWithinTheBounds() throws {
    let rule = WordRule(startDirections: [.down, .right])
    let request = try BoardGenerator(
      columns: 6, rows: 2, maxRows: 2, rules: [rule], filler: filler(), attempts: 0
    ).request(for: ["ABCDEF"], firstRule: rule)
    let board = request.board(seed: 1)
    #expect(board.rows == 2)
    #expect(board.placements.first?.direction == .right)
    #expect(rule.matches(board.placements[0]))
  }

  @Test(arguments: [0, 4])
  func theArmenianThirteenthLevelKeepsItsWordsAndSquare(attempts: Int) throws {
    let groups: [[Direction]] = [
      [.right, .down], [.downRight], [.downLeft], [.left], [.up], [.upLeft], [.upRight],
    ]
    let rules = groups.map { WordRule(startDirections: $0) }
    let introduced = WordRule(startDirections: [.upRight])
    let words = ["ՊԱՏ", "ԿԾԵԼ", "ԹԱՌՄԱ"]
    let request = try BoardGenerator(
      columns: 7, rows: 7, maxRows: 7, rules: rules,
      filler: LetterWeights(["ա": 1, "ե": 1, "ի": 1, "ո": 1, "ւ": 1, "ք": 1]),
      downWords: 1...2, layoutsPerAttempt: 40, attempts: attempts, fillsPerAttempt: 10
    ).request(for: words, firstRule: introduced)
    let dictionary = BoardDictionary(Set(words + ["ԳԱՀ", "ԳԵՏ", "ԱԶԳ"]))
    for seed in UInt64(0)..<16 {
      let board = request.board(seed: seed, dictionary: dictionary)
      check(board, words: words, rules: rules, quota: 1...2)
      #expect(introduced.matches(board.placements[0]))
    }
  }

  @Test(arguments: Direction.allCases, 0...3)
  func boundedFallbackHonoursEveryStartAndExactTurnCount(
    direction: Direction, turns: Int
  ) throws {
    let rule = WordRule(startDirections: [direction], turns: turns)
    let request = try BoardGenerator(
      columns: 7, rows: 7, maxRows: 7, rules: [rule], filler: filler(),
      attempts: 0, fillsPerAttempt: 0
    ).request(for: ["ABCDEF"], firstRule: rule)
    for seed in UInt64(0)..<4 {
      let board = request.board(seed: seed)
      #expect(board.columns == 7)
      #expect(board.rows == 7)
      #expect(rule.matches(board.placements[0]))
      #expect(board.occurrences(of: "ABCDEF", rules: [rule]) == 1)
    }
  }

  @Test(arguments: [0, 1])
  func cumulativeRulesKeepTheirQuotaAndIntroductionWithNoFillBudget(attempts: Int) throws {
    let rules = (0...3).map { WordRule(startDirections: Direction.allCases, turns: $0) }
    let introduced = WordRule(startDirections: [.upRight], turns: 3)
    let available = rules + [introduced]
    let words = ["PLANET", "ORBIT", "SUN"]
    let request = try BoardGenerator(
      columns: 7, rows: 7, maxRows: 7, rules: available, filler: filler(),
      downWords: 1...2, attempts: attempts, fillsPerAttempt: 0
    ).request(for: words, firstRule: introduced)
    for seed in UInt64(0)..<12 {
      let board = request.board(seed: seed)
      check(board, words: words, rules: available, quota: 1...2)
      #expect(introduced.matches(board.placements[0]))
    }
  }

  @Test func heightPruningUsesTheSpanBeforeNormalizingUpwardPaths() {
    let rule = WordRule(startDirections: [.up], turns: 2)
    let paths = PathShapes(
      columns: 5, length: 6, rule: rule, maximumShapes: 16, maximumRows: 3
    ).cells(seed: 9)
    #expect(!paths.isEmpty)
    for cells in paths {
      #expect(rule.matches(cells))
      #expect(cells.allSatisfy { (0..<3).contains($0.row) && (0..<5).contains($0.column) })
    }
  }

  @Test func boundedStraightBoardsKeepNaturalFillerWhenTheDictionaryIsNoisy() throws {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    let dictionary = Set(alphabet.flatMap { first in alphabet.map { "\(first)\($0)" } })
    let weights = try LetterWeights(
      Dictionary(uniqueKeysWithValues: alphabet.map { (String($0), 1.0) }))
    let words = ["PLANET", "ORBIT", "SUN"]
    let ways: [Direction] = [.right, .down]
    let request = try BoardGenerator(
      columns: 7, rows: 7, maxRows: 7, directions: ways, filler: weights,
      downWords: 1...2, attempts: 2, fillsPerAttempt: 2
    ).request(for: words)
    for seed in UInt64(0)..<4 {
      let board = request.board(seed: seed, dictionary: dictionary)
      let occupied = Set(board.placements.flatMap(\.cells))
      let targetLetters = Set(words.joined())
      let ordinary = (0..<board.rows).contains { row in
        (0..<board.columns).contains { column in
          let cell = Cell(row: row, column: column)
          return !occupied.contains(cell) && targetLetters.contains(board[cell])
        }
      }
      #expect(ordinary)
      #expect(board.rows == 7)
      for word in words { #expect(board.occurrences(of: word, along: ways) == 1) }
    }
  }

  @Test func theOptionalMaximumIsPartOfRequestIdentity() throws {
    let unrestricted = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down], filler: try filler())
    let explicitNil = BoardGenerator(
      columns: 7, rows: 7, maxRows: nil, directions: [.right, .down], filler: try filler())
    let bounded = BoardGenerator(
      columns: 7, rows: 7, maxRows: 7, directions: [.right, .down], filler: try filler())
    #expect(unrestricted == explicitNil)
    #expect(unrestricted != bounded)
    #expect(
      try unrestricted.request(for: ["CAT", "DOG"]).board(seed: 8)
        == explicitNil.request(for: ["CAT", "DOG"]).board(seed: 8))
  }

  private func check(
    _ board: Board, words: [String], rules: [WordRule], quota: ClosedRange<Int>
  ) {
    #expect(board.columns == 7)
    #expect(board.rows == 7)
    #expect(board.placements.map(\.word) == words)
    #expect(quota.contains(board.placements.filter(\.direction.isVertical).count))
    for placement in board.placements {
      #expect(board.text(along: placement.cells) == placement.word)
      #expect(rules.contains { $0.matches(placement) })
      #expect(board.occurrences(of: placement.word, rules: rules) == 1)
    }
  }

  private func filler() throws -> LetterWeights {
    try LetterWeights(["x": 1, "q": 2, "z": 3])
  }
}
