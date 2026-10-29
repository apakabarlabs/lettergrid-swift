enum ConditionalFill {
  static func roomForDecoys(
    _ characters: Set<Character>, beside layout: Layout, columns: Int, rules: [WordRule],
    budget: inout Int
  ) -> PathPacking.Completion {
    let (placements, rows) = (layout.placements, layout.rows)
    let used = Set(placements.map(\.word).joined())
    let required = characters.intersection(used).sorted { $0.precedesInCodePoints($1) }
    guard !required.isEmpty else { return .fits }
    guard
      let blank = (0xE000...0xF8FF).lazy.compactMap(Unicode.Scalar.init).map(Character.init)
        .first(where: { !used.contains($0) })
    else { return .doesNotFit }
    var letters = Array(repeating: Array(repeating: blank, count: columns), count: rows)
    for placement in placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    let occupied = Set(placements.flatMap(\.cells))
    var random = SeededRandom(seed: 0)
    var search = DecoySearch(
      required: required, placements: placements, rules: rules, blank: blank,
      free: random.shuffled(
        (0..<rows).flatMap { row in (0..<columns).map { Cell(row: row, column: $0) } }
          .filter { !occupied.contains($0) }),
      letters: letters, budget: budget)
    let found = search.place(at: 0)
    budget = search.budget
    if found { return .fits }
    return search.budget < 0 ? .ranOut : .doesNotFit
  }
}

private struct DecoySearch {
  let required: [Character]
  let placements: [Placement]
  let rules: [WordRule]
  let blank: Character
  let free: [Cell]
  var letters: [[Character]]
  var budget: Int
  var chosen: Set<Cell> = []

  mutating func place(at index: Int) -> Bool {
    guard index < required.count else {
      let board = Board(letters: letters, placements: placements)
      return placements.allSatisfy { board.hasSingleOccurrence(of: $0.word, rules: rules) }
    }
    for cell in free where !chosen.contains(cell) {
      budget -= 1
      guard budget >= 0 else { return false }
      chosen.insert(cell)
      letters[cell.row][cell.column] = required[index]
      if place(at: index + 1) { return true }
      chosen.remove(cell)
      letters[cell.row][cell.column] = blank
      if budget < 0 { return false }
    }
    return false
  }
}
