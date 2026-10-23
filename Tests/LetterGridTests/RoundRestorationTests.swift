import LetterGrid
import Testing

@MainActor
struct RoundRestorationTests {
  private var board: Board {
    Board(
      letters: [Array("CAT"), Array("DOG")],
      placements: [
        Placement(word: "CAT", start: Cell(row: 0, column: 0), direction: .right),
        Placement(word: "DOG", start: Cell(row: 1, column: 0), direction: .right),
      ])
  }

  @Test(arguments: [-1, 3, Int.max])
  func invalidRevealCountsAreReportedAtRestoration(_ count: Int) {
    let progress = RoundProgress(revealed: ["CAT": count])

    #expect(throws: RoundProgress.Failure.invalidRevealCount(word: "CAT", count: count)) {
      try Round(restoring: progress, board: board, directions: [.right])
    }
    #expect(progress.revealed["CAT"] == count)
  }

  @Test func unknownAndRepeatedFoundWordsAreReported() {
    #expect(throws: RoundProgress.Failure.unknownWord("SUN")) {
      try RoundProgress(found: ["SUN"]).validate(for: board)
    }
    #expect(throws: RoundProgress.Failure.duplicateFoundWord("CAT")) {
      try RoundProgress(found: ["CAT", "CAT"]).validate(for: board)
    }
    #expect(throws: RoundProgress.Failure.unknownWord("SUN")) {
      try RoundProgress(revealed: ["SUN": 1]).validate(for: board)
    }
  }

  @Test func negativeSecondsAreReported() {
    #expect(throws: RoundProgress.Failure.negativeSeconds(-1)) {
      try Round(restoring: RoundProgress(secondsLeft: -1), board: board, directions: [.right])
    }
  }

  @Test func aRoundMustAllowEveryWordToBeSelected() {
    #expect(throws: Round.Failure.unselectableWord("CAT")) {
      try Round(restoring: RoundProgress(), board: board, directions: [.down])
    }
  }

  @Test func anEmptyBoardIsAlreadyComplete() {
    let round = Round(board: Board(letters: [], placements: []), directions: [])
    #expect(round.phase == .won)
  }

  @Test func validProgressRoundTripsWithoutReplayingAnIntroduction() throws {
    let progress = RoundProgress(found: ["CAT"], revealed: ["DOG": 1], secondsLeft: 7)
    let round = try Round(
      restoring: progress, board: board, directions: [.right], seconds: 20, introduces: true)

    #expect(round.progress == progress)
    #expect(round.phase == .playing)
    #expect(round.shownLetters(of: board.placements[1]) == ["D", nil, nil])
  }

  @Test func aRestoredExpiredClockCannotPlayBeforeTheFirstTick() throws {
    let round = try Round(
      restoring: RoundProgress(secondsLeft: 0), board: board, directions: [.right],
      seconds: 20, introduces: true)

    round.touch(Cell(row: 0, column: 0))
    round.drag(to: Cell(row: 0, column: 2))

    #expect(round.phase == .lost)
    #expect(round.release() == nil)
  }

  @Test func externallyOwnedClockDoesNotStartARoundCountdown() throws {
    let progress = RoundProgress(found: ["CAT"], secondsLeft: 0)
    let round = try Round(restoring: progress, board: board, directions: [.right])

    #expect(round.phase == .playing)
    #expect(round.secondsLeft == nil)
  }
}
