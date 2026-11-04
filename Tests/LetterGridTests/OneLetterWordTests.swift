import Testing

@testable import LetterGrid

@MainActor
struct OneLetterWordTests {
  private let island = Cell(row: 1, column: 4)

  private var board: Board {
    Board(
      letters: [
        Array("HOUSEX"),
        Array("QDOORÖ"),
        Array("XXXXXX"),
      ],
      placements: [
        Placement(word: "HOUSE", start: Cell(row: 0, column: 0), direction: .right),
        Placement(word: "Ö", cells: [Cell(row: 1, column: 5)]),
      ]
    )
  }

  @Test func aOneLetterWordTakesOneCell() throws {
    let placement = try Placement(validating: "Ö", cells: [island])

    #expect(placement.cells == [island])
    #expect(placement.word == "Ö")
  }

  @Test func onlyARuleWithoutTurnsReadsOneCell() {
    let straight = WordRule(startDirections: [.right, .down])
    let turned = WordRule(startDirections: [.right, .down], turns: 1)

    #expect(straight.minimumLength == 1)
    #expect(straight.matches([island]))
    #expect(turned.minimumLength == 3)
    #expect(!turned.matches([island]))
  }

  @Test func aBoardWithAOneLetterWordValidates() throws {
    let letters = board.letters
    _ = try Board(validating: letters, placements: board.placements)
  }

  @Test func aTapOnTheCellOfAOneLetterWordFindsIt() {
    let round = Round(board: board, directions: [.right, .down])
    let word = board.placements[1]

    round.touch(Cell(row: 1, column: 5))

    #expect(round.release() == word)
    #expect(round.found.contains(word))
    #expect(round.rejected.isEmpty)
  }

  @Test func aTapElsewhereFindsNothingAndShowsNoRejection() {
    let round = Round(board: board, directions: [.right, .down])

    round.touch(Cell(row: 0, column: 0))

    #expect(round.release() == nil)
    #expect(round.found.isEmpty)
    #expect(round.rejected.isEmpty)
  }

  @Test func aOneLetterWordIsFoundOnceAndThenATapOnItDoesNothing() {
    let round = Round(board: board, directions: [.right, .down])
    round.touch(Cell(row: 1, column: 5))
    _ = round.release()

    round.touch(Cell(row: 1, column: 5))

    #expect(round.release() == nil)
    #expect(round.rejected.isEmpty)
  }
}
