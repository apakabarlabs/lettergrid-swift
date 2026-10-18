struct DiagonalLayoutBuilder {
  let columns: Int
  let minimumRows: Int
  let directions: [Direction]
  let downWords: ClosedRange<Int>

  func layout(for words: [String], using random: inout SeededRandom) -> Layout? {
    let indices = Array(words.indices)
    let others = directions.filter { $0 != .down }
    let forced = indices.filter { words[$0].count > columns || others.isEmpty }
    let maximum = directions.contains(.down) ? min(downWords.upperBound, words.count, columns) : 0
    guard forced.count <= maximum else { return nil }
    let minimum = min(max(downWords.lowerBound, forced.count), maximum)
    let optional = indices.filter { !forced.contains($0) }.shuffled(using: &random)
    let vertical = Set(
      forced + optional.prefix(Int.random(in: minimum...maximum, using: &random) - forced.count))
    var assigned: [Int: Direction] = [:]
    for index in indices {
      guard
        let direction = vertical.contains(index)
          ? Direction.down : others.randomElement(using: &random)
      else {
        return nil
      }
      assigned[index] = direction
    }
    var rows = max(minimumRows, words.map(\.count).max() ?? 0)
    var placed: [Placement] = []
    for index in indices.sorted(by: { words[$0].count > words[$1].count }) {
      guard let direction = assigned[index] else { fatalError("Every word needs a direction") }
      var choices = spots(for: words[index], direction: direction, rows: rows, beside: placed)
      while choices.isEmpty {
        rows += 1
        choices = spots(for: words[index], direction: direction, rows: rows, beside: placed)
      }
      let occupied = Set(placed.flatMap(\.cells))
      let crossing = choices.filter { !occupied.isDisjoint(with: $0.cells) }
      guard let chosen = (crossing.isEmpty ? choices : crossing).randomElement(using: &random)
      else {
        fatalError("A word needs at least one placement")
      }
      placed.append(chosen)
    }
    let ordered = words.compactMap { word in placed.first { $0.word == word } }
    let used = placed.flatMap(\.cells).map(\.row).max() ?? 0
    return Layout(rows: max(minimumRows, used + 1), placements: ordered)
  }

  private func spots(
    for word: String, direction: Direction, rows: Int, beside placed: [Placement]
  ) -> [Placement] {
    var letters: [Cell: Character] = [:]
    var parallel: Set<Cell> = []
    for placement in placed {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell] = letter
        if placement.direction == direction { parallel.insert(cell) }
      }
    }
    return (0..<rows).flatMap { row in
      (0..<columns).compactMap { column in
        let spot = Placement(
          word: word, start: Cell(row: row, column: column), direction: direction)
        let fits = zip(spot.cells, word).allSatisfy { cell, letter in
          (0..<rows).contains(cell.row) && (0..<columns).contains(cell.column)
            && !parallel.contains(cell) && (letters[cell].map { $0 == letter } ?? true)
        }
        return fits ? spot : nil
      }
    }
  }
}
