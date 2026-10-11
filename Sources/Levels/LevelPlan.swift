import WordGrid

public struct RankedWord: Equatable, Sendable {
  public let word: String
  public let rank: Int
}

public struct Level: Equatable, Sendable {
  public let number: Int
  public let columns: Int
  public let rows: Int
  public let seconds: Int?
  public let words: [RankedWord]
}

public struct LevelPlan: Sendable {
  public let configuration: GameConfiguration
  public let levels: [Level]
  public let playable: [String]
  public let seed: UInt64
  private let filler: LetterWeights
  private let dictionary: Set<String>

  public init(configuration: GameConfiguration, words: [WordEntry], seed: UInt64) throws {
    self.configuration = configuration
    self.seed = seed
    self.filler = try configuration.filler()
    let spellings = words.filter {
      $0.isOneWord && $0.word.count >= configuration.minWordLength
    }.map(\.spelling)
    var seen: Set<String> = []
    self.playable = spellings.filter { seen.insert($0).inserted }
    self.dictionary = Set(spellings)
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
      filler: filler,
      dictionary: dictionary,
      limits: [.down: configuration.minVerticalWords...configuration.maxVerticalWords]
    )
    return try generator.board(
      for: level.words.map(\.word), seed: seed &+ UInt64(level.number) &* 0x9E37_79B9)
  }

}

private struct Sequencer {
  let configuration: GameConfiguration

  func levels(of words: [WordEntry], seed: UInt64) -> [Level] {
    var queue = order(words, seed: seed)[...]
    var deferred: ArraySlice<RankedWord> = []
    var levels: [Level] = []
    while let step = configuration.step(at: levels.count + 1) {
      let number = levels.count + 1
      let wanted = step.words
      var chosen: [RankedWord] = []
      var acrossOnly: [RankedWord] = []
      var downOnly: [RankedWord] = []
      var skipped: [RankedWord] = []
      while chosen.count < wanted, let next = deferred.popFirst() ?? queue.popFirst() {
        let shortest = step.columns - configuration.minVerticalWords
        let shortAcross = acrossOnly.filter { $0.word.count <= shortest }.count
        let owedShort = configuration.minVerticalWords - downOnly.count - shortAcross
        let mustBeShort = owedShort >= wanted - chosen.count
        let across =
          configuration.directions.contains(.right)
          && next.word.count <= step.columns - downOnly.count
          && (!mustBeShort || next.word.count <= shortest)
        let down =
          !across && configuration.directions.contains(.down)
          && downOnly.count < configuration.maxVerticalWords
          && acrossOnly.allSatisfy { $0.word.count < step.columns - downOnly.count }
        if across || down, !chosen.contains(where: { overlaps($0.word, next.word) }) {
          chosen.append(next)
          if across { acrossOnly.append(next) } else { downOnly.append(next) }
        } else {
          skipped.append(next)
        }
      }
      deferred = skipped[...] + deferred
      guard chosen.count == wanted else { return levels }
      levels.append(
        Level(
          number: number,
          columns: step.columns,
          rows: max(step.rows, downOnly.map(\.word.count).max() ?? 0),
          seconds: step.seconds,
          words: chosen
        )
      )
    }
    return levels
  }

  private func order(_ words: [WordEntry], seed: UInt64) -> [RankedWord] {
    var random = SeededRandom(seed: seed)
    var seen: Set<String> = []
    let ranked = words.enumerated()
      .filter { $0.element.isOneWord && $0.element.word.count >= configuration.minWordLength }
      .filter { seen.insert($0.element.spelling).inserted }
      .map { RankedWord(word: $0.element.spelling, rank: $0.offset + 1) }
    return stride(from: 0, to: ranked.count, by: configuration.clusterSize).flatMap { start in
      ranked[start..<min(start + configuration.clusterSize, ranked.count)].shuffled(using: &random)
    }
  }

  private func overlaps(_ first: String, _ second: String) -> Bool {
    first.contains(second) || second.contains(first)
  }
}
