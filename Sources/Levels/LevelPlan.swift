import WordGrid

public struct RankedWord: Equatable, Sendable {
  public let word: String
  public let rank: Int
}

public struct Level: Equatable, Sendable {
  public let number: Int
  public let columns: Int
  public let rows: Int
  public let seconds: Int
  public let words: [RankedWord]
}

public struct LevelPlan: Sendable {
  public let configuration: GameConfiguration
  public let levels: [Level]
  private let seed: UInt64
  private let filler: LetterWeights

  public init(configuration: GameConfiguration, words: [String], seed: UInt64) throws {
    self.configuration = configuration
    self.seed = seed
    self.filler = try configuration.filler()
    self.levels = Sequencer(configuration: configuration).levels(of: words, seed: seed)
  }

  public func level(_ number: Int) -> Level? {
    levels.indices.contains(number - 1) ? levels[number - 1] : nil
  }

  public func board(for level: Level) throws -> Board {
    let generator = BoardGenerator(
      columns: level.columns,
      rows: level.rows,
      directions: configuration.directions,
      filler: filler
    )
    return try generator.board(
      for: level.words.map(\.word), seed: seed &+ UInt64(level.number) &* 0x9E37_79B9)
  }

}

private struct Sequencer {
  let configuration: GameConfiguration

  func levels(of words: [String], seed: UInt64) -> [Level] {
    var queue = order(words, seed: seed)[...]
    var deferred: ArraySlice<RankedWord> = []
    var levels: [Level] = []
    while true {
      let number = levels.count + 1
      let columns = configuration.columns.value(at: number)
      let rows = configuration.rows.value(at: number)
      let longest = configuration.directions.map { $0 == .right ? columns : rows }.max() ?? 0
      let wanted = configuration.wordsPerLevel.value(at: number)
      var chosen: [RankedWord] = []
      var skipped: [RankedWord] = []
      while chosen.count < wanted, let next = deferred.popFirst() ?? queue.popFirst() {
        if next.word.count <= longest, !chosen.contains(where: { overlaps($0.word, next.word) }) {
          chosen.append(next)
        } else {
          skipped.append(next)
        }
      }
      deferred = skipped[...] + deferred
      guard chosen.count == wanted else { return levels }
      levels.append(
        Level(
          number: number,
          columns: columns,
          rows: rows,
          seconds: configuration.secondsPerLevel,
          words: chosen
        )
      )
    }
  }

  private func order(_ words: [String], seed: UInt64) -> [RankedWord] {
    var random = SeededRandom(seed: seed)
    let ranked = words.enumerated()
      .map { RankedWord(word: $0.element, rank: $0.offset + 1) }
      .filter { $0.word.count >= configuration.minWordLength }
    return stride(from: 0, to: ranked.count, by: configuration.clusterSize).flatMap { start in
      ranked[start..<min(start + configuration.clusterSize, ranked.count)].shuffled(using: &random)
    }
  }

  private func overlaps(_ first: String, _ second: String) -> Bool {
    first.contains(second) || second.contains(first)
  }
}
