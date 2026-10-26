struct Layout: Equatable, Sendable {
  let rows: Int
  let placements: [Placement]

  var sharedCells: Int {
    let cells = placements.flatMap(\.cells)
    return cells.count - Set(cells).count
  }
}

struct LayoutBuilder {
  let columns: Int
  let minimumRows: Int
  let directions: [Direction]
  let downWords: ClosedRange<Int>
  var firstDirection: Direction?
  var maximumRows: Int?

  func lowestLayout(for words: [String], tries: Int, using random: inout SeededRandom) -> Layout? {
    var lowest: Layout?
    for _ in 0..<max(tries, 1) {
      guard let layout = layout(for: words, using: &random) else {
        if maximumRows != nil { continue }
        return nil
      }
      if lowest.map({
        layout.rows < $0.rows || (layout.rows == $0.rows && layout.sharedCells > $0.sharedCells)
      }) ?? true {
        lowest = layout
      }
    }
    return lowest
  }

  func layout(for words: [String], using random: inout SeededRandom) -> Layout? {
    let assignment = DirectionAssignment(
      columns: columns, directions: directions, downWords: downWords,
      firstDirection: firstDirection)
    if !assignment.usesForwardOrthogonalLayout {
      return DiagonalLayoutBuilder(
        columns: columns, minimumRows: minimumRows, directions: directions, downWords: downWords,
        firstDirection: firstDirection, maximumRows: maximumRows
      ).layout(for: words, using: &random)
    }
    guard let assigned = assignment.assignments(for: words, using: &random, order: .shortestFirst)
    else { return nil }
    let indices = Array(words.indices)
    let standing = assigned.filter(\.direction.isVertical).map(\.index)
    let lying = assigned.filter { !$0.direction.isVertical }.map(\.index)

    var rows = max(minimumRows, standing.map { words[$0].count }.max() ?? 0)
    guard maximumRows.map({ rows <= $0 }) ?? true else { return nil }
    var placed: [Int: Placement] = [:]
    let standingColumns = Array(0..<columns).shuffled(using: &random)
    for (index, column) in zip(standing, standingColumns) {
      let word = words[index]
      let row = Int.random(in: 0...(rows - word.count), using: &random)
      placed[index] = Placement(word: word, start: Cell(row: row, column: column), direction: .down)
    }
    for index in lying.sorted(by: { words[$0].count > words[$1].count }) {
      var spots = self.spots(for: words[index], rows: rows, beside: placed)
      while spots.isEmpty {
        if let maximumRows, rows >= maximumRows { return nil }
        rows += 1
        spots = self.spots(for: words[index], rows: rows, beside: placed)
      }
      placed[index] = spots.randomElement(using: &random)
    }
    for index in lying.shuffled(using: &random) {
      let others = placed.filter { $0.key != index }
      let crossing = spots(for: words[index], rows: rows, beside: others).filter { spot in
        !crossings(of: spot, with: others).isEmpty
      }
      if let spot = crossing.randomElement(using: &random) {
        placed[index] = spot
      }
    }
    let used = placed.values.flatMap(\.cells).map(\.row).max() ?? 0
    return Layout(
      rows: max(minimumRows, used + 1), placements: indices.compactMap { placed[$0] })
  }

  private func spots(for word: String, rows: Int, beside placed: [Int: Placement]) -> [Placement] {
    guard word.count <= columns else { return [] }
    var letters: [Cell: Character] = [:]
    var lying: Set<Cell> = []
    for placement in placed.values {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell] = letter
        if placement.direction == .right { lying.insert(cell) }
      }
    }
    return (0..<rows).flatMap { row in
      (0...(columns - word.count)).compactMap { column -> Placement? in
        let spot = Placement(word: word, start: Cell(row: row, column: column), direction: .right)
        let fits = zip(spot.cells, word).allSatisfy { cell, letter in
          !lying.contains(cell) && letters[cell].map { $0 == letter } ?? true
        }
        return fits ? spot : nil
      }
    }
  }

  private func crossings(of spot: Placement, with placed: [Int: Placement]) -> Set<Cell> {
    let standing = Set(placed.values.filter { $0.direction == .down }.flatMap(\.cells))
    return Set(spot.cells).intersection(standing)
  }
}
