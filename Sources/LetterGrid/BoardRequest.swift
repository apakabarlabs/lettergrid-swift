public struct BoardRequest: Equatable, Sendable {
  public let words: [String]
  public let firstDirection: Direction?
  public let firstRule: WordRule?
  let pathLayout: Layout?
  let boundedFallback: Layout?
  private let generator: BoardGenerator
  private let conditionalCharacters: Set<Character>
  private let conditionalFallback: Board?

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
    completed(generator.board(for: self, seed: seed, dictionary: dictionary), seed: seed)
  }

  public func board(seed: UInt64, dictionary: BoardDictionary) -> Board {
    completed(generator.board(for: self, seed: seed, dictionary: dictionary), seed: seed)
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
