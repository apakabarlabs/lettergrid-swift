struct FillWordCheck {
  private let board: Board
  private let index: WordIndex
  private let rules: [WordRule]
  private let directions: [Direction]?
  private let fixedIsClean: Bool

  init(board: Board, index: WordIndex, rules: [WordRule], fixed: [[Character?]]) {
    self.board = board
    self.index = index
    self.rules = rules
    let directions = Direction.allCases.filter { direction in
      rules.contains { $0.isValid && $0.turns == 0 && $0.startDirections.contains(direction) }
    }
    let straight = rules.allSatisfy { !$0.isValid || $0.turns == 0 }
    let incremental =
      straight && Self.fitsVisitLimit(board: board, directions: directions, longest: index.longest)
    if incremental {
      self.directions = directions
      fixedIsClean = Self.isClean(board: board, index: index, rules: rules, letters: fixed)
    } else {
      self.directions = nil
      fixedIsClean = true
    }
  }

  func isClean(filling changed: Cell, letters: [[Character?]]) -> Bool {
    guard index.longest > 0 else { return true }
    guard let directions else {
      return Self.isClean(board: board, index: index, rules: rules, letters: letters)
    }
    guard fixedIsClean else { return false }
    for direction in directions {
      for distance in 0..<index.longest {
        let start = changed.moved(direction, by: -distance)
        guard board.contains(start) else { break }
        if !isClean(from: start, direction: direction, through: distance, letters: letters) {
          return false
        }
      }
    }
    return true
  }

  private func isClean(
    from start: Cell, direction: Direction, through distance: Int, letters: [[Character?]]
  ) -> Bool {
    var cell = start
    var node: Int? = 0
    var length = 0
    while board.contains(cell), let letter = letters[cell.row][cell.column] {
      node = index.next(after: node, letter: letter)
      guard node != nil else { break }
      length += 1
      if length > distance, index.word(at: node) != nil { return false }
      guard length < index.longest else { break }
      cell = cell.moved(direction, by: 1)
    }
    return true
  }

  private static func isClean(
    board: Board, index: WordIndex, rules: [WordRule], letters: [[Character?]]
  ) -> Bool {
    index.longest == 0
      || board.strayWordCount(
        in: index, rules: rules, lessThan: 1, letters: { letters[$0.row][$0.column] }) == 0
  }

  private static func fitsVisitLimit(board: Board, directions: [Direction], longest: Int) -> Bool {
    guard longest > 0, !directions.isEmpty else { return true }
    guard board.rows > 0, board.columns > 0 else { return false }
    var available = NoiseSearch.maximumVisits
    let longestLine = min(longest, max(board.rows, board.columns))
    for factor in [board.rows, board.columns, directions.count, longestLine] {
      guard factor <= available else { return false }
      available /= factor
    }
    return true
  }
}
