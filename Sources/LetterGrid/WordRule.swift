public struct WordRule: Hashable, Sendable {
  public let startDirections: [Direction]
  public let turns: Int

  public init(startDirections: [Direction], turns: Int = 0) {
    self.startDirections = startDirections
    self.turns = turns
  }

  public func matches(_ cells: [Cell]) -> Bool {
    guard isValid, let geometry = PathGeometry(cells), startDirections.contains(geometry.direction)
    else {
      return false
    }
    return geometry.turns == turns
  }

  public func matches(_ placement: Placement) -> Bool { matches(placement.cells) }

  public var isValid: Bool { !startDirections.isEmpty && (0...3).contains(turns) }
  public var minimumLength: Int { isValid ? turns + 2 : Int.max }
}

struct PathGeometry {
  let direction: Direction
  let turns: Int

  init?(_ cells: [Cell]) {
    guard cells.count > 1, Set(cells).count == cells.count else { return nil }
    let steps = zip(cells, cells.dropFirst()).compactMap { Direction.between($0, $1) }
    guard steps.count == cells.count - 1, let first = steps.first else { return nil }
    var turns = 0
    for (previous, next) in zip(steps, steps.dropFirst()) where previous != next {
      guard previous.perpendiculars.contains(next) else { return nil }
      turns += 1
    }
    self.direction = first
    self.turns = turns
  }
}

extension Direction {
  var perpendiculars: [Direction] {
    Direction.allCases.filter { $0.rowStep * rowStep + $0.columnStep * columnStep == 0 }
  }

  static func between(_ start: Cell, _ end: Cell) -> Direction? {
    allCases.first {
      let row = start.row.addingReportingOverflow($0.rowStep)
      let column = start.column.addingReportingOverflow($0.columnStep)
      return !row.overflow && !column.overflow
        && end.row == row.partialValue && end.column == column.partialValue
    }
  }
}
