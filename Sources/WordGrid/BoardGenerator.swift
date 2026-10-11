public struct BoardGenerator: Sendable {
  public enum Failure: Error, Equatable {
    case noRoom(words: [String], columns: Int, rows: Int)
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
    self.downWords = downWords
    self.layoutsPerAttempt = layoutsPerAttempt
    self.attempts = attempts
    self.fillsPerAttempt = fillsPerAttempt
  }

  public func board(for words: [String], seed: UInt64) throws -> Board {
    let words = words.map { $0.uppercased() }
    let builder = LayoutBuilder(
      columns: columns, minimumRows: rows, directions: directions, downWords: downWords)
    var random = SeededRandom(seed: seed)
    for _ in 0..<attempts {
      guard
        let layout = builder.lowestLayout(
          for: words, tries: layoutsPerAttempt, using: &random)
      else { break }
      for _ in 0..<fillsPerAttempt {
        let board = Board(
          letters: filled(layout, by: &random), placements: layout.placements)
        if isClean(board, hiding: words) {
          return board
        }
      }
    }
    throw Failure.noRoom(words: words, columns: columns, rows: rows)
  }

  private func isClean(_ board: Board, hiding words: [String]) -> Bool {
    words.allSatisfy { board.occurrences(of: $0, along: directions) == 1 }
      && board.strayWords(of: dictionary, along: directions).isEmpty
  }

  private func filled(_ layout: Layout, by random: inout SeededRandom) -> [[Character]] {
    var letters = (0..<layout.rows).map { _ in
      (0..<columns).map { _ in filler.letter(using: &random) }
    }
    for placement in layout.placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    return letters
  }
}
