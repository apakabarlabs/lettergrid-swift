import Testing

@testable import LetterGrid

struct DiagonalTests {
  @Test func aBoardCanUseEitherDiagonalWithoutAddingStrayWords() throws {
    let words = ["CAT", "DOG", "SUN"]
    for direction in [Direction.downRight, .downLeft] {
      let generator = BoardGenerator(
        columns: 7, rows: 7, directions: [direction],
        filler: try LetterWeights(["x": 1, "q": 1, "z": 1]), dictionary: Set(words))
      let board = try generator.board(for: words, seed: 8)
      #expect(board.placements.allSatisfy { $0.direction == direction })
      for placement in board.placements {
        #expect(board.text(along: placement.cells) == placement.word)
        #expect(board.occurrences(of: placement.word, along: [direction]) == 1)
      }
      #expect(board.strayWords(of: Set(words), along: [direction]).isEmpty)
    }
  }

  @Test func mixedDirectionsKeepTheVerticalQuotaAndPermitBothDiagonals() throws {
    let ways: [Direction] = [.right, .down, .downRight, .downLeft]
    let generator = BoardGenerator(
      columns: 7, rows: 7, directions: ways,
      filler: try LetterWeights(["x": 1, "q": 1, "z": 1]), downWords: 1...2)
    var seen: Set<Direction> = []
    for seed in 1...30 {
      let board = try generator.board(for: ["CAT", "DOG", "SUN"], seed: UInt64(seed))
      #expect((1...2).contains(board.placements.filter { $0.direction == .down }.count))
      seen.formUnion(board.placements.map(\.direction))
    }
    #expect(seen.contains(.downRight))
    #expect(seen.contains(.downLeft))
  }

  @Test func aWordTooWideForADiagonalFailsInsteadOfGrowingForever() throws {
    let generator = BoardGenerator(
      columns: 3, rows: 3, directions: [.downLeft], filler: try LetterWeights(["x": 1]))
    #expect(throws: BoardGenerator.Failure.self) {
      try generator.board(for: ["ELEPHANT"], seed: 1)
    }
  }
}
