import Levels
import Testing
import WordGrid

@testable import Game

@MainActor
struct GameTests {
  private let words = ["cat", "dog", "sun", "map", "pen", "box", "hat", "cup"].map {
    WordEntry(word: $0)
  }

  private func configuration(seconds: Int? = nil) throws -> GameConfiguration {
    try GameConfiguration(
      steps: [GridStep(columns: 6, rows: 6, words: 2, levels: nil, seconds: seconds)],
      directions: [.right, .down],
      minVerticalWords: 0,
      maxVerticalWords: 2,
      minWordLength: 3,
      clusterSize: 1,
      letters: ["q": 1, "x": 1, "z": 1],
      introSecondsPerLetter: 0.3,
      pointsPerLetter: 1,
      hintCost: 2,
      rejectionSeconds: 2.5
    )
  }

  private func plan(words: [WordEntry]? = nil, seconds: Int? = nil, seed: UInt64 = 7) throws
    -> LevelPlan
  {
    try LevelPlan(
      configuration: configuration(seconds: seconds), words: words ?? self.words, seed: seed)
  }

  private func game(
    words: [WordEntry]? = nil, seconds: Int? = nil, snapshot: GameSnapshot? = nil,
    events: EventLog = EventLog()
  ) throws -> GameRun {
    let plan = try plan(words: words, seconds: seconds)
    return GameRun(
      plan: plan, snapshot: snapshot ?? GameSnapshot(seed: plan.seed),
      record: { events.entries.append($0) }, changed: { events.changes += 1 })
  }

  private func find(_ placement: Placement, in game: GameRun) {
    game.touch(placement.cells[0])
    game.drag(to: placement.cells[placement.cells.count - 1])
    game.release()
  }

  private func introduce(_ game: GameRun) {
    while game.round?.phase == .introducing {
      game.introduceNextLetter()
    }
  }

  @Test func theFirstLevelShowsItsFirstWordLetterByLetterAndCountsIt() throws {
    let events = EventLog()
    let game = try game(events: events)
    let round = try #require(game.round)
    let first = round.board.placements[0]

    #expect(round.phase == .introducing)
    #expect(round.showsFirstWord)
    game.introduceNextLetter()
    #expect(round.introduced == [first.cells[0]])
    introduce(game)

    #expect(round.phase == .playing)
    #expect(round.found == [first])
    #expect(game.score == first.word.count)
    #expect(game.known == [first.word])
    #expect(events.entries == [.word(first.word, points: first.word.count)])
  }

  @Test func onlyTheFirstLevelIntroducesAWord() throws {
    let game = try game()
    introduce(game)
    find(try #require(game.round).board.placements[1], in: game)
    game.nextLevel()

    #expect(game.round?.level.number == 2)
    #expect(game.round?.phase == .playing)
    #expect(game.round?.showsFirstWord == false)
  }

  @Test func aWordBringsAPointForEachOfItsLetters() throws {
    let events = EventLog()
    let game = try game(events: events)
    introduce(game)
    let second = try #require(game.round).board.placements[1]

    find(second, in: game)

    #expect(game.round?.phase == .won)
    #expect(game.score == 6)
    #expect(events.entries.last == .word(second.word, points: 3))
  }

  @Test func aDragOverNoWordIsRejectedUntilTheNextTouch() throws {
    let game = try game()
    introduce(game)
    let round = try #require(game.round)
    let second = round.board.placements[1]
    let wrong = second.cells.dropLast().map { $0 }

    game.touch(wrong[0])
    game.drag(to: wrong[wrong.count - 1])
    game.release()
    #expect(round.rejected == wrong)
    #expect(!round.found.contains(second))

    game.touch(second.cells[0])
    #expect(round.rejected.isEmpty)
  }

  @Test func aTapIsNotRejected() throws {
    let game = try game()
    introduce(game)
    let round = try #require(game.round)

    game.touch(round.board.placements[1].cells[0])
    game.release()

    #expect(round.rejected.isEmpty)
  }

  @Test func aRejectionFadesAway() throws {
    let game = try game()
    introduce(game)
    let round = try #require(game.round)
    let cells = Array(round.board.placements[1].cells.dropLast())
    game.touch(cells[0])
    game.drag(to: cells[cells.count - 1])
    game.release()

    game.clearRejection()

    #expect(round.rejected.isEmpty)
  }

  @Test func aHintOpensTheFirstLetterOfTheFirstUnopenedWordForItsCost() throws {
    let events = EventLog()
    let game = try game(events: events)
    introduce(game)
    let second = try #require(game.round).board.placements[1]

    #expect(game.canUseHint)
    game.useHint()

    #expect(game.round?.revealed[second] == 1)
    #expect(game.score == 1)
    #expect(events.entries.last == .hint(points: -2))
  }

  @Test func aHintNeedsEnoughPoints() throws {
    let game = try game()
    introduce(game)
    game.useHint()

    #expect(!game.canUseHint)
    game.useHint()
    #expect(game.score == 1)
  }

  @Test func theHintsLeftAreThePointsOverTheCostOfAHint() throws {
    let game = try game(snapshot: GameSnapshot(seed: 7, levelNumber: 2, score: 96))

    #expect(game.hintsLeft == 48)
    game.useHint()
    #expect(game.hintsLeft == 47)
  }

  @Test func withoutAClockALevelCannotBeLost() throws {
    let game = try game()
    introduce(game)

    for _ in 1...100 { game.secondPassed() }

    #expect(game.round?.phase == .playing)
    #expect(game.round?.secondsLeft == nil)
  }

  @Test func withAClockRunningOutLosesTheLevelAndEndsTheGame() throws {
    let game = try game(seconds: 5)
    introduce(game)

    for _ in 1...5 { game.secondPassed() }

    #expect(game.round?.phase == .lost)
    #expect(game.ending == .timeUp)
  }

  @Test func startingOverResetsTheScoreAndTheLevelButNotTheKnownWords() throws {
    let events = EventLog()
    let game = try game(events: events)
    introduce(game)
    find(try #require(game.round).board.placements[1], in: game)
    game.nextLevel()
    let known = game.known

    game.startOver(with: try plan(seed: 99))

    #expect(game.score == 0)
    #expect(game.round?.level.number == 1)
    #expect(game.round?.phase == .introducing)
    #expect(game.known == known)
    #expect(events.entries.last == .newGame)
  }

  @Test func theNewGameIsRecordedOnceTheFirstLevelOfTheNewPlanIsOpen() throws {
    let game = try game()
    introduce(game)
    find(try #require(game.round).board.placements[1], in: game)
    game.nextLevel()
    var snapshotAtNewGame: GameSnapshot?
    game.record = { event in
      if event == .newGame { snapshotAtNewGame = game.snapshot }
    }

    game.startOver(with: try plan(seed: 99))

    #expect(snapshotAtNewGame == GameSnapshot(seed: 99))
  }

  @Test func aSnapshotKeepsTheSecondsLeft() throws {
    let game = try game(seconds: 5)
    introduce(game)
    for _ in 1...2 { game.secondPassed() }

    let resumed = try self.game(seconds: 5, snapshot: game.snapshot)

    #expect(resumed.round?.secondsLeft == 3)
    #expect(resumed.round?.phase == .playing)
  }

  @Test func aLostLevelStaysLostAfterResuming() throws {
    let game = try game(seconds: 5)
    introduce(game)
    for _ in 1...5 { game.secondPassed() }

    let resumed = try self.game(seconds: 5, snapshot: game.snapshot)

    #expect(resumed.round?.phase == .lost)
    #expect(resumed.ending == .timeUp)
  }

  @Test func onlyWhatTheSnapshotHoldsCountsAsAChange() throws {
    let events = EventLog()
    let game = try game(events: events)
    introduce(game)
    let afterIntroduction = events.changes
    let round = try #require(game.round)
    let wrong = Array(round.board.placements[1].cells.dropLast())

    game.touch(wrong[0])
    game.drag(to: wrong[wrong.count - 1])
    game.release()
    game.secondPassed()
    #expect(events.changes == afterIntroduction)

    find(round.board.placements[1], in: game)
    #expect(events.changes == afterIntroduction + 1)
  }

  @Test func eachSecondOfAClockIsAChange() throws {
    let events = EventLog()
    let game = try game(seconds: 5, events: events)
    introduce(game)
    let afterIntroduction = events.changes

    game.secondPassed()

    #expect(events.changes == afterIntroduction + 1)
  }

  @Test func aSnapshotResumesTheLevelWithItsFoundWordsAndHints() throws {
    let game = try game()
    introduce(game)
    game.useHint()
    let snapshot = game.snapshot

    let resumed = try self.game(snapshot: snapshot)

    #expect(resumed.round?.phase == .playing)
    #expect(resumed.round?.found.map(\.word) == game.round?.found.map(\.word))
    #expect(resumed.round?.revealed.values.first == 1)
    #expect(resumed.score == game.score)
    #expect(resumed.hintsLeft == game.hintsLeft)
  }

  @Test func theGameEndsWhenThePlanRunsOutOfLevels() throws {
    let game = try game(words: Array(words.prefix(2)))
    introduce(game)
    find(try #require(game.round).board.placements[1], in: game)

    game.nextLevel()

    #expect(game.ending == .everyLevelPlayed)
  }

  @Test func theCountdownIntroducesAndThenStopsWithoutAClock() async throws {
    let game = try game()
    let countdown = Countdown { _ in await Task.yield() }

    await countdown.run(game)

    #expect(game.round?.phase == .playing)
    #expect(game.round?.found.count == 1)
  }

  @Test func theCountdownRunsAClockToItsEnd() async throws {
    let game = try game(seconds: 3)
    let countdown = Countdown { _ in await Task.yield() }

    await countdown.run(game)

    #expect(game.ending == .timeUp)
  }
}

@MainActor
final class EventLog {
  var entries: [ScoreEvent] = []
  var changes = 0
}
