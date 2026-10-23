struct LetterNeighbours {
  let columns: Int
  let rows: Int

  func counts(around cell: Cell, letterAt: (Cell) -> Character?) -> [Character: Int] {
    var counts: [Character: Int] = [:]
    for rowStep in -1...1 {
      for columnStep in -1...1 where rowStep != 0 || columnStep != 0 {
        let neighbour = Cell(row: cell.row + rowStep, column: cell.column + columnStep)
        guard (0..<rows).contains(neighbour.row), (0..<columns).contains(neighbour.column) else {
          continue
        }
        if let letter = letterAt(neighbour) {
          counts[letter, default: 0] += 1
        }
      }
    }
    return counts
  }
}
