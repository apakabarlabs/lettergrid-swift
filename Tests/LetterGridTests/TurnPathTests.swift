import Testing

@testable import LetterGrid

struct TurnPathTests {
  private let path = [
    Cell(row: 0, column: 0), Cell(row: 0, column: 1), Cell(row: 1, column: 1),
    Cell(row: 1, column: 2), Cell(row: 2, column: 2),
  ]

  @Test func aPlacementRetainsEveryTurnAndItsReverse() {
    let placement = Placement(word: "ABCDE", cells: path)
    #expect(placement.turns == 3)
    #expect(placement.start == path[0])
    #expect(placement.direction == .right)
    #expect(placement.reversed.cells == path.reversed())
    #expect(WordRule(startDirections: [.right], turns: 3).matches(placement))
    #expect(!WordRule(startDirections: [.right], turns: 2).matches(placement))
  }

  @Test func pathsRequireAdjacentCellsAndRightAngleTurnsWithoutRevisits() {
    #expect(PathGeometry([path[0], path[1], path[0]]) == nil)
    #expect(PathGeometry([path[0], path[1], Cell(row: 1, column: 2)]) == nil)
    #expect(PathGeometry([path[0], Cell(row: 0, column: 2)]) == nil)
    #expect(
      PathGeometry([
        Cell(row: 0, column: 1), Cell(row: 1, column: 2),
        Cell(row: 2, column: 1),
      ])?.turns == 1)
  }

  @Test func selectionFollowsTurnsAndBacktracksWithoutRevisiting() {
    let board = Board(letters: Array(repeating: Array("XXXXX"), count: 5), placements: [])
    let rule = WordRule(startDirections: [.right], turns: 3)
    var selected = [path[0]]
    for cell in path.dropFirst() {
      selected = board.selection(extending: selected, toward: cell, rules: [rule])
    }
    #expect(selected == path)
    #expect(
      board.selection(
        extending: selected, toward: Cell(row: 2, column: 3),
        rules: [rule]) == selected)
    selected = board.selection(extending: selected, toward: path[1], rules: [rule])
    #expect(selected == Array(path.prefix(2)))
  }

  @Test @MainActor func roundFindsABentWordAndHintsFollowItsCells() {
    let placement = Placement(word: "ABCDE", cells: path)
    let board = Board(
      letters: [Array("ABX"), Array("XCD"), Array("XXE")],
      placements: [placement])
    let round = Round(board: board, rules: [WordRule(startDirections: [.right], turns: 3)])
    for expected in path.dropLast() {
      _ = round.reveal()
      #expect(round.hintedCells.last == expected)
    }
    round.touch(path[0])
    for cell in path.dropFirst() { round.drag(to: cell) }
    #expect(round.release() == placement)
    #expect(round.phase == .won)
  }

  @Test @MainActor func straightOnlyRestorationRejectsABentPlacement() {
    let placement = Placement(word: "ABCDE", cells: path)
    let board = Board(
      letters: [Array("ABX"), Array("XCD"), Array("XXE")],
      placements: [placement])
    #expect(throws: Round.Failure.unselectableWord("ABCDE")) {
      try Round(restoring: RoundProgress(), board: board, directions: Direction.allCases)
    }
  }

  @Test func distinctReadingsThroughTheSameCellsCountSeparately() {
    let board = Board(letters: [Array("AA"), Array("AA")], placements: [])
    let rule = WordRule(startDirections: Direction.allCases, turns: 2)
    #expect(board.occurrences(of: "AAAA", rules: [rule]) == 4)
  }

  @Test func dictionarySingleLettersRemainVisibleToRuleBasedSearch() {
    let board = Board(letters: [Array("AX"), Array("XA")], placements: [])
    let rules = [WordRule(startDirections: Direction.allCases)]
    #expect(board.occurrences(of: "A", rules: rules) == 2)
    #expect(board.strayWords(of: ["A"], rules: rules) == ["A", "A"])
  }

  @Test func dictionarySearchIncludesTurnsAndIgnoresTheIntendedSubpath() {
    let placement = Placement(word: "ABCDE", cells: path)
    let board = Board(
      letters: [Array("ABX"), Array("XCD"), Array("XXE")],
      placements: [placement])
    let rules = (0...3).map { WordRule(startDirections: Direction.allCases, turns: $0) }
    #expect(board.strayWords(of: ["ABCDE", "BCD", "BXD"], rules: rules) == ["BXD"])
  }

  @Test func revealProgressHandlesEmptyPathsAndReducedMotion() {
    #expect(PathReveal(cells: path, elapsed: 0, duration: 1).cells == [path[0]])
    #expect(PathReveal(cells: path, elapsed: 0.7, duration: 1).cells == path)
    #expect(PathReveal(cells: path, elapsed: 0, duration: 1, reduceMotion: true).cells == path)
    #expect(PathReveal(cells: [], elapsed: 0, duration: 0).cells.isEmpty)
  }
}

struct TurnPathIntegrationTests {
  @Test(arguments: Direction.allCases, 0...3)
  func generationHonoursEveryStartAndExactTurnCount(direction: Direction, turns: Int) throws {
    let rule = WordRule(startDirections: [direction], turns: turns)
    let generator = BoardGenerator(
      columns: 7, rows: 7, rules: [rule],
      filler: try LetterWeights(["x": 1, "q": 1]), attempts: 1, fillsPerAttempt: 1)
    let board = try generator.request(for: ["ABCDEF"], firstRule: rule).board(seed: 12)
    #expect(rule.matches(board.placements[0]))
    #expect(board.occurrences(of: "ABCDEF", rules: [rule]) == 1)
  }

  @Test func tooShortATurnedWordIsRejectedBeforeBuilding() throws {
    let rule = WordRule(startDirections: [.right], turns: 3)
    let generator = BoardGenerator(
      columns: 7, rows: 7, rules: [rule],
      filler: try LetterWeights(["x": 1]))
    #expect(throws: BoardGenerator.Failure.self) {
      try generator.request(for: ["ABCD"], firstRule: rule)
    }
  }

  @Test func compactLayoutsReuseMatchingLetters() throws {
    let rule = WordRule(startDirections: [.right, .down])
    let generator = BoardGenerator(
      columns: 4, rows: 4, rules: [rule],
      filler: try LetterWeights(["x": 1, "y": 1, "z": 1, "q": 1]), downWords: 1...1,
      attempts: 1, fillsPerAttempt: 1)
    let board = try generator.request(for: ["CAT", "TAR"]).board(seed: 17)
    #expect(!Set(board.placements[0].cells).isDisjoint(with: board.placements[1].cells))
  }

  @Test func allRuleSearchPrunesALargeDictionaryAtItsPrefixes() {
    let board = Board(letters: Array(repeating: Array("ZZZZZZZ"), count: 7), placements: [])
    let dictionary = Set((0..<20_000).map { "ABC\($0)" })
    let rules = (0...3).map { WordRule(startDirections: Direction.allCases, turns: $0) }
    #expect(board.strayWords(of: dictionary, rules: rules).isEmpty)
    #expect(
      PathShapes(
        columns: 7, length: 20,
        rule: WordRule(startDirections: [.right], turns: 3)
      ).cells().count <= 256)
  }

  @Test func cumulativeRulesBuildNaturalWordsAndKeepTheRequiredIntroduction() throws {
    let groups: [[Direction]] = [
      [.right, .down], [.downRight], [.downLeft], [.left], [.up], [.upLeft], [.upRight],
    ]
    let rules = (0...3).flatMap { turns in
      groups.map { WordRule(startDirections: $0, turns: turns) }
    }
    let required = WordRule(startDirections: [.upRight], turns: 3)
    let words = ["PLANET", "ORBIT", "LUNAR"]
    let generator = BoardGenerator(
      columns: 7, rows: 7, rules: rules,
      filler: try LetterWeights(["x": 1, "q": 1, "z": 1]),
      dictionary: ["PLANET", "ORBIT", "LUNAR", "STAR", "MOON", "SOLAR"],
      downWords: 1...2, attempts: 2, fillsPerAttempt: 2)
    let board = try generator.request(for: words, firstRule: required).board(seed: 73)
    #expect(required.matches(board.placements[0]))
    #expect(board.placements.map(\.word) == words)
    #expect(words.allSatisfy { board.occurrences(of: $0, rules: rules) == 1 })
  }

  @Test func legacyFallbackConsumesTheReleasedWholePermutationPerBlank() throws {
    let filler = try LetterWeights(["x": 1, "y": 2, "z": 3], sameNeighbour: 0.02)
    var legacyRandom = SeededRandom(seed: 37)
    let legacy = BandLayout(columns: 3, minimumRows: 2, generationVersion: .v0p9)
      .board(for: ["AB"], directions: [0: .right], filler: filler, using: &legacyRandom)
    var expected = SeededRandom(seed: 37)
    for _ in 0..<12 { _ = expected.next() }
    #expect(legacyRandom.next() == expected.next())
    #expect(legacy.rows == 2)
    #expect(legacy.placements[0].word == "AB")
    #expect(BoardGenerationVersion(rawValue: "0.12") == .v0p12)
    #expect(BoardGenerationVersion(rawValue: "current") == nil)
  }

  @Test @MainActor func straightRulesCanCorrectAnInitiallyOffAxisDrag() {
    let placement = Placement(word: "CAT", start: Cell(row: 0, column: 0), direction: .right)
    let board = Board(letters: [Array("CAT"), Array("XXX")], placements: [placement])
    let round = Round(board: board, rules: [WordRule(startDirections: [.right, .down])])
    round.touch(placement.start)
    round.drag(to: Cell(row: 1, column: 1))
    round.drag(to: Cell(row: 0, column: 2))
    #expect(round.selection == placement.cells)
    #expect(round.release() == placement)
  }

  @Test @MainActor func mixedRulesCanCorrectTheFirstSegmentBeforeATurn() {
    let placement = Placement(word: "CAT", start: Cell(row: 0, column: 0), direction: .right)
    let board = Board(letters: [Array("CAT"), Array("XXX")], placements: [placement])
    let rules = [
      WordRule(startDirections: Direction.allCases),
      WordRule(startDirections: [.right, .down], turns: 1),
    ]
    let round = Round(board: board, rules: rules)
    round.touch(placement.start)
    round.drag(to: Cell(row: 1, column: 1))
    round.drag(to: Cell(row: 0, column: 2))
    #expect(round.selection == placement.cells)
    #expect(round.release() == placement)
  }

  @Test(arguments: [Cell(row: 2, column: 2), Cell(row: 2, column: 3)])
  func mixedSelectionPrefersAnIntentionalTurnWhenBothEndpointsMatch(end: Cell) {
    let board = Board(letters: Array(repeating: Array("XXXXX"), count: 5), placements: [])
    let rules = [
      WordRule(startDirections: Direction.allCases),
      WordRule(startDirections: [.right, .down], turns: 1),
    ]
    let start = Cell(row: 0, column: 0)
    let straight = [start, Cell(row: 0, column: 1), Cell(row: 0, column: 2)]
    let selected = board.selection(
      extending: straight, toward: end, rules: rules)
    #expect(selected == straight + [Cell(row: 1, column: 2), Cell(row: 2, column: 2)])
  }

  @Test func zeroTurnRulesUseTheExistingStraightGenerator() throws {
    let filler = try LetterWeights(["x": 1, "q": 1, "z": 1])
    let ways: [Direction] = [.right, .down, .downRight]
    let rules = [
      WordRule(startDirections: [.right, .down]), WordRule(startDirections: [.downRight]),
    ]
    let straight = BoardGenerator(
      columns: 7, rows: 7, directions: ways, filler: filler,
      downWords: 1...2)
    let generic = BoardGenerator(
      columns: 7, rows: 7, rules: rules, filler: filler,
      downWords: 1...2)
    let words = ["PLANET", "ORBIT", "STAR"]
    let expected = try straight.request(for: words, firstDirection: .downRight).board(seed: 19)
    let actual = try generic.request(for: words, firstRule: rules[1]).board(seed: 19)
    #expect(actual == expected)
  }

  @Test func boundedShapeSamplingVariesTheFirstTurnPosition() throws {
    var firstTurns: Set<Int> = []
    let rule = WordRule(startDirections: [.right], turns: 3)
    for seed in UInt64(0)..<32 {
      let shape = try #require(
        PathShapes(
          columns: 10, length: 10, rule: rule,
          maximumShapes: 1
        ).cells(seed: seed).first)
      let firstTurn = try #require(
        (1..<(shape.count - 1)).first { index in
          Direction.between(shape[index], shape[index + 1]) != .right
        })
      firstTurns.insert(firstTurn)
    }
    #expect(firstTurns.count >= 3)
  }

  @Test func aPreparedTurnedRequestKeepsItsShapeAcrossBoardSeeds() throws {
    let rule = WordRule(startDirections: [.right], turns: 3)
    let request = try BoardGenerator(
      columns: 7, rows: 7, rules: [rule],
      filler: LetterWeights(["x": 1, "q": 1]), layoutsPerAttempt: 1,
      attempts: 1, fillsPerAttempt: 1
    ).request(for: ["PLANET"], firstRule: rule)
    let first = request.board(seed: 1).placements[0]
    let second = request.board(seed: 2).placements[0]
    let relativeFirst = first.cells.map {
      Cell(row: $0.row - first.start.row, column: $0.column - first.start.column)
    }
    let relativeSecond = second.cells.map {
      Cell(row: $0.row - second.start.row, column: $0.column - second.start.column)
    }
    #expect(relativeFirst == relativeSecond)
  }

  @Test func equalLengthWordsCanReceiveDifferentReproducibleShapes() throws {
    let rule = WordRule(startDirections: [.right], turns: 3)
    let generator = BoardGenerator(
      columns: 7, rows: 7, rules: [rule],
      filler: try LetterWeights(["x": 1, "q": 1, "z": 1]), attempts: 0)
    let words = ["PLANET", "GALAXY", "COMETS", "NEBULA"]
    var paths: Set<[Cell]> = []
    for word in words {
      let first = try generator.request(for: [word], firstRule: rule).board(seed: 1)
      let repeated = try generator.request(for: [word], firstRule: rule).board(seed: 1)
      #expect(first == repeated)
      paths.insert(first.placements[0].cells)
    }
    #expect(paths.count > 1)
  }
}
