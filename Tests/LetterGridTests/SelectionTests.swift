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
}
