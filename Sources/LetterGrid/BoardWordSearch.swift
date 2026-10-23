struct BoardWordSearch {
  enum Lookup {
    case indexed(WordIndex)
    case words(Set<String>)

    var isEmpty: Bool {
      switch self {
      case .indexed(let index): index.longest == 0
      case .words(let words): words.isEmpty
      }
    }

    func contains(_ text: String) -> Bool {
      switch self {
      case .words(let words): return words.contains(text)
      case .indexed(let dictionary):
        var index: Int? = 0
        for letter in text {
          guard let next = dictionary.next(after: index, letter: letter) else { return false }
          index = next
        }
        return dictionary.word(at: index) != nil
      }
    }
  }

  let board: Board
  let dictionary: Lookup
  private let coverage: PlacementCoverage

  init(board: Board, dictionary: Lookup) {
    self.board = board
    self.dictionary = dictionary
    self.coverage = PlacementCoverage(board.placements)
  }

  func words(along directions: [Direction]) -> [String] {
    guard !dictionary.isEmpty else { return [] }
    let stable: Bool
    switch dictionary {
    case .indexed: stable = cellBoundariesAreStable(along: directions)
    case .words: stable = false
    }
    var words: [String] = []
    for row in 0..<board.rows {
      for column in 0..<board.columns {
        for direction in directions {
          let start = Cell(row: row, column: column)
          switch dictionary {
          case .indexed(let index) where stable:
            words += indexedWords(from: start, along: direction, in: index)
          default:
            words += joinedWords(from: start, along: direction)
          }
        }
      }
    }
    return words
  }

  static func shouldIndex(wordCount: Int, on board: Board, along directions: [Direction]) -> Bool {
    guard wordCount > 0 else { return false }
    var readings = 0
    for direction in directions {
      for row in 0..<board.rows {
        for column in 0..<board.columns {
          let rowSpace = direction.rowStep < 0 ? row + 1 : board.rows - row
          let columnSpace = direction.columnStep < 0 ? column + 1 : board.columns - column
          let length = min(
            direction.rowStep == 0 ? Int.max : rowSpace,
            direction.columnStep == 0 ? Int.max : columnSpace)
          if length >= wordCount - readings { return true }
          readings += length
        }
      }
    }
    return false
  }

  private func indexedWords(
    from start: Cell, along direction: Direction, in dictionary: WordIndex
  ) -> [String] {
    let covered = coverage.length(from: start, along: direction)
    var words: [String] = []
    var index: Int? = 0
    var length = 0
    var cell = start
    while board.contains(cell), let next = dictionary.next(after: index, letter: board[cell]) {
      index = next
      length += 1
      if length > covered, dictionary.word(at: index) != nil {
        let cells = (0..<length).map { start.moved(direction, by: $0) }
        words.append(board.text(along: cells))
      }
      cell = cell.moved(direction, by: 1)
    }
    return words
  }

  private func joinedWords(from start: Cell, along direction: Direction) -> [String] {
    let covered = coverage.length(from: start, along: direction)
    var words: [String] = []
    var text = ""
    var length = 0
    var cell = start
    while board.contains(cell) {
      text.append(board[cell])
      length += 1
      if length > covered, dictionary.contains(text) { words.append(text) }
      cell = cell.moved(direction, by: 1)
    }
    return words
  }

  private func cellBoundariesAreStable(along directions: [Direction]) -> Bool {
    for direction in directions {
      for row in 0..<board.rows {
        for column in 0..<board.columns {
          var cell = Cell(row: row, column: column)
          guard !board.contains(cell.moved(direction, by: -1)) else { continue }
          var letters: [Character] = []
          while board.contains(cell) {
            letters.append(board[cell])
            cell = cell.moved(direction, by: 1)
          }
          if Array(String(letters)) != letters { return false }
        }
      }
    }
    return true
  }
}
