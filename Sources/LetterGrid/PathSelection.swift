extension Board {
  public func selection(extending cells: [Cell], toward end: Cell, rules: [WordRule]) -> [Cell] {
    guard let last = cells.last, contains(end) else { return cells }
    if rules.allSatisfy({ $0.turns == 0 }), let start = cells.first {
      let directions = Direction.allCases.filter { way in
        rules.contains { $0.startDirections.contains(way) }
      }
      return selection(from: start, toward: end, along: directions)
    }
    if let index = cells.firstIndex(of: end) { return Array(cells.prefix(index + 1)) }
    if let firstSegment = firstSegmentSelection(cells, toward: end, rules: rules) {
      return firstSegment
    }
    let ways: [Direction]
    if cells.count == 1 {
      ways = Array(Set(rules.flatMap(\.startDirections))).sorted { $0.rawValue < $1.rawValue }
    } else {
      guard let geometry = PathGeometry(cells),
        let direction = Direction.between(cells[cells.count - 2], last)
      else { return cells }
      let canTurn = rules.contains {
        $0.startDirections.contains(geometry.direction) && geometry.turns < $0.turns
      }
      ways = [direction] + (canTurn ? direction.perpendiculars : [])
    }
    return continuedSelection(cells, toward: end, along: ways)
  }

  private func firstSegmentSelection(
    _ cells: [Cell], toward end: Cell, rules: [WordRule]
  ) -> [Cell]? {
    guard let geometry = PathGeometry(cells), geometry.turns == 0, let start = cells.first else {
      return nil
    }
    let starts = Direction.allCases.filter { way in
      rules.contains { $0.startDirections.contains(way) }
    }
    let straight = selection(from: start, toward: end, along: starts)
    let canTurn = rules.contains {
      $0.startDirections.contains(geometry.direction) && $0.turns > 0
    }
    guard canTurn else { return straight }
    let turned = continuedSelection(
      cells, toward: end,
      along: [geometry.direction] + geometry.direction.perpendiculars)
    return distance(straight, to: end) < distance(turned, to: end) ? straight : turned
  }

  private func distance(_ cells: [Cell], to end: Cell) -> Double {
    guard let last = cells.last else { return .infinity }
    let row = Double(last.row) - Double(end.row)
    let column = Double(last.column) - Double(end.column)
    return row * row + column * column
  }

  private func continuedSelection(
    _ cells: [Cell], toward end: Cell, along ways: [Direction]
  ) -> [Cell] {
    guard let last = cells.last else { return cells }
    let continuation = selection(from: last, toward: end, along: ways).dropFirst()
    var extended = cells
    for cell in continuation {
      guard !extended.contains(cell) else { break }
      extended.append(cell)
    }
    return extended
  }
}
