import LetterGrid
import Testing

struct BoardValidationTests {
  @Test func aRaggedMatrixIsRejectedBeforeAnyCellCanBeRead() {
    #expect(throws: Board.Failure.irregularRows) {
      try Board(validating: [Array("CAT"), Array("X")], placements: [])
    }
  }

  @Test func emptyRowsAreRejectedButAnEmptyBoardIsValid() throws {
    #expect(throws: Board.Failure.irregularRows) {
      try Board(validating: [[]], placements: [])
    }
    let empty = try Board(validating: [], placements: [])
    #expect(empty.rows == 0)
    #expect(empty.columns == 0)
    #expect(!empty.contains(Cell(row: 0, column: 0)))
  }

  @Test(arguments: [Int.min, -1, 1, Int.max])
  func anOutOfBoundsPlacementIsRejectedWithoutIndexingTheMatrix(_ row: Int) {
    #expect(throws: Board.Failure.invalidPlacement("CAT")) {
      try Board(
        validating: [Array("CAT")],
        placements: [Placement(word: "CAT", start: Cell(row: row, column: 0), direction: .down)])
    }
  }

  @Test func placementsMustReadTheirWordsAndHaveUniqueNames() {
    let cat = Placement(word: "CAT", start: Cell(row: 0, column: 0), direction: .right)
    #expect(throws: Board.Failure.invalidPlacement("CAT")) {
      try Board(validating: [Array("DOG")], placements: [cat])
    }
    #expect(throws: Board.Failure.duplicateWord("CAT")) {
      try Board(validating: [Array("CAT")], placements: [cat, cat])
    }
  }
}
