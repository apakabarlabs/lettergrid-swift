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

  @Test func aWordThatReadsTheSameBackwardsIsRejectedWhenBothWaysAreOn() throws {
    let filler = try LetterWeights(["x": 1])
    let bothWays = BoardGenerator(
      columns: 7, rows: 7, directions: [.right, .left], filler: filler, downWords: 0...0)
    let oneWay = BoardGenerator(
      columns: 7, rows: 7, directions: [.right], filler: filler, downWords: 0...0)

    #expect(throws: BoardGenerator.Failure.self) {
      try bothWays.request(for: ["LEVEL", "CAT"])
    }
    #expect(throws: Never.self) { try oneWay.request(for: ["LEVEL", "CAT"]) }
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
