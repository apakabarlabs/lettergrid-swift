struct BoardFiller {
  private struct Frame {
    let letters: [Character]
    var next = 0

    mutating func take() -> Character? {
      guard next < letters.count else { return nil }
      defer { next += 1 }
      return letters[next]
    }
  }

  let columns: Int
  let directions: [Direction]
  let dictionary: WordIndex
  let targets: WordIndex
  private let layout: Layout
  private let intended: Set<Placement>
  private let covered: PlacementCoverage

  init(
    layout: Layout, columns: Int, directions: [Direction], dictionary: WordIndex,
    targets: WordIndex
  ) {
    self.layout = layout
    self.columns = columns
    self.directions = directions
    self.dictionary = dictionary
    self.targets = targets
    let readings = layout.placements + layout.placements.filter(\.isPalindrome).map(\.reversed)
    intended = Set(readings)
    self.covered = PlacementCoverage(layout.placements)
  }

  func fill(
    with weights: LetterWeights, attempts: Int, using random: inout SeededRandom
  ) -> Board? {
    guard attempts > 0 else { return nil }
    var letters = [Character?](repeating: nil, count: columns * layout.rows)
    for placement in layout.placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[index(of: cell)] = letter
      }
    }
    guard allStartsAreClean(letters) else { return nil }
    let empty = letters.indices.filter { letters[$0] == nil }
    for _ in 0..<attempts {
      if let filled = search(letters, empty: empty, with: weights, using: &random) {
        return board(from: filled)
      }
    }
    return nil
  }

  private func search(
    _ placed: [Character?], empty: [Int], with weights: LetterWeights,
    using random: inout SeededRandom
  ) -> [Character?]? {
    var letters = placed
    var frames: [Frame] = []
    var position = 0
    var trials = empty.count * weights.letterCount
    while position < empty.count {
      if frames.count == position {
        let neighbours = neighbours(of: cell(at: empty[position]), in: letters)
        frames.append(
          Frame(letters: weights.orderedLetters(using: &random, neighbours: neighbours)))
      }
      guard let letter = frames[position].take() else {
        letters[empty[position]] = nil
        frames.removeLast()
        guard position > 0 else { return nil }
        position -= 1
        letters[empty[position]] = nil
        continue
      }
      guard trials > 0 else { return nil }
      trials -= 1
      let index = empty[position]
      letters[index] = letter
      if isClean(through: cell(at: index), letters: letters) { position += 1 }
    }
    return letters
  }

  private func neighbours(of cell: Cell, in letters: [Character?]) -> [Character: Int] {
    LetterNeighbours(columns: columns, rows: layout.rows).counts(around: cell) {
      letters[index(of: $0)]
    }
  }

  private func board(from letters: [Character?]) -> Board {
    let rows = (0..<layout.rows).map { row in
      (0..<columns).map { column in
        guard let letter = letters[row * columns + column] else {
          fatalError("Every cell has been filled")
        }
        return letter
      }
    }
    return Board(letters: rows, placements: layout.placements)
  }

  private func allStartsAreClean(_ letters: [Character?]) -> Bool {
    letters.indices.allSatisfy { index in
      directions.allSatisfy { direction in
        isClean(from: cell(at: index), along: direction, letters: letters)
      }
    }
  }

  private func isClean(through cell: Cell, letters: [Character?]) -> Bool {
    let longest = max(dictionary.longest, targets.longest)
    for direction in directions {
      for distance in 0..<longest {
        let start = cell.moved(direction, by: -distance)
        guard contains(start) else { break }
        if !isClean(from: start, along: direction, letters: letters) { return false }
      }
    }
    return true
  }

  private func isClean(
    from start: Cell, along direction: Direction, letters: [Character?]
  ) -> Bool {
    var dictionaryNode: Int? = 0
    var targetNode: Int? = 0
    var length = 0
    var cell = start
    let coverage = covered.length(from: start, along: direction)
    while contains(cell), let letter = letters[index(of: cell)] {
      dictionaryNode = dictionary.next(after: dictionaryNode, letter: letter)
      targetNode = targets.next(after: targetNode, letter: letter)
      guard dictionaryNode != nil || targetNode != nil else { break }
      length += 1
      if let word = targets.word(at: targetNode) {
        let placement = Placement(word: word, start: start, direction: direction)
        if !intended.contains(placement) { return false }
      }
      if dictionary.word(at: dictionaryNode) != nil, length > coverage { return false }
      cell = cell.moved(direction, by: 1)
    }
    return true
  }

  private func contains(_ cell: Cell) -> Bool {
    (0..<layout.rows).contains(cell.row) && (0..<columns).contains(cell.column)
  }

  private func index(of cell: Cell) -> Int { cell.row * columns + cell.column }

  private func cell(at index: Int) -> Cell {
    Cell(row: index / columns, column: index % columns)
  }
}
