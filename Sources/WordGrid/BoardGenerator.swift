public struct BoardGenerator: Sendable {
  public enum Failure: Error, Equatable {
    case noRoom(words: [String], columns: Int, rows: Int)
  }

  public let columns: Int
  public let rows: Int
  public let directions: [Direction]
  public let filler: LetterWeights
  public let attempts: Int

  public init(
    columns: Int, rows: Int, directions: [Direction], filler: LetterWeights, attempts: Int = 200
  ) {
    self.columns = columns
    self.rows = rows
    self.directions = directions
    self.filler = filler
    self.attempts = attempts
  }

  public func board(for words: [String], seed: UInt64) throws -> Board {
    let words = words.map { $0.uppercased() }
    var random = SeededRandom(seed: seed)
    for _ in 0..<attempts {
      guard let placements = place(words, using: &random) else { continue }
      let board = Board(letters: filled(placements, by: &random), placements: placements)
      if words.allSatisfy({ board.occurrences(of: $0, along: directions) == 1 }) {
        return board
      }
    }
    throw Failure.noRoom(words: words, columns: columns, rows: rows)
  }

  private func place(_ words: [String], using random: inout SeededRandom) -> [Placement]? {
    var taken: [Cell: Character] = [:]
    var placements: [Placement] = []
    for word in words.sorted(by: { $0.count > $1.count }) {
      let fitting = candidates(for: word).filter { placement in
        zip(placement.cells, word).allSatisfy { cell, letter in
          taken[cell].map { $0 == letter } ?? true
        }
      }
      guard let placement = fitting.randomElement(using: &random) else { return nil }
      for (cell, letter) in zip(placement.cells, word) {
        taken[cell] = letter
      }
      placements.append(placement)
    }
    let order = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1, $0) })
    return placements.sorted { order[$0.word, default: 0] < order[$1.word, default: 0] }
  }

  private func candidates(for word: String) -> [Placement] {
    directions.flatMap { direction in
      let lastRow = rows - 1 - (word.count - 1) * direction.rowStep
      let lastColumn = columns - 1 - (word.count - 1) * direction.columnStep
      guard lastRow >= 0, lastColumn >= 0 else { return [Placement]() }
      return (0...lastRow).flatMap { row in
        (0...lastColumn).map { column in
          Placement(word: word, start: Cell(row: row, column: column), direction: direction)
        }
      }
    }
  }

  private func filled(_ placements: [Placement], by random: inout SeededRandom) -> [[Character]] {
    var letters = (0..<rows).map { _ in (0..<columns).map { _ in filler.letter(using: &random) } }
    for placement in placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    return letters
  }
}
