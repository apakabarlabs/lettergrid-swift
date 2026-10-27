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
}
