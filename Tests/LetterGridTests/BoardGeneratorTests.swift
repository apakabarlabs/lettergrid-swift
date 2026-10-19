import Testing

@testable import LetterGrid

struct BoardGeneratorTests {
  private let filler: LetterWeights
  private let words = ["house", "water", "cat", "tree", "plan"]

  init() throws {
    filler = try LetterWeights(["a": 8, "e": 12, "t": 9, "s": 6, "q": 0.1])
  }

  private func generator(columns: Int = 7, rows: Int = 7) -> BoardGenerator {
    BoardGenerator(columns: columns, rows: rows, directions: [.right, .down], filler: filler)
  }

  @Test func placesEveryWordExactlyOnce() throws {
    let board = try generator().board(for: words, seed: 42)

    for word in words.map({ $0.uppercased() }) {
      #expect(board.occurrences(of: word, along: [.right, .down]) == 1)
    }
    #expect(board.placements.map(\.word) == words.map { $0.uppercased() })
    for placement in board.placements {
      #expect(board.text(along: placement.cells) == placement.word)
    }
  }

  @Test func fillsEveryCellWithALetter() throws {
    let board = try generator().board(for: words, seed: 7)

    #expect(board.rows == 7)
    #expect(board.columns == 7)
    let letters = board.letters.joined()
    #expect(letters.allSatisfy { $0.isLetter })
  }

  @Test func theSameSeedGivesTheSameBoard() throws {
    let first = try generator().board(for: words, seed: 99)
    let second = try generator().board(for: words, seed: 99)

    #expect(first == second)
  }

  @Test func noOtherWordOfTheDictionaryReadsOnTheBoard() throws {
    let dictionary: Set<String> = ["SAT", "TEA", "EAT", "SEA", "ATE", "TEST", "SET", "TAT"]
    let generator = BoardGenerator(
      columns: 6, rows: 6, directions: [.right, .down], filler: filler, dictionary: dictionary)

    for seed in 1...20 {
      let board = try generator.board(for: words, seed: UInt64(seed))
      #expect(board.strayWords(of: dictionary, along: [.right, .down]).isEmpty)
    }
  }

  @Test func aDictionaryWordInsideAHiddenWordIsNotStray() {
    let board = Board(
      letters: [Array("THERE"), Array("QQQQQ")],
      placements: [Placement(word: "THERE", start: Cell(row: 0, column: 0), direction: .right)]
    )

    #expect(board.strayWords(of: ["HER", "THE", "THERE"], along: [.right, .down]).isEmpty)
  }

  @Test func weightedFillerAvoidsStrayWordsInsteadOfNeedingAnUnlikelyRandomGrid() throws {
    let directions: [Direction] = [.right, .down, .downRight, .downLeft]
    let generator = BoardGenerator(
      columns: 7, rows: 15, directions: directions,
      filler: try LetterWeights(["a": 1_000, "b": 1]), dictionary: ["AAA"],
      downWords: 1...2, layoutsPerAttempt: 1, attempts: 1, fillsPerAttempt: 20)
    let words = ["PERSPECTIVE", "SUN", "MOON"]
    let board = try generator.board(for: words, seed: 1)

    #expect(board.strayWords(of: ["AAA"], along: directions).isEmpty)
    for word in words {
      #expect(board.occurrences(of: word, along: directions) == 1)
    }
    #expect(board.placements.map(\.word) == words)
  }

  @Test func aDictionaryWordAcrossTheBoardIsStray() {
    let board = Board(
      letters: [Array("CATQ"), Array("QQQQ")],
      placements: []
    )

    #expect(board.strayWords(of: ["CAT"], along: [.right, .down]) == ["CAT"])
  }

  @Test func moreWordsWiderThanTheBoardThanMayStandDownHaveNoRoom() {
    let generator = BoardGenerator(
      columns: 4, rows: 4, directions: [.right, .down], filler: filler, downWords: 0...1)

    #expect(throws: BoardGenerator.Failure.self) {
      try generator.board(for: ["elephant", "umbrella"], seed: 1)
    }
  }

  @Test func theWordsStandingDownStayWithinTheirRange() throws {
    for range in [0...1, 2...3, 3...5] {
      let generator = BoardGenerator(
        columns: 7, rows: 7, directions: [.right, .down], filler: filler, downWords: range)
      for seed in UInt64(1)...20 {
        let board = try generator.board(for: ["cat", "dog", "sun", "pen", "map"], seed: seed)
        #expect(range.contains(board.placements.filter { $0.direction == .down }.count))
      }
    }
  }

  @Test func anImpossibleMinimumVerticalQuotaFailsForEveryLayoutBuilder() throws {
    for firstDirection: Direction? in [nil, .right] {
      let generator = BoardGenerator(
        columns: 3, rows: 3, directions: [.right, .down], filler: filler,
        downWords: 2...2)

      #expect(throws: BoardGenerator.Failure.self) {
        try generator.board(for: ["CAT"], seed: 1, firstDirection: firstDirection)
      }
    }
  }

  @Test func repeatedTargetsAreRejectedAfterCaseNormalization() {
    for firstDirection: Direction? in [nil, .right] {
      #expect(throws: BoardGenerator.Failure.self) {
        try generator().board(for: ["cat", "CAT"], seed: 1, firstDirection: firstDirection)
      }
    }
  }

  @Test func targetsTooShortForASelectionAreRejected() {
    for word in ["", "A"] {
      #expect(throws: BoardGenerator.Failure.self) {
        try generator().board(for: [word], seed: 1)
      }
    }
  }

  @Test func aWordWiderThanTheBoardStandsDownAndStretchesIt() throws {
    let board = try generator(columns: 4, rows: 4).board(for: ["elephant", "cat"], seed: 1)

    #expect(board.placements.first { $0.word == "ELEPHANT" }?.direction == .down)
    #expect(board.rows >= 8)
    #expect(board.columns == 4)
  }

  @Test func wordsTooWideToLieBesideTheStandingOnesGetRowsOfTheirOwn() throws {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down], filler: filler, downWords: 2...2)
    let words = ["breakfast", "telephone", "kitchen", "freedom", "weather"]

    for seed in UInt64(1)...10 {
      let board = try generator.board(for: words, seed: seed)
      #expect(board.placements.count == words.count)
      #expect(board.placements.filter { $0.direction == .down }.count == 2)
    }
  }

  @Test func aWordLyingAcrossOftenCrossesOneStandingDown() throws {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .down], filler: filler, downWords: 2...2)
    let crossed = try (UInt64(1)...20).filter { seed in
      let cells = try generator.board(for: ["stone", "notes", "tones", "onset"], seed: seed)
        .placements.flatMap(\.cells)
      return Set(cells).count < cells.count
    }

    #expect(!crossed.isEmpty)
  }
}
