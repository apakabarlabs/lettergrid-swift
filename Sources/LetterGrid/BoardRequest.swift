public struct BoardRequest: Equatable, Sendable {
  private struct RunFreeFallback: Equatable, Sendable {
    let board: Board
    let weights: LetterWeights
    let symbols: Set<Character>
  }

  public let words: [String]
  public let firstDirection: Direction?
  public var firstRule: WordRule? { leadingRules.first }
  public let leadingRules: [WordRule]
  public var maxWordsPerDirection: Int? { generator.maxWordsPerDirection }
  let layout: Layout
  private let generator: BoardGenerator
  private var runFree: RunFreeFallback?

  init(
    words: [String], firstDirection: Direction?, generator: BoardGenerator,
    leadingRules: [WordRule],
    layout: Layout
  ) {
    self.words = words
    self.firstDirection = firstDirection
    self.generator = generator
    self.leadingRules = leadingRules
    self.layout = layout
  }

  public func board(seed: UInt64, dictionary: Set<String>? = nil) -> Board {
    board(
      seed: seed, dictionary: dictionary.map(BoardDictionary.init) ?? generator.preparedDictionary)
  }

  public func board(seed: UInt64, dictionary: BoardDictionary) -> Board {
    guard let runFree else {
      preconditionFailure("A request leaves preparation with its run-free fallback")
    }
    let index = dictionary.index
    guard
      let candidate = RunFreeFill(
        board: targets(seed: seed), weights: runFree.weights, rules: generator.rules,
        conditionalCharacters: runFree.symbols, dictionary: index
      ).filled(seed: seed)
    else { return runFree.board }
    let pairs = candidate.hasAddedEqualPair
    let fallbackPairs = runFree.board.hasAddedEqualPair
    if pairs != fallbackPairs { return pairs ? runFree.board : candidate }
    let noise = candidate.strayWordCount(in: index, rules: generator.rules)
    guard noise > 0 else { return candidate }
    let fallbackNoise = runFree.board.strayWordCount(
      in: index, rules: generator.rules, lessThan: noise)
    return fallbackNoise < noise ? runFree.board : candidate
  }

  func targets(seed: UInt64) -> Board {
    generator.targets(for: self, seed: seed)
  }

  func avoidingRuns(fallback: Board, weights: LetterWeights, symbols: Set<Character>) -> Self {
    var request = self
    request.runFree = RunFreeFallback(board: fallback, weights: weights, symbols: symbols)
    return request
  }
}
