import Testing

@testable import LetterGrid

@MainActor
struct RoundTests {
  private let board = Board(
    letters: [
      Array("HOUSEX"),
      Array("QDOORZ"),
      Array("XXXXXX"),
    ],
    placements: [
      Placement(word: "HOUSE", start: Cell(row: 0, column: 0), direction: .right),
      Placement(word: "DOOR", start: Cell(row: 1, column: 1), direction: .right),
    ]
  )

  private func revealAll(_ round: Round) {
    while round.reveal() != nil {}
  }

  @Test func aHintFromTheStartOpensTheLettersInOrderAndKeepsTheLastHidden() {
    let round = Round(board: board, directions: [.right, .down])
    let house = board.placements[0]

    revealAll(round)

    #expect(round.shownLetters(of: house) == ["H", "O", "U", "S", nil])
    #expect(round.hintTarget == nil)
  }

  @Test func aHintAnywhereButTheFirstLetterNeverOpensTheFirstAndKeepsOneMoreHidden() {
    let round = Round(board: board, directions: [.right, .down], hintOrder: .anyButFirst)
    let house = board.placements[0]

    revealAll(round)

    let shown = round.shownLetters(of: house)
    #expect(shown[0] == nil)
    #expect(shown.filter { $0 == nil }.count == 2)
    #expect(round.revealed[house] == 3)
  }

  @Test func theLettersAHintOpensAreTheSameEveryTime() {
    let first = Round(board: board, directions: [.right], hintOrder: .anyButFirst)
    let second = Round(board: board, directions: [.right], hintOrder: .anyButFirst)

    _ = first.reveal()
    _ = second.reveal()

    #expect(first.hintedCells == second.hintedCells)
    #expect(first.hintedCells.count == 1)
    #expect(first.hintedCells != [board.placements[0].cells[0]])
  }

  @Test func aFoundWordShowsEveryLetterAndNoLongerMarksItsHints() {
    let round = Round(board: board, directions: [.right])
    let door = board.placements[1]
    _ = round.reveal()
    _ = round.reveal()
    _ = round.reveal()

    round.touch(door.cells[0])
    round.drag(to: door.cells[3])
    _ = round.release()

    #expect(round.shownLetters(of: door) == ["D", "O", "O", "R"])
    #expect(round.hintedCells.allSatisfy { !door.cells.contains($0) })
  }

  @Test func theIntroducedWordIsFoundOnceItsLastLetterIsShown() {
    let round = Round(board: board, directions: [.right], introduces: true)

    while round.phase == .introducing {
      _ = round.introduceNextLetter()
    }

    #expect(round.found == [board.placements[0]])
    #expect(round.phase == .playing)
  }

  @Test func theCountdownIntroducesTheFirstWordLetterByLetter() async {
    let round = Round(board: board, directions: [.right], introduces: true)
    var letters = 0

    await Countdown { _ in await Task.yield() }.run(
      round, secondsPerLetter: 0.1,
      introduce: {
        letters += 1
        _ = round.introduceNextLetter()
      },
      tick: {})

    #expect(letters == 6)
    #expect(round.phase == .playing)
  }
}
