public struct BoardRequest: Equatable, Sendable {
  private enum FillPolicy: Equatable, Sendable {
    case original
    case avoidingRuns(fallback: Board, weights: LetterWeights, symbols: Set<Character>)
  }

  public let words: [String]
  public let firstDirection: Direction?
  public let firstRule: WordRule?
  let pathLayout: Layout?
  let boundedFallback: Layout?
  private let generator: BoardGenerator
  private let conditionalCharacters: Set<Character>
  private let conditionalFallback: Board?
  private var fillPolicy = FillPolicy.original

  init(
    words: [String], firstDirection: Direction?, generator: BoardGenerator,
    firstRule: WordRule? = nil, pathLayout: Layout? = nil, boundedFallback: Layout? = nil,
    conditionalCharacters: Set<Character> = [], conditionalFallback: Board? = nil
  ) {
    self.words = words
    self.firstDirection = firstDirection
    self.generator = generator
    self.firstRule = firstRule
    self.pathLayout = pathLayout
    self.boundedFallback = boundedFallback
    self.conditionalCharacters = conditionalCharacters
    self.conditionalFallback = conditionalFallback
  }

  public func board(seed: UInt64, dictionary: Set<String>? = nil) -> Board {
    if case .original = fillPolicy {
      return completed(generator.board(for: self, seed: seed, dictionary: dictionary), seed: seed)
    }
    return board(
      seed: seed, dictionary: dictionary.map(BoardDictionary.init) ?? generator.preparedDictionary)
  }

  public func board(seed: UInt64, dictionary: BoardDictionary) -> Board {
    avoidingRuns(
      completed(generator.board(for: self, seed: seed, dictionary: dictionary), seed: seed),
      seed: seed, dictionary: dictionary.index)
  }

  func avoidingRuns(fallback: Board, weights: LetterWeights, symbols: Set<Character>) -> Self {
    var request = self
    request.fillPolicy = .avoidingRuns(fallback: fallback, weights: weights, symbols: symbols)
    return request
  }

  private func avoidingRuns(_ board: Board, seed: UInt64, dictionary: WordIndex) -> Board {
    switch fillPolicy {
    case .original:
      return board
    case .avoidingRuns(let fallback, let weights, let symbols):
      guard
        let candidate = RunFreeFill(
          board: board, weights: weights, rules: generator.rules, conditionalCharacters: symbols,
          dictionary: dictionary
        ).filled(seed: seed)
      else { return fallback }
      let pairs = candidate.hasAddedEqualPair
      let fallbackPairs = fallback.hasAddedEqualPair
      if pairs != fallbackPairs { return pairs ? fallback : candidate }
      let noise = candidate.strayWordCount(in: dictionary, rules: generator.rules)
      guard noise > 0 else { return candidate }
      let fallbackNoise = fallback.strayWordCount(
        in: dictionary, rules: generator.rules, lessThan: noise)
      return fallbackNoise < noise ? fallback : candidate
    }
  }

  func requiring(_ characters: Set<Character>, fallback: Board) -> Self {
    Self(
      words: words, firstDirection: firstDirection, generator: generator,
      firstRule: firstRule, pathLayout: pathLayout, boundedFallback: boundedFallback,
      conditionalCharacters: characters, conditionalFallback: fallback)
  }

  private func completed(_ board: Board, seed: UInt64) -> Board {
    guard !conditionalCharacters.isEmpty else { return board }
    let filled = ConditionalFill.adding(
      conditionalCharacters, to: board, rules: generator.rules, seed: seed)
    if let filled { return filled }
    guard let conditionalFallback else {
      preconditionFailure("A conditional fill retains a checked fallback.")
    }
    return conditionalFallback
  }
}
