import Testing

@testable import LetterGrid

struct SelectionTests {
  private let board = Board(
    letters: [
      Array("CATS"),
      Array("ORXE"),
      Array("WEYA"),
      Array("ZZZL"),
    ],
    placements: []
  )

  @Test func aDragAlongTheRowSelectsTheRow() {
    let cells = board.selection(
      from: Cell(row: 0, column: 0), toward: Cell(row: 0, column: 2), along: [.right, .down])

    #expect(board.text(along: cells) == "CAT")
  }

  @Test func aDragSnapsToTheAxisItMovedFurthestAlong() {
    let cells = board.selection(
      from: Cell(row: 0, column: 0), toward: Cell(row: 2, column: 1), along: [.right, .down])

    #expect(board.text(along: cells) == "COW")
  }

  @Test func aDragBackwardsSelectsOnlyTheStartWhenOnlyForwardIsAllowed() {
    let cells = board.selection(
      from: Cell(row: 0, column: 3), toward: Cell(row: 0, column: 0), along: [.right, .down])

    #expect(cells == [Cell(row: 0, column: 3)])
  }

  @Test func aDragPastTheEdgeStopsAtTheEdge() {
    let cells = board.selection(
      from: Cell(row: 0, column: 3), toward: Cell(row: 9, column: 3), along: [.right, .down])

    #expect(board.text(along: cells) == "SEAL")
  }

  @Test func aDragToAnExtremeCoordinateOnlyVisitsBoardCells() {
    #expect(
      board.selection(
        from: Cell(row: 0, column: 3), toward: Cell(row: Int.max, column: 3), along: [.down])
        == (0..<4).map { Cell(row: $0, column: 3) })
    #expect(
      board.selection(
        from: Cell(row: 3, column: 3), toward: Cell(row: Int.min, column: Int.min),
        along: [.upLeft])
        == (0..<4).map { Cell(row: 3 - $0, column: 3 - $0) })
  }

  @Test func bothForwardDiagonalsCanBeSelected() {
    let ways: [Direction] = [.right, .down, .downRight, .downLeft]
    #expect(
      board.selection(from: Cell(row: 0, column: 0), toward: Cell(row: 3, column: 3), along: ways)
        == (0...3).map { Cell(row: $0, column: $0) })
    #expect(
      board.selection(from: Cell(row: 0, column: 3), toward: Cell(row: 3, column: 0), along: ways)
        == (0...3).map { Cell(row: $0, column: 3 - $0) })
  }

  @Test func anAlmostDiagonalDragSnapsToTheClosestDirection() {
    let cells = board.selection(
      from: Cell(row: 0, column: 0), toward: Cell(row: 3, column: 2),
      along: [.right, .down, .downRight, .downLeft])
    #expect(cells == (0...3).map { Cell(row: $0, column: $0) })
  }

  @Test func diagonalsStayUnavailableUnlessRequested() {
    let cells = board.selection(
      from: Cell(row: 0, column: 0), toward: Cell(row: 3, column: 2), along: [.right, .down])
    #expect(cells == (0...3).map { Cell(row: $0, column: 0) })
  }

  @Test func aBackwardDragDoesNotSnapToAForwardDiagonal() {
    let start = Cell(row: 0, column: 3)
    let cells = board.selection(
      from: start, toward: Cell(row: 0, column: 0),
      along: [.right, .down, .downRight, .downLeft])
    #expect(cells == [start])
  }
}
