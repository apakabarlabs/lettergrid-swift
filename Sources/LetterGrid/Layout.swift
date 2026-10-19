struct Layout {
  let rows: Int
  let placements: [Placement]
}

struct LayoutBuilder {
  let columns: Int
  let minimumRows: Int
  let directions: [Direction]
  let downWords: ClosedRange<Int>
  var firstDirection: Direction?

  func lowestLayout(for words: [String], tries: Int, using random: inout SeededRandom) -> Layout? {
    var lowest: Layout?
    for _ in 0..<max(tries, 1) {
      guard let layout = layout(for: words, using: &random) else { return nil }
      if layout.rows < lowest?.rows ?? Int.max {
        lowest = layout
      }
    }
    return lowest
  }

  func layout(for words: [String], using random: inout SeededRandom) -> Layout? {
    if directions.contains(.downRight) || directions.contains(.downLeft) || firstDirection != nil {
      return DiagonalLayoutBuilder(
        columns: columns, minimumRows: minimumRows, directions: directions, downWords: downWords,
        firstDirection: firstDirection
      ).layout(for: words, using: &random)
    }
    let across = directions.contains(.right)
    let down = directions.contains(.down)
    let indices = Array(words.indices)
    let mustStand = indices.filter { !across || words[$0].count > columns }
    let mayLie = indices.filter { across && words[$0].count <= columns }
    let most = down ? min(downWords.upperBound, words.count, columns) : 0
    let fewest = max(downWords.lowerBound, mustStand.count)
    guard fewest <= most else { return nil }
    let shortestFirst = mayLie.shuffled(using: &random).sorted {
      words[$0].count < words[$1].count
    }
    let standing =
      mustStand
      + shortestFirst.prefix(Int.random(in: fewest...most, using: &random) - mustStand.count)
    let lying = mayLie.filter { !standing.contains($0) }

    var rows = max(minimumRows, standing.map { words[$0].count }.max() ?? 0)
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
