struct BandLayout {
  let columns: Int
  let minimumRows: Int

  func board(
    for words: [String], directions assigned: [Int: Direction], filler: LetterWeights,
    using random: inout SeededRandom
  ) -> Board {
    var placements: [Placement] = []
    var row = 0
    for (index, word) in words.enumerated() {
      guard let direction = assigned[index] else { fatalError("Every word needs a direction") }
      let column = direction == .downLeft ? word.count - 1 : 0
      placements.append(
        Placement(word: word, start: Cell(row: row, column: column), direction: direction))
      row += (direction == .right ? 1 : word.count) + 1
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
}
