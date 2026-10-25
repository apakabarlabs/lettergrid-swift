struct PathSearch {
  private struct AllowedTurns {
    let direction: Direction
    let counts: Set<Int>
    var maximum: Int { counts.max() ?? 0 }
  }

  private struct Cursor {
    let cells: [Cell]
    let direction: Direction
    let turns: Int
    let node: Int
  }

  let board: Board
  let rules: [WordRule]
  var maximumReadings = Int.max

  func readings(in index: WordIndex) -> [Placement] {
    guard index.longest > 0 else { return [] }
    var found: Set<Placement> = []
    let grouped = Direction.allCases.compactMap { direction -> AllowedTurns? in
      let counts = Set(
        rules.filter { $0.isValid && $0.startDirections.contains(direction) }.map(\.turns))
      return counts.isEmpty ? nil : AllowedTurns(direction: direction, counts: counts)
    }
    for rule in grouped {
      for row in 0..<board.rows {
        for column in 0..<board.columns {
          let start = Cell(row: row, column: column)
          guard let node = index.next(after: 0, letter: board[start]) else { continue }
          walk(
            Cursor(cells: [start], direction: rule.direction, turns: 0, node: node),
            rule: rule, index: index, found: &found)
        }
      }
    }
    return Array(found)
  }

  private func walk(
    _ cursor: Cursor, rule: AllowedTurns, index: WordIndex, found: inout Set<Placement>
  ) {
    guard found.count < maximumReadings else { return }
    let cells = cursor.cells
    let turns = cursor.turns
    let direction = cursor.direction
    if rule.counts.contains(turns), let word = index.word(at: cursor.node) {
      let placement =
        cells.count == 1
        ? Placement(word: word, start: cells[0], direction: rule.direction)
        : Placement(word: word, cells: cells)
      found.insert(placement)
    }
    guard cells.count < index.longest, let last = cells.last else { return }
    let ways =
      [direction] + (cells.count > 1 && turns < rule.maximum ? direction.perpendiculars : [])
    for way in ways {
      let next = last.moved(way, by: 1)
      guard board.contains(next), !cells.contains(next),
        let child = index.next(after: cursor.node, letter: board[next])
      else { continue }
      walk(
        Cursor(
          cells: cells + [next], direction: way,
          turns: turns + (way == direction ? 0 : 1), node: child),
        rule: rule, index: index, found: &found)
    }
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
    PathSearch(board: self, rules: rules).readings(in: dictionary).filter { reading in
      !placements.contains { placement in
        placement.containsReading(reading.cells)
          || (placement.isPalindrome && placement.reversed.containsReading(reading.cells))
      }
    }.map(\.word).sorted()
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
