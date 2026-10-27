struct PathPacking {
  enum Outcome: Equatable {
    case placed([Placement])
    case impossible
    case undetermined
  }

  private struct Candidate {
    let slots: [Int]
    let placement: Placement
  }

  private struct Search {
    let words: [[Character]]
    let choices: [[Candidate]]
    let order: [Int]
    let downWords: ClosedRange<Int>
    let nodeLimit: Int
    let standApart: ([Placement?]) -> Bool
    let completes: ([Placement]) -> Bool
    var letters: [Character?]
    var uses: [Int]
    var chosen: [Placement?]
    var vertical = 0
    var nodes = 0
    var exhausted = false

    mutating func place(at depth: Int) -> Bool {
      guard depth < order.count else {
        return downWords.contains(vertical) && completes(chosen.compactMap { $0 })
      }
      let index = order[depth]
      let remaining = order.count - depth - 1
      for candidate in choices[index] {
        nodes += 1
        guard nodes <= nodeLimit else {
          exhausted = true
          return false
        }
        let counted = vertical + (candidate.placement.direction.isVertical ? 1 : 0)
        guard counted <= downWords.upperBound, counted + remaining >= downWords.lowerBound,
          fits(candidate, word: words[index])
        else { continue }
        apply(candidate, word: words[index])
        chosen[index] = candidate.placement
        vertical = counted
        if standApart(chosen), place(at: depth + 1) { return true }
        vertical -= candidate.placement.direction.isVertical ? 1 : 0
        chosen[index] = nil
        remove(candidate)
        if exhausted { return false }
      }
      return false
    }

    private func fits(_ candidate: Candidate, word: [Character]) -> Bool {
      zip(candidate.slots, word).allSatisfy { slot, letter in
        letters[slot].map { $0 == letter } ?? true
      }
    }

    private mutating func apply(_ candidate: Candidate, word: [Character]) {
      for (slot, letter) in zip(candidate.slots, word) {
        letters[slot] = letter
        uses[slot] += 1
      }
    }

    private mutating func remove(_ candidate: Candidate) {
      for slot in candidate.slots {
        uses[slot] -= 1
        if uses[slot] == 0 { letters[slot] = nil }
      }
    }
  }

  let columns: Int
  let rows: Int
  let rules: [WordRule]
  var firstRule: WordRule?
  var downWords: ClosedRange<Int> = 0...Int.max
  var nodeLimit = 2_000_000
  var completes: @Sendable ([Placement]) -> Bool = { _ in true }

  func pack(_ words: [String], seed: UInt64 = 0) -> Outcome {
    precondition(
      firstRule.map(rules.contains) ?? true,
      "The first word's rule must be one of the rules every reading is checked against.")
    var random = SeededRandom(seed: seed)
    let used = Set(words.joined())
    guard !words.isEmpty,
      let blank = (0xE000...0xF8FF).lazy.compactMap(Unicode.Scalar.init).map(Character.init)
        .first(where: { !used.contains($0) })
    else { return .impossible }
    let alone = [Placement?](repeating: nil, count: words.count)
    let choices = words.indices.map { index in
      candidates(for: words[index], rules: index == 0 ? firstRule.map { [$0] } ?? rules : rules)
        .filter { candidate in
          var chosen = alone
          chosen[index] = candidate.placement
          return standApart(chosen, words: words, blank: blank)
        }
        .shuffled(using: &random)
    }
    guard choices.allSatisfy({ !$0.isEmpty }) else { return .impossible }
    var search = Search(
      words: words.map(Array.init), choices: choices,
      order: words.indices.sorted { choices[$0].count < choices[$1].count },
      downWords: downWords, nodeLimit: nodeLimit,
      standApart: { standApart($0, words: words, blank: blank) }, completes: completes,
      letters: Array(repeating: nil, count: rows * columns),
      uses: Array(repeating: 0, count: rows * columns),
      chosen: Array(repeating: nil, count: words.count))
    if search.place(at: 0) { return .placed(search.chosen.compactMap { $0 }) }
    return search.exhausted ? .undetermined : .impossible
  }

  private func candidates(for word: String, rules: [WordRule]) -> [Candidate] {
    var seen: Set<[Cell]> = []
    var found: [Candidate] = []
    for rule in rules {
      for direction in rule.startDirections {
        let shapes = PathShapes(
          columns: columns, length: word.count,
          rule: WordRule(startDirections: [direction], turns: rule.turns),
          maximumShapes: Int.max, maximumRows: rows, visitedLimit: nil, randomized: false
        ).cells()
        for shape in shapes {
          let height = (shape.map(\.row).max() ?? 0) + 1
          let width = (shape.map(\.column).max() ?? 0) + 1
          guard height <= rows, width <= columns else { continue }
          for row in 0...(rows - height) {
            for column in 0...(columns - width) {
              let cells = shape.map { Cell(row: $0.row + row, column: $0.column + column) }
              guard seen.insert(cells).inserted else { continue }
              found.append(
                Candidate(
                  slots: cells.map { $0.row * columns + $0.column },
                  placement: Placement(word: word, cells: cells)))
            }
          }
        }
      }
    }
    return found
  }

  private func standApart(_ chosen: [Placement?], words: [String], blank: Character) -> Bool {
    let placements = chosen.compactMap { $0 }
    var letters = Array(repeating: Array(repeating: blank, count: columns), count: rows)
    for placement in placements {
      for (cell, letter) in zip(placement.cells, placement.word) {
        letters[cell.row][cell.column] = letter
      }
    }
    let areas = placements.map { Set($0.cells) }
    let nested = areas.indices.contains { inner in
      areas.indices.contains { $0 != inner && areas[inner].isSubset(of: areas[$0]) }
    }
    guard !nested else { return false }
    let board = Board(letters: letters, placements: placements)
    let counts = letterCounts(letters, blank: blank)
    guard
      placements.allSatisfy({
        standsAlone($0.word, among: counts) || board.hasSingleOccurrence(of: $0.word, rules: rules)
      })
    else { return false }
    return zip(chosen, words).allSatisfy { placement, word in
      placement != nil || !spells(word, from: counts)
        || leavesRoom(for: word, on: board, beside: areas)
    }
  }

  private func letterCounts(_ letters: [[Character]], blank: Character) -> [Character: Int] {
    var counts: [Character: Int] = [:]
    for row in letters {
      for letter in row where letter != blank { counts[letter, default: 0] += 1 }
    }
    return counts
  }

  private func spells(_ word: String, from counts: [Character: Int]) -> Bool {
    var needed: [Character: Int] = [:]
    for letter in word { needed[letter, default: 0] += 1 }
    return needed.allSatisfy { counts[$0.key, default: 0] >= $0.value }
  }

  private func standsAlone(_ word: String, among counts: [Character: Int]) -> Bool {
    Set(word).count == word.count && word.allSatisfy { counts[$0] == 1 }
  }

  private func leavesRoom(for word: String, on board: Board, beside areas: [Set<Cell>]) -> Bool {
    var paths: Set<[Cell]> = []
    for reading in PathSearch(board: board, rules: rules, maximumReadings: 3)
      .readings(in: WordIndex([word]))
    where !paths.contains(Array(reading.cells.reversed())) {
      paths.insert(reading.cells)
    }
    guard let path = paths.first else { return true }
    return paths.count == 1 && !areas.contains { Set(path).isSubset(of: $0) }
  }
}
