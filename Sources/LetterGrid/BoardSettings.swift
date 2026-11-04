public struct BoardSize: Equatable, Sendable {
  public let columns: Int
  public let rows: Int
  public let maxRows: Int?

  public init(columns: Int, rows: Int, maxRows: Int? = nil) {
    self.columns = columns
    self.rows = rows
    self.maxRows = maxRows
  }
}

public struct Filler: Equatable, Sendable {
  public let weights: LetterWeights
  public let conditionalCharacters: Set<Character>

  public init(weights: LetterWeights, conditionalCharacters: Set<Character> = []) {
    self.weights = weights
    self.conditionalCharacters = Set(conditionalCharacters.map(\.cellUppercased))
  }
}

public struct PlacementLimits: Equatable, Sendable {
  public let downWords: ClosedRange<Int>
  public let maxWordsPerDirection: Int?

  public init(downWords: ClosedRange<Int> = 0...Int.max, maxWordsPerDirection: Int? = nil) {
    self.downWords = downWords
    self.maxWordsPerDirection = maxWordsPerDirection
  }
}

public struct RoundOptions: Equatable, Sendable {
  public let seconds: Int?
  public let introduces: Bool
  public let hintOrder: HintOrder

  public init(seconds: Int? = nil, introduces: Bool = false, hintOrder: HintOrder = .fromStart) {
    self.seconds = seconds
    self.introduces = introduces
    self.hintOrder = hintOrder
  }
}

extension WordRule {
  public static func straight(_ directions: [Direction]) -> WordRule {
    WordRule(startDirections: directions)
  }
}
