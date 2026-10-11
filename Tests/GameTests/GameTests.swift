import Levels
import Testing
import WordGrid

@testable import Game

@MainActor
struct GameTests {
  private let yaml = """
    seconds_per_level: 5
    intro_seconds_per_letter: 0.3
    show_word_list: true
    directions: [right, down]
    columns: {first: 6, step: 0, every: 1, last: 6}
    rows: {first: 6, step: 0, every: 1, last: 6}
    words_per_level: {first: 2, step: 0, every: 1, last: 2}
    min_word_length: 3
    cluster_size: 1
    letters: {q: 1, x: 1, z: 1}
    """

  private func run(words: [String] = ["cat", "dog", "sun", "map", "pen", "box"]) throws -> GameRun {
    let configuration = try GameConfiguration.decode(yaml)
    return GameRun(plan: try LevelPlan(configuration: configuration, words: words, seed: 7))
  }

  private func find(_ placement: Placement, in round: LevelRound) {
    round.touch(placement.cells[0])
    round.drag(to: placement.cells[placement.cells.count - 1])
    round.release()
  }

  private func introduce(_ round: LevelRound) {
    while round.phase == .introducing {
      round.introduceNextLetter()
    }
  }

  @Test func theFirstLevelShowsItsFirstWordLetterByLetterBeforeTheClockStarts() throws {
    let round = try #require(try run().round)
    let first = round.board.placements[0]

    #expect(round.phase == .introducing)
    round.secondPassed()
    #expect(round.secondsLeft == 5)

    round.introduceNextLetter()
    #expect(round.introduced == [first.cells[0]])
    introduce(round)

    #expect(round.phase == .playing)
    #expect(round.found == [first])
    #expect(round.introduced.isEmpty)
  }

  @Test func onlyTheFirstLevelIntroducesAWord() throws {
    let run = try run()
    let first = try #require(run.round)
    introduce(first)
    find(first.board.placements[1], in: first)
    run.roundEnded()
    run.nextLevel()

    #expect(run.round?.level.number == 2)
    #expect(run.round?.phase == .playing)
  }

  @Test func aDragAlongAWordFindsItAndADragElsewhereDoesNot() throws {
    let round = try #require(try run().round)
    introduce(round)
    let second = round.board.placements[1]

    round.touch(second.cells[0])
    round.release()
    #expect(!round.found.contains(second))

    find(second, in: round)
    #expect(round.found.contains(second))
    #expect(round.selection.isEmpty)
  }

  @Test func findingEveryWordWinsAndTheSecondsLeftGoToTheScore() throws {
    let run = try run()
    let round = try #require(run.round)
    introduce(round)
    round.secondPassed()
    round.secondPassed()

    find(round.board.placements[1], in: round)
    run.roundEnded()

    #expect(round.phase == .won)
    #expect(run.score == 3)
    #expect(run.ending == nil)
  }

  @Test func theClockRunningOutLosesTheLevelAndEndsTheGame() throws {
    let run = try run()
    let round = try #require(run.round)
    introduce(round)

    for _ in 1...5 { round.secondPassed() }
    run.roundEnded()

    #expect(round.phase == .lost)
    #expect(round.secondsLeft == 0)
    #expect(run.ending == .timeUp)
    #expect(run.score == 0)
  }

  @Test func nothingCanBeFoundOnceTheLevelIsLost() throws {
    let round = try #require(try run().round)
    introduce(round)
    for _ in 1...5 { round.secondPassed() }

    find(round.board.placements[1], in: round)

    #expect(round.found.count == 1)
  }

  @Test func givingUpEndsTheGameWithTheScoreSoFar() throws {
    let run = try run()
    let round = try #require(run.round)
    introduce(round)
    find(round.board.placements[1], in: round)
    run.roundEnded()

    run.giveUp()

    #expect(run.ending == .gaveUp)
    #expect(run.score == 5)
  }

  @Test func theGameEndsWhenThePlanRunsOutOfLevels() throws {
    let run = try run(words: ["cat", "dog"])
    let round = try #require(run.round)
    introduce(round)
    find(round.board.placements[1], in: round)
    run.roundEnded()

    run.nextLevel()

    #expect(run.ending == .everyLevelPlayed)
  }

  @Test func theCountdownIntroducesThenRunsTheClockToTheEnd() async throws {
    let round = try #require(try run().round)
    let countdown = Countdown(introSecondsPerLetter: 0.3) { _ in await Task.yield() }

    await countdown.run(round)

    #expect(round.phase == .lost)
    #expect(round.found.count == 1)
  }
}
