enum ConditionalFill {
  static func adding(
    _ characters: Set<Character>, to board: Board, rules: [WordRule], seed: UInt64
  ) -> Board? {
    let required = characters.intersection(Set(board.placements.map(\.word).joined()))
      .sorted { String($0) < String($1) }
    guard !required.isEmpty else { return board }
    let occupied = Set(board.placements.flatMap(\.cells))
    let available = (0..<board.rows).flatMap { row in
      (0..<board.columns).map { Cell(row: row, column: $0) }
    }.filter { !occupied.contains($0) }
    guard available.count >= required.count else { return nil }
    var random = SeededRandom(seed: seed)
    for _ in 0..<64 {
      var letters = board.letters
      for (character, cell) in zip(required, available.shuffled(using: &random)) {
        letters[cell.row][cell.column] = character
      }
      let filled = Board(letters: letters, placements: board.placements)
      if filled.placements.allSatisfy({ filled.hasSingleOccurrence(of: $0.word, rules: rules) }) {
        return filled
      }
    }
    return nil
  }

  static func decoys(
    _ characters: Set<Character>, beside layout: Layout, columns: Int, rules: [WordRule],
    seed: UInt64
  ) -> [Cell: Character]? {
    let (placements, rows) = (layout.placements, layout.rows)
    let used = Set(placements.map(\.word).joined())
    let required = characters.intersection(used).sorted { String($0) < String($1) }
    guard !required.isEmpty else { return [:] }
    guard
      let blank = (0xE000...0xF8FF).lazy.compactMap(Unicode.Scalar.init).map(Character.init)
        .first(where: { !used.contains($0) })
    else { return nil }
    var letters = Array(repeating: Array(repeating: blank, count: columns), count: rows)
    for placement in placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    let occupied = Set(placements.flatMap(\.cells))
    var random = SeededRandom(seed: seed)
    var search = DecoySearch(
      required: required, placements: placements, rules: rules, blank: blank,
      free: (0..<rows).flatMap { row in (0..<columns).map { Cell(row: row, column: $0) } }
        .filter { !occupied.contains($0) }.shuffled(using: &random),
      letters: letters)
    return search.place(at: 0) ? search.chosen : nil
  }
}

private struct DecoySearch {
  let required: [Character]
  let placements: [Placement]
  let rules: [WordRule]
  let blank: Character
  let free: [Cell]
  var letters: [[Character]]
  var chosen: [Cell: Character] = [:]

  mutating func place(at index: Int) -> Bool {
    guard index < required.count else {
      let board = Board(letters: letters, placements: placements)
      return placements.allSatisfy { board.hasSingleOccurrence(of: $0.word, rules: rules) }
    }
    for cell in free where chosen[cell] == nil {
      chosen[cell] = required[index]
      letters[cell.row][cell.column] = required[index]
      if place(at: index + 1) { return true }
      chosen[cell] = nil
      letters[cell.row][cell.column] = blank
    }
    return false
  }
}
