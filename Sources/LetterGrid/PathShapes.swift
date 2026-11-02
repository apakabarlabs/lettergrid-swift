struct PathShapes {
  private struct Search {
    var visited = 0
    var random: SeededRandom
    var shapes: [[Cell]] = []

    mutating func visit(upTo limit: Int?) -> Bool {
      guard let limit else { return true }
      guard visited < limit else { return false }
      visited += 1
      return true
    }
  }

  let columns: Int
  let length: Int
  let rule: WordRule
  var maximumShapes = Generation.settings.shapes.shapeLimit
  var maximumRows: Int?
  var visitedLimit: Int? = Generation.settings.shapes.visitLimit
  var randomized = true

  func cells(seed: UInt64 = 0) -> [[Cell]] {
    guard rule.isValid, length >= rule.minimumLength else { return [] }
    var shapes: [[Cell]] = []
    for direction in rule.startDirections {
      var search = Search(random: SeededRandom(seed: seed))
      let origin = Cell(row: 0, column: 0)
      var path = [origin]
      path.reserveCapacity(length)
      walk(&path, bounds: Bounds(origin), direction: direction, turns: 0, search: &search)
      shapes += search.shapes
    }
    return shapes
  }

  private struct Bounds {
    var top: Int
    var bottom: Int
    var left: Int
    var right: Int

    init(_ cell: Cell) {
      (top, bottom, left, right) = (cell.row, cell.row, cell.column, cell.column)
    }

    func including(_ cell: Cell) -> Bounds {
      var widened = self
      widened.top = min(top, cell.row)
      widened.bottom = max(bottom, cell.row)
      widened.left = min(left, cell.column)
      widened.right = max(right, cell.column)
      return widened
    }
  }

  private func walk(
    _ path: inout [Cell], bounds: Bounds, direction: Direction, turns: Int,
    search: inout Search
  ) {
    guard search.shapes.count < maximumShapes, search.visit(upTo: visitedLimit) else { return }
    guard length - path.count >= rule.turns - turns else { return }
    if path.count == length {
      guard turns == rule.turns else { return }
      search.shapes.append(
        path.map { Cell(row: $0.row - bounds.top, column: $0.column - bounds.left) })
      return
    }
    guard let last = path.last else { return }
    for way in directions(after: direction, count: path.count, turns: turns, search: &search) {
      let next = last.moved(way, by: 1)
      guard !path.contains(next) else { continue }
      let widened = bounds.including(next)
      guard widened.right - widened.left < columns else { continue }
      if let maximumRows {
        guard widened.bottom - widened.top < maximumRows else { continue }
      }
      path.append(next)
      walk(
        &path, bounds: widened, direction: way, turns: turns + (way == direction ? 0 : 1),
        search: &search)
      path.removeLast()
    }
  }

  private func directions(
    after direction: Direction, count: Int, turns: Int, search: inout Search
  ) -> [Direction] {
    let ways = [direction] + (count > 1 && turns < rule.turns ? direction.perpendiculars : [])
    return randomized ? search.random.shuffled(ways) : ways
  }
}
