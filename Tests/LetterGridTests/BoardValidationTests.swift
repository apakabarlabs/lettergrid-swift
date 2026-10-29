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

  @Test(arguments: [
    [], [Cell(row: 0, column: 0)], [Cell(row: 0, column: 0), Cell(row: 0, column: 1)],
    [Cell(row: 0, column: 0), Cell(row: 0, column: 2), Cell(row: 0, column: 3)],
    [Cell(row: 0, column: 0), Cell(row: 0, column: 1), Cell(row: 0, column: 0)],
    [Cell(row: 0, column: 0), Cell(row: 0, column: 1), Cell(row: 1, column: 2)],
  ])
  func aSavedPathThatIsNoWordPathIsReportedInsteadOfTrapping(_ cells: [Cell]) {
    #expect(throws: Board.Failure.invalidPlacement("CAT")) {
      try Placement(validating: "CAT", cells: cells)
    }
  }

  @Test func aValidSavedPathRestoresThePlacement() throws {
    let cells = [Cell(row: 0, column: 0), Cell(row: 0, column: 1), Cell(row: 1, column: 1)]
    #expect(
      try Placement(validating: "CAT", cells: cells) == Placement(word: "CAT", cells: cells))
  }
}
