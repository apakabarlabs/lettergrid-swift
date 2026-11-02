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

  public func board(seed: UInt64) -> Board {
    guard let runFree else {
      preconditionFailure("A request leaves preparation with its run-free fallback")
    }
    guard
      let candidate = RunFreeFill(
        board: targets(seed: seed), weights: runFree.weights, rules: generator.rules,
        conditionalCharacters: runFree.symbols
      ).filled(seed: seed)
    else { return runFree.board }
    return candidate.hasAddedEqualPair && !runFree.board.hasAddedEqualPair
      ? runFree.board : candidate
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
