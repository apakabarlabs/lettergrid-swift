public struct BoardDictionary: Sendable {
  public let words: Set<String>
  let index: WordIndex

  public init(_ words: Set<String>) {
    self.words = Set(words.map(\.cellUppercased))
    index = WordIndex(self.words)
  }
}
