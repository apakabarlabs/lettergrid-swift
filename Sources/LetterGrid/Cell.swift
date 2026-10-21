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
  case downRight = "down_right"
  case downLeft = "down_left"
  case left
  case up
  case upLeft = "up_left"
  case upRight = "up_right"

  public var rowStep: Int {
    switch self {
    case .right, .left: 0
    case .down, .downRight, .downLeft: 1
    case .up, .upLeft, .upRight: -1
    }
  }

  public var columnStep: Int {
    switch self {
    case .right, .downRight, .upRight: 1
    case .down, .up: 0
    case .left, .downLeft, .upLeft: -1
    }
  }

  public var opposite: Direction {
    switch self {
    case .right: .left
    case .down: .up
    case .downRight: .upLeft
    case .downLeft: .upRight
    case .left: .right
    case .up: .down
    case .upLeft: .downRight
    case .upRight: .downLeft
    }
  }

  public var isVertical: Bool { columnStep == 0 }
  public var isDiagonal: Bool { rowStep != 0 && columnStep != 0 }
}
