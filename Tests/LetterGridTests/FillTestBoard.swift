@testable import LetterGrid

enum FillTestBoard {
  static func make(words: [String], columns: Int = 5, rows: Int = 5, rowSpacing: Int = 2) -> Board {
    var letters = Array(repeating: Array(repeating: Character("X"), count: columns), count: rows)
    let placements = words.enumerated().map { index, word in
      let placement = Placement(
        word: word, start: Cell(row: index * rowSpacing, column: 0), direction: .right)
      for (cell, letter) in zip(placement.cells, word) { letters[cell.row][cell.column] = letter }
      return placement
    }
    return Board(letters: letters, placements: placements)
  }
}
