struct RunFreeFill {
  static let completedCandidates = Generation.settings.fill.completedCandidates
  static let stepsPerChoice = Generation.settings.fill.stepsPerChoice

  private struct Template {
    let letters: [[Character?]]
    let empty: [Cell]
    let required: Set<Character>
    let targets: WordIndex
  }

  private struct CopyDemand {
    let missing: Set<Character>
    let remaining: Int
    let isCopyCell: Bool
  }

  private struct FillOrder {
    let cells: [Cell]
    let required: Set<Character>

    init(template: Template, using random: inout SeededRandom) {
      let copyCells = Set(random.shuffled(template.empty).prefix(template.required.count))
      cells =
        template.empty.filter(copyCells.contains)
        + template.empty.filter { !copyCells.contains($0) }
      required = template.required
    }

    func demand(at position: Int, letters: [[Character?]]) -> CopyDemand {
      CopyDemand(
        missing: required.subtracting(
          cells.prefix(position).compactMap { letters[$0.row][$0.column] }),
        remaining: cells.count - position, isCopyCell: position < required.count)
    }
  }

  private struct Strategy {
    let avoidsPairs: Bool

    func frame(letters: [Character], neighbours: [Character: Int]) -> Frame {
      let separate = letters.filter { neighbours[$0] == nil }
      let paired = avoidsPairs ? [] : letters.filter { neighbours[$0] != nil }
      return Frame(letters: separate + paired)
    }
  }

  private struct Frame {
    var letters: [Character]
    var next = 0

    mutating func take() -> Character? {
      guard next < letters.count else { return nil }
      defer { next += 1 }
      return letters[next]
    }
  }

  let board: Board
  let weights: LetterWeights
  let rules: [WordRule]
  let conditionalCharacters: Set<Character>

  func filled(seed: UInt64) -> Board? {
    let symbols = conditionalCharacters.union(
      board.placements.map(\.word).joined().filter { !$0.isLetter })
    guard let ordinary = weights.letters(excluding: symbols) else { return nil }
    let template = template()
    guard template.required.count <= template.empty.count else { return nil }
    let runs = LetterRuns(placements: board.placements, columns: board.columns, rows: board.rows)
    guard !runs.containsForbiddenRun(in: template.letters) else { return nil }
    var random = SeededRandom(seed: seed)
    for strategy in [Strategy(avoidsPairs: true), Strategy(avoidsPairs: false)] {
      let filled = search(
        template, weights: ordinary, runs: runs, strategy: strategy, using: &random)
      if let filled { return filled }
    }
    return nil
  }

  private func template() -> Template {
    let letters = board.placementLetters
    var empty: [Cell] = []
    for row in 0..<board.rows {
      for column in 0..<board.columns {
        let cell = Cell(row: row, column: column)
        if letters[row][column] == nil { empty.append(cell) }
      }
    }
    var counts: [Character: Int] = [:]
    for letter in letters.joined().compactMap({ $0 }) { counts[letter, default: 0] += 1 }
    return Template(
      letters: letters, empty: empty,
      required: Set(counts.filter { $0.value < 2 }.keys),
      targets: WordIndex(Set(board.placements.map(\.word))))
  }

  private func search(
    _ template: Template, weights: LetterWeights, runs: LetterRuns,
    strategy: Strategy, using random: inout SeededRandom
  ) -> Board? {
    var letters = template.letters
    let targets = FillWordCheck(
      board: board, index: template.targets, rules: rules, fixed: template.letters)
    let order = FillOrder(template: template, using: &random)
    let empty = order.cells
    var frames: [Frame] = []
    var position = 0
    var completions = 0
    var remaining = max(1, empty.count) * (weights.letterCount + 1) * Self.stepsPerChoice
    let neighbours = LetterNeighbours(columns: board.columns, rows: board.rows)
    while remaining > 0 || position == empty.count {
      if position == empty.count {
        guard completions < Self.completedCandidates else { return nil }
        completions += 1
        let candidate = completed(letters)
        if readsTargetsOnce(candidate) { return candidate }
        guard position > 0 else { return nil }
        position -= 1
        let cell = empty[position]
        letters[cell.row][cell.column] = nil
        continue
      }
      let cell = empty[position]
      if frames.count == position {
        let counts = neighbours.counts(around: cell) { letters[$0.row][$0.column] }
        let ordered = choices(
          for: order.demand(at: position, letters: letters), weights: weights,
          neighbours: counts, using: &random)
        frames.append(strategy.frame(letters: ordered, neighbours: counts))
      }
      guard let letter = frames[position].take() else {
        letters[cell.row][cell.column] = nil
        frames.removeLast()
        guard position > 0 else { return nil }
        position -= 1
        let previous = empty[position]
        letters[previous.row][previous.column] = nil
        continue
      }
      remaining -= 1
      letters[cell.row][cell.column] = letter
      guard !runs.hasForbiddenRun(through: cell, in: letters),
        targets.isClean(filling: cell, letters: letters)
      else { continue }
      position += 1
    }
    return nil
  }

  private func choices(
    for demand: CopyDemand, weights: LetterWeights, neighbours: [Character: Int],
    using random: inout SeededRandom
  ) -> [Character] {
    let missing = demand.missing
    guard missing.count <= demand.remaining else { return [] }
    let copies = random.shuffled(missing.sorted(by: { $0.precedesInCodePoints($1) }))
    guard missing.count < demand.remaining else { return copies }
    let ordinary = weights.orderedLetters(using: &random, neighbours: neighbours)
      .filter { !missing.contains($0) }
    return demand.isCopyCell || random.nextInt(below: demand.remaining) < missing.count
      ? copies + ordinary : ordinary + copies
  }

  private func readsTargetsOnce(_ candidate: Board) -> Bool {
    candidate.placements.allSatisfy { candidate.hasSingleOccurrence(of: $0.word, rules: rules) }
  }

  private func completed(_ letters: [[Character?]]) -> Board {
    Board(
      letters: letters.map { row in
        row.map { letter in
          guard let letter else { preconditionFailure("Every searched cell has a letter") }
          return letter
        }
      }, placements: board.placements)
  }
}

struct LetterRuns {
  private struct Triple {
    let first: Cell
    let second: Cell
    let third: Cell

    func matches(_ letters: [[Character?]]) -> Bool {
      guard let letter = letters[first.row][first.column] else { return false }
      return letters[second.row][second.column] == letter
        && letters[third.row][third.column] == letter
    }
  }

  let columns: Int
  let rows: Int
  private let triplesByCell: [Cell: [Triple]]

  init(placements: [Placement], columns: Int, rows: Int) {
    self.columns = columns
    self.rows = rows
    var triples: Set<[Cell]> = []
    for placement in placements where placement.cells.count >= 3 {
      for start in 0...(placement.cells.count - 3) {
        let cells = Array(placement.cells[start..<(start + 3)])
        triples.insert(cells)
        triples.insert(Array(cells.reversed()))
      }
    }
    var indexed: [Cell: [Triple]] = [:]
    let axes = Direction.lineAxes
    for row in 0..<rows {
      for column in 0..<columns {
        let start = Cell(row: row, column: column)
        for direction in axes {
          let cells = (0..<3).map { start.moved(direction, by: $0) }
          guard
            cells.allSatisfy({
              (0..<rows).contains($0.row) && (0..<columns).contains($0.column)
            }), !triples.contains(cells)
          else { continue }
          let triple = Triple(first: cells[0], second: cells[1], third: cells[2])
          for cell in cells { indexed[cell, default: []].append(triple) }
        }
      }
    }
    triplesByCell = indexed
  }

  func containsForbiddenRun(in letters: [[Character?]]) -> Bool {
    (0..<rows).contains { row in
      (0..<columns).contains { column in
        hasForbiddenRun(through: Cell(row: row, column: column), in: letters)
      }
    }
  }

  func hasForbiddenRun(through cell: Cell, in letters: [[Character?]]) -> Bool {
    triplesByCell[cell, default: []].contains { $0.matches(letters) }
  }
}

extension Board {
  init(targets layout: Layout, columns: Int) {
    let used = Set(layout.placements.map(\.word).joined())
    guard
      let blank = (0xE000...0xF8FF).lazy.compactMap(Unicode.Scalar.init).map(Character.init)
        .first(where: { !used.contains($0) })
    else { preconditionFailure("Target words cannot use every private-use character") }
    var letters = Array(repeating: Array(repeating: blank, count: columns), count: layout.rows)
    for placement in layout.placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    self.init(letters: letters, placements: layout.placements)
  }

  var placementLetters: [[Character?]] {
    let occupied = Set(placements.flatMap(\.cells))
    return letters.enumerated().map { row, letters in
      letters.enumerated().map { column, letter in
        occupied.contains(Cell(row: row, column: column)) ? letter : nil
      }
    }
  }

  var hasAddedEqualPair: Bool {
    let occupied = Set(placements.flatMap(\.cells))
    let axes = Direction.lineAxes
    for row in 0..<rows {
      for column in 0..<columns {
        let cell = Cell(row: row, column: column)
        for direction in axes {
          let next = cell.moved(direction, by: 1)
          guard contains(next), !(occupied.contains(cell) && occupied.contains(next)),
            self[cell] == self[next]
          else { continue }
          return true
        }
      }
    }
    return false
  }
}

extension Layout {
  func hasForbiddenTargetRun(columns: Int) -> Bool {
    var letters = Array(repeating: [Character?](repeating: nil, count: columns), count: rows)
    for placement in placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    return LetterRuns(placements: placements, columns: columns, rows: rows)
      .containsForbiddenRun(in: letters)
  }

  func charactersToCopyIfRoom(columns: Int) -> Set<Character>? {
    var letters: [Cell: Character] = [:]
    for placement in placements {
      for (cell, letter) in zip(placement.cells, placement.word) { letters[cell] = letter }
    }
    var counts: [Character: Int] = [:]
    for letter in letters.values { counts[letter, default: 0] += 1 }
    let needing = Set(counts.filter { $0.value < 2 }.keys)
    return needing.count <= rows * columns - letters.count ? needing : nil
  }
}
