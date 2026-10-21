import Testing

@testable import LetterGrid

struct ReverseDirectionTests {
  private let reverses: [Direction] = [.left, .up, .upLeft, .upRight]

  @Test func eachReverseDirectionStepsOppositeToItsForwardOne() {
    let pairs: [(Direction, Direction)] = [
      (.right, .left), (.down, .up), (.downRight, .upLeft), (.downLeft, .upRight),
    ]
    for (forward, reverse) in pairs {
      #expect(reverse.rowStep == -forward.rowStep)
      #expect(reverse.columnStep == -forward.columnStep)
      #expect(forward.opposite == reverse)
      #expect(reverse.opposite == forward)
    }
  }

  @Test func aBoardCanUseEachReverseDirectionWithoutStrayWords() throws {
    let words = ["CAT", "DOG", "SUN"]
    for direction in reverses {
      let generator = BoardGenerator(
        columns: 7, rows: 7, directions: [direction],
        filler: try LetterWeights(["x": 1, "q": 1, "z": 1]), dictionary: Set(words),
        downWords: 0...3)
      let board = try generator.board(for: words, seed: 8)
      #expect(board.placements.allSatisfy { $0.direction == direction }, "\(direction)")
      for placement in board.placements {
        #expect(board.text(along: placement.cells) == placement.word)
        #expect(board.occurrences(of: placement.word, along: [direction]) == 1)
      }
      #expect(board.strayWords(of: Set(words), along: [direction]).isEmpty)
    }
  }

  @Test func wordsRunningUpCountTowardTheVerticalQuota() throws {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .up],
      filler: try LetterWeights(["x": 1, "q": 1, "z": 1]), downWords: 1...1)
    for seed in 1...20 {
      let board = try generator.board(for: ["CAT", "DOG", "SUN"], seed: UInt64(seed))
      #expect(board.placements.filter { $0.direction == .up }.count == 1)
    }
  }

  @Test func aWordThatReadsTheSameBackwardsStandsOnceWhenBothWaysAreOn() throws {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .left, .down, .up],
      filler: try LetterWeights(["x": 1, "q": 1, "z": 1]), dictionary: ["LEVEL", "CAT", "SUN"],
      downWords: 0...3)
    for seed in 1...20 {
      let board = try generator.board(for: ["LEVEL", "CAT", "SUN"], seed: UInt64(seed))
      #expect(board.occurrences(of: "LEVEL", along: generator.directions) == 1)
      #expect(board.strayWords(of: ["LEVEL", "CAT", "SUN"], along: generator.directions).isEmpty)
    }
  }

  @MainActor
  @Test func aWordThatReadsTheSameBackwardsIsFoundFromEitherEnd() {
    let level = Placement(word: "LEVEL", start: Cell(row: 0, column: 0), direction: .right)
    let board = Board(letters: [Array("LEVELX"), Array("XXXXXX")], placements: [level])
    for (start, end) in [(0, 4), (4, 0)] {
      let round = Round(board: board, directions: [.right, .left])
      round.touch(Cell(row: 0, column: start))
      round.drag(to: Cell(row: 0, column: end))

      #expect(round.release() == level)
    }
  }

  @MainActor
  @Test func aWordThatReadsDifferentlyBackwardsIsNotFoundFromItsEnd() {
    let cat = Placement(word: "CAT", start: Cell(row: 0, column: 0), direction: .right)
    let board = Board(letters: [Array("CATX"), Array("XXXX")], placements: [cat])
    let round = Round(board: board, directions: [.right, .left])
    round.touch(Cell(row: 0, column: 2))
    round.drag(to: Cell(row: 0, column: 0))

    #expect(round.release() == nil)
  }

  @Test func aWordWhoseReverseLiesInsideAnotherIsRejectedWhenBothWaysAreOn() throws {
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: [.down, .up], filler: try LetterWeights(["x": 1]),
      downWords: 0...2)

    #expect(throws: BoardGenerator.Failure.self) {
      try generator.request(for: ["TAC", "CATS"])
    }
  }

  @Test func aDragTowardTheStartOfTheRowSelectsLeftwards() {
    let board = Board(letters: [Array("TACX"), Array("XXXX")], placements: [])

    let cells = board.selection(
      from: Cell(row: 0, column: 2), toward: Cell(row: 0, column: 0), along: [.right, .left])

    #expect(board.text(along: cells) == "CAT")
  }

  @Test func aDragUpAndLeftSelectsTheReverseDiagonal() {
    let board = Board(
      letters: [Array("TXX"), Array("XAX"), Array("XXC")], placements: [])

    let cells = board.selection(
      from: Cell(row: 2, column: 2), toward: Cell(row: 0, column: 0),
      along: [.right, .down, .upLeft])

    #expect(board.text(along: cells) == "CAT")
  }
}
