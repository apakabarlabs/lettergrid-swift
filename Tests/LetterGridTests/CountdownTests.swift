import LetterGrid
import Testing

@MainActor
struct CountdownTests {
  private struct SleepFailure: Error {}

  private var board: Board {
    Board(
      letters: [Array("CAT")],
      placements: [Placement(word: "CAT", start: Cell(row: 0, column: 0), direction: .right)])
  }

  @Test(arguments: [
    Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude,
    Double(Int64.max), .leastNonzeroMagnitude, 0, -1,
  ])
  func invalidIntervalsAreReportedBeforeSleeping(_ seconds: Double) async {
    let round = Round(board: board, directions: [.right], introduces: true)
    await #expect(throws: Countdown.Failure.invalidInterval) {
      try await Countdown { _ in throw SleepFailure() }.run(
        round, secondsPerLetter: seconds, introduce: {}, tick: {})
    }
  }

  @Test func callbacksThatDoNotAdvanceTheRoundFailInsteadOfLoopingForever() async {
    let introduction = Round(board: board, directions: [.right], introduces: true)
    let playing = Round(board: board, directions: [.right], seconds: 1)

    await #expect(throws: Countdown.Failure.noIntroductionProgress) {
      try await Countdown { _ in }.run(
        introduction, secondsPerLetter: 0.1, introduce: {}, tick: {})
    }
    await #expect(throws: Countdown.Failure.noClockProgress) {
      try await Countdown { _ in }.run(
        playing, secondsPerLetter: 0.1, introduce: {}, tick: {})
    }
  }

  @Test func aSleepFailureReachesTheCaller() async {
    let round = Round(board: board, directions: [.right], seconds: 1)

    await #expect(throws: SleepFailure.self) {
      try await Countdown { _ in throw SleepFailure() }.run(
        round, secondsPerLetter: 0.1, introduce: {}, tick: { round.secondPassed() })
    }

    #expect(round.secondsLeft == 1)
  }

  @Test func cancellationDuringSleepDoesNotTickEvenIfSleepReturnsNormally() async throws {
    let round = Round(board: board, directions: [.right], seconds: 1)
    var ticks = 0
    let task = Task {
      try await Countdown { _ in
        withUnsafeCurrentTask { $0?.cancel() }
      }.run(
        round, secondsPerLetter: 0.1, introduce: {},
        tick: {
          ticks += 1
          round.secondPassed()
        })
    }

    try await task.value

    #expect(ticks == 0)
    #expect(round.secondsLeft == 1)
  }

  @Test func cancellationDuringIntroductionDoesNotRevealAnotherLetter() async throws {
    let round = Round(board: board, directions: [.right], introduces: true)
    let task = Task {
      try await Countdown { _ in
        withUnsafeCurrentTask { $0?.cancel() }
      }.run(
        round, secondsPerLetter: 0.1,
        introduce: { _ = round.introduceNextLetter() }, tick: {})
    }

    try await task.value

    #expect(round.introduced.isEmpty)
    #expect(round.phase == .introducing)
  }

  @Test func aRoundFinishedDuringSleepDoesNotReceiveAStaleTick() async throws {
    let round = Round(board: board, directions: [.right], seconds: 1)
    var ticks = 0

    try await Countdown { _ in
      await MainActor.run {
        round.touch(Cell(row: 0, column: 0))
        round.drag(to: Cell(row: 0, column: 2))
        _ = round.release()
      }
    }.run(
      round, secondsPerLetter: 0.1, introduce: {},
      tick: {
        ticks += 1
        round.secondPassed()
      })

    #expect(round.phase == .won)
    #expect(ticks == 0)
    #expect(round.secondsLeft == 1)
  }
}
