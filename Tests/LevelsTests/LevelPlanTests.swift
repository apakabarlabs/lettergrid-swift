import Testing
import WordGrid

@testable import Levels

struct LevelPlanTests {
  private let words = [
    "the", "there", "cat", "elephant", "dog", "house", "sun", "tree", "map", "pen", "ink", "box",
  ]

  private func configuration(clusterSize: Int = 1, columns: Ramp? = nil) throws
    -> GameConfiguration
  {
    try GameConfiguration(
      secondsPerLevel: 60,
      introSecondsPerLetter: 0.3,
      directions: [.right, .down],
      columns: columns ?? Ramp(first: 5, step: 1, every: 2, last: 7),
      rows: Ramp(first: 5, step: 1, every: 2, last: 7),
      wordsPerLevel: Ramp(first: 2, step: 1, every: 3, last: 4),
      minWordLength: 3,
      clusterSize: clusterSize,
      letters: ["a": 1, "e": 1, "x": 1]
    )
  }

  private func plan(clusterSize: Int = 1, seed: UInt64 = 3) throws -> LevelPlan {
    try LevelPlan(configuration: configuration(clusterSize: clusterSize), words: words, seed: seed)
  }

  @Test func rampsGrowEveryFewLevelsUpToTheLast() {
    let ramp = Ramp(first: 5, step: 1, every: 2, last: 7)

    #expect((1...7).map(ramp.value(at:)) == [5, 5, 6, 6, 7, 7, 7])
  }

  @Test func levelsTakeWordsFromTheMostFrequent() throws {
    let first = try #require(try plan().level(1))

    #expect(first.words.map(\.word) == ["the", "cat"])
    #expect(first.columns == 5)
    #expect(first.seconds == 60)
  }

  @Test func aWordInsideAnotherWaitsForALaterLevel() throws {
    let levels = try plan().levels
    let together = levels.contains { level in
      let chosen = level.words.map(\.word)
      return chosen.contains("the") && chosen.contains("there")
    }

    #expect(!together)
    #expect(levels.flatMap(\.words).contains { $0.word == "there" })
  }

  @Test func everyWordFitsTheGridOfItsLevel() throws {
    let levels = try plan().levels

    #expect(
      levels.allSatisfy { level in
        level.words.allSatisfy { $0.word.count <= max(level.columns, level.rows) }
      })
    #expect(!levels.flatMap(\.words).contains { $0.word == "elephant" })
  }

  @Test func wordsAreShuffledOnlyWithinTheirCluster() throws {
    let words = (1...40).map { "w\($0 < 10 ? "0" : "")\($0)" }
    let orders = try (1...5).map { seed in
      try LevelPlan(configuration: configuration(clusterSize: 10), words: words, seed: seed)
        .levels.flatMap(\.words).map(\.rank)
    }

    for order in orders {
      let clusters = order.map { ($0 - 1) / 10 }
      #expect(clusters == clusters.sorted())
    }
    #expect(Set(orders).count > 1)
  }

  @Test func thePlanEndsWhenALevelCannotBeFilled() throws {
    let configuration = try configuration()
    let levels = try plan().levels
    let used = levels.flatMap(\.words).map(\.word)

    #expect(Set(used).count == used.count)
    #expect(
      levels.allSatisfy { $0.words.count == configuration.wordsPerLevel.value(at: $0.number) })
  }

  @Test func everyLevelGetsABoard() throws {
    let plan = try plan()

    for level in plan.levels {
      let board = try plan.board(for: level)
      #expect(board.placements.count == level.words.count)
    }
  }

  @Test func theSameSeedGivesTheSameLevels() throws {
    let first = try plan(clusterSize: 4).levels
    let second = try plan(clusterSize: 4).levels

    #expect(first == second)
  }

  @Test func aBrokenConfigurationIsRefused() {
    #expect(throws: GameConfiguration.Failure.invalidRamp("columns")) {
      try configuration(columns: Ramp(first: 5, step: 1, every: 0, last: 7))
    }
  }

  @Test func theYAMLKeysFillEveryField() throws {
    let configuration = try GameConfiguration.decode(
      """
      seconds_per_level: 60
      intro_seconds_per_letter: 0.35
      directions: [right, down]
      columns: {first: 7, step: 1, every: 10, last: 9}
      rows: {first: 8, step: 0, every: 1, last: 8}
      words_per_level: {first: 5, step: 1, every: 20, last: 8}
      min_word_length: 3
      cluster_size: 50
      letters: {a: 8.2, b: 1.5}
      """)

    #expect(configuration.secondsPerLevel == 60)
    #expect(configuration.introSecondsPerLetter == 0.35)
    #expect(configuration.directions == [.right, .down])
    #expect(configuration.columns == Ramp(first: 7, step: 1, every: 10, last: 9))
    #expect(configuration.rows == Ramp(first: 8))
    #expect(configuration.wordsPerLevel == Ramp(first: 5, step: 1, every: 20, last: 8))
    #expect(configuration.minWordLength == 3)
    #expect(configuration.clusterSize == 50)
    #expect(configuration.letters == ["a": 8.2, "b": 1.5])
  }

  @Test func aDecodedConfigurationIsCheckedLikeABuiltOne() {
    #expect(throws: GameConfiguration.Failure.noDirections) {
      try GameConfiguration.decode(
        """
        seconds_per_level: 60
        intro_seconds_per_letter: 0.35
        directions: []
        columns: {first: 7, step: 0, every: 1, last: 7}
        rows: {first: 7, step: 0, every: 1, last: 7}
        words_per_level: {first: 5, step: 0, every: 1, last: 5}
        min_word_length: 3
        cluster_size: 50
        letters: {a: 1}
        """)
    }
  }
}
