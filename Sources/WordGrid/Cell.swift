public struct Cell: Hashable, Sendable {
  public let row: Int
  public let column: Int

  public init(row: Int, column: Int) {
    self.row = row
    self.column = column
  }

  func moved(_ direction: Direction, by distance: Int) -> Cell {
    Cell(row: row + direction.rowStep * distance, column: column + direction.columnStep * distance)
  }
}

public enum Direction: String, CaseIterable, Sendable, Decodable {
  case right
  case down

  var rowStep: Int {
    switch self {
    case .right: 0
    case .down: 1
    }
  }

  var columnStep: Int {
    switch self {
    case .right: 1
    case .down: 0
    }
  }
}
