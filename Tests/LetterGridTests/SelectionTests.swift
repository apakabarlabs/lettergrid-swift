import Foundation
import Testing
import Yams

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

  private struct Case: Decodable {
    let name: String
    let rows: [String]
    let from: [Int]
    let toward: [Int]
    let ways: [Direction]
    let text: String
  }

  @Test func dragsSelectTheCellsEveryPortAgreesOn() throws {
    let url = try #require(
      Bundle.module.url(forResource: "selections", withExtension: "yaml", subdirectory: "Fixtures"))
    let cases = try YAMLDecoder().decode(
      [Case].self, from: String(contentsOf: url, encoding: .utf8))
    for item in cases {
      let board = Board(letters: item.rows.map(Array.init), placements: [])
      let cells = board.selection(
        from: Cell(row: item.from[0], column: item.from[1]),
        toward: Cell(row: item.toward[0], column: item.toward[1]), along: item.ways)
      #expect(board.text(along: cells) == item.text, "\(item.name)")
    }
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
