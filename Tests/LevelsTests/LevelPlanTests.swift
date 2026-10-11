import Testing
import WordGrid

@testable import Levels

struct LevelPlanTests {
  private let yaml = """
    seconds_per_level: 60
    show_word_list: true
    directions: [right, down]
    columns: {first: 5, step: 1, every: 2, last: 7}
    rows: {first: 5, step: 1, every: 2, last: 7}
    words_per_level: {first: 2, step: 1, every: 3, last: 4}
    min_word_length: 3
    cluster_size: 1
    letters: {a: 1, e: 1, x: 1}
    """

  private let words = [
    "the", "there", "cat", "elephant", "dog", "house", "sun", "tree", "map", "pen", "ink", "box",
  ]

  private func configuration(clusterSize: Int = 1) throws -> GameConfiguration {
    try GameConfiguration.decode(
      yaml.replacingOccurrences(of: "cluster_size: 1", with: "cluster_size: \(clusterSize)"))
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
      try GameConfiguration.decode(
        yaml.replacingOccurrences(
          of: "columns: {first: 5, step: 1, every: 2, last: 7}",
          with: "columns: {first: 5, step: 1, every: 0, last: 7}")
      )
    }
  }
}
