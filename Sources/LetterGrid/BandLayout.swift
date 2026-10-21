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
    var (starts, row) = downStarts(for: words, directions: directions)
    for (index, word) in words.enumerated() where directions[index] != .down {
      let column = directions[index] == .downLeft ? word.count - 1 : 0
      starts[index] = Cell(row: row, column: column)
      row += (directions[index] == .right ? 1 : word.count) + 1
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
    let rows = letters.map { line in
      line.map { letter in
        letter ?? filler.orderedLetters(using: &random)[0]
      }
    }
    return Board(letters: rows, placements: placements)
  }

  private func downStarts(
    for words: [String], directions: [Direction]
  ) -> (starts: [Int: Cell], nextRow: Int) {
    let down = words.indices.filter { directions[$0] == .down }
    let perBand = (columns + 1) / 2
    var starts: [Int: Cell] = [:]
    var row = 0
    for band in stride(from: 0, to: down.count, by: perBand) {
      let indices = down[band..<min(band + perBand, down.count)]
      for (slot, index) in indices.enumerated() {
        starts[index] = Cell(row: row, column: slot * 2)
      }
      row += (indices.map { words[$0].count }.max() ?? 0) + 1
    }
    return (starts, row)
  }
}
