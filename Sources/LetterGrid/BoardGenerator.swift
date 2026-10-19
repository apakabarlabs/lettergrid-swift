import Foundation

public struct BoardGenerator: Sendable {
  public enum Failure: LocalizedError, Equatable {
    case noRoom(words: [String], columns: Int, rows: Int)

    public var errorDescription: String? {
      switch self {
      case .noRoom(let words, let columns, let rows):
        "No clean grid \(columns) wide and at least \(rows) high holds "
          + words.joined(separator: ", ")
      }
    }
  }

  public let columns: Int
  public let rows: Int
  public let directions: [Direction]
  public let filler: LetterWeights
  public let dictionary: Set<String>
  public let downWords: ClosedRange<Int>
  public let layoutsPerAttempt: Int
  public let attempts: Int
  public let fillsPerAttempt: Int
  private let wordIndex: WordIndex

  public init(
    columns: Int, rows: Int, directions: [Direction], filler: LetterWeights,
    dictionary: Set<String> = [], downWords: ClosedRange<Int> = 0...Int.max,
    layoutsPerAttempt: Int = 40, attempts: Int = 200, fillsPerAttempt: Int = 20
  ) {
    self.columns = columns
    self.rows = rows
    self.directions = directions
    self.filler = filler
    self.dictionary = Set(dictionary.map { $0.uppercased() })
    self.wordIndex = WordIndex(self.dictionary)
    self.downWords = downWords
    self.layoutsPerAttempt = layoutsPerAttempt
    self.attempts = attempts
    self.fillsPerAttempt = fillsPerAttempt
  }

  public func board(
    for words: [String], seed: UInt64, firstDirection: Direction? = nil
  ) throws -> Board {
    let words = words.map { $0.uppercased() }
    guard Set(words).count == words.count, words.allSatisfy({ $0.count > 1 }) else {
      throw Failure.noRoom(words: words, columns: columns, rows: rows)
    }
    let builder = LayoutBuilder(
      columns: columns, minimumRows: rows, directions: directions, downWords: downWords,
      firstDirection: firstDirection)
    var random = SeededRandom(seed: seed)
    let targets = WordIndex(Set(words))
    for _ in 0..<attempts {
      guard
        let layout = builder.lowestLayout(
          for: words, tries: layoutsPerAttempt, using: &random)
      else { break }
      let filler = BoardFiller(
        layout: layout, columns: columns, directions: directions,
        dictionary: wordIndex, targets: targets)
      guard
        let board = filler.fill(with: self.filler, attempts: fillsPerAttempt, using: &random)
      else { continue }
      if isClean(board, hiding: words) { return board }
    }
    throw Failure.noRoom(words: words, columns: columns, rows: rows)
  }

  private func isClean(_ board: Board, hiding words: [String]) -> Bool {
    words.allSatisfy { board.occurrences(of: $0, along: directions) == 1 }
      && board.strayWords(of: dictionary, along: directions).isEmpty
  }
}
