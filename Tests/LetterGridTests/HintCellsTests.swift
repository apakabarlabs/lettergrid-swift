import LetterGrid
import Testing

@MainActor
struct HintCellsTests {
  private var board: Board {
    Board(
      letters: [Array("XOX"), Array("CAT"), Array("XRX")],
      placements: [
        Placement(word: "CAT", start: Cell(row: 1, column: 0), direction: .right),
        Placement(word: "OAR", start: Cell(row: 0, column: 1), direction: .down),
      ])
  }

  @Test func crossingHintsKeepPlacementOrderAndRepeatedCells() {
    let round = Round(
      board: board, directions: [.right, .down],
      progress: RoundProgress(revealed: ["CAT": 2, "OAR": 2]))

    #expect(
      round.hintedCells == [
        Cell(row: 1, column: 0), Cell(row: 1, column: 1),
        Cell(row: 0, column: 1), Cell(row: 1, column: 1),
      ])
  }

  @Test func findingAWordRemovesItsHintsButKeepsTheCrossingWordHints() {
    let round = Round(
      board: board, directions: [.right, .down],
      progress: RoundProgress(found: ["CAT"], revealed: ["CAT": 2, "OAR": 2]))

    #expect(round.hintedCells == [Cell(row: 0, column: 1), Cell(row: 1, column: 1)])
  }

  @Test func aLongWordRestoresTheSameShuffledHintOrder() throws {
    let word = String(repeating: "A", count: 256)
    let placement = Placement(word: word, start: Cell(row: 0, column: 0), direction: .right)
    let board = Board(letters: [Array(word)], placements: [placement])
    let round = Round(board: board, directions: [.right], hintOrder: .anyButFirst)
    for _ in 1..<word.count { _ = round.reveal() }
    let before = round.hintedCells
    let restored = try Round(
      restoring: round.progress, board: board, directions: [.right], hintOrder: .anyButFirst)

    #expect(before.count == 255)
    #expect(Set(before) == Set(placement.cells.dropFirst()))
    #expect(restored.hintedCells == before)
    #expect(round.hintedCells == before)
    #expect(
      restored.shownLetters(of: placement) == [nil] + Array(repeating: Character("A"), count: 255))
    #expect(restored.hintTarget == nil)
  }
}
