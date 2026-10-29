struct PathSearch {
  private struct Visitor {
    let visit: (Placement) -> Bool
    let skips: (Int) -> Bool
  }
  private struct AllowedTurns {
    let direction: Direction
    let counts: Set<Int>
    var maximum: Int { counts.max() ?? 0 }
  }

  private struct Trail {
    var cells: [Cell] = []
    var visited: [Bool]
    var stopped = false
  }

  private struct Step {
    let direction: Direction
    let turns: Int
    let node: Int
  }

  let board: Board
  let rules: [WordRule]
  var maximumReadings = Int.max
  var letters: ((Cell) -> Character?)?

  func readings(in index: WordIndex) -> [Placement] {
    var found: Set<Placement> = []
    visitReadings(in: index) { placement in
      found.insert(placement)
      return found.count < maximumReadings
    }
    return Array(found)
  }

  func visitReadings(
    in index: WordIndex, skipping: @escaping (Int) -> Bool = { _ in false },
    _ visit: @escaping (Placement) -> Bool
  ) {
    guard index.longest > 0, maximumReadings > 0 else { return }
    let grouped = Direction.allCases.compactMap { direction -> AllowedTurns? in
      let counts = Set(
        rules.filter { $0.isValid && $0.startDirections.contains(direction) }.map(\.turns))
      return counts.isEmpty ? nil : AllowedTurns(direction: direction, counts: counts)
    }
    var trail = Trail(visited: Array(repeating: false, count: board.rows * board.columns))
    let visitor = Visitor(visit: visit, skips: skipping)
    trail.cells.reserveCapacity(min(index.longest, board.rows * board.columns))
    for rule in grouped {
      for row in 0..<board.rows {
        for column in 0..<board.columns {
          let start = Cell(row: row, column: column)
          guard let letter = letter(at: start),
            let node = index.next(after: 0, letter: letter), !visitor.skips(node)
          else {
            continue
          }
          enter(start, &trail)
          walk(
            Step(direction: rule.direction, turns: 0, node: node), rule: rule, index: index,
            trail: &trail, visitor: visitor)
          leave(&trail)
          if trail.stopped { return }
        }
      }
    }
  }

  private func walk(
    _ step: Step, rule: AllowedTurns, index: WordIndex, trail: inout Trail,
    visitor: Visitor
  ) {
    let (direction, turns, node) = (step.direction, step.turns, step.node)
    let length = trail.cells.count
    if rule.counts.contains(turns), let word = index.word(at: node) {
      let placement =
        length == 1
        ? Placement(word: word, start: trail.cells[0], direction: rule.direction)
        : Placement(word: word, cells: trail.cells)
      if !visitor.visit(placement) {
        trail.stopped = true
        return
      }
    }
    guard length < index.longest, let last = trail.cells.last else { return }
    let canTurn = length > 1 && turns < rule.maximum
    for way in [direction] + (canTurn ? direction.perpendiculars : []) {
      let next = last.moved(way, by: 1)
      guard board.contains(next), !trail.visited[slot(of: next)], let letter = letter(at: next),
        let child = index.next(after: node, letter: letter), !visitor.skips(child)
      else { continue }
      enter(next, &trail)
      walk(
        Step(direction: way, turns: turns + (way == direction ? 0 : 1), node: child),
        rule: rule, index: index, trail: &trail, visitor: visitor)
      leave(&trail)
      if trail.stopped { return }
    }
  }

  private func slot(of cell: Cell) -> Int { cell.row * board.columns + cell.column }

  private func letter(at cell: Cell) -> Character? {
    if let letters { return letters(cell) }
    return board[cell]
  }

  private func enter(_ cell: Cell, _ trail: inout Trail) {
    trail.cells.append(cell)
    trail.visited[slot(of: cell)] = true
  }

  private func leave(_ trail: inout Trail) {
    let cell = trail.cells.removeLast()
    trail.visited[slot(of: cell)] = false
  }
}

extension Board {
  func hasSingleOccurrence(of word: String, rules: [WordRule]) -> Bool {
    let palindrome = word == String(word.reversed())
    let readings = PathSearch(board: self, rules: rules, maximumReadings: palindrome ? 3 : 2)
      .readings(in: WordIndex([word]))
    guard let first = readings.first else { return false }
    return readings.allSatisfy {
      $0.cells == first.cells || (palindrome && $0.cells == Array(first.cells.reversed()))
    }
  }

  public func occurrences(of word: String, rules: [WordRule]) -> Int {
    let readings = PathSearch(board: self, rules: rules).readings(in: WordIndex([word]))
    var paths: Set<[Cell]> = []
    for reading in readings {
      if reading.isPalindrome, paths.contains(Array(reading.cells.reversed())) { continue }
      paths.insert(reading.cells)
    }
    return paths.count
  }

  public func strayWords(of dictionary: Set<String>, rules: [WordRule]) -> [String] {
    strayWords(in: WordIndex(dictionary), rules: rules)
  }

  func strayWords(in dictionary: WordIndex, rules: [WordRule]) -> [String] {
    PathSearch(board: self, rules: rules).readings(in: dictionary).filter { !covers($0) }
      .map(\.word).sorted()
  }

  func covers(_ reading: Placement) -> Bool {
    placements.contains { placement in
      placement.containsReading(reading.cells)
        || (placement.isPalindrome && placement.reversed.containsReading(reading.cells))
    }
  }
}

extension Placement {
  func containsReading(_ path: [Cell]) -> Bool {
    guard path.count <= cells.count else { return false }
    return (0...(cells.count - path.count)).contains { offset in
      Array(cells[offset..<(offset + path.count)]) == path
    }
  }
}
