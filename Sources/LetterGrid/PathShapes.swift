struct PathShapes {
  private struct Search {
    var visited = 0
    var random: SeededRandom
  }

  let columns: Int
  let length: Int
  let rule: WordRule
  var maximumShapes = 256

  func cells(seed: UInt64 = 0) -> [[Cell]] {
    guard rule.isValid, length >= rule.minimumLength else { return [] }
    var shapes: [[Cell]] = []
    for direction in rule.startDirections {
      var directed: [[Cell]] = []
      var search = Search(random: SeededRandom(seed: seed))
      walk(
        [Cell(row: 0, column: 0)], direction: direction, turns: 0,
        shapes: &directed, search: &search)
      shapes += directed
    }
    return shapes
  }

  private func walk(
    _ path: [Cell], direction: Direction, turns: Int,
    shapes: inout [[Cell]], search: inout Search
  ) {
    guard shapes.count < maximumShapes, search.visited < 100_000 else { return }
    search.visited += 1
    guard length - path.count >= rule.turns - turns else { return }
    if path.count == length {
      guard turns == rule.turns else { return }
      let row = path.map(\.row).min() ?? 0
      let column = path.map(\.column).min() ?? 0
      shapes.append(path.map { Cell(row: $0.row - row, column: $0.column - column) })
      return
    }
    guard let last = path.last else { return }
    let ways = [direction] + (path.count > 1 && turns < rule.turns ? direction.perpendiculars : [])
    for way in ways.shuffled(using: &search.random) {
      let next = last.moved(way, by: 1)
      guard !path.contains(next) else { continue }
      let columnsUsed = path.map(\.column) + [next.column]
      guard (columnsUsed.max() ?? 0) - (columnsUsed.min() ?? 0) < columns else { continue }
      walk(
        path + [next], direction: way, turns: turns + (way == direction ? 0 : 1),
        shapes: &shapes, search: &search)
    }
  }
}
