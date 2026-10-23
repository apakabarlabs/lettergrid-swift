import Foundation

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

  public var isPalindrome: Bool { word == String(word.reversed()) }

  var reversed: Placement {
    Placement(
      word: String(word.reversed()), start: start.moved(direction, by: word.count - 1),
      direction: direction.opposite)
  }

  func reads(_ cells: [Cell]) -> Bool {
    cells == self.cells || (isPalindrome && cells == reversed.cells)
  }
}

public struct Board: Equatable, Sendable {
  public enum Failure: LocalizedError, Equatable {
    case irregularRows
    case duplicateWord(String)
    case invalidPlacement(String)

    public var errorDescription: String? {
      switch self {
      case .irregularRows: "A board must have equally wide, nonempty rows."
      case .duplicateWord(let word): "The board contains more than one placement of \(word)."
      case .invalidPlacement(let word):
        "The placement of \(word) must contain at least two letters and match its board cells."
      }
    }
  }

  public let columns: Int
  public let rows: Int
  public let letters: [[Character]]
  public let placements: [Placement]

  public init(letters: [[Character]], placements: [Placement]) {
    do {
      try self.init(validating: letters, placements: placements)
    } catch {
      preconditionFailure("Invalid board: \(error.localizedDescription)")
    }
  }

  public init(validating letters: [[Character]], placements: [Placement]) throws {
    self.columns = letters.first?.count ?? 0
    self.rows = letters.count
    self.letters = letters
    self.placements = placements
    guard letters.isEmpty || (columns > 0 && letters.allSatisfy({ $0.count == columns })) else {
      throw Failure.irregularRows
    }
    var words: Set<String> = []
    for placement in placements {
      guard words.insert(placement.word).inserted else {
        throw Failure.duplicateWord(placement.word)
      }
      guard fits(placement), text(along: placement.cells) == placement.word
      else { throw Failure.invalidPlacement(placement.word) }
    }
  }

  private func fits(_ placement: Placement) -> Bool {
    guard placement.word.count > 1, contains(placement.start) else { return false }
    let rowSpace =
      placement.direction.rowStep < 0
      ? placement.start.row + 1 : rows - placement.start.row
    let columnSpace =
      placement.direction.columnStep < 0
      ? placement.start.column + 1 : columns - placement.start.column
    return (placement.direction.rowStep == 0 || placement.word.count <= rowSpace)
      && (placement.direction.columnStep == 0 || placement.word.count <= columnSpace)
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
    guard length > 0 else { return 0 }
    var found: Set<Set<Cell>> = []
    for row in 0..<rows {
      for column in 0..<columns {
        for direction in directions {
          let start = Cell(row: row, column: column)
          let cells = (0..<length).map { start.moved(direction, by: $0) }
          if cells.allSatisfy(contains), text(along: cells) == word {
            found.insert(Set(cells))
          }
        }
      }
    }
    return found.count
  }

  public func strayWords(of dictionary: Set<String>, along directions: [Direction]) -> [String] {
    if BoardWordSearch.shouldIndex(wordCount: dictionary.count, on: self, along: directions) {
      return strayWords(in: WordIndex(dictionary), along: directions)
    }
    return BoardWordSearch(board: self, dictionary: .words(dictionary)).words(along: directions)
  }

  func strayWords(in dictionary: WordIndex, along directions: [Direction]) -> [String] {
    BoardWordSearch(board: self, dictionary: .indexed(dictionary)).words(along: directions)
  }

  public func selection(from start: Cell, toward end: Cell, along ways: [Direction]) -> [Cell] {
    guard contains(start) else { return [] }
    let row = Double(end.row) - Double(start.row)
    let column = Double(end.column) - Double(start.column)
    let reach = ways.map { way in
      let length = Double(way.rowStep * way.rowStep + way.columnStep * way.columnStep)
      let projection = row * Double(way.rowStep) + column * Double(way.columnStep)
      return (way: way, alignment: projection / sqrt(length), distance: projection / length)
    }
    guard let best = reach.filter({ $0.alignment > 0 }).max(by: { $0.alignment < $1.alignment })
    else {
      return [start]
    }
    let direction = best.way
    if ways.contains(where: \.isDiagonal) {
      let travel = hypot(row, column)
      guard best.alignment / travel >= cos(.pi / 8) else { return [start] }
    }
    let distance = Int(min(Double(max(rows, columns) - 1), best.distance.rounded()))
    return (0...distance).map { start.moved(direction, by: $0) }.prefix(while: contains).map { $0 }
  }
}
