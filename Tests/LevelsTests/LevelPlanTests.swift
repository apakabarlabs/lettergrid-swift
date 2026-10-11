import Testing
import WordGrid

@testable import Levels

struct LevelPlanTests {
  private let words = [
    "the", "there", "cat", "elephant", "dog", "house", "sun", "tree", "map", "pen", "ink", "box",
  ].map { WordEntry(word: $0) }

  private let growingSteps = [
    GridStep(columns: 5, rows: 5, words: 2, levels: 1),
    GridStep(columns: 6, rows: 6, words: 3, levels: 2, seconds: 45),
    GridStep(columns: 7, rows: 7, words: 4, levels: nil),
  ]

  private func configuration(
    steps: [GridStep]? = nil, clusterSize: Int = 1, minVerticalWords: Int = 0,
    maxVerticalWords: Int = 1
  ) throws -> GameConfiguration {
    try GameConfiguration(
      steps: steps ?? growingSteps,
      directions: [.right, .down],
      minVerticalWords: minVerticalWords,
      maxVerticalWords: maxVerticalWords,
      minWordLength: 3,
      clusterSize: clusterSize,
      letters: ["a": 1, "e": 1, "x": 1],
      introSecondsPerLetter: 0.3,
      pointsPerLetter: 1,
      hintCost: 2,
      hintsPerLevel: 2,
      rejectionSeconds: 2.5
    )
  }

  private func plan(words: [WordEntry]? = nil, clusterSize: Int = 1, seed: UInt64 = 3) throws
    -> LevelPlan
  {
    try LevelPlan(
      configuration: configuration(clusterSize: clusterSize), words: words ?? self.words, seed: seed
    )
  }

  @Test func eachStepHoldsItsLevelsAndTheLastOneHoldsTheRest() throws {
    let configuration = try configuration()

    #expect((1...6).map { configuration.step(at: $0)?.columns } == [5, 6, 6, 7, 7, 7])
    #expect(configuration.step(at: 2)?.seconds == 45)
    #expect(configuration.step(at: 4)?.seconds == nil)
  }

  @Test func levelsFollowTheirStep() throws {
    let levels = try plan().levels

    #expect(levels.map(\.columns).prefix(3) == [5, 6, 6])
    #expect(levels.map(\.words.count).prefix(3) == [2, 3, 3])
    #expect(levels[0].seconds == nil)
    #expect(levels[1].seconds == 45)
  }

  @Test func levelsTakeWordsFromTheMostFrequent() throws {
    let first = try #require(try plan().level(1))

    #expect(first.words.map(\.word) == ["THE", "CAT"])
    #expect(first.words.map(\.rank) == [1, 3])
  }

  @Test func onlyOneWordSpellingsLongEnoughGoOnTheBoard() throws {
    let words = [
      WordEntry(word: "a, an"), WordEntry(word: "go"), WordEntry(word: "ice cream"),
      WordEntry(word: "T-shirt"), WordEntry(word: "o’clock"),
      WordEntry(word: "bank", sense: "money"),
      WordEntry(word: "bank", sense: "river"), WordEntry(word: "May"), WordEntry(word: "may"),
      WordEntry(word: "cat"),
    ]
    let placed = try plan(words: words).levels.flatMap(\.words)

    #expect(placed.map(\.word) == ["BANK", "MAY", "CAT"])
    #expect(placed.map(\.rank) == [6, 8, 10])
  }

  @Test func aWordInsideAnotherWaitsForALaterLevel() throws {
    let levels = try plan().levels
    let together = levels.contains { level in
      let chosen = level.words.map(\.word)
      return chosen.contains("THE") && chosen.contains("THERE")
    }

    #expect(!together)
    #expect(levels.flatMap(\.words).contains { $0.word == "THERE" })
  }

  @Test func aWordWiderThanTheGridStretchesItsBoardDown() throws {
    let plan = try plan()
    let level = try #require(plan.levels.first { $0.words.contains { $0.word == "ELEPHANT" } })
    let board = try plan.board(for: level)

    #expect(board.columns == level.columns)
    #expect(board.rows >= 8)
  }

  @Test func everyPlayableWordLandsOnExactlyOneLevel() throws {
    let long = ["elephants", "umbrellas", "computers", "telephone", "breakfast", "chocolate"]
    let short = ["cat", "dog", "sun", "map", "pen", "box", "hat"]
    let words = (short + long).map { WordEntry(word: $0) }
    let steps = [GridStep(columns: 7, rows: 7, words: 5, levels: nil)]
    let plan = try LevelPlan(
      configuration: configuration(steps: steps, minVerticalWords: 2, maxVerticalWords: 3),
      words: words, seed: 2)
    let placed = plan.levels.flatMap(\.words).map(\.word)

    #expect(placed.sorted() == plan.playable.sorted())
    for level in plan.levels {
      #expect(try plan.board(for: level).placements.count == level.words.count)
    }
  }

  @Test func aLevelHoldsNoMoreWordsWiderThanTheGridThanMayStandDown() throws {
    let long = ["elephants", "umbrellas", "computers", "telephone", "breakfast", "chocolate"]
    let words = (long + ["cat", "dog", "sun", "map", "pen", "box", "hat", "cup", "bed", "car"])
      .map { WordEntry(word: $0) }
    let steps = [GridStep(columns: 5, rows: 5, words: 4, levels: nil)]
    let levels = try LevelPlan(
      configuration: configuration(steps: steps, maxVerticalWords: 2), words: words, seed: 1
    ).levels

    #expect(levels.flatMap(\.words).filter { $0.word.count > 5 }.count == long.count)
    #expect(levels.allSatisfy { level in level.words.filter { $0.word.count > 5 }.count <= 2 })
  }

  @Test func aBoardStandsDownBetweenTheFewestAndTheMostWordsAllowed() throws {
    let steps = [GridStep(columns: 7, rows: 7, words: 5, levels: nil)]
    let plan = try LevelPlan(
      configuration: configuration(steps: steps, minVerticalWords: 2, maxVerticalWords: 3),
      words: words, seed: 5)

    #expect(!plan.levels.isEmpty)
    for level in plan.levels {
      let board = try plan.board(for: level)
      #expect((2...3).contains(board.placements.filter { $0.direction == .down }.count))
    }
  }

  @Test func moreVerticalWordsRequiredThanAllowedIsRefused() {
    #expect(throws: GameConfiguration.Failure.fewerAllowedThanRequired("vertical_words")) {
      try configuration(minVerticalWords: 3, maxVerticalWords: 2)
    }
  }

  @Test func wordsAreShuffledOnlyWithinTheirCluster() throws {
    let letters = Array("abcdefghij")
    let words = (0..<60).map { WordEntry(word: "w\(letters[$0 / 10])\(letters[$0 % 10])") }
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

  @Test func onlyTheLastLevelsHoldFewerWordsThanTheirStep() throws {
    let configuration = try configuration()
    let levels = try plan().levels
    let short = levels.filter { $0.words.count < configuration.step(at: $0.number)?.words ?? 0 }

    #expect(short.allSatisfy { $0.number > levels.count - configuration.maxVerticalWords - 1 })
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

  @Test func anEndlessStepMustBeTheLast() {
    #expect(throws: GameConfiguration.Failure.endlessStepBeforeTheLast) {
      try configuration(steps: [
        GridStep(columns: 5, rows: 5, words: 2, levels: nil),
        GridStep(columns: 6, rows: 6, words: 3, levels: 2),
      ])
    }
  }

  @Test func aStepWithoutWordsIsRefused() {
    #expect(throws: GameConfiguration.Failure.notPositive("words")) {
      try configuration(steps: [GridStep(columns: 5, rows: 5, words: 0, levels: nil)])
    }
  }

  @Test func theYAMLKeysFillEveryField() throws {
    let configuration = try GameConfiguration.decode(
      """
      steps:
      - {columns: 4, rows: 4, words: 2, levels: 1}
      - {columns: 7, rows: 8, words: 5, seconds: 60}
      directions: [right, down]
      min_vertical_words: 1
      max_vertical_words: 2
      min_word_length: 3
      cluster_size: 50
      letters: {a: 8.2, b: 1.5}
      intro_seconds_per_letter: 0.35
      points_per_letter: 1
      hint_cost: 2
      hints_per_level: 3
      rejection_seconds: 2.5
      """)

    #expect(
      configuration.steps == [
        GridStep(columns: 4, rows: 4, words: 2, levels: 1),
        GridStep(columns: 7, rows: 8, words: 5, levels: nil, seconds: 60),
      ])
    #expect(configuration.directions == [.right, .down])
    #expect(configuration.minVerticalWords == 1)
    #expect(configuration.maxVerticalWords == 2)
    #expect(configuration.minWordLength == 3)
    #expect(configuration.clusterSize == 50)
    #expect(configuration.letters == ["a": 8.2, "b": 1.5])
    #expect(configuration.introSecondsPerLetter == 0.35)
    #expect(configuration.pointsPerLetter == 1)
    #expect(configuration.hintCost == 2)
    #expect(configuration.hintsPerLevel == 3)
    #expect(configuration.rejectionSeconds == 2.5)
  }

  @Test func aDecodedConfigurationIsCheckedLikeABuiltOne() {
    #expect(throws: GameConfiguration.Failure.noDirections) {
      try GameConfiguration.decode(
        """
        steps:
        - {columns: 4, rows: 4, words: 2}
        directions: []
        min_vertical_words: 0
        max_vertical_words: 2
        min_word_length: 3
        cluster_size: 50
        letters: {a: 1}
        intro_seconds_per_letter: 0.35
        points_per_letter: 1
        hint_cost: 2
        hints_per_level: 2
        rejection_seconds: 2.5
        """)
    }
  }

  @Test func theWordListReadsEveryField() throws {
    let list = try WordList.decode(
      """
      words:
      - word: bank
        sense: river
        grammar: n. B1
        level: B1
      - word: ice cream
        grammar: n. A1
        level: A1
      """)

    #expect(
      list.words == [
        WordEntry(word: "bank", sense: "river", grammar: "n. B1", level: "B1"),
        WordEntry(word: "ice cream", grammar: "n. A1", level: "A1"),
      ])
  }
}
