struct BandLayout {
  let columns: Int
  let minimumRows: Int

  func board(
    for words: [String], directions assigned: [Int: Direction], filler: LetterWeights,
    using random: inout SeededRandom
  ) -> Board {
    let directions = words.indices.map { index in
      guard let direction = assigned[index] else { fatalError("Every word needs a direction") }
      return direction
    }
    var (starts, row) = uprightStarts(for: words, directions: directions)
    for (index, word) in words.enumerated() where !directions[index].isVertical {
      starts[index] = start(of: word, along: directions[index], from: Cell(row: row, column: 0))
      row += (directions[index].rowStep == 0 ? 1 : word.count) + 1
    }
    let placements = words.enumerated().map { index, word in
      guard let start = starts[index] else { fatalError("Every word needs a start") }
      return Placement(word: word, start: start, direction: directions[index])
    }
    var letters = Array(
      repeating: [Character?](repeating: nil, count: columns), count: max(minimumRows, row - 1))
    for placement in placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    let neighbours = LetterNeighbours(columns: columns, rows: letters.count)
    for row in letters.indices {
      for column in 0..<columns where letters[row][column] == nil {
        let counts = neighbours.counts(around: Cell(row: row, column: column)) {
          letters[$0.row][$0.column]
        }
        letters[row][column] = filler.orderedLetters(using: &random, neighbours: counts)[0]
      }
    }
    let rows = letters.map { line in
      line.map { letter in
        guard let letter else { fatalError("Every cell has been filled") }
        return letter
      }
    }
    return Board(letters: rows, placements: placements)
  }

  private func uprightStarts(
    for words: [String], directions: [Direction]
  ) -> (starts: [Int: Cell], nextRow: Int) {
    let upright = words.indices.filter { directions[$0].isVertical }
    let perBand = (columns + 1) / 2
    var starts: [Int: Cell] = [:]
    var row = 0
    for band in stride(from: 0, to: upright.count, by: perBand) {
      let indices = upright[band..<min(band + perBand, upright.count)]
      for (slot, index) in indices.enumerated() {
        starts[index] = start(
          of: words[index], along: directions[index], from: Cell(row: row, column: slot * 2))
      }
      row += (indices.map { words[$0].count }.max() ?? 0) + 1
    }
    return (starts, row)
  }

  private func start(of word: String, along direction: Direction, from corner: Cell) -> Cell {
    let far = word.count - 1
    return Cell(
      row: corner.row + (direction.rowStep < 0 ? far : 0),
      column: corner.column + (direction.columnStep < 0 ? far : 0))
  }
}
