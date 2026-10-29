struct RunFreeFill {
  static let completedCandidates = 20

  private enum SearchResult {
    case filled(Board)
    case impossible
    case unsettled
  }

  private struct Template {
    let letters: [[Character?]]
    let empty: [Cell]
    let required: Set<Character>
    let targets: WordIndex

    func missing(in letters: [[Character?]], before position: Int) -> Set<Character> {
      required.subtracting(empty.prefix(position).compactMap { letters[$0.row][$0.column] })
    }
  }

  private struct Strategy {
    let avoidsPairs: Bool
    let eliminatesNoise: Bool

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

  private struct WordChecks {
    let targets: FillWordCheck
    let noise: FillWordCheck?

    func isClean(filling cell: Cell, letters: [[Character?]]) -> Bool {
      guard targets.isClean(filling: cell, letters: letters) else { return false }
      guard let noise else { return true }
      return noise.isClean(filling: cell, letters: letters)
    }
  }

  let board: Board
  let weights: LetterWeights
  let rules: [WordRule]
  let conditionalCharacters: Set<Character>
  let dictionary: WordIndex

  func filled(seed: UInt64) -> Board? {
    let symbols = conditionalCharacters.union(
      board.placements.map(\.word).joined().filter { !$0.isLetter })
    guard let ordinary = weights.letters(excluding: symbols) else { return nil }
    let template = template(requiring: symbols)
    guard template.required.count <= template.empty.count else { return nil }
    let runs = LetterRuns(placements: board.placements, columns: board.columns, rows: board.rows)
    guard !runs.containsForbiddenRun(in: template.letters) else { return nil }
    var random = SeededRandom(seed: seed)
    for avoidsPairs in [true, false] {
      for eliminatesNoise in [true, false] {
        let strategy = Strategy(avoidsPairs: avoidsPairs, eliminatesNoise: eliminatesNoise)
        let result = search(
          template, weights: ordinary, runs: runs, strategy: strategy, using: &random)
        switch result {
        case .filled(let board): return board
        case .impossible: continue
        case .unsettled:
          if !eliminatesNoise && !avoidsPairs { return nil }
        }
      }
    }
    return nil
  }

  private func template(requiring symbols: Set<Character>) -> Template {
    let letters = board.placementLetters
    var empty: [Cell] = []
    for row in 0..<board.rows {
      for column in 0..<board.columns {
        let cell = Cell(row: row, column: column)
        if letters[row][column] == nil { empty.append(cell) }
      }
    }
    return Template(
      letters: letters, empty: empty,
      required: symbols.intersection(Set(board.placements.map(\.word).joined())),
      targets: WordIndex(Set(board.placements.map(\.word))))
  }

  private func search(
    _ template: Template, weights: LetterWeights, runs: LetterRuns,
    strategy: Strategy, using random: inout SeededRandom
  ) -> SearchResult {
    var letters = template.letters
    let checks = checks(for: template, eliminatingNoise: strategy.eliminatesNoise)
    let empty = template.empty
    var frames: [Frame] = []
    var position = 0
    var best: Board?
    var leastNoise = Int.max
    var completedCandidates = 0
    var remaining = max(1, empty.count) * (weights.letterCount + template.required.count) * 32
    let neighbours = LetterNeighbours(columns: board.columns, rows: board.rows)
    while remaining > 0 || position == empty.count {
      if position == empty.count {
        guard completedCandidates < Self.completedCandidates else {
          return best.map(SearchResult.filled) ?? .unsettled
        }
        completedCandidates += 1
        let candidate = completed(letters)
        consider(candidate, best: &best, leastNoise: &leastNoise)
        if leastNoise == 0 { return .filled(candidate) }
        guard position > 0 else { return best.map(SearchResult.filled) ?? .impossible }
        position -= 1
        let cell = empty[position]
        letters[cell.row][cell.column] = nil
        continue
      }
      let cell = empty[position]
      if frames.count == position {
        let counts = neighbours.counts(around: cell) { letters[$0.row][$0.column] }
        let ordered = choices(
          weights: weights, missing: template.missing(in: letters, before: position),
          remaining: empty.count - position, neighbours: counts, using: &random)
        frames.append(strategy.frame(letters: ordered, neighbours: counts))
      }
      guard let letter = frames[position].take() else {
        letters[cell.row][cell.column] = nil
        frames.removeLast()
        guard position > 0 else { return best.map(SearchResult.filled) ?? .impossible }
        position -= 1
        let previous = empty[position]
        letters[previous.row][previous.column] = nil
        continue
      }
      remaining -= 1
      letters[cell.row][cell.column] = letter
      guard !runs.hasForbiddenRun(through: cell, in: letters),
        checks.isClean(filling: cell, letters: letters)
      else { continue }
      position += 1
    }
    return best.map(SearchResult.filled) ?? .unsettled
  }

  private func checks(for template: Template, eliminatingNoise: Bool) -> WordChecks {
    WordChecks(
      targets: FillWordCheck(
        board: board, index: template.targets, rules: rules, fixed: template.letters),
      noise: eliminatingNoise
        ? FillWordCheck(board: board, index: dictionary, rules: rules, fixed: template.letters)
        : nil)
  }

  private func choices(
    weights: LetterWeights, missing: Set<Character>, remaining: Int,
    neighbours: [Character: Int], using random: inout SeededRandom
  ) -> [Character] {
    guard missing.count <= remaining else { return [] }
    var ordered =
      missing.count == remaining
      ? []
      : weights.orderedLetters(
        using: &random, neighbours: neighbours)
    for letter in missing.sorted(by: { String($0) < String($1) }) {
      ordered.insert(letter, at: random.nextInt(in: 0...ordered.count))
    }
    return ordered
  }

  private func consider(_ candidate: Board, best: inout Board?, leastNoise: inout Int) {
    guard
      candidate.placements.allSatisfy({
        candidate.hasSingleOccurrence(of: $0.word, rules: rules)
      })
    else { return }
    let noise = candidate.strayWordCount(in: dictionary, rules: rules, lessThan: leastNoise)
    if best == nil || noise < leastNoise {
      best = candidate
      leastNoise = noise
    }
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
}
