extension Character {
  static func privateUse(avoiding used: Set<Character>) -> Character? {
    (0xE000...0xF8FF).lazy.compactMap(Unicode.Scalar.init).map(Character.init)
      .first(where: { !used.contains($0) })
  }
}

extension Sequence<Placement> {
  func letters(columns: Int, rows: Int, blank: Character) -> [[Character]] {
    letters(columns: columns, rows: rows, empty: blank) { $0 }
  }

  func letters(columns: Int, rows: Int) -> [[Character?]] {
    letters(columns: columns, rows: rows, empty: nil) { $0 }
  }

  private func letters<Letter>(
    columns: Int, rows: Int, empty: Letter, _ letter: (Character) -> Letter
  ) -> [[Letter]] {
    var letters = Array(repeating: Array(repeating: empty, count: columns), count: rows)
    for placement in self {
      for (cell, character) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter(character)
      }
    }
    return letters
  }
}

extension [WordRule] {
  var startDirections: [Direction] {
    Direction.allCases.filter { way in contains { $0.startDirections.contains(way) } }
  }

  var startDirectionsInOrder: [Direction] {
    var ordered: [Direction] = []
    for rule in self {
      for way in rule.startDirections where !ordered.contains(way) { ordered.append(way) }
    }
    return ordered
  }
}
