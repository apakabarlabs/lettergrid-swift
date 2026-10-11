public struct Placement: Hashable, Sendable {
  public let word: String
  public let start: Cell
  public let direction: Direction

  public init(word: String, start: Cell, direction: Direction) {
    self.word = word
    self.start = start
    self.direction = direction
  }

  public var cells: [Cell] {
    (0..<word.count).map { start.moved(direction, by: $0) }
  }
}

public struct Board: Equatable, Sendable {
  public let columns: Int
  public let rows: Int
  public let letters: [[Character]]
  public let placements: [Placement]

  public init(letters: [[Character]], placements: [Placement]) {
    self.columns = letters.first?.count ?? 0
    self.rows = letters.count
    self.letters = letters
    self.placements = placements
  }

  public subscript(cell: Cell) -> Character {
    letters[cell.row][cell.column]
  }

  public func contains(_ cell: Cell) -> Bool {
    (0..<rows).contains(cell.row) && (0..<columns).contains(cell.column)
  }

  public func text(along cells: [Cell]) -> String {
    String(cells.map { self[$0] })
  }

  public func occurrences(of word: String, along directions: [Direction]) -> Int {
    let length = word.count
    var found = 0
    for row in 0..<rows {
      for column in 0..<columns {
        for direction in directions {
          let start = Cell(row: row, column: column)
          let cells = (0..<length).map { start.moved(direction, by: $0) }
          if cells.allSatisfy(contains), text(along: cells) == word {
            found += 1
          }
        }
      }
    }
    return found
  }

  public func selection(from start: Cell, toward end: Cell, along ways: [Direction]) -> [Cell] {
    guard contains(start) else { return [] }
    let reach = ways.map { way in
      (way, way.rowStep == 0 ? end.column - start.column : end.row - start.row)
    }
    guard let (direction, distance) = reach.filter({ $0.1 > 0 }).max(by: { $0.1 < $1.1 }) else {
      return [start]
    }
    return (0...distance).map { start.moved(direction, by: $0) }.prefix(while: contains).map { $0 }
  }
}
