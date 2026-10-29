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
    let compatibility = PlacementCompatibility(
      columns: columns, rows: rows, rules: rules, words: words, blank: blank)
    let alone = [Placement?](repeating: nil, count: words.count)
    let choices = words.indices.map { index in
      let allowedRules = index == 0 ? firstRule.map { [$0] } ?? rules : rules
      return random.shuffled(
        candidates(for: words[index], rules: allowedRules) { placement in
          var chosen = alone
          chosen[index] = placement
          return compatibility.accepts(chosen)
        })
    }
    guard choices.allSatisfy({ !$0.isEmpty }) else { return .impossible }
    var search = Search(
      words: words.map(Array.init), choices: choices,
      order: words.indices.sorted { choices[$0].count < choices[$1].count },
      downWords: downWords, nodeLimit: nodeLimit,
      standApart: compatibility.accepts, completes: completes,
      letters: Array(repeating: nil, count: rows * columns),
      uses: Array(repeating: 0, count: rows * columns),
      chosen: Array(repeating: nil, count: words.count))
    if search.place(at: 0) { return .placed(search.chosen.compactMap { $0 }) }
    return search.exhausted ? .undetermined : .impossible
  }

  private func candidates(
    for word: String, rules: [WordRule], accepting: (Placement) -> Bool
  ) -> [Candidate] {
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
          guard accepting(Placement(word: word, cells: shape)) else { continue }
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
}
