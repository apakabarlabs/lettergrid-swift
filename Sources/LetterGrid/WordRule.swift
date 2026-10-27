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

  public func canFit(length: Int, columns: Int, maximumRows: Int? = nil) -> Bool {
    guard isValid, length >= minimumLength, columns > 0 else { return false }
    if let maximumRows {
      guard maximumRows > 0, (length - 1) / columns < maximumRows else { return false }
    }
    return !PathShapes(
      columns: columns, length: length, rule: self, maximumShapes: 1,
      maximumRows: maximumRows, visitedLimit: nil, randomized: false
    ).cells().isEmpty
  }

  public static func minimumTurns(
    toFit length: Int, startDirections: [Direction], columns: Int, maximumRows: Int? = nil
  ) -> Int? {
    supportedTurns.first {
      WordRule(startDirections: startDirections, turns: $0)
        .canFit(length: length, columns: columns, maximumRows: maximumRows)
    }
  }

  public static let supportedTurns = 0...3

  public var isValid: Bool { !startDirections.isEmpty && Self.supportedTurns.contains(turns) }
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
